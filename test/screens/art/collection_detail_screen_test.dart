import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/collection_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public viewer sees collection actions without empty menu',
      (tester) async {
    final harness = _CollectionHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(CreatorSubjectActionsButton), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('public embedded collection hides the empty menu trigger',
      (tester) async {
    final harness = _CollectionHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
      embedded: true,
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('collection owner can open management actions', (tester) async {
    final harness = _CollectionHarness(owner: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
      embedded: true,
    )));
    await tester.pumpAndSettle();

    final menu = find.byIcon(Icons.more_horiz);
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}

class _CollectionHarness {
  _CollectionHarness({bool owner = false})
      : collections = CollectionsProvider(api: _FakeBackendApiService()),
        wallet = WalletProvider(deferInit: true),
        savedItems = SavedItemsProvider(),
        takeover = PublicEntityTakeoverProvider(),
        collab = CollabProvider(api: _FakeCollabApi()),
        profile = ProfileProvider() {
    collections.seedPublicPresentation(const <String, dynamic>{
      'id': 'collection-1',
      'title': 'Public collection',
      'itemCount': 0,
    });
    if (owner) wallet.setCurrentWalletAddressForTesting('owner-wallet');
  }

  final CollectionsProvider collections;
  final WalletProvider wallet;
  final SavedItemsProvider savedItems;
  final PublicEntityTakeoverProvider takeover;
  final CollabProvider collab;
  final ProfileProvider profile;

  Widget app(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CollectionsProvider>.value(value: collections),
          ChangeNotifierProvider<WalletProvider>.value(value: wallet),
          ChangeNotifierProvider<SavedItemsProvider>.value(value: savedItems),
          ChangeNotifierProvider<PublicEntityTakeoverProvider>.value(
            value: takeover,
          ),
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
      );

  void dispose() {
    collections.dispose();
    wallet.dispose();
    savedItems.dispose();
    takeover.dispose();
    collab.dispose();
    profile.dispose();
  }
}

class _FakeBackendApiService implements BackendApiService {
  @override
  Future<Map<String, dynamic>> getCollection(String collectionId) async =>
      <String, dynamic>{
        'id': collectionId,
        'name': 'Public collection',
        'wallet_address': 'owner-wallet',
        'is_public': true,
        'artwork_count': 0,
        'artworks': <dynamic>[],
      };

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollabApi implements CollabApi {
  @override
  Future<List<CollabMember>> listCollaborators(
    String entityType,
    String entityId,
  ) async =>
      <CollabMember>[];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
