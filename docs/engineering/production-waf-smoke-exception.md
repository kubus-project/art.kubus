# Production post-deploy smoke: WAF exception setup

This document is the server-side runbook for letting the production release
smoke reach `https://app.kubus.site` from a GitHub-hosted runner. It is the
missing host-side half of the `SMOKE_BYPASS_TOKEN` / `X-Deploy-Smoke` mechanism
already wired through the repository. Read
[`branching-and-deployment.md`](branching-and-deployment.md) first for the
deployment contract.

## Exact root cause

`release-production.yml` builds an immutable artifact, uploads it, and
atomically promotes it. The post-promotion smoke then verifies the live site.
That smoke runs on a GitHub-hosted runner (a datacenter IP), and the production
origin's bot filter answers datacenter IPs with **HTTP 415** while a normal
client IP receives the correct `308 -> /en` canonicalization.

Verified behaviour:

- From an ordinary client IP, `GET https://app.kubus.site/` returns
  `308 Permanent Redirect -> https://app.kubus.site/en`, and it does so **even
  when an incorrect `X-Deploy-Smoke` header is sent**. The block is therefore
  keyed on IP reputation, not on request content.
- From the GitHub-hosted runner, the same request returns `415`, so the smoke's
  `root canonicalization expected 308 ... got 415` assertion fails and the
  deployment correctly rolls back.
- Response headers show `Server: LiteSpeed` and a `PH_HPXY_CHECK` cookie, the
  signature of an Imunify360-style reverse-proxy bot filter (WebShield) in front
  of LiteSpeed.

The repository side is already complete: every smoke client (curl in
`smoke_production_web.sh`, `fetch` in `production_seo_contract.mjs`, and the
Playwright context in `public_flutter_takeover_smoke.mjs`) sends
`X-Deploy-Smoke: <SMOKE_BYPASS_TOKEN>` scoped to the deployment origin, and
`release-production.yml` forwards the environment secret. The only missing piece
is a host rule that recognises the header. Until it exists, the smoke fails
closed with a classified WAF diagnosis (never a false pass).

## Why an `.htaccess` rule cannot fix this (Option B rejected)

The reverse-proxy bot filter evaluates the request **before** LiteSpeed reads
the document root's `.htaccess`. A blocked datacenter IP is answered with `415`
at the proxy layer and never reaches Apache/LiteSpeed rewrite or header
processing, so no `.htaccess` directive -- rewrite, header, `SecRuleRemoveById`,
or otherwise -- can influence the decision. A deploy-time `.htaccess` overlay
(the mechanism used for development Basic Auth) would be an ineffective
pseudo-fix here and is intentionally not implemented for production. The fix
must live in the WAF/reverse-proxy layer (Option A) or move the smoke to a
non-datacenter IP (Option C).

## Option A (preferred): header-scoped Imunify360 / WAF exception

A server administrator with WHM/root performs this once. The account/cPanel user
that CI deploys as cannot configure the proxy filter, so this is a human step.

Goal: skip only the false-positive datacenter filter for `app.kubus.site`
requests that carry the exact `X-Deploy-Smoke` token, keeping every other
security rule and all other traffic unchanged.

1. Pick the token. Use the same random value stored in the `production-web`
   GitHub Environment secret `SMOKE_BYPASS_TOKEN`. Never place it in a file that
   is world-readable or backed up off-host in clear text.

2. Add a header-scoped allow rule. In Imunify360 this is a custom WAF rule that
   matches the header and disables the filter for that request only. Example
   ModSecurity form (place it where the server's Imunify360/WAF custom rules are
   loaded, not in an account `.htaccess`):

   ```
   SecRule REQUEST_HEADERS:X-Deploy-Smoke "@streq REPLACE_WITH_TOKEN" \
     "id:19010723,phase:1,pass,nolog,allow,\
      ctl:ruleEngine=Off,\
      chain"
   SecRule REQUEST_HEADERS:Host "@streq app.kubus.site"
   ```

   The `chain` restricts the exception to `app.kubus.site`. `phase:1` runs on
   request headers so the exception is decided before body rules. Use the exact
   token with `@streq` (exact match), never a prefix or regex.

3. If the block is enforced by Imunify360 WebShield (the reverse proxy) rather
   than by ModSecurity, add the equivalent WebShield allow condition on the
   `X-Deploy-Smoke` header for `app.kubus.site` in the Imunify360 configuration.
   If the installed Imunify360 version cannot match a request header in
   WebShield, use Option C instead -- do not fall back to allowlisting GitHub's
   IP ranges, which are large, shared, and rotate.

4. Reload the WAF/proxy configuration.

Security boundary: the exception matches only the exact secret header value and
only `app.kubus.site`; it disables only the false-positive filter for that one
request; all other rules and all header-less traffic keep the full policy.

## Option C (fallback): trusted-runner smoke

If the host cannot express a header-scoped exception, run the identical smoke
from an IP the filter does not greylist (a self-hosted runner, or a trusted
external probe on a residential/business IP -- the same class of IP that already
receives the correct `308`). Requirements:

- keep the job bound to the `production-web` GitHub Environment and its approval;
- keep the exact-SHA and latest-head guards, the full smoke suite, and automatic
  rollback inside the same protected deployment transaction;
- give the runner only the minimum secrets it needs;
- do not reduce coverage or convert any failure into a warning.

With Option C the `SMOKE_BYPASS_TOKEN` secret can be left unset for production;
the smoke then sends no bypass header and relies on the runner's IP reaching the
origin directly. Do not choose Option C merely because it is easier than Option
A.

## Verifying the host rule (read-only, no deployment)

After the host rule is in place, confirm it before the next release without
triggering a deployment. From a runner or an equivalent datacenter environment,
run the read-only probe. Load the token from a mode-0600 file so it never
appears in shell history, a process list, or a log:

```bash
SMOKE_BYPASS_TOKEN="$(cat ~/.kubus-smoke-token)" \
WEB_SMOKE_URL=https://app.kubus.site/ \
  sh scripts/deploy/waf_smoke_probe.sh
```

Expected once the rule is active:

- with the correct header the origin returns `308 -> /en` (probe exits `0`,
  reports the exception is ACTIVE);
- a header-less request from the same host still returns `415` (the filter is
  intact for everyone else);
- an incorrect header value still returns `415`.

If the probe reports `host WAF exception for X-Deploy-Smoke is NOT active`, the
rule is missing or not matching; recheck the token value and the `Host`
condition. The probe never prints the token.

## What must never happen

- No host path, account username, or token value in the repository, workflow
  files, artifacts, logs, screenshots, or pull-request text.
- No disabling of Imunify360/ModSecurity globally, no IP-range allowlisting as a
  first resort, no weakening of the smoke, and no treating `415` as success.
- No development Basic Auth directives on production.
