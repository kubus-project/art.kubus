import 'package:art_kubus/widgets/detail/artwork_place_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps textual place visible without coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArtworkPlaceContext(
            placeLabel: 'Špica, Ljubljana',
            coordinates: null,
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('Špica, Ljubljana'), findsOneWidget);
    expect(find.byIcon(Icons.my_location_outlined), findsNothing);
  });

  testWidgets('shows coordinates only when supplied by a validated caller', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArtworkPlaceContext(
            placeLabel: null,
            coordinates: '46.0500, 14.5000',
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('46.0500, 14.5000'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });
}
