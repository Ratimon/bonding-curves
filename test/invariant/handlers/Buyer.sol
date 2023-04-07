// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;


import {Test} from "@forge-std/Test.sol";
import {console} from "@forge-std/console.sol";
import {UD60x18, ud, unwrap } from "@prb-math/UD60x18.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from  "@solmate/test/utils/mocks/MockERC20.sol";
import {LinearBondingCurve} from "@main/examples/LinearBondingCurve.sol";

contract InvariantBuyer is Test {

    LinearBondingCurve internal  _bondingCurve;
    MockERC20 internal _underlyingBuyToken;
    MockERC20 internal _underlyingSaleToken;

    constructor(address bondingCurve_, address underlyingBuyToken_, address underlyingSaleToken_) {
        _bondingCurve    = LinearBondingCurve(bondingCurve_);
        _underlyingBuyToken = MockERC20(underlyingBuyToken_);
        _underlyingSaleToken =  MockERC20(underlyingSaleToken_);
    }

    function purchase(uint256 amount_) external {
        amount_ = bound(amount_, 1, 1e29 );  // 100 billion at WAD precision
        uint256 startingBuyBalance = _underlyingBuyToken.balanceOf(address(this));
        deal({token : address(_underlyingBuyToken), to: address(this), give: amount_ });
        _underlyingBuyToken.approve(address(_bondingCurve), amount_);
        _bondingCurve.purchase( address(this),  amount_);
        // Ensure successful purchase
        assertEq(_underlyingBuyToken.balanceOf(address(this)), startingBuyBalance - amount_);
    }

}


contract InvariantBuyerManager is Test {

    address  _bondingCurve;
    address internal _underlyingBuyToken;
    address internal _underlyingSaleToken;
    InvariantBuyer[] public buyers;
    mapping(bytes32 => uint256) public calls;

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor(address bondingCurve_, address underlyingBuyToken_, address underlyingSaleToken_) {
        _bondingCurve    = bondingCurve_;
        _underlyingBuyToken = underlyingBuyToken_;
        _underlyingSaleToken =  underlyingSaleToken_;
    }

    function createBuyer() external {
        InvariantBuyer buyer = new InvariantBuyer(_bondingCurve, _underlyingBuyToken, _underlyingSaleToken);
        buyers.push(buyer);
    }

    function purchase(uint256 amount_, uint256 index_) external countCall("purchase") {
        index_ = bound(index_, 0, buyers.length - 1 );  
        buyers[index_].purchase(amount_);
    }

    function getBuyerCount() external view returns (uint256 stakerCount_) {
        return buyers.length;
    }

    function callSummary() external view {
        console.log("-------------------");
        console.log("purchase", calls["purchase"]);
    }

}