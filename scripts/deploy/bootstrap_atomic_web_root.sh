#!/usr/bin/env sh

set -eu

die() {
  echo "atomic web bootstrap: $*" >&2
  exit 1
}

require_absolute_path() {
  label="$1"
  value="$2"
  case "$value" in
    /*) ;;
    *) die "$label must be an absolute path" ;;
  esac
  case "$value" in
    *..*) die "$label must not contain '..'" ;;
  esac
  [ "$value" != "/" ] || die "$label must not be the filesystem root"
}

live_dir="${1%/}"
release_root="${2%/}"
source_sha="$3"

require_absolute_path LIVE_DIR "$live_dir"
require_absolute_path RELEASE_ROOT "$release_root"
printf '%s' "$source_sha" | grep -Eq '^[0-9a-f]{40}$' \
  || die "SOURCE_SHA must be a full lowercase commit SHA"

authenticated_home="$(pwd -P)"
[ "$(dirname "$live_dir")" = "$authenticated_home" ] \
  || die "LIVE_DIR must be a direct child of the authenticated SFTP home"
case "$release_root/" in
  "$live_dir/"*) die "RELEASE_ROOT must not be inside LIVE_DIR" ;;
esac

bootstrap_release="$release_root/releases/pre-atomic-$source_sha"
mkdir -p "$release_root/releases"

if [ -L "$live_dir" ]; then
  current_target="$(readlink "$live_dir")"
  case "$current_target" in
    "$release_root/releases/"*) ;;
    *) die "existing LIVE_DIR symlink points outside the immutable releases tree" ;;
  esac
  [ -d "$live_dir" ] || die "existing LIVE_DIR symlink target is unavailable"
  echo "Atomic web root is already provisioned."
  exit 0
fi

if [ ! -e "$live_dir" ] && [ -d "$bootstrap_release" ]; then
  ln -s "$bootstrap_release" "$live_dir" \
    || die "failed to recover the live symlink after an interrupted bootstrap"
fi

if [ -L "$live_dir" ]; then
  [ "$(readlink "$live_dir")" = "$bootstrap_release" ] \
    || die "recovered LIVE_DIR points at an unexpected target"
  echo "Recovered the atomic web root after an interrupted bootstrap."
  exit 0
fi

[ -d "$live_dir" ] || die "LIVE_DIR must be an existing physical directory"
[ ! -e "$bootstrap_release" ] \
  || die "bootstrap release already exists while LIVE_DIR is still physical"

mv "$live_dir" "$bootstrap_release"
if ! ln -s "$bootstrap_release" "$live_dir"; then
  mv "$bootstrap_release" "$live_dir" \
    || die "symlink creation failed and the original directory could not be restored"
  die "symlink creation failed; the original directory was restored"
fi

[ "$(readlink "$live_dir")" = "$bootstrap_release" ] \
  || die "LIVE_DIR does not point at the preserved bootstrap release"
[ -d "$live_dir" ] || die "preserved bootstrap release is unavailable"
echo "Migrated the existing web root into the atomic release layout."
