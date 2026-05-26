// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {YieldFlowDemoRouter} from "../src/YieldFlowDemoRouter.sol";
import {YieldFlowGuardHook} from "../src/YieldFlowGuardHook.sol";

contract RunDemoSwaps is Script {
    using PoolIdLibrary for PoolKey;

    int24 internal constant TICK_SPACING = 60;

    function run() external returns (int256 netExitPressure, uint256 lastUpdatedBlock, uint24 lastFee) {
        address usdg = vm.envAddress("USDG_ADDRESS");
        address stYusdg = vm.envAddress("ST_YUSDG_ADDRESS");
        address hook = vm.envAddress("YIELD_FLOW_GUARD_HOOK");
        YieldFlowDemoRouter demoRouter = YieldFlowDemoRouter(payable(vm.envAddress("DEMO_ROUTER_ADDRESS")));

        (Currency currency0, Currency currency1) = _sortCurrencies(usdg, stYusdg);
        bool yieldTokenIsCurrency0 = Currency.unwrap(currency0) == stYusdg;

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });

        bool exitZeroForOne = yieldTokenIsCurrency0;
        bool rebalanceZeroForOne = !exitZeroForOne;

        vm.startBroadcast();
        IERC20Minimal(usdg).approve(address(demoRouter), type(uint256).max);
        IERC20Minimal(stYusdg).approve(address(demoRouter), type(uint256).max);

        demoRouter.swap(key, _exactInputParams(exitZeroForOne, 10e18), "");
        demoRouter.swap(key, _exactInputParams(exitZeroForOne, 120e18), "");
        demoRouter.swap(key, _exactInputParams(rebalanceZeroForOne, 20e18), "");
        vm.stopBroadcast();

        (netExitPressure, lastUpdatedBlock, lastFee) = YieldFlowGuardHook(hook).flowStates(key.toId());
    }

    function _exactInputParams(bool zeroForOne, uint256 amountIn) internal pure returns (SwapParams memory) {
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        return
            SwapParams({
                zeroForOne: zeroForOne, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: sqrtPriceLimitX96
            });
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
