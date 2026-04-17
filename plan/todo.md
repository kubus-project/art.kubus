# Email/System Notification Overhaul Todo

## 1. Audit and evidence
- [x] Read all repo `AGENTS.md` files before code changes.
- [x] Confirm current Git branch and working tree state.
- [x] Audit backend transactional email service and active sender methods.
- [x] Audit backend routes/jobs/triggers that send verification, reset, notification, account security, wallet/passkey, promotion, DAO, support, and moderation emails.
- [x] Audit admin moderation entities for safe recipient resolution.
- [x] Audit app-side UX surfaces for verification, resend, password reset, account security, support receipt copy, settings, and email preferences.
- [x] Record confirmed current state and remaining gaps in `plan/progress.md`.
- [x] Populate this todo with atomic tasks before additional implementation.

## 2. Work tracking setup
- [x] Ensure `plan/progress.md` exists with the required sections.
- [x] Ensure `plan/todo.md` exists with the required phase groups.
- [x] Keep `plan/progress.md` current while implementing remaining gaps.
- [x] Keep this todo current while implementing remaining gaps.

## 3. Backend email completion
- [x] Confirm active transactional email families use the shared shell.
- [x] Confirm CTA styling is unified on teal `#0f8f8c`.
- [x] Confirm old active green/blue CTA fragments are not present in `transactionalEmailService.js`.
- [x] Confirm plaintext rendering exists for shared shell output.
- [x] Confirm verification emails use the shared shell.
- [x] Confirm password reset emails use the shared shell.
- [x] Confirm generic notification emails use the shared shell.
- [x] Confirm account security, wallet backup, and passkey security emails use the shared shell through `sendAccountSecurityEmail`.
- [x] Confirm promotion lifecycle emails use the shared shell.
- [x] Confirm DAO submission receipt and DAO decision pathways use the shared email/notification system.
- [x] Confirm support receipt and support update pathways use the shared shell.
- [x] Complete missing moderation/account-standing sender coverage where safe recipients are available.

## 4. Missing flow wiring
- [x] Confirm DAO submission receipt wiring in `POST /api/dao/reviews`.
- [x] Confirm DAO decision email pathway through DAO decision notifications.
- [x] Confirm support ticket receipt wiring in support ticket creation.
- [x] Confirm support ticket update/resolution wiring in admin ticket updates.
- [x] Confirm moderation outcome emails for users/account-standing changes.
- [x] Confirm moderation outcome emails for groups.
- [x] Confirm moderation outcome emails for community posts.
- [x] Confirm moderation outcome emails for comments.
- [x] Confirm moderation outcome emails for artworks.
- [x] Confirm moderation outcome emails for collections.
- [x] Confirm moderation outcome emails for art markers when linked artwork ownership resolves.
- [x] Confirm moderation outcome emails for AR markers when linked art marker/artwork ownership resolves.
- [x] Confirm moderation outcome emails for events to collaboration owners.
- [x] Confirm moderation outcome emails for exhibitions to collaboration owners.
- [x] Document justified non-send cases: no email is sent when there is no verified email audience, no linked artwork owner, no group owner, or no event/exhibition collaboration owner.

## 5. App-side UX alignment
- [x] Confirm verification sent and resend expectations align with backend delivery responses.
- [x] Confirm password reset expectations align with safe backend responses.
- [x] Confirm account security messaging aligns with security mail behavior.
- [x] Confirm settings and email preference labels/grouping align with backend preference categories.
- [x] Confirm support ticket success copy mentions receipt email when the user provided an email.
- [x] Confirm email verification badge is localized.
- [x] Re-check app-side files after backend completion; no additional copy changes were needed.

## 6. Tests and validation
- [x] Existing targeted backend tests cover verification flow.
- [x] Existing targeted backend tests cover resend verification flow.
- [x] Existing targeted backend tests cover password reset flow.
- [x] Existing targeted backend tests cover account security flow.
- [x] Existing targeted backend tests cover promotion flow.
- [x] Existing targeted backend tests cover DAO submission receipt flow.
- [x] Existing targeted backend tests cover DAO decision flow.
- [x] Existing targeted backend tests cover support receipt flow.
- [x] Existing targeted backend tests cover support update flow.
- [x] Existing targeted backend tests cover shared shell teal CTA/branded output.
- [x] Add/update moderation tests for newly wired entity types.
- [x] Run `node --check` on changed backend files.
- [x] Run targeted backend Jest tests.
- [x] Run backend drift checks for direct mailer usage and old CTA colors.
- [!] Run targeted frontend CLI validation. Blocked because `dart` and `flutter` are not available on PATH in this sandbox; manual localization key and widget reference checks were completed with `rg`.

## 7. Final self-audit and cleanup
- [x] Verify `plan/progress.md` is current.
- [x] Verify `plan/todo.md` has no stale `[~]` items.
- [x] Verify no active email family uses the old plain/minimal template.
- [x] Verify shared teal CTA styling across live email families.
- [x] Verify EN/SL compatibility where relevant.
- [x] Verify app-side UX alignment was not skipped.
- [x] Verify missing flow coverage is complete or explicitly justified.
- [x] Confirm acceptance criteria one by one in `plan/progress.md`.
- [x] State final status without overclaiming.
