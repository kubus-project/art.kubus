import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const workerPath = resolve(process.cwd(), 'build', 'web', 'flutter_service_worker.js');
const worker = readFileSync(workerPath, 'utf8');

const required = [
  /registration\.unregister\(\)/,
  /addEventListener\(['"]install['"]/,
  /addEventListener\(['"]activate['"]/,
];
const forbidden = [
  /addEventListener\(['"]fetch['"]/,
  /\bRESOURCES\b/,
  /flutter-app-cache/,
  /index\.html/,
  /cache\.put\(/,
];

for (const pattern of required) {
  if (!pattern.test(worker)) {
    throw new Error(`Service worker tombstone is missing ${pattern}`);
  }
}
for (const pattern of forbidden) {
  if (pattern.test(worker)) {
    throw new Error(`Service worker must not intercept canonical SSR routes: ${pattern}`);
  }
}

console.log('Flutter service worker is an unregister-only tombstone.');
