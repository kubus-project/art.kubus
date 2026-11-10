import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collection_record.dart';
import 'package:art_kubus/screens/art/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(CollectionArtworkRecord artwork) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CollectionArtworkCredit(artwork: artwork)),
      );

  testWidgets('recorded credit links only the explicit artwork author',
      (tester) async {
    final artwork = CollectionArtworkRecord.fromMap({
      'id': 'work',
      'title': 'Work',
      'artistName': 'turrdl',
      'authorProfile': {
        'profileId': 'profile-1',
        'username': 'damjan_stevovic',
        'displayName': 'Damjan Stevovic',
      },
      'ownerUserId': 'other-owner',
    });
    await tester.pumpWidget(harness(artwork));
    expect(find.text('turrdl'), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
    expect(artwork.authorProfile?.profileId, 'profile-1');
  });

  testWidgets('text credit never links an owner without author attribution',
      (tester) async {
    final artwork = CollectionArtworkRecord.fromMap({
      'id': 'work',
      'title': 'Work',
      'artist_name': 'Recorded artist',
      'ownerUserId': 'other-owner',
    });
    await tester.pumpWidget(harness(artwork));
    expect(find.text('Recorded artist'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}
