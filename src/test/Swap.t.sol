// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {TestHelper} from "./TestHelper.sol";

import {TestSwapper} from "./TestSwapper.sol";
import {IWETH9} from "./../interfaces/IWETH9.sol";

contract ArbSwapTest is TestHelper {
    address internal constant DAI =
        address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal constant WETH =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant YFI =
        address(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    address internal constant USDC =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    TestSwapper internal swapper;

    function setUp() public {
        // We need WETH as well as the ERC20
        swapper = new TestSwapper();

        VM.label(DAI, "DAI");
        VM.label(WETH, "WETH");
        VM.label(YFI, "YFI");
        VM.label(USDC, "USDC");
    }

    function testFlashswapDAIWETH() public {
        _setTokenBalance(DAI, address(swapper), 100000 ether);
        swapper.swap(WETH, 10 ether, DAI, false, bytes(""));
    }

    function testFlashswapDAIWETHYFI() public {
        _setTokenBalance(DAI, address(swapper), 100000 ether);
        swapper.swap(YFI, 2 ether, DAI, true, bytes(""));
    }

    function testFlashswapDAIWETHUSDC() public {
        _setTokenBalance(DAI, address(swapper), 100000 ether);
        swapper.swap(USDC, 1000e6, DAI, true, bytes(""));
    }
}
