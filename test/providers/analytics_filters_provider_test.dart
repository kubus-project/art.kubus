import 'package:art_kubus/providers/analytics_filters_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AnalyticsFiltersProvider defaults to 30d', () {
    final provider = AnalyticsFiltersProvider();
    expect(provider.artistTimeframe, '30d');
    expect(provider.institutionTimeframe, '30d');
  });

  test('AnalyticsFiltersProvider normalizes and validates timeframes', () {
    final provider = AnalyticsFiltersProvider();

    provider.setArtistTimeframe(' 7D ');
    expect(provider.artistTimeframe, '7d');

    provider.setInstitutionTimeframe('1Y');
    expect(provider.institutionTimeframe, '1y');

    provider.setArtistTimeframe('invalid');
    expect(provider.artistTimeframe, '7d');
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
  });
}

