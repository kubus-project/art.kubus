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
