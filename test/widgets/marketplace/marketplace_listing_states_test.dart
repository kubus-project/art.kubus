import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collectible.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/web3/marketplace/marketplace.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/marketplace/marketplace_listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Artwork _artwork(String id, String title, String artist) => Artwork(
      id: id,
      title: title,
      artist: artist,
      description: 'Fixture.',
      imageUrl: '/uploads/$id.png',
      position: const LatLng(46.0, 14.0),
      rewards: 2,
      createdAt: DateTime.utc(2025, 1, 1),
      category: 'Photography',
    );

/// One listed edition (55 KUB8) and one series with no listing.
Future<CollectiblesProvider> _seed(ArtworkProvider artworks) async {
  final provider = CollectiblesProvider()..bindArtworkProvider(artworks);
  artworks.addOrUpdateArtwork(_artwork('art-a', 'Listed Work', 'Ana Kovač'));
  final listed = await provider.createNFTSeries(
    artworkId: 'art-a',
    name: 'Listed Series',
    description: 'Listed.',
    creatorAddress: 'creator-wallet-a',
    totalSupply: 10,
    rarity: CollectibleRarity.legendary,
    mintPrice: 14,
    imageUrl: '/uploads/series-a.png',
  );
  final edition = await provider.mintCollectible(
    seriesId: listed.id,
    ownerAddress: 'collector-wallet-1',
    transactionHash: 'tx-a',
  );
  await provider.listCollectibleForSale(collectibleId: edition.id, price: '55');

  artworks.addOrUpdateArtwork(_artwork('art-b', 'Quiet Work', 'Maja Novak'));
  final quiet = await provider.createNFTSeries(
    artworkId: 'art-b',
    name: 'Quiet Series',
    description: 'Not listed.',
    creatorAddress: 'creator-wallet-b',
    totalSupply: 5,
    rarity: CollectibleRarity.epic,
    mintPrice: 20,
    imageUrl: '/uploads/series-b.png',
  );
  await provider.mintCollectible(
    seriesId: quiet.id,
    ownerAddress: 'collector-wallet-2',
    transactionHash: 'tx-b',
  );
  return provider;
}

class _FailingCollectibles extends CollectiblesProvider {
  @override
  String? get error => 'SocketException: Failed host lookup: api.kubus.site';

  @override
  bool get isLoading => false;
}

Widget _app(
  Widget home, {
  required CollectiblesProvider collectibles,
  ArtworkProvider? artworks,
  Locale locale = const Locale('en'),
}) {
  final theme = ThemeProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: artworks ?? ArtworkProvider()),
      ChangeNotifierProvider.value(value: collectibles),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => Web3Provider()),
      ChangeNotifierProvider(create: (_) => WalletProvider(deferInit: true)),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: theme.lightTheme,
      routes: {
        '/connect-wallet': (_) => const Scaffold(body: SizedBox.shrink()),
        '/ar': (_) => const Scaffold(body: SizedBox.shrink()),
      },
      home: home,
    ),
  );
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'Marketplace_onboarding_completed': true,
    });
  });

  testWidgets(
      'listing separates the cultural object from the economic listing: '
      'creator byline, then value source, amount + unit and state',
      (tester) async {
    final artworks = ArtworkProvider();
    final provider = await _seed(artworks);
    final entries = provider.getFeaturedMarketplaceEntries();
    final listed = entries.firstWhere((e) => e.isListed);
    final quiet = entries.firstWhere((e) => !e.isListed);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_app(
      Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              height: 380,
              child: MarketplaceListingCard(entry: listed, onOpen: () {}),
            ),
            SizedBox(
              width: 200,
              height: 380,
              child: MarketplaceListingCard(entry: quiet, onOpen: () {}),
            ),
          ],
        ),
      ),
      collectibles: provider,
      artworks: artworks,
    ));
    await tester.pump();

    // Cultural layer: creator is the artwork's artist, not a wallet.
    expect(find.text('by Ana Kovač'), findsOneWidget);
    expect(find.textContaining('collector-wallet'), findsNothing);
    expect(find.textContaining('creator-wallet'), findsNothing);

    // Economic layer: the listed edition says it is a listing price.
    expect(find.text('Listed for'), findsOneWidget);
    expect(find.text('55 KUB8'), findsOneWidget);
    expect(find.text('FOR SALE'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Listed for: 55 KUB8. For sale'),
      findsOneWidget,
    );
    // The unlisted series never claims to be for sale.
    expect(find.text('NOT LISTED'), findsOneWidget);

    // No rarity gradients or glass behind the art.
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>();
    expect(decorations.any((d) => d.gradient != null), isFalse);
    expect(find.byType(LiquidGlassCard), findsNothing);
    handle.dispose();
  });

  testWidgets('wallet disconnected: My listings asks to connect, no fake list',
      (tester) async {
    final artworks = ArtworkProvider();
    final provider = await _seed(artworks);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        _app(const Marketplace(), collectibles: provider, artworks: artworks));
    await _frames(tester);

    await tester.tap(find.text('My listings').last);
    await _frames(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Marketplace)))!;
    expect(find.text(l10n.marketplaceConnectWalletTitle), findsOneWidget);
    expect(find.text('55 KUB8'), findsNothing);
  });

  testWidgets('load failure is classified with retry, never the raw string',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      const DesktopMarketplaceScreen(),
      collectibles: _FailingCollectibles(),
    ));
    await _frames(tester);
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets('empty marketplace uses the empty state, not an error',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        _app(const Marketplace(), collectibles: CollectiblesProvider()));
    await _frames(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(Marketplace)))!;
    expect(find.text(l10n.marketplaceNoMintedNftsTitle), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('SL at 320 px with 2x text: listing card fits', (tester) async {
    final artworks = ArtworkProvider();
    final provider = await _seed(artworks);
    final listed =
        provider.getFeaturedMarketplaceEntries().firstWhere((e) => e.isListed);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(2.0),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: MarketplaceListingSummary(entry: listed),
            ),
          ),
        ),
      ),
      collectibles: provider,
      artworks: artworks,
      locale: const Locale('sl'),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
