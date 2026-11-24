// Replays captured agent frames with the real rrweb Replayer in headless
// Chrome and screenshots the replay at the requested offsets.
//   node scripts/render-replay.mjs <frames-dir> <out-dir> [offsetSeconds,...]
// Offsets above 1e12 are read as absolute epoch milliseconds.
// Without offsets, renders one screenshot per full/incremental snapshot event.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const [framesDir, outDir, offsetsArg] = process.argv.slice(2);
if (!framesDir || !outDir) {
  console.error('usage: node scripts/render-replay.mjs <frames-dir> <out-dir> [offsetSeconds,...]');
  process.exit(1);
}
const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const rrwebDir = path.resolve(path.dirname(require.resolve('rrweb')), '..');
const rrwebJs = fs.readFileSync(path.join(rrwebDir, 'dist/rrweb.umd.cjs'), 'utf8');
const rrwebCss = fs.readFileSync(path.join(rrwebDir, 'dist/style.css'), 'utf8');

// Merge every captured file, dropping duplicate events from overlapping copies.
const seen = new Set();
const events = [];
for (const file of fs.readdirSync(framesDir).filter(f => f.endsWith('.json'))) {
  for (const e of JSON.parse(fs.readFileSync(path.join(framesDir, file), 'utf8'))) {
    const key = JSON.stringify(e);
    if (!seen.has(key)) {
      seen.add(key);
      events.push(e);
    }
  }
}
// Stable sort keeps meta before the full snapshot that shares its timestamp.
events.sort((a, b) => a.timestamp - b.timestamp || (a.type === 4 ? -1 : b.type === 4 ? 1 : 0));
const start = events[0].timestamp;
const meta = events.find(e => e.type === 4);
const width = meta?.data.width ?? 400;
const height = meta?.data.height ?? 870;

const offsets = offsetsArg
  ? offsetsArg.split(',').map(s => {
      const v = parseFloat(s);
      return v > 1e12 ? v - start : Math.round(v * 1000);
    })
  : events.filter(e => e.type === 2 || e.type === 3 && e.data.source === 0).map(e => e.timestamp - start);

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'events.json'), JSON.stringify(events));
const summary = [];
for (const offset of [...new Set(offsets)].filter(o => o >= 0)) {
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${rrwebCss}
    html,body{margin:0;background:#fff}.replayer-mouse,.replayer-mouse-tail{display:none}</style></head>
    <body><div id="root"></div><script>${rrwebJs}</script><script>
    const events = ${JSON.stringify(events)};
    const r = new rrweb.Replayer(events, { root: document.getElementById('root'), mouseTail: false, showWarning: true });
    r.pause(${offset});
    </script></body></html>`;
  const name = `t${String(offset).padStart(7, '0')}`;
  const htmlPath = path.join(outDir, `${name}.html`);
  fs.writeFileSync(htmlPath, html);
  execFileSync(CHROME, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--timeout=4000',
    `--user-data-dir=${path.resolve(outDir, '.chrome-profile')}`,
    `--window-size=${width},${height}`, `--screenshot=${path.resolve(outDir, name + '.png')}`,
    `file://${path.resolve(htmlPath)}`,
  ], { stdio: 'ignore', timeout: 30000 });
  fs.unlinkSync(htmlPath);
  console.error(`rendered ${name}`);
  summary.push(`${name}.png  +${(offset / 1000).toFixed(1)}s`);
}
fs.rmSync(path.resolve(outDir, '.chrome-profile'), { recursive: true, force: true });
console.log(`${events.length} events, ${(events.at(-1).timestamp - start) / 1000}s\n${summary.join('\n')}`);
