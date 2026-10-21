// Usage: NODE_PATH=<global node_modules> node render.mjs out.mp4 [fps]
// Renders index.html frame by frame (deterministic, audio-independent) and muxes the song with ffmpeg.
import { createRequire } from 'module';
import { spawn } from 'child_process';
import path from 'path';
const { chromium } = createRequire(import.meta.url)('playwright');
const out = process.argv[2] || 'mv.mp4', fps = +(process.argv[3] || 30), DURATION = 77.0;
const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-c:v', 'mjpeg', '-framerate', String(fps), '-i', '-',
  '-i', 'assets/song.m4a', '-map', '0:v', '-map', '1:a', '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
page.on('pageerror', e => console.error('page error:', e.message));
await page.goto('file://' + path.resolve('index.html') + '?render=1');
await page.evaluate(() => window.mvReady);
const n = Math.round(DURATION * fps);
for (let i = 0; i < n; i++) {
  const b64 = await page.evaluate(t => { renderAt(t); return document.getElementById('cv').toDataURL('image/jpeg', .95).split(',')[1]; }, i / fps);
  if (!ff.stdin.write(Buffer.from(b64, 'base64'))) await new Promise(r => ff.stdin.once('drain', r));
  if (i % 300 === 0) console.log(`frame ${i}/${n}`);
}
ff.stdin.end();
await browser.close();
await new Promise(r => ff.on('close', r));
console.log('done:', out);
