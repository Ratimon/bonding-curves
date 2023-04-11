// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {powu, sqrt} from "@prb-math/ud60x18/Math.sol";
import {UD60x18, ud} from "@prb-math/UD60x18.sol";

/**
 * @notice abstract contract for calcuting curve
 * @dev functioncal components could be used in derived contract
 *
 */
contract LinearCurve {
    /**
     * @notice the curve slope
     * @dev refer to price = slope * currentTokenPurchased + initialPrice
     *
     */
    UD60x18 public immutable slope;

    /**
     * @notice the token price when there purchased token is zero
     * @dev refer to the instantaneous price = slope * currentTokenPurchased + initialPrice
     *
     */
    UD60x18 public immutable initialPrice;

    /**
     * @notice BondingCurve constructor
     * @param _slope slope for this bonding curve
     * @param _initialPrice initial price for this bonding curve
     *
     */
    constructor(uint256 _slope, uint256 _initialPrice) {
        slope = ud(_slope);
        initialPrice = ud(_initialPrice);
    }

    /**
     * @notice return instantaneous bonding curve price
     * @return the instantaneous price = slope * currentTokenPurchased + initialPrice
     *
     */
    function getLinearInstantaneousPrice(UD60x18 tokenSupply) public view returns (UD60x18) {
        return slope.mul(tokenSupply).add(initialPrice);
    }

    /**
     * @notice return the pool balance or the amount of the reserve currency at the given token supply
     * @param tokenSupply the token supply
     * @return the total token price reported
     * @dev The Integral of price regarding to tokensupply f(supply)
     * @dev : The integral: pool balance = y = f(x = currentTokenPurchased) =  slope/2 * (currentTokenPurchased)^2 + initialPrice * (currentTokenPurchased)
     *
     */
    function getPoolBalance(UD60x18 tokenSupply) public view returns (UD60x18) {
        return slope.mul(powu(tokenSupply, 2)).div(ud(2e18)).add(tokenSupply.mul(initialPrice));
    }

    /**
     * @notice return the token supply at the given pool balance
     * @param poolBalance the pool balance
     * @return the token supply reported
     * @dev The Inverse of the integral of price regarding to tokensupply
     * @dev The Inverse : token supply = x = f-1(y = poolBalance) =  (-b ± sqrt(b^2 + 2my)) / m
     * @dev as token supply (x) can not be negative so f-1(y) = (-b + sqrt(b^2 + 2my)) / m
     * @dev where m = slope and b = initial price
     *
     *
     */
    function getTokenSupply(UD60x18 poolBalance) public view returns (UD60x18) {
        return (sqrt((initialPrice.powu(2)).add(ud(2e18).mul(slope).mul(poolBalance))).sub(initialPrice)).div(slope);
    }
}
