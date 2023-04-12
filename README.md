<h1> Bonding Curve Library</h1>


## 📚 What is it for ?

A bonding curve is a mathematical curve or an equation used to connect between token price and the token supply of an asset. 

A common use case is TVL bootstrapping or fund raising. The token ,at any time, allows to be automaticaly minted, or burned according to the prices defined by a smart contract.

This interoperates liquid, transparent and effienct market, because the function curve and relavant variables could be set to reflect the objective of the system.

Generally, a natural incentive structure is to encourage early adopters. The pricing function could be defined such that the token prices increase as more tokens supplys are minted.
This incentivises adopters to buy token early as it is cheaper in the early stages as the ecosystem grows.

This tutorial will cover invariant testing this mathamatic logic in Solidity using `Foundry invaraint testing`.

However, this guide is for educational purpose only. The code is'nt audited. Please do not use it in production.

Any other implementation for different cureve examples are welcomed!!


### Specification

In this tutorial, we'll use linear bonding curce, whose the general formula specified by:

> $( Price = f(supply) = m * supply + b)$

where 
1. `m` describes the slope 
2. `b` is the initial price when the token supply equals zero

In simple words, as the token is purchased, the token price also steady increase by according to `m` rate.

For the example in our unit testing implementation, we let:

1. `m` = 1.5 
2. `b` = 30

Then:

![Linear Curve](https://github.com/Ratimon/bonding-curves/blob/master/docs/LinearCurve.png)

$( Price = m * Supply + b)$

> $( Price = f(supply) = 1.5 * supply + 30)$

However, the token pricing in each purchase is not as simple as multiplying the current token price by the tokens amount being bought.

Instead, we will take the intregral of the bonding curve, such that the total price of the next set of token is calculated. We will illustrate this as in solidity code in the next section.

This implementation is one-sided, meaning that the buyer can only buy token, but they are not able to use the bought token to buy back those spent.

It is denominated in any ERC20 tokens. Simply put, the buyer purchases one ERC20 token with another ERC20 token.


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


> 💡 Note: Other commands for this tutorial can be found in [ `Makefile`](https://github.com/Ratimon/bonding-curves/blob/master/Makefile).

We ,for example, can run fuzzing campagin by the following command :

```sh
make invariant-LinearBondingCurve
```


### Exploring more !!!

> 💡 Note: We acknowledge, use, and inspire from the projects [PaulRBerg/prb-math](https://github.com/PaulRBerg/prb-math) and `Timed.sol` from [fei-protocol-core](https://github.com/fei-protocol/fei-protocol-core/blob/develop/contracts/utils/Timed.sol)