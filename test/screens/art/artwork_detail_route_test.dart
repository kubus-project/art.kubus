import 'package:art_kubus/screens/art/art_detail_route.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390, 899]) {
    testWidgets('$width px selects the compact artwork detail screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width.toDouble(), 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late Widget selectedScreen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              selectedScreen = buildArtworkDetailRoute(
                context,
                artworkId: 'public-artwork-fixture',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(selectedScreen, isA<ArtDetailScreen>());
      expect(selectedScreen, isNot(isA<DesktopArtworkDetailScreen>()));
    });
  }

  for (final width in [900, 901]) {
    testWidgets('$width px selects the desktop artwork detail screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width.toDouble(), 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late Widget selectedScreen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              selectedScreen = buildArtworkDetailRoute(
                context,
                artworkId: 'public-artwork-fixture',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(selectedScreen, isA<DesktopArtworkDetailScreen>());
      expect(selectedScreen, isNot(isA<ArtDetailScreen>()));
    });
  }
}
