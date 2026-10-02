# Support

This repository primarily contains the **art.kubus Flutter client**. Some functionality depends on a separately operated backend and optional platform services.

## Where to go

### Reproducible client bugs

Open a GitHub issue with:

- platform + device (Android/iOS/Web/Desktop)
- expected vs actual behavior
- minimal reproduction steps
- screenshots/screen recordings (if UI)
- logs (redact tokens/PII)

Helpful commands to include:

- `flutter --version`
- `flutter doctor -v`

### Questions, ideas, and proposals

- Questions about using or building the app: [Discussions, Q&A](https://github.com/kubus-project/art.kubus/discussions/categories/q-a)
- Ideas and proposals: [Discussions, Ideas](https://github.com/kubus-project/art.kubus/discussions/categories/ideas)
- Anything else, including feedback: [Discussions, General](https://github.com/kubus-project/art.kubus/discussions/categories/general)

Want to contribute a fix yourself? Start with [`CONTRIBUTING.md`](CONTRIBUTING.md).

### Security vulnerabilities

Do **not** open a public issue for vulnerabilities.

Follow `SECURITY.md` and report privately via **support@kubus.site**.

### Backend / platform service issues

This repo includes a backend under `backend/`, but hosted production operations and internal systems may differ.

If your problem is:

- backend deployment, infrastructure, or environment setup → start with `backend/README.md`
- API contract mismatch affecting the client → file a GitHub issue with request/response details (redacting sensitive data)

## What not to post publicly

- access tokens, refresh tokens, session cookies
- private keys / mnemonics
- production `.env` contents
- user PII (emails, phone numbers, addresses)

If you accidentally post sensitive information, rotate/revoke it immediately and contact maintainers.
