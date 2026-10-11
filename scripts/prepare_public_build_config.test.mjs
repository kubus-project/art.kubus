import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, copyFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

for (const flag of [undefined, 'false', 'true', 'TRUE', 'invalid']) {
  test(`public build Community flag ${flag ?? 'default'}`, () => {
    const root = mkdtempSync(join(tmpdir(), 'kubus-community-build-'));
    try {
      mkdirSync(join(root, 'scripts'));
      mkdirSync(join(root, 'ios', 'Flutter'), { recursive: true });
      copyFileSync(new URL('./prepare_public_build_config.mjs', import.meta.url), join(root, 'scripts', 'prepare_public_build_config.mjs'));
      const env = { ...process.env, KUBUS_BACKEND_URL: 'https://api.example.test',
        KUBUS_GOOGLE_CLIENT_ID: 'public-client', KUBUS_GOOGLE_WEB_CLIENT_ID: 'public-web-client',
        KUBUS_GOOGLE_IOS_CLIENT_ID: 'public-ios.apps.googleusercontent.com' };
      delete env.KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED;
      delete env.KUBUS_APP_VERSION;
      delete env.KUBUS_BUILD_NUMBER;
      delete env.KUBUS_BUILD_DATE;
      if (flag !== undefined) env.KUBUS_COMMUNITY_MULTI_MEDIA_ENABLED = flag;
      const result = spawnSync(process.execPath, [join(root, 'scripts', 'prepare_public_build_config.mjs')], { env, encoding: 'utf8' });
      assert.equal(result.status, flag === 'invalid' ? 1 : 0, result.stderr);
      if (flag === 'invalid') return;
      const defines = JSON.parse(readFileSync(join(root, '.dart_tool', 'public-build-defines.json')));
      // Enabled unless a build explicitly passes false (the rollback switch).
      assert.equal(defines.COMMUNITY_MULTI_MEDIA_ENABLED, flag === undefined ? true : flag.toLowerCase() === 'true');
      assert.equal(typeof defines.COMMUNITY_MULTI_MEDIA_ENABLED, 'boolean');
      assert.equal(defines.KUBUS_BACKEND_URL, env.KUBUS_BACKEND_URL);
      assert.equal(defines.ANALYTICS_APP_ENABLED, true);
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}

for (const flag of [undefined, 'false', 'true', 'invalid']) {
  test(`public build Community video autoplay ${flag ?? 'default'}`, () => {
    const root = mkdtempSync(join(tmpdir(), 'kubus-autoplay-build-'));
    try {
      mkdirSync(join(root, 'scripts'));
      mkdirSync(join(root, 'ios', 'Flutter'), { recursive: true });
      copyFileSync(new URL('./prepare_public_build_config.mjs', import.meta.url), join(root, 'scripts', 'prepare_public_build_config.mjs'));
      const env = { ...process.env, KUBUS_BACKEND_URL: 'https://api.example.test',
        KUBUS_GOOGLE_CLIENT_ID: 'public-client', KUBUS_GOOGLE_WEB_CLIENT_ID: 'public-web-client',
        KUBUS_GOOGLE_IOS_CLIENT_ID: 'public-ios.apps.googleusercontent.com' };
      delete env.KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED;
      delete env.KUBUS_APP_VERSION;
      delete env.KUBUS_BUILD_NUMBER;
      delete env.KUBUS_BUILD_DATE;
      if (flag !== undefined) env.KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED = flag;
      const result = spawnSync(process.execPath, [join(root, 'scripts', 'prepare_public_build_config.mjs')], { env, encoding: 'utf8' });
      assert.equal(result.status, flag === 'invalid' ? 1 : 0, result.stderr);
      if (flag === 'invalid') return;
      const defines = JSON.parse(readFileSync(join(root, '.dart_tool', 'public-build-defines.json')));
      // On by default in every build; a build passes false only as a kill switch.
      assert.equal(defines.COMMUNITY_VIDEO_AUTOPLAY_ENABLED, flag === undefined ? true : flag === 'true');
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}

const workflow = (name) => readFileSync(new URL(`../.github/workflows/${name}`, import.meta.url), 'utf8');

for (const name of ['web-artifact.yml', 'deploy-development.yml', 'release-production.yml']) {
  test(`${name} defaults Community multi-media to enabled`, () => {
    const text = workflow(name);
    assert.match(text, /community_multi_media_enabled:[\s\S]*?required: false\s+default: true\s+type: boolean/);
  });
}

test('development push builds are enabled and only a manual dispatch can opt out', () => {
  // A push carries no inputs, so a bare `inputs.x == true` would silently build
  // the disabled variant.
  assert.match(
    workflow('deploy-development.yml'),
    /community_multi_media_enabled: \$\{\{ github\.event_name != 'workflow_dispatch' \|\| inputs\.community_multi_media_enabled \}\}/,
  );
});

test('the artifact records the capability it was built with', () => {
  assert.match(workflow('web-artifact.yml'), /kubus-community-build\.json[\s\S]*COMMUNITY_MULTI_MEDIA_ENABLED: defines\.COMMUNITY_MULTI_MEDIA_ENABLED/);
});

for (const flag of [undefined, 'false', 'true', 'invalid']) {
  test(`public build Community video posters ${flag ?? 'default'}`, () => {
    const root = mkdtempSync(join(tmpdir(), 'kubus-posters-build-'));
    try {
      mkdirSync(join(root, 'scripts'));
      mkdirSync(join(root, 'ios', 'Flutter'), { recursive: true });
      copyFileSync(new URL('./prepare_public_build_config.mjs', import.meta.url), join(root, 'scripts', 'prepare_public_build_config.mjs'));
      const env = { ...process.env, KUBUS_BACKEND_URL: 'https://api.example.test',
        KUBUS_GOOGLE_CLIENT_ID: 'public-client', KUBUS_GOOGLE_WEB_CLIENT_ID: 'public-web-client',
        KUBUS_GOOGLE_IOS_CLIENT_ID: 'public-ios.apps.googleusercontent.com' };
      delete env.KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED;
      delete env.KUBUS_APP_VERSION;
      delete env.KUBUS_BUILD_NUMBER;
      delete env.KUBUS_BUILD_DATE;
      if (flag !== undefined) env.KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED = flag;
      const result = spawnSync(process.execPath, [join(root, 'scripts', 'prepare_public_build_config.mjs')], { env, encoding: 'utf8' });
      assert.equal(result.status, flag === 'invalid' ? 1 : 0, result.stderr);
      if (flag === 'invalid') return;
      const defines = JSON.parse(readFileSync(join(root, '.dart_tool', 'public-build-defines.json')));
      // On by default; a build passes false only as a kill switch for poster capture and upload.
      assert.equal(defines.COMMUNITY_VIDEO_POSTERS_ENABLED, flag === undefined ? true : flag === 'true');
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}

// An unset repository variable reaches the script as an empty string, which must mean the default.
test('an empty repository variable keeps both video switches on', () => {
  const root = mkdtempSync(join(tmpdir(), 'kubus-empty-vars-'));
  try {
    mkdirSync(join(root, 'scripts'));
    mkdirSync(join(root, 'ios', 'Flutter'), { recursive: true });
    copyFileSync(new URL('./prepare_public_build_config.mjs', import.meta.url), join(root, 'scripts', 'prepare_public_build_config.mjs'));
    const env = { ...process.env, KUBUS_BACKEND_URL: 'https://api.example.test',
      KUBUS_GOOGLE_CLIENT_ID: 'public-client', KUBUS_GOOGLE_WEB_CLIENT_ID: 'public-web-client',
      KUBUS_GOOGLE_IOS_CLIENT_ID: 'public-ios.apps.googleusercontent.com',
      KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED: '', KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED: '' };
    const result = spawnSync(process.execPath, [join(root, 'scripts', 'prepare_public_build_config.mjs')], { env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const defines = JSON.parse(readFileSync(join(root, '.dart_tool', 'public-build-defines.json')));
    assert.equal(defines.COMMUNITY_VIDEO_AUTOPLAY_ENABLED, true);
    assert.equal(defines.COMMUNITY_VIDEO_POSTERS_ENABLED, true);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// Every release path that runs the prepare step must map both repository variables.
for (const [name, expected] of [['web-artifact.yml', 1], ['mobile-release.yml', 2]]) {
  test(`${name} maps the video repository variables into every prepare step`, () => {
    const text = workflow(name);
    const autoplay = 'KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED: ${{ vars.KUBUS_COMMUNITY_VIDEO_AUTOPLAY_ENABLED }}';
    const posters = 'KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED: ${{ vars.KUBUS_COMMUNITY_VIDEO_POSTERS_ENABLED }}';
    assert.equal(text.split(autoplay).length - 1, expected);
    assert.equal(text.split(posters).length - 1, expected);
  });
}

test('the artifact records both video switches it was built with', () => {
  assert.match(workflow('web-artifact.yml'), /COMMUNITY_VIDEO_AUTOPLAY_ENABLED: defines\.COMMUNITY_VIDEO_AUTOPLAY_ENABLED, COMMUNITY_VIDEO_POSTERS_ENABLED: defines\.COMMUNITY_VIDEO_POSTERS_ENABLED/);
});
