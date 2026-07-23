#!/usr/bin/env sh
set -eu

# Read-only production WAF-exception verifier.
#
# Confirms whether the host has been configured to let the CI smoke through the
# Imunify360/LiteSpeed bot filter for requests carrying the secret
# `X-Deploy-Smoke: <SMOKE_BYPASS_TOKEN>` header. It performs only GET / probes
# against the deployment origin and changes nothing on the host. It never prints
# the token value.
#
# Usage:
#   WEB_SMOKE_URL=https://app.kubus.site/ SMOKE_BYPASS_TOKEN=... \
#     sh scripts/deploy/waf_smoke_probe.sh
#
# To avoid the token ever appearing in a shell history or process list, prefer
# loading it from a mode-0600 file rather than an inline assignment:
#   SMOKE_BYPASS_TOKEN="$(cat ~/.kubus-smoke-token)" \
#     sh scripts/deploy/waf_smoke_probe.sh
#
# Exit status:
#   0  the origin is reachable (either no WAF block, or the bypass header works)
#   1  the origin returns a WAF block that the bypass header does not clear
#   2  usage / environment error

die() {
  echo "waf smoke probe: $*" >&2
  exit 2
}

: "${WEB_SMOKE_URL:?WEB_SMOKE_URL is required (e.g. https://app.kubus.site/)}"
case "$WEB_SMOKE_URL" in
  https://*) ;;
  http://127.0.0.1[:/]*|http://127.0.0.1|http://localhost[:/]*|http://localhost) ;;
  *) die "WEB_SMOKE_URL must be an https URL (http is allowed only for loopback tests)" ;;
esac
case "$WEB_SMOKE_URL" in *'@'*) die "WEB_SMOKE_URL must not contain credentials" ;; esac

origin="$(printf '%s' "$WEB_SMOKE_URL" | sed -E 's#(https?://[^/]+).*#\1#')"

# shellcheck source=scripts/deploy/waf_smoke_diagnostics.sh
. "$(dirname "$0")/waf_smoke_diagnostics.sh"

# Observe the current status the same way the smoke does, then classify.
observed="$(_waf_probe_status with-header "$origin")"
echo "waf smoke probe against $origin"
if waf_diagnose "$origin" "$observed"; then
  echo "waf smoke probe: origin is reachable for the CI smoke."
  exit 0
fi
echo "waf smoke probe: origin still blocks the CI smoke; the host exception is not active." >&2
exit 1
