import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const required = [
  'KUBUS_BACKEND_URL',
  'KUBUS_GOOGLE_CLIENT_ID',
  'KUBUS_GOOGLE_WEB_CLIENT_ID',
  'KUBUS_GOOGLE_IOS_CLIENT_ID',
];
const optional = ['KUBUS_WALLETCONNECT_PROJECT_ID'];
const buildMetadata = [
  'KUBUS_APP_VERSION',
  'KUBUS_BUILD_NUMBER',
  'KUBUS_BUILD_DATE',
];

const missing = required.filter((name) => !(process.env[name] || '').trim());
if (missing.length > 0) {
  console.error(`Missing required public build configuration: ${missing.join(', ')}`);
  process.exit(1);
}

let backendUrl;
try {
  backendUrl = new URL(process.env.KUBUS_BACKEND_URL);
} catch {
  console.error('KUBUS_BACKEND_URL must be an absolute URL.');
  process.exit(1);
}
if (!['https:', 'http:'].includes(backendUrl.protocol)) {
  console.error('KUBUS_BACKEND_URL must use HTTP or HTTPS.');
  process.exit(1);
}

const values = Object.fromEntries([
  ...required.map((name) => [name, process.env[name].trim()]),
  ...optional.map((name) => [name, (process.env[name] || '').trim()]),
]);
const suppliedBuildMetadata = Object.fromEntries(
  buildMetadata.map((name) => [name, (process.env[name] || '').trim()]),
);
const suppliedBuildMetadataCount = Object.values(suppliedBuildMetadata).filter(Boolean).length;
if (suppliedBuildMetadataCount > 0 && suppliedBuildMetadataCount !== buildMetadata.length) {
  console.error('CI build metadata must provide version, build number, and build date together.');
  process.exit(1);
}
if (suppliedBuildMetadataCount === buildMetadata.length) {
  if (!/^\d+\.\d+\.\d+$/.test(suppliedBuildMetadata.KUBUS_APP_VERSION)) {
    console.error('KUBUS_APP_VERSION must use X.Y.Z.');
    process.exit(1);
  }
  if (!/^\d+$/.test(suppliedBuildMetadata.KUBUS_BUILD_NUMBER)) {
    console.error('KUBUS_BUILD_NUMBER must be an integer.');
    process.exit(1);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(suppliedBuildMetadata.KUBUS_BUILD_DATE)) {
    console.error('KUBUS_BUILD_DATE must use YYYY-MM-DD.');
    process.exit(1);
  }
  Object.assign(values, suppliedBuildMetadata);
}
values.KUBUS_ENABLE_WEB_SEMANTICS = false;

const outputPath = resolve(rootDir, '.dart_tool', 'public-build-defines.json');
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(values, null, 2)}\n`, 'utf8');

if (process.argv.includes('--web')) {
  const indexPath = resolve(rootDir, 'web', 'index.html');
  const original = readFileSync(indexPath, 'utf8');
  const pattern = /(<meta name="google-signin-client_id" content=")[^"]*(">)/;
  if (!pattern.test(original)) {
    console.error('google-signin-client_id meta tag not found in web/index.html.');
    process.exit(1);
  }
  writeFileSync(
    indexPath,
    original.replace(
      pattern,
      (_match, prefix, suffix) => `${prefix}${values.KUBUS_GOOGLE_WEB_CLIENT_ID}${suffix}`,
    ),
    'utf8',
  );
}

console.log(`Public build configuration written to ${outputPath}.`);
