// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 internal token;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new MockERC20("Static Yield USDG", "st-yUSDG", 18);
    }

    function testMintAndTransfer() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        bool ok = token.transfer(bob, 40e18);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(bob), 40e18);
    }

    function testTransferFromUsesAllowance() public {
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.approve(address(this), 25e18);

        bool ok = token.transferFrom(alice, bob, 25e18);

        assertTrue(ok);
        assertEq(token.allowance(alice, address(this)), 0);
        assertEq(token.balanceOf(bob), 25e18);
    }

    function testBalanceDoesNotChangeAcrossBlocksWithoutTransfer() public {
        token.mint(alice, 100e18);

        vm.roll(block.number + 500);
        vm.warp(block.timestamp + 30 days);

        assertEq(token.balanceOf(alice), 100e18);
    }
}
