import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and desktop share leased walking-session semantics', () {
    final mobile = File('lib/screens/map_screen.dart').readAsStringSync();
    final desktop =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();

    for (final source in <String>[mobile, desktop]) {
      // The session lease is created from the intent, but only after the build
      // phase: `start` notifies listeners and would otherwise rebuild the
      // provider scope mid-build.
      expect(source, contains('_walkingNavigationLease ??= provider.start('));
      expect(source, contains('addPostFrameCallback'));
      expect(source, contains('stopOwned(_walkingNavigationLease)'));
      expect(source, contains('lease: _walkingNavigationLease'));
      expect(source, contains('WalkingLocationApi? walkingLocationApi'));
      expect(
        source,
        contains('widget.walkingNavigationIntent == null &&'),
      );
      expect(source, contains('initialTarget.hasIdentity'));
    }
  });

  test('walking panel has foreground priority over marker previews', () {
    final mobile = File('lib/screens/map_screen.dart').readAsStringSync();
    final desktop =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();

    final mobileStack = mobile.indexOf('child: Stack(');
    final desktopStack = desktop.indexOf('child: Stack(');
    expect(
      mobile.indexOf(
          'if (widget.walkingNavigationIntent != null)', mobileStack),
      greaterThan(
          mobile.indexOf('_buildMarkerOverlay(themeProvider', mobileStack)),
    );
    expect(
      desktop.indexOf(
        'if (widget.walkingNavigationIntent != null)',
        desktopStack,
      ),
      greaterThan(
          desktop.indexOf('return _buildMarkerOverlayLayer(', desktopStack)),
    );
  });

  test('desktop recenter requests permission while initial load stays passive',
      () {
    final desktop =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();
    final compactDesktop = desktop.replaceAll(RegExp(r'\s+'), ' ');

    final recenterStart = compactDesktop.indexOf('onCenterOnMe: () {');
    final recenterEnd = compactDesktop.indexOf(
      'if (_userLocation == null)',
      recenterStart,
    );
    expect(recenterStart, greaterThanOrEqualTo(0));
    expect(recenterEnd, greaterThan(recenterStart));
    expect(
      compactDesktop.substring(recenterStart, recenterEnd),
      contains(
        '_refreshUserLocation(animate: true, requestPermission: true);',
      ),
    );

    final initialRefreshStart = compactDesktop.indexOf(
      'final bool shouldAnimateToUser',
    );
    final initialRefreshEnd = compactDesktop.indexOf(
      '_prefetchMarkerSubjects()',
      initialRefreshStart,
    );
    expect(initialRefreshStart, greaterThanOrEqualTo(0));
    expect(initialRefreshEnd, greaterThan(initialRefreshStart));
    expect(
      compactDesktop.substring(initialRefreshStart, initialRefreshEnd),
      contains('requestPermission: widget.walkingNavigationIntent != null'),
    );
  });
}
