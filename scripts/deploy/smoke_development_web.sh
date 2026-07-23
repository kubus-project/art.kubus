#!/usr/bin/env bash
set -euo pipefail
set +x

die() {
  echo "development web smoke: $*" >&2
  exit 1
}

: "${WEB_SMOKE_URL:?WEB_SMOKE_URL is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${HTTP_BASIC_USERNAME:?HTTP_BASIC_USERNAME is required}"
: "${HTTP_BASIC_PASSWORD:?HTTP_BASIC_PASSWORD is required}"

printf '%s' "$SOURCE_SHA" | grep -Eq '^[0-9a-f]{40}$' || die "SOURCE_SHA must be a full lowercase commit SHA"
case "$WEB_SMOKE_URL" in *'@'*) die "WEB_SMOKE_URL must not contain credentials" ;; esac
base="${WEB_SMOKE_URL%/}"
origin="$(printf '%s' "$base" | sed -E 's#(https?://[^/]+).*#\1#')"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
netrc="$work_dir/netrc"
host="$(printf '%s' "$origin" | sed -E 's#^https?://([^/:]+).*#\1#')"
{
  printf 'machine %s\n' "$host"
  printf 'login %s\n' "$HTTP_BASIC_USERNAME"
  printf 'password %s\n' "$HTTP_BASIC_PASSWORD"
} > "$netrc"
chmod 600 "$netrc"

# Optional WAF bypass header so the CI runner's requests reach the origin. The
# host is configured to skip its bot/IP filter only when this header carries the
# SMOKE_BYPASS_TOKEN secret; Basic Auth and every assertion below still apply.
smoke_bypass_args=()
if [ -n "${SMOKE_BYPASS_TOKEN:-}" ]; then
  smoke_bypass_args=(--header "X-Deploy-Smoke: $SMOKE_BYPASS_TOKEN")
fi

unauth_headers="$work_dir/unauth-headers"
unauth_status="$(curl --silent --show-error "${smoke_bypass_args[@]}" --dump-header "$unauth_headers" --output /dev/null --write-out '%{http_code}' "$origin/app")"
[ "$unauth_status" = "${PROTECTED_HTTP_STATUS:-401}" ] || die "unauthenticated request returned $unauth_status"
grep -Eiq '^WWW-Authenticate:' "$unauth_headers" || die "unauthenticated response lacks an authentication challenge"

curl_auth=(--silent --show-error --fail --retry 3 --retry-delay 2 --netrc-file "$netrc" "${smoke_bypass_args[@]}")
app_headers="$work_dir/app-headers"
app_body="$work_dir/app.html"
curl "${curl_auth[@]}" --dump-header "$app_headers" "$origin/app" --output "$app_body"
grep -Eq 'flutter_bootstrap\.js|main\.dart\.js' "$app_body" || die "/app does not serve the Flutter entrypoint"
robots_header="$(tr -d '\r' < "$app_headers" | awk 'BEGIN{IGNORECASE=1} /^X-Robots-Tag:/ {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')"
printf '%s' "$robots_header" | grep -Eiq 'noindex' || die "X-Robots-Tag lacks noindex"
printf '%s' "$robots_header" | grep -Eiq 'nofollow' || die "X-Robots-Tag lacks nofollow"
printf '%s' "$robots_header" | grep -Eiq 'noarchive' || die "X-Robots-Tag lacks noarchive"

served_revision="$(curl "${curl_auth[@]}" "$origin/kubus-web-revision.txt" | tr -d '\r\n')"
[ "$served_revision" = "$SOURCE_SHA" ] || die "served revision does not match the source SHA"

robots="$work_dir/robots.txt"
curl "${curl_auth[@]}" "$origin/robots.txt" --output "$robots"
grep -Fx 'User-agent: *' "$robots" >/dev/null || die "robots.txt lacks the defensive user-agent rule"
grep -Fx 'Disallow: /' "$robots" >/dev/null || die "robots.txt lacks the deny-all rule"
if grep -Eiq '^Sitemap:' "$robots"; then die "staging robots.txt must not publish a sitemap"; fi

for locale in en sl; do
  body="$work_dir/$locale.html"
  status="$(curl "${curl_auth[@]}" --output "$body" --write-out '%{http_code}' "$origin/$locale")"
  case "$status" in 200|204|301|302|307|308) ;; *) die "/$locale returned $status" ;; esac
  if grep -Eiq "rel=['\"]canonical['\"]" "$body" && grep -Fq 'https://dev.kubus.site' "$body"; then
    die "/$locale declares staging as canonical"
  fi
done

echo "Development web smoke passed for revision $SOURCE_SHA."
