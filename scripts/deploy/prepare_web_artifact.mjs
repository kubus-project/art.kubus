#!/usr/bin/env node
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';

function arg(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? null : process.argv[index + 1];
}

const environment = arg('--environment');
const sourceSha = arg('--source-sha');
const artifactDir = resolve(arg('--directory') || 'build/web');

if (!['development', 'production'].includes(environment)) throw new Error('environment must be development or production');
if (!/^[0-9a-f]{40}$/.test(sourceSha || '')) throw new Error('source SHA must be 40 lowercase hex characters');

const indexPath = join(artifactDir, 'index.html');
const htaccessPath = join(artifactDir, '.htaccess');
if (!statSync(indexPath).isFile()) throw new Error('web artifact is missing index.html');
if (!statSync(htaccessPath).isFile()) throw new Error('web artifact is missing .htaccess');

const stagingBlock = `<IfModule mod_headers.c>
  Header always set X-Robots-Tag "noindex, nofollow, noarchive"
</IfModule>
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteRule ^robots\\.txt$ - [L]
</IfModule>

`;

// Staging Basic Auth (development only). The atomic deploy replaces the docroot
// .htaccess on every release, so cPanel Directory Privacy does not survive; bake
// the auth into each immutable artifact instead, referencing a persistent
// htpasswd file supplied via DEV_HTPASSWD_FILE. Production is never protected.
const authUserFile = (process.env.DEV_HTPASSWD_FILE || '').trim();
const authRealm = (process.env.DEV_AUTH_REALM || 'Protected staging').replace(/["\r\n]/g, '').trim();

let htaccess = readFileSync(htaccessPath, 'utf8');
if (environment === 'development') {
  if (authUserFile) {
    if (!authUserFile.startsWith('/') || authUserFile.includes('..')) {
      throw new Error('DEV_HTPASSWD_FILE must be a safe absolute path');
    }
    if (!htaccess.includes('# kubus-staging-auth')) {
      htaccess = `# kubus-staging-auth\nAuthType Basic\nAuthName "${authRealm}"\nAuthUserFile "${authUserFile}"\nRequire valid-user\n\n${htaccess}`;
    }
  }
  if (!htaccess.includes('X-Robots-Tag "noindex, nofollow, noarchive"')) {
    htaccess = stagingBlock + htaccess;
  }
  writeFileSync(join(artifactDir, 'robots.txt'), 'User-agent: *\nDisallow: /\n');
} else {
  if (htaccess.includes('X-Robots-Tag "noindex, nofollow, noarchive"')) {
    throw new Error('production artifact unexpectedly contains the staging noindex block');
  }
  if (/^\s*AuthType\s+Basic/im.test(htaccess) || htaccess.includes('# kubus-staging-auth')) {
    throw new Error('production artifact unexpectedly contains a staging auth block');
  }
}
writeFileSync(htaccessPath, htaccess);
writeFileSync(join(artifactDir, 'kubus-web-revision.txt'), `${sourceSha}\n`);
writeFileSync(join(artifactDir, 'kubus-deployment-metadata.json'), `${JSON.stringify({ environment, sourceSha, artifact: `flutter-web-${environment}-${sourceSha}` }, null, 2)}\n`);

function walk(directory) {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

if (environment === 'development') {
  for (const file of walk(artifactDir).filter((path) => path.endsWith('.html'))) {
    const text = readFileSync(file, 'utf8');
    if (/rel=["']canonical["'][^>]+https:\/\/dev\.kubus\.site|https:\/\/dev\.kubus\.site[^>]+rel=["']canonical["']/i.test(text)) {
      throw new Error(`${basename(file)} declares the staging hostname as canonical`);
    }
  }
}

process.stdout.write(`Prepared ${environment} web artifact for ${sourceSha}.\n`);
