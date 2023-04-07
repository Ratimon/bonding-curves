// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBondingCurve} from "@main/bondingcurves/IBondingCurve.sol";
import {IERC20Mintable} from "@main/interfaces/IERC20Mintable.sol";

import {Errors} from "@main/shared/Error.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Timed} from "@main/utils/Timed.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {UD60x18, ud, unwrap} from "@prb-math/UD60x18.sol";
import {gte, isZero} from "@prb-math/ud60x18/Helpers.sol";

abstract contract BondingCurve is IBondingCurve, Initializable, Pausable, Ownable2Step, Timed {
    using SafeERC20 for IERC20;

    /**
     * @notice the ERC20 token sale for this bonding curve
     *
     */
    IERC20 public immutable override token;

    /**
     * @notice the ERC20 accepted token for this bonding curve
     *
     */
    IERC20 public immutable override acceptedToken;

    /**
     * @notice the total amount of sale token purchased on bonding curve
     *
     */
    UD60x18 public override totalPurchased;

    /**
     * @notice the cap on how much sale token can be minted by the bonding curve
     *
     */
    UD60x18 public override cap;

    /**
     * @notice BondingCurve constructor
     * @param _acceptedToken ERC20 token in for this bonding curve
     * @param _token ERC20 token sale out for this bonding curve
     * @param _duration duration to sell
     * @param _cap maximum token sold for this bonding curve to ensure security
     *
     */
    constructor(IERC20 _acceptedToken, IERC20 _token, uint256 _duration, uint256 _cap) Timed(_duration) {
        acceptedToken = _acceptedToken;
        token = _token;
        // start timer
        _initTimed();
        _setCap(ud(_cap));
    }

    /**
     * @notice init function to  be called after deployment
     * @dev must be atomic in one deployment script
     *
     */
    function init() external override initializer {
        //deployer must approve token first
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), unwrap(cap));
        require(
            cap.eq(ud(IERC20(token).balanceOf(address(this)))), "BondingCurve: must send Token to the contract first"
        );
    }

    /**
     * @notice purchase token for accepted tokens
     * @param to address to sale token
     * @param amountIn amount of underlying accepted tokens input
     *  @return amountOut amount of token sale received
     *
     */
    function purchase(address to, uint256 amountIn)
        external
        payable
        virtual
        override
        whenNotPaused
        duringTime
        returns (UD60x18 amountOut)
    {
        require(msg.value == 0, "BondingCurve: unexpected ETH input");
        amountOut = _purchase(to, amountIn);

        SafeERC20.safeTransferFrom(acceptedToken, msg.sender, address(this), amountIn);
        SafeERC20.safeTransfer(token, to, unwrap(amountOut));

        return amountOut;
    }

    /**
     * @notice allocate held accepted ERC20 token
     * @param amount the amount quantity of underlying token  to allocate
     * @param to address destination
     *
     */
    function allocate(uint256 amount, address to) external virtual override onlyOwner afterTime {
        SafeERC20.safeTransfer(acceptedToken, to, amount);
        emit Allocate(msg.sender, ud(amount));
    }

    /**
     * @notice pause pausable function
     *
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice unpause pausable function
     *
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice returns how close to the cap we are
     *
     */
    function availableToSell() public view override returns (UD60x18) {
        return cap.sub(totalPurchased);
    }

    /**
     * @notice return current instantaneous bonding curve price
     * @return amountOut price reported
     * @dev just use only one helper function from LinearCurve
     *
     */
    function getCurrentPrice() external view virtual returns (UD60x18);

    /**
     * @notice return amount of token sale received after a bonding curve purchase
     * @param tokenAmountIn the amount of underlying used to purchase
     * @return balanceAmountOut the amount of sale token received
     * @dev retained poolBalance (i.e. after including the next set of added tokensupply) minus current poolBalance
     *
     */
    function calculatePurchaseAmountOut(UD60x18 tokenAmountIn) public view virtual returns (UD60x18);

    /**
     * @notice balance of accepted token the bonding curve
     * @return the amount of accepted token held in contract and ready to be allocated
     *
     */
    function reserveBalance() public view virtual override returns (UD60x18) {
        return ud(acceptedToken.balanceOf(address(this)));
    }

    function _purchase(address to, uint256 tokenAmountIn) internal returns (UD60x18 saleTokenAmountOut) {
        saleTokenAmountOut = calculatePurchaseAmountOut(ud(tokenAmountIn));

        require(gte(availableToSell(), saleTokenAmountOut), "BondingCurve: exceeds cap");
        _incrementTotalPurchased(saleTokenAmountOut);

        emit Purchase(to, ud(tokenAmountIn), saleTokenAmountOut);
        return saleTokenAmountOut;
    }

    function _incrementTotalPurchased(UD60x18 amount) internal {
        totalPurchased = totalPurchased.add(amount);
    }

    function _setCap(UD60x18 newCap) internal {
        if (isZero(newCap)) revert Errors.ZeroNumberNotAllowed();

        UD60x18 oldCap = cap;
        cap = newCap;

        emit CapUpdate(oldCap, newCap);
    }
}
