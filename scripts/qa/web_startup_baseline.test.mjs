import assert from 'node:assert/strict';
import test from 'node:test';

import { classify, summarizeRequests } from './web_startup_baseline.mjs';

test('requests are classified by origin', () => {
  assert.equal(classify('http://127.0.0.1:5000/main.dart.js'), 'app-static');
  assert.equal(classify('https://api.devnet.solana.com/'), 'solana-rpc');
  assert.equal(classify('https://api.kubus.site/api/artworks?page=1'), 'backend-api');
  assert.equal(classify('https://api.kubus.site/uploads/a.jpg'), 'backend-media');
  assert.equal(classify('https://ipfs.io/ipfs/bafy'), 'ipfs');
  assert.equal(classify('https://tiles.openfreemap.org/planet/20260101_000000_pt/1/2/3.pbf'), 'map-tiles');
});

test('only identical requests count as repeats; overlap marks them concurrent', () => {
  const summary = summarizeRequests([
    { method: 'GET', url: 'https://api.kubus.site/api/profiles/w', kind: 'backend-api', startMs: 0, endMs: 100 },
    { method: 'GET', url: 'https://api.kubus.site/api/profiles/w', kind: 'backend-api', startMs: 50, endMs: 120 },
    { method: 'GET', url: 'https://api.kubus.site/api/profiles/w', kind: 'backend-api', startMs: 300, endMs: 320 },
    { method: 'GET', url: 'https://api.kubus.site/api/profiles/w?x=1', kind: 'backend-api', startMs: 0, endMs: 10 },
    { method: 'OPTIONS', url: 'https://api.kubus.site/api/profiles/w', kind: 'backend-api', startMs: 0, endMs: 5 },
    { method: 'GET', url: 'https://t/1.mvt', kind: 'map-tiles', startMs: 0, endMs: 5 },
    { method: 'GET', url: 'https://t/1.mvt', kind: 'map-tiles', startMs: 1, endMs: 6 },
    { method: 'POST', url: 'https://api.devnet.solana.com/', kind: 'solana-rpc', body: '{"method":"getBalance"}', rpcMethods: ['getBalance'], startMs: 0, endMs: 10 },
    { method: 'POST', url: 'https://api.devnet.solana.com/', kind: 'solana-rpc', body: '{"method":"getSignaturesForAddress"}', rpcMethods: ['getSignaturesForAddress'], startMs: 0, endMs: 10 },
  ]);
  assert.equal(summary.total, 9);
  assert.deepEqual(summary.rpc, { getBalance: 1, getSignaturesForAddress: 1 });
  assert.equal(summary.repeatedGets.length, 1, 'tiles, preflights and distinct queries or bodies are not repeats');
  assert.equal(summary.repeatedGets[0].count, 3);
  assert.equal(summary.concurrentDuplicates, 1);
});
