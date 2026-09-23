#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
tmp_root="$(mktemp -d /tmp/kubus-netcup-test-XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM
live="$tmp_root/current"
root="$tmp_root/releases-root"
sha=0123456789abcdef0123456789abcdef01234567
export KUBUS_DEPLOY_TEST_MODE=1

mkdir -p "$live" "$root"
printf 'preserve me\n' > "$live/index.html"
sh "$script_dir/bootstrap_atomic_web_root.sh" "$live" "$root" "$sha"
[ -d "$live" ] && [ ! -L "$live" ]
[ "$(cat "$live/index.html")" = 'preserve me' ]
[ -d "$root/releases" ]

if sh "$script_dir/bootstrap_atomic_web_root.sh" "$tmp_root/other" "$root" "$sha" >/dev/null 2>&1; then
  echo 'bootstrap accepted an unapproved document root' >&2
  exit 1
fi

mv "$live" "$tmp_root/old"
ln -s "$tmp_root/old" "$live"
if sh "$script_dir/bootstrap_atomic_web_root.sh" "$live" "$root" "$sha" >/dev/null 2>&1; then
  echo 'bootstrap accepted a symlinked document root' >&2
  exit 1
fi
echo 'Physical Netcup root preflight tests passed.'
