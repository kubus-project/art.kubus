#!/usr/bin/env node
// Read-only health probe. Health cannot attest publishing validation, deployed
// revision, migration 098 or every writable HA instance. Verify those gates
// through read-only operator evidence and tests on disposable infrastructure.
// Exit codes: 1 unreachable, 2 UNKNOWN. Never sends credentials/create probes.
import { pathToFileURL } from 'node:url';

export async function verifyCommunityContract({ base }) {
  const response = await fetch(new URL('/health', base), {
    method: 'GET', redirect: 'error', signal: AbortSignal.timeout(10000),
  });
  return { ok: false, verifiable: false, checks: [{
    name: 'read-only health reachability (not publishing compatibility)',
    pass: response.ok, detail: `HTTP ${response.status}`,
  }] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const base = process.env.KUBUS_API_BASE;
  if (!base) {
    console.error('Set KUBUS_API_BASE to the backend origin to check.');
    process.exit(1);
  }
  try {
    const result = await verifyCommunityContract({ base });
    for (const check of result.checks) {
      console.log(`${check.pass ? 'PASS' : 'UNKNOWN'}  ${check.name} (${check.detail})`);
    }
    console.log('UNKNOWN: health cannot prove the 2200-code-point / ten-item contract. Verify revision, migration and HA gates read-only; run publishing tests only on disposable infrastructure.');
    process.exit(2);
  } catch {
    console.error('Backend health unreachable; publishing compatibility UNKNOWN.');
    process.exit(1);
  }
}
