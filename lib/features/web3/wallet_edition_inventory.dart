import '../../models/collectible.dart';
import '../../providers/collectibles_provider.dart';

class WalletEditionInventory {
  const WalletEditionInventory._();

  static List<Collectible> resolve({
    required CollectiblesProvider collectiblesProvider,
    required String walletAddress,
  }) {
    final seriesById = <String, CollectibleSeries>{
      for (final series in collectiblesProvider.allSeries) series.id: series,
    };
    return collectiblesProvider
        .getCollectiblesByOwner(walletAddress)
        .where(
          (item) => seriesById[item.seriesId]?.type == CollectibleType.nft,
        )
        .toList(growable: false);
  }
}
