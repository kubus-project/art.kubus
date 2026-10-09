#!/usr/bin/env node
// Checks that a backend speaks the Community publishing contract the app now
// assumes (art.kubus-backend#79): 2200-code-point captions and ten media items.
//
// Every probe is rejected by validation, so nothing is ever created. The create
// route authenticates before it validates, which means the contract can only be
// read with a session. Pass one through KUBUS_CONTRACT_TOKEN (a short-lived
// access token for a test account; it is never printed). Without a token only
// the authentication requirement is checked and the exit code is 2.
//
//   KUBUS_API_BASE=https://api.kubus.site KUBUS_CONTRACT_TOKEN=... \
//     node scripts/verify_community_backend_contract.mjs
//
// Exit codes: 0 compatible, 1 incompatible or unreachable, 2 not verifiable.

const CONTENT_LIMIT = 2200;
const MEDIA_LIMIT = 10;

export function codePoints(text) {
  return Array.from(text).length;
}

async function post(base, token, body) {
  const headers = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(new URL('/api/community/posts', base), {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch {
    // Non-JSON bodies are reported by status alone.
  }
  return { status: response.status, payload };
}

function messages(payload) {
  const details = Array.isArray(payload?.details) ? payload.details : [];
  const text = details.map((d) => `${d.field ?? ''}: ${d.message ?? ''}`);
  if (typeof payload?.error === 'string') text.push(payload.error);
  return text.join(' | ');
}

function fields(payload) {
  const details = Array.isArray(payload?.details) ? payload.details : [];
  return new Set(details.map((d) => String(d.field ?? '')));
}

/** Runs the probes and returns `{ ok, verifiable, checks }`. */
export async function verifyCommunityContract({ base, token }) {
  const checks = [];
  const add = (name, pass, detail) => checks.push({ name, pass, detail });

  const anonymous = await post(base, '', { content: 'contract probe' });
  add('create requires authentication', anonymous.status === 401, `HTTP ${anonymous.status}`);

  if (!token) {
    return { ok: checks.every((c) => c.pass), verifiable: false, checks };
  }

  const media = (n) => Array.from({ length: n }, (_, i) => `https://contract.invalid/m${i}.jpg`);

  // Over the limit by one code point (emoji count once, as in the app).
  const tooLong = '😀'.repeat(CONTENT_LIMIT + 1);
  const over = await post(base, token, { content: tooLong });
  add(
    `${CONTENT_LIMIT + 1} code points are rejected for length`,
    over.status === 400 && fields(over.payload).has('content') && /2200/.test(messages(over.payload)),
    `HTTP ${over.status} ${messages(over.payload).slice(0, 120)}`,
  );

  // Past the old 1000-character cap but inside the new one. The invalid media
  // scheme is what makes this request fail, so the response must not blame the
  // caption: that proves the longer caption itself was accepted.
  const longButValid = 'a'.repeat(1500);
  const accepted = await post(base, token, {
    content: longButValid,
    mediaUrls: ['javascript:contract-probe'],
  });
  const acceptedText = messages(accepted.payload);
  add(
    '1500 characters are not rejected for length',
    accepted.status === 400 && !fields(accepted.payload).has('content') &&
      [...fields(accepted.payload)].some((f) => f.startsWith('mediaUrls')),
    `HTTP ${accepted.status} ${acceptedText.slice(0, 120)}`,
  );

  const many = await post(base, token, { content: 'contract probe', mediaUrls: media(MEDIA_LIMIT + 1) });
  add(
    `${MEDIA_LIMIT + 1} media items are rejected`,
    many.status === 400 && /10|ten/i.test(messages(many.payload)),
    `HTTP ${many.status} ${messages(many.payload).slice(0, 120)}`,
  );

  return { ok: checks.every((c) => c.pass), verifiable: true, checks };
}

if (import.meta.url === `file://${process.argv[1].replace(/\\/g, '/')}` ||
    process.argv[1]?.endsWith('verify_community_backend_contract.mjs')) {
  const base = process.env.KUBUS_API_BASE;
  if (!base) {
    console.error('Set KUBUS_API_BASE to the backend origin to check.');
    process.exit(1);
  }
  const token = (process.env.KUBUS_CONTRACT_TOKEN || '').trim();
  let result;
  try {
    result = await verifyCommunityContract({ base, token });
  } catch (error) {
    console.error(`Backend unreachable: ${error.message}`);
    process.exit(1);
  }
  for (const check of result.checks) {
    console.log(`${check.pass ? 'PASS' : 'FAIL'}  ${check.name}  (${check.detail})`);
  }
  if (!result.verifiable) {
    console.log('NOT VERIFIED: the length and media contract needs KUBUS_CONTRACT_TOKEN.');
    process.exit(result.ok ? 2 : 1);
  }
  process.exit(result.ok ? 0 : 1);
}
