// Usage: node preview.mjs out_dir t1 t2 ...   -> writes JPEG stills of the MV at those times
import { createRequire } from 'module';
const { chromium } = createRequire(import.meta.url)('playwright'); // set NODE_PATH if installed globally
import fs from 'fs'; import path from 'path';
const [out, ...ts] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const errs = []; page.on('pageerror', e => errs.push(e.message)); page.on('console', m => m.type() === 'error' && errs.push(m.text()));
await page.goto('file://' + path.resolve('index.html') + '?render=1');
await page.evaluate(() => window.mvReady);
for (const t of ts) {
  const data = await page.evaluate(t => { renderAt(+t); return document.getElementById('cv').toDataURL('image/jpeg', .8); }, t);
  fs.writeFileSync(path.join(out, `t${(+t).toFixed(1).padStart(5, '0')}.jpg`), Buffer.from(data.split(',')[1], 'base64'));
}
console.log(errs.length ? errs.join('\n') : 'no errors');
await browser.close();
