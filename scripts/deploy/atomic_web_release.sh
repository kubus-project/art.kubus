#!/usr/bin/env sh

set -eu

development_policy_begin='# BEGIN KUBUS HOST DEVELOPMENT AUTH'
development_policy_end='# END KUBUS HOST DEVELOPMENT AUTH'

die() {
  echo "atomic web release: $*" >&2
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

validate_contract() {
  printf '%s' "$SOURCE_SHA" | grep -Eq '^[0-9a-f]{40}$' \
    || die "SOURCE_SHA must be a full lowercase commit SHA"
  case "$DEPLOYMENT_ENVIRONMENT" in
    development|production) ;;
    *) die "DEPLOYMENT_ENVIRONMENT must be development or production" ;;
  esac
  require_absolute_path LIVE_DIR "$LIVE_DIR"
  require_absolute_path RELEASE_ROOT "$RELEASE_ROOT"
  require_absolute_path INCOMING_DIR "$INCOMING_DIR"
  require_absolute_path RELEASE_DIR "$RELEASE_DIR"

  [ "$INCOMING_DIR" = "$RELEASE_ROOT/incoming-$SOURCE_SHA" ] \
    || die "INCOMING_DIR is outside the release contract"
  [ "$RELEASE_DIR" = "$RELEASE_ROOT/releases/$SOURCE_SHA" ] \
    || die "RELEASE_DIR is outside the release contract"
  if [ "${KUBUS_DEPLOY_TEST_MODE:-}" = 1 ]; then
    case "$SOURCE_SHA" in
      0123456789abcdef0123456789abcdef01234567|89abcdef0123456789abcdef0123456789abcdef) ;;
      *) die "test mode requires a test-only source SHA" ;;
    esac
    test_root="${LIVE_DIR%/current}"
    case "$test_root" in /tmp/kubus-netcup-test-*) ;; *) die "test mode requires an isolated /tmp root" ;; esac
    [ "$LIVE_DIR" = "$test_root/current" ] \
      && [ "$RELEASE_ROOT" = "$test_root/releases-root" ] \
      || die "test mode paths differ from the isolated fixture"
  else
    case "$DEPLOYMENT_ENVIRONMENT:$LIVE_DIR:$RELEASE_ROOT" in
      production:/app.kubus.site/httpdocs:/deploy/app.kubus.site|development:/dev.kubus.site/httpdocs:/deploy/dev.kubus.site) ;;
      *) die "deployment paths are not the approved Netcup environment pair" ;;
    esac
  fi
  [ -d "$LIVE_DIR" ] && [ ! -L "$LIVE_DIR" ] \
    || die "LIVE_DIR must be a physical Netcup document root"
  printf '%s' "$RETAIN_RELEASE_COUNT" | grep -Eq '^[0-9]+$' \
    || die "RETAIN_RELEASE_COUNT must be a non-negative integer"
  [ "$RETAIN_RELEASE_COUNT" -le 50 ] \
    || die "RETAIN_RELEASE_COUNT must not exceed 50"
}

verify_artifact_release() {
  candidate="$1"
  [ -f "$candidate/index.html" ] || die "release is missing index.html"
  [ -f "$candidate/.htaccess" ] || die "release is missing .htaccess"
  [ -f "$candidate/SHA256SUMS" ] || die "release is missing SHA256SUMS"
  [ "$(tr -d '\r\n' < "$candidate/kubus-web-revision.txt")" = "$SOURCE_SHA" ] \
    || die "release revision does not match SOURCE_SHA"
  (cd "$candidate" && sha256sum -c SHA256SUMS)
}

reject_auth_policy() {
  htaccess="$1"
  if grep -Eiq \
    '^[[:space:]]*(AuthType|AuthName|AuthUserFile|Require[[:space:]]+valid-user)([[:space:]]|$)' \
    "$htaccess"; then
    die "source artifact unexpectedly contains HTTP authentication policy"
  fi
  if grep -Fq "$development_policy_begin" "$htaccess" \
    || grep -Fq "$development_policy_end" "$htaccess"; then
    die "source artifact unexpectedly contains development host policy markers"
  fi
}

extract_auth_user_file() {
  htaccess="$1"
  auth_line_count="$(
    grep -Eic '^[[:space:]]*AuthUserFile[[:space:]]+' "$htaccess" || true
  )"
  [ "$auth_line_count" -eq 1 ] \
    || die "development authentication source is unavailable or ambiguous"
  auth_file="$(grep -Ei '^[[:space:]]*AuthUserFile[[:space:]]+' "$htaccess" \
    | head -n 1 | sed -E 's/^[[:space:]]*AuthUserFile[[:space:]]+//I')"
  case "$auth_file" in
    \"*\")
      auth_file="${auth_file#\"}"
      auth_file="${auth_file%\"}"
      ;;
  esac
  printf '%s' "$auth_file"
}

validate_auth_source() {
  auth_file="$1"
  require_absolute_path "development authentication source" "$auth_file"
  printf '%s' "$auth_file" | grep -Eq '^/[A-Za-z0-9._/-]+$' \
    || die "development authentication source has an unsafe path shape"
  expected_auth_file='/deploy/dev.kubus.site/auth/passwd'
  if [ "${KUBUS_DEPLOY_TEST_MODE:-}" = 1 ]; then
    expected_auth_file="$RELEASE_ROOT/auth/passwd"
  fi
  [ "$auth_file" = "$expected_auth_file" ] \
    || die "development authentication source is not the Netcup host-private password file"
  [ -f "$auth_file" ] && [ -r "$auth_file" ] && [ -s "$auth_file" ] \
    || die "development authentication source is not a readable non-empty file"
  grep -Eq '^[^:[:space:]]+:[^:[:space:]]+' "$auth_file" \
    || die "development authentication source has no usable credential record"
}

expected_application_htaccess_hash() {
  manifest="$1"
  entry_count="$(grep -Ec '^[0-9a-f]{64} [ *]\./\.htaccess$' "$manifest" || true)"
  [ "$entry_count" -eq 1 ] \
    || die "artifact checksum manifest must contain exactly one .htaccess entry"
  grep -E '^[0-9a-f]{64} [ *]\./\.htaccess$' "$manifest" | cut -d ' ' -f 1
}

write_host_policy_manifest() {
  release="$1"
  application_hash="$2"
  policy_dir="$RELEASE_ROOT/host-policy"
  policy_manifest="$policy_dir/$SOURCE_SHA"
  policy_tmp="$policy_manifest.tmp"
  final_hash="$(sha256sum "$release/.htaccess" | cut -d ' ' -f 1)"

  mkdir -p "$policy_dir"
  umask 077
  {
    printf 'version=1\n'
    printf 'environment=%s\n' "$DEPLOYMENT_ENVIRONMENT"
    printf 'source_sha=%s\n' "$SOURCE_SHA"
    printf 'application_htaccess_sha256=%s\n' "$application_hash"
    printf 'final_htaccess_sha256=%s\n' "$final_hash"
  } > "$policy_tmp"
  mv "$policy_tmp" "$policy_manifest"
}

verify_host_policy_manifest() {
  release="$1"
  application_hash="$2"
  policy_manifest="$RELEASE_ROOT/host-policy/$SOURCE_SHA"
  [ -f "$policy_manifest" ] || die "host-policy verification record is missing"
  [ "$(sed -n 's/^version=//p' "$policy_manifest")" = "1" ] \
    || die "host-policy verification record has an unsupported version"
  [ "$(sed -n 's/^environment=//p' "$policy_manifest")" = "$DEPLOYMENT_ENVIRONMENT" ] \
    || die "host-policy environment does not match the deployment request"
  [ "$(sed -n 's/^source_sha=//p' "$policy_manifest")" = "$SOURCE_SHA" ] \
    || die "host-policy source revision does not match the deployment request"
  [ "$(sed -n 's/^application_htaccess_sha256=//p' "$policy_manifest")" = "$application_hash" ] \
    || die "host-policy application rules do not match the original artifact"
  final_hash="$(sha256sum "$release/.htaccess" | cut -d ' ' -f 1)"
  [ "$(sed -n 's/^final_htaccess_sha256=//p' "$policy_manifest")" = "$final_hash" ] \
    || die "host-policy verification record does not match the prepared release"
  if grep -Eq '/|AuthUserFile|htpass|home' "$policy_manifest"; then
    die "host-policy verification record contains forbidden host details"
  fi
}

apply_development_policy() {
  candidate="$1"
  application_htaccess="$candidate/.htaccess"
  reject_auth_policy "$application_htaccess"

  auth_file='/deploy/dev.kubus.site/auth/passwd'
  if [ "${KUBUS_DEPLOY_TEST_MODE:-}" = 1 ]; then
    auth_file="$RELEASE_ROOT/auth/passwd"
  fi
  validate_auth_source "$auth_file"

  prepared_htaccess="$candidate/.htaccess.host-policy"
  {
    printf '%s\n' "$development_policy_begin"
    printf 'AuthType Basic\n'
    printf 'AuthName "Protected development site"\n'
    printf 'AuthUserFile "%s"\n' "$auth_file"
    printf 'Require valid-user\n'
    printf '%s\n\n' "$development_policy_end"
    cat "$application_htaccess"
  } > "$prepared_htaccess"
  chmod 0644 "$prepared_htaccess"
  mv "$prepared_htaccess" "$application_htaccess"
}

verify_development_policy() {
  release="$1"
  htaccess="$release/.htaccess"
  manifest="$release/SHA256SUMS"
  application_hash="$(expected_application_htaccess_hash "$manifest")"
  verification_dir="$INCOMING_DIR/host-policy-verification"
  application_copy="$verification_dir/application.htaccess"
  filtered_manifest="$verification_dir/SHA256SUMS.without-htaccess"

  [ "$(sed -n '1p' "$htaccess")" = "$development_policy_begin" ] \
    || die "development authentication policy is not the first .htaccess block"
  [ "$(grep -Fxc "$development_policy_begin" "$htaccess" || true)" -eq 1 ] \
    || die "development authentication policy begin marker is duplicated"
  [ "$(grep -Fxc "$development_policy_end" "$htaccess" || true)" -eq 1 ] \
    || die "development authentication policy end marker is missing or duplicated"
  [ "$(grep -Eic '^[[:space:]]*AuthType[[:space:]]+Basic[[:space:]]*$' "$htaccess" || true)" -eq 1 ] \
    || die "development authentication policy must contain exactly one AuthType Basic directive"
  [ "$(grep -Eic '^[[:space:]]*Require[[:space:]]+valid-user[[:space:]]*$' "$htaccess" || true)" -eq 1 ] \
    || die "development authentication policy must contain exactly one Require valid-user directive"
  auth_file="$(extract_auth_user_file "$htaccess")"
  validate_auth_source "$auth_file"

  rm -rf "$verification_dir"
  mkdir -p "$verification_dir"
  sed "1,/^${development_policy_end}$/d" "$htaccess" | sed '1{/^$/d;}' > "$application_copy"
  [ "$(sha256sum "$application_copy" | cut -d ' ' -f 1)" = "$application_hash" ] \
    || die "development policy did not preserve the application .htaccess rules"
  grep -Ev '^[0-9a-f]{64} [ *]\./\.htaccess$' "$manifest" > "$filtered_manifest"
  (cd "$release" && sha256sum -c "$filtered_manifest")
  rm -rf "$verification_dir"
  verify_host_policy_manifest "$release" "$application_hash"
}

verify_production_policy() {
  release="$1"
  reject_auth_policy "$release/.htaccess"
  verify_artifact_release "$release"
  application_hash="$(expected_application_htaccess_hash "$release/SHA256SUMS")"
  verify_host_policy_manifest "$release" "$application_hash"
}

verify_prepared_release() {
  release="$1"
  [ -d "$release" ] || die "prepared release directory is missing"
  [ "$(tr -d '\r\n' < "$release/kubus-web-revision.txt")" = "$SOURCE_SHA" ] \
    || die "prepared release revision does not match SOURCE_SHA"
  case "$DEPLOYMENT_ENVIRONMENT" in
    development) verify_development_policy "$release" ;;
    production) verify_production_policy "$release" ;;
  esac
}

prepare() {
  archive="art-kubus-web-$SOURCE_SHA.tar.gz"
  archive_path="$INCOMING_DIR/$archive"
  checksum_path="$archive_path.sha256"
  candidate="$INCOMING_DIR/payload"

  [ -f "$archive_path" ] || die "incoming archive is missing"
  [ -f "$checksum_path" ] || die "incoming archive checksum is missing"
  (cd "$INCOMING_DIR" && sha256sum -c "$archive.sha256")

  rm -rf "$candidate"
  mkdir "$candidate"
  tar -xzf "$archive_path" -C "$candidate"
  verify_artifact_release "$candidate"
  reject_auth_policy "$candidate/.htaccess"
  application_hash="$(expected_application_htaccess_hash "$candidate/SHA256SUMS")"

  case "$DEPLOYMENT_ENVIRONMENT" in
    development) apply_development_policy "$candidate" ;;
    production) ;;
  esac

  if [ -e "$RELEASE_DIR" ] || [ -L "$RELEASE_DIR" ]; then
    [ -d "$RELEASE_DIR" ] || die "immutable release path is not a directory"
    [ "$(sha256sum "$candidate/SHA256SUMS" | cut -d ' ' -f 1)" = "$(sha256sum "$RELEASE_DIR/SHA256SUMS" | cut -d ' ' -f 1)" ] \
      || die "existing immutable release does not match the uploaded artifact manifest"
    [ "$(sha256sum "$candidate/.htaccess" | cut -d ' ' -f 1)" = "$(sha256sum "$RELEASE_DIR/.htaccess" | cut -d ' ' -f 1)" ] \
      || die "existing immutable release does not match the current host policy"
    rm -rf "$candidate"
    verify_prepared_release "$RELEASE_DIR"
    return
  fi

  mkdir -p "$RELEASE_ROOT/releases"
  mv "$candidate" "$RELEASE_DIR"
  write_host_policy_manifest "$RELEASE_DIR" "$application_hash"
  verify_prepared_release "$RELEASE_DIR"
}

promote() {
  rollback_dir="$RELEASE_ROOT/rollback-$SOURCE_SHA"
  candidate_dir="$LIVE_DIR.next-$SOURCE_SHA"
  verify_prepared_release "$RELEASE_DIR"
  if [ -f "$LIVE_DIR/kubus-web-revision.txt" ] \
    && [ "$(tr -d '\r\n' < "$LIVE_DIR/kubus-web-revision.txt")" = "$SOURCE_SHA" ]; then
    verify_prepared_release "$LIVE_DIR"
    return
  fi
  [ ! -e "$rollback_dir" ] && [ ! -e "$candidate_dir" ] \
    || die "rollback or candidate directory already exists; refusing overwrite"
  cp -a "$RELEASE_DIR" "$candidate_dir"
  find "$candidate_dir" -type d -exec chmod 755 {} +
  find "$candidate_dir" -type f -exec chmod 644 {} +
  verify_prepared_release "$candidate_dir"
  mv "$LIVE_DIR" "$rollback_dir"
  if ! mv "$candidate_dir" "$LIVE_DIR"; then
    mv "$rollback_dir" "$LIVE_DIR" \
      || die "promotion failed and the previous document root could not be restored"
    die "promotion failed; restored the previous document root"
  fi
  if ! (verify_prepared_release "$LIVE_DIR"); then
    failed_dir="$RELEASE_ROOT/failed-$SOURCE_SHA"
    [ ! -e "$failed_dir" ] || die "failed-release path already exists"
    mv "$LIVE_DIR" "$failed_dir"
    mv "$rollback_dir" "$LIVE_DIR" \
      || die "post-promotion verification failed and previous document root could not be restored"
    die "post-promotion verification failed; restored previous document root"
  fi
}

rollback() {
  rollback_dir="$RELEASE_ROOT/rollback-$SOURCE_SHA"
  failed_dir="$RELEASE_ROOT/failed-$SOURCE_SHA"
  [ -d "$rollback_dir" ] && [ ! -L "$rollback_dir" ] || die "rollback state is missing"
  [ ! -e "$failed_dir" ] || die "failed-release path already exists"
  [ "$(tr -d '\r\n' < "$LIVE_DIR/kubus-web-revision.txt")" = "$SOURCE_SHA" ] \
    || die "current release changed after promotion; refusing stale rollback"
  mv "$LIVE_DIR" "$failed_dir"
  if ! mv "$rollback_dir" "$LIVE_DIR"; then
    mv "$failed_dir" "$LIVE_DIR" \
      || die "rollback failed and the current document root could not be restored"
    die "rollback failed; restored the current document root"
  fi
}

prune_releases() {
  kept=0
  for candidate in $(ls -1dt "$RELEASE_ROOT"/releases/* 2>/dev/null || true); do
    [ -d "$candidate" ] || continue
    [ ! -L "$candidate" ] || continue
    [ "$candidate" != "$RELEASE_DIR" ] || continue
    release_name="$(basename "$candidate")"
    printf '%s' "$release_name" | grep -Eq '^[0-9a-f]{40}$' || continue
    kept=$((kept + 1))
    if [ "$kept" -gt "$RETAIN_RELEASE_COUNT" ]; then
      rm -rf -- "$candidate"
      rm -f "$RELEASE_ROOT/host-policy/$release_name"
    fi
  done
}

finalize() {
  [ "$(tr -d '\r\n' < "$LIVE_DIR/kubus-web-revision.txt")" = "$SOURCE_SHA" ] \
    || die "requested release is not current; refusing finalization"
  verify_prepared_release "$RELEASE_DIR"
  verify_prepared_release "$LIVE_DIR"
  prune_releases
}

mode="${1:-}"
: "${DEPLOYMENT_ENVIRONMENT:?DEPLOYMENT_ENVIRONMENT is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${LIVE_DIR:?LIVE_DIR is required}"
: "${RELEASE_ROOT:?RELEASE_ROOT is required}"
: "${INCOMING_DIR:?INCOMING_DIR is required}"
: "${RELEASE_DIR:?RELEASE_DIR is required}"
: "${RETAIN_RELEASE_COUNT:=5}"
validate_contract

case "$mode" in
  prepare) prepare ;;
  promote) promote ;;
  rollback) rollback ;;
  finalize) finalize ;;
  *) die "usage: atomic_web_release.sh <prepare|promote|rollback|finalize>" ;;
esac
