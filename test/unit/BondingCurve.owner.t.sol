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

contract TestUnitBondingCurveAsOwner is ConstantsFixture, DeploymentLinearBondingCurve {

    event CapUpdate(UD60x18 oldAmount, UD60x18 newAmount);
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

    modifier buyerPurchasesThen() {
        deal({token : address(acceptedToken), to: alice, give: 20e18 });
        vm.startPrank(alice);
        vm.warp( {newTimestamp: staticTime + 1 days} );

        IERC20(address(acceptedToken)).approve(address(linearBondingCurve), type(uint256).max);
        uint256 purchase_amount = 7e18;

        linearBondingCurve.purchase( alice, purchase_amount);
        
        vm.stopPrank(  );
        _;
    }



    function test_allocate() external deployerInit() buyerPurchasesThen() {

        vm.startPrank(deployer);
        vm.warp({newTimestamp: staticTime + 3 weeks } );

        uint256 deployerPreBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(deployer);
        uint256 allocate_amount = 5e18;

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true, emitter: address(linearBondingCurve) }  );
        emit Allocate(deployer, ud(allocate_amount));
        linearBondingCurve.allocate( allocate_amount, deployer);

        uint256 deployerPostBalAcceptedToken = IERC20(address(acceptedToken)).balanceOf(deployer);
        uint256 changeInDeployerBalAcceptedToken = deployerPostBalAcceptedToken > deployerPreBalAcceptedToken ? (deployerPostBalAcceptedToken - deployerPreBalAcceptedToken) : (deployerPreBalAcceptedToken - deployerPostBalAcceptedToken);

        assertEq(deployerPostBalAcceptedToken, 5e18 );
        assertEq(changeInDeployerBalAcceptedToken, allocate_amount );

        vm.stopPrank();
    }


}