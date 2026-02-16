# Security Policy

## Supported scope

This policy applies to the open-source client repository and related published artifacts.
Backend production infrastructure and internal systems are handled privately.

## Reporting a vulnerability

Please do **not** open public issues for security vulnerabilities.

Report privately via: support@kubus.site

Include:
- affected version/commit,
- reproduction steps,
- impact assessment,
- any proof-of-concept details.

## Response process

- We acknowledge reports as quickly as possible.
- We triage by severity and exploitability.
- We coordinate fixes and disclosure timing.

## Secret handling requirements

- Never commit `.env`, private keys, service-account credentials, or production secrets.
- Rotate and revoke any key that may have been exposed.
- Use `.env.example` templates for configuration documentation.

## Safe harbor

We appreciate good-faith research that avoids privacy violations, service disruption, or data destruction.
