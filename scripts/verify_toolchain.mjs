import { existsSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const expected = Object.freeze({
  node: '22.15.0',
  npm: '11.7.0',
  flutter: '3.44.2',
  dart: '3.12.2',
  javaMajor: '21',
  androidSdk: '36',
  androidBuildTools: '36.0.0',
  gradle: '8.14.3',
  gradleSha256: 'ed1a8d686605fd7c23bdf62c7fc7add1c5b23b2bbc3721e661934ef4a4911d7c',
  gradleWrapperJarSha256: '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172',
});

const failures = [];

function fail(message) {
  failures.push(message);
}

function readTrimmed(relativePath) {
  const path = resolve(rootDir, relativePath);
  if (!existsSync(path)) {
    fail(`${relativePath} is missing.`);
    return '';
  }
  return readFileSync(path, 'utf8').trim();
}

function expectEqual(label, actual, wanted) {
  if (actual !== wanted) {
    fail(`${label} must be ${wanted}; found ${actual || '<missing>'}.`);
  } else {
    console.log(`${label}: ${actual}`);
  }
}

function commandFor(name) {
  if (process.platform !== 'win32') return name;
  if (name === 'npm') return 'npm.cmd';
  if (name === 'flutter') {
    const localFlutter = 'C:\\dev\\flutter\\bin\\flutter.bat';
    return existsSync(localFlutter) ? localFlutter : 'flutter.bat';
  }
  return name;
}

function flutterCommand() {
  return process.env.FLUTTER_BIN?.trim() || commandFor('flutter');
}

let cachedFlutterConfig;
function flutterConfig() {
  if (cachedFlutterConfig !== undefined) return cachedFlutterConfig;
  const result = spawnSync(flutterCommand(), ['config', '--machine'], {
    cwd: rootDir,
    encoding: 'utf8',
    shell: process.platform === 'win32' && /\.(?:bat|cmd)$/i.test(flutterCommand()),
  });
  try {
    cachedFlutterConfig = result.status === 0 ? JSON.parse(result.stdout) : {};
  } catch {
    cachedFlutterConfig = {};
  }
  return cachedFlutterConfig;
}

function run(command, args) {
  const needsWindowsShell = process.platform === 'win32' && /\.(?:bat|cmd)$/i.test(command);
  const result = spawnSync(command, args, {
    cwd: rootDir,
    encoding: 'utf8',
    shell: needsWindowsShell,
  });
  if (result.error || result.status !== 0) {
    const detail = result.error?.message || result.stderr?.trim() || `exit ${result.status}`;
    fail(`${command} ${args.join(' ')} failed: ${detail}`);
    return null;
  }
  return `${result.stdout || ''}${result.stderr || ''}`.trim();
}

function verifyPins() {
  let fvm = {};
  try {
    fvm = JSON.parse(readTrimmed('.fvmrc'));
  } catch (error) {
    fail(`.fvmrc is invalid JSON: ${error.message}`);
  }
  expectEqual('.fvmrc Flutter', fvm.flutter, expected.flutter);
  expectEqual('.node-version', readTrimmed('.node-version'), expected.node);
  expectEqual('.nvmrc', readTrimmed('.nvmrc'), expected.node);
  expectEqual('.java-version', readTrimmed('.java-version'), expected.javaMajor);

  let packageJson = {};
  try {
    packageJson = JSON.parse(readTrimmed('package.json'));
  } catch (error) {
    fail(`package.json is invalid JSON: ${error.message}`);
  }
  expectEqual('packageManager', packageJson.packageManager, `npm@${expected.npm}`);
  expectEqual('engines.node', packageJson.engines?.node, expected.node);
  expectEqual('engines.npm', packageJson.engines?.npm, expected.npm);

  const wrapper = readTrimmed('android/gradle/wrapper/gradle-wrapper.properties');
  const distributionUrl = wrapper.match(/^distributionUrl=(.+)$/m)?.[1] || '';
  const distributionSha256 = wrapper.match(/^distributionSha256Sum=(.+)$/m)?.[1] || '';
  if (!distributionUrl.includes(`gradle-${expected.gradle}-all.zip`)) {
    fail(`Gradle wrapper must use ${expected.gradle}; found ${distributionUrl || '<missing>'}.`);
  } else {
    console.log(`Gradle wrapper: ${expected.gradle}`);
  }
  expectEqual('Gradle distribution SHA-256', distributionSha256, expected.gradleSha256);

  const wrapperJarPath = resolve(rootDir, 'android/gradle/wrapper/gradle-wrapper.jar');
  if (!existsSync(wrapperJarPath)) {
    fail('android/gradle/wrapper/gradle-wrapper.jar is missing.');
  } else {
    const wrapperJarSha256 = createHash('sha256')
      .update(readFileSync(wrapperJarPath))
      .digest('hex');
    expectEqual('Gradle wrapper JAR SHA-256', wrapperJarSha256, expected.gradleWrapperJarSha256);
  }
}

function verifyNode() {
  expectEqual('Node', process.versions.node, expected.node);
  const npmVersion = run(commandFor('npm'), ['--version']);
  if (npmVersion !== null) expectEqual('npm', npmVersion, expected.npm);
}

function verifyFlutter() {
  const output = run(flutterCommand(), [
    '--version',
    '--machine',
  ]);
  if (output === null) return;
  try {
    const version = JSON.parse(output);
    expectEqual('Flutter', version.frameworkVersion || version.flutterVersion, expected.flutter);
    expectEqual('Dart', version.dartSdkVersion, expected.dart);
  } catch (error) {
    fail(`Unable to parse Flutter version output: ${error.message}`);
  }
}

function verifyJava() {
  const configuredJdk = (process.env.JAVA_HOME || flutterConfig()['jdk-dir'] || '').trim();
  const javaExecutable = configuredJdk
    ? resolve(configuredJdk, 'bin', process.platform === 'win32' ? 'java.exe' : 'java')
    : 'java';
  const output = run(javaExecutable, ['-version']);
  if (output === null) return;
  const version = output.match(/version\s+"([^"]+)"/)?.[1] || output.match(/openjdk\s+([0-9][^\s]*)/)?.[1] || '';
  const major = version.startsWith('1.') ? version.split('.')[1] : version.split('.')[0];
  expectEqual('Java major', major, expected.javaMajor);
}

function androidSdkRoot() {
  const configured = (process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME || '').trim();
  if (configured) return configured;

  const localProperties = resolve(rootDir, 'android/local.properties');
  if (existsSync(localProperties)) {
    const encoded = readFileSync(localProperties, 'utf8').match(/^sdk\.dir=(.+)$/m)?.[1]?.trim() || '';
    if (encoded) return encoded.replace(/\\\\/g, '\\').replace(/\\:/g, ':');
  }
  return (flutterConfig()['android-sdk'] || '').trim();
}

function verifyAndroid() {
  verifyJava();
  const sdkRoot = androidSdkRoot();
  if (!sdkRoot) {
    fail('ANDROID_SDK_ROOT/ANDROID_HOME is not configured and android/local.properties has no sdk.dir.');
    return;
  }
  const platform = resolve(sdkRoot, 'platforms', `android-${expected.androidSdk}`, 'android.jar');
  const buildTools = resolve(sdkRoot, 'build-tools', expected.androidBuildTools);
  if (!existsSync(platform)) fail(`Android SDK ${expected.androidSdk} is missing at ${platform}.`);
  else console.log(`Android SDK: ${expected.androidSdk}`);
  if (!existsSync(buildTools)) fail(`Android build tools ${expected.androidBuildTools} are missing at ${buildTools}.`);
  else console.log(`Android build tools: ${expected.androidBuildTools}`);
}

const requested = new Set(process.argv.slice(2));
if (requested.size === 0 || requested.has('all')) {
  requested.clear();
  requested.add('node');
  requested.add('flutter');
  requested.add('android');
}

const valid = new Set(['node', 'flutter', 'android']);
for (const target of requested) {
  if (!valid.has(target)) {
    console.error(`Unknown toolchain target: ${target}`);
    process.exit(2);
  }
}

verifyPins();
if (requested.has('node')) verifyNode();
if (requested.has('flutter') || requested.has('android')) verifyFlutter();
if (requested.has('android')) verifyAndroid();

if (failures.length > 0) {
  console.error('\nToolchain verification failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('\nToolchain verification passed.');
