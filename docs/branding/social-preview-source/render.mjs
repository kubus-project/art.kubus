// Renders index.html to ../social-preview.png (1280x640, DSF 1) with Playwright.
//   node docs/branding/social-preview-source/render.mjs
// Then optimise if the PNG is over ~400 KB:  python docs/branding/social-preview-source/optimize.py
// The capture comes from scripts/qa/readme_screenshots_capture.mjs (scenario map-card-desktop-dark) cropped by hand into capture/.
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.resolve(here, '../../../scripts/qa/package.json'));
const { chromium } = require('playwright');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 640 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(path.join(here, 'index.html')).href);
await page.evaluate(() => document.fonts.ready);
await page.waitForFunction(() => [...document.images].every((i) => i.complete && i.naturalWidth > 0));
const fonts = await page.evaluate(() => ({
  upright: document.fonts.check('400 20px "Sofia Sans"'),
  italicHeavy: document.fonts.check('italic 900 20px "Sofia Sans"'),
  kubusStyle: getComputedStyle(document.querySelector('.kubus')).fontStyle,
  kubusWeight: getComputedStyle(document.querySelector('.kubus')).fontWeight,
}));
if (!fonts.upright || !fonts.italicHeavy || fonts.kubusStyle !== 'italic') throw new Error(`fonts not ready: ${JSON.stringify(fonts)}`);
await page.screenshot({ path: path.join(here, '../social-preview.png'), clip: { x: 0, y: 0, width: 1280, height: 640 } });
await browser.close();
console.log('rendered', JSON.stringify(fonts));
