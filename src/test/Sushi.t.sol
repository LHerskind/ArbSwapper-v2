// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {TestHelper} from "./helpers/TestHelper.sol";

import {SushiArber} from "./../swappers/sushi/SushiArber.sol";
import {IWETH9} from "./../interfaces/IWETH9.sol";
import {IUniswapV2Router01} from "./../interfaces/IUniswapV2Router01.sol";

contract SushiArbTest is TestHelper {
    address internal constant DAI =
        address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal constant WETH =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant YFI =
        address(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    address internal constant USDC =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IUniswapV2Router01 public constant ROUTER =
        IUniswapV2Router01(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    SushiArber internal swapper;

    function setUp() public {
        swapper = new SushiArber();

        hevm.label(DAI, "DAI");
        hevm.label(WETH, "WETH");
        hevm.label(YFI, "YFI");
        hevm.label(USDC, "USDC");
    }

    function printState(address pair, address swapper) public {
        emit log_named_decimal_uint(
            "\tDAI  in pair",
            IERC20(DAI).balanceOf(pair),
            18
        );
        emit log_named_decimal_uint(
            "\tUSDC in pair",
            IERC20(USDC).balanceOf(pair),
            6
        );
        emit log_named_decimal_uint(
            "\tDAI  in swapper",
            IERC20(DAI).balanceOf(swapper),
            18
        );
        emit log_named_decimal_uint(
            "\tUSDC in swapper",
            IERC20(USDC).balanceOf(swapper),
            6
        );
    }

    function testArbDaiUSDC() public {
        /**
         * 1. Print initial state
         * 2. Some "victim" makes a bad trade and pushes pair off peg
         * 3. Print state after off peg to ensure it is off
         * 4. Arb it with a flashswap, no cash needed up front.
         * 5. Print state after arb, balance in swapper is profit
         */

        address pair = address(0xAaF5110db6e744ff70fB339DE037B990A20bdace);

        emit log("Initial state");
        printState(pair, address(swapper));

        pushPriceInPair(pair, DAI, USDC, 10000 ether);

        emit log("After pushing off pey");
        printState(pair, address(swapper));

        swapper.swap(USDC, 10000e6, DAI, false, bytes(""));

        emit log("Arbed");
        printState(pair, address(swapper));
    }

    function pushPriceInPair(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public {
        address victim = address(0xdead);
        _setTokenBalance(tokenIn, victim, amountIn);
        hevm.startPrank(victim);
        IERC20(tokenIn).approve(address(ROUTER), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Say hi to the mother of slippage
        ROUTER.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            victim,
            block.timestamp
        );
    }
}
