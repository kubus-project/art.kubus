#!/usr/bin/env bash
set -euo pipefail

canonical_expected="$(git rev-parse HEAD:backend)"
secondary_expected="$(git rev-parse HEAD:backend-open-art-wt)"

if [ "$canonical_expected" != "$secondary_expected" ]; then
  echo "backend and backend-open-art-wt must pin the same backend commit." >&2
  echo "backend:             $canonical_expected" >&2
  echo "backend-open-art-wt: $secondary_expected" >&2
  exit 1
fi

: "${BACKEND_SUBMODULE_SSH_KEY:?BACKEND_SUBMODULE_SSH_KEY is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

key_path="$RUNNER_TEMP/art-kubus-backend-submodule-key"
known_hosts_path="$RUNNER_TEMP/art-kubus-github-known-hosts"

cleanup() {
  rm -f "$key_path" "$known_hosts_path"
}
trap cleanup EXIT

umask 077
printf '%s\n' "$BACKEND_SUBMODULE_SSH_KEY" > "$key_path"

ssh-keyscan -t ed25519 github.com > "$known_hosts_path" 2>/dev/null
fingerprint="$(ssh-keygen -lf "$known_hosts_path" -E sha256 | awk '{ print $2 }')"
expected_fingerprint='SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'
if [ "$fingerprint" != "$expected_fingerprint" ]; then
  echo "GitHub SSH host fingerprint verification failed." >&2
  exit 1
fi

# The root checkout uses GITHUB_TOKEN. Remove only its URL rewrite before using
# the dedicated deploy key for the private backend repository.
git config --global --unset-all url.https://github.com/.insteadOf || true
export GIT_SSH_COMMAND="ssh -i '$key_path' -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile='$known_hosts_path'"

# Fetch the private backend once. The second historical path is materialized as
# a local worktree at the same immutable commit, avoiding a duplicate network
# clone while preserving every existing repository path and validation script.
git submodule sync -- backend
git submodule update --init --force backend

canonical_actual="$(git -C backend rev-parse HEAD)"
if [ "$canonical_actual" != "$canonical_expected" ]; then
  echo "Canonical backend checkout is at $canonical_actual, expected $canonical_expected." >&2
  exit 1
fi

rm -rf backend-open-art-wt
git -C backend worktree prune
git -C backend worktree add --force --detach ../backend-open-art-wt "$secondary_expected"

secondary_actual="$(git -C backend-open-art-wt rev-parse HEAD)"
if [ "$secondary_actual" != "$secondary_expected" ]; then
  echo "Backend worktree is at $secondary_actual, expected $secondary_expected." >&2
  exit 1
fi

test -f backend/package.json
test -f backend-open-art-wt/package.json
