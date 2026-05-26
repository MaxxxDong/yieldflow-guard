// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {YieldFlowDemoRouter} from "../src/YieldFlowDemoRouter.sol";
import {YieldFlowGuardHook} from "../src/YieldFlowGuardHook.sol";

contract CreateDemoPoolAndLiquidity is Script {
    using PoolIdLibrary for PoolKey;

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    int24 internal constant TICK_SPACING = 60;
    uint128 internal constant LIQUIDITY_AMOUNT = 10_000e18;

    function run() external returns (bytes32 poolId, bool yieldTokenIsCurrency0) {
        address usdg = vm.envAddress("USDG_ADDRESS");
        address stYusdg = vm.envAddress("ST_YUSDG_ADDRESS");
        address hook = vm.envAddress("YIELD_FLOW_GUARD_HOOK");
        YieldFlowDemoRouter demoRouter = YieldFlowDemoRouter(payable(vm.envAddress("DEMO_ROUTER_ADDRESS")));

        (Currency currency0, Currency currency1) = _sortCurrencies(usdg, stYusdg);
        yieldTokenIsCurrency0 = Currency.unwrap(currency0) == stYusdg;

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });

        int24 tickLower = TickMath.minUsableTick(TICK_SPACING);
        int24 tickUpper = TickMath.maxUsableTick(TICK_SPACING);
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(LIQUIDITY_AMOUNT)),
            salt: bytes32(0)
        });

        vm.startBroadcast();
        IERC20Minimal(usdg).approve(address(demoRouter), type(uint256).max);
        IERC20Minimal(stYusdg).approve(address(demoRouter), type(uint256).max);
        YieldFlowGuardHook(hook).configurePool(key, yieldTokenIsCurrency0);
        demoRouter.initialize(key, SQRT_PRICE_1_1);
        demoRouter.modifyLiquidity(key, params, "");
        vm.stopBroadcast();

        poolId = PoolId.unwrap(key.toId());
    }

    function _sortCurrencies(address usdg, address stYusdg)
        internal
        pure
        returns (Currency currency0, Currency currency1)
    {
        require(usdg != stYusdg, "YieldFlow: duplicate tokens");
        (address token0, address token1) = usdg < stYusdg ? (usdg, stYusdg) : (stYusdg, usdg);
        return (Currency.wrap(token0), Currency.wrap(token1));
    }
}
