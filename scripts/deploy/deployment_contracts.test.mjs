import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, readFile, writeFile } from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, '..', '..');
const bashCandidates = process.platform === 'win32'
  ? [process.env.BASH_BIN, 'C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe']
  : [process.env.BASH_BIN, 'bash'];
const bash = bashCandidates.find(Boolean);

function run(command, args, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: rootDir,
      env: { ...process.env, ...env },
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`${command} exited ${code}\n${stdout}\n${stderr}`));
    });
  });
}

test('artifact preparation isolates staging indexing policy from production', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'kubus-artifact-'));
  const sha = '0123456789abcdef0123456789abcdef01234567';
  for (const environment of ['development', 'production']) {
    const directory = path.join(temp, environment);
    await mkdir(directory);
    await writeFile(path.join(directory, 'index.html'), '<html><script src="flutter_bootstrap.js"></script></html>');
    await writeFile(path.join(directory, '.htaccess'), '<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n');
    await run(process.execPath, [path.join(scriptDir, 'prepare_web_artifact.mjs'), '--environment', environment, '--source-sha', sha, '--directory', directory]);
    assert.equal((await readFile(path.join(directory, 'kubus-web-revision.txt'), 'utf8')).trim(), sha);
    const htaccess = await readFile(path.join(directory, '.htaccess'), 'utf8');
    if (environment === 'development') {
      assert.match(htaccess, /X-Robots-Tag "noindex, nofollow, noarchive"/);
      assert.equal(await readFile(path.join(directory, 'robots.txt'), 'utf8'), 'User-agent: *\nDisallow: /\n');
    } else {
      assert.doesNotMatch(htaccess, /X-Robots-Tag/);
    }
    assert.doesNotMatch(htaccess, /AuthType|AuthUserFile|KUBUS HOST DEVELOPMENT AUTH/);
  }
});

test('public artifact preparation rejects host-local authentication policy', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'kubus-artifact-auth-'));
  const sha = '0123456789abcdef0123456789abcdef01234567';
  await writeFile(path.join(temp, 'index.html'), '<html></html>');
  await writeFile(
    path.join(temp, '.htaccess'),
    'AuthType Basic\nAuthUserFile "/account-local/private/passwd"\nRequire valid-user\n',
  );
  for (const environment of ['development', 'production']) {
    await assert.rejects(
      run(process.execPath, [
        path.join(scriptDir, 'prepare_web_artifact.mjs'),
        '--environment',
        environment,
        '--source-sha',
        sha,
        '--directory',
        temp,
      ]),
      /source artifact must not contain host-local HTTP authentication policy/,
    );
  }
});

test('deployment target validation rejects host confusion and emits safe SHA paths', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'kubus-target-'));
  const output = path.join(temp, 'output');
  const common = {
    DEPLOYMENT_ENVIRONMENT: 'development',
    ENVIRONMENT_NAME: 'development',
    SOURCE_SHA: '0123456789abcdef0123456789abcdef01234567',
    SFTP_SERVER: 'staging-upload.example.net',
    SFTP_USERNAME: 'deploy-user',
    SFTP_PRIVATE_KEY: 'test-only-key',
    SFTP_HOST_FINGERPRINT: 'SHA256:test-only',
    SFTP_PORT: '22',
    WEB_SERVER_DIR: '/home/{SFTP_USERNAME}/dev.kubus.site',
    WEB_RELEASES_DIR: '/home/{SFTP_USERNAME}/.art-kubus-development-releases',
    WEB_SMOKE_URL: 'https://dev.kubus.site/',
    EXPECTED_DEPLOYMENT_HOST: 'staging-upload.example.net',
    RETAIN_RELEASE_COUNT: '3',
    GITHUB_OUTPUT: output,
  };
  await run(bash, [path.join(scriptDir, 'validate_deployment_target.sh')], common);
  const emitted = await readFile(output, 'utf8');
  assert.match(emitted, /incoming-0123456789abcdef0123456789abcdef01234567/);
  await assert.rejects(run(bash, [path.join(scriptDir, 'validate_deployment_target.sh')], { ...common, EXPECTED_DEPLOYMENT_HOST: 'production-upload.example.net', GITHUB_OUTPUT: path.join(temp, 'bad-output') }));
});

test('development smoke validates Basic Auth, revision, routes, and noindex without credentials in URLs', async () => {
  const username = 'stage-user';
  const password = 'stage-password';
  const sha = '89abcdef0123456789abcdef0123456789abcdef';
  const expectedAuth = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
  const bypassToken = 'ci-waf-bypass-token';
  const bypassHeaderSeen = new Set();
  const server = http.createServer((request, response) => {
    bypassHeaderSeen.add(request.headers['x-deploy-smoke'] ?? '(none)');
    if (request.headers.authorization !== expectedAuth) {
      response.writeHead(401, { 'WWW-Authenticate': 'Basic realm="staging"' });
      response.end('protected');
      return;
    }
    const headers = { 'X-Robots-Tag': 'noindex, nofollow, noarchive' };
    if (request.url === '/app') {
      response.writeHead(200, { ...headers, 'Content-Type': 'text/html' });
      response.end('<html><script src="flutter_bootstrap.js"></script></html>');
    } else if (request.url === '/kubus-web-revision.txt') {
      response.writeHead(200, headers);
      response.end(`${sha}\n`);
    } else if (request.url === '/robots.txt') {
      response.writeHead(200, headers);
      response.end('User-agent: *\nDisallow: /\n');
    } else if (request.url === '/en' || request.url === '/sl') {
      response.writeHead(200, { ...headers, 'Content-Type': 'text/html' });
      response.end('<html><link rel="canonical" href="https://app.kubus.site/en"></html>');
    } else {
      response.writeHead(404, headers);
      response.end('missing');
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const { port } = server.address();
    const result = await run(bash, [path.join(scriptDir, 'smoke_development_web.sh')], {
      WEB_SMOKE_URL: `http://127.0.0.1:${port}`,
      SOURCE_SHA: sha,
      HTTP_BASIC_USERNAME: username,
      HTTP_BASIC_PASSWORD: password,
      SMOKE_BYPASS_TOKEN: bypassToken,
    });
    assert.doesNotMatch(result.stdout + result.stderr, new RegExp(`${username}|${password}|${bypassToken}`));
    assert.ok(bypassHeaderSeen.has(bypassToken), 'smoke must send the X-Deploy-Smoke bypass header when the token is set');
    assert.ok(!bypassHeaderSeen.has('(none)'), 'every smoke request (incl. the unauthenticated probe) must carry the bypass header');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('development Basic Auth remains mandatory with and without the WAF bypass header', async () => {
  const username = 'contract-user';
  const password = 'contract-password';
  const expectedAuth = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
  const server = http.createServer((request, response) => {
    if (request.headers.authorization !== expectedAuth) {
      response.writeHead(401, { 'WWW-Authenticate': 'Basic realm="development"' });
      response.end('protected');
      return;
    }
    response.writeHead(200);
    response.end('ok');
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const { port } = server.address();
    const url = `http://127.0.0.1:${port}/app`;
    const cases = [
      { bypass: false, authenticated: false, status: 401 },
      { bypass: false, authenticated: true, status: 200 },
      { bypass: true, authenticated: false, status: 401 },
      { bypass: true, authenticated: true, status: 200 },
    ];
    for (const item of cases) {
      const headers = {};
      if (item.bypass) headers['X-Deploy-Smoke'] = 'test-bypass-only';
      if (item.authenticated) headers.Authorization = expectedAuth;
      const response = await fetch(url, { headers });
      assert.equal(response.status, item.status);
      if (!item.authenticated) assert.match(response.headers.get('www-authenticate') ?? '', /^Basic /);
    }
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('host-local policy is applied remotely without changing original artifact provenance', async () => {
  const release = await readFile(path.join(scriptDir, 'atomic_web_release.sh'), 'utf8');
  const action = await readFile(
    path.join(rootDir, '.github', 'actions', 'deploy-web-artifact', 'action.yml'),
    'utf8',
  );
  const artifactWorkflow = await readFile(
    path.join(rootDir, '.github', 'workflows', 'web-artifact.yml'),
    'utf8',
  );

  assert.match(release, /"\$HOME"\/\.htpasswds\/\*\/passwd/);
  assert.match(release, /write_host_policy_manifest/);
  assert.match(release, /application_htaccess_sha256/);
  assert.doesNotMatch(release, /DEV_HTPASSWD_FILE|\/home\//);
  assert.doesNotMatch(action + artifactWorkflow, /DEV_HTPASSWD_FILE|\/home\//);
  assert.match(
    action,
    /Apply and verify host-local development protection[\s\S]*?atomic_web_release\.sh" prepare[\s\S]*?Atomically promote prepared release[\s\S]*?atomic_web_release\.sh" promote/,
  );
  assert.match(release, /verify_artifact_release "\$candidate"[\s\S]*?apply_development_policy "\$candidate"/);
  assert.doesNotMatch(release, /(?:mv|cp).+SHA256SUMS|sha256sum.+>\s*["']?\$[^ \n]*SHA256SUMS/);
});

test('production smoke contract preserves routing, SEO, revision, takeover, and unknown-route checks', async () => {
  const source = await readFile(path.join(scriptDir, 'smoke_production_web.sh'), 'utf8');
  for (const required of [
    'root canonicalization expected 308',
    'kubus-web-revision.txt',
    'production robots.txt lacks the production sitemap',
    'unknown production route is not a real 404',
    'qa:public-takeover',
    'production_seo_contract.mjs',
  ]) assert.match(source, new RegExp(required.replaceAll('.', '\\.')));
  assert.doesNotMatch(source, /--user\s+https?:\/\/[^\s]*@/);
});

// --- Production WAF-bypass smoke contract -----------------------------------
//
// A deterministic origin that reproduces the production failure: the LiteSpeed/
// Imunify360 filter answers a "blocked" request with 415 and only lets a request
// through when it carries the exact X-Deploy-Smoke token.
//
//   mode 'exception-active'  -> correct token: real responses; else 415
//   mode 'exception-missing' -> always 415 (host rule not installed)
//   mode 'open'              -> always the real responses (no WAF)
function startWafOrigin({ token, mode, appBodyOverride }) {
  const seen = [];
  const server = http.createServer((request, response) => {
    const header = request.headers['x-deploy-smoke'];
    seen.push({ url: request.url, method: request.method, header: header ?? null });

    const authorized = header === token && token !== undefined && token !== '';
    const blocked = mode === 'exception-missing'
      || (mode === 'exception-active' && !authorized);
    if (blocked) {
      response.writeHead(415, { 'Content-Type': 'text/plain' });
      response.end('blocked by waf');
      return;
    }

    // Authorized (or open): production-like responses. Only the root probe and
    // /app are exercised by these tests; later assertions are covered elsewhere.
    if (request.url === '/') {
      response.writeHead(308, { Location: '/en' });
      response.end();
      return;
    }
    if (request.url === '/app') {
      response.writeHead(200, { 'Content-Type': 'text/html' });
      response.end(appBodyOverride ?? '<html><script src="flutter_bootstrap.js"></script></html>');
      return;
    }
    response.writeHead(404, { 'Content-Type': 'text/plain' });
    response.end('missing');
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      resolve({ server, seen, port: server.address().port });
    });
  });
}

const sha40 = 'abcdef0123456789abcdef0123456789abcdef01';
const fastRoot = { SMOKE_ROOT_ATTEMPTS: '2', SMOKE_ROOT_DELAY_SECONDS: '0' };

test('production smoke fails closed on a persistent WAF 415 and names the missing host rule', async () => {
  const token = 'prod-waf-token-DO-NOT-LEAK';
  const { server, seen, port } = await startWafOrigin({ token, mode: 'exception-missing' });
  try {
    const error = await run(bash, [path.join(scriptDir, 'smoke_production_web.sh')], {
      ...fastRoot,
      WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
      SOURCE_SHA: sha40,
      EXPECT_PUBLIC_FLUTTER_TAKEOVER: 'false',
      PUBLIC_CONTRACT_ARTWORK_ID: '00000000-0000-4000-8000-000000000000',
      SMOKE_BYPASS_TOKEN: token,
    }).then(() => null, (e) => e);

    assert.ok(error, 'smoke must fail closed when the origin persistently returns 415');
    // The failure is classified as a WAF block with the exception not installed,
    // never mistaken for an application regression.
    assert.match(error.message, /root canonicalization expected 308/);
    assert.match(error.message, /host WAF exception for X-Deploy-Smoke is NOT active/);
    // A 415 is never converted into a pass.
    assert.doesNotMatch(error.message, /Production web smoke passed/);
    // The token value never appears in any output.
    assert.doesNotMatch(error.message, new RegExp(token));
    // The runner still sent the bypass header on the root probe (plumbing works).
    assert.ok(
      seen.some((r) => r.url === '/' && r.header === token),
      'the root probe must carry the X-Deploy-Smoke header when the token is set',
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('production smoke sends the bypass header on every request and clears the WAF when the host honors it', async () => {
  const token = 'prod-waf-token-ANOTHER-SECRET';
  // Break /app so the smoke fails *after* the root probe: this proves the header
  // cleared the WAF on the root request and was resent on /app.
  const { server, seen, port } = await startWafOrigin({
    token,
    mode: 'exception-active',
    appBodyOverride: '<html>no bundle here</html>',
  });
  try {
    const error = await run(bash, [path.join(scriptDir, 'smoke_production_web.sh')], {
      ...fastRoot,
      WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
      SOURCE_SHA: sha40,
      EXPECT_PUBLIC_FLUTTER_TAKEOVER: 'false',
      PUBLIC_CONTRACT_ARTWORK_ID: '00000000-0000-4000-8000-000000000000',
      SMOKE_BYPASS_TOKEN: token,
    }).then(() => null, (e) => e);

    assert.ok(error, 'smoke must still fail on the broken /app response');
    // Root canonicalization passed (the WAF was cleared); the failure is the app.
    assert.doesNotMatch(error.message, /root canonicalization expected 308/);
    assert.match(error.message, /\/app does not serve Flutter/);
    assert.doesNotMatch(error.message, new RegExp(token));
    // Both the root probe and the /app request carried the header.
    assert.ok(seen.some((r) => r.url === '/' && r.header === token));
    assert.ok(seen.some((r) => r.url === '/app' && r.header === token));
    // No request was ever made without the header while the token was set.
    assert.ok(
      !seen.some((r) => r.header === null),
      'no smoke request may omit the bypass header when the token is configured',
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('production smoke sends no bypass header when the token is absent', async () => {
  // No token: every request must be header-free, and the failure must say so.
  const { server, seen, port } = await startWafOrigin({ token: undefined, mode: 'exception-active' });
  try {
    const error = await run(bash, [path.join(scriptDir, 'smoke_production_web.sh')], {
      ...fastRoot,
      WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
      SOURCE_SHA: sha40,
      EXPECT_PUBLIC_FLUTTER_TAKEOVER: 'false',
      PUBLIC_CONTRACT_ARTWORK_ID: '00000000-0000-4000-8000-000000000000',
      // SMOKE_BYPASS_TOKEN intentionally unset.
    }).then(() => null, (e) => e);

    assert.ok(error, 'smoke fails when the origin blocks a header-free runner');
    assert.match(error.message, /SMOKE_BYPASS_TOKEN is empty/);
    assert.ok(
      seen.every((r) => r.header === null),
      'no request may carry the bypass header when the token is unset',
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('waf smoke probe classifies each host state without leaking the token', async () => {
  const token = 'probe-token-STRICTLY-SECRET';
  const probe = path.join(scriptDir, 'waf_smoke_probe.sh');

  // 1. Host exception active + correct token -> reachable, exit 0.
  {
    const { server, port } = await startWafOrigin({ token, mode: 'exception-active' });
    try {
      const { stdout, stderr } = await run(bash, [probe], {
        WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
        SMOKE_BYPASS_TOKEN: token,
      });
      assert.match(stdout + stderr, /origin is reachable/);
      assert.doesNotMatch(stdout + stderr, new RegExp(token));
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }

  // 2. Host exception missing + token set -> not active, exit 1.
  {
    const { server, port } = await startWafOrigin({ token, mode: 'exception-missing' });
    try {
      const error = await run(bash, [probe], {
        WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
        SMOKE_BYPASS_TOKEN: token,
      }).then(() => null, (e) => e);
      assert.ok(error, 'probe must exit non-zero when the exception is not active');
      assert.match(error.message, /host WAF exception for X-Deploy-Smoke is NOT active/);
      assert.doesNotMatch(error.message, new RegExp(token));
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }

  // 3. Token unset -> reports the empty token, exit 1.
  {
    const { server, seen, port } = await startWafOrigin({ token: undefined, mode: 'exception-active' });
    try {
      const error = await run(bash, [probe], {
        WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
      }).then(() => null, (e) => e);
      assert.ok(error, 'probe must exit non-zero when the token is unset and the WAF blocks');
      assert.match(error.message, /SMOKE_BYPASS_TOKEN is empty/);
      assert.ok(seen.every((r) => r.header === null));
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }

  // 4. No WAF at all -> reachable and explicitly not a WAF block, exit 0.
  {
    const { server, port } = await startWafOrigin({ token: undefined, mode: 'open' });
    try {
      const { stdout, stderr } = await run(bash, [probe], {
        WEB_SMOKE_URL: `http://127.0.0.1:${port}/`,
      });
      assert.match(stdout + stderr, /not a WAF IP block/);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  }
});
