# art.kubus 0.8.4: final 0.8 stabilization

Status: **RELEASED** on 2026-10-21. Tag `v0.8.4` is on `master` `8c2c571f`; production web and the
GitHub Release are live. Statuses are kept separate:
**implemented**, **tested**, **reviewed**, **merged**, **deployed** and **released** are
never inferred from one another. Maturity stays 0.8.x-alpha. The version bump is its own
commit (build `261020.01`, 2026-10-20).

0.8.4 closes the 0.8 line before 0.9. It adds no Web2.5 features. Walletless posting,
account-ID direct messages and the other account-owned community work are preserved for
0.9 (backend #104/#105/#106, app #340/#341); see "Deferred to 0.9".

## Backend (art.kubus-backend): merged and deployed

Integration PR [#110](https://github.com/kubus-project/art.kubus-backend/pull/110) was merged
with a merge commit as `master` `c3925db2`.

| PR | Scope |
| --- | --- |
| #107 | Security: revoke realtime conversation access when a member leaves |
| #108 | Notifications on the wallet-keyed model (R07/R08/R10), unread summary, migration 112, forward-only read state, schema FK order |
| #109 | R18: public pages enter the interactive app map; crawlable hub breadcrumb |
| #94 | Single-use auth challenges, forward-only sign count, PRF results discarded |
| #93 | Bounded Orbit public reads |
| #96, #98, #101, #102 | SEO authored counts, import evaluation, institution identity and claims, Moderation Studio S1 |
| #100, #103 | LISTEN_HOST binding; WALLET_REQUIRED 403 instead of 500 |

**Deployed** to Oracle on 2026-10-20 at 19:07Z (`GIT_COMMIT` c3925db, healthy). Migrations 107, 108,
109, 110 and 112 were applied (102 total). The compose invocation was proven by config hash
before deploying. Rollback: image `artkubus-backend:rollback-pre-c3925db`, plus a database dump
taken before migrating (125 MB, 133 tables). `app.kubus.site` reports
`X-Kubus-Backend-Revision: c3925db`, and the R18 links are live.

Follow-up [#111](https://github.com/kubus-project/art.kubus-backend/pull/111) (R04), merged as
`master` `34cbb0c` and **deployed** to Oracle on 2026-10-20 at 22:24Z. It is healthy, and the public
pages report `X-Kubus-Backend-Revision: 34cbb0c`. The compose invocation was re-proven by config hash.
There were no migrations. Rollback image: `artkubus-backend:rollback-pre-34cbb0c`.
- Email and Google (`account_linked`) sessions may write their own profile and avatar. The owner comes
  only from the token; another wallet or user returns 403 `PROFILE_OWNERSHIP_MISMATCH`.
- R04 root cause: the default-avatar `BEFORE INSERT` trigger fills the proposed row, so the upsert's
  `COALESCE(EXCLUDED.avatar_url, ...)` reset an uploaded avatar to the identicon on every save that
  did not resend it. The edit screen does exactly that with its preferences save.
- Every profile update sent without `preferences` returned a 500 (NOT NULL, proposed row).

## App (art.kubus)

Release PR [#348](https://github.com/kubus-project/art.kubus/pull/348) (`dev` to `master`, merge commit)
is merged as `master` `8c2c571f`. Exact-head full CI passed and the review thread is resolved.
- **Deployed:** `release-production.yml` run 39531825402 on `8c2c571f`, approved through `production-web`.
  `app.kubus.site/kubus-web-revision.txt` reports `8c2c571f`, and `version.json` reports 0.8.4.
- **Released:** tag `v0.8.4`, with mobile-release run 39532754396 published as an immutable
  [GitHub Release](https://github.com/kubus-project/art.kubus/releases/tag/v0.8.4). Assets: signed
  Android APK and AAB, an unsigned iOS IPA, `release-manifest.json` and `SHA256SUMS`.

After #345, R04 landed in #347 and #349:
- Avatar and profile save for every sign-in method; specific EN/SL error messages.
- Mobile now restores email and Google sessions that have no wallet. Before this, the Account tab
  showed the guest screen.
- Walletless preference sync.
- The onboarding avatar is kept for retry when the save fails.

Rendered QA on isolated local staging, against the web build of #347 plus backend #111: 4 of 4 PASS.
- Accounts: email-only, and email with a linked wallet. Viewports: 390 and 1440.
- Each run: avatar upload, save, reload. The new `/uploads/...` avatar and the bio persist in the DB
  and the UI.


Integration PR [#345](https://github.com/kubus-project/art.kubus/pull/345) was merged into
`dev` with a merge commit as `7d7586e1`. It contains #326, #331, #332, #333, #335, #336, #337,
#338, #339, #342, #312, #315, #318, #328, #329, #343 and #344. #325 and #334 were already in
`dev`. An independent review (Claude Sonnet) approved it, and exact-head CI passed (one known
flaky test was rerun).

Corrections found by rendered QA on an isolated local staging stack and fixed before merge:
- The desktop rail had gained an unapproved Messages entry. It was removed; the message
  unread badge is on Connect, and the internal `/messages` route keeps Connect selected.
- Restored sessions never initialized notification state, so returning users had no unread
  badges. Warm-up and sign-in now initialize it.
- Marking an older message read could move read state backwards (backend #108).
- One desktop Solana RPC (`getTokenAccountsByOwner`) ran at startup for guests and walletless
  accounts. Verified zero after the fix.
- Light-mode dialog contrast: action labels measured 1.94:1 before and 5.62:1 after (WCAG AA).

## Web family: merged and deployed as 0.8.4

| Site | PR | Live revision | Performance fix |
| --- | --- | --- | --- |
| node.kubus.site | #15 | `3372106e` | Cache lifetimes: hashed JS/CSS and fonts 1 year immutable, images 1 week, HTML no-cache |
| art.kubus.site | #34 | `ab2a2e45` | Full-page CLS removed (the main stylesheet had been loaded asynchronously); responsive map LCP image |
| kubus.site | #18 | `e47aa114` | Responsive WebP archive images |

Lighthouse 12.8.2 on art.kubus.site (live before, local production build after): `/en/map/` mobile
went from 36 to 66, CLS 0.906 to 0, LCP 6.7 s to 4.0 s; home desktop went from 69 to 95,
CLS 1.015 to 0.012.

## Regression matrix (R01-R18)

| ID | Item | Status |
| --- | --- | --- |
| R01/R02/R15 | Icon, app name, iOS location purpose | Merged (#334). Physical device check owed |
| R03 | iOS Google sign-in | BLOCKED_OWNER (Google Sign-In configuration) |
| R04/R06 | Avatar persistence, follow state | Released (#336, #347, #349; backend #111 deployed). Rendered on local staging, 4 of 4 PASS |
| R05 | Generic profile eyebrow removed | Merged earlier (db141c54) |
| R07/R08/R10 | Message and interaction notifications, unread badges | Merged (#338, backend #108 deployed). Rendered on local staging: Connect badge 4, cleared after reading |
| R09 | EN/SL notification copy | Merged (#339). Widget tests |
| R11 | Messaging redesign | Merged (#342). Rendered at 390/1440, light/dark, reduced motion; sent and received |
| R12/R13 | Image decode bounds, glass | Merged (#337). Device check owed |
| R14 | Artwork return keeps the bottom-bar tab | Merged (#335). Widget tests |
| R16 | Comments navigation and scrolling | Merged (#335). Widget tests |
| R17 | Dialog layout, contrast, dismissal | Merged (#344). Contrast measured on rendered screenshots |
| R18 | SEO page to Flutter entry | Released. Production, Chromium and Firefox: the EN/SL hub CTA (`/map?lang=`) enters the app map. EN place pages are taken over by Flutter in Chromium. JS off: the crawlable HTML has the map links |

## Known limitations
- Headless Firefox: the public-page Flutter takeover falls back to the HTML page (`flutter_takeover_failed`
  after about 1.6 s; the page stays fully usable). Chromium completes the takeover. The takeover files did
  not change in 0.8.4. Check in a real (non-headless) Firefox.
- The mobile profile shows "Connect wallet to see profile" for email-only accounts (cosmetic). Cover image
  upload still requires a wallet.
- iOS: no Apple Developer Program enrolment, so the IPA is unsigned and there is no TestFlight build.
- On desktop, Enter in the message composer inserts a new line (pre-existing; the send button sends).
- Hub SEO pages remain HTML by design; their primary CTA enters the app map, and `/map` ignores
  a `markerId` query (place pages are used instead).
- Follow-ups recorded in PRs: a forced notification re-init can be dropped during an in-flight
  init; admin account deletion keeps conversation memberships; the email-session hydration flag
  is not keyed to the user.

## Deferred to 0.9
Preserved branches, exact heads and the rebase order are in [handoff-0.9.md](handoff-0.9.md).
Backend #104 (walletless posting, migration 111), #105 (account notifications), #106 (account
messaging, migrations 113/114); app #340 (account messaging identity), #341 (R11 on the account
model), and the walletless compose commit 83196e2c. **#108 ships `112_account_aware_notifications.sql`
under the same filename as #105.** Reconcile any difference with a new migration, because 0.8.4's 112 is
applied in production.

## Rollback
- Backend: retag `artkubus-backend:rollback-pre-c3925db`; restore the pre-migration dump if needed.
- Web app: redeploy the previous `master` (`841d92a3`) through release-production.
- Web family: redeploy the previous revision through each site's protected deploy.
