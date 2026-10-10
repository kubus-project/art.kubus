import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/screens/support_center_screen.dart';

void main() {
  testWidgets('FAQ opens and explains public discovery', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SupportCenterScreen()),
    );

    expect(find.text('What is art.kubus?'), findsOneWidget);
    await tester.tap(find.text('What is art.kubus?'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'An open art map for exploring artworks, exhibitions and cultural spaces.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('bug reports expose reproduction and expected-result fields',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SupportCenterScreen(initialSection: SupportSection.bug),
      ),
    );

    expect(find.text('Steps to reproduce'), findsOneWidget);
    expect(find.text('Expected behavior'), findsOneWidget);
    expect(find.text('Actual behavior'), findsOneWidget);
    expect(find.text('Include device platform'), findsOneWidget);
  });

  testWidgets('Slovenian support navigation and contact form are present',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('sl'),
        supportedLocales: [Locale('en'), Locale('sl')],
        home: SupportCenterScreen(initialSection: SupportSection.contact),
      ),
    );

    expect(find.text('Pomoč in podpora'), findsWidgets);
    expect(find.text('Zadeva'), findsOneWidget);
    expect(find.text('Sporočilo'), findsOneWidget);
  });
}
