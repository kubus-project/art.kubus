import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:art_kubus/models/stats/stats_models.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/stats_api_service.dart';

/// Profile API that is never reached by these tests: refreshStats with an
/// explicit wallet only touches the stats service.
class _UnusedProfileApi implements ProfileBackendApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stats service whose snapshots are released by the test, one request at a
/// time, so a response can land after sign-out or an account switch.
class _CompleterStatsApi extends StatsApiService {
  _CompleterStatsApi() : super(api: null);

  final List<({String entityId, Completer<StatsSnapshot> completer})> requests =
      [];

  @override
  Future<StatsSnapshot> fetchSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) {
    final completer = Completer<StatsSnapshot>();
    requests.add((entityId: entityId, completer: completer));
    return completer.future;
  }
}

StatsSnapshot _snapshot(String entityId, Map<String, int> counters) {
  return StatsSnapshot(
    entityType: 'user',
    entityId: entityId,
    scope: 'public',
    metrics: counters.keys.toList(growable: false),
    counters: counters,
    generatedAt: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stats response for account A is dropped after sign-out', () async {
    final stats = _CompleterStatsApi();
    final provider = ProfileProvider(
      apiService: _UnusedProfileApi(),
      statsApi: stats,
    );

    final pending = provider.refreshStats(walletAddress: 'walletA');
    await Future<void>.delayed(Duration.zero);
    expect(stats.requests.single.entityId, 'walletA');

    provider.signOut();
    stats.requests.single.completer
        .complete(_snapshot('walletA', {'followers': 99, 'following': 7}));
    await pending;

    expect(provider.followersCount, 0);
    expect(provider.followingCount, 0);
    expect(provider.currentUser, isNull);
  });

  test('stats response for account A is dropped after switching to B',
      () async {
    final stats = _CompleterStatsApi();
    final provider = ProfileProvider(
      apiService: _UnusedProfileApi(),
      statsApi: stats,
    );

    final pendingA = provider.refreshStats(walletAddress: 'walletA');
    await Future<void>.delayed(Duration.zero);

    // Account switch: the profile load epoch moves on before B's stats land.
    provider.signOut();
    final pendingB = provider.refreshStats(walletAddress: 'walletB');
    await Future<void>.delayed(Duration.zero);
    expect(stats.requests.last.entityId, 'walletB');

    stats.requests.first.completer
        .complete(_snapshot('walletA', {'followers': 99}));
    await pendingA;
    expect(provider.followersCount, 0);

    stats.requests.last.completer
        .complete(_snapshot('walletB', {'followers': 5}));
    await pendingB;
    expect(provider.followersCount, 5);
  });

  test('stats response applies when no account boundary intervened', () async {
    final stats = _CompleterStatsApi();
    final provider = ProfileProvider(
      apiService: _UnusedProfileApi(),
      statsApi: stats,
    );

    final pending = provider.refreshStats(walletAddress: 'walletA');
    await Future<void>.delayed(Duration.zero);
    stats.requests.single.completer
        .complete(_snapshot('walletA', {'followers': 12, 'following': 3}));
    await pending;

    expect(provider.followersCount, 12);
    expect(provider.followingCount, 3);
  });
}
