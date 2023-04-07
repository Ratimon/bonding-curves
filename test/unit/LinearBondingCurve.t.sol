// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBondingCurve} from "@main/bondingcurves/IBondingCurve.sol";

import {LinearCurve} from "@main/pricings/LinearCurve.sol";
import {BondingCurve} from "@main/bondingcurves/BondingCurve.sol";
import {LinearBondingCurve} from "@main/examples/LinearBondingCurve.sol";

import {MockERC20} from  "@solmate/test/utils/mocks/MockERC20.sol";
import {UD60x18, ud, unwrap } from "@prb-math/UD60x18.sol";

import {ConstantsFixture}  from "@test/utils/ConstantsFixture.sol";
import {DeploymentLinearBondingCurve}  from "@test/utils/LinearBondingCurve.constructor.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TestUnitLinearBondingCurve is ConstantsFixture, DeploymentLinearBondingCurve {

    event CapUpdate(UD60x18 oldAmount, UD60x18 newAmount);
    event Purchase(address indexed to, UD60x18 amountIn, UD60x18 amountOut);
    
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

    modifier beforeEach() {
        vm.startPrank(deployer);

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true}  );
        emit CapUpdate(ud(0), ud(arg_linearBondingCurve._cap));

        // linearBondingCurve = new LinearBondingCurve(
        //     arg_linearBondingCurve.acceptedToken,
        //     arg_linearBondingCurve.token, 
        //     arg_linearBondingCurve._duration,
        //     arg_linearBondingCurve._cap,
        //     arg_linearBondingCurve._slope,
        //     arg_linearBondingCurve._initialPrice
        // );

        // saleToken.approve(address(linearBondingCurve),type(uint256).max);
        // dealERC20( address(saleToken), deployer,arg_linearBondingCurve._cap);
        // linearBondingCurve.init();
        linearBondingCurve = IBondingCurve(DeploymentLinearBondingCurve.deployAndSetup( arg_linearBondingCurve, dealERC20, saleToken, deployer ));

        vm.label(address(linearBondingCurve), "linearBondingCurve");

        assertEq( unwrap(linearBondingCurve.cap()), IERC20(saleToken).balanceOf(address(linearBondingCurve)) );

        vm.stopPrank(  );
        _;
    }

     function test_RevertWhen_unexpectedETH_purchase() external beforeEach() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 7e18;
        vm.expectRevert( bytes("BondingCurve: unexpected ETH input"));
        linearBondingCurve.purchase{value : 0.1 ether}( alice, purchase_amount);

        vm.stopPrank();
     }

    function test_RevertWhen_exceedsCap_purchase() external beforeEach() {
        deal({token : address(acceptedToken), to: alice, give: 200e18 });
        vm.startPrank(alice);

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 200e18;
        vm.expectRevert( bytes("BondingCurve: exceeds cap"));
        linearBondingCurve.purchase( alice, purchase_amount);

        vm.stopPrank();
     }

    function test_ForState_acceptedToken_purchase() external beforeEach() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);

        uint256 alicePreBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(alice);
        UD60x18 preReserveBalance = linearBondingCurve.reserveBalance();

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 7e18;

        // vm.expectEmit();
        // vm.expectEmit(true, true, true, true, address(linearBondingCurve));
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true, emitter: address(linearBondingCurve) }  );
        emit Purchase(alice, ud(purchase_amount), ud(246.75 ether));
        linearBondingCurve.purchase( alice, purchase_amount);

        uint256 alicePostBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(alice);
        UD60x18 postReserveBalance = linearBondingCurve.reserveBalance();
        uint256 changeInAliceBalAcceptedToken = alicePostBalAcceptedToken > alicePreBalAcceptedToken ? (alicePostBalAcceptedToken - alicePreBalAcceptedToken) : (alicePreBalAcceptedToken - alicePostBalAcceptedToken);

        assertEq(alicePostBalAcceptedToken, 13e18 );
        assertEq(changeInAliceBalAcceptedToken, purchase_amount );
        assertEq(unwrap(postReserveBalance.sub(preReserveBalance)), purchase_amount );

        vm.stopPrank();
    }

    function test_ForState_SaleToken_purchase() external beforeEach() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);

        uint256 alicePreBalSaleToken = IERC20(address(saleToken)).balanceOf(alice);
        UD60x18 preTotalPurchased = linearBondingCurve.totalPurchased();
        UD60x18 preAvailableToSell = linearBondingCurve.availableToSell();

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 7e18;

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

        assertEq(alicePostBalSaleToken, 246.75e18 );
        assertEq(alicePostBalSaleToken - alicePreBalSaleToken, unwrap(changeInSaleToken) );

        assertEq(unwrap(postTotalPurchased), 246.75e18 );
        assertEq(unwrap(postTotalPurchased), unwrap(amountOut) );
        assertEq(unwrap(postTotalPurchased.sub(preTotalPurchased)),unwrap(changeInSaleToken) );
        assertEq(unwrap(postAvailableToSell), unwrap(preAvailableToSell.sub(changeInSaleToken)));

        vm.stopPrank();
    }


    function test_allocate() external beforeEach() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);
        vm.warp( {newTimestamp: staticTime + 1 days} );

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 7e18;

        linearBondingCurve.purchase( alice, purchase_amount);

        vm.stopPrank();

        vm.startPrank(deployer);
        vm.warp({newTimestamp: staticTime + 3 weeks } );

        uint256 deployerPreBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(deployer);
        uint256 allocate_amount = 5e18;

        linearBondingCurve.allocate( allocate_amount, deployer);

        uint256 deployerPostBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(deployer);
        uint256 changeInDeployerBalAcceptedToken = deployerPostBalAcceptedToken > deployerPreBalAcceptedToken ? (deployerPostBalAcceptedToken - deployerPreBalAcceptedToken) : (deployerPreBalAcceptedToken - deployerPostBalAcceptedToken);

        assertEq(deployerPostBalAcceptedToken, 5e18 );
        assertEq(changeInDeployerBalAcceptedToken, allocate_amount );


        vm.stopPrank();
    }


}