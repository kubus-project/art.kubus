#!/usr/bin/env node
// Validates a decoded iOS provisioning profile against the signing identity and
// the release configuration before anything is built. Prints only public
// profile facts (UUID, name, kind, expiry); never certificate or key material.
import { readFileSync, writeFileSync } from 'node:fs';
import { X509Certificate } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const EXPORT_METHOD_KINDS = {
  'app-store': 'app-store',
  'app-store-connect': 'app-store',
  'ad-hoc': 'ad-hoc',
  'release-testing': 'ad-hoc',
  development: 'development',
  debugging: 'development',
  enterprise: 'enterprise',
};
const EXPIRY_WARNING_DAYS = 30;
// Certificate common-name prefixes per role, current and legacy Apple names.
const DEVELOPMENT_IDENTITY = /^(Apple Development|iPhone Developer|iOS Development): /;
const DISTRIBUTION_IDENTITY = /^(Apple Distribution|iPhone Distribution|iOS Distribution): /;

function commonName(certificate) {
  const line = certificate.subject.split('\n').find((part) => part.startsWith('CN='));
  return line ? line.slice(3) : '';
}

function decodeXmlText(text) {
  return text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

// Minimal XML property-list reader for the output of `security cms -D`.
export function parsePlist(xml) {
  const tokens = xml.replace(/<\?xml[^>]*\?>|<!DOCTYPE[^>]*>|<!--[\s\S]*?-->/g, '').match(/<[^>]+>|[^<]+/g) || [];
  let index = 0;
  const next = () => tokens[index++];
  const skipWhitespace = () => {
    while (index < tokens.length && !tokens[index].startsWith('<') && tokens[index].trim() === '') index++;
  };
  const readText = (closing) => {
    let text = '';
    while (index < tokens.length && tokens[index] !== closing) text += tokens[index++];
    if (next() !== closing) throw new Error(`profile plist: missing ${closing}`);
    return decodeXmlText(text);
  };
  const readValue = () => {
    skipWhitespace();
    const tag = next();
    if (tag === undefined) throw new Error('profile plist: unexpected end');
    if (/^<(true|false)\s*\/>$/.test(tag)) return tag.includes('true');
    if (/^<(string|data|array|dict)\s*\/>$/.test(tag)) {
      return tag.includes('array') ? [] : tag.includes('dict') ? {} : '';
    }
    switch (tag) {
      case '<string>': return readText('</string>');
      case '<integer>': return Number.parseInt(readText('</integer>').trim(), 10);
      case '<real>': return Number.parseFloat(readText('</real>').trim());
      case '<date>': return new Date(readText('</date>').trim());
      case '<data>': return Buffer.from(readText('</data>').replace(/\s+/g, ''), 'base64');
      case '<array>': {
        const values = [];
        for (;;) {
          skipWhitespace();
          if (tokens[index] === '</array>') { index++; return values; }
          values.push(readValue());
        }
      }
      case '<dict>': {
        const values = {};
        for (;;) {
          skipWhitespace();
          const keyTag = next();
          if (keyTag === '</dict>') return values;
          if (keyTag !== '<key>') throw new Error(`profile plist: expected <key>, found ${keyTag}`);
          const key = readText('</key>');
          values[key] = readValue();
        }
      }
      default: throw new Error(`profile plist: unsupported element ${tag}`);
    }
  };
  skipWhitespace();
  if (next() !== '<plist version="1.0">') throw new Error('profile plist: missing <plist version="1.0">');
  return readValue();
}

export function profileKind(profile) {
  if (profile.ProvisionsAllDevices === true) return 'enterprise';
  const devices = Array.isArray(profile.ProvisionedDevices) && profile.ProvisionedDevices.length > 0;
  if (!devices) return 'app-store';
  return profile.Entitlements?.['get-task-allow'] === true ? 'development' : 'ad-hoc';
}

function sha1Hex(der) {
  return new X509Certificate(der).fingerprint.replace(/:/g, '').toUpperCase();
}

export function inspectProfile(profile, { teamId, bundleId, exportMethod, identityHashes, now = new Date() }) {
  const errors = [];
  const warnings = [];
  const expectedKind = EXPORT_METHOD_KINDS[exportMethod];
  if (!expectedKind) errors.push(`IOS_EXPORT_METHOD "${exportMethod}" is not one of ${Object.keys(EXPORT_METHOD_KINDS).join(', ')}`);

  const team = Array.isArray(profile.TeamIdentifier) ? profile.TeamIdentifier[0] : undefined;
  if (team !== teamId) errors.push(`profile team ${team ?? '(none)'} does not match IOS_TEAM_ID`);
  const applicationId = profile.Entitlements?.['application-identifier'];
  if (applicationId !== `${teamId}.${bundleId}`) {
    errors.push(`profile application identifier ${applicationId ?? '(none)'} is not ${teamId}.${bundleId} (wildcard profiles are not accepted)`);
  }

  const kind = profileKind(profile);
  if (expectedKind && kind !== expectedKind) errors.push(`profile is ${kind} but IOS_EXPORT_METHOD ${exportMethod} needs ${expectedKind}`);

  const expires = profile.ExpirationDate instanceof Date ? profile.ExpirationDate : null;
  if (!expires || Number.isNaN(expires.getTime())) {
    errors.push('profile has no ExpirationDate');
  } else if (expires <= now) {
    errors.push(`profile expired on ${expires.toISOString()}`);
  } else if (expires - now < EXPIRY_WARNING_DAYS * 86_400_000) {
    warnings.push(`profile expires on ${expires.toISOString()}`);
  }

  const wanted = new Set(identityHashes.map((hash) => hash.toUpperCase()));
  const certificates = Array.isArray(profile.DeveloperCertificates) ? profile.DeveloperCertificates : [];
  const matching = certificates.filter((der) => wanted.has(sha1Hex(der)));
  if (matching.length === 0) {
    errors.push('no certificate in the profile matches a signing identity imported from IOS_DISTRIBUTION_CERTIFICATE_BASE64');
  }
  let certificateExpires = null;
  let signingIdentity = '';
  // A development export signs with a development certificate, every other
  // export with a distribution certificate. The exact common name goes to
  // CODE_SIGN_IDENTITY so Xcode selects this certificate and no other.
  const wantedRole = kind === 'development' ? DEVELOPMENT_IDENTITY : DISTRIBUTION_IDENTITY;
  for (const der of matching) {
    const certificate = new X509Certificate(der);
    const validTo = new Date(certificate.validTo);
    const name = commonName(certificate);
    if (!wantedRole.test(name)) {
      errors.push(`the signing certificate "${name}" is not ${kind === 'development' ? 'an Apple Development' : 'an Apple Distribution'} certificate, which a ${kind} profile needs`);
    } else if (!signingIdentity) {
      signingIdentity = name;
    }
    if (!certificate.subject.split('\n').includes(`OU=${teamId}`)) {
      errors.push('the matching signing certificate belongs to a different team');
    }
    if (validTo <= now) {
      errors.push(`the matching signing certificate expired on ${validTo.toISOString()}`);
    } else if (validTo - now < EXPIRY_WARNING_DAYS * 86_400_000) {
      warnings.push(`the signing certificate expires on ${validTo.toISOString()}`);
    }
    if (!certificateExpires || validTo > certificateExpires) certificateExpires = validTo;
  }

  return {
    errors,
    warnings,
    facts: {
      uuid: typeof profile.UUID === 'string' ? profile.UUID : '',
      name: typeof profile.Name === 'string' ? profile.Name : '',
      kind,
      expires: expires && !Number.isNaN(expires.getTime()) ? expires.toISOString() : '',
      certificate_expires: certificateExpires ? certificateExpires.toISOString() : '',
      signing_identity: signingIdentity,
    },
  };
}

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const profilePath = argument('profile-plist');
  const result = inspectProfile(parsePlist(readFileSync(profilePath, 'utf8')), {
    teamId: argument('team-id'),
    bundleId: argument('bundle-id'),
    exportMethod: argument('export-method'),
    identityHashes: (argument('identity-hashes') || '').split(',').filter(Boolean),
  });
  for (const warning of result.warnings) console.log(`::warning::${warning}`);
  for (const error of result.errors) console.log(`::error::${error}`);
  if (result.errors.length > 0) process.exit(1);
  if (!/^[0-9A-Fa-f-]{36}$/.test(result.facts.uuid)) {
    console.log('::error::profile UUID is missing or malformed');
    process.exit(1);
  }
  // The name lands in an xcconfig line, so it must be a single plain line.
  if (!/^[^\r\n=;]+$/.test(result.facts.signing_identity)) {
    console.log('::error::the signing certificate has no usable common name');
    process.exit(1);
  }
  const facts = Object.entries(result.facts).map(([key, value]) => `${key}=${value}\n`).join('');
  writeFileSync(argument('output'), facts, { mode: 0o600 });
  console.log(`Provisioning profile ${result.facts.name} (${result.facts.kind}) valid until ${result.facts.expires}; signing certificate valid until ${result.facts.certificate_expires}.`);
}
