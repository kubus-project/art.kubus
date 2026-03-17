import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collectible.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

Artwork _artwork({
  required String id,
  bool isNft = false,
  String? nftMintAddress,
  bool isPublic = true,
  bool isActive = true,
  bool isForSale = false,
  double? price,
  String? currency,
  String? imageUrl,
}) {
  return Artwork(
    id: id,
    title: 'Artwork $id',
    artist: 'Artist $id',
    description: 'Description $id',
    position: const LatLng(46.0, 14.0),
    rewards: 1,
    createdAt: DateTime.utc(2025, 1, 1),
    isNft: isNft,
    nftMintAddress: nftMintAddress,
    isPublic: isPublic,
    isActive: isActive,
    isForSale: isForSale,
    price: price,
    currency: currency,
    imageUrl: imageUrl,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('excludes series-only data with no minted proof', () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(_artwork(id: 'art-1'));
    await collectiblesProvider.createNFTSeries(
      artworkId: 'art-1',
      name: 'Series 1',
      description: 'Series 1 Desc',
      creatorAddress: 'wallet-1',
      totalSupply: 10,
      rarity: CollectibleRarity.rare,
      mintPrice: 10,
      imageUrl: '/uploads/series-1.png',
    );

    expect(collectiblesProvider.marketplaceEntries, isEmpty);
  });

  test(
      'excludes bare isNft artwork when there is no mint address or collectible proof',
      () {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(_artwork(id: 'art-2', isNft: true));

    expect(collectiblesProvider.marketplaceEntries, isEmpty);
  });

  test('includes backend-minted artwork with nft mint address', () {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(_artwork(
      id: 'art-3',
      isNft: true,
      nftMintAddress: 'mint-3',
      price: 25,
      currency: 'KUB8',
      imageUrl: '/uploads/art-3.png',
    ));

    final entries = collectiblesProvider.marketplaceEntries;
    expect(entries, hasLength(1));
    expect(entries.single.artwork.id, 'art-3');
    expect(entries.single.hasMintedProof, isTrue);
    expect(entries.single.coverUrl, contains('/uploads/art-3.png'));
  });

  test(
      'includes locally minted artwork with collectible proof and excludes orphan series',
      () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(
      _artwork(id: 'art-4', imageUrl: '/uploads/art-4-cover.png'),
    );

    final validSeries = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-4',
      name: 'Series 4',
      description: 'Series 4 Desc',
      creatorAddress: 'wallet-4',
      totalSupply: 20,
      rarity: CollectibleRarity.legendary,
      mintPrice: 40,
      imageUrl: '/uploads/series-4.png',
    );
    await collectiblesProvider.createNFTSeries(
      artworkId: 'missing-artwork',
      name: 'Orphan Series',
      description: 'Orphan Desc',
      creatorAddress: 'wallet-ghost',
      totalSupply: 20,
      rarity: CollectibleRarity.rare,
      mintPrice: 5,
      imageUrl: '/uploads/orphan.png',
    );

    await collectiblesProvider.mintCollectible(
      seriesId: validSeries.id,
      ownerAddress: 'wallet-collector',
      transactionHash: 'tx-4',
    );

    final entries = collectiblesProvider.marketplaceEntries;
    expect(entries, hasLength(1));
    expect(entries.single.artwork.id, 'art-4');
    expect(entries.single.coverUrl, contains('/uploads/art-4-cover.png'));
  });

  test(
      'value precedence is listing over artwork listing over last sale over mint',
      () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(_artwork(
      id: 'art-5',
      price: 30,
      currency: 'KUB8',
      isForSale: true,
    ));

    final series = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-5',
      name: 'Series 5',
      description: 'Series 5 Desc',
      creatorAddress: 'wallet-5',
      totalSupply: 10,
      rarity: CollectibleRarity.mythic,
      mintPrice: 12,
    );

    final soldCollectible = await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-a',
      transactionHash: 'tx-5a',
    );
    await collectiblesProvider.purchaseCollectible(
      collectibleId: soldCollectible.id,
      buyerAddress: 'wallet-b',
      salePrice: 18,
      transactionHash: 'tx-5b',
    );

    final listedCollectible = await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-c',
      transactionHash: 'tx-5c',
    );
    await collectiblesProvider.listCollectibleForSale(
      collectibleId: listedCollectible.id,
      price: '55',
    );

    final entry = collectiblesProvider.marketplaceEntries.single;
    expect(entry.displayValue?.source, MarketplaceValueSource.listing);
    expect(entry.displayValue?.amount, 55);
    expect(entry.displayValue?.currency, 'KUB8');
  });

  test(
      'collectible display value prefers the token listing over series-level values',
      () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(_artwork(
      id: 'art-6',
      price: 30,
      currency: 'KUB8',
      isForSale: true,
    ));

    final series = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-6',
      name: 'Series 6',
      description: 'Series 6 Desc',
      creatorAddress: 'wallet-6',
      totalSupply: 10,
      rarity: CollectibleRarity.rare,
      mintPrice: 12,
    );

    final firstCollectible = await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-a',
      transactionHash: 'tx-6a',
    );
    await collectiblesProvider.listCollectibleForSale(
      collectibleId: firstCollectible.id,
      price: '55',
    );

    final secondCollectible = await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-b',
      transactionHash: 'tx-6b',
    );
    await collectiblesProvider.listCollectibleForSale(
      collectibleId: secondCollectible.id,
      price: '75',
    );

    final firstValue =
        collectiblesProvider.getDisplayValueForCollectible(firstCollectible);
    final secondValue =
        collectiblesProvider.getDisplayValueForCollectible(secondCollectible);

    expect(firstValue?.source, MarketplaceValueSource.listing);
    expect(firstValue?.amount, 55);
    expect(secondValue?.source, MarketplaceValueSource.listing);
    expect(secondValue?.amount, 75);
  });

  test('cover fallback stays on the linked artwork entry', () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider
      ..addOrUpdateArtwork(_artwork(id: 'art-a'))
      ..addOrUpdateArtwork(_artwork(id: 'art-b', imageUrl: '/uploads/b.png'));

    final series = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-a',
      name: 'Series A',
      description: 'Series A Desc',
      creatorAddress: 'wallet-a',
      totalSupply: 5,
      rarity: CollectibleRarity.rare,
      mintPrice: 7,
      imageUrl: '/uploads/a-series.png',
    );
    await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-a',
      transactionHash: 'tx-a',
    );

    final entry = collectiblesProvider.marketplaceEntries.single;
    expect(entry.artwork.id, 'art-a');
    expect(entry.coverUrl, contains('/uploads/a-series.png'));
    expect(entry.coverUrl, isNot(contains('/uploads/b.png')));
  });

  test('keeps multiple minted series for the same artwork visible', () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    artworkProvider.addOrUpdateArtwork(
      _artwork(id: 'art-multi', imageUrl: '/uploads/art-multi.png'),
    );

    final firstSeries = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-multi',
      name: 'Series Alpha',
      description: 'First drop',
      creatorAddress: 'wallet-multi',
      totalSupply: 5,
      rarity: CollectibleRarity.rare,
      mintPrice: 10,
      imageUrl: '/uploads/alpha.png',
    );
    final secondSeries = await collectiblesProvider.createNFTSeries(
      artworkId: 'art-multi',
      name: 'Series Beta',
      description: 'Second drop',
      creatorAddress: 'wallet-multi',
      totalSupply: 5,
      rarity: CollectibleRarity.legendary,
      mintPrice: 20,
      imageUrl: '/uploads/beta.png',
    );

    await collectiblesProvider.mintCollectible(
      seriesId: firstSeries.id,
      ownerAddress: 'wallet-owner-a',
      transactionHash: 'tx-alpha',
    );
    await collectiblesProvider.mintCollectible(
      seriesId: secondSeries.id,
      ownerAddress: 'wallet-owner-b',
      transactionHash: 'tx-beta',
    );

    final entries = collectiblesProvider.marketplaceEntries;
    expect(entries, hasLength(2));
    expect(
        entries.map((entry) => entry.id),
        containsAll(<String>[
          firstSeries.id,
          secondSeries.id,
        ]));
  });

  test('builds owned collectible entries even when artwork metadata is absent',
      () async {
    final artworkProvider = ArtworkProvider();
    final collectiblesProvider = CollectiblesProvider()
      ..bindArtworkProvider(artworkProvider);

    final series = await collectiblesProvider.createNFTSeries(
      artworkId: 'missing-artwork',
      name: 'Wallet Only Series',
      description: 'Owned token without loaded artwork metadata.',
      creatorAddress: 'wallet-owner',
      totalSupply: 3,
      rarity: CollectibleRarity.rare,
      mintPrice: 9,
      imageUrl: '/uploads/wallet-only.png',
    );
    final collectible = await collectiblesProvider.mintCollectible(
      seriesId: series.id,
      ownerAddress: 'wallet-owner',
      transactionHash: 'tx-wallet-only',
    );

    final entry =
        collectiblesProvider.getMarketplaceEntryForCollectible(collectible);
    expect(entry, isNotNull);
    expect(entry!.artwork.id, 'missing-artwork');
    expect(entry.title, 'Wallet Only Series');
    expect(entry.coverUrl, contains('/uploads/wallet-only.png'));
  });
}
