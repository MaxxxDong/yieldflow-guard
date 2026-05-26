// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library YieldFlowFeeModel {
    uint24 internal constant MAX_UNISWAP_LP_FEE = 1_000_000;

    error InvalidFeeConfig();
    error InvalidAmount();

    struct Config {
        uint24 minFee;
        uint24 baseFee;
        uint24 maxFee;
        uint256 imbalanceThreshold;
        uint256 largeSwapThreshold;
        uint24 imbalancePenalty;
        uint24 largeSwapPenalty;
    }

    struct FlowState {
        int256 netExitPressure;
        uint256 lastUpdatedBlock;
        uint24 lastFee;
    }

    function quoteFee(Config memory config, FlowState memory state, uint256 amount, bool isExit)
        internal
        pure
        returns (uint24)
    {
        validate(config);

        int256 projectedPressure = nextPressure(state, amount, isExit);
        uint256 beforeAbs = abs(state.netExitPressure);
        uint256 afterAbs = abs(projectedPressure);

        if (afterAbs < beforeAbs) {
            return config.minFee;
        }

        uint256 fee = config.baseFee;

        if (afterAbs >= config.imbalanceThreshold) {
            fee += config.imbalancePenalty;
        }

        if (amount >= config.largeSwapThreshold) {
            fee += config.largeSwapPenalty;
        }

        if (fee > config.maxFee) {
            return config.maxFee;
        }

        return uint24(fee);
    }

    function nextPressure(FlowState memory state, uint256 amount, bool isExit) internal pure returns (int256) {
        if (amount > uint256(type(int256).max)) revert InvalidAmount();

        int256 signedAmount = int256(amount);
        return isExit ? state.netExitPressure + signedAmount : state.netExitPressure - signedAmount;
    }

    function absoluteAmount(int256 amountSpecified) internal pure returns (uint256) {
        return abs(amountSpecified);
    }

    function abs(int256 value) internal pure returns (uint256) {
        if (value == type(int256).min) revert InvalidAmount();
        return uint256(value < 0 ? -value : value);
    }

    function validate(Config memory config) internal pure {
        bool invalid = config.minFee > config.baseFee || config.baseFee > config.maxFee
            || config.maxFee > MAX_UNISWAP_LP_FEE || config.imbalanceThreshold == 0 || config.largeSwapThreshold == 0;

        if (invalid) revert InvalidFeeConfig();
    }
}
