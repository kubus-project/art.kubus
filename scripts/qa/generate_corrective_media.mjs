// Deterministic synthetic QA clips. Output stays outside product assets.
import { mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
const output = path.resolve(process.argv[2] || 'output/qa/media-fixtures');
await mkdir(output, { recursive: true });
const ffmpeg = process.env.FFMPEG_BIN || 'ffmpeg';
function run(args) {
  const result = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', ...args], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr || result.error?.message || 'ffmpeg failed');
}
for (const [name, size] of Object.entries({ portrait: '180x320', landscape: '320x180', square: '240x240', ultrawide: '420x180' })) {
  const video = path.join(output, `${name}.webm`);
  run(['-f', 'lavfi', '-i', `testsrc2=size=${size}:rate=24`, '-t', '8', '-c:v', 'libvpx', '-b:v', '160k', '-an', '-y', video]);
  run(['-i', video, '-frames:v', '1', '-y', path.join(output, `${name}.png`)]);
}
run(['-i', 'build/web/images/social-preview-default.webp', '-frames:v', '1', '-y', path.join(output, 'artwork.png')]);
console.log(output);
