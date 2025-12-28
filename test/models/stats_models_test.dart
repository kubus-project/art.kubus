import 'package:art_kubus/models/stats/stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StatsSnapshot.fromJson parses counters + metrics', () {
    final snapshot = StatsSnapshot.fromJson(<String, dynamic>{
      'entityType': 'user',
      'entityId': 'wallet_test_1',
      'scope': 'public',
      'metrics': ['followers', 'following'],
      'counters': {'followers': 12, 'following': '34'},
      'generatedAt': '2025-01-01T00:00:00.000Z',
    });

    expect(snapshot.entityType, 'user');
    expect(snapshot.entityId, 'wallet_test_1');
    expect(snapshot.scope, 'public');
    expect(snapshot.metrics, containsAll(<String>['followers', 'following']));
    expect(snapshot.counters['followers'], 12);
    expect(snapshot.counters['following'], 34);
    expect(snapshot.generatedAt, isNotNull);
  });

  test('StatsSeries.fromJson parses grouped points', () {
    final series = StatsSeries.fromJson(<String, dynamic>{
      'entityType': 'user',
      'entityId': 'wallet_test_1',
      'scope': 'private',
      'metric': 'viewsReceived',
      'bucket': 'day',
      'from': '2025-01-01T00:00:00.000Z',
      'to': '2025-01-08T00:00:00.000Z',
      'groupBy': 'targetType',
      'series': [
        {'t': '2025-01-01T00:00:00.000Z', 'v': 2, 'g': 'artwork'},
        {'t': '2025-01-02T00:00:00.000Z', 'v': '3', 'g': 'event'},
      ],
      'generatedAt': '2025-01-08T00:00:00.000Z',
    });

    expect(series.entityType, 'user');
    expect(series.entityId, 'wallet_test_1');
    expect(series.scope, 'private');
    expect(series.metric, 'viewsReceived');
    expect(series.bucket, 'day');
    expect(series.groupBy, 'targetType');
    expect(series.series.length, 2);
    expect(series.series.first.v, 2);
    expect(series.series.first.g, 'artwork');
    expect(series.series.last.v, 3);
    expect(series.series.last.g, 'event');
  });
}

