// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {YieldFlowFeeModel} from "../src/YieldFlowFeeModel.sol";

contract YieldFlowFeeModelTest is Test {
    YieldFlowFeeModel.Config internal config;
    YieldFlowFeeModelHarness internal harness;

    function setUp() public {
        harness = new YieldFlowFeeModelHarness();
        config = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 15_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });
    }

    function testBalancedSmallExitUsesBaseFee() public {
        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 0, lastUpdatedBlock: 0, lastFee: 0});

        uint24 fee = YieldFlowFeeModel.quoteFee(config, state, 10e18, true);

        assertEq(fee, 500);
    }

    function testWorseningExitPressureUsesHigherFee() public {
        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 120e18, lastUpdatedBlock: 0, lastFee: 0});

        uint24 fee = YieldFlowFeeModel.quoteFee(config, state, 20e18, true);

        assertEq(fee, 3_000);
    }

    function testRebalancingFlowUsesMinimumFee() public {
        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 120e18, lastUpdatedBlock: 0, lastFee: 0});

        uint24 fee = YieldFlowFeeModel.quoteFee(config, state, 20e18, false);

        assertEq(fee, 100);
    }

    function testLargeWorseningSwapIsCapped() public {
        YieldFlowFeeModel.Config memory capped = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 1_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });
        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 200e18, lastUpdatedBlock: 0, lastFee: 0});

        uint24 fee = YieldFlowFeeModel.quoteFee(capped, state, 300e18, true);

        assertEq(fee, 1_000);
    }

    function testNextPressureAddsExitAndSubtractsRebalance() public {
        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 50e18, lastUpdatedBlock: 0, lastFee: 0});

        int256 afterExit = YieldFlowFeeModel.nextPressure(state, 20e18, true);
        int256 afterRebalance = YieldFlowFeeModel.nextPressure(state, 20e18, false);

        assertEq(afterExit, 70e18);
        assertEq(afterRebalance, 30e18);
    }

    function testInvalidFeeConfigReverts() public {
        YieldFlowFeeModel.Config memory invalid = config;
        invalid.minFee = 600;
        invalid.baseFee = 500;

        YieldFlowFeeModel.FlowState memory state =
            YieldFlowFeeModel.FlowState({netExitPressure: 0, lastUpdatedBlock: 0, lastFee: 0});

        vm.expectRevert(YieldFlowFeeModel.InvalidFeeConfig.selector);
        harness.quoteFee(invalid, state, 1e18, true);
    }
}

contract YieldFlowFeeModelHarness {
    function quoteFee(
        YieldFlowFeeModel.Config memory config,
        YieldFlowFeeModel.FlowState memory state,
        uint256 amount,
        bool isExit
    ) external pure returns (uint24) {
        return YieldFlowFeeModel.quoteFee(config, state, amount, isExit);
    }
}
