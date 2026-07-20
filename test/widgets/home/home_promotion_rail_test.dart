import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/home/home_promotion_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

HomeRailItem _item(PromotionEntityType type, String title) {
  return HomeRailItem.fromJson(<String, dynamic>{
    'id': title,
    'entityType': type.apiValue,
    'title': title,
    'stats': <String, dynamic>{},
  });
}

IconData _iconFor(PromotionEntityType type) {
  switch (type) {
    case PromotionEntityType.artwork:
      return Icons.palette_outlined;
    case PromotionEntityType.profile:
      return Icons.person_outline;
    case PromotionEntityType.institution:
      return Icons.apartment_outlined;
    case PromotionEntityType.event:
      return Icons.event_outlined;
    case PromotionEntityType.exhibition:
      return Icons.museum_outlined;
  }
}

Widget _harness(Widget child, {double width = 900}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: const [KubusColorRoles.dark],
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

// The four media entity types render without provider dependencies; the
// profile card path (ProfileIdentitySummary) is exercised elsewhere.
const _mediaTypes = <PromotionEntityType>[
  PromotionEntityType.artwork,
  PromotionEntityType.institution,
  PromotionEntityType.event,
  PromotionEntityType.exhibition,
];

void main() {
  testWidgets('renders a card per entity type with a non-colour icon signal',
      (tester) async {
    final items = _mediaTypes.map((t) => _item(t, t.apiValue)).toList();
    await tester.pumpWidget(
      _harness(
        HomePromotionRailList(
          items: items,
          placeholderIconBuilder: _iconFor,
          profileFallbackLabel: 'Creator',
          enableHover: true,
        ),
      ),
    );
    await tester.pump();

    for (final t in _mediaTypes) {
      expect(find.text(t.apiValue), findsOneWidget);
      // Entity type stays identifiable without colour via the placeholder icon.
      expect(find.byIcon(_iconFor(t)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards are keyboard-focusable and activate on Enter',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      _harness(
        HomePromotionRailList(
          items: [_item(PromotionEntityType.artwork, 'Artwork')],
          placeholderIconBuilder: _iconFor,
          profileFallbackLabel: 'Creator',
          onItemTap: (item) => tapped.add(item.title),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FocusableActionDetector), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tapped, contains('Artwork'));
  });

  testWidgets('tapping a card invokes the tap handler', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      _harness(
        HomePromotionRailList(
          items: [_item(PromotionEntityType.event, 'Event')],
          placeholderIconBuilder: _iconFor,
          profileFallbackLabel: 'Creator',
          onItemTap: (item) => tapped.add(item.title),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Event'));
    expect(tapped, contains('Event'));
  });
}
