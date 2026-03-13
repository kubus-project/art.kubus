import 'package:art_kubus/providers/analytics_filters_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AnalyticsFiltersProvider defaults to 30d', () {
    final provider = AnalyticsFiltersProvider();
    expect(provider.artistTimeframe, '30d');
    expect(provider.institutionTimeframe, '30d');
    expect(
      provider.timeframeFor(AnalyticsFiltersProvider.homeContextKey),
      '30d',
    );
    expect(
      provider.metricFor(AnalyticsFiltersProvider.homeContextKey),
      'engagement',
    );
    expect(
      provider.hasExplicitMetricFor(AnalyticsFiltersProvider.homeContextKey),
      isFalse,
    );
  });

  test('AnalyticsFiltersProvider normalizes and validates timeframes', () {
    final provider = AnalyticsFiltersProvider();

    provider.setArtistTimeframe(' 7D ');
    expect(provider.artistTimeframe, '7d');

    provider.setInstitutionTimeframe('1Y');
    expect(provider.institutionTimeframe, '1y');

    provider.setTimeframeFor(AnalyticsFiltersProvider.profileContextKey, '90D');
    expect(
      provider.timeframeFor(AnalyticsFiltersProvider.profileContextKey),
      '90d',
    );

    provider.setTimeframeFor(AnalyticsFiltersProvider.homeContextKey, '24H');
    expect(
      provider.timeframeFor(AnalyticsFiltersProvider.homeContextKey),
      '24h',
    );

    provider.setArtistTimeframe('invalid');
    expect(provider.artistTimeframe, '7d');
  });

  test('AnalyticsFiltersProvider stores per-context metrics', () {
    final provider = AnalyticsFiltersProvider();

    provider.setMetricFor(
      AnalyticsFiltersProvider.profileContextKey,
      'likesReceived',
      allowedMetrics: const <String>['viewsReceived', 'likesReceived'],
    );
    expect(
      provider.metricFor(AnalyticsFiltersProvider.profileContextKey),
      'likesReceived',
    );
    expect(
      provider.hasExplicitMetricFor(AnalyticsFiltersProvider.profileContextKey),
      isTrue,
    );

    provider.setMetricFor(
      AnalyticsFiltersProvider.profileContextKey,
      'invalid',
      allowedMetrics: const <String>['viewsReceived', 'likesReceived'],
    );
    expect(
      provider.metricFor(AnalyticsFiltersProvider.profileContextKey),
      'likesReceived',
    );
  });

  test('AnalyticsFiltersProvider marks explicit selection for default metric', () {
    final provider = AnalyticsFiltersProvider();

    provider.setMetricFor(
      AnalyticsFiltersProvider.homeContextKey,
      'engagement',
      allowedMetrics: const <String>[
        'engagement',
        'viewsReceived',
        'followers',
      ],
    );

    expect(
      provider.hasExplicitMetricFor(AnalyticsFiltersProvider.homeContextKey),
      isTrue,
    );
    expect(
      provider.metricFor(AnalyticsFiltersProvider.homeContextKey),
      'engagement',
    );
  });

  test('AnalyticsFiltersProvider notifies only on changes', () {
    final provider = AnalyticsFiltersProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.setArtistTimeframe('30d');
    expect(notifications, 0);

    provider.setArtistTimeframe('7d');
    expect(notifications, 1);

    provider.setArtistTimeframe('7d');
    expect(notifications, 1);

    provider.setMetricFor(
      AnalyticsFiltersProvider.communityContextKey,
      'likesReceived',
      allowedMetrics: const <String>['posts', 'likesReceived'],
    );
    expect(notifications, 2);

    provider.setMetricFor(
      AnalyticsFiltersProvider.communityContextKey,
      'likesReceived',
      allowedMetrics: const <String>['posts', 'likesReceived'],
    );
    expect(notifications, 2);

    provider.setMetricFor(
      AnalyticsFiltersProvider.homeContextKey,
      'engagement',
      allowedMetrics: const <String>['engagement', 'followers'],
    );
    expect(notifications, 3);

    provider.setMetricFor(
      AnalyticsFiltersProvider.homeContextKey,
      'engagement',
      allowedMetrics: const <String>['engagement', 'followers'],
    );
    expect(notifications, 3);
  });
}
