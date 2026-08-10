import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/features/web3/wallet_edition_inventory.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collectible.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/wallet_custody_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class _WalletWithIdentity extends WalletProvider {
  _WalletWithIdentity() : super(deferInit: true);

  static const String address = 'wallet-owner';

  @override
  WalletAuthoritySnapshot get authority => const WalletAuthoritySnapshot(
        state: WalletAuthorityState.localSignerReady,
        signerSource: WalletSignerSource.local,
        accountSignedIn: true,
        signInMethod: AuthSignInMethod.email,
        accountEmail: 'owner@example.com',
        walletAddress: address,
        hasLocalSigner: true,
        hasExternalSigner: false,
        externalWalletConnected: false,
        externalWalletName: null,
        hasEncryptedBackup: false,
        encryptedBackupStatusKnown: true,
        hasPasskeyProtection: false,
        mnemonicBackupRequired: false,
        recoveryNeeded: false,
      );

  @override
  String? get currentWalletAddress => address;

  @override
  bool get hasWalletIdentity => true;

  @override
  bool get canTransact => true;
}

Future<CollectiblesProvider> _ownedEditionProvider() async {
  final artworkProvider = ArtworkProvider();
  artworkProvider.addOrUpdateArtwork(
    Artwork(
      id: 'art-owned',
      title: 'Owned Edition Artwork',
      artist: 'Owner Artist',
      description: 'Canonical wallet inventory test.',
      imageUrl: '/uploads/owned-edition.png',
      position: const LatLng(46, 14),
      rewards: 0,
      createdAt: DateTime.utc(2026, 8, 1),
      category: 'Sculpture',
    ),
  );
  final provider = CollectiblesProvider()..bindArtworkProvider(artworkProvider);
  final series = await provider.createNFTSeries(
    artworkId: 'art-owned',
    name: 'Owned Edition Series',
    description: 'Series held by the active wallet.',
    creatorAddress: 'creator-wallet',
    totalSupply: 3,
    rarity: CollectibleRarity.rare,
    mintPrice: 0,
    imageUrl: '/uploads/owned-edition.png',
  );
  await provider.mintCollectible(
    seriesId: series.id,
    ownerAddress: _WalletWithIdentity.address,
    transactionHash: 'tx-owned-edition',
  );
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'desktop wallet removes staking and uses canonical owned editions',
      (tester) async {
    final collectibles = await _ownedEditionProvider();
    final canonicalOwned = WalletEditionInventory.resolve(
      collectiblesProvider: collectibles,
      walletAddress: _WalletWithIdentity.address,
    );
    expect(canonicalOwned, hasLength(1));
    expect(
      collectibles.allSeries
          .any((series) => series.id == canonicalOwned.single.seriesId),
      isTrue,
    );
    final wallet = _WalletWithIdentity();
    final theme = ThemeProvider();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<WalletProvider>.value(value: wallet),
          ChangeNotifierProvider<CollectiblesProvider>.value(
            value: collectibles,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/connect-wallet': (_) => const Scaffold(),
            '/import-wallet': (_) => const Scaffold(),
          },
          home: const DesktopWalletScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -600),
    );
    await tester.pump();

    final context = tester.element(find.byType(DesktopWalletScreen));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.walletHomeDesktopTabNfts), findsOneWidget);
    expect(find.text(l10n.walletHomeDesktopTabStaking), findsNothing);
    expect(find.text(l10n.walletHomeStakeAction), findsNothing);
    expect(find.byType(WalletCustodyStatusPanel), findsOneWidget);
  });
}
