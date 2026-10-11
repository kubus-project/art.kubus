import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/map/marker_info_detail_screen.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Map detail covers are shown in cards and panels, so they request the card
/// width (`MediaUrlResolver.cardMaxWidth`), not the hero width.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ArtMarker markerWithCover(String coverUrl) {
    return ArtMarker.fromMap(<String, dynamic>{
      'id': 'marker-cover-width',
      'name': 'Marker',
      'description': 'A marker description.',
      'latitude': 46.0569,
      'longitude': 14.5058,
      'createdAt': '2026-07-01T10:00:00.000Z',
      'createdBy': 'tester',
      'metadata': <String, dynamic>{'coverImageUrl': coverUrl},
    });
  }

  testWidgets('the marker info cover requests the bounded card width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: MarkerInfoDetailScreen(
            marker: markerWithCover(
              'https://cdn.example.com/cover.jpg?width=4000',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The screen background is an asset image; the cover is the one network
    // image.
    final covers = tester
        .widgetList<Image>(find.byType(Image))
        .where((image) => image.image is NetworkImage)
        .toList();
    expect(covers, hasLength(1), reason: 'one cover image is shown');
    final url = (covers.single.image as NetworkImage).url;
    expect(url, contains('width=${MediaUrlResolver.cardMaxWidth}'));
    expect(url, isNot(contains('width=1600')),
        reason: 'the hero default width is not requested for a card');
    expect(url, isNot(contains('width=4000')));

    // Dispose the screen so its animations do not outlive the test.
    await tester.pumpWidget(const SizedBox());
  });

  test('desktop exhibition and event panel covers request the card width', () {
    final source =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();

    for (final field in ['exhibition.coverUrl', 'event.coverUrl']) {
      final bounded = RegExp(
        'resolveDisplayUrl\\(\\s*${RegExp.escape(field)},\\s*'
        'maxWidth:\\s*MediaUrlResolver\\.cardMaxWidth,?\\s*\\)',
      );
      expect(bounded.hasMatch(source), isTrue,
          reason: '$field must resolve at the card width');
      expect(
        source.contains('MediaUrlResolver.resolve($field)'),
        isFalse,
        reason: 'the unbounded resolve must not come back for $field',
      );
    }
  });
}
