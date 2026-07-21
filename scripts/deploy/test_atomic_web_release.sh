#!/usr/bin/env sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
release_script="$script_dir/atomic_web_release.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

SOURCE_SHA=0123456789abcdef0123456789abcdef01234567
RELEASE_ROOT="$tmp_root/releases-root"
INCOMING_DIR="$RELEASE_ROOT/incoming-$SOURCE_SHA"
RELEASE_DIR="$RELEASE_ROOT/releases/$SOURCE_SHA"
LIVE_DIR="$tmp_root/current"
RETAIN_RELEASE_COUNT=1
export SOURCE_SHA RELEASE_ROOT INCOMING_DIR RELEASE_DIR LIVE_DIR RETAIN_RELEASE_COUNT

mkdir -p "$tmp_root/previous" "$INCOMING_DIR" "$tmp_root/payload"
printf 'previous\n' > "$tmp_root/previous/index.html"
ln -s "$tmp_root/previous" "$LIVE_DIR"

printf '<html>candidate</html>\n' > "$tmp_root/payload/index.html"
printf 'bootstrap\n' > "$tmp_root/payload/flutter_bootstrap.js"
(
  cd "$tmp_root/payload"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)
archive="art-kubus-web-$SOURCE_SHA.tar.gz"
tar -C "$tmp_root/payload" -czf "$INCOMING_DIR/$archive" .
(cd "$INCOMING_DIR" && sha256sum "$archive" > "$archive.sha256")

sh "$release_script" promote
[ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ]
[ "$(cat "$LIVE_DIR/index.html")" = '<html>candidate</html>' ]
[ -f "$RELEASE_ROOT/rollback-$SOURCE_SHA" ]

sh "$release_script" rollback
[ "$(readlink "$LIVE_DIR")" = "$tmp_root/previous" ]
[ "$(cat "$LIVE_DIR/index.html")" = 'previous' ]

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
rm -rf "$INCOMING_DIR"
[ ! -e "$INCOMING_DIR" ]

if sh "$release_script" promote >/dev/null 2>&1; then
  echo 'promotion unexpectedly succeeded without an incoming artifact' >&2
  exit 1
fi

echo 'Atomic web promotion and rollback test passed.'
