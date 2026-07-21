#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "deployment target: $*" >&2
  exit 1
}

: "${DEPLOYMENT_ENVIRONMENT:?DEPLOYMENT_ENVIRONMENT is required}"
: "${ENVIRONMENT_NAME:?ENVIRONMENT_NAME is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${SFTP_SERVER:?SFTP_SERVER is required}"
: "${SFTP_USERNAME:?SFTP_USERNAME is required}"
: "${SFTP_PRIVATE_KEY:?SFTP_PRIVATE_KEY is required}"
: "${SFTP_HOST_FINGERPRINT:?SFTP_HOST_FINGERPRINT is required}"
: "${SFTP_PORT:?SFTP_PORT is required}"
: "${WEB_SERVER_DIR:?WEB_SERVER_DIR is required}"
: "${WEB_RELEASES_DIR:?WEB_RELEASES_DIR is required}"
: "${WEB_SMOKE_URL:?WEB_SMOKE_URL is required}"
: "${EXPECTED_DEPLOYMENT_HOST:?EXPECTED_DEPLOYMENT_HOST is required}"
: "${RETAIN_RELEASE_COUNT:?RETAIN_RELEASE_COUNT is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

[ "$ENVIRONMENT_NAME" = "$DEPLOYMENT_ENVIRONMENT" ] || die "ENVIRONMENT_NAME does not match the selected environment"
printf '%s' "$SOURCE_SHA" | grep -Eq '^[0-9a-f]{40}$' || die "SOURCE_SHA must be a full lowercase commit SHA"
printf '%s' "$SFTP_SERVER" | grep -Eq '^[A-Za-z0-9.-]+$' || die "SFTP_SERVER contains unsupported characters"
printf '%s' "$EXPECTED_DEPLOYMENT_HOST" | grep -Eq '^[A-Za-z0-9.-]+$' || die "EXPECTED_DEPLOYMENT_HOST contains unsupported characters"
[ "$SFTP_SERVER" = "$EXPECTED_DEPLOYMENT_HOST" ] || die "SFTP_SERVER does not match EXPECTED_DEPLOYMENT_HOST"
printf '%s' "$SFTP_USERNAME" | grep -Eq '^[A-Za-z0-9._-]+$' || die "SFTP_USERNAME contains unsupported characters"
printf '%s' "$SFTP_PORT" | grep -Eq '^[0-9]+$' || die "SFTP_PORT must be numeric"
if [ "$SFTP_PORT" -lt 1 ] || [ "$SFTP_PORT" -gt 65535 ]; then
  die "SFTP_PORT is out of range"
fi
printf '%s' "$RETAIN_RELEASE_COUNT" | grep -Eq '^[0-9]+$' || die "RETAIN_RELEASE_COUNT must be numeric"
[ "$RETAIN_RELEASE_COUNT" -le 50 ] || die "RETAIN_RELEASE_COUNT must not exceed 50"

live_dir="${WEB_SERVER_DIR%/}"
live_dir="${live_dir//\{SFTP_USERNAME\}/$SFTP_USERNAME}"
release_root="${WEB_RELEASES_DIR%/}"
release_root="${release_root//\{SFTP_USERNAME\}/$SFTP_USERNAME}"
for value in "$live_dir" "$release_root"; do
  printf '%s' "$value" | grep -Eq '^/[A-Za-z0-9_./-]+$' || die "deployment paths must be safe absolute paths"
  case "$value" in *..*) die "deployment paths must not contain '..'" ;; esac
  [ "$value" != / ] || die "deployment paths must not be the filesystem root"
done
[ "$live_dir" != "$release_root" ] || die "live and release directories must differ"
case "$release_root/" in "$live_dir/"*) die "release root must not be inside the live directory" ;; esac

printf '%s' "$WEB_SMOKE_URL" | grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/.*)?$' || die "WEB_SMOKE_URL must be an HTTPS URL without credentials"
case "$WEB_SMOKE_URL" in *'@'*) die "WEB_SMOKE_URL must not contain credentials" ;; esac
if [ "$DEPLOYMENT_ENVIRONMENT" = development ]; then
  printf '%s' "$WEB_SMOKE_URL" | grep -Eq '^https://dev\.kubus\.site(/|$)' || die "development smoke URL must use dev.kubus.site"
fi

{
  echo "live_dir=$live_dir"
  echo "release_root=$release_root"
  echo "incoming_dir=$release_root/incoming-$SOURCE_SHA"
  echo "release_dir=$release_root/releases/$SOURCE_SHA"
  echo "smoke_url=$WEB_SMOKE_URL"
  echo "retained_releases=$RETAIN_RELEASE_COUNT"
} >> "$GITHUB_OUTPUT"

echo "Validated $DEPLOYMENT_ENVIRONMENT deployment target contract."
