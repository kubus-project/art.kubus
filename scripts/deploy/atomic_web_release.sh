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
  [ -L "$LIVE_DIR" ] || die "LIVE_DIR must be a pre-provisioned symlink"
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
    awk 'tolower($1) == "authuserfile" { count += 1 } END { print count + 0 }' "$htaccess"
  )"
  [ "$auth_line_count" -eq 1 ] \
    || die "development authentication source is unavailable or ambiguous"
  auth_file="$(
    awk '
      tolower($1) == "authuserfile" {
        $1 = ""
        sub(/^[[:space:]]+/, "")
        print
        exit
      }
    ' "$htaccess"
  )"
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
  require_absolute_path HOME "${HOME:-}"
  case "$auth_file" in
    "$HOME"/.htpasswds/*/passwd) ;;
    *) die "development authentication source is outside the cPanel-managed account area" ;;
  esac
  [ -f "$auth_file" ] && [ -r "$auth_file" ] && [ -s "$auth_file" ] \
    || die "development authentication source is not a readable non-empty file"
  awk -F: '
    NF >= 2 && length($1) > 0 && length($2) > 0 { usable = 1 }
    END { exit usable ? 0 : 1 }
  ' "$auth_file" \
    || die "development authentication source has no usable credential record"
}

expected_application_htaccess_hash() {
  manifest="$1"
  entry_count="$(
    awk '{
      path = $2
      sub(/^\*/, "", path)
      if (path == "./.htaccess") count += 1
    } END { print count + 0 }' "$manifest"
  )"
  [ "$entry_count" -eq 1 ] \
    || die "artifact checksum manifest must contain exactly one .htaccess entry"
  awk '{
    path = $2
    sub(/^\*/, "", path)
    if (path == "./.htaccess") {
      print $1
      exit
    }
  }' "$manifest"
}

write_host_policy_manifest() {
  release="$1"
  application_hash="$2"
  policy_dir="$RELEASE_ROOT/host-policy"
  policy_manifest="$policy_dir/$SOURCE_SHA"
  policy_tmp="$policy_manifest.tmp"
  final_hash="$(sha256sum "$release/.htaccess" | awk '{ print $1 }')"

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
  final_hash="$(sha256sum "$release/.htaccess" | awk '{ print $1 }')"
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

  live_htaccess="$LIVE_DIR/.htaccess"
  [ -f "$live_htaccess" ] \
    || die "current development release has no cPanel authentication policy"
  auth_file="$(extract_auth_user_file "$live_htaccess")"
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
  [ "$(awk -v marker="$development_policy_begin" '$0 == marker { count += 1 } END { print count + 0 }' "$htaccess")" -eq 1 ] \
    || die "development authentication policy begin marker is duplicated"
  [ "$(awk -v marker="$development_policy_end" '$0 == marker { count += 1 } END { print count + 0 }' "$htaccess")" -eq 1 ] \
    || die "development authentication policy end marker is missing or duplicated"
  [ "$(awk 'tolower($1) == "authtype" && tolower($2) == "basic" { count += 1 } END { print count + 0 }' "$htaccess")" -eq 1 ] \
    || die "development authentication policy must contain exactly one AuthType Basic directive"
  [ "$(awk 'tolower($1) == "require" && tolower($2) == "valid-user" { count += 1 } END { print count + 0 }' "$htaccess")" -eq 1 ] \
    || die "development authentication policy must contain exactly one Require valid-user directive"
  auth_file="$(extract_auth_user_file "$htaccess")"
  validate_auth_source "$auth_file"

  rm -rf "$verification_dir"
  mkdir -p "$verification_dir"
  sed "1,/^${development_policy_end}$/d" "$htaccess" | sed '1{/^$/d;}' > "$application_copy"
  [ "$(sha256sum "$application_copy" | awk '{ print $1 }')" = "$application_hash" ] \
    || die "development policy did not preserve the application .htaccess rules"
  awk '{
    path = $2
    sub(/^\*/, "", path)
    if (path != "./.htaccess") print
  }' "$manifest" > "$filtered_manifest"
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
    cmp -s "$candidate/SHA256SUMS" "$RELEASE_DIR/SHA256SUMS" \
      || die "existing immutable release does not match the uploaded artifact manifest"
    cmp -s "$candidate/.htaccess" "$RELEASE_DIR/.htaccess" \
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
  rollback_file="$RELEASE_ROOT/rollback-$SOURCE_SHA"
  verify_prepared_release "$RELEASE_DIR"

  previous_target="$(readlink "$LIVE_DIR")"
  [ -n "$previous_target" ] || die "LIVE_DIR has an empty symlink target"
  if [ "$previous_target" = "$RELEASE_DIR" ]; then
    printf '@already-current\n' > "$rollback_file"
    return
  fi
  printf '%s\n' "$previous_target" > "$rollback_file"

  next_link="$LIVE_DIR.next-$SOURCE_SHA"
  rm -f "$next_link"
  ln -s "$RELEASE_DIR" "$next_link"
  mv -Tf "$next_link" "$LIVE_DIR"
  [ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ] \
    || die "atomic promotion did not select the requested release"
}

rollback() {
  rollback_file="$RELEASE_ROOT/rollback-$SOURCE_SHA"
  [ -f "$rollback_file" ] || die "rollback state is missing"
  [ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ] \
    || die "current release changed after promotion; refusing stale rollback"
  previous_target="$(sed -n '1p' "$rollback_file")"
  [ -n "$previous_target" ] || die "rollback target is empty"
  if [ "$previous_target" = "@already-current" ]; then
    rm -f "$rollback_file"
    return
  fi

  rollback_link="$LIVE_DIR.rollback-$SOURCE_SHA"
  rm -f "$rollback_link"
  ln -s "$previous_target" "$rollback_link"
  mv -Tf "$rollback_link" "$LIVE_DIR"
  [ "$(readlink "$LIVE_DIR")" = "$previous_target" ] \
    || die "atomic rollback did not restore the previous release"
  rm -f "$rollback_file"
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
  [ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ] \
    || die "requested release is not current; refusing finalization"
  verify_prepared_release "$RELEASE_DIR"
  rm -f "$RELEASE_ROOT/rollback-$SOURCE_SHA"
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
