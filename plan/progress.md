# Objective
Finish the incomplete email-system overhaul so every active transactional/system email uses one branded art.kubus email system with consistent hierarchy, teal CTA styling, EN/SL-aware copy where relevant, sensible plaintext, and no live mixed old/new email UIs.

# Scope
- Audit backend email senders, templates, triggers, preference gates, tests, and app-side UX surfaces that set user expectations for email delivery.
- Build or complete one shared transactional email shell/base system.
- Migrate active email families onto that shared system.
- Add trust-critical missing flows where the backend supports them cleanly.
- Tighten app-side copy where it affects email trust and clarity.
- Validate the updated flows and keep this worklog accurate.

# Confirmed current state
- Preflight read completed for all repo `AGENTS.md` files found under root, `backend/**`, and `lib/**`.
- Existing `plan/progress.md` was from a previous UI/localization task and did not reflect this email overhaul.
- `plan/todo.md` was missing at the start of this task.
- `backend/src/services/transactionalEmailService.js` is the central SMTP sender. It has a branded verification template only; password reset and generic notification templates are still minimal inline HTML. CTA colors are mixed and include green `#1db854` and blue link styling.
- `sendAccountSecurityEmail` and `sendPromotionAlertEmail` currently call `sendNotificationEmail`, so account security, wallet backup/passkey, password-reset-completed, and promotion lifecycle emails inherit the generic minimal notification UI.
- Email verification is sent from `backend/src/routes/auth.js` through `sendEmailVerification`.
- Password reset is sent from `backend/src/routes/auth.js` through `sendPasswordReset`.
- Generic notification emails are sent from `backend/src/routes/notifications.js` through `sendNotificationEmail`.
- Account security/wallet backup/passkey events are defined in `backend/src/services/accountSecurityMailService.js` and triggered from auth and wallet backup routes.
- Promotion lifecycle emails are defined in `backend/src/services/promotionAlertService.js` and triggered from promotion admin/app routes and the promotion alert poller.
- DAO decision emails are sent as notification emails through `createDaoDecisionNotification`.
- DAO submission receipts are not currently emailed when `POST /api/dao/reviews` succeeds.
- Support ticket receipts are not currently emailed when `POST /api/support/tickets` succeeds.
- Support ticket update/resolution emails are not currently sent by `backend/src/routes/adminTickets.js`.
- Moderation outcome emails for creator-impacting admin changes are not currently sent by `backend/src/routes/adminModeration.js`; DAO decisions are the existing exception.
- App-side verification, resend verification, password reset, settings email preferences, support ticket dialog, and email verification badge surfaces exist and need minor copy/status alignment.

# Acceptance criteria
- One shared transactional email shell exists in code.
- Verification, password reset, and generic notification emails use that shared shell.
- Account security emails use that shared shell.
- Promotion emails use that shared shell.
- CTA styling is unified and teal.
- Old divergent active templates are removed or no longer used.
- Missing high-value flows in scope are implemented or explicitly blocked and documented.
- App-side UX/copy is aligned where needed.
- `plan/progress.md` exists and is current.
- `plan/todo.md` exists and is current.
- Final self-audit confirms no mixed old/new system remains in active use.

# Phases
1. Audit and evidence
2. Shared email architecture
3. Template migration
4. Missing email flows
5. App-side UX alignment
6. Tests and validation
7. Final self-audit and cleanup

# Current phase
Phase 7: Final self-audit and cleanup

# Files audited
- `AGENTS.md`
- `backend/AGENTS.md`
- `backend/src/AGENTS.md`
- `backend/src/middleware/AGENTS.md`
- `backend/src/routes/AGENTS.md`
- `backend/src/services/AGENTS.md`
- `lib/AGENTS.md`
- `lib/providers/AGENTS.md`
- `lib/screens/AGENTS.md`
- `lib/screens/desktop/AGENTS.md`
- `lib/services/AGENTS.md`
- `plan/progress.md`
- `backend/src/services/transactionalEmailService.js`
- `backend/src/routes/supportTickets.js`
- `backend/src/routes/adminTickets.js`
- `backend/src/routes/dao.js`
- `backend/src/routes/adminModeration.js`
- `backend/__tests__/transactionalEmailService.test.js`
- `backend/__tests__/supportTicketsRoutes.test.js`
- `backend/__tests__/adminModerationReportsTicketsRoutes.test.js`
- `backend/__tests__/daoReviewsRoutes.test.js`
- `lib/widgets/email_verification_status_badge.dart`
- `lib/widgets/support/support_ticket_dialog.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_sl.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_sl.dart`
- `backend/src/services/accountSecurityMailService.js`
- `backend/src/services/promotionAlertService.js`
- `backend/src/routes/auth.js`
- `backend/src/routes/notifications.js`
- `backend/src/routes/supportTickets.js`
- `backend/src/routes/adminTickets.js`
- `backend/src/routes/adminModeration.js`
- `backend/src/routes/dao.js`
- `backend/src/utils/emailDeliveryPolicy.js`
- `backend/src/utils/emailPreferences.js`
- `backend/__tests__/transactionalEmailService.test.js`
- `backend/__tests__/authEmailLifecycle.test.js`
- `backend/__tests__/notificationsRoutesAuth.test.js`
- `backend/__tests__/promotionAlertService.test.js`
- `backend/__tests__/supportTicketsRoutes.test.js`
- `backend/__tests__/adminModerationReportsTicketsRoutes.test.js`
- `backend/__tests__/daoReviewsRoutes.test.js`
- `backend/__tests__/walletBackupsRoutes.test.js`
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

# Files changed
- `plan/progress.md`
- `plan/todo.md`
- `backend/src/services/transactionalEmailService.js`
- `backend/src/routes/supportTickets.js`
- `backend/src/routes/adminTickets.js`
- `backend/src/routes/dao.js`
- `backend/src/routes/adminModeration.js`
- `backend/__tests__/transactionalEmailService.test.js`
- `backend/__tests__/supportTicketsRoutes.test.js`
- `backend/__tests__/adminModerationReportsTicketsRoutes.test.js`
- `backend/__tests__/daoReviewsRoutes.test.js`
- `lib/widgets/email_verification_status_badge.dart`
- `lib/widgets/support/support_ticket_dialog.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_sl.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_sl.dart`

# Validation log
- Preflight AGENTS review completed.
- `plan/progress.md` updated for this task.
- `plan/todo.md` created for this task.
- `git status --short` was initially blocked by Git dubious ownership for the sandbox user; future non-destructive Git checks will use per-command safe-directory config.
- Phase 1 audit completed with `rg` and direct file reads across backend senders, routes, tests, and app UX surfaces.
- Phase 2 shared architecture verified in code: `transactionalEmailService.js` now has one shared renderer with branded header/logo, teal CTA `#0f8f8c`, fallback links, help/safety footer, and plaintext output.
- Phase 3 migration verified in code for verification, password reset, generic notifications, account security/wallet/passkey events, promotion lifecycle emails, and DAO decision emails through the shared transactional shell. `rg` found no old `#1db854` or `#1a73e8` CTA styling in the transactional email service.
- Phase 4 implemented DAO submission receipts, support ticket receipts, support ticket update/resolution emails, and creator-impacting moderation outcome emails for community posts, comments, artworks, and collections where owner wallets are available.
- Phase 5 aligned app-side support receipt copy and localized the email verification status badge; existing verification/resend, password reset, account security, and email preference copy already matched the backend delivery expectations after audit.
- `node --check` passed for `transactionalEmailService.js`, `supportTickets.js`, `adminTickets.js`, `dao.js`, and `adminModeration.js`.
- `npm.cmd test -- --runInBand --runTestsByPath __tests__/transactionalEmailService.test.js __tests__/supportTicketsRoutes.test.js __tests__/adminModerationReportsTicketsRoutes.test.js __tests__/daoReviewsRoutes.test.js __tests__/promotionAlertService.test.js __tests__/notificationsRoutesAuth.test.js __tests__/walletBackupsRoutes.test.js __tests__/authEmailLifecycle.test.js` passed: 8 suites, 61 tests.
- `npm.cmd test -- --runInBand --runTestsByPath __tests__/transactionalEmailService.test.js` passed after Slovenian copy cleanup: 1 suite, 4 tests.
- `npm.cmd test -- --runInBand --runTestsByPath __tests__/adminModerationReportsTicketsRoutes.test.js` passed after comment action-link cleanup: 1 suite, 11 tests.
- `npm test` through PowerShell was blocked by execution policy for `npm.ps1`; rerun with `npm.cmd` succeeded.
- Jest parallel worker startup was blocked by `spawn EPERM`; rerun with `--runInBand` succeeded.
- `dart format` and `flutter --version` were blocked because `dart` and `flutter` are not available on PATH in this sandbox.
- `rg` checks confirmed app localization keys are present in ARB and generated localization files, the badge no longer hardcodes English, and the transactional service no longer contains old `#1db854` or `#1a73e8` CTA styling.
- Final self-audit `rg` found no old green/blue CTA colors or old minimal password-reset/notification template fragments in active backend email code.
- Acceptance criteria checked: one shared shell exists; verification, password reset, generic notification, account security, promotion, DAO decision, support, and moderation emails use it; CTA color is unified teal; old divergent templates are disconnected; missing high-value flows were implemented where ownership is safe and blockers documented where not; app copy was aligned; both plan files are current.

# Remaining issues
- Frontend formatter/analyzer validation remains blocked by missing Dart/Flutter CLI.
- Moderation outcome emails for groups are blocked in this pass because the route updates group visibility but recipient policy may involve group owners and/or members.
- Moderation outcome emails for art markers and AR markers are blocked in this pass because owner resolution needs marker data, linked artwork ownership, and AR-marker linkage rules resolved together.
- Moderation outcome emails for events and exhibitions are blocked in this pass because ownership is collaboration/member based and the admin route does not resolve a single safe recipient.

# Final status
Implemented with documented blockers for owner-ambiguous moderation entities and blocked frontend CLI validation. Backend email overhaul acceptance criteria are satisfied for active email families.
