#!/usr/bin/env sh

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
release_script="$script_dir/atomic_web_release.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

build_archive() {
  payload_dir="$1"
  incoming_dir="$2"
  source_sha="$3"
  rm -rf "$incoming_dir"
  mkdir -p "$incoming_dir"
  (
    cd "$payload_dir"
    find . -type f ! -name SHA256SUMS -print0 \
      | sort -z \
      | xargs -0 sha256sum > SHA256SUMS
  )
  archive="art-kubus-web-$source_sha.tar.gz"
  tar -C "$payload_dir" -czf "$incoming_dir/$archive" .
  (cd "$incoming_dir" && sha256sum "$archive" > "$archive.sha256")
}

SOURCE_SHA=0123456789abcdef0123456789abcdef01234567
DEPLOYMENT_ENVIRONMENT=development
RELEASE_ROOT="$tmp_root/releases-root"
INCOMING_DIR="$RELEASE_ROOT/incoming-$SOURCE_SHA"
RELEASE_DIR="$RELEASE_ROOT/releases/$SOURCE_SHA"
LIVE_DIR="$tmp_root/current"
RETAIN_RELEASE_COUNT=1
HOME="$tmp_root/account"
export DEPLOYMENT_ENVIRONMENT SOURCE_SHA RELEASE_ROOT INCOMING_DIR RELEASE_DIR
export LIVE_DIR RETAIN_RELEASE_COUNT HOME

previous_release="$tmp_root/previous"
payload="$tmp_root/payload"
mkdir -p "$previous_release" "$payload" "$HOME"
printf 'previous\n' > "$previous_release/index.html"
printf '<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n' > "$previous_release/.htaccess"
ln -s "$previous_release" "$LIVE_DIR"

printf '<html>candidate</html>\n' > "$payload/index.html"
printf 'bootstrap\n' > "$payload/flutter_bootstrap.js"
printf '<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteRule ^app$ index.html [L]\n</IfModule>\n' > "$payload/.htaccess"
build_archive "$payload" "$INCOMING_DIR" "$SOURCE_SHA"
cp "$payload/SHA256SUMS" "$tmp_root/original-SHA256SUMS"

failed_output="$tmp_root/failed-prepare.log"
if sh "$release_script" prepare >"$failed_output" 2>&1; then
  echo 'development preparation unexpectedly succeeded without a host auth source' >&2
  exit 1
fi
[ "$(readlink "$LIVE_DIR")" = "$previous_release" ]
[ ! -e "$RELEASE_DIR" ]
if grep -Fq "$HOME" "$failed_output"; then
  echo 'development preparation exposed the derived account path' >&2
  exit 1
fi

auth_source="$HOME/.htpasswds/dev.example.test/passwd"
mkdir -p "$(dirname "$auth_source")"
printf 'test-user:$2y$test-only-hash\n' > "$auth_source"
chmod 0600 "$auth_source"
{
  printf 'AuthType Basic\n'
  printf 'AuthName "cPanel protected"\n'
  printf 'AuthUserFile "%s"\n' "$auth_source"
  printf 'Require valid-user\n\n'
  printf '<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n'
} > "$previous_release/.htaccess"

sh "$release_script" prepare
[ "$(readlink "$LIVE_DIR")" = "$previous_release" ]
[ -d "$RELEASE_DIR" ]
[ "$(grep -Fc '# BEGIN KUBUS HOST DEVELOPMENT AUTH' "$RELEASE_DIR/.htaccess")" -eq 1 ]
[ "$(grep -Fc '# END KUBUS HOST DEVELOPMENT AUTH' "$RELEASE_DIR/.htaccess")" -eq 1 ]
grep -Fq 'RewriteRule ^app$ index.html [L]' "$RELEASE_DIR/.htaccess"
cmp "$tmp_root/original-SHA256SUMS" "$RELEASE_DIR/SHA256SUMS"
policy_record="$RELEASE_ROOT/host-policy/$SOURCE_SHA"
[ -f "$policy_record" ]
if grep -Eq '/|AuthUserFile|htpass|home' "$policy_record"; then
  echo 'host-policy verification record exposed a host path' >&2
  exit 1
fi

sh "$release_script" promote
[ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ]
[ "$(cat "$LIVE_DIR/index.html")" = '<html>candidate</html>' ]
[ -f "$RELEASE_ROOT/rollback-$SOURCE_SHA" ]

sh "$release_script" rollback
[ "$(readlink "$LIVE_DIR")" = "$previous_release" ]
[ "$(cat "$LIVE_DIR/index.html")" = 'previous' ]

# A rolled-back SHA directory is immutable. A retry with different artifact
# contents must fail closed without replacing that directory.
release_identity="$(stat -c '%d:%i' "$RELEASE_DIR")"
mismatched_payload="$tmp_root/mismatched-payload"
cp -R "$payload" "$mismatched_payload"
printf '<html>different candidate</html>\n' > "$mismatched_payload/index.html"
build_archive "$mismatched_payload" "$INCOMING_DIR" "$SOURCE_SHA"
mismatch_output="$tmp_root/mismatched-retry.log"
if sh "$release_script" prepare >"$mismatch_output" 2>&1; then
  echo 'development preparation unexpectedly replaced an immutable SHA release' >&2
  exit 1
fi
grep -Fq 'existing immutable release does not match the uploaded artifact manifest' "$mismatch_output"
[ "$(stat -c '%d:%i' "$RELEASE_DIR")" = "$release_identity" ]
[ "$(readlink "$LIVE_DIR")" = "$previous_release" ]

# Reusing the immutable release also requires its prepared overlay to match the
# current cPanel policy. A moved auth source fails closed even while the old
# credential file remains readable.
build_archive "$payload" "$INCOMING_DIR" "$SOURCE_SHA"
rotated_auth_source="$HOME/.htpasswds/rotated.example.test/passwd"
mkdir -p "$(dirname "$rotated_auth_source")"
printf 'smoke-user:rotated-hash\n' > "$rotated_auth_source"
rotated_live_htaccess="$tmp_root/rotated-live.htaccess"
sed "s|AuthUserFile \"$auth_source\"|AuthUserFile \"$rotated_auth_source\"|" \
  "$previous_release/.htaccess" > "$rotated_live_htaccess"
mv "$rotated_live_htaccess" "$previous_release/.htaccess"
policy_mismatch_output="$tmp_root/policy-mismatched-retry.log"
if sh "$release_script" prepare >"$policy_mismatch_output" 2>&1; then
  echo 'development preparation unexpectedly reused a stale host policy' >&2
  exit 1
fi
grep -Fq 'existing immutable release does not match the current host policy' \
  "$policy_mismatch_output"
[ "$(stat -c '%d:%i' "$RELEASE_DIR")" = "$release_identity" ]
[ "$(readlink "$LIVE_DIR")" = "$previous_release" ]
restored_live_htaccess="$tmp_root/restored-live.htaccess"
sed "s|AuthUserFile \"$rotated_auth_source\"|AuthUserFile \"$auth_source\"|" \
  "$previous_release/.htaccess" > "$restored_live_htaccess"
mv "$restored_live_htaccess" "$previous_release/.htaccess"

# A failed deployment can be prepared and promoted again without duplicating
# host policy, replacing the immutable SHA directory, or regenerating the
# original artifact checksum manifest.
sh "$release_script" prepare
[ "$(stat -c '%d:%i' "$RELEASE_DIR")" = "$release_identity" ]
[ "$(grep -Fc '# BEGIN KUBUS HOST DEVELOPMENT AUTH' "$RELEASE_DIR/.htaccess")" -eq 1 ]
cmp "$tmp_root/original-SHA256SUMS" "$RELEASE_DIR/SHA256SUMS"
sh "$release_script" promote
[ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ]

old_release_one="$RELEASE_ROOT/releases/1111111111111111111111111111111111111111"
old_release_two="$RELEASE_ROOT/releases/2222222222222222222222222222222222222222"
mkdir -p "$old_release_one" "$old_release_two"
touch -t 202001010000 "$old_release_one"
touch -t 202101010000 "$old_release_two"
sh "$release_script" finalize
[ ! -e "$RELEASE_ROOT/rollback-$SOURCE_SHA" ]
[ ! -e "$old_release_one" ]
[ -d "$old_release_two" ]

# Re-running an already-current release is a verified no-op and remains
# finalizable; it never duplicates the auth overlay.
sh "$release_script" prepare
sh "$release_script" promote
[ "$(grep -Fc '# BEGIN KUBUS HOST DEVELOPMENT AUTH' "$RELEASE_DIR/.htaccess")" -eq 1 ]
sh "$release_script" finalize

# Production preparation rejects any authentication directive and never changes
# the live symlink before that failure.
SOURCE_SHA=89abcdef0123456789abcdef0123456789abcdef
DEPLOYMENT_ENVIRONMENT=production
INCOMING_DIR="$RELEASE_ROOT/incoming-$SOURCE_SHA"
RELEASE_DIR="$RELEASE_ROOT/releases/$SOURCE_SHA"
export SOURCE_SHA DEPLOYMENT_ENVIRONMENT INCOMING_DIR RELEASE_DIR
production_payload="$tmp_root/production-payload"
mkdir -p "$production_payload"
printf '<html>production</html>\n' > "$production_payload/index.html"
printf 'AuthType Basic\nAuthUserFile "/forbidden/host/path"\nRequire valid-user\n' > "$production_payload/.htaccess"
build_archive "$production_payload" "$INCOMING_DIR" "$SOURCE_SHA"
if sh "$release_script" prepare >/dev/null 2>&1; then
  echo 'production preparation unexpectedly accepted staging authentication' >&2
  exit 1
fi
[ "$(readlink "$LIVE_DIR")" = "$RELEASE_ROOT/releases/0123456789abcdef0123456789abcdef01234567" ]
[ ! -e "$RELEASE_DIR" ]

printf '<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n' > "$production_payload/.htaccess"
build_archive "$production_payload" "$INCOMING_DIR" "$SOURCE_SHA"
sh "$release_script" prepare
[ -d "$RELEASE_DIR" ]
if grep -Eiq 'AuthType|AuthUserFile|KUBUS HOST DEVELOPMENT AUTH' "$RELEASE_DIR/.htaccess"; then
  echo 'production release unexpectedly contains staging authentication' >&2
  exit 1
fi
[ "$(readlink "$LIVE_DIR")" != "$RELEASE_DIR" ]

echo 'Atomic web preparation, host policy, promotion, rollback, and retry tests passed.'
