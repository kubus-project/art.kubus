import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/utils/home_rail_semantics.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeRailSemantics.accentFor', () {
    for (final roles in <KubusColorRoles>[
      KubusColorRoles.light,
      KubusColorRoles.dark,
    ]) {
      final label = roles == KubusColorRoles.light ? 'light' : 'dark';

      test('every entity type resolves to a colour ($label)', () {
        for (final type in PromotionEntityType.values) {
          expect(HomeRailSemantics.accentFor(type, roles), isA<Color>());
        }
      });

      test('all five entity types resolve to distinct accents ($label)', () {
        final accents = PromotionEntityType.values
            .map((t) => HomeRailSemantics.accentFor(t, roles).toARGB32())
            .toSet();
        expect(
          accents.length,
          PromotionEntityType.values.length,
          reason: 'each rail entity type must have a distinct accent',
        );
      });

      test('known entity types never fall back to a generic primary ($label)',
          () {
        // The resolver draws exclusively from the stat/achievement palette,
        // never a bare scheme.primary. Assert each mapping matches its role.
        expect(HomeRailSemantics.accentFor(PromotionEntityType.artwork, roles),
            roles.statTeal);
        expect(HomeRailSemantics.accentFor(PromotionEntityType.profile, roles),
            roles.statBlue);
        expect(
            HomeRailSemantics.accentFor(PromotionEntityType.institution, roles),
            roles.statGreen);
        expect(HomeRailSemantics.accentFor(PromotionEntityType.event, roles),
            roles.statCoral);
        expect(
            HomeRailSemantics.accentFor(PromotionEntityType.exhibition, roles),
            roles.achievementGold);
      });
    }

    testWidgets('of() resolves via BuildContext theme extension',
        (tester) async {
      late Color resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [KubusColorRoles.light],
          ),
          home: Builder(
            builder: (context) {
              resolved =
                  HomeRailSemantics.of(context, PromotionEntityType.artwork);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, KubusColorRoles.light.statTeal);
    });
  });
}
