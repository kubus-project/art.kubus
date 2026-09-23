#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
release_script="$script_dir/atomic_web_release.sh"
tmp_root="$(mktemp -d /tmp/kubus-netcup-test-XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

export KUBUS_DEPLOY_TEST_MODE=1
export LIVE_DIR="$tmp_root/current"
export RELEASE_ROOT="$tmp_root/releases-root"
export RETAIN_RELEASE_COUNT=3
mkdir -p "$LIVE_DIR" "$RELEASE_ROOT"
printf 'previous placeholder\n' > "$LIVE_DIR/index.html"

build_archive() {
  payload="$1"
  mkdir -p "$INCOMING_DIR"
  (
    cd "$payload"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
  )
  archive="art-kubus-web-$SOURCE_SHA.tar.gz"
  tar -C "$payload" -czf "$INCOMING_DIR/$archive" .
  (cd "$INCOMING_DIR" && sha256sum "$archive" > "$archive.sha256")
}

export SOURCE_SHA=0123456789abcdef0123456789abcdef01234567
export DEPLOYMENT_ENVIRONMENT=development
export INCOMING_DIR="$RELEASE_ROOT/incoming-$SOURCE_SHA"
export RELEASE_DIR="$RELEASE_ROOT/releases/$SOURCE_SHA"
payload="$tmp_root/dev-payload"
mkdir -p "$payload"
printf '<html>development</html>\n' > "$payload/index.html"
printf '%s\n' "$SOURCE_SHA" > "$payload/kubus-web-revision.txt"
printf 'RewriteEngine On\nRewriteRule ^app$ index.html [L]\n' > "$payload/.htaccess"
build_archive "$payload"

if sh "$release_script" prepare >/dev/null 2>&1; then
  echo 'development preparation accepted a missing private password file' >&2
  exit 1
fi
[ -d "$LIVE_DIR" ] && [ ! -e "$RELEASE_DIR" ]
mkdir -p "$RELEASE_ROOT/auth"
printf 'test-user:$2y$test-only-hash\n' > "$RELEASE_ROOT/auth/passwd"
sh "$release_script" prepare >/dev/null
[ -d "$RELEASE_DIR" ]
grep -Fq 'AuthUserFile "'"$RELEASE_ROOT/auth/passwd"'"' "$RELEASE_DIR/.htaccess"
grep -Fq 'RewriteRule ^app$ index.html [L]' "$RELEASE_DIR/.htaccess"
[ -f "$RELEASE_ROOT/host-policy/$SOURCE_SHA" ]
sh "$release_script" promote >/dev/null
[ -d "$LIVE_DIR" ] && [ ! -L "$LIVE_DIR" ]
[ "$(cat "$LIVE_DIR/kubus-web-revision.txt")" = "$SOURCE_SHA" ]
[ -d "$RELEASE_ROOT/rollback-$SOURCE_SHA" ]
sh "$release_script" rollback >/dev/null
[ "$(cat "$LIVE_DIR/index.html")" = 'previous placeholder' ]

# The immutable directory cannot be silently replaced by a changed artifact.
printf '<html>changed</html>\n' > "$payload/index.html"
rm -rf "$INCOMING_DIR"
build_archive "$payload"
if sh "$release_script" prepare >/dev/null 2>&1; then
  echo 'an existing SHA release accepted different payload bytes' >&2
  exit 1
fi

export SOURCE_SHA=89abcdef0123456789abcdef0123456789abcdef
export DEPLOYMENT_ENVIRONMENT=production
export INCOMING_DIR="$RELEASE_ROOT/incoming-$SOURCE_SHA"
export RELEASE_DIR="$RELEASE_ROOT/releases/$SOURCE_SHA"
production="$tmp_root/prod-payload"
mkdir -p "$production"
printf '<html>production</html>\n' > "$production/index.html"
printf '%s\n' "$SOURCE_SHA" > "$production/kubus-web-revision.txt"
printf 'AuthType Basic\nRequire valid-user\n' > "$production/.htaccess"
build_archive "$production"
if sh "$release_script" prepare >/dev/null 2>&1; then
  echo 'production accepted development auth directives' >&2
  exit 1
fi
printf 'RewriteEngine On\n' > "$production/.htaccess"
rm -rf "$INCOMING_DIR"
build_archive "$production"
sh "$release_script" prepare >/dev/null
sh "$release_script" promote >/dev/null
sh "$release_script" finalize >/dev/null
if grep -Eiq 'AuthType|AuthUserFile|KUBUS HOST DEVELOPMENT AUTH' "$LIVE_DIR/.htaccess"; then
  echo 'production inherited development authentication' >&2
  exit 1
fi
[ -d "$RELEASE_ROOT/rollback-$SOURCE_SHA" ]
sh "$release_script" rollback >/dev/null
[ "$(cat "$LIVE_DIR/index.html")" = 'previous placeholder' ]

echo 'Netcup physical release, private auth, checksum and rollback tests passed.'
