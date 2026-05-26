// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {YieldFlowDemoRouter} from "../src/YieldFlowDemoRouter.sol";

contract DeployDemoStack is Script {
    address internal constant X_LAYER_POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
    uint256 internal constant MINT_AMOUNT = 1_000_000e18;

    function run() external returns (MockERC20 usdg, MockERC20 stYusdg, YieldFlowDemoRouter demoRouter) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();
        usdg = new MockERC20("Demo USDG", "USDG", 18);
        stYusdg = new MockERC20("Static Yield USDG", "st-yUSDG", 18);
        demoRouter = new YieldFlowDemoRouter(IPoolManager(X_LAYER_POOL_MANAGER));

        usdg.mint(deployer, MINT_AMOUNT);
        stYusdg.mint(deployer, MINT_AMOUNT);

        usdg.approve(address(demoRouter), type(uint256).max);
        stYusdg.approve(address(demoRouter), type(uint256).max);
        vm.stopBroadcast();
    }
}
