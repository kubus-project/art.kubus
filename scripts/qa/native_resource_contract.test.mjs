import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const read = (path) => readFileSync(resolve(repoRoot, path), 'utf8');

function plistString(plist, key) {
  const keyTag = `<key>${key}</key>`;
  const keyAt = plist.indexOf(keyTag);
  assert.notEqual(keyAt, -1, `Info.plist is missing ${key}`);
  const value = plist.slice(keyAt + keyTag.length).match(/^\s*<string>(.*?)<\/string>/s);
  assert.ok(value, `Info.plist ${key} must have a string value`);
  return value[1];
}

function pngDimensions(path) {
  const image = readFileSync(path);
  assert.equal(image.toString('hex', 0, 8), '89504e470d0a1a0a', `${path} must be a PNG`);
  assert.equal(image.toString('ascii', 12, 16), 'IHDR', `${path} must have a PNG header`);
  return {
    width: image.readUInt32BE(16),
    height: image.readUInt32BE(20),
    bitDepth: image[24],
    colorType: image[25],
  };
}

function xcconfigValue(config, key) {
  return config.match(new RegExp(`^${key}=([^\\r\\n]+)$`, 'm'))?.[1]?.trim();
}

test('iOS installed branding and foreground location purpose are configured', () => {
  const plist = read('ios/Runner/Info.plist');
  const debug = read('ios/Flutter/Debug.xcconfig');
  const release = read('ios/Flutter/Release.xcconfig');

  assert.equal(plistString(plist, 'CFBundleDisplayName'), 'art.kubus');
  assert.equal(plistString(plist, 'CFBundleName'), 'art.kubus');
  assert.equal(plistString(plist, 'CFBundleIdentifier'), '$(PRODUCT_BUNDLE_IDENTIFIER)');
  for (const config of [debug, release]) {
    assert.equal(xcconfigValue(config, 'KUBUS_IOS_BUNDLE_ID'), 'com.art.kubus');
  }

  const purpose = plistString(plist, 'NSLocationWhenInUseUsageDescription');
  assert.match(purpose, /location/i);
  assert.match(purpose, /nearby artworks/i);
  assert.doesNotMatch(plist, /NSLocationAlways(?:AndWhenInUse)?UsageDescription/);
});

test('iOS Google sign-in client and callback configuration remain connected', () => {
  const plist = read('ios/Runner/Info.plist');
  const debug = read('ios/Flutter/Debug.xcconfig');
  const release = read('ios/Flutter/Release.xcconfig');

  assert.equal(plistString(plist, 'GIDClientID'), '$(KUBUS_GOOGLE_IOS_CLIENT_ID)');
  assert.equal(plistString(plist, 'GIDServerClientID'), '$(KUBUS_GOOGLE_SERVER_CLIENT_ID)');
  const callbackScheme = plist.match(/<key>CFBundleURLSchemes<\/key>\s*<array>\s*<string>(.*?)<\/string>/s)?.[1];
  assert.equal(callbackScheme, '$(KUBUS_GOOGLE_REVERSED_IOS_CLIENT_ID)');

  for (const config of [debug, release]) {
    const iosClientId = xcconfigValue(config, 'KUBUS_GOOGLE_IOS_CLIENT_ID');
    const serverClientId = xcconfigValue(config, 'KUBUS_GOOGLE_SERVER_CLIENT_ID');
    const reversedClientId = xcconfigValue(config, 'KUBUS_GOOGLE_REVERSED_IOS_CLIENT_ID');
    assert.ok(iosClientId?.endsWith('.apps.googleusercontent.com'), 'iOS OAuth client ID must be configured');
    assert.ok(serverClientId?.endsWith('.apps.googleusercontent.com'), 'server OAuth client ID must be configured');
    assert.ok(reversedClientId?.startsWith('com.googleusercontent.apps.'), 'Google callback scheme must be configured');
    const expectedReversedId = `com.googleusercontent.apps.${iosClientId.slice(0, -'.apps.googleusercontent.com'.length)}`;
    assert.ok(reversedClientId === expectedReversedId, 'Google callback scheme must match the iOS OAuth client');
  }
});

test('native launcher icon catalogs package the approved logo at each required size', () => {
  const project = read('ios/Runner.xcodeproj/project.pbxproj');
  const catalog = JSON.parse(read('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'));
  assert.match(project, /ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*AppIcon;/);

  for (const entry of catalog.images) {
    assert.ok(entry.filename, 'every app icon catalog entry must name a packaged image');
    const path = resolve(repoRoot, 'ios/Runner/Assets.xcassets/AppIcon.appiconset', entry.filename);
    assert.ok(existsSync(path), `iOS app icon ${entry.filename} must exist`);
    const logicalSize = Number(entry.size.split('x')[0]);
    const scale = Number(entry.scale.replace('x', ''));
    const expectedPixels = Math.round(logicalSize * scale);
    const png = pngDimensions(path);
    assert.deepEqual([png.width, png.height], [expectedPixels, expectedPixels], `${entry.filename} dimensions`);
    assert.equal(png.bitDepth, 8, `${entry.filename} must use 8-bit channels`);
    if (entry.idiom === 'ios-marketing') {
      assert.equal(png.colorType, 2, 'the iOS marketing icon must be opaque RGB PNG');
    }
  }

  const manifest = read('android/app/src/main/AndroidManifest.xml');
  assert.match(manifest, /android:label="art\.kubus"/);
  assert.match(manifest, /android:icon="@mipmap\/ic_launcher"/);
  assert.match(manifest, /android\.permission\.ACCESS_FINE_LOCATION/);
  assert.match(manifest, /android\.permission\.ACCESS_COARSE_LOCATION/);

  const androidSizes = new Map([
    ['mipmap-mdpi', 48],
    ['mipmap-hdpi', 72],
    ['mipmap-xhdpi', 96],
    ['mipmap-xxhdpi', 144],
    ['mipmap-xxxhdpi', 192],
  ]);
  for (const [density, expectedPixels] of androidSizes) {
    const path = resolve(repoRoot, 'android/app/src/main/res', density, 'ic_launcher.png');
    const png = pngDimensions(path);
    assert.deepEqual([png.width, png.height], [expectedPixels, expectedPixels], `${density} icon dimensions`);
    assert.equal(png.colorType, 2, `${density} launcher icon must be opaque RGB`);
  }
});
