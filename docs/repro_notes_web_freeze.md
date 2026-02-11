# Repro Notes: Web Freeze / Minified `G$` Frame

Date: February 11, 2026

## Commands

- `flutter clean`
- `flutter pub get`
- `flutter run -d chrome --debug`
- `flutter run -d chrome --debug --route /map`
- `flutter build web --release --source-maps`

## Observed Failure (debug run)

Trigger action:
- Initial app load on desktop shell (right sidebar build path), before any manual interaction.

Full exception (first thrown):
- `setState() or markNeedsBuild() called during build.`
- Emitter: `StatsProvider.notifyListeners`
- Build site: `DesktopHomeScreen._buildPlatformStatsSection`

Stack head:
- `package:art_kubus/providers/stats_provider.dart:321`
- `package:art_kubus/providers/stats_provider.dart:286` (`ensureSnapshot`)
- `package:art_kubus/screens/desktop/desktop_home_screen.dart:2232`

## Minified Frame Mapping

Observed minified frame in release bundle:
- `build/web/main.dart.js:225992`
- `gof(){return this.G$!=null&&this.az!=null},`

Source-map mapping (`build/web/main.dart.js.map`):
- Flutter framework `RenderTransform.alwaysNeedsCompositing`
- `flutter/packages/flutter/lib/src/rendering/proxy_box.dart:2534`
- Dart source: `child != null && _filterQuality != null`

Interpretation:
- The minified frame is framework rendering code.
- The app-level trigger is re-entrant provider notification during widget build, which destabilizes frame/build flow and can surface as opaque minified runtime failures in release.
