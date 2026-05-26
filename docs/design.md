# YieldFlow Guard Design Review

Date: 2026-05-26

## Summary

YieldFlow Guard is a Uniswap v4 Hook for static yield-position exit liquidity on X Layer.

The Hook does not custody funds, deposit into Aave, run a vault strategy, or introduce a new token. It only uses Uniswap v4 dynamic fee override to price one specific pool condition: concentrated exits from a yield-position token into its base asset.

## Problem

Yield-position assets need exit liquidity. A holder of a static yield token, such as a future `stataUSDG`-style wrapper, may want to swap back into the base token immediately instead of waiting for protocol redemption or routing through fragmented venues.

That creates a natural AMM pair:

```text
static yield-position token / base token
st-yUSDG / USDG in the demo
```

When many traders sell the yield-position token into the base token, the pool accumulates more yield-position inventory and loses base-token inventory. LPs are taking more directional and liquidity risk. YieldFlow Guard turns that pressure into an on-chain LP fee signal.

## Why Not Raw Aave aTokens

The MVP intentionally avoids raw Aave aTokens.

Raw aTokens have growing balances. Their balances can change because of interest accrual, not just swaps and liquidity operations. That creates avoidable accounting risk for an AMM Hook that wants to infer flow from pool deltas.

The safer MVP target is a static yield-position token or a mock static token:

- P0 demo: `st-yUSDG / USDG`
- P1 real target: static wrappers such as `stataUSDT0 / USDT0` or `stataUSDG / USDG`, only after the wrapper is confirmed on X Layer
- Not P0: raw `aXlrUSDT0`, raw `aXlrUSDG`, raw `aXlrxETH`

This keeps the hackathon project focused on Hook innovation rather than rebasing-token integration risk.

## Mechanism

The Hook stores one flow state per pool:

```solidity
struct FlowState {
    int256 netExitPressure;
    uint256 lastUpdatedBlock;
    uint24 lastFee;
}
```

Positive `netExitPressure` means more net flow has sold the yield-position token into the base token. Negative pressure means flow has moved in the opposite direction and replenished the yield-position side.

For each swap:

1. `beforeSwap` checks whether the swap is exit flow or rebalancing flow.
2. It quotes a dynamic LP fee from current pressure, projected pressure, and swap size.
3. `afterSwap` updates the stored pressure and emits flow evidence.

The fee rule is intentionally simple:

```text
if projected pressure is lower than current pressure:
  fee = minFee
else:
  fee = baseFee
  if pressure crosses imbalance threshold: fee += imbalancePenalty
  if swap size crosses large swap threshold: fee += largeSwapPenalty
  fee = min(fee, maxFee)
```

## Why Rebalancing Flow Gets A Lower Fee

If the pool has already been pushed toward too much yield-position inventory and too little base-token inventory, a reverse trade helps LPs. A trader who brings base tokens into the pool and removes yield-position inventory is reducing imbalance.

The Hook discounts that direction because it improves the pool state:

- LPs recover base-token inventory.
- The pool becomes more useful for future exits.
- Arbitrageurs and routers get a clear incentive to rebalance the pool.

This is not a guarantee against LP loss. It is a transparent fee response to flow imbalance.

## Hackathon Fit

| Requirement / scoring axis | YieldFlow Guard response |
| --- | --- |
| Uniswap v4 Hook | Uses `beforeSwap`, `afterSwap`, and `afterAddLiquidity` |
| X Layer deployment | Hook, router, v4 pool, liquidity, and swaps are deployed on X Layer mainnet |
| Innovation | Flow-sensitive LP fee for static yield-position exit pools |
| Market potential | Early X Layer yield assets need safer and more transparent exit liquidity |
| Completion | Deployed contracts, configured pool, liquidity, live swaps, tests, docs, social assets, and video |
| Code quality | No custody, no oracle dependency, no Aave calls, no raw rebasing-token pool |

## Demo Evidence

The demo pair is `st-yUSDG / USDG`.

Observed fee path:

```text
base exit flow        -> 500
worsening exit flow   -> 3000
rebalancing flow      -> 100
```

The final Hook state is stored on-chain:

```text
netExitPressure = 110e18
lastFee = 100
lastUpdatedBlock = 61009807
```

## Risks And Boundaries

YieldFlow Guard should not be described as capital protection or risk-free exit liquidity.

It does not solve:

- asset depeg risk
- base protocol risk
- bridge risk
- sequencer or chain risk
- insufficient total liquidity

It does solve a narrower problem: LP fee response becomes stateful, transparent, and aligned with whether a swap worsens or improves exit pressure.

## Public Pitch

> YieldFlow Guard is a Uniswap v4 Hook on X Layer that turns yield-token exit pressure into dynamic LP fees. Exit flow pays more when it worsens pool imbalance, while rebalancing flow pays less.

## References

- OKX Build X Hook the Future: https://web3.okx.com/zh-hans/xlayer/build-x-hackathon/hook
- OKX Aave on X Layer: https://web3.okx.com/learn/aave-xlayer
- Uniswap v4 Dynamic Fees: https://developers.uniswap.org/docs/protocols/v4/concepts/dynamic-fees
- Uniswap v4 Hooks: https://developers.uniswap.org/docs/protocols/v4/concepts/hooks
- Uniswap v4 Deployments: https://developers.uniswap.org/docs/protocols/v4/deployments
- Uniswap unsupported token considerations: https://developers.uniswap.org/docs/protocols/v3/concepts/unsupported-tokens
- Uniswap Foundation Hook Security Framework: https://github.com/uniswapfoundation/security-framework
- Aave aTokens: https://aave.com/help/aave-101/introduction-to-aave
- BGD static aToken v3: https://governance.aave.com/t/bgd-statatoken-v3/11894
- Aave X Layer discussion: https://governance.aave.com/t/arfc-deploy-aave-v3-on-x-layer/23175
