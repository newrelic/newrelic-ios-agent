// Lays simulator screenshots next to the replay rendered at the same moment.
//   node scripts/compare.mjs <render-dir> <out-dir> <shot.png>...
// Shots must be named <label>_<epochMs>.png; render-dir is render-replay.mjs output.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const [renderDir, outDir, ...shots] = process.argv.slice(2);
const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const events = JSON.parse(fs.readFileSync(path.join(renderDir, 'events.json'), 'utf8'));
const start = events[0].timestamp;
fs.mkdirSync(outDir, { recursive: true });

for (const shot of shots) {
  const [, label, ms] = path.basename(shot).match(/^(.*)_(\d+)\.png$/);
  const replay = path.resolve(renderDir, `t${String(Number(ms) - start).padStart(7, '0')}.png`);
  if (!fs.existsSync(replay)) continue;
  const html = `<!doctype html><meta charset="utf-8"><body style="margin:0;display:flex;gap:8px;background:#888;font:14px sans-serif">
    <figure style="margin:0"><figcaption>device: ${label}</figcaption><img src="file://${path.resolve(shot)}" width="440"></figure>
    <figure style="margin:0"><figcaption>replay</figcaption><img src="file://${replay}" width="440"></figure></body>`;
  const htmlPath = path.resolve(outDir, `${label}.html`);
  fs.writeFileSync(htmlPath, html);
  execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--timeout=1500',
    `--user-data-dir=${path.resolve(outDir, '.chrome-profile')}`, '--allow-file-access-from-files',
    '--window-size=900,990', `--screenshot=${path.resolve(outDir, label + '.png')}`, `file://${htmlPath}`],
    { stdio: 'ignore', timeout: 30000 });
  fs.unlinkSync(htmlPath);
  console.log(path.resolve(outDir, label + '.png'));
}
fs.rmSync(path.resolve(outDir, '.chrome-profile'), { recursive: true, force: true });
