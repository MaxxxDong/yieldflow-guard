# YieldFlow Guard Demo Video Script

Target length: 90-120 seconds.
Format: 16:9 web-video artifact, recordable as one full demo or three short X segments.

## Segment 1 - Mechanism

YieldFlow Guard is a Uniswap v4 Hook on X Layer for yield-position liquidity.
The problem is simple: early yield pools need instant exit liquidity, but LPs take concentrated risk when everyone exits the yield token at the same time.

The Hook tracks exit pressure directly in the pool. Before a swap, it quotes a dynamic LP fee. After the swap, it updates the pressure state.
Balanced flow pays the base fee. Worsening exit pressure pays a higher fee. Rebalancing flow pays a lower fee.

## Segment 2 - On-Chain Proof

This is deployed on X Layer mainnet.
The Hook address is `0x7B8Ae07b6eeC3a82109644501E45837559Db54c0`, and the demo pool ID is `0x19fcbf9649578188e26718f7c88010beed42a1b9bafe6a5c7780947a34943955`.

The demo pair is `st-yUSDG / USDG`, with a small router that initializes the v4 pool, adds liquidity, and runs swaps.
Three real swaps triggered three fee paths: `500`, then `3000`, then `100`.

## Segment 3 - Market Path

The final hook state is also on-chain: net exit pressure is `110e18`, and the last fee is `100` because the last trade helped rebalance the pool.

The market goal is safer liquidity bootstrapping for X Layer yield wrappers, stable yield tokens, and static position assets.
LPs get transparent compensation when exit pressure builds, while routers and users can verify the behavior from pool events and hook state.

YieldFlow Guard is built for the Hook the Future hackathon: a new Hook logic, deployed pool, live transactions, and a demo path that can be replayed.
