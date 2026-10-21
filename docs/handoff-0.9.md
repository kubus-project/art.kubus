# 0.9 handoff: account-owned community and messaging (preserved from the 0.8.4 programme)

Written 2026-10-20 (session 10). Every branch below is preserved exactly as listed. None of them was rebased, merged or deleted.
Reconcile them in the dedicated 0.9 session against the final released 0.8.4 base, not against today's dev.

## Released 0.8.4 base (2026-10-21)
- App: `master` `8c2c571f` (tag `v0.8.4`). `dev` gains the release merge commit through the record PR.
- Backend: `master` `34cbb0c` (#110 integration, then #111), deployed on Oracle. Production migrations through 112.
- #111 changed `POST /api/profiles` and `POST /api/profiles/avatars`:
  - They now use `requireAccountOwnerToken` (`wallet_signed` or `account_linked`), with the owner taken from the token only.
  - Walletless profiles save by profile id (`ON CONFLICT (id)`).
  - The upsert reads `avatar_url` from `$6`, not `EXCLUDED`, because the default-avatar trigger fills the proposed row.
  - #104/#106 touch the same profile and identity paths, so keep those contracts when rebasing.
- App #347 restores walletless sessions in `ProfileProvider.initialize()` and syncs walletless preferences through `POST /api/profiles`. Reuse this for account-owned identity in #340.

## Preserved branches (exact heads)

| Repo | PR | Branch | Head | Content |
|---|---|---|---|---|
| backend | #104 | fix/084-account-community-posting | 3a833a37 | Walletless account-owned posts/reposts; migration 111_account_community_posting |
| backend | #105 | fix/084-account-notifications | 93faa322 | Account-aware notifications (stacked on #104); migration 112 |
| backend | #106 | fix/084-account-messaging | f5dfabec | Account-ID DMs, walletless reactions; migrations 113, 114 (stacked on #105) |
| backend | none | integration/084-provisional-composite-20261020 | local 450f7e59 | Old composite incl. #104/#105; superseded by integration/084-backend-candidate-s10 |
| app | #340 | fix/084-account-chat-identity-pr | faaea65c | Account-scoped messaging identity + session isolation (stacked on #338) |
| app | #341 | feat/084-messaging-ui | bab6935b | R11 UI on top of #340 (merge of #340 + 19dfccf7 + 10085804) |
| app | none | integration/084-provisional-composite-20261020 | 5f13f5a6 | Contains 83196e2c walletless ordinary compose (0.9) |
| app | none | fix/084-account-chat-identity | local 64699f63 | Older composite, superseded by #340; keep |

## What 0.8.4 already took (do not re-apply)
- **Socket revocation:** backend #107 (fix/084-messaging-socket-revocation @955ec8a) ports the revocation part of #106 (a8016ab, 47b2583, b932833), wallet-keyed. Left out: acct-sock/wallet-sock rooms keyed on userId, the isRevocationRoom tripwire, accountRoom/identityRoom, disconnectAccountSockets, account-deletion revocation (auth.js, profiles.js, adminModeration.js) and req.messagingIdentity.
- **Notifications:** backend #108 (fix/084-notifications-master @f8fbff6) ports #105's commits (7869cbe, 31e7446, e6ad2b6, 93faa32) onto master without #104. **It ships migration `112_account_aware_notifications.sql` with the same filename as #105's.** When #105 is reconciled, diff the two 112 files. If they differ, the 0.8.4 version is already applied in production, so the difference must go into a NEW migration. Dropped hunk: the repost notification's `originalAuthorUserId ||` path (needs #104). #108 also fixed the schema.sql FK order (notifications user FKs after the users constraints, f8fbff6). #105 has the same bootstrap bug.
- **R11 UI:** app #342 (feat/084-messaging-ui-v2 @6f658a98) = 19dfccf7 + 10085804 on #338, without #340. Dropped: the `senderUserId` grouping fallback in message_grouping.dart `_senderIdentityKey` and its test "account-only senders group by user id". **Restore both when #340 lands.**
- **R09 / recipient privacy:** app #339 (d312fbd3, on #338) is 0.8.4 scope and in the 0.8.4 candidate.

## Review evidence to carry forward (from session 9; exact SHAs)
- backend #106 share/socket review: P1 revocation bypass fixed (a8016ab, 47b2583); P2a/P2b fixed; Sonnet re-review PASS at 47b2583. Migration 114: P1 + P2s fixed, accepted after the NOT EXISTS guard (f5dfabe).
  Open P3s: the add-member path writes wallet-only rows; the notification member query reads stale wallet_address (messages.js ~885); the wallet-rebind route revocation was not located.
- app #340: 4 P2s fixed in ac6db375; reactorUserIds client in faaea65c. Backend reactions stored by wallet only, which is what migration 114 addresses.
- Cross-repo privacy review: no P0/P1. P3s: DM text in notification rows survives member removal or conversation delete (0.8.4 #108 now filters list and count by membership); lock-screen DM preview has no hide setting; no removed-member deep-link widget test; the artwork deep link was not reviewed.
- New 0.8.4 follow-ups relevant to 0.9 (from the session-10 Sonnet reviews):
  - Admin account deletion leaves conversation_members rows (#107 review).
  - Desktop hydration flag is a bool, not keyed to the user; a failed B load after A->B keeps A's currentUser (#343 review).
  - Like/comment/follow notifications for deleted posts are not filtered (#108 review).
  - From the R04 work: there is no unique index on `profiles.user_id` for walletless rows, so two concurrent first saves can create two rows. Cover upload still needs a wallet. The mobile profile shows "Connect wallet to see profile" for email-only accounts.
  - The public-page Flutter takeover falls back to HTML in headless Firefox. Check it in a real Firefox.

## Tests that exist on the preserved branches
- #106: 55 focused tests + isolated migration suite 4/4 (incl. rollback) on migration 113; 114 has its own tests.
- #341: 93 tests passed locally at bab6935b (session 9). Stacked PRs ran GitGuardian only, with no full CI.

## Integration instructions for 0.9
1. Start from the released 0.8.4 backend master and app dev/master. Re-fetch everything.
2. Backend: rebase #104 onto released master. Expect conflicts with #103 (WALLET_REQUIRED) in src/routes/community.js: keep the 403 contract for any path still requiring a wallet. Then rebase #105 on it, reconciling against #108 (see the migration 112 note above), then #106 against #107 (keep #107's wallet-keyed revocation module and extend it to account rooms, rather than keeping two mechanisms).
3. Run `npm run schema:bootstrap:ci` against a fresh database after each rebase. The draft tier does not run it.
4. App: rebase #340 onto released dev (which will contain #338/#339/#342/#343), then rebuild the R11 identity hunk (senderUserId fallback) on top. Reapply 83196e2c (walletless compose) only together with #104.
5. Fresh Sonnet review on the rebased heads. Earlier approvals refer to the SHAs above only.
