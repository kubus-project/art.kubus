# shellcheck shell=sh
# Shared, token-safe WAF diagnosis for the production post-deploy smoke.
#
# This optional classifier remains available if a Netcup origin filter is
# observed. The old Domenca LiteSpeed/Imunify360 415 incident is historical;
# a 415 on Netcup must be diagnosed independently before adding a host rule.
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
  # Honor the SSH SOCKS egress tunnel when one is configured, so the diagnosis
  # reflects the same transport the smoke uses.
  set -- --silent --output /dev/null --write-out '%{http_code}' --max-time 15
  if [ -n "${SMOKE_SOCKS_PROXY:-}" ]; then
    set -- "$@" --proxy "$SMOKE_SOCKS_PROXY"
  fi
  if [ "$_waf_send_header" = with-header ] && [ -n "${SMOKE_BYPASS_TOKEN:-}" ]; then
    set -- "$@" --header "X-Deploy-Smoke: $SMOKE_BYPASS_TOKEN"
  fi
  curl "$@" "$_waf_origin/" 2>/dev/null || printf '000'
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
      echo "  cause: the host WAF exception for X-Deploy-Smoke is NOT active. Requests carrying the header still return 415 (root -> $_wd_with_header_status). Verify the Netcup response and any host filter with Netcup support before adding an origin exception; do not apply the old Domenca rule." >&2
      return 1
    fi
    echo "  cause: the origin did not respond as expected even with the bypass header (root -> $_wd_with_header_status). Investigate origin/application health." >&2
    return 1
  fi

  # No token configured in this step.
  if [ "$_wd_no_header_status" = 415 ] || [ "$_wd_observed_status" = 415 ]; then
    echo "  cause: SMOKE_BYPASS_TOKEN is empty in this step and the origin returned 415. Investigate the Netcup response and any host filter before setting an optional bypass secret." >&2
    return 1
  fi
  echo "  cause: this is not a WAF IP block (the origin is reachable without a bypass header). Investigate as an ordinary application/routing/SEO smoke failure, not a network filter." >&2
  return 0
}
