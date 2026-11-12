import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The artist badge marks an artist capability; the verified glyph marks separately evidenced
// identity. A walletless approved artist must show the first without the second, and neither may
// depend on a wallet being linked.
void main() {
  group('artist badge is independent of identity verification and of a wallet',
      () {
    testWidgets(
        'an unverified artist shows the artist badge and no verified glyph',
        (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(
          displayName: 'Damjan Stevović',
          handle: 'damjan_stevovic',
          isArtist: true,
          isVerified: false,
        ),
      );
      expect(find.byType(ArtistBadge), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets(
        'a verified non-artist shows the verified glyph and no artist badge',
        (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(
          displayName: 'Ana Kovač',
          handle: 'ana',
          isArtist: false,
          isVerified: true,
        ),
      );
      expect(find.byType(ArtistBadge), findsNothing);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('a generic profile shows neither', (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(displayName: 'Ana', handle: 'ana'),
      );
      expect(find.byType(ArtistBadge), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
    });
  });

  group('public profile payload of a walletless artist', () {
    // Shape returned by GET /api/profiles/:id for an approved, walletless, unverified artist.
    const payload = <String, dynamic>{
      'id': '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
      'userId': 'e10d1421-019f-481a-8065-637f1fad53ed',
      'walletAddress': null,
      'username': 'damjan_stevovic',
      'displayName': 'Damjan Stevović',
      'isArtist': true,
      'isVerified': false,
      'isInstitution': false,
    };

    test('keeps isArtist true with no wallet (camelCase and snake_case)', () {
      final camel = UserProfile.fromJson(payload);
      expect(camel.isArtist, isTrue);
      expect(camel.walletAddress, isEmpty);
      expect(camel.userId, 'e10d1421-019f-481a-8065-637f1fad53ed');

      final snake = UserProfile.fromJson(<String, dynamic>{
        'id': payload['id'],
        'user_id': payload['userId'],
        'username': payload['username'],
        'display_name': payload['displayName'],
        'is_artist': true,
      });
      expect(snake.isArtist, isTrue);
      expect(snake.walletAddress, isEmpty);
    });

    test('a generic profile stays generic', () {
      final generic = UserProfile.fromJson(<String, dynamic>{
        ...payload,
        'isArtist': false,
      });
      expect(generic.isArtist, isFalse);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}
