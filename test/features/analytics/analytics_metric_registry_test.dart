import 'package:art_kubus/features/analytics/analytics_entity_registry.dart';
import 'package:art_kubus/features/analytics/analytics_metric_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry exposes canonical user metrics with grouping metadata', () {
    final viewsReceived = AnalyticsMetricRegistry.requireById('viewsReceived');

    expect(viewsReceived.label, 'Views received');
    expect(viewsReceived.supportsEntity(AnalyticsEntityType.user), isTrue);
    expect(viewsReceived.supportsScope(AnalyticsScope.public), isTrue);
    expect(viewsReceived.supportsScope(AnalyticsScope.private), isTrue);
    expect(
      viewsReceived.supportedGroupBys,
      containsAll(<AnalyticsGroupBy>[
        AnalyticsGroupBy.source,
        AnalyticsGroupBy.targetType,
      ]),
    );
  });

  test('snapshot-only metrics do not advertise series support', () {
    expect(AnalyticsMetricRegistry.requireById('comments').seriesSupported,
        isFalse);
    expect(
      AnalyticsMetricRegistry.requireById('arEnabledArtworks').seriesSupported,
      isFalse,
    );
    expect(
      AnalyticsMetricRegistry.requireById('exhibitionArtworks').seriesSupported,
      isFalse,
    );
  });

  test('series support follows backend entity and scope contract', () {
    expect(
      AnalyticsMetricRegistry.supportsSeriesFor(
        metric: AnalyticsMetricRegistry.requireById('views'),
        entityType: AnalyticsEntityType.platform,
        scope: AnalyticsScope.public,
      ),
      isFalse,
    );
    expect(
      AnalyticsMetricRegistry.supportsSeriesFor(
        metric: AnalyticsMetricRegistry.requireById('views'),
        entityType: AnalyticsEntityType.platform,
        scope: AnalyticsScope.private,
      ),
      isTrue,
    );
    expect(
      AnalyticsMetricRegistry.supportsSeriesFor(
        metric: AnalyticsMetricRegistry.requireById('viewsReceived'),
        entityType: AnalyticsEntityType.user,
        scope: AnalyticsScope.public,
      ),
      isTrue,
    );
    expect(
      AnalyticsMetricRegistry.supportsSeriesFor(
        metric: AnalyticsMetricRegistry.requireById('daoTotalProposals'),
        entityType: AnalyticsEntityType.dao,
        scope: AnalyticsScope.public,
      ),
      isTrue,
    );
    expect(
      AnalyticsMetricRegistry.requireById('daoTotalProposals').defaultGroupBy,
      AnalyticsGroupBy.targetType,
    );
    expect(
      AnalyticsMetricRegistry.requireById('daoTreasuryAmount').seriesSupported,
      isFalse,
    );
  });

  test('private-only metrics are filtered from public profile capabilities',
      () {
    final publicMetrics = AnalyticsMetricRegistry.forEntity(
      AnalyticsEntityType.user,
      includePrivate: false,
    ).map((metric) => metric.id);

    expect(publicMetrics, contains('viewsReceived'));
    expect(publicMetrics, isNot(contains('engagement')));
    expect(publicMetrics, isNot(contains('artworksDiscovered')));
  });

  test('compact formatting remains stable for large analytics counters', () {
    expect(AnalyticsMetricRegistry.formatCompact(999), '999');
    expect(AnalyticsMetricRegistry.formatCompact(1200), '1.2k');
    expect(AnalyticsMetricRegistry.formatCompact(2500000), '2.5m');
  });
}
