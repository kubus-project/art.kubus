#!/usr/bin/env bash
set -euo pipefail

# Open a verified SSH dynamic (SOCKS5) tunnel to the deployment host so the
# post-deploy smoke can egress from the *host's own IP* instead of the CI
# runner's datacenter IP. The origin's Imunify360/LiteSpeed bot filter greylists
# datacenter IPs (HTTP 415) but trusts the server itself, so routing the smoke
# through this tunnel reaches the real vhost/TLS/.htaccess/app while sidestepping
# the false-positive IP block. Every smoke assertion still runs unchanged.
#
# This uses the same SSH credentials already trusted for deployment (SFTP key +
# verified host fingerprint). It fails closed:
#   * the host key must match SFTP_HOST_FINGERPRINT exactly;
#   * if the host refuses TCP forwarding (AllowTcpForwarding no) or the tunnel
#     cannot carry traffic, this script exits non-zero with a precise message
#     rather than letting the smoke run unproxied.
#
# On success it appends `SMOKE_SOCKS_PROXY=socks5h://127.0.0.1:<port>` to
# GITHUB_ENV for the smoke steps, and records tunnel state for the closer.
# The private key, passphrase, and token are never printed.

die() { echo "ssh smoke egress: $*" >&2; exit 1; }

: "${SFTP_SERVER:?SFTP_SERVER is required}"
: "${SFTP_USERNAME:?SFTP_USERNAME is required}"
: "${SFTP_PORT:?SFTP_PORT is required}"
: "${SFTP_PRIVATE_KEY:?SFTP_PRIVATE_KEY is required}"
: "${SFTP_HOST_FINGERPRINT:?SFTP_HOST_FINGERPRINT is required}"
: "${WEB_SMOKE_URL:?WEB_SMOKE_URL is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"

socks_port="${SMOKE_SOCKS_PORT:-18080}"
printf '%s' "$socks_port" | grep -Eq '^[1-9][0-9]{2,4}$' || die "SMOKE_SOCKS_PORT is invalid"
printf '%s' "$SFTP_PORT" | grep -Eq '^[0-9]+$' || die "SFTP_PORT must be numeric"

state_dir="${SMOKE_EGRESS_STATE_DIR:-${RUNNER_TEMP:-/tmp}/kubus-smoke-egress}"
rm -rf "$state_dir"
mkdir -p "$state_dir"
chmod 700 "$state_dir"

key_file="$state_dir/id"
known_hosts="$state_dir/known_hosts"
printf '%s\n' "$SFTP_PRIVATE_KEY" > "$key_file"
chmod 600 "$key_file"

origin="$(printf '%s' "$WEB_SMOKE_URL" | sed -E 's#(https?://[^/]+).*#\1#')"

# --- Verify the host key against the known fingerprint before trusting it -----
expected_fp="$SFTP_HOST_FINGERPRINT"
scanned="$state_dir/scanned"
: > "$scanned"
ssh-keyscan -T 10 -p "$SFTP_PORT" "$SFTP_SERVER" > "$scanned" 2>/dev/null || true
[ -s "$scanned" ] || die "could not retrieve any host key from $SFTP_SERVER:$SFTP_PORT"

: > "$known_hosts"
matched=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in \#*) continue ;; esac
  printf '%s\n' "$line" > "$state_dir/one"
  fp="$(ssh-keygen -lf "$state_dir/one" 2>/dev/null | awk '{print $2}')"
  if [ "$fp" = "$expected_fp" ] || [ "SHA256:$fp" = "$expected_fp" ] || [ "$fp" = "SHA256:$expected_fp" ]; then
    cat "$state_dir/one" >> "$known_hosts"
    matched=1
  fi
done < "$scanned"
rm -f "$state_dir/one"
[ "$matched" -eq 1 ] || die "host key fingerprint did not match SFTP_HOST_FINGERPRINT; refusing to open the tunnel"

# --- Load the key (with optional passphrase) into an ephemeral agent ----------
agent_env="$state_dir/agent.env"
ssh-agent -s > "$agent_env"
# shellcheck disable=SC1090
. "$agent_env" >/dev/null
if [ -n "${SFTP_PRIVATE_KEY_PASSPHRASE:-}" ]; then
  pass_file="$state_dir/pass"
  askpass="$state_dir/askpass.sh"
  printf '%s' "$SFTP_PRIVATE_KEY_PASSPHRASE" > "$pass_file"
  chmod 600 "$pass_file"
  printf '#!/bin/sh\ncat %q\n' "$pass_file" > "$askpass"
  chmod 700 "$askpass"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" \
    ssh-add "$key_file" </dev/null >/dev/null 2>&1 || die "could not load the deployment key (passphrase rejected?)"
  rm -f "$pass_file" "$askpass"
else
  ssh-add "$key_file" </dev/null >/dev/null 2>&1 || die "could not load the deployment key"
fi

# --- Start the dynamic (SOCKS5) tunnel ---------------------------------------
ssh -N -D "127.0.0.1:$socks_port" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$known_hosts" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
  -p "$SFTP_PORT" "$SFTP_USERNAME@$SFTP_SERVER" &
ssh_pid=$!
echo "$ssh_pid" > "$state_dir/ssh.pid"

proxy="socks5h://127.0.0.1:$socks_port"
tunnel_ok=0
for _ in 1 2 3 4 5 6 7 8 9 10 12 13 14 15; do
  if ! kill -0 "$ssh_pid" 2>/dev/null; then
    die "the SSH tunnel process exited before it carried traffic (authentication or forwarding failure)"
  fi
  status="$(curl --proxy "$proxy" --silent --output /dev/null --write-out '%{http_code}' --max-time 10 "$origin/" 2>/dev/null || printf '000')"
  if [ "$status" != 000 ]; then
    tunnel_ok=1
    echo "ssh smoke egress: tunnel established; origin answered $status through the host."
    break
  fi
  sleep 2
done

if [ "$tunnel_ok" -ne 1 ]; then
  die "the SSH dynamic tunnel could not carry traffic to $origin. The host most likely disallows TCP forwarding (AllowTcpForwarding no). Ask the host to permit forwarding for the deploy user, or use a trusted-IP runner / host WAF exception (see docs/engineering/production-waf-smoke-exception.md)."
fi

echo "SMOKE_SOCKS_PROXY=$proxy" >> "$GITHUB_ENV"
echo "ssh smoke egress: smoke will route through $proxy"
