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

## Repository Docs

- [Design Review](docs/design.md)
- [Implementation Plan](docs/implementation-plan.md)
- [Submission Kit](docs/submission-kit.md)
- [Submission Plan](docs/submission-plan.md)
- [Submission Assets](submission/social/x-thread.md)

## Build And Test

```bash
forge install
forge test -vv
forge build
```

This workspace keeps a local Windows Foundry binary under `tools/foundry/` for verification. The directory is intentionally ignored; a standalone repo should use a normal Foundry install and `forge install`.

If Foundry dependency installation is blocked by a monorepo/subdirectory setup, clone the three local dependency caches manually:

```bash
mkdir -p lib
git -c core.longpaths=true clone --depth 1 --recurse-submodules https://github.com/foundry-rs/forge-std.git lib/forge-std
git -c core.longpaths=true clone --depth 1 --recurse-submodules https://github.com/OpenZeppelin/uniswap-hooks.git lib/uniswap-hooks
git -c core.longpaths=true clone --depth 1 --recurse-submodules https://github.com/akshatmittal/hookmate.git lib/hookmate
```

## Local Verification Snapshot

| Check | Result |
| --- | --- |
| Fee model tests | 6 passed |
| Mock static token tests | 3 passed |
| Hook harness tests | 8 passed |
| v4 pool integration test | 1 passed |
| Demo router integration test | 1 passed |
| Deploy script dry run | Owner-controlled hook address depends on `DEPLOYER_ADDRESS` |
| X Layer Hook deployment | Success in block `61009042`; owner verified as `0xC3bFa68F5318bc51cbd579FAd013E885D8568038` |
| X Layer Demo stack deployment | Code verified for demo tokens and router; deployer holds `1,000,000` of each mock token with router allowance set |
| X Layer Demo pool and liquidity | Success in block `61009382`; `poolConfigs` enabled and PoolManager holds both initial tokens |
| X Layer Demo swaps | Success in block `61009807`; fees observed as `500 -> 3000 -> 100`, final net exit pressure `110e18` |

## X Layer Deployment Targets

| Target | Address / ID |
| --- | --- |
| X Layer PoolManager | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` |
| YieldFlowGuardHook | `0x7B8Ae07b6eeC3a82109644501E45837559Db54c0` |
| DemoRouter | `0xf166b45373b5c4D133fF5812331b8d870944C91f` |
| USDG mock | `0x61fA26D5b898088D007F4B807934e00Ba368030B` |
| st-yUSDG mock | `0x9E3d360125Bc17Af083200F2FF398F1dC6fEBBF7` |
| Demo Pool | `0x19fcbf9649578188e26718f7c88010beed42a1b9bafe6a5c7780947a34943955` |

## Evidence Table

| Evidence | Transaction |
| --- | --- |
| Hook deployment | `0x0e92e30b22b0c11eca88fbf4134697652a60532833c3dac30b13d6b0cdaacd34` |
| Demo stack deployment | USDG `0x9e71e96a0a5fd607f89af260a670fa1ea504bc78c272744971a3be0dec78cf6e`; st-yUSDG `0xd7dc4fb36458a85a631a20860ea9a7b6cab5d18d5708c0a514a516f993338602`; DemoRouter `0x72229416281e91d84f4ea6e99eff1e178b7bf816840e79f282ac498a6b257137` |
| Pool configuration | `0x5e2556594d89bc9b129299c8e05fc62f9c92f512e8d7fb04c509ae5612a981f8` |
| Pool initialization | `0xb2f3c2cdb0c828d7fbde81ee600c005f8eddfd628eaceceb0447d005f5835446` |
| Add liquidity | `0x87be387f265708cea59302fc1c26a3343262f4e0ba5591b0192720f9508bf113` |
| Balanced exit swap | `0xaa0092fb40d120369f2169bcca345e5c6116a3ac28024b9edf9c0711260689bf` |
| Worsening exit swap | `0x356d9ae6bde524d614b784d648a24541db043eeac8f1b4d99aef2c3a05b9c762` |
| Rebalancing swap | `0x6d7cd050adc2260487069074a70cefe63acd8747ef1ed668b0cd48f894289619` |

## X Layer Demo Commands

Run these from this directory after setting `PRIVATE_KEY`, `X_LAYER_RPC_URL`, and `DEPLOYER_ADDRESS` in the same PowerShell session:

```powershell
$env:X_LAYER_RPC_URL="https://rpc.xlayer.tech"
$env:DEPLOYER_ADDRESS="0xC3bFa68F5318bc51cbd579FAd013E885D8568038"
```

Deploy the owner-controlled hook:

```powershell
.\tools\foundry\forge.exe script script/00_DeployYieldFlowGuard.s.sol `
  --rpc-url $env:X_LAYER_RPC_URL `
  --private-key $env:PRIVATE_KEY `
  --broadcast `
  -vvvv
```

After the command prints `hook`, set:

```powershell
$env:YIELD_FLOW_GUARD_HOOK="0x7B8Ae07b6eeC3a82109644501E45837559Db54c0"
```

Deploy demo tokens and the demo router:

```powershell
.\tools\foundry\forge.exe script script/01_DeployDemoStack.s.sol `
  --rpc-url $env:X_LAYER_RPC_URL `
  --private-key $env:PRIVATE_KEY `
  --broadcast `
  -vvvv
```

After the command prints `usdg`, `stYusdg`, and `demoRouter`, set:

```powershell
$env:USDG_ADDRESS="0x61fA26D5b898088D007F4B807934e00Ba368030B"
$env:ST_YUSDG_ADDRESS="0x9E3d360125Bc17Af083200F2FF398F1dC6fEBBF7"
$env:DEMO_ROUTER_ADDRESS="0xf166b45373b5c4D133fF5812331b8d870944C91f"
$env:YIELD_FLOW_GUARD_HOOK="0x7B8Ae07b6eeC3a82109644501E45837559Db54c0"
```

Create the dynamic-fee pool, configure the hook, initialize at 1:1, and add full-range liquidity:

```powershell
.\tools\foundry\forge.exe script script/02_CreateDemoPoolAndLiquidity.s.sol `
  --rpc-url $env:X_LAYER_RPC_URL `
  --private-key $env:PRIVATE_KEY `
  --broadcast `
  -vvvv
```

Run the three evidence swaps:

```powershell
.\tools\foundry\forge.exe script script/03_RunDemoSwaps.s.sol `
  --rpc-url $env:X_LAYER_RPC_URL `
  --private-key $env:PRIVATE_KEY `
  --broadcast `
  -vvvv
```

## Hackathon Rule Mapping

| Rule | YieldFlow Guard Response |
| --- | --- |
| Build around Uniswap v4 Hook | Uses `beforeSwap`, `afterSwap`, and `afterAddLiquidity` |
| Deploy V4 Pool and Hook on X Layer | Deployment script targets X Layer PoolManager |
| Innovation | Exit-pressure-sensitive dynamic LP fees for static yield-position pools |
| Market value | Supports safer liquidity bootstrapping for X Layer yield assets |
| Completion | Tests, deploy script, transaction evidence table, and demo path |

## Demo Script

1. Show `st-yUSDG / USDG` as a static yield-position pair.
2. Run a balanced swap and show base fee.
3. Run an exit-pressure worsening swap and show higher fee.
4. Run a rebalancing swap and show lower fee.
5. Show hook events and the X Layer transaction table.

## Submission Checklist

- Deploy `YieldFlowGuardHook` on X Layer.
- Initialize a v4 dynamic-fee pool using the hook.
- Add liquidity to the demo pool.
- Execute balanced, worsening, and rebalancing swaps.
- Fill the evidence table with explorer links.
- Record a 1-3 minute demo video.
- Post from an independent X account and tag `@XLayerOfficial`, `@Uniswap`, and `@flapdotsh`; include `#BuildX` for the Google Form.

## References

- OKX Build X Hackathon Hook: https://web3.okx.com/zh-hans/xlayer/build-x-hackathon/hook
- Uniswap v4 Dynamic Fees: https://developers.uniswap.org/docs/protocols/v4/concepts/dynamic-fees
- Uniswap v4 Hook Deployment: https://developers.uniswap.org/docs/protocols/v4/guides/hooks/hook-deployment
- Uniswap v4 Deployments: https://developers.uniswap.org/docs/protocols/v4/deployments
- Aave static aToken design: https://governance.aave.com/t/bgd-statatoken-v3/11894
