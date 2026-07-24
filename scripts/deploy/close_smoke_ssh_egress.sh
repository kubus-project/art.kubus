#!/usr/bin/env bash
set -uo pipefail

# Tear down the SSH SOCKS tunnel opened by open_smoke_ssh_egress.sh and remove
# all ephemeral key/passphrase state. Best-effort and always exits 0 so it can
# run in an always() cleanup step without masking the smoke's own verdict.

state_dir="${SMOKE_EGRESS_STATE_DIR:-${RUNNER_TEMP:-/tmp}/kubus-smoke-egress}"

if [ -f "$state_dir/ssh.pid" ]; then
  ssh_pid="$(cat "$state_dir/ssh.pid" 2>/dev/null || true)"
  if [ -n "$ssh_pid" ]; then
    kill "$ssh_pid" 2>/dev/null || true
  fi
fi

if [ -f "$state_dir/agent.env" ]; then
  # shellcheck disable=SC1090
  . "$state_dir/agent.env" >/dev/null 2>&1 || true
  if [ -n "${SSH_AGENT_PID:-}" ]; then
    ssh-agent -k >/dev/null 2>&1 || true
  fi
fi

rm -rf "$state_dir" 2>/dev/null || true
echo "ssh smoke egress: torn down."
exit 0
