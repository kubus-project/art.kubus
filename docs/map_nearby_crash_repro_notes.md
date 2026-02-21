# Map + Nearby Art Crash Reproduction Notes

Context: browser instability was observed while dragging the Nearby Art panel on the map surface.

## Reproduction focus
- Open `MapScreen` on web (`chrome`, `firefox`, `safari-ios`).
- Immediately drag the Nearby Art sheet up/down repeatedly.
- Observe map responsiveness and console/framework errors.

## Instrumentation points
- `lib/screens/map_screen.dart`
  - `_handleSheetExtentNotification`: captures DraggableScrollableSheet extent changes.
  - `_setSheetBlocking`: tracks when map-gesture blocking toggles.
  - `_syncWebAttributionBottomForSheet`: tracks attribution-bottom updates on web.

## Expected failure signature before fix
- Extremely high frequency extent updates causing repeated full-screen rebuilds.
- Jank spikes while dragging and occasional browser instability when the map is loading.
