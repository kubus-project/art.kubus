import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/widgets/artwork_author_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';

Artwork _artwork({
  String artist = 'Free Text Artist',
  ArtworkAuthorProfile? author,
  Map<String, dynamic>? metadata,
}) =>
    Artwork(
      id: 'art-1',
      title: 'Public work',
      artist: artist,
      authorProfile: author,
      description: '',
      position: const LatLng(46, 14),
      rewards: 0,
      createdAt: DateTime(2026),
      metadata: metadata,
    );

const _author = ArtworkAuthorProfile(
  profileId: _profileId,
  username: 'damjan_stevovic',
  displayName: 'Damjan Stevovic',
);

Widget _harness(
  Artwork artwork, {
  ArtworkAuthorProfileOpener? openProfile,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: openProfile == null
            ? ArtworkAuthorLine(artwork: artwork)
            : ArtworkAuthorLine(artwork: artwork, openProfile: openProfile),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with an author profile the line preserves cultural credit', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_artwork(author: _author)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Free Text Artist @damjan_stevovic',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('tapping opens the profile by the attributed profile id', (
    tester,
  ) async {
    final opened = <(String, String?)>[];
    await tester.pumpWidget(
      _harness(
        _artwork(author: _author),
        openProfile: (context, {required profileId, username}) async {
          opened.add((profileId, username));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(opened, [(_profileId, 'damjan_stevovic')]);
  });

  testWidgets('keyboard focus and Enter / Space activate the link', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      _harness(
        _artwork(author: _author),
        openProfile: (context, {required profileId, username}) async {
          opens++;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull, reason: 'the author link is reachable by Tab');
    expect(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byWidgetPredicate((w) => w is Focus),
      ),
      findsWidgets,
    );
    expect(inkWell.canRequestFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opens, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(opens, 2);
  });

  testWidgets('touch target is at least 44 logical pixels', (tester) async {
    await tester.pumpWidget(_harness(_artwork(author: _author)));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(InkWell));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  testWidgets('semantics announce a button that names the profile', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_harness(_artwork(author: _author)));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(InkWell));
    expect(node.label, 'Open profile of Free Text Artist @damjan_stevovic');
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('the semantics label is localized', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(_artwork(author: _author), locale: const Locale('sl')),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(InkWell));
    expect(node.label, 'Odpri profil: Free Text Artist @damjan_stevovic');
    semantics.dispose();
  });

  testWidgets('a missing handle still renders the display name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _artwork(
          artist: 'Unknown',
          author: const ArtworkAuthorProfile(
            profileId: _profileId,
            username: '',
            displayName: 'Only Name',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Only Name', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('@', findRichText: true), findsNothing);
  });

  testWidgets('without an author profile the artist line is text only', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_artwork()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Free Text Artist', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a single profile is not assigned to a multi-artist credit',
      (tester) async {
    await tester.pumpWidget(_harness(_artwork(
      artist: 'Unknown',
      author: _author,
      metadata: {
        'artist_name_byline': ['Artist A', 'Artist B']
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Artist A', findRichText: true), findsOneWidget);
    expect(find.textContaining('Artist B', findRichText: true), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('uploader and artist metadata never produce a link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _artwork(
          metadata: {
            'walletAddress': 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb',
            'creatorId': _profileId,
            'artistUserId': '11111111-1111-4111-8111-111111111111',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Free Text Artist', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(InkWell), findsNothing);
  });

  test('both detail screens render the shared author line', () {
    for (final path in const [
      'lib/screens/art/art_detail_screen.dart',
      'lib/screens/desktop/art/desktop_artwork_detail_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ArtworkAuthorLine('), reason: path);
      expect(source, isNot(contains('ArtworkCreatorByline(')), reason: path);
    }
  });
}
