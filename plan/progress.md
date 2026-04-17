# Objective
Finish the email/system notification overhaul so backend transactional/system mail and relevant app-side UX are coherent, validated, and accurately documented.

# Scope
- Backend transactional email rendering and active sender methods.
- Backend flows for verification, resend verification, password reset, generic notifications, account security, wallet backup/passkey security, promotion lifecycle, DAO submission/decision, support ticket receipt/update, and moderation outcomes.
- App UX copy/status surfaces for email verification/resend/reset/security/settings/support receipts.
- Plan tracking files required by the task.

# Confirmed current state
- Preflight read completed for all repo `AGENTS.md` files found under root, `lib/**`, and `backend/**`.
- `plan/progress.md` and `plan/todo.md` already existed when this turn started, but `plan/todo.md` did not use the exact required phase group names. It has now been normalized.
- `git -c safe.directory=G:/WorkingDATA/art.kubus/art.kubus branch --show-current` reports `master`, not `public-server-setup`.
- `git -c safe.directory=G:/WorkingDATA/art.kubus/art.kubus status --short` reported a clean working tree before this turn's edits.
- `backend/src/services/transactionalEmailService.js` contains one shared transactional renderer with branded art.kubus logo/header, teal primary CTA `#0f8f8c`, fallback link block, safety/help footer, HTML, and plaintext output.
- Email verification, password reset, generic notifications, account security, wallet backup/passkey security events, promotion lifecycle alerts, DAO submission receipts, support ticket receipts, support ticket updates, and moderation outcome emails all call the shared transactional renderer through service methods.
- DAO submission receipt wiring exists in `backend/src/routes/dao.js`.
- DAO decision mail path exists through `createDaoDecisionNotification`.
- Support ticket receipt wiring exists in `backend/src/routes/supportTickets.js`.
- Support ticket update/resolution wiring exists in `backend/src/routes/adminTickets.js`.
- Moderation outcome wiring already existed for community posts, comments, artworks, and collections.
- This turn completed the remaining admin moderation/account-standing wiring for users, groups, art markers, AR markers, events, and exhibitions.
- App-side audit found verification/resend/reset/security/settings copy aligned; support ticket success copy already mentions an emailed receipt when an email is provided, and the email verification badge is localized.

# Remaining gaps
- No code coverage gaps remain for the requested overhaul in the current checkout.
- Frontend formatter/analyzer validation could not be run because `dart` and `flutter` are not available on PATH in this sandbox.
- Operational SMTP delivery from a deployed container was not tested; this pass validates code paths and rendered payloads, not live SMTP provider delivery.

# Acceptance criteria
- `plan/progress.md` exists and reflects the real final state. Confirmed.
- `plan/todo.md` exists and reflects the real final state. Confirmed.
- One shared transactional email shell is the active system. Confirmed in `transactionalEmailService.js`.
- Verification, password reset, generic notifications, account security, and promotion emails all use that shared shell. Confirmed by route/service audit and targeted tests.
- DAO submission receipt and support receipt/update flows are wired and working in code. Confirmed by audit and targeted tests.
- Moderation outcome emails are wired for all relevant moderated entity types discovered in audit, with safe-recipient exclusions documented. Confirmed for users, groups, community posts, comments, artworks, collections, art markers, AR markers, events, and exhibitions.
- App-side UX/copy is aligned where needed with actual email behavior. Confirmed by audit of verification/resend/reset/security/settings/support surfaces.
- Tests or validation coverage were added/performed and logged. Confirmed.
- Final self-audit confirms no major remaining gaps. Confirmed, subject to the environment notes above.

# Phases
1. Audit and evidence
2. Work tracking setup
3. Backend email completion
4. Missing flow wiring
5. App-side UX alignment
6. Tests and validation
7. Final self-audit and cleanup

# Current phase
Phase 7: Final self-audit and cleanup complete

# Files audited
- `AGENTS.md`
- `lib/AGENTS.md`
- `lib/providers/AGENTS.md`
- `lib/services/AGENTS.md`
- `lib/screens/AGENTS.md`
- `lib/screens/desktop/AGENTS.md`
- `backend/AGENTS.md`
- `backend/src/AGENTS.md`
- `backend/src/middleware/AGENTS.md`
- `backend/src/routes/AGENTS.md`
- `backend/src/services/AGENTS.md`
- `plan/progress.md`
- `plan/todo.md`
- `backend/src/services/transactionalEmailService.js`
- `backend/src/services/accountSecurityMailService.js`
- `backend/src/services/promotionAlertService.js`
- `backend/src/routes/auth.js`
- `backend/src/routes/notifications.js`
- `backend/src/routes/supportTickets.js`
- `backend/src/routes/adminTickets.js`
- `backend/src/routes/dao.js`
- `backend/src/routes/adminModeration.js`
- `backend/src/routes/walletBackups.js`
- `backend/src/utils/emailDeliveryPolicy.js`
- `backend/src/utils/emailPreferences.js`
- `backend/src/db/schema.sql`
- `backend/src/db/schema_complete.sql`
- `backend/__tests__/transactionalEmailService.test.js`
- `backend/__tests__/authEmailLifecycle.test.js`
- `backend/__tests__/notificationsRoutesAuth.test.js`
- `backend/__tests__/promotionAlertService.test.js`
- `backend/__tests__/supportTicketsRoutes.test.js`
- `backend/__tests__/daoReviewsRoutes.test.js`
- `backend/__tests__/walletBackupsRoutes.test.js`
- `backend/__tests__/adminModerationReportsTicketsRoutes.test.js`
- `lib/screens/auth/verify_email_screen.dart`
- `lib/screens/auth/forgot_password_screen.dart`
- `lib/screens/auth/reset_password_screen.dart`
- `lib/screens/auth/secure_account_screen.dart`
- `lib/widgets/auth_methods_panel.dart`
- `lib/widgets/support/support_ticket_dialog.dart`
- `lib/widgets/email_verification_status_badge.dart`
- `lib/providers/email_preferences_provider.dart`
- `lib/models/email_preferences.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/desktop/desktop_settings_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_sl.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_sl.dart`

# Files changed
- `plan/progress.md`
- `plan/todo.md`
- `backend/src/routes/adminModeration.js`
- `backend/src/services/transactionalEmailService.js`
- `backend/__tests__/adminModerationReportsTicketsRoutes.test.js`

# Validation log
- Read all `AGENTS.md` files required by repo preflight.
- Confirmed `git branch --show-current` reports `master`; this is recorded as a branch mismatch because the prompt named `public-server-setup`.
- Confirmed initial working tree was clean with per-command `safe.directory` Git option.
- Used `rg` and direct file reads to audit active backend email sender methods, route wiring, moderation route entity coverage, app UX surfaces, schema ownership columns, and existing tests.
- Confirmed shared shell CTA color in `transactionalEmailService.js` is `#0f8f8c`.
- Confirmed `rg` found no `#1db854` or `#1a73e8` in `backend/src/services/transactionalEmailService.js` or active backend route code.
- Confirmed direct SMTP/nodemailer usage is limited to `backend/src/services/transactionalEmailService.js`.
- Confirmed active sender methods route through `sendEmailVerification`, `sendPasswordReset`, `sendNotificationEmail`, `sendAccountSecurityEmail`, `sendPromotionAlertEmail`, `sendDaoSubmissionReceiptEmail`, `sendSupportTicketReceiptEmail`, `sendSupportTicketUpdateEmail`, and `sendModerationOutcomeEmail`.
- Added moderation tests for users, group owners, art marker owners, AR marker owners, event collaboration owners, and exhibition collaboration owners; extended user deletion coverage for account removal mail.
- `node --check backend/src/routes/adminModeration.js` passed.
- `node --check backend/src/services/transactionalEmailService.js` passed.
- `node --check backend/__tests__/adminModerationReportsTicketsRoutes.test.js` passed.
- `npm.cmd test -- --runInBand --runTestsByPath __tests__/adminModerationReportsTicketsRoutes.test.js` passed: 1 suite, 17 tests.
- `npm.cmd test -- --runInBand --runTestsByPath __tests__/transactionalEmailService.test.js __tests__/supportTicketsRoutes.test.js __tests__/adminModerationReportsTicketsRoutes.test.js __tests__/daoReviewsRoutes.test.js __tests__/promotionAlertService.test.js __tests__/notificationsRoutesAuth.test.js __tests__/walletBackupsRoutes.test.js __tests__/authEmailLifecycle.test.js` passed: 8 suites, 67 tests.
- `dart --version` failed because `dart` is not available on PATH.
- `flutter --version` failed because `flutter` is not available on PATH.
- Manual app-side `rg` checks confirmed support receipt copy exists in EN/SL, the support dialog uses that copy when email is provided, settings expose the relevant email preference groups on mobile and desktop, and verification/reset screens use the backend email flows.

# Remaining issues
- Local branch mismatch: the checkout reports `master`, while the prompt says `public-server-setup`. I did not switch branches because the task forbids destructive git operations and the current checkout already contained the audited overhaul work.
- Frontend CLI validation is blocked by missing `dart`/`flutter` binaries on PATH.
- Live SMTP delivery was not exercised against a real provider/container.
- Justified non-send cases: no moderation email is sent when the owner/audience cannot be resolved safely, the email is unverified, a marker has no linked artwork owner, or an event/exhibition has no collaboration owner.

# Final status
Complete in the current checkout. The email/system notification overhaul is fully implemented in code with targeted backend validation passing; the only remaining notes are environment validation limits and the branch-name mismatch documented above.
