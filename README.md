<h1> Bonding Curve Library</h1>


## 📚 What is it for ?

A bonding curve is a mathematical curve or equation used to connect the token price and the token supply of an asset. 

A common use case is TVL bootstrapping or fund raising. The token, at any time, can be automatically minted or burned according to the prices defined by a smart contract.

This interoperates liquid, transparent, and efficient market, because the function curve and relevant variables could be set to reflect the objective of the system.

Generally, a natural incentive structure is to encourage early adopters. The pricing function could be defined such that the token prices increase as more tokens supplys are minted. This incentivizes adopters to buy tokens early as they are cheaper in the early stages as the ecosystem grows.

The code is not audited. Please do not use it in production.

Any other implementations or examples for different curves (such as polynomial, logarithmic, or a mix of those) are welcomed!

### Quick Start & Architecture

Our project is structured as following:

```
.
├── Makefile
├── lib
│   ├── forge-std
│   ├── openzeppelin-contracts
│   ├── prb-math
│   └── solmate
├── script
├── src
│   ├── bondingcurves
│   │   ├── BondingCurve.sol
│   │   └── IBondingCurve.sol
│   ├── examples
│   │   └── LinearBondingCurve.sol
│   ├── interfaces
│   ├── mocks
│   ├── pricings
│   │   └── LinearCurve.sol
│   ├── shared
│   └── utils
│       └── Timed.sol
└── test
    ├── invariant
    ├── unit
    └── utils
```


> 💡 Note: commands can be found in [ `Makefile`](https://github.com/Ratimon/bonding-curves/blob/master/Makefile).

We ,for example, can run fuzzing campagin by the following command :

```sh
make invariant-LinearBondingCurve
```


### Specification

In this repository, we implement linear bonding curce, whose the general formula specified by:

> $( Price = f(supply) = m * supply + b)$

where 
1. `m` describes the slope.
2. `b` is the initial price when the token supply equals zero.

In simple words, as the token is purchased, the token price also steadily increase by `m` rate.

For the example in our unit testing implementation, we let:

1. `m` = 1.5 
2. `b` = 30

Then:

![Linear Curve](https://github.com/Ratimon/bonding-curves/blob/master/docs/LinearCurve.png)

> $( Price = f(supply) = 1.5 * supply + 30)$

However, the token pricing in each purchase is not as simple as multiplying the current token price by the number of tokens being bought.

Instead, we will take the integral of the bonding curve, such that the total price of the next set of tokens is calculated. The implementation in solidity code is in [ `LinearCurve.sol`](https://github.com/Ratimon/bonding-curves/blob/master/src/pricings/LinearCurve.sol) as follows.

```solidity

    /** ... */
    contract LinearCurve {

        /** ... */

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

        /** ... */
    
    }

```

This implementation is one-sided, meaning that the buyer can only buy tokens, but they are not able to use the bought tokens to buy back the ones they have already spent.

It is denominated in any ERC20 token. Simply put, the buyer purchases one ERC20 token with another ERC20 token.


### Exploring more !!!

> 💡 Note: We acknowledge, use, and get inspiration from the projects [PaulRBerg/prb-math](https://github.com/PaulRBerg/prb-math) and `Timed.sol` from [fei-protocol-core](https://github.com/fei-protocol/fei-protocol-core/blob/develop/contracts/utils/Timed.sol)