import 'package:art_kubus/models/stats/stats_models.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// A WalletProvider that already holds [address]: the wallet a device keeps
/// after a forced sign-out, and the wallet of a signed-in wallet account.
class HeldWallet extends WalletProvider {
  HeldWallet(this.address) : super(deferInit: true);

  final String address;

  @override
  String? get currentWalletAddress => address;

  @override
  bool get hasWalletIdentity => true;
}

/// Wallet and Web3 providers for [address], to pass as extraProviders.
List<SingleChildWidget> heldWalletProviders(String address) {
  final wallet = HeldWallet(address);
  final web3 = Web3Provider()..bindWalletProvider(wallet);
  return <SingleChildWidget>[
    ChangeNotifierProvider<WalletProvider>.value(value: wallet),
    ChangeNotifierProvider<Web3Provider>.value(value: web3),
  ];
}

/// Records which entities a screen asks stats for, so a test can prove a held
/// wallet is not queried for "Your stats" without a session.
class RecordingStatsProvider extends StatsProvider {
  final List<String> requestedEntityIds = <String>[];

  @override
  Future<StatsSnapshot?> ensureSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) async {
    requestedEntityIds.add(entityId);
    return null;
  }

  @override
  Future<StatsSeries?> ensureSeries({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) async {
    requestedEntityIds.add(entityId);
    return null;
  }
}
