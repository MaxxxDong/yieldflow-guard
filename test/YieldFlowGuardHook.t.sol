// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/libraries/EasyPosm.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {YieldFlowDemoRouter} from "../src/YieldFlowDemoRouter.sol";
import {YieldFlowFeeModel} from "../src/YieldFlowFeeModel.sol";
import {YieldFlowGuardHook} from "../src/YieldFlowGuardHook.sol";

contract YieldFlowGuardHookHarness is YieldFlowGuardHook {
    constructor(IPoolManager manager, YieldFlowFeeModel.Config memory config, address owner_)
        YieldFlowGuardHook(manager, config, owner_)
    {}

    function exposedGetFee(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (uint24)
    {
        return _getFee(sender, key, params, hookData);
    }

    function exposedAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }

    function exposedAfterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        return _afterAddLiquidity(sender, key, params, delta, feesAccrued, hookData);
    }
}

contract YieldFlowGuardHookTest is Test {
    using PoolIdLibrary for PoolKey;

    YieldFlowGuardHookHarness internal hook;
    PoolKey internal key;
    PoolId internal poolId;

    function setUp() public {
        YieldFlowFeeModel.Config memory config = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 15_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });

        address flags = address(
            uint160(
                Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144)
        );

        deployCodeTo(
            "YieldFlowGuardHook.t.sol:YieldFlowGuardHookHarness",
            abi.encode(IPoolManager(address(0xBEEF)), config, address(this)),
            flags
        );

        hook = YieldFlowGuardHookHarness(flags);

        key = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = key.toId();
        hook.configurePool(key, true);
    }

    function testGetHookPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();

        assertTrue(permissions.afterInitialize);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeSwapReturnDelta);
        assertFalse(permissions.afterSwapReturnDelta);
    }

    function testOwnerSetFromConstructor() public view {
        assertEq(hook.owner(), address(this));
    }

    function testConfigurePoolRevertsForNonOwner() public {
        PoolKey memory otherKey = PoolKey({
            currency0: Currency.wrap(address(0x3000)),
            currency1: Currency.wrap(address(0x4000)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        vm.prank(address(0xABCD));
        vm.expectRevert(YieldFlowGuardHook.NotOwner.selector);
        hook.configurePool(otherKey, true);
    }

    function testUnconfiguredPoolReverts() public {
        PoolKey memory otherKey = PoolKey({
            currency0: Currency.wrap(address(0x3000)),
            currency1: Currency.wrap(address(0x4000)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        SwapParams memory params = SwapParams({zeroForOne: true, amountSpecified: -10e18, sqrtPriceLimitX96: 0});

        vm.expectRevert(YieldFlowGuardHook.PoolNotConfigured.selector);
        hook.exposedGetFee(address(this), otherKey, params, "");
    }

    function testBalancedExitQuotesBaseFee() public {
        SwapParams memory params = SwapParams({zeroForOne: true, amountSpecified: -10e18, sqrtPriceLimitX96: 0});

        uint24 fee = hook.exposedGetFee(address(this), key, params, "");

        assertEq(fee, 500);
    }

    function testAfterSwapUpdatesExitPressure() public {
        SwapParams memory params = SwapParams({zeroForOne: true, amountSpecified: -10e18, sqrtPriceLimitX96: 0});
        BalanceDelta delta = toBalanceDelta(10e18, -9e18);

        hook.exposedAfterSwap(address(this), key, params, delta, "");

        (int256 pressure, uint256 lastUpdatedBlock, uint24 lastFee) = hook.flowStates(poolId);
        assertEq(pressure, 10e18);
        assertEq(lastUpdatedBlock, block.number);
        assertEq(lastFee, 500);
    }

    function testWorseningAfterPressureQuotesHigherFee() public {
        SwapParams memory first = SwapParams({zeroForOne: true, amountSpecified: -120e18, sqrtPriceLimitX96: 0});
        hook.exposedAfterSwap(address(this), key, first, toBalanceDelta(120e18, -118e18), "");

        SwapParams memory second = SwapParams({zeroForOne: true, amountSpecified: -20e18, sqrtPriceLimitX96: 0});
        uint24 fee = hook.exposedGetFee(address(this), key, second, "");

        assertEq(fee, 3_000);
    }

    function testRebalancingAfterPressureQuotesMinFee() public {
        SwapParams memory first = SwapParams({zeroForOne: true, amountSpecified: -120e18, sqrtPriceLimitX96: 0});
        hook.exposedAfterSwap(address(this), key, first, toBalanceDelta(120e18, -118e18), "");

        SwapParams memory rebalance = SwapParams({zeroForOne: false, amountSpecified: -20e18, sqrtPriceLimitX96: 0});
        uint24 fee = hook.exposedGetFee(address(this), key, rebalance, "");

        assertEq(fee, 100);
    }
}

contract YieldFlowGuardHookIntegrationTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;

    Currency internal currency0;
    Currency internal currency1;
    PoolKey internal poolKey;
    PoolId internal poolId;
    YieldFlowGuardHook internal hook;

    function setUp() public {
        deployArtifactsAndLabel();
        (currency0, currency1) = deployCurrencyPair();

        YieldFlowFeeModel.Config memory config = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 15_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });

        address flags = address(
            uint160(
                Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x5555 << 144)
        );

        deployCodeTo("YieldFlowGuardHook.sol:YieldFlowGuardHook", abi.encode(poolManager, config, address(this)), flags);
        hook = YieldFlowGuardHook(flags);

        poolKey = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 60, IHooks(hook));
        poolId = poolKey.toId();

        hook.configurePool(poolKey, true);
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);
        uint128 liquidityAmount = 100e18;
        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
    }

    function testV4SwapTriggersFeeAndFlowEvents() public {
        BalanceDelta firstSwap = swapRouter.swapExactTokensForTokens({
            amountIn: 10e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertLt(firstSwap.amount0(), 0);

        (int256 pressureAfterFirst,, uint24 lastFeeAfterFirst) = hook.flowStates(poolId);
        assertEq(pressureAfterFirst, 10e18);
        assertEq(lastFeeAfterFirst, 500);

        BalanceDelta secondSwap = swapRouter.swapExactTokensForTokens({
            amountIn: 20e18,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertLt(secondSwap.amount1(), 0);

        (int256 pressureAfterSecond,,) = hook.flowStates(poolId);
        assertEq(pressureAfterSecond, -10e18);
    }
}

contract YieldFlowDemoRouterIntegrationTest is BaseTest {
    using PoolIdLibrary for PoolKey;

    Currency internal currency0;
    Currency internal currency1;
    PoolKey internal poolKey;
    PoolId internal poolId;
    YieldFlowGuardHook internal hook;
    YieldFlowDemoRouter internal demoRouter;

    function setUp() public {
        deployArtifactsAndLabel();
        (currency0, currency1) = deployCurrencyPair();

        YieldFlowFeeModel.Config memory config = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 15_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });

        address flags = address(
            uint160(
                Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x6666 << 144)
        );

        deployCodeTo("YieldFlowGuardHook.sol:YieldFlowGuardHook", abi.encode(poolManager, config, address(this)), flags);
        hook = YieldFlowGuardHook(flags);
        demoRouter = new YieldFlowDemoRouter(poolManager);

        poolKey = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 60, IHooks(hook));
        poolId = poolKey.toId();

        IERC20Minimal(Currency.unwrap(currency0)).approve(address(demoRouter), type(uint256).max);
        IERC20Minimal(Currency.unwrap(currency1)).approve(address(demoRouter), type(uint256).max);

        hook.configurePool(poolKey, true);
        demoRouter.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TickMath.minUsableTick(poolKey.tickSpacing),
            tickUpper: TickMath.maxUsableTick(poolKey.tickSpacing),
            liquidityDelta: 10_000e18,
            salt: bytes32(0)
        });
        demoRouter.modifyLiquidity(poolKey, params, Constants.ZERO_BYTES);
    }

    function testDemoRouterSwapsTriggerHookPressure() public {
        demoRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -10e18, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            Constants.ZERO_BYTES
        );
        demoRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -120e18, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            Constants.ZERO_BYTES
        );
        demoRouter.swap(
            poolKey,
            SwapParams({zeroForOne: false, amountSpecified: -20e18, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1}),
            Constants.ZERO_BYTES
        );

        (int256 pressure, uint256 lastUpdatedBlock, uint24 lastFee) = hook.flowStates(poolId);
        assertEq(pressure, 110e18);
        assertEq(lastUpdatedBlock, block.number);
        assertEq(lastFee, 100);
    }
}
