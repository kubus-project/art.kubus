import 'package:art_kubus/screens/activity/saved_items_screen.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final width in <double>[320, 390]) {
    testWidgets(
        'an empty library shows one empty state and no empty sections '
        '(${width.toInt()}px)', (tester) async {
      final errors = await pumpProductSurface(
        tester,
        child: const SavedItemsScreen(),
        size: Size(width, 800),
      );

      expect(errors, isEmpty);
      expect(find.byType(EmptyStateCard), findsOneWidget);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      // The app bar names the page once; the header does not repeat it.
      expect(find.text('Saved items'), findsOneWidget);
      // No per-type sections are rendered while nothing is saved.
      expect(find.textContaining('Saved artworks'), findsNothing);
      expect(find.textContaining('Saved events'), findsNothing);
      expect(find.text('Explore the map'), findsOneWidget);
    });
  }
}
