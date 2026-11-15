import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/web3/artist/collection_creator.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountA = '40000000-0000-4000-8000-000000000010';
const _profileA = '10000000-0000-4000-8000-000000000010';
const _accountB = '40000000-0000-4000-8000-000000000020';
const _profileB = '10000000-0000-4000-8000-000000000020';

class _ArtworkApi implements ArtworkBackendApi {
  final calls = <({bool mine, String? authorProfileId})>[];
  Completer<List<Artwork>>? delayedMine;
  bool returnOwnArtwork = true;

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
    List<String>? ids,
    bool mine = false,
    String? authorProfileId,
  }) async {
    calls.add((mine: mine, authorProfileId: authorProfileId));
    if (mine) {
      final pending = delayedMine;
      if (pending != null) return pending.future;
      if (returnOwnArtwork) return [_artwork('Private A library item')];
    }
    return const <Artwork>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Artwork _artwork(String title) => Artwork(
      id: title.toLowerCase().replaceAll(' ', '-'),
      title: title,
      artist: 'Creator',
      description: 'Private library fixture',
      position: const LatLng(46.0511, 14.5051),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      isPublic: false,
    );

UserProfile _profile({required String accountId, required String profileId}) =>
    UserProfile(
      id: profileId,
      userId: accountId,
      walletAddress: '',
      username: 'creator',
      displayName: 'Creator',
      bio: '',
      avatar: '',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _pumpCreator(
  WidgetTester tester, {
  required ProfileProvider profile,
  required ArtworkProvider artworks,
  required CollectionsProvider collections,
  required Web3Provider web3,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<CollectionsProvider>.value(value: collections),
        ChangeNotifierProvider<Web3Provider>.value(value: web3),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en'), Locale('sl')],
        home: const CollectionCreator(),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.resetForTesting();
  });

  testWidgets(
      'account switch clears private library and selection; same-account refresh preserves it',
      (tester) async {
    final api = _ArtworkApi();
    final artworkProvider = ArtworkProvider(backendApi: api);
    final profileProvider = ProfileProvider();
    final collectionsProvider = CollectionsProvider();
    final web3Provider = Web3Provider();
    addTearDown(artworkProvider.dispose);
    addTearDown(profileProvider.dispose);
    addTearDown(collectionsProvider.dispose);
    addTearDown(web3Provider.dispose);

    AccountIdentity.setAccountKey(_accountA);
    profileProvider.setCurrentUser(
      _profile(accountId: _accountA, profileId: _profileA),
    );
    await _pumpCreator(
      tester,
      profile: profileProvider,
      artworks: artworkProvider,
      collections: collectionsProvider,
      web3: web3Provider,
    );

    final localizations = AppLocalizations.of(
      tester.element(find.byType(CollectionCreator)),
    )!;
    final loadButton =
        find.text(localizations.collectionCreatorLoadArtworkLibraryLabel);
    await tester.ensureVisible(loadButton);
    await tester.pump();
    await tester.tap(loadButton);
    await _pumpFrames(tester);
    expect(find.text('Private A library item'), findsOneWidget);
    expect(api.calls, contains((mine: true, authorProfileId: null)));
    expect(api.calls, contains((mine: false, authorProfileId: _profileA)));

    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.pump();
    await tester.tap(checkbox);
    await _pumpFrames(tester);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);

    // Refreshing the token/profile with the same canonical identity keeps the
    // current selection; account identity changes are the reset boundary.
    profileProvider.setCurrentUser(
      _profile(accountId: _accountA, profileId: _profileA)
          .copyWith(displayName: 'Creator refreshed'),
    );
    await _pumpFrames(tester);
    expect(find.text('Private A library item'), findsWidgets);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);

    AccountIdentity.setAccountKey(_accountB);
    profileProvider.setCurrentUser(
      _profile(accountId: _accountB, profileId: _profileB),
    );
    AccountIdentity.notifyListenersChanged();
    await _pumpFrames(tester);

    expect(find.text('Private A library item'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(api.calls, hasLength(2));
    expect(localizations.commonRetry, isNotEmpty);
  });

  testWidgets('late A library response cannot restore A content after switch',
      (tester) async {
    final api = _ArtworkApi()..delayedMine = Completer<List<Artwork>>();
    final artworkProvider = ArtworkProvider(backendApi: api);
    final profileProvider = ProfileProvider();
    final collectionsProvider = CollectionsProvider();
    final web3Provider = Web3Provider();
    addTearDown(artworkProvider.dispose);
    addTearDown(profileProvider.dispose);
    addTearDown(collectionsProvider.dispose);
    addTearDown(web3Provider.dispose);

    AccountIdentity.setAccountKey(_accountA);
    profileProvider.setCurrentUser(
      _profile(accountId: _accountA, profileId: _profileA),
    );
    await _pumpCreator(
      tester,
      profile: profileProvider,
      artworks: artworkProvider,
      collections: collectionsProvider,
      web3: web3Provider,
    );

    final localizations = AppLocalizations.of(
      tester.element(find.byType(CollectionCreator)),
    )!;
    final loadButton =
        find.text(localizations.collectionCreatorLoadArtworkLibraryLabel);
    await tester.ensureVisible(loadButton);
    await tester.pump();
    await tester.tap(loadButton);
    await tester.pump();
    expect(api.calls, contains((mine: true, authorProfileId: null)));

    AccountIdentity.setAccountKey(_accountB);
    profileProvider.setCurrentUser(
      _profile(accountId: _accountB, profileId: _profileB),
    );
    AccountIdentity.notifyListenersChanged();
    await _pumpFrames(tester);

    api.delayedMine!.complete([_artwork('Late private A item')]);
    await _pumpFrames(tester);

    expect(find.text('Late private A item'), findsNothing);
    expect(artworkProvider.artworks, isEmpty);
  });
}
