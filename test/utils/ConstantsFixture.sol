// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Test} from "@forge-std/Test.sol";

contract ConstantsFixture is Test {
    uint256 public staticTime;

    address public deployer;
    address public alice = address(11);
    address public bob = address(12);
    address public carol = address(13);
    address public dave = address(14);

    function setUp() public virtual {
        staticTime = block.timestamp;
        deployer = msg.sender;
        vm.label(deployer, "Deployer");

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        deal(alice, 1 ether);
        deal(bob, 1 ether);
    }
}
