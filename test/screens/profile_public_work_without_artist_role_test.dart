import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// Authored works and a public collection belong to the profile whatever its
/// role. Only the artist label, the artist's events and the artist's own
/// actions depend on the role.
const List<Map<String, dynamic>> _authoredWorks = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'authored-lala',
    'title': 'Lala Pilot Work',
    'artistName': 'turrdl',
    'relationship': 'authored',
  },
];

const List<Map<String, dynamic>> _collections = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'collection-hof',
    'name': 'Head of Flowers',
    'artworkCount': 1,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(ProfileIdentityBlock).first),
      )!;

  testWidgets(
      'mobile profile without the artist role shows its works and collection, '
      'with no artist label or events', (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.mobilePublic,
      user: ProfileFixtures.user(),
      artistArtworks: _authoredWorks,
      artistCollections: _collections,
      size: const Size(390, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text('Lala Pilot Work'), findsWidgets);
    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.userProfileArtistHighlightsTitle), findsNothing);
    expect(find.text(l10n.settingsRoleArtistTitle), findsNothing);
    expect(find.text(l10n.userProfileEventsTitle), findsNothing);
  });

  testWidgets(
      'desktop profile without the artist role shows its works and collection, '
      'with no artist label', (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopPublic,
      canonicalPublicEntry: true,
      user: ProfileFixtures.user(),
      artistArtworks: _authoredWorks,
      artistCollections: _collections,
      size: const Size(1440, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text('Lala Pilot Work'), findsWidgets);
    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.userProfileArtistPortfolioTitle), findsNothing);
    expect(find.text(l10n.settingsRoleArtistTitle), findsNothing);
  });

  testWidgets('mobile artist keeps the artist highlights, label and events',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.mobilePublic,
      user: ProfileFixtures.user(isArtist: true),
      artistArtworks: _authoredWorks,
      artistCollections: _collections,
      size: const Size(390, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text(l10n.userProfileArtistHighlightsTitle), findsOneWidget);
    expect(find.text(l10n.userProfileEventsTitle), findsWidgets);
    expect(find.text('Lala Pilot Work'), findsWidgets);
    expect(find.text('Head of Flowers'), findsWidgets);
  });

  testWidgets('desktop artist keeps the artist portfolio and label',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopPublic,
      canonicalPublicEntry: true,
      user: ProfileFixtures.user(isArtist: true),
      artistArtworks: _authoredWorks,
      artistCollections: _collections,
      size: const Size(1440, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text(l10n.userProfileArtistPortfolioTitle), findsOneWidget);
    expect(find.text(l10n.settingsRoleArtistTitle), findsWidgets);
    expect(find.text('Lala Pilot Work'), findsWidgets);
  });

  testWidgets(
      'mobile profile without the artist role and with only a collection '
      'shows no empty Artworks band', (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.mobilePublic,
      user: ProfileFixtures.user(),
      artistCollections: _collections,
      size: const Size(390, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text('Head of Flowers'), findsWidgets);
    expect(
      find.text(l10n.userProfileNoItemsTitle(l10n.userProfileArtworksTitle)),
      findsNothing,
    );
  });

  testWidgets(
      'desktop profile without the artist role and with only a collection '
      'shows no empty portfolio band', (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopPublic,
      canonicalPublicEntry: true,
      user: ProfileFixtures.user(),
      artistCollections: _collections,
      size: const Size(1440, 9000),
    );
    final l10n = l10nOf(tester);

    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.userProfileNoCreatorContentTitle), findsNothing);
    expect(find.text(l10n.userProfileArtistPortfolioTitle), findsNothing);
  });
}
