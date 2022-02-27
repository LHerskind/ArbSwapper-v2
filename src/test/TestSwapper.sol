// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseSwapperV2} from "./../BaseSwapperV2.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {DSTest} from "ds-test/test.sol";

contract TestSwapper is BaseSwapperV2, DSTest {
    function execute(
        address _borrowAsset,
        uint256 _borrowAmount,
        address _repayAsset,
        uint256 _repayAmount,
        bytes memory _executionData
    ) internal virtual override(BaseSwapperV2) {
        uint256 balance = ERC20(_borrowAsset).balanceOf(address(this));
        assertGe(balance, _borrowAmount, "");
        emit log_named_decimal_uint("Borrow amount ", balance, 18);
        emit log_named_decimal_uint("Repay amount  ", _repayAmount, 18);
    }
}
