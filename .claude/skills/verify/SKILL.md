---
name: verify
description: Launch the art.kubus Flutter app on web and drive it with Playwright to visually verify UI changes end-to-end (onboarding, auth, guest map).
---

# verify (art.kubus)

Runtime verification recipe for this repo. Surface = Flutter web GUI.

## Launch

```bash
# From the repo root; MUST use puro (pinned env artkubus, see .puro.json)
puro flutter run -d web-server --web-port=8765
# wait for: "lib/main.dart is being served at http://localhost:8765"
# debug build takes ~90-120s cold
```

Run it in the background and grep the log for `is being served at`.

## Drive (Playwright MCP)

- Resize viewport to 430x900 for mobile layout, >=1280 wide for desktop shell.
- The Flutter accessibility tree is NOT enabled by default; `browser_click`
  by role/text fails. Use `browser_run_code_unsafe` with `page.mouse.click(x, y)`
  coordinates read off screenshots instead. (The "Enable accessibility"
  placeholder exists but is off-viewport and flaky to click.)
- Take screenshots with `browser_take_screenshot` and Read the PNG to inspect.
  Screenshots land in the repo root / `.playwright-mcp/` — delete them after.

## Useful flows (no backend needed)

- Boot -> `/onboarding/alpha-notice` dialog -> "Nadaljuj na uvod" (~215,571).
- `/onboarding` welcome: "Odkrij umetnost" = guest mode -> `/main` map;
  "Prijava" (~215,667) -> `/sign-in`.
- `/sign-in`: "Nadaljuj z e-pošto" (~215,483) opens the email form; click a
  field to see the focus border.
- Theme toggle: top-right dropdown ("Temna") ~ (355,36); menu items
  Sistemska/Svetla/Temna at ~y=48/96/143.
- `/register` is `AuthMethodsPanel` standalone (amber accent backdrop —
  its own styling, not the onboarding step palette).

## Gotchas

- UI copy is Slovenian by default on this machine.
- Guest mode boots straight to the map with the tutorial overlay (1/7).
- Backend calls 401/timeout harmlessly for guest surfaces; console errors
  about refresh-token storage are expected offline noise.
