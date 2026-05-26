# YieldFlow Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deployable Uniswap v4 Hook that dynamically prices exit pressure for `static yield position / base token` pools on X Layer.

**Architecture:** Use the Uniswap Foundation v4-template as the project scaffold, OpenZeppelin `BaseOverrideFee` for per-swap LP fee overrides, a small pure fee-model library for deterministic tests, and a Hook contract that stores per-pool exit-pressure state. Keep Aave out of the P0 contract path; use mock static yield tokens for demo and document raw aToken risk.

**Tech Stack:** Solidity 0.8.30, Foundry stable, Uniswap v4-core/v4-periphery via v4-template, OpenZeppelin uniswap-hooks, forge-std.

---

## File Structure

- Create: `yieldflow-guard/foundry.toml` - Foundry config copied from v4-template and kept project-local.
- Create: `yieldflow-guard/remappings.txt` - v4-template remappings for v4-core, v4-periphery, OpenZeppelin hooks, forge-std.
- Create: `yieldflow-guard/src/YieldFlowFeeModel.sol` - pure fee math and pressure accounting.
- Create: `yieldflow-guard/src/YieldFlowGuardHook.sol` - Uniswap v4 Hook, pool configuration, fee override, flow events.
- Create: `yieldflow-guard/src/mocks/MockERC20.sol` - simple fixed-supply behavior mock, no rebasing.
- Create: `yieldflow-guard/test/YieldFlowFeeModel.t.sol` - pure unit tests for fee behavior.
- Create: `yieldflow-guard/test/MockERC20.t.sol` - mock token behavior tests.
- Create: `yieldflow-guard/test/YieldFlowGuardHook.t.sol` - hook tests with v4-template `BaseTest`.
- Create: `yieldflow-guard/script/00_DeployYieldFlowGuard.s.sol` - mines and deploys hook with correct address flags.
- Modify: `yieldflow-guard/README.md` - add build/test/deploy commands, evidence table, demo checklist.
- Modify: `yieldflow-guard/docs/design.md` - add implementation notes discovered during build only if they change the design.

## External Constraints

- Current local PowerShell does not have `forge`, `cast`, or `anvil` on PATH.
- Foundry official installer currently requires Git Bash or WSL on Windows because `foundryup` does not support PowerShell or Cmd.
- Network access is needed for `git clone` and `forge install`.
- X Layer v4 PoolManager address from Uniswap deployments: `0x360e68faccca8ca495c1b759fd9eee466db9fb32`.

---

### Task 1: Bootstrap v4-template Foundry Project

**Files:**
- Create: `yieldflow-guard/foundry.toml`
- Create: `yieldflow-guard/remappings.txt`
- Create via template copy: `yieldflow-guard/test/utils/**`
- Create via template copy: `yieldflow-guard/script/**`

- [ ] **Step 1: Verify Foundry toolchain**

Run from the repository root:

```powershell
forge --version
cast --version
anvil --version
```

Expected on this machine before setup: PowerShell reports the commands are not recognized.

- [ ] **Step 2: Install Foundry in Git Bash or WSL**

Run in Git Bash or WSL, not PowerShell:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version
cast --version
anvil --version
```

Expected: all three tools print stable Foundry versions.

- [ ] **Step 3: Import v4-template scaffold into a temporary directory**

Run:

```powershell
git clone https://github.com/uniswapfoundation/v4-template.git .v4-template
```

Expected: `.v4-template` contains `src/Counter.sol`, `test/Counter.t.sol`, `test/utils`, `script`, `foundry.toml`, and `remappings.txt`.

- [ ] **Step 4: Copy only scaffold files needed by this project**

Run:

```powershell
Copy-Item -LiteralPath .v4-template\foundry.toml -Destination .\foundry.toml
Copy-Item -LiteralPath .v4-template\remappings.txt -Destination .\remappings.txt
New-Item -ItemType Directory -Force -Path .\test | Out-Null
Copy-Item -Recurse -Force -LiteralPath .v4-template\test\utils -Destination .\test\utils
Copy-Item -Recurse -Force -LiteralPath .v4-template\script -Destination .\script
```

Expected: project has v4-template config, test helpers, and scripts, without importing the sample `Counter.sol`.

- [ ] **Step 5: Install dependencies**

Run:

```powershell
forge install
```

Expected: `lib/uniswap-hooks`, `lib/forge-std`, and nested v4 dependencies are present.

- [ ] **Step 6: Commit scaffold**

Run:

```powershell
git add yieldflow-guard/foundry.toml yieldflow-guard/remappings.txt yieldflow-guard/test/utils yieldflow-guard/script yieldflow-guard/lib
git commit -m "chore: scaffold YieldFlow Guard v4 project"
```

Expected: a focused commit containing only project-local v4 scaffold files.

---

### Task 2: Implement Fee Model With TDD

**Files:**
- Create: `yieldflow-guard/test/YieldFlowFeeModel.t.sol`
- Create: `yieldflow-guard/src/YieldFlowFeeModel.sol`

- [ ] **Step 1: Write failing tests**

Create `yieldflow-guard/test/YieldFlowFeeModel.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {YieldFlowFeeModel} from "../src/YieldFlowFeeModel.sol";

contract YieldFlowFeeModelTest is Test {
    YieldFlowFeeModel.Config internal config;

    function setUp() public {
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
        YieldFlowFeeModel.quoteFee(invalid, state, 1e18, true);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
forge test --match-contract YieldFlowFeeModelTest -vv
```

Expected: FAIL because `src/YieldFlowFeeModel.sol` does not exist.

- [ ] **Step 3: Implement fee model**

Create `yieldflow-guard/src/YieldFlowFeeModel.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library YieldFlowFeeModel {
    error InvalidFeeConfig();
    error AmountTooLarge();

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

    function validate(Config memory config) internal pure {
        if (config.minFee > config.baseFee || config.baseFee > config.maxFee) {
            revert InvalidFeeConfig();
        }
        if (config.maxFee > 1_000_000) {
            revert InvalidFeeConfig();
        }
        if (config.imbalanceThreshold == 0 || config.largeSwapThreshold == 0) {
            revert InvalidFeeConfig();
        }
    }

    function quoteFee(
        Config memory config,
        FlowState memory state,
        uint256 absAmount,
        bool isExitFlow
    ) internal pure returns (uint24) {
        validate(config);

        int256 pressureAfter = nextPressure(state, absAmount, isExitFlow);
        uint256 beforeAbs = abs(state.netExitPressure);
        uint256 afterAbs = abs(pressureAfter);

        if (afterAbs < beforeAbs) {
            return config.minFee;
        }

        uint256 fee = config.baseFee;

        if (afterAbs >= config.imbalanceThreshold) {
            fee += config.imbalancePenalty;
        }

        if (absAmount >= config.largeSwapThreshold) {
            fee += config.largeSwapPenalty;
        }

        if (fee > config.maxFee) {
            return config.maxFee;
        }

        if (fee < config.minFee) {
            return config.minFee;
        }

        return uint24(fee);
    }

    function nextPressure(FlowState memory state, uint256 absAmount, bool isExitFlow)
        internal
        pure
        returns (int256)
    {
        if (absAmount > uint256(type(int256).max)) {
            revert AmountTooLarge();
        }

        int256 signedAmount = int256(absAmount);
        return isExitFlow ? state.netExitPressure + signedAmount : state.netExitPressure - signedAmount;
    }

    function abs(int256 value) internal pure returns (uint256) {
        if (value == type(int256).min) {
            revert AmountTooLarge();
        }

        return uint256(value < 0 ? -value : value);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
forge test --match-contract YieldFlowFeeModelTest -vv
```

Expected: PASS, six tests passing.

- [ ] **Step 5: Commit fee model**

Run:

```powershell
git add yieldflow-guard/src/YieldFlowFeeModel.sol yieldflow-guard/test/YieldFlowFeeModel.t.sol
git commit -m "feat: add YieldFlow fee model"
```

Expected: focused commit with pure fee model and tests.

---

### Task 3: Add Mock Static Yield Token

**Files:**
- Create: `yieldflow-guard/src/mocks/MockERC20.sol`
- Create: `yieldflow-guard/test/MockERC20.t.sol`

- [ ] **Step 1: Write failing tests**

Create `yieldflow-guard/test/MockERC20.t.sol`:

```solidity
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
forge test --match-contract MockERC20Test -vv
```

Expected: FAIL because `src/mocks/MockERC20.sol` does not exist.

- [ ] **Step 3: Implement mock token**

Create `yieldflow-guard/src/mocks/MockERC20.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "MockERC20: insufficient allowance");

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "MockERC20: transfer to zero");
        require(balanceOf[from] >= amount, "MockERC20: insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
forge test --match-contract MockERC20Test -vv
```

Expected: PASS, three tests passing.

- [ ] **Step 5: Commit mock token**

Run:

```powershell
git add yieldflow-guard/src/mocks/MockERC20.sol yieldflow-guard/test/MockERC20.t.sol
git commit -m "test: add static yield token mock"
```

Expected: focused commit with mock token and tests.

---

### Task 4: Implement YieldFlow Guard Hook

**Files:**
- Create: `yieldflow-guard/src/YieldFlowGuardHook.sol`
- Create: `yieldflow-guard/test/YieldFlowGuardHook.t.sol`

- [ ] **Step 1: Write failing hook tests**

Create `yieldflow-guard/test/YieldFlowGuardHook.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {YieldFlowFeeModel} from "../src/YieldFlowFeeModel.sol";
import {YieldFlowGuardHook} from "../src/YieldFlowGuardHook.sol";

contract YieldFlowGuardHookHarness is YieldFlowGuardHook {
    constructor(IPoolManager manager, YieldFlowFeeModel.Config memory config) YieldFlowGuardHook(manager, config) {}

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
            abi.encode(IPoolManager(address(0xBEEF)), config),
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
        assertEq(lastFee, 0);
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
forge test --match-contract YieldFlowGuardHookTest -vv
```

Expected: FAIL because `src/YieldFlowGuardHook.sol` does not exist.

- [ ] **Step 3: Implement hook contract**

Create `yieldflow-guard/src/YieldFlowGuardHook.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseOverrideFee} from "@openzeppelin/uniswap-hooks/src/fee/BaseOverrideFee.sol";
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

    constructor(IPoolManager manager, YieldFlowFeeModel.Config memory config) BaseOverrideFee(manager) {
        config.validate();
        owner = msg.sender;
        feeConfig = config;
    }

    function configurePool(PoolKey calldata key, bool yieldTokenIsCurrency0) external onlyOwner {
        if (key.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert PoolMustUseDynamicFee();
        }

        PoolId poolId = key.toId();
        poolConfigs[poolId] = PoolConfig({enabled: true, yieldTokenIsCurrency0: yieldTokenIsCurrency0});

        address yieldToken =
            yieldTokenIsCurrency0 ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address baseToken =
            yieldTokenIsCurrency0 ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);

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

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        PoolConfig memory poolConfig = poolConfigs[poolId];
        if (!poolConfig.enabled) revert PoolNotConfigured();

        uint256 absAmount = _absAmountSpecified(params.amountSpecified);
        bool isExitFlow = _isExitFlow(poolConfig, params.zeroForOne);
        YieldFlowFeeModel.FlowState storage state = flowStates[poolId];

        state.netExitPressure = YieldFlowFeeModel.nextPressure(state, absAmount, isExitFlow);
        state.lastUpdatedBlock = block.number;

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

        return uint256(amountSpecified < 0 ? -amountSpecified : amountSpecified);
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
```

- [ ] **Step 4: Run hook tests**

Run:

```powershell
forge test --match-contract YieldFlowGuardHookTest -vv
```

Expected: PASS for permission, configuration, fee quote, and pressure update tests.

- [ ] **Step 5: Commit hook**

Run:

```powershell
git add yieldflow-guard/src/YieldFlowGuardHook.sol yieldflow-guard/test/YieldFlowGuardHook.t.sol
git commit -m "feat: add YieldFlow Guard hook"
```

Expected: focused commit with hook and tests.

---

### Task 5: Add v4 Pool Integration Test

**Files:**
- Modify: `yieldflow-guard/test/YieldFlowGuardHook.t.sol`

- [ ] **Step 1: Add integration test imports**

Add these imports to `yieldflow-guard/test/YieldFlowGuardHook.t.sol`:

```solidity
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/libraries/EasyPosm.sol";
import {BaseTest} from "./utils/BaseTest.sol";
```

- [ ] **Step 2: Add integration test contract**

Append to `yieldflow-guard/test/YieldFlowGuardHook.t.sol`:

```solidity
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

        deployCodeTo("YieldFlowGuardHook.sol:YieldFlowGuardHook", abi.encode(poolManager, config), flags);
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
        assertEq(lastFeeAfterFirst, 0);

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
```

- [ ] **Step 3: Run integration test**

Run:

```powershell
forge test --match-contract YieldFlowGuardHookIntegrationTest -vv
```

Expected: PASS and at least one v4 swap path calls the hook.

- [ ] **Step 4: Run full test suite**

Run:

```powershell
forge test -vv
```

Expected: PASS for all YieldFlow Guard tests and imported scaffold tests that remain relevant.

- [ ] **Step 5: Commit integration test**

Run:

```powershell
git add yieldflow-guard/test/YieldFlowGuardHook.t.sol
git commit -m "test: cover YieldFlow hook in v4 pool"
```

Expected: focused commit with integration coverage.

---

### Task 6: Add Hook Deployment Script

**Files:**
- Create: `yieldflow-guard/script/00_DeployYieldFlowGuard.s.sol`

- [ ] **Step 1: Write deployment script**

Create `yieldflow-guard/script/00_DeployYieldFlowGuard.s.sol`:

```solidity
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

        bytes memory constructorArgs = abi.encode(IPoolManager(X_LAYER_POOL_MANAGER), config);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(YieldFlowGuardHook).creationCode, constructorArgs);

        vm.broadcast();
        hook = new YieldFlowGuardHook{salt: salt}(IPoolManager(X_LAYER_POOL_MANAGER), config);

        require(address(hook) == hookAddress, "YieldFlowGuard: hook address mismatch");
    }
}
```

- [ ] **Step 2: Run local script dry run**

Run:

```powershell
forge script script/00_DeployYieldFlowGuard.s.sol --sig "run()"
```

Expected: script compiles and prints simulated deployment traces without broadcasting.

- [ ] **Step 3: Commit deployment script**

Run:

```powershell
git add yieldflow-guard/script/00_DeployYieldFlowGuard.s.sol
git commit -m "script: add YieldFlow hook deploy script"
```

Expected: focused commit with deployment script.

---

### Task 7: Update README Evidence Package

**Files:**
- Modify: `yieldflow-guard/README.md`

- [ ] **Step 1: Replace README with submission-oriented content**

Update `yieldflow-guard/README.md` to include:

```markdown
# YieldFlow Guard

YieldFlow Guard is a Uniswap v4 Hook for pricing exit pressure in static yield-position pools on X Layer.

## Why It Exists

Early yield assets need instant-exit liquidity, but LPs need transparent compensation when flow becomes one-sided. YieldFlow Guard raises LP fees when swaps increase exit pressure and lowers fees when swaps rebalance the pool.

## MVP Scope

- P0 asset pair: `st-yUSDG / USDG` mock static yield-position pool.
- Raw Aave aTokens are not used in the MVP pool because growing-balance tokens introduce accounting risk for AMMs and hooks.
- The Aave on X Layer story is used as market context and future integration direction.

## Hook Behavior

| Flow | Effect |
| --- | --- |
| Balanced small swap | Base fee |
| Exit-pressure worsening swap | Higher fee |
| Rebalancing swap | Minimum fee |
| Large worsening swap | Capped high fee |

## Build And Test

```bash
forge install
forge test -vv
```

## X Layer Deployment Targets

| Contract | Address |
| --- | --- |
| X Layer PoolManager | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` |
| YieldFlowGuardHook | Not deployed yet |
| Demo Pool | Not deployed yet |

## Evidence Table

| Evidence | Transaction |
| --- | --- |
| Hook deployment | Not deployed yet |
| Pool initialization | Not deployed yet |
| Add liquidity | Not deployed yet |
| Balanced swap | Not deployed yet |
| Worsening swap | Not deployed yet |
| Rebalancing swap | Not deployed yet |

## Hackathon Rule Mapping

| Rule | YieldFlow Guard Response |
| --- | --- |
| Build around Uniswap v4 Hook | Uses `beforeSwap`, `afterSwap`, and `afterAddLiquidity` |
| Deploy V4 Pool and Hook on X Layer | Deployment script targets X Layer PoolManager |
| Innovation | Exit-pressure-sensitive dynamic LP fees for static yield-position pools |
| Market value | Supports safer liquidity bootstrapping for X Layer yield assets |
| Completion | Tests, deploy script, tx evidence table, and demo path |

## Demo Script

1. Show `st-yUSDG / USDG` as a static yield-position pair.
2. Run a balanced swap and show base fee.
3. Run an exit-pressure worsening swap and show higher fee.
4. Run a rebalancing swap and show lower fee.
5. Show hook events and the X Layer transaction table.

## References

- OKX Build X Hackathon Hook: https://web3.okx.com/zh-hans/xlayer/build-x-hackathon/hook
- Uniswap v4 Dynamic Fees: https://developers.uniswap.org/docs/protocols/v4/concepts/dynamic-fees
- Uniswap v4 Hook Deployment: https://developers.uniswap.org/docs/protocols/v4/guides/hooks/hook-deployment
- Aave static aToken design: https://governance.aave.com/t/bgd-statatoken-v3/11894
```

- [ ] **Step 2: Run markdown link check by search**

Run:

```powershell
rg -n "Not deployed yet|raw Aave|static yield" README.md docs
```

Expected: README contains the planned evidence slots and clearly states raw aTokens are excluded from P0.

- [ ] **Step 3: Commit README update**

Run:

```powershell
git add yieldflow-guard/README.md
git commit -m "docs: prepare YieldFlow submission README"
```

Expected: focused commit with submission README.

---

### Task 8: Final Verification Before X Layer Deployment

**Files:**
- No file changes required unless verification exposes a concrete defect.

- [ ] **Step 1: Run full tests**

Run:

```powershell
forge test -vv
```

Expected: all tests pass.

- [ ] **Step 2: Run formatting**

Run:

```powershell
forge fmt --check
```

Expected: no formatting changes required.

- [ ] **Step 3: Run build**

Run:

```powershell
forge build
```

Expected: build succeeds.

- [ ] **Step 4: Check git status**

Run:

```powershell
git status --short
```

Expected: only unrelated pre-existing untracked files outside `yieldflow-guard` remain.

- [ ] **Step 5: Commit verification fixes if any were needed**

Run only after a concrete code or documentation fix:

```powershell
git add yieldflow-guard
git commit -m "fix: stabilize YieldFlow verification"
```

Expected: commit exists only if Step 1, Step 2, or Step 3 required a fix.

---

## Plan Self-Review

**Spec coverage:** The plan covers the static-yield MVP, dynamic fee hook, pool-specific state, mock token, tests, deployment script, X Layer PoolManager target, README evidence table, and raw aToken risk messaging.

**Placeholder scan:** The README intentionally contains `Not deployed yet` cells as evidence slots before real X Layer transactions exist. No task step depends on an unspecified implementation detail.

**Type consistency:** The plan uses `netExitPressure` consistently in code while mapping it back to the design's exit-pressure concept. Hook flags match implemented callbacks: `afterInitialize`, `afterAddLiquidity`, `beforeSwap`, and `afterSwap`.
