// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {UnsafeUnilib} from "./lib/UnsafeUnilib.sol";

// We are throwing away requires that are mostly hitting us if we have bad input.

/**
 * @notice Minimal implementation to support Uniswap V2 flash swaps (flashloan + swap)
 * @dev This contract should not be holding any funds beyond a few wei for gas savings.
 * There are no requires or safety checks within the code, meaning that it may revert late
 * if incorrect or bad input is provided.
 * @author Lasse Herskind
 */
abstract contract BaseSwapperV2 {
    using SafeTransferLib for ERC20;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @notice Execute arbitrary logic for the user.
     * @dev To be overridden by inheriting contract
     * @param _borrowAsset The address of the asset to borrow
     * @param _borrowAmount The amount borrowed that is given to the contract
     * @param _repayAsset The address of the asset to repay with
     * @param _repayAmount The amount to repay
     */
    function execute(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        uint256 _repayAmount,
        bytes memory _executionData
    ) internal virtual {}

    /**
     * @notice Performs a Uniswap V2 flash swap through 1 or 2 pairs
     * @param _borrowAsset The address of the asset to borrow
     * @param _borrowAmount The amount to borrow
     * @param _repayAsset The address of the asset to repay with
     * @param _triangular True if flashswap should go through WETH, false otherwise
     * @param _executionData Bytes to be decoded by `execute` to perform arb
     */
    function swap(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        bool _triangular,
        bytes memory _executionData
    ) public {
        if (!_triangular) {
            _singleFlashSwap(
                _borrowAsset,
                _borrowAmount,
                _repayAsset,
                _executionData
            );
        } else {
            _triangularFlashSwap(
                _borrowAsset,
                _borrowAmount,
                _repayAsset,
                _executionData
            );
        }
    }

    /**
     * @notice Helper function to initiate single pair flash swap
     * @param _borrowAsset The address of the borrow asset
     * @param _borrowAmount The amount to borrow
     * @param _repayAsset The address of the asset to repay with
     * @param _executionData Bytes to be decoded by `execute` to perform arb
     */
    function _singleFlashSwap(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        bytes memory _executionData
    ) private {
        (
            address token0,
            address token1,
            uint256 amount0Out,
            uint256 amount1Out
        ) = _borrowAsset < _repayAsset
                ? (_borrowAsset, _repayAsset, _borrowAmount, uint256(0))
                : (_repayAsset, _borrowAsset, uint256(0), _borrowAmount);
        bytes memory data = abi.encode(
            _borrowAsset,
            _borrowAmount,
            _repayAsset,
            0,
            _executionData
        );
        // Assume that pair is deployed. Compute the pair address internally to save gas
        address pair = UnsafeUnilib.getPair(token0, token1);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    /**
     * @notice Helper function to initiate double pair flash swap, e.g., A -> WETH -> B
     * @dev Triangular swaps are more complex. Will go to `repayPair` to get WETH and then
     * swap that to borrow, before finally repaying with the repay asset to satisfy K
     * @param _borrowAsset The address of the borrow asset
     * @param _borrowAmount The amount to borrow
     * @param _repayAsset The address of the asset to repay with
     * @param _executionData Bytes to be decoded by `execute` to perform arb
     */
    function _triangularFlashSwap(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        bytes memory _executionData
    ) private {
        (address borrowPair, uint256 wethNeeded) = _computeInputAmount(
            WETH,
            _borrowAsset,
            _borrowAmount
        );
        bytes memory data = abi.encode(
            _borrowAsset,
            _borrowAmount,
            _repayAsset,
            wethNeeded,
            _executionData
        );

        (
            uint256 amount0Out,
            uint256 amount1Out,
            address token0,
            address token1
        ) = _repayAsset < WETH
                ? (uint256(0), wethNeeded, _repayAsset, WETH)
                : (wethNeeded, uint256(0), WETH, _repayAsset);
        address repayPair = UnsafeUnilib.getPair(token0, token1);
        IUniswapV2Pair(repayPair).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }

    /// Callback in Uniswap V2 swap  ///

    /**
     * @notice Execute payload for triangular swap. Use Uniswap V2 pair to get `_borrowAmount` of `_borrowAsset`, then compute amount to repay and execute user-specific logic.
     * @param _borrowAsset The address that is borrowed
     * @param _borrowAmount The amount that is borrowed
     * @param _repayAsset The address of the asset to repay with
     * @param _executionData Bytes to be decoded by `execute` to perform arb
     */
    function _triangleExecute(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        uint256 _wethReceived,
        bytes memory _executionData
    ) private {
        (
            address token0,
            address token1,
            uint256 amount0Out,
            uint256 amount1Out
        ) = _borrowAsset < WETH
                ? (_borrowAsset, WETH, _borrowAmount, uint256(0))
                : (WETH, _borrowAsset, uint256(0), _borrowAmount);
        address borrowPair = UnsafeUnilib.getPair(token0, token1);
        ERC20(WETH).safeTransfer(borrowPair, _wethReceived);

        // Swap WETH to `_borrowAmount` `_borrowAsset`
        IUniswapV2Pair(borrowPair).swap(
            amount0Out,
            amount1Out,
            address(this),
            bytes("")
        );
        (address repayPair, uint256 amountToRepay) = _computeInputAmount(
            _repayAsset,
            WETH,
            _wethReceived
        );
        execute(
            _borrowAsset,
            _borrowAmount,
            _repayAsset,
            amountToRepay,
            _executionData
        );
        ERC20(_repayAsset).safeTransfer(repayPair, amountToRepay);
    }

    /**
     * @notice Execute payload for single swap, will compute how much is needed to repay
     * @param _borrowAsset The address that is borrowed
     * @param _borrowAmount The amount that is borrowed
     * @param _repayAsset The address of the asset to repay with
     * @param _executionData Bytes to be decoded by `execute` to perform arb
     */
    function _singleExecute(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        bytes memory _executionData
    ) private {
        (address pair, uint256 repayAmount) = _computeInputAmount(
            _repayAsset,
            _borrowAsset,
            _borrowAmount
        );
        execute(
            _borrowAsset,
            _borrowAmount,
            _repayAsset,
            repayAmount,
            _executionData
        );
        ERC20(_repayAsset).safeTransfer(pair, repayAmount);
    }

    /**
     * @notice Computes the amount of `_inputAsset` needed to get `_outputAmount` of `_outputAsset`.
     * @param _inputAsset The address of the asset we are providing as input
     * @param _outputAsset The address of the asset we which to receive
     * @param _outputAmount The amount of `_outputAsset` we are to receive
     * @return pair The address of uniswap pair
     * @return inputAmount The amount of `_inputAsset` needed to satisfy K
     */
    function _computeInputAmount(
        address _inputAsset,
        address _outputAsset,
        uint256 _outputAmount
    ) private view returns (address pair, uint256 inputAmount) {
        pair = UnsafeUnilib.sortAndGetPair(_inputAsset, _outputAsset);
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        (uint256 inputReserve, uint256 outputReserve) = _inputAsset <
            _outputAsset
            ? (uint256(reserve0), uint256(reserve1))
            : (uint256(reserve1), uint256(reserve0));
        inputAmount =
            ((1000 * inputReserve * _outputAmount) /
                (997 * (outputReserve - _outputAmount))) +
            1;
    }

    /**
     * @notice Fallback function from Uniswap V2 `swap`
     * @param _sender The msg.sender that initiated the `swap` function
     * @param _amount0 The amount of asset0 that is received
     * @param _amount1 The amount of asset1 that is received
     * @param _data Bytes containing information for the swap + execution specific data
     */
    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        (
            address _borrowAsset,
            uint256 _borrowAmount,
            address _repayAsset,
            uint256 _wethIntermediate,
            bytes memory _executionData
        ) = abi.decode(_data, (address, uint256, address, uint256, bytes));

        if (_wethIntermediate > 0) {
            _triangleExecute(
                _borrowAsset,
                _borrowAmount,
                _repayAsset,
                _wethIntermediate,
                _executionData
            );
        } else {
            _singleExecute(
                _borrowAsset,
                _borrowAmount,
                _repayAsset,
                _executionData
            );
        }
    }
}
