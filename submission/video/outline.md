# YieldFlow Guard Web Video Outline

This outline follows the `web-video-presentation-artifact` skill contract:
one main idea per scene, product evidence on screen, click navigation, keyboard navigation, and optional autoplay for recording.

## Global Timing

| Scene | Segment | Duration | Purpose |
| --- | --- | ---: | --- |
| 0 | 1 | 9s | Open with the product and hackathon fit. |
| 1 | 1 | 12s | Show the LP risk problem. |
| 2 | 1 | 14s | Explain the Hook fee mechanism. |
| 3 | 2 | 12s | Show X Layer deployment addresses. |
| 4 | 2 | 12s | Show the demo pool architecture. |
| 5 | 2 | 17s | Show the three swap evidence path. |
| 6 | 3 | 12s | Show final hook state and what it proves. |
| 7 | 3 | 14s | Close with market value and submission readiness. |

Full recording duration: about 102 seconds.

## Scene Acceptance Checks

- The viewer can see the project name and category within the first 3 seconds.
- The Hook mechanism is represented as `beforeSwap -> fee quote -> afterSwap -> pressure update`.
- The deployed Hook address and pool ID are visible.
- The three important transaction hashes are visible with their fee outcomes.
- The market slide does not overclaim production integration. It states the path from mock static pair to real wrappers.
- Every scene fits inside 16:9 at 1920x1080.
- The artifact can be used as one full demo or three continuous short segments.

## Segment Mapping

| Segment file | Scenes | X post |
| --- | --- | --- |
| `segment-01-mechanism.mp4` | 0-2 | Post 1: product and mechanism |
| `segment-02-onchain-proof.mp4` | 3-5 | Post 2: deployed proof and txs |
| `segment-03-market-path.mp4` | 6-7 | Post 3: market value and next integration |

## Evidence To Keep Visible

- Hook: `0x7B8Ae07b6eeC3a82109644501E45837559Db54c0`
- Pool ID: `0x19fcbf9649578188e26718f7c88010beed42a1b9bafe6a5c7780947a34943955`
- X Layer chain ID: `196`
- Demo pair: `st-yUSDG / USDG`
- Fee path: `500 -> 3000 -> 100`
- Swap txs:
  - `0xaa0092fb40d120369f2169bcca345e5c6116a3ac28024b9edf9c0711260689bf`
  - `0x356d9ae6bde524d614b784d648a24541db043eeac8f1b4d99aef2c3a05b9c762`
  - `0x6d7cd050adc2260487069074a70cefe63acd8747ef1ed668b0cd48f894289619`
