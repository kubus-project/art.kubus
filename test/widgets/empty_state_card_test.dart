import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
      'announces the empty-state title and description as a live region',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: EmptyStateCard(
              title: 'No records',
              description: 'Create one to get started.',
            ),
          ),
        ),
      ),
    );

    final finder = find.bySemanticsLabel(
      'No records. Create one to get started.',
    );
    expect(finder, findsOneWidget);
    expect(
      tester.getSemantics(finder).flagsCollection.isLiveRegion,
      isTrue,
    );

    semantics.dispose();
  });
}
