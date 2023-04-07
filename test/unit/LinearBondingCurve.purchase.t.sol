// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBondingCurve} from "@main/bondingcurves/IBondingCurve.sol";

import {BondingCurve} from "@main/bondingcurves/BondingCurve.sol";
import {LinearCurve} from "@main/pricings/LinearCurve.sol";
import {LinearBondingCurve} from "@main/examples/LinearBondingCurve.sol";

import {MockERC20} from  "@solmate/test/utils/mocks/MockERC20.sol";
import {UD60x18, ud, unwrap } from "@prb-math/UD60x18.sol";

import {ConstantsFixture}  from "@test/utils/ConstantsFixture.sol";
import {DeploymentLinearBondingCurve}  from "@test/utils/LinearBondingCurve.constructor.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TestUnitLinearBondingCurve is ConstantsFixture, DeploymentLinearBondingCurve {

    event CapUpdate(UD60x18 oldAmount, UD60x18 newAmount);
    event Purchase(address indexed to, UD60x18 amountIn, UD60x18 amountOut);
    event Allocate(address indexed caller, UD60x18 amount);
    
    IBondingCurve linearBondingCurve;

    IERC20 acceptedToken;
    IERC20 saleToken;

    function setUp() public  virtual override {
        super.setUp();
        vm.label(address(this), "TestUnitLinearBondingCurve");

        vm.startPrank(deployer);
        vm.warp({newTimestamp: staticTime } );

        acceptedToken = IERC20(address( new MockERC20("TestAcceptedToken", "AT0", 18)));
        vm.label(address(acceptedToken), "acceptedToken");

        saleToken = IERC20(address( new MockERC20("TestSaleToken", "ST0", 18)));
        vm.label(address(saleToken), "TestSaleToken");

        arg_linearBondingCurve.acceptedToken = IERC20(address(acceptedToken));
        arg_linearBondingCurve.token = IERC20(address(saleToken));
        arg_linearBondingCurve._duration = 1 weeks;
        arg_linearBondingCurve._cap = 20_000e18;
        arg_linearBondingCurve._slope = 1.5e18;
        arg_linearBondingCurve._initialPrice = 30e18;

        vm.stopPrank();
    }

    function dealERC20(address saleToken_, address deployer_, uint256 cap_ ) internal {
        deal({token : saleToken_, to: deployer_, give: cap_ });
    }

    modifier deployerInit() {
        vm.startPrank(deployer);

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true}  );
        emit CapUpdate(ud(0), ud(arg_linearBondingCurve._cap));
        linearBondingCurve = IBondingCurve(DeploymentLinearBondingCurve.deployAndSetup( arg_linearBondingCurve, dealERC20, saleToken, deployer ));
        vm.label(address(linearBondingCurve), "linearBondingCurve");

        assertEq( unwrap(linearBondingCurve.cap()), IERC20(saleToken).balanceOf(address(linearBondingCurve)) );

        vm.stopPrank(  );
        _;
    }

    modifier asBuyer() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);
        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        _;
        vm.stopPrank(  );
    }

     function test_RevertWhen_unexpectedETH_purchase() external deployerInit() asBuyer() {
        uint256 purchase_amount = 7e18;
        vm.expectRevert( bytes("BondingCurve: unexpected ETH input"));
        linearBondingCurve.purchase{value : 0.1 ether}( alice, purchase_amount);

        vm.stopPrank();
     }

    function test_RevertWhen_exceedsCap_purchase() external deployerInit() {
        uint256 purchase_amount = 200e18;
        vm.expectRevert( bytes("BondingCurve: exceeds cap"));
        linearBondingCurve.purchase( alice, purchase_amount);

        vm.stopPrank();
     }

    function test_ForState_acceptedToken_purchase() external deployerInit() asBuyer() {
        uint256 alicePreBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(alice);
        UD60x18 preReserveBalance = linearBondingCurve.reserveBalance();

        uint256 purchase_amount = 7e18;
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true, emitter: address(linearBondingCurve) }  );
        emit Purchase(alice, ud(purchase_amount), ud(246.75 ether));
        linearBondingCurve.purchase( alice, purchase_amount);

        uint256 alicePostBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(alice);
        UD60x18 postReserveBalance = linearBondingCurve.reserveBalance();
        uint256 changeInAliceBalAcceptedToken = alicePostBalAcceptedToken > alicePreBalAcceptedToken ? (alicePostBalAcceptedToken - alicePreBalAcceptedToken) : (alicePreBalAcceptedToken - alicePostBalAcceptedToken);

        assertEq(alicePostBalAcceptedToken, 13e18 );
        assertEq(changeInAliceBalAcceptedToken, purchase_amount );
        assertEq(unwrap(postReserveBalance.sub(preReserveBalance)), purchase_amount );
    }

    function test_ForState_SaleToken_purchase() external deployerInit() asBuyer() {
        uint256 alicePreBalSaleToken = IERC20(address(saleToken)).balanceOf(alice);
        UD60x18 preTotalPurchased = linearBondingCurve.totalPurchased();
        UD60x18 preAvailableToSell = linearBondingCurve.availableToSell();

        uint256 purchase_amount = 7e18;

        // 1.5*0 + 30 = 30
        assertEq(unwrap(linearBondingCurve.getCurrentPrice(ud(0))), 30e18 );
        assertEq(unwrap(linearBondingCurve.getCurrentPrice(linearBondingCurve.reserveBalance())), 30e18 );

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true, emitter: address(linearBondingCurve) }  );
        emit Purchase(alice, ud(purchase_amount), ud(246.75 ether));
        UD60x18 amountOut = linearBondingCurve.purchase( alice, purchase_amount);
        // 1.5/2*(7^2) + 30*(7) = 246.75

        uint256 alicePostBalSaleToken = IERC20(address(saleToken)).balanceOf(alice);
        UD60x18 postTotalPurchased = linearBondingCurve.totalPurchased();
        UD60x18 postAvailableToSell = linearBondingCurve.availableToSell();

        LinearCurve linearCurve =  LinearCurve(address(linearBondingCurve));
        
        UD60x18 postSaleTokenSupply = preTotalPurchased.add(ud(purchase_amount));
        UD60x18 firstIntegral = linearCurve.getPoolBalance(postSaleTokenSupply);
        UD60x18 secondIntegral = linearCurve.getPoolBalance(preTotalPurchased);
        UD60x18 changeInSaleToken = firstIntegral.sub(secondIntegral);

        // 1.5*7 + 30 = 40.5
        assertEq(unwrap(linearBondingCurve.getCurrentPrice(ud(purchase_amount))), 40.5e18 );
        assertEq(unwrap(linearBondingCurve.getCurrentPrice(linearBondingCurve.reserveBalance())), 40.5e18 );

        assertEq(alicePostBalSaleToken, 246.75e18 );
        assertEq(alicePostBalSaleToken - alicePreBalSaleToken, unwrap(changeInSaleToken) );

        assertEq(unwrap(postTotalPurchased), 246.75e18 );
        assertEq(unwrap(postTotalPurchased), unwrap(amountOut) );
        assertEq(unwrap(postTotalPurchased.sub(preTotalPurchased)),unwrap(changeInSaleToken) );
        assertEq(unwrap(postAvailableToSell), unwrap(preAvailableToSell.sub(changeInSaleToken)));
    }

}