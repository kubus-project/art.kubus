# Email System Overhaul Todo

## 1. Audit and evidence
- [x] Read all repo `AGENTS.md` files before code changes.
- [x] Create or refresh `plan/progress.md` and `plan/todo.md` for this task.
- [x] Audit backend email services, template helpers, and direct mailer usage.
- [x] Audit backend routes/jobs/triggers that send email.
- [x] Audit preference gates and notification settings that affect email delivery.
- [x] Audit app-side UX surfaces for verification, password reset, account security, settings, and email preferences.
- [x] Record confirmed current state and acceptance criteria in `plan/progress.md`.
- [x] Fill this todo with atomic implementation tasks before major implementation begins.

## 2. Shared email architecture
- [x] Identify current shared email primitives and gaps.
- [x] Add shared render helpers inside the transactional email service.
- [x] Build one reusable transactional email shell for all system emails.
- [x] Add branded logo/header, consistent typography, teal CTA, fallback link block, help/safety footer, and email-safe HTML.
- [x] Ensure plaintext rendering remains sensible.
- [x] Make wrapper methods call the shell directly instead of composing divergent templates.
- [x] Make the API easy for future email types to add.

## 3. Template migration
- [x] Migrate email verification to the shared shell.
- [x] Migrate password reset to the shared shell.
- [x] Migrate generic notification emails to the shared shell.
- [x] Migrate account security emails to the shared shell without wrapping a divergent generic template.
- [x] Migrate wallet backup/passkey security events to the shared shell.
- [x] Migrate promotion lifecycle emails to the shared shell.
- [x] Migrate DAO decision emails to the shared shell.
- [x] Migrate support receipt/update emails to the shared shell.
- [x] Migrate moderation outcome emails to the shared shell.
- [x] Remove or disconnect old divergent live templates.

## 4. Missing email flows
- [x] Implement DAO submission receipt email from `POST /api/dao/reviews`.
- [x] Implement support ticket receipt email from `POST /api/support/tickets`.
- [x] Implement support ticket update/resolution emails from `PATCH /api/admin/tickets/:id`.
- [x] Implement moderation outcome email helper for owned content.
- [x] Send moderation outcome emails for community posts where owner can be resolved.
- [x] Send moderation outcome emails for comments where owner can be resolved.
- [x] Send moderation outcome emails for artworks where owner can be resolved.
- [x] Send moderation outcome emails for collections where owner can be resolved.
- [!] Moderation outcome emails for groups are blocked in this pass because the route updates visibility but the ownership/audience model can include group owners and members; adding recipient logic needs a dedicated group-notification policy.
- [!] Moderation outcome emails for art markers and AR markers are blocked in this pass because the route does not consistently expose a verified creator wallet without resolving marker data, linked artwork ownership, and AR-marker linkage rules together.
- [!] Moderation outcome emails for events and exhibitions are blocked in this pass because ownership is collaboration/member based and the admin route only updates status without resolving a single safe recipient.
- [x] Document blockers for any high-value flow that cannot be completed cleanly.

## 5. App-side UX alignment
- [x] Align verification sent and resend expectations.
- [x] Align password reset expectations.
- [x] Align account security messaging.
- [x] Align settings and email preference labels/grouping.
- [x] Align UI copy that promises or depends on backend email delivery.
- [x] Localize the email verification status badge.
- [x] Update support ticket success copy to mention the emailed receipt when an email was provided.

## 6. Tests and validation
- [x] Add or update tests for verification flow.
- [x] Add or update tests for resend verification flow.
- [x] Add or update tests for password reset flow.
- [x] Add or update tests for account security flow.
- [x] Add or update tests for promotion flow.
- [x] Add or update tests for DAO decision flow.
- [x] Add tests for DAO submission receipt email.
- [x] Add tests for support ticket receipt and update emails.
- [x] Add tests for moderation outcome emails.
- [x] Add tests that shared shell output uses the teal CTA and branded shell.
- [x] Run targeted backend tests or document blockers.
- [!] Run targeted frontend validation or document blockers. Blocked because `dart` and `flutter` are not available on PATH in this sandbox; manual localization key and widget reference checks were completed with `rg`.

## 7. Final self-audit and cleanup
- [x] Verify no active email family uses the old plain/minimal template.
- [x] Verify shared teal CTA styling across live email families.
- [x] Verify EN/SL compatibility where relevant.
- [x] Update `plan/progress.md` with final files changed and validation log.
- [x] Update `plan/todo.md` so every item is `[x]` or `[!]` with accurate reasons.
- [x] Confirm acceptance criteria one by one.
- [x] State final status without overclaiming.
