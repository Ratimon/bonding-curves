// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {CommonBase} from "@forge-std/Base.sol";
import {StdCheats} from "@forge-std/StdCheats.sol";
import {StdUtils} from "@forge-std/StdUtils.sol";
import {console} from "@forge-std/console.sol";

import {MockERC20} from  "@solmate/test/utils/mocks/MockERC20.sol";
import {LinearBondingCurve} from "@main/examples/LinearBondingCurve.sol";

contract Warper is CommonBase, StdCheats, StdUtils {

    LinearBondingCurve internal  _bondingCurve;

    mapping(bytes32 => uint256) public calls;
    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor(address bondingCurve_) {
        _bondingCurve = LinearBondingCurve(bondingCurve_);
    }

    function warp(uint256 warpTime_) external countCall("warp") {
        vm.warp(block.timestamp + bound(warpTime_, 2 weeks, 3 weeks));
    }

    function callSummary() external view {
        console.log("-------------------");
        console.log("warp", calls["warp"]);
    }

}