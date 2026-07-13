#!/usr/bin/env sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bootstrap_script="$script_dir/bootstrap_atomic_web_root.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

home_dir="$tmp_root/home/deploy-user"
live_dir="$home_dir/app.kubus.site"
release_root="$home_dir/.art-kubus-releases"
source_sha=0123456789abcdef0123456789abcdef01234567
mkdir -p "$live_dir"
printf 'existing release\n' > "$live_dir/index.html"

(
  cd "$home_dir"
  sh "$bootstrap_script" "$live_dir" "$release_root" "$source_sha"
)

bootstrap_release="$release_root/releases/pre-atomic-$source_sha"
[ -L "$live_dir" ]
[ "$(readlink "$live_dir")" = "$bootstrap_release" ]
[ "$(cat "$live_dir/index.html")" = 'existing release' ]

(
  cd "$home_dir"
  sh "$bootstrap_script" "$live_dir" "$release_root" "$source_sha"
)

recovery_live="$home_dir/recovery.kubus.site"
recovery_root="$home_dir/.art-kubus-recovery"
recovery_sha=89abcdef0123456789abcdef0123456789abcdef
recovery_release="$recovery_root/releases/pre-atomic-$recovery_sha"
mkdir -p "$recovery_release"
printf 'recovered release\n' > "$recovery_release/index.html"
(
  cd "$home_dir"
  sh "$bootstrap_script" "$recovery_live" "$recovery_root" "$recovery_sha"
)
[ -L "$recovery_live" ]
[ "$(cat "$recovery_live/index.html")" = 'recovered release' ]

outside="$home_dir/outside"
unsafe_live="$home_dir/unsafe.kubus.site"
mkdir -p "$outside"
ln -s "$outside" "$unsafe_live"
if (
  cd "$home_dir"
  sh "$bootstrap_script" "$unsafe_live" "$release_root" "$source_sha"
) >/dev/null 2>&1; then
  echo 'bootstrap unexpectedly accepted a symlink outside the release tree' >&2
  exit 1
fi

echo 'Atomic web-root bootstrap test passed.'
