# YieldFlow Guard Submission Plan

This is the operator checklist for submitting YieldFlow Guard to Hook the Future.

## Official Rule Fit

The hackathon page requires:

- Build around the Uniswap v4 Hook mechanism.
- Deploy at least one V4 Pool and Hook contract on X Layer mainnet or testnet.
- Submit verifiable contract addresses.
- Use a dedicated X account and tag `@XLayerOfficial`, `@Uniswap`, and `@flapdotsh` at submission.
- The Google Form also requires the X post to include `#BuildX`.
- Submit through the official Google Form before `2026-05-28 23:59 UTC`.
- Demo video is optional but recommended, 1-3 minutes.

YieldFlow Guard already satisfies the technical completion requirements through the deployed Hook, demo pool, liquidity, and three behavior-triggering swaps.

## Submission Assets

| Asset | Path | Use |
| --- | --- | --- |
| Public submission kit | `docs/submission-kit.md` | Copy answers into the Google Form. |
| Video artifact | `submission/video/index.html` | Open locally or record as full video / segments. |
| Video script | `submission/video/script.md` | Voiceover and narration source. |
| Video outline | `submission/video/outline.md` | Scene timing and segment mapping. |
| X post pack | `submission/social/x-thread.md` | Publish one concise post from the dedicated project X account. |
| X poster 1 | `submission/social/post-01-mechanism-gpt.png` | 9:16 GPT Image 2 poster for mechanism. |
| X poster 2 | `submission/social/post-02-onchain-proof-gpt.png` | 9:16 GPT Image 2 poster for on-chain proof. |
| X poster 3 | `submission/social/post-03-market-path-gpt.png` | 9:16 GPT Image 2 poster for market path. |

## Recommended Submission Order

1. Push the repository to a public GitHub repo.
2. Confirm the README shows:
   - Hook address
   - Demo pool ID
   - PoolManager
   - DemoRouter
   - three swap transactions
   - test and build commands
3. Record the full demo video from `submission/video/index.html`.
4. Upload the demo video to a stable public URL.
5. Publish one X post from the dedicated project account. It must include `@XLayerOfficial`, `@Uniswap`, `@flapdotsh`, `#BuildX`, the public GitHub URL, and all three posters.
6. Copy the X post URL, public repo URL, Hook address, and pool ID into the Google Form.
7. Submit before `2026-05-28 23:59 UTC`.

## Google Form Field Pack

Observed from the official Google Form on `2026-05-26`. Fill these exact fields:

| Field | Value |
| --- | --- |
| Email | Use the Google account email shown by the form. |
| Project Name | `YieldFlow Guard` |
| One-Line Description & Project Highlights | `YieldFlow Guard is a Uniswap v4 Hook on X Layer that turns yield-token exit pressure into a dynamic LP fee signal. It is deployed on X Layer mainnet with a configured v4 pool, liquidity, and live swaps proving three fee paths: 500 -> 3000 -> 100. Hook: 0x7B8Ae07b6eeC3a82109644501E45837559Db54c0; Pool ID: 0x19fcbf9649578188e26718f7c88010beed42a1b9bafe6a5c7780947a34943955.` |
| X (Twitter) Official Handle | Add the dedicated project X account URL, for example `https://x.com/<project-account>`. |
| X (Twitter) Post Link | Add the live single-post URL after publishing. The post must tag `@XLayerOfficial`, include `#BuildX`, and keep `@Uniswap` and `@flapdotsh` too. |
| Team Members Telegram Contact | Add the core team Telegram handle(s), for example `@your_telegram`. |
| Team Members X (Twitter) Contact | Add the core team X handle(s), for example `https://x.com/<your-handle>`. |
| Untitled radio block | Leave untouched unless the form validator forces a choice; it has no visible label in the current form view. |
| GitHub Repository Link | Add the public GitHub repository URL after pushing. |
| Any other words to X Layer team | `Thanks for hosting Hook the Future. We focused on a verifiable Hook primitive rather than a mock-only pitch: deployed Hook, configured v4 pool, liquidity, and live swap evidence are included. The next path is connecting this fee primitive to real X Layer yield wrappers and stable/yield assets.` |

## Values To Confirm Before Submit

| Value | Why it is still manual |
| --- | --- |
| Dedicated project X account URL | The form asks for the official project handle. Use the project account, not a random personal browsing-history candidate. |
| Team member X handle(s) | The form asks for team contact separately from the project account. |
| Team Telegram handle(s) | Required by the form and not derivable from the repo. |
| Public GitHub repo URL | This local worktree currently has no remote configured. Add after publishing. |
| Hosted full demo video URL | Optional for the form. Add if you upload `submission/video/renders/full-demo.mp4` to a public URL. |

## Evidence Pack

| Evidence | Hash / address |
| --- | --- |
| Hook deployment | `0x0e92e30b22b0c11eca88fbf4134697652a60532833c3dac30b13d6b0cdaacd34` |
| Hook contract | `0x7B8Ae07b6eeC3a82109644501E45837559Db54c0` |
| Demo router | `0xf166b45373b5c4D133fF5812331b8d870944C91f` |
| Demo pool ID | `0x19fcbf9649578188e26718f7c88010beed42a1b9bafe6a5c7780947a34943955` |
| Pool configuration | `0x5e2556594d89bc9b129299c8e05fc62f9c92f512e8d7fb04c509ae5612a981f8` |
| Pool initialization | `0xb2f3c2cdb0c828d7fbde81ee600c005f8eddfd628eaceceb0447d005f5835446` |
| Add liquidity | `0x87be387f265708cea59302fc1c26a3343262f4e0ba5591b0192720f9508bf113` |
| Balanced exit swap | `0xaa0092fb40d120369f2169bcca345e5c6116a3ac28024b9edf9c0711260689bf` |
| Worsening exit swap | `0x356d9ae6bde524d614b784d648a24541db043eeac8f1b4d99aef2c3a05b9c762` |
| Rebalancing swap | `0x6d7cd050adc2260487069074a70cefe63acd8747ef1ed668b0cd48f894289619` |

## X Post Execution

Publish one post from `submission/social/x-thread.md`, then add the public repo URL before posting. The post must include `@XLayerOfficial` and `#BuildX`.

Recommended attachments:

- `submission/social/post-01-mechanism-gpt.png`
- `submission/social/post-02-onchain-proof-gpt.png`
- `submission/social/post-03-market-path-gpt.png`

Use 9:16 vertical posters for X. They read better on mobile and can also serve as short-video covers.

Do not split the initial campaign into three posts unless there is time for follow-up posts. If video segments are used later, they can become follow-up content:

- `submission/video/renders/segment-01-mechanism.mp4`
- `submission/video/renders/segment-02-onchain-proof.mp4`
- `submission/video/renders/segment-03-market-path.mp4`

## GPT Image 2 Poster Commands

Generate the three X posters as 9:16 GPT Image 2 images. Use `1152x2048` so the output is vertical and ready for the X mobile feed.

First check the local GPT Image 2 mode and gateway reachability:

```powershell
$node="node"
if ($env:CODEX_NODE) { $node=$env:CODEX_NODE }
$check="$env:USERPROFILE\.codex\skills\gpt-image-2\scripts\check-mode.js"
$gen="$env:USERPROFILE\.codex\skills\gpt-image-2\scripts\generate.js"
& $node $check --json

try {
  Invoke-WebRequest "http://127.0.0.1:59403/v1/models" -UseBasicParsing
} catch {
  if ($_.Exception.Message -match "401|unauthorized|Authorization|X-API-Key") {
    "Gateway is reachable; auth is loaded by the GPT Image 2 script."
  } else {
    throw
  }
}
```

Then generate the posters:

```powershell
& $node $gen --promptfile .\submission\social\prompts\post-01-mechanism-gpt-image-2.md --prompt-output .\submission\social\prompts\post-01-mechanism-final.md --image .\submission\social\post-01-mechanism-gpt.png --size 1152x2048 --quality high --output-format png --json
& $node $gen --promptfile .\submission\social\prompts\post-02-onchain-proof-gpt-image-2.md --prompt-output .\submission\social\prompts\post-02-onchain-proof-final.md --image .\submission\social\post-02-onchain-proof-gpt.png --size 1152x2048 --quality high --output-format png --json
& $node $gen --promptfile .\submission\social\prompts\post-03-market-path-gpt-image-2.md --prompt-output .\submission\social\prompts\post-03-market-path-final.md --image .\submission\social\post-03-market-path-gpt.png --size 1152x2048 --quality high --output-format png --json
```

If the gateway preflight fails, start the GPT Image 2 local gateway first and rerun the same commands. Do not switch to the official OpenAI API unless `OPENAI_API_KEY` is a real Platform API key; a Codex/Garden token is not accepted by `api.openai.com`.

## Recording Commands

Use the bundled Codex Node runtime from PowerShell:

```powershell
$node="node"
if ($env:CODEX_NODE) { $node=$env:CODEX_NODE }
& $node .\submission\video\record.js full
& $node .\submission\video\record.js segment-01
& $node .\submission\video\record.js segment-02
& $node .\submission\video\record.js segment-03
& $node .\submission\video\add-voiceover.js --force
```

Expected outputs:

- `submission/video/renders/full-demo.mp4`
- `submission/video/renders/segment-01-mechanism.mp4`
- `submission/video/renders/segment-02-onchain-proof.mp4`
- `submission/video/renders/segment-03-market-path.mp4`

The final MP4 files should contain an AAC audio track. `add-voiceover.js` uses one local Windows SAPI voice for every scene unless `SAPI_VOICE` is explicitly set.

## Final Pre-Submit Check

- [ ] Public repo opens without private paths.
- [ ] README and `docs/submission-kit.md` contain the same Hook address and pool ID.
- [ ] Full demo video plays from the hosted URL.
- [ ] X post includes all three required tags, `#BuildX`, the public GitHub URL, and all three posters.
- [ ] Google Form has the X post URL, public repo URL, team Telegram, team X handle, Hook address, and pool ID.
