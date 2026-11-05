# iOS for 0.8.6: sideloaded testing with AltStore Classic

For 0.8.6 iOS is **sideloaded testing**. It is not distributed through the App Store or TestFlight, and nothing in the release depends on a paid Apple Developer Program
membership. The package is an **unsigned** IPA built by CI; AltStore Classic re-signs it on your computer with a free Apple ID. Do not describe it as App Store signed or published.

## 1. Get the IPA
1. GitHub → **Actions → iOS unsigned build → Run workflow**. Choose the branch to build:
   * from an `integration/*` branch (for example `integration/086-app`): `source_ref` is that same branch and the run builds its current head (use this before merge);
   * from `master`: `source_ref` is a `v*` tag, `dev` or `master`.
   A `v*` release tag also builds an unsigned IPA inside *Mobile release* when `IOS_RELEASE_ENABLED` is not set; it is attached to that run.
2. Download the artifact `ios-unsigned-<ref>-<sha>`: `art.kubus-<ref>-<sha>-unsigned.ipa`, `….build.json` and `SHA256SUMS`.
3. Check it: `shasum -a 256 -c SHA256SUMS` (macOS/Linux) or `Get-FileHash -Algorithm SHA256 <file>` (Windows). `….build.json` records the source commit, version, build number, bundle id, backend URL and `"signed": false`.
   The run summary shows the Xcode 26 toolchain used. CI has already checked that the package opens as `Payload/Runner.app`, has the arm64 executable, `Flutter.framework`, `App.framework` with `flutter_assets`, the compiled asset catalogue, no unresolved
   build variables in `Info.plist`, no code signature, no provisioning profile and **no entitlements**; and that bundle id, version and build number match the source.

## 2. Install with AltStore Classic
1. Install AltServer on a Windows PC or Mac and AltStore Classic on the iPhone (follow altstore.io; iTunes/Finder access and the same Wi-Fi are needed). Sign in with a free Apple ID.
2. On the iPhone enable **Developer Mode** (Settings → Privacy & Security → Developer Mode; iOS 16 and later) and restart.
3. Put the IPA on the phone (AirDrop, Files, or the AltServer menu *Sideload .ipa…*). In AltStore → **My Apps → +** → choose the IPA. AltStore re-signs it with your Apple ID and installs it.
4. First launch: Settings → General → VPN & Device Management → trust your Apple ID.
5. Refresh before it lapses: a free account's install **expires after 7 days**. Keep AltServer running on the same network; AltStore refreshes in the background, or tap *Refresh All*.

## 3. What a free Apple ID changes (not application defects)
| Limit | Effect on art.kubus |
|---|---|
| The install expires after 7 days; at most 3 sideloaded apps (AltStore counts as one); 10 new App IDs per rolling 7 days | the app stops opening if not refreshed; reinstalling many times can hit the App ID limit |
| AltStore gives the app a different bundle identifier (`com.art.kubus.<your team id>`) | anything tied to `com.art.kubus` fails: **native Google sign-in** (the iOS OAuth client is bound to the original bundle id) will be refused — sign in with e-mail and password instead |
| No capabilities or entitlements can be granted | there are none to lose: the app declares none. Passkeys (need associated domains), universal links from `art.kubus.site` into the app, push notifications and Sign in with Apple are **not available** in a sideloaded build and are not part of 0.8.6 for iOS |
| The app is not reviewed or notarised | iOS shows a one-time trust prompt; the app cannot be installed on other people's phones through the App Store |
Everything else is the production configuration: backend, map, camera/AR, location, Face ID, wallet deep links (`metamask`, `phantom`, `solflare`) and the `artkubus://` scheme.

## 4. What counts as an application defect (please report)
A crash or hang on launch or during use; a blank or half-drawn screen; missing text, images or maps; wrong language; the camera, location or Face ID prompt not appearing or appearing without its explanation; AR placement not working on a supported
device; a request failing against the production backend with an error that e-mail sign-in should not produce; a removed post or comment still visible; reports, decisions, appeals or account closure failing. If something fails, first check §3.

Report with: iPhone model and iOS version, AltStore version, the app version/build (from the app's settings or `build.json`), the `build.json` source commit, what you did, what you expected, what happened, a screenshot or screen recording, and whether it happens after a clean reinstall.

## 5. What this does not provide
No App Store or TestFlight build, no App Store Connect upload, no distribution certificate, no push notifications, no passkeys and no universal links. These need a paid Apple Developer Program membership and are deferred; they are not requirements of 0.8.6.
