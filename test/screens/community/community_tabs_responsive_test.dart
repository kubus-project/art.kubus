import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/product_surface_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in <({Locale locale, double textScale})>[
    (locale: const Locale('en'), textScale: 1),
    (locale: const Locale('sl'), textScale: 1.8),
  ]) {
    testWidgets(
      'four Community tabs fill a 320px phone in '
      '${entry.locale.languageCode} at ${entry.textScale}x text',
      (tester) async {
        final previousOnError = FlutterError.onError;
        final errors = await pumpProductSurface(
          tester,
          child: const CommunityScreen(),
          size: const Size(320, 844),
          locale: entry.locale,
          textScale: entry.textScale,
          settle: const Duration(milliseconds: 400),
        );
        FlutterError.onError = previousOnError;

        final tabBar = tester.widget<TabBar>(find.byType(TabBar).first);
        expect(tabBar.isScrollable, isFalse);
        expect(tabBar.tabAlignment, TabAlignment.fill);
        expect(tabBar.tabs, hasLength(4));
        final tabTargets = find.descendant(
          of: find.byType(TabBar).first,
          matching: find.byType(InkWell),
        );
        final tabRects = tabTargets.evaluate().map(
              (element) => tester.getRect(find.byWidget(element.widget)),
            );
        final widths = tabRects.map((rect) => rect.width).toList();
        // Each Tab must be laid out by TabBar's equal-width segmented row.
        expect(widths, hasLength(4));
        for (var index = 1; index < widths.length; index++) {
          expect(widths[index], closeTo(widths.first, 0.5),
              reason: 'tab widths=$widths');
        }

        final context = tester.element(find.byType(CommunityScreen));
        final l10n = AppLocalizations.of(context)!;
        for (final label in <String>[
          l10n.communityFollowingTab,
          l10n.communityDiscoverTab,
          l10n.communityGroupsTab,
          l10n.communityArtTab,
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 2);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
        }
        expect(errors, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
