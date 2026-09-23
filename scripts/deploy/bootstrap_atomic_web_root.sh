#!/usr/bin/env sh

# Netcup serves physical httpdocs directories. This preflight intentionally
# leaves the Plesk document root in place; the first promotion backs it up.
set -eu

die() {
  echo "Netcup web root preflight: $*" >&2
  exit 1
}

live_dir="${1%/}"
release_root="${2%/}"
source_sha="${3:-}"

printf '%s' "$source_sha" | grep -Eq '^[0-9a-f]{40}$' \
  || die "SOURCE_SHA must be a full lowercase commit SHA"
if [ "${KUBUS_DEPLOY_TEST_MODE:-}" = 1 ]; then
  [ "$source_sha" = '0123456789abcdef0123456789abcdef01234567' ] \
    || die "test mode requires the test-only SHA"
  test_root="${live_dir%/current}"
  case "$test_root" in /tmp/kubus-netcup-test-*) ;; *) die "test mode requires an isolated /tmp root" ;; esac
  [ "$live_dir" = "$test_root/current" ] \
    && [ "$release_root" = "$test_root/releases-root" ] \
    || die "test mode paths differ from the isolated fixture"
else
  case "$live_dir:$release_root" in
    /app.kubus.site/httpdocs:/deploy/app.kubus.site|/dev.kubus.site/httpdocs:/deploy/dev.kubus.site) ;;
    *) die "paths are not an approved Netcup document root and private release pair" ;;
  esac
fi
[ -d "$live_dir" ] && [ ! -L "$live_dir" ] \
  || die "the Netcup document root must be an existing physical directory"
[ -d "$release_root" ] && [ ! -L "$release_root" ] \
  || die "the Netcup private release root must be an existing physical directory"
mkdir -p "$release_root/releases"
echo "Netcup physical document root is ready for guarded promotion."
