'use strict';
const fs = require('node:fs');
const crypto = require('node:crypto');
const { Client } = require('pg');
const express = require('express');
const request = require('supertest');

const phase = { name: 'init' };
const evidence = {
  schema: 'kubus-backend-orbitdb-marker-lifecycle-v1',
  candidateSha: process.env.CANDIDATE_SHA,
  observedAt: new Date().toISOString(),
  host: process.env.PGHOST,
  port: Number(process.env.PGPORT),
  postgresDbImage: process.env.PG_IMAGE_DIGEST,
  kuboEndpoint: process.env.IPFS_RPC_URL,
  dnsLinkProvider: process.env.DNSLINK_PROVIDER,
  snapshotPublisherEnabled: String(process.env.ENABLE_PUBLIC_SNAPSHOT_PUBLISHER || 'false'),
  redisConfigured: Boolean(process.env.REDIS_URL || process.env.REDIS_HOST),
  id: {},
  checks: [],
};
let maintenance;
let fixture;
let dbModule;
let orbit;
let ipfsClient;
let databaseCreated = false;
let failed = null;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function record(name, details = {}) {
  evidence.checks.push({ name, pass: true, ...details });
}
function cleanError(error) {
  return String(error && error.message || error || 'unknown error')
    .replace(/postgres(?:ql)?:\/\/[^\s]+/gi, 'postgresql://[redacted]')
    .replace(/(password|secret|token)=([^\s&]+)/gi, '$1=[redacted]');
}
function connectionOptions(database) {
  return {
    host: process.env.PGHOST,
    port: Number(process.env.PGPORT),
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database,
    connectionTimeoutMillis: 5000,
  };
}
function buildDatabaseUrl(database) {
  const user = encodeURIComponent(process.env.PGUSER);
  const password = encodeURIComponent(process.env.PGPASSWORD);
  return 'postgresql://' + user + ':' + password + '@' + process.env.PGHOST + ':' + process.env.PGPORT + '/' + database;
}
function uuid() { return crypto.randomUUID(); }
async function catCid(client, cid) {
  const chunks = [];
  for await (const chunk of client.cat(String(cid))) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}
async function idsFromPublicApi(app) {
  const response = await request(app).get('/api/markers?limit=100').expect(200);
  const rows = response.body && Array.isArray(response.body.data) ? response.body.data : [];
  return rows.map((row) => String(row.id || row.artMarkerId || '')).filter(Boolean);
}
async function assertPublicState(app, publicSync, orbitService, markerId, expected, stage, allowRawStale = false) {
  const rawDoc = await orbitService.getARMarker(markerId);
  const fallbackDoc = await publicSync.getOrbitMarker(markerId);
  const fallbackList = await publicSync.listOrbitMarkers({ limit: 100, offset: 0 });
  const listedIds = await idsFromPublicApi(app);
  const content = await request(app).get('/api/ar-markers/' + markerId + '/content');
  const apiPresent = listedIds.includes(markerId);
  const fallbackPresent = Boolean(fallbackDoc);
  const fallbackListed = fallbackList.some((row) => String(row.id || row.markerId || '') === markerId);
  const contentStatus = content.status;
  assert(apiPresent === expected, stage + ': current marker API visibility mismatch');
  assert(fallbackPresent === expected, stage + ': current Orbit fallback detail visibility mismatch');
  assert(fallbackListed === expected, stage + ': current Orbit fallback list visibility mismatch');
  assert(contentStatus === (expected ? 200 : 404), stage + ': AR content route visibility mismatch');
  if (!expected && !allowRawStale) assert(!rawDoc, stage + ': stale Orbit doc should have been removed');
  if (!expected && allowRawStale) assert(Boolean(rawDoc), stage + ': expected stale Orbit doc to demonstrate read-time gate');
  record(stage, { expectedVisible: expected, publicApiPresent: apiPresent, orbitFallbackPresent: fallbackPresent,
    orbitFallbackListed: fallbackListed, arContentStatus: contentStatus, rawOrbitDocPresent: Boolean(rawDoc) });
  return { rawDoc, fallbackDoc, listedIds };
}
async function seedMarker(client, markerId, artworkId, editorialState, markerName, seedLegacy) {
  const markerData = { isPublic: true, isActive: true, name: markerName, description: 'synthetic lifecycle fixture' };
  await client.query(
    `INSERT INTO art_markers (id, artwork_id, latitude, longitude, marker_data, is_active, editorial_state)
     VALUES ($1, $2, 46.051, 14.505, $3::jsonb, true, $4)`,
    [markerId, artworkId, JSON.stringify(markerData), editorialState],
  );
  await client.query(
    `INSERT INTO ar_markers (art_marker_id, config)
     VALUES ($1, '{"animationName":"synthetic-baseline"}'::jsonb)`,
    [markerId],
  );
  if (seedLegacy) {
    const result = await client.query(
      `SELECT public.marker_legacy_material_fingerprint(am, ar, a) AS fingerprint
         FROM art_markers am
         JOIN ar_markers ar ON ar.art_marker_id = am.id
         LEFT JOIN artworks a ON a.id = am.artwork_id
        WHERE am.id = $1`,
      [markerId],
    );
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.marker_legacy_seed', 'on', true)");
    await client.query(
      `INSERT INTO marker_legacy_visibility_grants (marker_id, material_fingerprint, captured_at)
       VALUES ($1, $2, now())`,
      [markerId, result.rows[0].fingerprint],
    );
    await client.query('COMMIT');
  }
}
async function grantStatus(client, markerId) {
  const result = await client.query(
    'SELECT revoked_at, revoke_reason FROM marker_legacy_visibility_grants WHERE marker_id = $1', [markerId],
  );
  return result.rows[0] || null;
}

async function main() {
  assert(process.env.CANDIDATE_SHA === '88d792ffccc4ccaff96f82f230d4b9e14b7e00a1', 'unexpected candidate source SHA');
  assert(process.env.DNSLINK_PROVIDER === 'off', 'DNSLink publication must be disabled');
  assert(String(process.env.ENABLE_PUBLIC_SNAPSHOT_PUBLISHER || 'false').toLowerCase() !== 'true', 'automatic publisher must remain disabled');
  const databaseName = process.env.LIFECYCLE_DB_NAME;
  assert(/^orbitdb_lifecycle_085_[a-z0-9_]+$/.test(databaseName), 'unsafe lifecycle database name');
  evidence.database = databaseName;
  evidence.phase = phase.name = 'postgres-bootstrap';
  maintenance = new Client(connectionOptions('postgres'));
  await maintenance.connect();
  const exists = await maintenance.query('SELECT 1 FROM pg_database WHERE datname = $1', [databaseName]);
  assert(exists.rowCount === 0, 'task database already exists; refusing reuse');
  await maintenance.query('CREATE DATABASE ' + databaseName);
  databaseCreated = true;
  const version = await maintenance.query('SELECT current_setting(\'server_version\') AS version');
  evidence.postgres = { version: version.rows[0].version };
  await maintenance.end();
  maintenance = null;

  phase.name = 'schema-and-migration';
  fixture = new Client(connectionOptions(databaseName));
  await fixture.connect();
  // Use the candidate's own migration runner (schema plus the whole migration
  // chain, including 113) rather than executing schema_complete.sql by hand:
  // art_markers is created by the migration chain, not by that file alone.
  require('node:child_process').execFileSync('node', ['/repo/src/db/migrate.js'], {
    env: { ...process.env, DATABASE_URL: buildDatabaseUrl(databaseName), NODE_ENV: 'test' },
    stdio: ['ignore', 'ignore', 'inherit'],
  });
  const postgis = await fixture.query("SELECT extversion AS postgis FROM pg_extension WHERE extname = 'postgis'");
  evidence.postgres.postgis = postgis.rows[0].postgis;
  const baseCounts = await fixture.query(`SELECT
      (SELECT count(*)::int FROM art_markers) AS markers,
      (SELECT count(*)::int FROM marker_legacy_visibility_grants) AS grants`);
  assert(baseCounts.rows[0].markers === 0 && baseCounts.rows[0].grants === 0, 'fresh schema did not remain free of production rows');
  record('fresh migration chain (runner) applied including 113', { initialMarkers: 0, initialGrants: 0 });

  phase.name = 'seed-synthetic-fixtures';
  const artworkId = uuid();
  const approvedId = uuid();
  const hideId = uuid();
  const rejectId = uuid();
  const materialId = uuid();
  evidence.id = { artworkId, approvedMarkerId: approvedId, legacyHideMarkerId: hideId,
    legacyRejectMarkerId: rejectId, legacyMaterialMarkerId: materialId };
  await fixture.query(
    `INSERT INTO artworks (id, wallet_address, title, description, image_url, is_public, is_active, editorial_state)
     VALUES ($1, 'synthetic-orbit-owner', 'Synthetic Orbit lifecycle artwork', 'synthetic fixture', 'https://example.invalid/synthetic-orbit.png', true, true, 'unreviewed')`,
    [artworkId],
  );
  await seedMarker(fixture, approvedId, artworkId, 'approved', 'Synthetic approved marker', false);
  await seedMarker(fixture, hideId, artworkId, 'unreviewed', 'Synthetic legacy hide marker', true);
  await seedMarker(fixture, rejectId, artworkId, 'unreviewed', 'Synthetic legacy reject marker', true);
  await seedMarker(fixture, materialId, artworkId, 'unreviewed', 'Synthetic legacy material marker', true);
  const eligibility = await fixture.query(
    `SELECT am.id::text AS id, ${require('/repo/src/services/markerVisibilityRules').publicMarkerEligibilitySql('am')} AS eligible
       FROM art_markers am WHERE am.id = ANY($1::uuid[]) ORDER BY am.id`,
    [[approvedId, hideId, rejectId, materialId]],
  );
  assert(eligibility.rowCount === 4 && eligibility.rows.every((row) => row.eligible === true), 'synthetic fixtures not initially eligible');
  assert((await grantStatus(fixture, hideId))?.revoked_at == null, 'legacy grant seed did not take');
  record('synthetic approved and QA-seeded legacy grants', { approved: 1, legacyGrants: 3, allInitiallyEligible: true,
    editorialStates: { approved: 1, unreviewedWithGrant: 3 } });
  await fixture.end();
  fixture = null;

  phase.name = 'candidate-orbitdb-lifecycle';
  process.env.DATABASE_URL = buildDatabaseUrl(databaseName);
  dbModule = require('/repo/src/db');
  assert(await dbModule.testConnection(), 'candidate service database pool failed');
  const publicSync = require('/repo/src/services/publicSyncService');
  const orbitService = require('/repo/src/services/orbitdbService');
  orbit = orbitService;
  const snapshotService = require('/repo/src/services/publicSnapshotService');
  const dnsLinkService = require('/repo/src/services/dnsLinkService');
  const { getIpfsClient } = require('/repo/src/services/ipfsClientService');
  const app = express();
  app.use('/api/markers', require('/repo/src/routes/publicMarkers'));
  app.use('/api/ar-markers', require('/repo/src/routes/arMarkers'));
  assert(publicSync.orbitSyncEnabled(), 'candidate OrbitDB sync mode is off');
  assert(await publicSync.ensureSchemaReady(), 'candidate schema readiness check failed');
  assert(await publicSync.ensureOrbitReady({ operation: 'lifecycle', entityType: 'marker', throwOnUnavailable: true }), 'OrbitDB init failed');
  ipfsClient = await getIpfsClient();
  const ipfsId = await ipfsClient.id();
  evidence.kuboPeerId = ipfsId.id;
  // dnsLinkService does not export its provider; the env value it reads and
  // its exported isConfigured() are the observable runtime signals.
  evidence.dnsLinkProviderAtRuntime = String(process.env.DNSLINK_PROVIDER || 'off').trim().toLowerCase();
  evidence.dnsLinkConfiguredAtRuntime = dnsLinkService.isConfigured();
  assert(evidence.dnsLinkConfiguredAtRuntime === false, 'DNSLink reports itself configured');
  evidence.snapshotPublisherEnabledAtRuntime = snapshotService.isPublisherEnabled();
  evidence.redisEnabledAtRuntime = require('/repo/src/services/redisClient').isRedisEnabled();
  assert(evidence.dnsLinkProviderAtRuntime === 'off', 'runtime DNSLink provider is not off');
  assert(evidence.snapshotPublisherEnabledAtRuntime === false, 'automatic snapshot publishing unexpectedly enabled');
  assert(evidence.redisEnabledAtRuntime === false, 'unexpected Redis use in focused isolated run');

  const ids = [approvedId, hideId, rejectId, materialId];
  for (const markerId of ids) {
    const synced = await publicSync.syncMarkerById(markerId);
    assert(synced && synced.id === markerId, 'candidate did not publish marker to OrbitDB: ' + markerId);
    await assertPublicState(app, publicSync, orbitService, markerId, true, 'initial-visible-' + markerId);
  }
  const publication = await dbModule.query(
    `SELECT am.id::text AS id, am.editorial_state, am.public_record_cid, am.public_manifest_cid,
            am.public_manifest_version, pov.public_record_cid AS historical_record_cid
       FROM art_markers am
       LEFT JOIN public_objects po ON po.entity_type = 'marker' AND po.entity_id = am.id::text
       LEFT JOIN public_object_versions pov ON pov.public_object_id = po.id AND pov.version_number = am.public_manifest_version
      WHERE am.id = ANY($1::uuid[])`,
    [ids],
  );
  const publicationById = Object.fromEntries(publication.rows.map((row) => [row.id, row]));
  for (const markerId of ids) {
    assert(publicationById[markerId] && publicationById[markerId].public_record_cid, 'public record CID missing after publication: ' + markerId);
  }
  evidence.publication = ids.map((id) => ({ id, editorialState: publicationById[id].editorial_state,
    manifestVersion: publicationById[id].public_manifest_version,
    manifestCid: publicationById[id].public_manifest_cid,
    recordCid: publicationById[id].public_record_cid,
    historicalRecordCid: publicationById[id].historical_record_cid }));
  record('actual OrbitDB write and current API/detail/list reads', { markerCount: ids.length, approvedCount: 1, legacyGrantCount: 3 });

  async function exerciseLegacyTransition(markerId, transition, revert, label) {
    await dbModule.query(transition.sql, [markerId]);
    const grantAfterChange = await dbModule.query(
      'SELECT revoked_at, revoke_reason FROM marker_legacy_visibility_grants WHERE marker_id = $1', [markerId],
    );
    assert(grantAfterChange.rows[0]?.revoked_at, label + ': grant was not revoked');
    await assertPublicState(app, publicSync, orbitService, markerId, false, label + '-read-time-deny', true);
    const rawHistoricalCid = publicationById[markerId].public_record_cid;
    const cidBody = await catCid(ipfsClient, rawHistoricalCid);
    assert(cidBody.length > 0, label + ': historical immutable record CID is no longer fetchable');
    const versionCheck = await dbModule.query(
      `SELECT pov.public_record_cid FROM public_object_versions pov
         JOIN public_objects po ON po.id = pov.public_object_id
        WHERE po.entity_type = 'marker' AND po.entity_id = $1 AND pov.public_record_cid = $2`,
      [markerId, rawHistoricalCid],
    );
    assert(versionCheck.rowCount === 1, label + ': historical version row was not retained');
    await publicSync.syncMarkerById(markerId);
    const removed = await assertPublicState(app, publicSync, orbitService, markerId, false, label + '-post-sync-deny', false);
    await dbModule.query(revert.sql, [markerId]);
    const grantAfterRevert = await dbModule.query(
      'SELECT revoked_at, revoke_reason FROM marker_legacy_visibility_grants WHERE marker_id = $1', [markerId],
    );
    assert(grantAfterRevert.rows[0]?.revoked_at, label + ': revert resurrected the legacy grant');
    await publicSync.syncMarkerById(markerId);
    await assertPublicState(app, publicSync, orbitService, markerId, false, label + '-revert-still-denied', false);
    const historyAfter = await catCid(ipfsClient, rawHistoricalCid);
    assert(historyAfter.length > 0 && crypto.createHash('sha256').update(historyAfter).digest('hex') === crypto.createHash('sha256').update(cidBody).digest('hex'),
      label + ': historical CID bytes changed');
    record(label + ' revocation, read-time denial, removal, monotonic revert, historical CID remains readable', {
      revokeReason: grantAfterRevert.rows[0].revoke_reason,
      orbitDocPresentBeforeSync: Boolean(removed.rawDoc),
      orbitDocRemovedAfterSync: !removed.rawDoc,
      historicalRecordCid: rawHistoricalCid,
      historicalCidReadableAfterRevert: true,
      historicalBytesStable: true,
    });
  }

  await exerciseLegacyTransition(hideId,
    { sql: `UPDATE art_markers SET marker_data = marker_data || '{"isPublic":false}'::jsonb WHERE id = $1` },
    { sql: `UPDATE art_markers SET marker_data = marker_data || '{"isPublic":true}'::jsonb WHERE id = $1` },
    'owner-hide-unhide');
  await exerciseLegacyTransition(rejectId,
    { sql: "UPDATE art_markers SET editorial_state = 'rejected' WHERE id = $1" },
    { sql: "UPDATE art_markers SET editorial_state = 'unreviewed' WHERE id = $1" },
    'reject-unreview');
  await exerciseLegacyTransition(materialId,
    { sql: `UPDATE art_markers SET marker_data = marker_data || '{"description":"material changed"}'::jsonb WHERE id = $1` },
    { sql: `UPDATE art_markers SET marker_data = marker_data - 'description' WHERE id = $1` },
    'material-edit-revert');

  phase.name = 'fresh-public-snapshot';
  const snapshot = await snapshotService.buildPublicSnapshotBundle();
  const inMemoryMarkerIds = snapshot.datasets.markers.map((row) => String(row.id));
  assert(inMemoryMarkerIds.includes(approvedId), 'fresh snapshot omitted approved control marker');
  assert(![hideId, rejectId, materialId].some((id) => inMemoryMarkerIds.includes(id)), 'fresh snapshot included revoked legacy marker');
  const publishedSnapshot = await snapshotService.publishPublicSnapshotBundle();
  assert(publishedSnapshot.published && publishedSnapshot.datasets?.markers?.cid, 'snapshot was not published to isolated Kubo');
  assert(publishedSnapshot.dnsLink?.updated === false && publishedSnapshot.dnsLink?.skipped === true,
    'DNSLink publisher did not report disabled/no pointer update');
  const snapshotBytes = await catCid(ipfsClient, publishedSnapshot.datasets.markers.cid);
  const publishedMarkerDocs = JSON.parse(snapshotBytes.toString('utf8'));
  const publishedMarkerIds = publishedMarkerDocs.map((row) => String(row.id));
  assert(publishedMarkerIds.includes(approvedId), 'published marker snapshot omitted approved control marker');
  assert(![hideId, rejectId, materialId].some((id) => publishedMarkerIds.includes(id)), 'published marker snapshot included revoked legacy marker');
  evidence.snapshot = {
    inMemoryGeneratedAt: snapshot.generatedAt,
    inMemoryMarkerCount: inMemoryMarkerIds.length,
    inMemoryApprovedPresent: inMemoryMarkerIds.includes(approvedId),
    inMemoryRevokedLegacyIdsExcluded: [hideId, rejectId, materialId].every((id) => !inMemoryMarkerIds.includes(id)),
    publishedGeneratedAt: publishedSnapshot.generatedAt,
    registryCid: String(publishedSnapshot.registryCid),
    markerDatasetCid: String(publishedSnapshot.datasets.markers.cid),
    publishedMarkerCount: publishedMarkerIds.length,
    publishedApprovedPresent: publishedMarkerIds.includes(approvedId),
    publishedRevokedLegacyIdsExcluded: [hideId, rejectId, materialId].every((id) => !publishedMarkerIds.includes(id)),
    dnsLink: publishedSnapshot.dnsLink,
    dnsLinkPointerChanged: publishedSnapshot.dnsLink.updated === true,
  };
  record('fresh public snapshot built and stored to isolated Kubo; revoked legacy markers excluded; DNSLink skipped', evidence.snapshot);
  evidence.phase = phase.name = 'passed';
}

(async () => {
  try {
    await main();
  } catch (error) {
    failed = { phase: phase.name, message: cleanError(error), stack: String(error && error.stack || '').split('\n').slice(0, 8).join('\n') };
  } finally {
    if (orbit) {
      // OrbitDBService.close() also calls stop() on its remote Kubo RPC client,
      // which asks the daemon itself to shut down. Detach the client so only
      // OrbitDB is stopped and the task Kubo stays up for evidence.
      try { orbit._ipfs = null; await orbit.close(); } catch (error) { failed ||= { phase: phase.name, message: cleanError(error) }; }
    }
    if (dbModule) {
      try { await dbModule.closePool(); } catch (error) { failed ||= { phase: phase.name, message: cleanError(error) }; }
    }
    if (fixture) {
      try { await fixture.end(); } catch (_) {}
      fixture = null;
    }
    if (maintenance) {
      try { await maintenance.end(); } catch (_) {}
      maintenance = null;
    }
    if (databaseCreated) {
      try {
        const cleanup = new Client(connectionOptions('postgres'));
        await cleanup.connect();
        await cleanup.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()", [evidence.database]);
        await cleanup.query('DROP DATABASE ' + evidence.database);
        await cleanup.end();
        evidence.ownedDatabaseDropped = true;
      } catch (error) {
        evidence.ownedDatabaseDropped = false;
        failed ||= { phase: 'cleanup-own-test-database', message: cleanError(error) };
      }
    }
    evidence.finishedAt = new Date().toISOString();
    evidence.result = failed ? 'FAIL' : 'PASS';
    evidence.failure = failed;
    fs.writeFileSync('/evidence/orbitdb-marker-lifecycle.v2.json', JSON.stringify(evidence, null, 2) + '\n', { mode: 0o600 });
    process.stdout.write(JSON.stringify({ result: evidence.result, phase: failed?.phase || 'passed', checks: evidence.checks.length,
      evidencePath: '/evidence/orbitdb-marker-lifecycle.v2.json', failure: failed }) + '\n');
    process.exitCode = failed ? 1 : 0;
  }
})();





