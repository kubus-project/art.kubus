import 'package:art_kubus/features/map/shared/map_initial_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Slovenian locale resolves Slovenia framing', () {
    final viewport = MapInitialViewport.forLocale(const Locale('sl'));

    expect(viewport.fitBounds.west, closeTo(13.35, 0.01));
    expect(viewport.fitBounds.east, closeTo(16.61, 0.01));
    expect(viewport.initialCenter.latitude, closeTo(46.12, 0.2));
  });

  test('English and fallback locales resolve Europe framing', () {
    for (final locale in <Locale>[const Locale('en'), const Locale('de')]) {
      final viewport = MapInitialViewport.forLocale(locale);
      expect(viewport.fitBounds.west, closeTo(-12, 0.01));
      expect(viewport.fitBounds.east, closeTo(40, 0.01));
      expect(viewport.initialCenter.latitude, closeTo(53, 1));
    }
  });

  test('explicit targets and live-follow location take precedence', () {
    expect(
      MapInitialViewport.shouldApplyLocaleFallback(
        hasExplicitTarget: true,
        hasWalkingIntent: false,
        autoFollowHasLiveLocation: false,
      ),
      isFalse,
    );
    expect(
      MapInitialViewport.shouldApplyLocaleFallback(
        hasExplicitTarget: false,
        hasWalkingIntent: false,
        autoFollowHasLiveLocation: true,
      ),
      isFalse,
    );
  });
}
