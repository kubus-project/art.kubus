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

# The application now boots directly at the site root: there is no longer a 308
# to /en, and /en and /sl are localized Flutter entries rather than generic
# server-rendered homepages. Root is still the first request after the atomic
# symlink swap, and it was the only assertion here without a retry, so any single
# transient response (a host filter's first-contact challenge, or LiteSpeed still
# holding the previous release's document root) failed the deploy and rolled back
# a good release. curl's own --retry cannot cover this: it only retries transient
# statuses (408/429/5xx), and the body has to be inspected rather than --fail on
# status, so the poll is explicit. Status and body come from one request so the
# two can never describe different responses.
# Retry count and delay default to the production values; the contract tests
# override them (to run fast) without changing any assertion. Both are clamped
# so an override can never silently disable the poll.
root_attempts="${SMOKE_ROOT_ATTEMPTS:-6}"
root_delay="${SMOKE_ROOT_DELAY_SECONDS:-3}"
printf '%s' "$root_attempts" | grep -Eq '^[1-9][0-9]*$' || root_attempts=6
printf '%s' "$root_delay" | grep -Eq '^[0-9]+$' || root_delay=3
root_status=''
attempt=1
while :; do
  # A connection-level curl failure (e.g. the SSH egress tunnel not yet ready, or
  # a dropped connection) must be retried like any other non-200, not abort the
  # script under `set -e`; `|| true` keeps the poll in control of the outcome.
  root_status="$(smoke_curl --silent --output "$work_dir/root.html" --write-out '%{http_code}' "$origin/" || true)"
  if [ "$root_status" = 200 ] && grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$work_dir/root.html"; then
    break
  fi
  if [ "$attempt" -ge "$root_attempts" ]; then
    # Classify the failure (WAF IP block vs. missing token vs. app fault) so a
    # 415 is not mistaken for an application regression. Never prints the token.
    waf_diagnose "$origin" "$root_status" "" || true
    die "root did not boot the Flutter application: expected 200 with the Flutter bootstrap, got $root_status after $root_attempts attempts"
  fi
  attempt=$((attempt + 1))
  sleep "$root_delay"
done

smoke_curl --fail --silent --show-error --retry 5 --retry-delay 3 --retry-all-errors \
  --header 'Cache-Control: no-cache' --header 'Pragma: no-cache' \
  "$origin/app" --output "$work_dir/app.html"
grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$work_dir/app.html" || die "/app compatibility entry does not serve Flutter"

# /en and /sl are now localized Flutter entries. Flutter is REQUIRED here; its
# presence is no longer a failure signal. Deep localized public-entity routes
# keep their server-rendered semantic HTML and are asserted by
# production_seo_contract.mjs (invoked below) and the public-takeover smoke.
smoke_curl --fail --silent --show-error --retry 5 --retry-delay 3 "$origin/en" --output "$work_dir/en.html"
grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$work_dir/en.html" || die "/en does not boot the Flutter application"
smoke_curl --fail --silent --show-error --retry 5 --retry-delay 3 "$origin/sl" --output "$work_dir/sl.html"
grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$work_dir/sl.html" || die "/sl does not boot the Flutter application"

smoke_curl --fail --silent --show-error "$origin/robots.txt" --output "$work_dir/robots.txt"
grep -q "Sitemap: $origin/sitemap.xml" "$work_dir/robots.txt" || die "production robots.txt lacks the production sitemap"
if grep -Eiq '^Disallow: /$' "$work_dir/robots.txt"; then die "production robots.txt contains the staging deny-all rule"; fi
smoke_curl --fail --silent --show-error "$origin/sitemap.xml" --output "$work_dir/sitemap.xml"
grep -Eq '<sitemapindex|<urlset' "$work_dir/sitemap.xml" || die "production sitemap.xml is not a valid sitemap index or urlset"
test "$(smoke_curl --silent --output /dev/null --write-out '%{http_code}' "$origin/__deploy_unknown_$SOURCE_SHA")" = 404 || die "unknown production route is not a real 404"

# Revision verification is decoupled from the SEO PHP gateway: /en is now a static
# Flutter entry and does not set the renderer's X-Kubus-Web-Revision header. The
# immutable artifact always ships /kubus-web-revision.txt, so read it directly and
# require an exact match with the deployed source SHA.
served_revision="$(smoke_curl --fail --silent --show-error "$origin/kubus-web-revision.txt" | tr -d '\r\n')"
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
