import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';
import { codePoints, verifyCommunityContract } from './verify_community_backend_contract.mjs';

// A stand-in for the create route: authenticates, then validates like the real
// validator does, with a configurable caption limit.
function server({ limit }) {
  return new Promise((resolve) => {
    const s = http.createServer((req, res) => {
      let raw = '';
      req.on('data', (c) => (raw += c));
      req.on('end', () => {
        res.setHeader('content-type', 'application/json');
        if (req.headers.authorization !== 'Bearer good') {
          res.statusCode = 401;
          return res.end(JSON.stringify({ success: false }));
        }
        const body = JSON.parse(raw || '{}');
        const details = [];
        if (codePoints(body.content || '') > limit) {
          details.push({ field: 'content', message: `Content must be 1-${limit} characters` });
        }
        const urls = body.mediaUrls ?? [];
        if (urls.length > 10) details.push({ field: 'mediaUrls', message: 'Media URLs must contain at most 10 items' });
        if (urls.some((u) => !/^https?:\/\//.test(u))) details.push({ field: 'mediaUrls[0]', message: 'Media URL is not an accepted reference' });
        res.statusCode = details.length ? 400 : 201;
        res.end(JSON.stringify(details.length ? { success: false, error: 'Validation failed', details } : { success: true }));
      });
    });
    s.listen(0, '127.0.0.1', () => resolve(s));
  });
}

const base = (s) => `http://127.0.0.1:${s.address().port}`;

test('a backend with the 2200 contract is compatible', async () => {
  const s = await server({ limit: 2200 });
  const result = await verifyCommunityContract({ base: base(s), token: 'good' });
  s.close();
  assert.equal(result.ok, true, JSON.stringify(result.checks));
  assert.equal(result.verifiable, true);
});

test('the old 1000-character backend is reported incompatible', async () => {
  const s = await server({ limit: 1000 });
  const result = await verifyCommunityContract({ base: base(s), token: 'good' });
  s.close();
  assert.equal(result.ok, false);
  assert.ok(result.checks.some((c) => !c.pass && /rejected for length/.test(c.name) || !c.pass && /not rejected/.test(c.name)));
});

test('without a token only authentication is checked and the result is not verifiable', async () => {
  const s = await server({ limit: 2200 });
  const result = await verifyCommunityContract({ base: base(s), token: '' });
  s.close();
  assert.equal(result.verifiable, false);
  assert.equal(result.checks.length, 1);
  assert.equal(result.checks[0].pass, true);
});

test('code points count emoji once', () => {
  assert.equal(codePoints('😀'.repeat(2201)), 2201);
});
