import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/app_refresh_provider.dart';
import 'package:art_kubus/providers/artwork_drafts_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/tile_providers.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/web3/artist/artwork_creator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The artwork creator offers an optional "Artist / author" field. It starts
/// blank even for a signed-in account with a display name: authorship is an
/// explicit statement and is never inferred from the uploader.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<(ArtworkDraftsProvider, String)> pump(
    WidgetTester tester, {
    required Locale locale,
    Size size = const Size(390, 900),
    ThemeMode themeMode = ThemeMode.light,
    ArtworkDraftsProvider? drafts,
    String? draftId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final provider = drafts ?? ArtworkDraftsProvider();
    final id = draftId ?? provider.createDraft();
    final profile = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'u1',
        walletAddress: 'WalletUploader1111111111111111111111111111111',
        username: 'uploader',
        displayName: 'Uploader Person',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
    final theme = ThemeProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArtworkDraftsProvider>.value(value: provider),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
          ChangeNotifierProvider<AppRefreshProvider>(
              create: (_) => AppRefreshProvider()),
          ChangeNotifierProvider<CollabProvider>(
              create: (_) => CollabProvider()),
          Provider<TileProviders>(create: (_) => TileProviders(theme)),
        ],
        child: MaterialApp(
          locale: locale,
          themeMode: themeMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArtworkCreatorScreen(draftId: id),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return (provider, id);
  }

  // Basics lists Title, then Artist / author, then Description.
  Finder artistField(String label) {
    expect(find.text(label), findsWidgets, reason: 'field label');
    return find.byType(TextFormField).at(1);
  }

  testWidgets('the field exists in EN, starts blank, and carries the helper',
      (tester) async {
    await pump(tester, locale: const Locale('en'));
    expect(find.text('Artist / author'), findsWidgets);
    expect(find.text('Leave blank if the author is unknown.'), findsOneWidget);
    final field = tester.widget<TextFormField>(artistField('Artist / author'));
    expect(field.controller?.text ?? field.initialValue ?? '', isEmpty);
    // The signed-in uploader's name is nowhere in the field.
    expect(find.text('Uploader Person'), findsNothing);
  });

  testWidgets('Slovenian copy comes from the ARB', (tester) async {
    await pump(tester, locale: const Locale('sl'));
    expect(find.text('Umetnik / avtor'), findsWidgets);
    expect(find.text('Pustite prazno, če avtor ni znan.'), findsOneWidget);
  });

  testWidgets('typing writes the draft, and a rebuild keeps the value',
      (tester) async {
    final (provider, id) = await pump(tester, locale: const Locale('en'));
    await tester.enterText(artistField('Artist / author'), '  Francesco Robba');
    await tester.pump();
    expect(provider.getDraft(id)!.artistName, '  Francesco Robba');

    // Rebuild the whole screen from the same draft (navigation / rotation).
    await pump(
      tester,
      locale: const Locale('en'),
      size: const Size(1440, 900),
      drafts: provider,
      draftId: id,
    );
    final field = tester.widget<TextFormField>(artistField('Artist / author'));
    expect(field.controller?.text, '  Francesco Robba');
  });
}
