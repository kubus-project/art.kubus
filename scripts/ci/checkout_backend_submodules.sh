#!/usr/bin/env bash
set -euo pipefail

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
expected_fingerprint='SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zP70W7sMWUjUhESQ'
if [ "$fingerprint" != "$expected_fingerprint" ]; then
  echo "GitHub SSH host fingerprint verification failed." >&2
  exit 1
fi

# actions/checkout rewrites git@github.com URLs to HTTPS when no SSH key is
# supplied. The root checkout intentionally uses its normal GITHUB_TOKEN, then
# this step removes only that rewrite before fetching the private gitlinks.
git config --global --unset-all url.https://github.com/.insteadOf || true

export GIT_SSH_COMMAND="ssh -i '$key_path' -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile='$known_hosts_path'"
git submodule sync --recursive
git submodule update --init --force --recursive
