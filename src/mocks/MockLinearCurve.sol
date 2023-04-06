// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {LinearCurve} from "@main/pricings/LinearCurve.sol";

contract MockLinearCurve is LinearCurve {
    constructor(
        uint256 _slope,
        uint256 _initialPrice
        ) LinearCurve(_slope,_initialPrice) {
    }
}
