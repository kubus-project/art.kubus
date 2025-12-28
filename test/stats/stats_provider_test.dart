import 'dart:async';

import 'package:art_kubus/models/stats/stats_models.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/services/stats_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStatsApiService extends StatsApiService {
  int snapshotCalls = 0;
  Completer<StatsSnapshot>? snapshotCompleter;

  _FakeStatsApiService();

  @override
  Future<StatsSnapshot> fetchSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) {
    snapshotCalls += 1;
    final completer = snapshotCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(
      StatsSnapshot(
        entityType: entityType,
        entityId: entityId,
        scope: scope,
        metrics: metrics,
        counters: const <String, int>{},
        generatedAt: DateTime.utc(2025, 1, 1),
      ),
    );
  }
}

void main() {
  test('StatsProvider dedupes in-flight snapshot fetches', () async {
    final api = _FakeStatsApiService();
    api.snapshotCompleter = Completer<StatsSnapshot>();

    final provider = StatsProvider(api: api);
    const params = (
      entityType: 'user',
      entityId: 'wallet_test_1',
      metrics: <String>['followers'],
      scope: 'public',
    );

    final future1 = provider.ensureSnapshot(
      entityType: params.entityType,
      entityId: params.entityId,
      metrics: params.metrics,
      scope: params.scope,
    );
    final future2 = provider.ensureSnapshot(
      entityType: params.entityType,
      entityId: params.entityId,
      metrics: params.metrics,
      scope: params.scope,
    );

    expect(api.snapshotCalls, 1);

    final resolved = StatsSnapshot(
      entityType: params.entityType,
      entityId: params.entityId,
      scope: params.scope,
      metrics: params.metrics,
      counters: const {'followers': 1},
      generatedAt: DateTime.utc(2025, 1, 1),
    );
    api.snapshotCompleter!.complete(resolved);

    final s1 = await future1;
    final s2 = await future2;

    expect(s1, isNotNull);
    expect(s2, isNotNull);
    expect(s1!.counters['followers'], 1);
    expect(s2!.counters['followers'], 1);
    expect(api.snapshotCalls, 1);
  });

  test('StatsProvider returns cached snapshot within TTL', () async {
    final api = _FakeStatsApiService();
    final provider = StatsProvider(api: api);

    final first = await provider.ensureSnapshot(
      entityType: 'user',
      entityId: 'wallet_test_1',
      metrics: const ['followers'],
      scope: 'public',
    );
    expect(first, isNotNull);
    expect(api.snapshotCalls, 1);

    final second = await provider.ensureSnapshot(
      entityType: 'user',
      entityId: 'wallet_test_1',
      metrics: const ['followers'],
      scope: 'public',
    );
    expect(second, isNotNull);
    expect(api.snapshotCalls, 1);
  });
}

