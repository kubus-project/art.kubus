import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collectible.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/web3/marketplace/marketplace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Artwork _marketplaceArtwork() {
  return Artwork(
    id: 'art-market-1',
    title: 'Marketplace Artwork',
    artist: 'Artist One',
    description: 'Photography artwork for marketplace rendering.',
    imageUrl: '/uploads/art-market-1-cover.png',
    position: const LatLng(46.0, 14.0),
    rewards: 2,
    createdAt: DateTime.utc(2025, 1, 1),
    category: 'Photography',
  );
}

Future<CollectiblesProvider> _seedCollectibles(
  ArtworkProvider artworkProvider,
) async {
  final collectiblesProvider = CollectiblesProvider()
    ..bindArtworkProvider(artworkProvider);

  artworkProvider.addOrUpdateArtwork(_marketplaceArtwork());
  final series = await collectiblesProvider.createNFTSeries(
    artworkId: 'art-market-1',
    name: 'Marketplace Series',
    description: 'Series for marketplace parity checks.',
    creatorAddress: 'wallet-market-1',
    totalSupply: 10,
    rarity: CollectibleRarity.rare,
    mintPrice: 14,
    imageUrl: '/uploads/series-market-1.png',
  );

  final collectible = await collectiblesProvider.mintCollectible(
    seriesId: series.id,
    ownerAddress: 'wallet-owner-1',
    transactionHash: 'tx-market-1',
  );
  await collectiblesProvider.listCollectibleForSale(
    collectibleId: collectible.id,
    price: '55',
  );

  return collectiblesProvider;
}

Widget _buildApp({
  required Widget home,
  required ArtworkProvider artworkProvider,
  required CollectiblesProvider collectiblesProvider,
  required ThemeProvider themeProvider,
  required NavigationProvider navigationProvider,
  required Web3Provider web3Provider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: artworkProvider),
      ChangeNotifierProvider.value(value: collectiblesProvider),
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: navigationProvider),
      ChangeNotifierProvider.value(value: web3Provider),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: {
        '/connect-wallet': (_) => const Scaffold(body: SizedBox.shrink()),
        '/ar': (_) => const Scaffold(body: SizedBox.shrink()),
      },
      home: home,
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 8}) async {
  for (var i = 0; i < count; i += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

List<String> _networkImageUrls(WidgetTester tester) {
  final urls = <String>[];
  for (final image in tester.widgetList<Image>(find.byType(Image))) {
    final imageProvider = image.image;
    if (imageProvider is NetworkImage) {
      urls.add(imageProvider.url);
    } else if (imageProvider is ResizeImage &&
        imageProvider.imageProvider is NetworkImage) {
      urls.add((imageProvider.imageProvider as NetworkImage).url);
    }
  }
  return urls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'Marketplace_onboarding_completed': true,
      'skipOnboardingForReturningUsers': false,
    });
  });

  testWidgets(
      'mobile and desktop marketplace cards render the same truthful value and cover image',
      (tester) async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = await _seedCollectibles(artworkProvider);
    final themeProvider = ThemeProvider();
    final navigationProvider = NavigationProvider();
    final web3Provider = Web3Provider();

    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      _buildApp(
        home: const Marketplace(),
        artworkProvider: artworkProvider,
        collectiblesProvider: collectiblesProvider,
        themeProvider: themeProvider,
        navigationProvider: navigationProvider,
        web3Provider: web3Provider,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('55 KUB8'), findsWidgets);
    expect(
      _networkImageUrls(tester).any(
        (url) => url.contains('art-market-1-cover.png'),
      ),
      isTrue,
    );

    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    await tester.pumpWidget(
      _buildApp(
        home: const DesktopMarketplaceScreen(),
        artworkProvider: artworkProvider,
        collectiblesProvider: collectiblesProvider,
        themeProvider: themeProvider,
        navigationProvider: navigationProvider,
        web3Provider: web3Provider,
      ),
    );
    await _pumpFrames(tester, count: 10);

    expect(find.text('55 KUB8'), findsWidgets);
    expect(find.textContaining('SOL'), findsNothing);
    expect(
      _networkImageUrls(tester).any(
        (url) => url.contains('art-market-1-cover.png'),
      ),
      isTrue,
    );
  });
}
