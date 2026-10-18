// Unit tests for the provisioning-profile gate. The two certificates are
// throwaway self-signed public certificates (no private key exists anywhere);
// they only give X509Certificate real input.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import { inspectProfile, parsePlist, profileKind } from './inspect_ios_profile.mjs';

const TEAM_CERTIFICATE = [
  'MIID8TCCAtmgAwIBAgIUDlLzaPVuxaNGiHubd2JEjOExbF4wDQYJKoZIhvcNAQELBQAwgYcxGjAYBgoJkiaJk/IsZAEBDApB',
  'QkNERTEyMzQ1MTMwMQYDVQQDDCpBcHBsZSBEaXN0cmlidXRpb246IFRlc3QgVGVhbSAoQUJDREUxMjM0NSkxEzARBgNVBAsM',
  'CkFCQ0RFMTIzNDUxEjAQBgNVBAoMCVRlc3QgVGVhbTELMAkGA1UEBhMCU0kwHhcNMjYxMDE4MTEwMTUzWhcNMzYxMDE1MTEw',
  'MTUzWjCBhzEaMBgGCgmSJomT8ixkAQEMCkFCQ0RFMTIzNDUxMzAxBgNVBAMMKkFwcGxlIERpc3RyaWJ1dGlvbjogVGVzdCBU',
  'ZWFtIChBQkNERTEyMzQ1KTETMBEGA1UECwwKQUJDREUxMjM0NTESMBAGA1UECgwJVGVzdCBUZWFtMQswCQYDVQQGEwJTSTCC',
  'ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKekt/tmOASOiwQZwA4KeuUfpyCIduWKf64IGvWuR6/ugmOv77eYEcuU',
  'qa733GKE6W5TwGobHqeCjwhixwesfCuZJ9QquedQUPRWwwq5MQ8BFm4siPBQEEoO8a+Z74FmZ12zjqmbe2Wbr9U6McR7Oj0G',
  'hg1GIk/tGkvYBcbqyCmbg/TuxblJK6W5nhkQ/I9ovxH63wIhTfZeLty35qLalPBdGrvXBKOT3U7gK5izoTnZfpVO9pu158Za',
  'RMzBv8rzF5tnF9iJ5T2AVjYspo2D+Dj4yXTAWXv0Rg1SRwXVfBImOzKySNTd7QtPBYO6btPsDBkLXFUA+P0g4Hp5ItHFrtMC',
  'AwEAAaNTMFEwHQYDVR0OBBYEFDtGuinXmmrCNCpxx1d7cmNRRS9AMB8GA1UdIwQYMBaAFDtGuinXmmrCNCpxx1d7cmNRRS9A',
  'MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAATo934BKjYufcNb4MXNh49IBWqTfqxYfftO0aAd4Nqqu2FX',
  'JxhpxusNJBX92bluMdyG7fRIJqRJWGGibCGXOCQAG5yOJ/J3FguNwp/pdIWOFzbyLxo/PVTbXbbndnjuxAE5fUyar4IYCrEo',
  'rExGaZH1BFMkopZs0RrwnS7/YGGhXhbvRNSOek/5bSwv5UdNboq38/9mOdUURBGeKdn1a+vgr0InZl88AIzvpURxIdTWNv+B',
  'Bt8kmUqaslqc9Ncg7/NEWRFYjuxkTeDR0xK7NJxzRq58D51a3kUHo4PzWAbIQghZg+P5HJ8a0DdtG/TnzRsRXOCUTH0T9j5X',
  'RWCwgYg=',
].join('');
const OTHER_TEAM_CERTIFICATE = [
  'MIIDpzCCAo+gAwIBAgIUcXGMzKk4JbSOdIHynvE89bH5EBYwDQYJKoZIhvcNAQELBQAwYzEvMC0GA1UEAwwmQXBwbGUgRGlz',
  'dHJpYnV0aW9uOiBPdGhlciAoWlpaWlo5OTk5OSkxEzARBgNVBAsMClpaWlpaOTk5OTkxDjAMBgNVBAoMBU90aGVyMQswCQYD',
  'VQQGEwJTSTAeFw0yNjEwMTgxMTAxNTRaFw0zNjEwMTUxMTAxNTRaMGMxLzAtBgNVBAMMJkFwcGxlIERpc3RyaWJ1dGlvbjog',
  'T3RoZXIgKFpaWlpaOTk5OTkpMRMwEQYDVQQLDApaWlpaWjk5OTk5MQ4wDAYDVQQKDAVPdGhlcjELMAkGA1UEBhMCU0kwggEi',
  'MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC8IxJEyCTMSqujvqe2XRHrF6vIkB51wi32dYxIrGAFRtUE9VB4818ovG2u',
  'cijLXLQbDPJD9dtUY3Tb7F9D4wgMd4pA/hgPfsVWTREyLK45Yi59odKCrSSHWJajHljgKt7aD+AdzG//8t9XNLa3dxvuGAXt',
  'LjLhEGFgsYmm5NXq13iZW+n6dqI0mLsyGeUdfHzICCBZoYe1UXBOl3ULcj4MH1soTlYH5MMiSBZ0rZdWnWjvTMjZD1obTA6N',
  'EJq+xVqaIfl4z+6XZWvhN7kkwnB9ZTc8PMXVzWG9uv9BZmR8f56xKoWP9l/9WRoEV0p5ZLMI9PaIx16LTLs7fv60PE9dAgMB',
  'AAGjUzBRMB0GA1UdDgQWBBQTBYZgLoSCLX/iqJlO6S4+IwyOzDAfBgNVHSMEGDAWgBQTBYZgLoSCLX/iqJlO6S4+IwyOzDAP',
  'BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQB4LW3sleGgOovaG9Sx9ZyfmuyxAqZCVj3QjeDpDWtP2fORJn19',
  'lozoP+H9j+f0rSE6kiofaFLxGmZlgMoRNhxxXjVhhQQEmnO3GqJ2YGKLU7PBRSvvYsY1y6eHJdfkC5z7wzJMbeJOzJkbbYSm',
  'VUb7yuvUVfaNymXZeDuiz4pEex9yLq1rA56qlG5eTL+mEwL/X2jc8AePlvN6vpmtzfGu6QGHCkOX5Pu12c5jMYyXj0nXcF2h',
  '5ILaAkAQIfdEOwxBzSDk7jdTRuNAUhb1bCC7/i125vsbKGACVEdOoDp0CSbqhmbLz9jrSsyCywlk/AKjExUqAPkgnOskfgTy',
  '/dRP',
].join('');

const TEAM = 'ABCDE12345';
const BUNDLE = 'com.art.kubus';
const NOW = new Date('2026-10-18T12:00:00Z');
const sha1 = (base64) => createHash('sha1').update(Buffer.from(base64, 'base64')).digest('hex').toUpperCase();

function profileXml({
  team = TEAM,
  applicationId = `${TEAM}.${BUNDLE}`,
  expires = '2027-10-18T12:00:00Z',
  certificates = [TEAM_CERTIFICATE],
  devices = null,
  getTaskAllow = false,
  allDevices = false,
} = {}) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AppIDName</key>
  <string>art.kubus &amp; friends</string>
  <key>DeveloperCertificates</key>
  <array>
${certificates.map((certificate) => `    <data>\n    ${certificate.match(/.{1,68}/g).join('\n    ')}\n    </data>`).join('\n')}
  </array>
  <key>Entitlements</key>
  <dict>
    <key>application-identifier</key>
    <string>${applicationId}</string>
    <key>get-task-allow</key>
    ${getTaskAllow ? '<true/>' : '<false/>'}
    <key>keychain-access-groups</key>
    <array>
      <string>${team}.*</string>
    </array>
  </dict>
  <key>ExpirationDate</key>
  <date>${expires}</date>
  <key>Name</key>
  <string>art.kubus App Store</string>
${devices ? `  <key>ProvisionedDevices</key>\n  <array>\n${devices.map((device) => `    <string>${device}</string>`).join('\n')}\n  </array>` : ''}
${allDevices ? '  <key>ProvisionsAllDevices</key>\n  <true/>' : ''}
  <key>TeamIdentifier</key>
  <array>
    <string>${team}</string>
  </array>
  <key>UUID</key>
  <string>0f8b6b2e-6c1d-4c55-9a43-3d7f1b0c2a11</string>
  <key>Version</key>
  <integer>1</integer>
</dict>
</plist>
`;
}

const inspect = (xml, options = {}) => inspectProfile(parsePlist(xml), {
  teamId: TEAM,
  bundleId: BUNDLE,
  exportMethod: 'app-store',
  identityHashes: [sha1(TEAM_CERTIFICATE)],
  now: NOW,
  ...options,
});

test('parses the property-list types a decoded profile uses', () => {
  const profile = parsePlist(profileXml());
  assert.equal(profile.AppIDName, 'art.kubus & friends');
  assert.equal(profile.Version, 1);
  assert.equal(profile.Entitlements['get-task-allow'], false);
  assert.deepEqual(profile.Entitlements['keychain-access-groups'], [`${TEAM}.*`]);
  assert.ok(profile.ExpirationDate instanceof Date);
  assert.equal(profile.ExpirationDate.toISOString(), '2027-10-18T12:00:00.000Z');
  assert.ok(Buffer.isBuffer(profile.DeveloperCertificates[0]));
  assert.equal(profile.UUID, '0f8b6b2e-6c1d-4c55-9a43-3d7f1b0c2a11');
});

test('accepts a matching App Store profile and reports only public facts', () => {
  const result = inspect(profileXml());
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.warnings, []);
  assert.equal(result.facts.uuid, '0f8b6b2e-6c1d-4c55-9a43-3d7f1b0c2a11');
  assert.equal(result.facts.kind, 'app-store');
  assert.equal(result.facts.expires, '2027-10-18T12:00:00.000Z');
  assert.match(result.facts.certificate_expires, /^20\d\d-/);
  assert.deepEqual(inspect(profileXml(), { exportMethod: 'app-store-connect' }).errors, []);
});

test('rejects a profile from another team or for another or wildcard app id', () => {
  assert.match(inspect(profileXml({ team: 'ZZZZZ99999' })).errors.join('\n'), /profile team ZZZZZ99999/);
  assert.match(inspect(profileXml({ applicationId: `${TEAM}.com.example.other` })).errors.join('\n'), /application identifier/);
  assert.match(inspect(profileXml({ applicationId: `${TEAM}.*` })).errors.join('\n'), /wildcard profiles are not accepted/);
});

test('rejects an expired profile and warns before expiry', () => {
  assert.match(inspect(profileXml({ expires: '2026-10-01T00:00:00Z' })).errors.join('\n'), /profile expired/);
  const soon = inspect(profileXml({ expires: '2026-11-01T00:00:00Z' }));
  assert.deepEqual(soon.errors, []);
  assert.match(soon.warnings.join('\n'), /profile expires on 2026-11-01/);
});

test('rejects a profile that does not contain the imported signing certificate', () => {
  const result = inspect(profileXml({ certificates: [OTHER_TEAM_CERTIFICATE] }));
  assert.match(result.errors.join('\n'), /no certificate in the profile matches/);
});

test('rejects a matching certificate issued to another team', () => {
  const result = inspect(profileXml({ certificates: [OTHER_TEAM_CERTIFICATE] }), {
    identityHashes: [sha1(OTHER_TEAM_CERTIFICATE)],
  });
  assert.match(result.errors.join('\n'), /belongs to a different team/);
});

test('rejects an expired signing certificate', () => {
  const result = inspect(profileXml(), { now: new Date('2040-01-01T00:00:00Z') });
  assert.match(result.errors.join('\n'), /signing certificate expired/);
});

test('matches the profile kind to the export method', () => {
  const adHoc = profileXml({ devices: ['00008110-000A1B2C3D4E5F60'] });
  assert.equal(profileKind(parsePlist(adHoc)), 'ad-hoc');
  assert.match(inspect(adHoc).errors.join('\n'), /profile is ad-hoc but IOS_EXPORT_METHOD app-store needs app-store/);
  assert.deepEqual(inspect(adHoc, { exportMethod: 'ad-hoc' }).errors, []);
  assert.deepEqual(inspect(adHoc, { exportMethod: 'release-testing' }).errors, []);
  const development = profileXml({ devices: ['00008110-000A1B2C3D4E5F60'], getTaskAllow: true });
  assert.equal(profileKind(parsePlist(development)), 'development');
  assert.equal(profileKind(parsePlist(profileXml({ allDevices: true }))), 'enterprise');
  assert.match(inspect(profileXml(), { exportMethod: 'store' }).errors.join('\n'), /is not one of/);
});

test('rejects malformed property lists', () => {
  assert.throws(() => parsePlist('<plist version="1.0"><dict><string>x</string></dict></plist>'), /expected <key>/);
  assert.throws(() => parsePlist('<dict></dict>'), /missing <plist/);
});

test('the command line writes facts to a file and fails with annotations', async () => {
  const { mkdtempSync, readFileSync: read, writeFileSync: write, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { spawnSync } = await import('node:child_process');
  const { fileURLToPath } = await import('node:url');
  const script = fileURLToPath(new URL('./inspect_ios_profile.mjs', import.meta.url));
  const root = mkdtempSync(join(tmpdir(), 'ios-profile-'));
  try {
    const plist = join(root, 'profile.plist');
    const output = join(root, 'facts');
    write(plist, profileXml({ expires: '2099-01-01T00:00:00Z' }));
    const args = [script, '--profile-plist', plist, '--team-id', TEAM, '--bundle-id', BUNDLE, '--export-method', 'app-store', '--output', output];
    const ok = spawnSync(process.execPath, [...args, '--identity-hashes', sha1(TEAM_CERTIFICATE)], { encoding: 'utf8' });
    assert.equal(ok.status, 0, ok.stdout + ok.stderr);
    assert.match(read(output, 'utf8'), /^uuid=0f8b6b2e-6c1d-4c55-9a43-3d7f1b0c2a11$/m);
    assert.doesNotMatch(ok.stdout, /MIID/);
    const bad = spawnSync(process.execPath, [...args, '--identity-hashes', sha1(OTHER_TEAM_CERTIFICATE)], { encoding: 'utf8' });
    assert.equal(bad.status, 1);
    assert.match(bad.stdout, /^::error::no certificate in the profile matches/m);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
