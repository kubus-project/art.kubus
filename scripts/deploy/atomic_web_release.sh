#!/usr/bin/env sh

set -eu

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

verify_release() {
  candidate="$1"
  [ -f "$candidate/index.html" ] || die "release is missing index.html"
  [ -f "$candidate/SHA256SUMS" ] || die "release is missing SHA256SUMS"
  (cd "$candidate" && sha256sum -c SHA256SUMS)
}

promote() {
  archive="art-kubus-web-$SOURCE_SHA.tar.gz"
  archive_path="$INCOMING_DIR/$archive"
  checksum_path="$archive_path.sha256"
  rollback_file="$RELEASE_ROOT/rollback-$SOURCE_SHA"

  [ -f "$archive_path" ] || die "incoming archive is missing"
  [ -f "$checksum_path" ] || die "incoming archive checksum is missing"
  (cd "$INCOMING_DIR" && sha256sum -c "$archive.sha256")

  mkdir -p "$RELEASE_ROOT/releases"
  if [ -e "$RELEASE_DIR" ] || [ -L "$RELEASE_DIR" ]; then
    [ -d "$RELEASE_DIR" ] || die "immutable release path is not a directory"
    verify_release "$RELEASE_DIR"
  else
    candidate="$INCOMING_DIR/payload"
    rm -rf "$candidate"
    mkdir "$candidate"
    tar -xzf "$archive_path" -C "$candidate"
    verify_release "$candidate"
    mv "$candidate" "$RELEASE_DIR"
  fi

  previous_target="$(readlink "$LIVE_DIR")"
  [ -n "$previous_target" ] || die "LIVE_DIR has an empty symlink target"
  [ "$previous_target" != "$RELEASE_DIR" ] || die "release is already current"
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
    basename "$candidate" | grep -Eq '^[0-9a-f]{40}$' || continue
    kept=$((kept + 1))
    if [ "$kept" -gt "$RETAIN_RELEASE_COUNT" ]; then
      rm -rf -- "$candidate"
    fi
  done
}

finalize() {
  [ "$(readlink "$LIVE_DIR")" = "$RELEASE_DIR" ] \
    || die "requested release is not current; refusing finalization"
  rm -f "$RELEASE_ROOT/rollback-$SOURCE_SHA"
  prune_releases
}

mode="${1:-}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${LIVE_DIR:?LIVE_DIR is required}"
: "${RELEASE_ROOT:?RELEASE_ROOT is required}"
: "${INCOMING_DIR:?INCOMING_DIR is required}"
: "${RELEASE_DIR:?RELEASE_DIR is required}"
: "${RETAIN_RELEASE_COUNT:=5}"
validate_contract

case "$mode" in
  promote) promote ;;
  rollback) rollback ;;
  finalize) finalize ;;
  *) die "usage: atomic_web_release.sh <promote|rollback|finalize>" ;;
esac
