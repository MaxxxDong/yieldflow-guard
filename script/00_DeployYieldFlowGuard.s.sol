// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {YieldFlowFeeModel} from "../src/YieldFlowFeeModel.sol";
import {YieldFlowGuardHook} from "../src/YieldFlowGuardHook.sol";

contract DeployYieldFlowGuard is Script {
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address internal constant X_LAYER_POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;

    function run() external returns (YieldFlowGuardHook hook) {
        address hookOwner = vm.envAddress("DEPLOYER_ADDRESS");
        YieldFlowFeeModel.Config memory config = YieldFlowFeeModel.Config({
            minFee: 100,
            baseFee: 500,
            maxFee: 15_000,
            imbalanceThreshold: 100e18,
            largeSwapThreshold: 250e18,
            imbalancePenalty: 2_500,
            largeSwapPenalty: 10_000
        });

        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG
        );

        bytes memory constructorArgs = abi.encode(IPoolManager(X_LAYER_POOL_MANAGER), config, hookOwner);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(YieldFlowGuardHook).creationCode, constructorArgs);

        vm.broadcast();
        hook = new YieldFlowGuardHook{salt: salt}(IPoolManager(X_LAYER_POOL_MANAGER), config, hookOwner);

        require(address(hook) == hookAddress, "YieldFlowGuard: hook address mismatch");
    }
}
