# Claude Code configuration

Shared, version-controlled Claude Code setup for the art.kubus workspace.
Personal overrides go in `settings.local.json` (gitignored).

## Layout

```
.claude/
  settings.json            # hooks + permission allow/deny (shared)
  hooks/
    block-env-edits.js     # PreToolUse: block writes to real .env* secret files
    l10n-guard.js          # PostToolUse: warn when generated l10n loses its patch
  skills/
    bump-l10n/             # /bump-l10n  — regenerate l10n + re-apply patch + verify
    flutter-test/          # /flutter-test — run Flutter tests under puro
    backend-test/          # /backend-test — run Jest, serial when state collides
    vue-check/             # /vue-check — lint/type-check/test the Vue frontends
  agents/
    security-reviewer.md   # subagent for auth/wallet/crypto/secrets diffs
../.mcp.json               # context7 + read-only Postgres MCP servers
```

## Hooks

Both hooks are Node scripts (Node 22+ on PATH) invoked with a relative path so
they work under cmd.exe and sh. They **fail open** — a hook bug never blocks
editing. Logs are not written; messages surface via stderr.

- **block-env-edits** denies Edit/Write/MultiEdit/NotebookEdit on `.env`,
  `.env.flutter.production.json`, `backend/.env*`, etc. `*.example` stays editable.
- **l10n-guard** fires when `lib/l10n/app_localizations*.dart` is edited and
  reminds you to re-apply the locale-fallback patch and run the guard test.
  See the `bump-l10n` skill for the full sequence.

## Skills

All four are user-invocable (`/name`) and have `disable-model-invocation: true`
because they run commands / mutate generated files. Invoke them explicitly.

## MCP servers (`.mcp.json`)

- **context7** — live library docs (Solana SDK, Reown AppKit, Vue, Vite, etc.).
- **postgres** — read-only backend DB introspection. Set `POSTGRES_READONLY_URL`
  in your environment to a **read-only** role connection string before use; it is
  intentionally not hardcoded.

## Permissions

`settings.json` pre-allows common read-only git and project test/lint/build
commands to cut down on prompts, and denies reads of secret files
(`.env*`, `*.key`, keystores, `google-services.json`, plist). Tighten or extend
in `settings.local.json` per developer.
