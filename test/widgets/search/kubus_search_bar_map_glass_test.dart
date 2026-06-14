import 'package:art_kubus/widgets/common/kubus_glass_chip.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:art_kubus/widgets/search/kubus_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('KubusSearchBar map glass mode', () {
    testWidgets(
        'fallback over the map drops BackdropFilter and adds the material sheen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            // Mirrors what the map screen passes via kubusMapBlurEnabled() when
            // sitting over the native MapLibre platform view.
            enableBlur: false,
            useMapGlassSurface: true,
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
    });

    testWidgets('normal search bar fallback does NOT use the map sheen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            enableBlur: false,
            useMapGlassSurface: false,
          ),
        ),
      );

      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });

    testWidgets('map mode keeps real blur when blur is available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            enableBlur: true,
            useMapGlassSurface: true,
          ),
        ),
      );

      // Provider absent => GlassSurface defaults to real blur, and the sheen is
      // only for the blur-off fallback.
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });
  });

  group('KubusGlassChip map glass fallback', () {
    testWidgets('quick filter chip gets the sheen when real blur is off',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          KubusGlassChip(
            label: 'Nearby',
            icon: Icons.near_me,
            active: false,
            enableBlur: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
    });

    testWidgets('quick filter chip keeps real blur when available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          KubusGlassChip(
            label: 'Nearby',
            icon: Icons.near_me,
            active: false,
            enableBlur: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });
  });
}
