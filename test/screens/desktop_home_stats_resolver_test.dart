import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveArtworksDiscoveredCount', () {
    test('prefers higher remote count (profile > stats)', () {
      expect(
        resolveArtworksDiscoveredCount(
          statsCounterValue: 4,
          profileCounterValue: 9,
          localFallbackValue: 100,
        ),
        9,
      );
    });

    test('prefers higher remote count (stats > profile)', () {
      expect(
        resolveArtworksDiscoveredCount(
          statsCounterValue: 12,
          profileCounterValue: 3,
          localFallbackValue: 100,
        ),
        12,
      );
    });

    test('uses local fallback only when both remotes are zero', () {
      expect(
        resolveArtworksDiscoveredCount(
          statsCounterValue: 0,
          profileCounterValue: 0,
          localFallbackValue: 7,
        ),
        7,
      );
    });

    test('does not override non-zero remote with local', () {
      expect(
        resolveArtworksDiscoveredCount(
          statsCounterValue: 2,
          profileCounterValue: 0,
          localFallbackValue: 9,
        ),
        2,
      );
    });
  });
}
