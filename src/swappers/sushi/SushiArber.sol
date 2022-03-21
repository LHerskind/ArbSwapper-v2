// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV2Router01} from "./../../interfaces/IUniswapV2Router01.sol";

import {BaseSwapperV2} from "./../BaseSwapperV2.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {DSTest} from "ds-test/test.sol";

/**
 * @notice Simple arber for sushiswap. Not the most gas-efficient, but made to be easy to follow.
 * Will swap `_borrowAmount` of `_borrowAsset` to at least `_repayAmount` of _repayAsset`.
 * Using the sushi swap router and only one pair, could use the `_executionData` to pass a path etc.
 */
contract SushiArber is BaseSwapperV2, DSTest {
    IUniswapV2Router01 public constant ROUTER =
        IUniswapV2Router01(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    function execute(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        uint256 _repayAmount,
        bytes memory _executionData
    ) internal virtual override(BaseSwapperV2) {
        ERC20(_borrowAsset).approve(address(ROUTER), _borrowAmount);

        address[] memory path = new address[](2);
        path[0] = _borrowAsset;
        path[1] = _repayAsset;

        ROUTER.swapExactTokensForTokens(
            _borrowAmount,
            _repayAmount,
            path,
            address(this),
            block.timestamp
        );
    }
}
