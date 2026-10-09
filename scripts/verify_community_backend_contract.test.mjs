import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';
import { verifyCommunityContract } from './verify_community_backend_contract.mjs';

for (const status of [200, 404, 500]) {
  test(`HTTP ${status} cannot attest compatibility or create posts even with a token`, async (t) => {
    const requests = [];
    const server = http.createServer((req, res) => {
      requests.push({ method: req.method, path: req.url, authorization: req.headers.authorization });
      // Deliberately accepts ANY create request, without auth or validation.
      res.writeHead(req.method === 'POST' ? 201 : status);
      res.end('{}');
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => server.close());
    const result = await verifyCommunityContract({
      base: `http://127.0.0.1:${server.address().port}`,
      token: 'must-never-be-transmitted',
    });
    assert.equal(result.ok, false);
    assert.equal(result.verifiable, false);
    assert.deepEqual(requests, [{ method: 'GET', path: '/health', authorization: undefined }]);
  });
}

test('health redirects are refused', async (t) => {
  let requests = 0;
  const server = http.createServer((req, res) => {
    requests++;
    res.writeHead(307, { location: '/api/community/posts' });
    res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  await assert.rejects(verifyCommunityContract({ base: `http://127.0.0.1:${server.address().port}` }));
  assert.equal(requests, 1);
});
