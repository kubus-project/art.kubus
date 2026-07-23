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
