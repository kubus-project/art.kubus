import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';

void main() {
  group('shouldShowHomeStatCardIcon', () {
    test('shows icon for stacked mobile analytics cards', () {
      expect(
        shouldShowHomeStatCardIcon(showIconOnly: false, isVerticalLayout: true),
        isTrue,
      );
    });

    test('shows icon for horizontal icon-forward cards', () {
      expect(
        shouldShowHomeStatCardIcon(showIconOnly: true, isVerticalLayout: false),
        isTrue,
      );
    });

    test(
      'allows callers to hide icon only for non-vertical full-content cards',
      () {
        expect(
          shouldShowHomeStatCardIcon(
            showIconOnly: false,
            isVerticalLayout: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('home cultural metric layout', () {
    test('uses a measured content threshold for normal phone widths', () {
      const viewportToContentWidths = <(int, double)>[
        (320, 272),
        (360, 312),
        (393, 353),
        (412, 372),
        (430, 390),
      ];
      for (final entry in viewportToContentWidths) {
        expect(
          shouldUseSingleColumnHomeCulturalStats(width: entry.$2, textScale: 1),
          entry.$1 == 320,
          reason:
              '${entry.$1}px viewport with ${entry.$2}px content controls columns',
        );
      }
    });

    test('stacks narrow and 150 percent plus text layouts', () {
      expect(
        shouldUseSingleColumnHomeCulturalStats(width: 272, textScale: 1),
        isTrue,
      );
      for (final width in <double>[272, 312, 353, 372, 390]) {
        expect(
          shouldUseSingleColumnHomeCulturalStats(width: width, textScale: 2),
          isTrue,
          reason: '$width px of content should stack at 200 percent text',
        );
      }
    });

    test('uses the shared metric value size rather than navigation badges', () {
      expect(KubusTextStyles.statValue.fontSize, greaterThanOrEqualTo(24));
    });

    for (final width in <double>[320, 360, 393, 412, 430]) {
      final textScale = width == 412 ? 2.0 : 1.0;
      testWidgets(
        'renders four readable metrics at ${width.toInt()}px and ${textScale}x',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final previousFlutterError = FlutterError.onError;
          final errors = await pumpProductSurface(
            tester,
            child: const HomeScreen(),
            size: Size(width, textScale == 2 ? 1800 : 1400),
            locale: const Locale('en'),
            brightness: Brightness.light,
            textScale: textScale,
            signedInProfile: qaOwner(),
          );
          FlutterError.onError = previousFlutterError;
          final cards = find.byType(KubusStatCard);
          for (var i = 0; i < 12 && cards.evaluate().isEmpty; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -650),
            );
            await tester.pumpAndSettle();
          }
          expect(cards, findsNWidgets(4));
          expect(find.text('18'), findsOneWidget);
          final first = tester.getTopLeft(cards.at(0));
          final second = tester.getTopLeft(cards.at(1));
          final third = tester.getTopLeft(cards.at(2));
          final fourth = tester.getTopLeft(cards.at(3));
          final expectSingleColumn = width == 320 || textScale >= 1.5;
          if (expectSingleColumn) {
            expect(second.dy, greaterThan(first.dy));
          } else {
            expect(second.dy, closeTo(first.dy, 1));
            expect(second.dx, greaterThan(first.dx));
            expect(fourth.dy, closeTo(third.dy, 1));
          }
          expect(errors, isEmpty);
        },
      );
    }

    testWidgets(
        'natural header wraps a long identity at narrow 200 percent text',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final previousFlutterError = FlutterError.onError;
      final errors = await pumpProductSurface(
        tester,
        child: const HomeScreen(),
        size: const Size(320, 1800),
        locale: const Locale('sl'),
        brightness: Brightness.dark,
        textScale: 2,
        signedInProfile: qaOwner().copyWith(
          displayName:
              'Ana Kovač, ustvarjalka velikih stenskih poslikav in javne umetnosti',
        ),
      );
      FlutterError.onError = previousFlutterError;

      expect(find.byType(SliverFloatingHeader), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('natural header hides on scroll and returns on reverse scroll',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final previousFlutterError = FlutterError.onError;
      final errors = await pumpProductSurface(
        tester,
        child: const HomeScreen(),
        size: const Size(390, 844),
        signedInProfile: qaOwner(),
      );
      FlutterError.onError = previousFlutterError;

      final search = find.bySemanticsLabel('home_search_input');
      expect(search, findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(search, findsNothing);

      await tester.drag(scrollable, const Offset(0, 900));
      await tester.pump(const Duration(milliseconds: 700));
      expect(search, findsOneWidget);
      expect(errors, isEmpty);
    });
  });
}
