#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "production web smoke: $*" >&2
  exit 1
}

: "${WEB_SMOKE_URL:?WEB_SMOKE_URL is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
printf '%s' "$SOURCE_SHA" | grep -Eq '^[0-9a-f]{40}$' || die "SOURCE_SHA must be a full lowercase commit SHA"
case "$WEB_SMOKE_URL" in *'@'*) die "WEB_SMOKE_URL must not contain credentials" ;; esac
origin="$(printf '%s' "$WEB_SMOKE_URL" | sed -E 's#(https?://[^/]+).*#\1#')"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

# shellcheck source=scripts/deploy/waf_smoke_diagnostics.sh
. "$(dirname "$0")/waf_smoke_diagnostics.sh"

# Optional SSH SOCKS egress: when set, every smoke request is routed through the
# deployment host so it leaves from the host's trusted IP instead of the CI
# runner's greylisted datacenter IP (see open_smoke_ssh_egress.sh). The Node SEO
# contract and Playwright takeover inherit SMOKE_SOCKS_PROXY from the environment.
smoke_proxy_args=()
if [ -n "${SMOKE_SOCKS_PROXY:-}" ]; then
  smoke_proxy_args=(--proxy "$SMOKE_SOCKS_PROXY")
fi

# Optional WAF bypass header so the CI runner's requests reach the origin. The
# host is configured to skip its bot/IP filter only when this header carries the
# SMOKE_BYPASS_TOKEN secret; every production assertion below still applies.
smoke_bypass_args=()
if [ -n "${SMOKE_BYPASS_TOKEN:-}" ]; then
  smoke_bypass_args=(--header "X-Deploy-Smoke: $SMOKE_BYPASS_TOKEN")
fi
smoke_curl() { curl "${smoke_proxy_args[@]}" "${smoke_bypass_args[@]}" "$@"; }

# Root is the first request after the atomic symlink swap, and it was the only
# assertion here without a retry, so any single transient response (a host
# filter's first-contact challenge, or LiteSpeed still holding the previous
# release's document root) failed the deploy and rolled back a good release.
# curl's own --retry cannot cover this: it only retries transient statuses
# (408/429/5xx), and --write-out has to observe the status rather than --fail on
# it, so the poll is explicit. Status and target come from one request so the two
# can never describe different responses.
# Retry count and delay default to the production values; the contract tests
# override them (to run fast) without changing any assertion. Both are clamped
# so an override can never silently disable the poll.
root_attempts="${SMOKE_ROOT_ATTEMPTS:-6}"
root_delay="${SMOKE_ROOT_DELAY_SECONDS:-3}"
printf '%s' "$root_attempts" | grep -Eq '^[1-9][0-9]*$' || root_attempts=6
printf '%s' "$root_delay" | grep -Eq '^[0-9]+$' || root_delay=3
root_status=''
root_target=''
attempt=1
while :; do
  # A connection-level curl failure (e.g. the SSH egress tunnel not yet ready, or
  # a dropped connection) must be retried like any other non-308, not abort the
  # script under `set -e`; `|| true` keeps the poll in control of the outcome.
  root_probe="$(smoke_curl --silent --output /dev/null --write-out '%{http_code} %{redirect_url}' "$origin/" || true)"
  root_status="${root_probe%% *}"
  root_target="${root_probe#* }"
  if [ "$root_status" = 308 ] && [ "$root_target" = "$origin/en" ]; then
    break
  fi
  if [ "$attempt" -ge "$root_attempts" ]; then
    # Classify the failure (WAF IP block vs. missing token vs. app fault) so a
    # 415 is not mistaken for an application regression. Never prints the token.
    waf_diagnose "$origin" "$root_status" "$root_target" || true
    die "root canonicalization expected 308 to $origin/en, got $root_status to $root_target after $root_attempts attempts"
  fi
  attempt=$((attempt + 1))
  sleep "$root_delay"
done

smoke_curl --fail --silent --show-error --retry 5 --retry-delay 3 --retry-all-errors \
  --header 'Cache-Control: no-cache' --header 'Pragma: no-cache' \
  "$origin/app" --output "$work_dir/app.html"
grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$work_dir/app.html" || die "/app does not serve Flutter"

smoke_curl --fail --silent --show-error --retry 5 --retry-delay 3 "$origin/en" --output "$work_dir/en.html"
grep -q '<h1>' "$work_dir/en.html" || die "localized production home lacks an h1"
grep -q 'rel="canonical"' "$work_dir/en.html" || die "localized production home lacks a canonical"
if grep -Eq 'flutter_bootstrap\.js|main\.dart\.js|maplibre' "$work_dir/en.html"; then
  die "public HTML unexpectedly loads the interactive app bundle"
fi
smoke_curl --fail --silent --show-error "$origin/robots.txt" --output "$work_dir/robots.txt"
grep -q "Sitemap: $origin/sitemap.xml" "$work_dir/robots.txt" || die "production robots.txt lacks the production sitemap"
if grep -Eiq '^Disallow: /$' "$work_dir/robots.txt"; then die "production robots.txt contains the staging deny-all rule"; fi
test "$(smoke_curl --silent --output /dev/null --write-out '%{http_code}' "$origin/__deploy_unknown_$SOURCE_SHA")" = 404 || die "unknown production route is not a real 404"

served_revision="$(smoke_curl --silent --head "$origin/en" | tr -d '\r' | awk 'BEGIN{IGNORECASE=1} /^X-Kubus-Web-Revision:/ {print $2; exit}')"
if [ -z "$served_revision" ]; then
  served_revision="$(smoke_curl --fail --silent --show-error "$origin/kubus-web-revision.txt" | tr -d '\r\n')"
fi
[ "$served_revision" = "$SOURCE_SHA" ] || die "production revision does not match the source SHA"

if [ -n "${PUBLIC_TAKEOVER_URL:-}" ]; then
  alias_id="$(printf '%s' "$PUBLIC_TAKEOVER_URL" | sed -E 's#.*/##')"
  alias_status="$(smoke_curl --silent --output /dev/null --write-out '%{http_code}' "$origin/a/$alias_id")"
  alias_target="$(smoke_curl --silent --output /dev/null --write-out '%{redirect_url}' "$origin/a/$alias_id")"
  if [ "$alias_status" != 308 ] || [ "$alias_target" != "$origin/en/artworks/$alias_id" ]; then
    die "compact artwork alias does not resolve to its localized canonical"
  fi
fi

case "${EXPECT_PUBLIC_FLUTTER_TAKEOVER:-false}" in
  true|1|yes|on)
    [ -n "${PUBLIC_TAKEOVER_URL:-}" ] || die "PUBLIC_TAKEOVER_URL is required when takeover is expected"
    [ -n "${PUBLIC_TAKEOVER_MISSING_URL:-}" ] || die "PUBLIC_TAKEOVER_MISSING_URL is required when takeover is expected"
    npm --prefix scripts/qa ci --no-audit --no-fund
    (cd scripts/qa && npx playwright install --with-deps chromium firefox)
    npm --prefix scripts/qa run qa:public-takeover
    ;;
  false|0|no|off) ;;
  *) die "EXPECT_PUBLIC_FLUTTER_TAKEOVER must be a boolean" ;;
esac

contract_id="${PUBLIC_CONTRACT_ARTWORK_ID:-}"
if [ -z "$contract_id" ] && [ -n "${PUBLIC_TAKEOVER_URL:-}" ]; then
  contract_id="$(printf '%s' "$PUBLIC_TAKEOVER_URL" | sed -E 's#.*/##')"
fi
[ -n "$contract_id" ] || die "PUBLIC_CONTRACT_ARTWORK_ID or PUBLIC_TAKEOVER_URL is required"
# When routing through the SSH egress tunnel the SEO contract uses Playwright's
# request API (SOCKS-capable), so it needs qa deps installed. The takeover branch
# above already installs them in production; install here too if we are proxying
# and that has not happened (no browser binaries are needed for the request API).
if [ -n "${SMOKE_SOCKS_PROXY:-}" ] && [ ! -d scripts/qa/node_modules ]; then
  npm --prefix scripts/qa ci --no-audit --no-fund
fi
KUBUS_ORIGIN="$origin" KUBUS_ARTWORK_ID="$contract_id" node scripts/qa/production_seo_contract.mjs

echo "Production web smoke passed for revision $SOURCE_SHA."
