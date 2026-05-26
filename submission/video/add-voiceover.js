const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

function commandExists(command) {
  const probe = spawnSync(process.platform === "win32" ? "where.exe" : "which", [command], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"]
  });
  return probe.status === 0 ? probe.stdout.split(/\r?\n/).find(Boolean) : null;
}

function firstExisting(candidates) {
  return candidates.find((candidate) => candidate && fs.existsSync(candidate)) || null;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { stdio: "inherit", ...options });
  if (result.status !== 0) {
    throw new Error(`${path.basename(command)} failed with status ${result.status}`);
  }
}

function runText(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
  if (result.status !== 0) {
    throw new Error(`${path.basename(command)} failed with status ${result.status}`);
  }
  return result.stdout.trim();
}

const here = __dirname;
const homeDir = os.homedir();
const narrations = JSON.parse(fs.readFileSync(path.join(here, "narrations.json"), "utf8"));
const audioDir = path.join(here, "audio");
const tmpDir = path.join(audioDir, ".tmp");
const renderDir = path.join(here, "renders");
const force = process.argv.includes("--force");

const voice = process.env.SAPI_VOICE || "Microsoft Zira Desktop";
const rate = Number(process.env.SAPI_RATE || 0);
const powershell = process.env.POWERSHELL_PATH || commandExists("powershell.exe") || commandExists("pwsh.exe");
const ffmpeg = process.env.FFMPEG_PATH || commandExists("ffmpeg") || path.join(homeDir, "bin", "ffmpeg.exe");
const ffprobe = process.env.FFPROBE_PATH || commandExists("ffprobe") || path.join(homeDir, "bin", "ffprobe.exe");

if (!powershell || !fs.existsSync(powershell)) throw new Error("PowerShell was not found");
if (!ffmpeg || !fs.existsSync(ffmpeg)) throw new Error("ffmpeg was not found");
if (!ffprobe || !fs.existsSync(ffprobe)) throw new Error("ffprobe was not found");

fs.mkdirSync(audioDir, { recursive: true });
fs.rmSync(tmpDir, { recursive: true, force: true });
fs.mkdirSync(tmpDir, { recursive: true });

const sapiScriptPath = path.join(tmpDir, "sapi-speak.ps1");
fs.writeFileSync(sapiScriptPath, `
param(
  [string]$TextPath,
  [string]$OutputPath,
  [string]$Voice,
  [int]$Rate
)
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  if ($Voice) { $synth.SelectVoice($Voice) }
  $synth.Rate = $Rate
  $synth.SetOutputToWaveFile($OutputPath)
  $text = Get-Content -LiteralPath $TextPath -Raw
  $synth.Speak($text)
} finally {
  $synth.Dispose()
}
`, "utf8");

for (const [index, item] of narrations.entries()) {
  const sceneNo = String(index + 1).padStart(2, "0");
  const textPath = path.join(tmpDir, `scene-${sceneNo}.txt`);
  const mediaPath = path.join(audioDir, `scene-${sceneNo}.wav`);

  if (!force && fs.existsSync(mediaPath)) {
    continue;
  }

  fs.writeFileSync(textPath, item.voiceover, "utf8");
  run(powershell, [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", sapiScriptPath,
    textPath,
    mediaPath,
    voice,
    String(rate)
  ]);
}

function durationSeconds(filePath) {
  const output = runText(ffprobe, [
    "-v", "error",
    "-show_entries", "format=duration",
    "-of", "default=nw=1:nk=1",
    filePath
  ]);
  return Number(Number(output).toFixed(2));
}

function concatAudio(sceneIndexes, outPath) {
  const listPath = path.join(tmpDir, `${path.basename(outPath, ".mp3")}.txt`);
  const lines = sceneIndexes.map((sceneIndex) => {
    const sceneNo = String(sceneIndex + 1).padStart(2, "0");
    const audioPath = path.join(audioDir, `scene-${sceneNo}.wav`).replace(/\\/g, "/").replace(/'/g, "'\\''");
    return `file '${audioPath}'`;
  });
  fs.writeFileSync(listPath, `${lines.join("\n")}\n`, "utf8");
  run(ffmpeg, [
    "-y",
    "-hide_banner",
    "-loglevel", "error",
    "-f", "concat",
    "-safe", "0",
    "-i", listPath,
    "-codec:a", "libmp3lame",
    "-q:a", "2",
    outPath
  ]);
}

function padAudio(inputAudio, outputAudio, targetSeconds) {
  run(ffmpeg, [
    "-y",
    "-hide_banner",
    "-loglevel", "error",
    "-i", inputAudio,
    "-af", "apad",
    "-t", String(targetSeconds),
    "-codec:a", "libmp3lame",
    "-q:a", "2",
    outputAudio
  ]);
}

function muxVideo(videoPath, audioPath) {
  const tmpVideo = `${videoPath}.tmp.mp4`;
  run(ffmpeg, [
    "-y",
    "-hide_banner",
    "-loglevel", "error",
    "-i", videoPath,
    "-i", audioPath,
    "-map", "0:v:0",
    "-map", "1:a:0",
    "-c:v", "copy",
    "-c:a", "aac",
    "-b:a", "192k",
    "-shortest",
    tmpVideo
  ]);
  fs.renameSync(tmpVideo, videoPath);
}

const jobs = [
  { name: "full-demo", scenes: narrations.map((_, index) => index), video: "full-demo.mp4" },
  { name: "segment-01-mechanism", scenes: [0, 1, 2], video: "segment-01-mechanism.mp4" },
  { name: "segment-02-onchain-proof", scenes: [3, 4, 5], video: "segment-02-onchain-proof.mp4" },
  { name: "segment-03-market-path", scenes: [6, 7], video: "segment-03-market-path.mp4" }
];

const report = [];

for (const job of jobs) {
  const videoPath = path.join(renderDir, job.video);
  const rawAudio = path.join(audioDir, `${job.name}-voiceover-raw.mp3`);
  const paddedAudio = path.join(audioDir, `${job.name}-voiceover.mp3`);
  const videoSeconds = durationSeconds(videoPath);

  concatAudio(job.scenes, rawAudio);
  padAudio(rawAudio, paddedAudio, videoSeconds);
  muxVideo(videoPath, paddedAudio);

  report.push({
    video: path.relative(here, videoPath).replace(/\\/g, "/"),
    audio: path.relative(here, paddedAudio).replace(/\\/g, "/"),
    voice,
    rate,
    videoSeconds,
    audioSeconds: durationSeconds(paddedAudio)
  });
}

fs.rmSync(tmpDir, { recursive: true, force: true });
for (const name of fs.readdirSync(audioDir)) {
  if (/^scene-\d+\.wav$/.test(name) || /-voiceover-raw\.mp3$/.test(name)) {
    fs.rmSync(path.join(audioDir, name), { force: true });
  }
}
fs.writeFileSync(path.join(audioDir, "voiceover-report.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
console.log(JSON.stringify(report, null, 2));
