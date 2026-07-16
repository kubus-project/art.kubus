import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and desktop share leased walking-session semantics', () {
    final mobile = File('lib/screens/map_screen.dart').readAsStringSync();
    final desktop =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();

    for (final source in <String>[mobile, desktop]) {
      expect(
          source, contains('provider.start(widget.walkingNavigationIntent!)'));
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
}
