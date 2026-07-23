# shellcheck shell=sh
# Shared, token-safe WAF diagnosis for the production post-deploy smoke.
#
# The production origin (app.kubus.site) is a LiteSpeed host fronted by an
# Imunify360-style reverse-proxy bot filter. That filter greylists datacenter
# IP ranges and answers them with HTTP 415, while a normal client IP receives
# the correct 308 -> /en canonicalization. The GitHub-hosted runner therefore
# cannot reach the origin unless the host is configured to skip that filter for
# requests carrying the secret `X-Deploy-Smoke: <SMOKE_BYPASS_TOKEN>` header.
#
# When the smoke fails, an opaque "got 415" is not actionable. `waf_diagnose`
# turns it into a classified message that names the exact failure mode without
# ever printing the token value:
#
#   * missing token / header not forwarded
#   * host rule not installed (header ignored, still 415)
#   * transient WAF/origin state
#   * ordinary application smoke failure (not a WAF block)
#
# This file is meant to be sourced; it defines functions and no top-level state.

# Perform one read-only root probe and echo just the HTTP status. A curl failure
# (DNS, timeout, connection reset) becomes 000 so callers can branch on it.
# The first argument selects whether the bypass header is attached; the token is
# only ever passed to the same origin the smoke already targets and is never
# echoed.
_waf_probe_status() {
  _waf_send_header="$1"
  _waf_origin="$2"
  if [ "$_waf_send_header" = with-header ] && [ -n "${SMOKE_BYPASS_TOKEN:-}" ]; then
    curl --silent --output /dev/null --write-out '%{http_code}' --max-time 15 \
      --header "X-Deploy-Smoke: $SMOKE_BYPASS_TOKEN" "$_waf_origin/" 2>/dev/null || printf '000'
  else
    curl --silent --output /dev/null --write-out '%{http_code}' --max-time 15 \
      "$_waf_origin/" 2>/dev/null || printf '000'
  fi
}

# waf_diagnose <origin> <observed_status> [observed_target]
# Emits a classified, token-free diagnosis to stderr. Returns 0 when the origin
# is reachable through the bypass header (the block is resolved), 1 otherwise, so
# standalone callers can gate on it. It never changes the smoke's own verdict.
waf_diagnose() {
  _wd_origin="$1"
  _wd_observed_status="${2:-unknown}"
  _wd_observed_target="${3:-}"

  _wd_token_present=0
  [ -n "${SMOKE_BYPASS_TOKEN:-}" ] && _wd_token_present=1

  _wd_no_header_status="$(_waf_probe_status no-header "$_wd_origin")"
  _wd_with_header_status='n/a'
  if [ "$_wd_token_present" -eq 1 ]; then
    _wd_with_header_status="$(_waf_probe_status with-header "$_wd_origin")"
  fi

  {
    echo "production web smoke WAF diagnosis (the token value is never shown):"
    echo "  observed root status     : $_wd_observed_status${_wd_observed_target:+ -> $_wd_observed_target}"
    echo "  root without bypass header: $_wd_no_header_status"
    if [ "$_wd_token_present" -eq 1 ]; then
      echo "  root with bypass header   : $_wd_with_header_status"
    else
      echo "  root with bypass header   : n/a (SMOKE_BYPASS_TOKEN not set in this step)"
    fi
  } >&2

  case "$_wd_with_header_status" in 200|301|302|307|308) _wd_bypass_reachable=1 ;; *) _wd_bypass_reachable=0 ;; esac

  if [ "$_wd_token_present" -eq 1 ]; then
    if [ "$_wd_bypass_reachable" -eq 1 ]; then
      if [ "$_wd_no_header_status" = 415 ]; then
        echo "  cause: the host WAF exception for X-Deploy-Smoke is ACTIVE. The bypass header clears the 415 (root -> $_wd_with_header_status) while an unauthenticated datacenter request stays filtered (root -> 415). If the smoke still failed, investigate the specific application assertion, not the WAF." >&2
      else
        echo "  cause: the origin is reachable with the bypass header (root -> $_wd_with_header_status) and is not applying a datacenter 415 block. If the smoke still failed, investigate it as an ordinary application/routing/SEO failure." >&2
      fi
      return 0
    fi
    if [ "$_wd_with_header_status" = 415 ] || [ "$_wd_no_header_status" = 415 ] \
      || [ "$_wd_observed_status" = 415 ]; then
      echo "  cause: the host WAF exception for X-Deploy-Smoke is NOT active. Requests that carry the bypass header are still answered with 415 (root -> $_wd_with_header_status), so the origin is ignoring the header. Install or repair the host rule (root/WHM step) per docs/engineering/production-waf-smoke-exception.md; an .htaccess rule cannot fix this because the reverse-proxy filter runs before LiteSpeed reads .htaccess." >&2
      return 1
    fi
    echo "  cause: the origin did not respond as expected even with the bypass header (root -> $_wd_with_header_status). Investigate origin/application health." >&2
    return 1
  fi

  # No token configured in this step.
  if [ "$_wd_no_header_status" = 415 ] || [ "$_wd_observed_status" = 415 ]; then
    echo "  cause: SMOKE_BYPASS_TOKEN is empty in this step. Either the secret is unset in the production-web GitHub Environment or the caller workflow did not forward it, so no bypass header was sent. The origin WAF (LiteSpeed/Imunify360) is blocking the CI runner's datacenter IP with 415. See docs/engineering/production-waf-smoke-exception.md." >&2
    return 1
  fi
  echo "  cause: this is not a WAF IP block (the origin is reachable without a bypass header). Investigate as an ordinary application/routing/SEO smoke failure, not a network filter." >&2
  return 0
}
