// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseOverrideFee} from "@openzeppelin/uniswap-hooks/src/fee/BaseOverrideFee.sol";
import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {YieldFlowFeeModel} from "./YieldFlowFeeModel.sol";

contract YieldFlowGuardHook is BaseOverrideFee {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using YieldFlowFeeModel for YieldFlowFeeModel.Config;

    error NotOwner();
    error InvalidOwner();
    error PoolNotConfigured();
    error PoolMustUseDynamicFee();
    error InvalidAmountSpecified();

    struct PoolConfig {
        bool enabled;
        bool yieldTokenIsCurrency0;
    }

    address public immutable owner;
    YieldFlowFeeModel.Config public feeConfig;

    mapping(PoolId poolId => PoolConfig config) public poolConfigs;
    mapping(PoolId poolId => YieldFlowFeeModel.FlowState state) public flowStates;

    event PoolConfigured(bytes32 indexed poolId, address yieldToken, address baseToken);
    event FeeQuoted(bytes32 indexed poolId, bool zeroForOne, int256 netExitPressure, uint24 fee);
    event FlowObserved(bytes32 indexed poolId, int256 yieldDelta, int256 baseDelta, int256 newNetExitPressure);
    event LiquidityObserved(bytes32 indexed poolId, address indexed sender, int256 yieldDelta, int256 baseDelta);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(IPoolManager manager, YieldFlowFeeModel.Config memory config, address owner_) BaseHook(manager) {
        config.validate();
        if (owner_ == address(0)) revert InvalidOwner();
        owner = owner_;
        feeConfig = config;
    }

    function configurePool(PoolKey calldata key, bool yieldTokenIsCurrency0) external onlyOwner {
        if (key.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert PoolMustUseDynamicFee();
        }

        PoolId poolId = key.toId();
        poolConfigs[poolId] = PoolConfig({enabled: true, yieldTokenIsCurrency0: yieldTokenIsCurrency0});

        address yieldToken = yieldTokenIsCurrency0 ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address baseToken = yieldTokenIsCurrency0 ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);

        emit PoolConfigured(PoolId.unwrap(poolId), yieldToken, baseToken);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _getFee(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (uint24)
    {
        PoolId poolId = key.toId();
        PoolConfig memory poolConfig = poolConfigs[poolId];
        if (!poolConfig.enabled) revert PoolNotConfigured();

        uint256 absAmount = _absAmountSpecified(params.amountSpecified);
        bool isExitFlow = _isExitFlow(poolConfig, params.zeroForOne);
        YieldFlowFeeModel.FlowState memory state = flowStates[poolId];

        uint24 fee = YieldFlowFeeModel.quoteFee(feeConfig, state, absAmount, isExitFlow);
        emit FeeQuoted(PoolId.unwrap(poolId), params.zeroForOne, state.netExitPressure, fee);

        return fee;
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        PoolId poolId = key.toId();
        PoolConfig memory poolConfig = poolConfigs[poolId];
        if (!poolConfig.enabled) revert PoolNotConfigured();

        uint256 absAmount = _absAmountSpecified(params.amountSpecified);
        bool isExitFlow = _isExitFlow(poolConfig, params.zeroForOne);
        YieldFlowFeeModel.FlowState storage state = flowStates[poolId];

        uint24 fee = YieldFlowFeeModel.quoteFee(feeConfig, state, absAmount, isExitFlow);
        state.netExitPressure = YieldFlowFeeModel.nextPressure(state, absAmount, isExitFlow);
        state.lastUpdatedBlock = block.number;
        state.lastFee = fee;

        (int256 yieldDelta, int256 baseDelta) = _splitDelta(poolConfig, delta);
        emit FlowObserved(PoolId.unwrap(poolId), yieldDelta, baseDelta, state.netExitPressure);

        return (this.afterSwap.selector, 0);
    }

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        PoolConfig memory poolConfig = poolConfigs[poolId];
        if (!poolConfig.enabled) revert PoolNotConfigured();

        (int256 yieldDelta, int256 baseDelta) = _splitDelta(poolConfig, delta);
        emit LiquidityObserved(PoolId.unwrap(poolId), sender, yieldDelta, baseDelta);

        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _isExitFlow(PoolConfig memory poolConfig, bool zeroForOne) internal pure returns (bool) {
        return poolConfig.yieldTokenIsCurrency0 ? zeroForOne : !zeroForOne;
    }

    function _absAmountSpecified(int256 amountSpecified) internal pure returns (uint256) {
        if (amountSpecified == 0 || amountSpecified == type(int256).min) {
            revert InvalidAmountSpecified();
        }

        return YieldFlowFeeModel.absoluteAmount(amountSpecified);
    }

    function _splitDelta(PoolConfig memory poolConfig, BalanceDelta delta)
        internal
        pure
        returns (int256 yieldDelta, int256 baseDelta)
    {
        int256 amount0 = int256(delta.amount0());
        int256 amount1 = int256(delta.amount1());

        if (poolConfig.yieldTokenIsCurrency0) {
            return (amount0, amount1);
        }

        return (amount1, amount0);
    }
}
