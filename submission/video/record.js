const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const homeDir = os.homedir();
const runtimeModules = process.env.CODEX_NODE_MODULES ||
  path.join(homeDir, ".cache", "codex-runtimes", "codex-primary-runtime", "dependencies", "node", "node_modules");
process.env.NODE_PATH = [
  runtimeModules,
  path.join(runtimeModules, ".pnpm", "node_modules"),
  process.env.NODE_PATH
].filter(Boolean).join(path.delimiter);
require("module").Module._initPaths();

const { chromium } = require("playwright");

const ffmpegCandidates = [
  process.env.FFMPEG_PATH,
  path.join(homeDir, "bin", "ffmpeg.exe"),
  path.join(homeDir, "AppData", "Local", "ms-playwright", "ffmpeg-1011", "ffmpeg-win64.exe")
].filter(Boolean);

const browserCandidates = [
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE,
  path.join(homeDir, "AppData", "Local", "ms-playwright", "chromium_headless_shell-1208", "chrome-headless-shell-win64", "chrome-headless-shell.exe"),
  path.join(homeDir, "AppData", "Local", "ms-playwright", "chromium-1208", "chrome-win64", "chrome.exe"),
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
].filter(Boolean);

const modes = {
  full: { segment: "full", output: "full-demo" },
  "segment-01": { segment: "segment-01", output: "segment-01-mechanism" },
  "segment-02": { segment: "segment-02", output: "segment-02-onchain-proof" },
  "segment-03": { segment: "segment-03", output: "segment-03-market-path" }
};

async function main() {
  const mode = process.argv[2] || "full";
  if (!modes[mode]) {
    throw new Error(`Unknown mode "${mode}". Use one of: ${Object.keys(modes).join(", ")}`);
  }

  const here = __dirname;
  const outDir = path.join(here, "renders");
  const tmpDir = path.join(outDir, ".video-tmp");
  fs.mkdirSync(outDir, { recursive: true });
  fs.rmSync(tmpDir, { recursive: true, force: true });
  fs.mkdirSync(tmpDir, { recursive: true });

  const existingBrowser = browserCandidates.find((candidate) => fs.existsSync(candidate));
  const launchOptions = existingBrowser
    ? { headless: true, executablePath: existingBrowser }
    : { headless: true };
  const browser = await chromium.launch(launchOptions);
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    recordVideo: {
      dir: tmpDir,
      size: { width: 1920, height: 1080 }
    }
  });
  const page = await context.newPage();
  const url = `file://${path.join(here, "index.html").replace(/\\/g, "/")}?record=1&segment=${modes[mode].segment}`;
  await page.goto(url);
  await page.waitForFunction(() => window.__demoDone === true, null, { timeout: 150000 });
  await page.waitForTimeout(800);
  await context.close();
  await browser.close();

  const webm = fs.readdirSync(tmpDir).find((name) => name.endsWith(".webm"));
  if (!webm) {
    throw new Error("Playwright did not produce a .webm recording");
  }

  const webmPath = path.join(tmpDir, webm);
  const keepWebmPath = path.join(outDir, `${modes[mode].output}.webm`);
  fs.copyFileSync(webmPath, keepWebmPath);

  const mp4Path = path.join(outDir, `${modes[mode].output}.mp4`);
  const ffmpegPath = ffmpegCandidates.find((candidate) => fs.existsSync(candidate));
  if (ffmpegPath) {
    const result = spawnSync(ffmpegPath, [
      "-y",
      "-i", keepWebmPath,
      "-vf", "format=yuv420p",
      "-movflags", "+faststart",
      mp4Path
    ], { stdio: "inherit" });
    if (result.status !== 0) {
      throw new Error(`ffmpeg conversion failed with status ${result.status}`);
    }
    console.log(mp4Path);
  } else {
    console.log(`ffmpeg not found, kept WebM at ${keepWebmPath}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
