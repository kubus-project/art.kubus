import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'enableAnalytics': false,
    });
  });

  test('analytics preference updates StatsProvider without reconstruction',
      () async {
    final config = ConfigProvider();
    await config.initialize();
    final stats = StatsProvider()..bindConfigProvider(config);
    var configNotifications = 0;
    var statsNotifications = 0;
    config.addListener(() => configNotifications++);
    stats.addListener(() => statsNotifications++);

    expect(config.enableAnalytics, isFalse);
    expect(stats.analyticsPreferenceEnabled, isFalse);

    await config.setEnableAnalytics(true);

    expect(config.enableAnalytics, isTrue);
    expect(stats.analyticsPreferenceEnabled, isTrue);
    expect(stats.analyticsEnabled, isTrue);
    expect(configNotifications, 1);
    await Future<void>.delayed(Duration.zero);
    expect(statsNotifications, greaterThanOrEqualTo(1));
    expect(
      (await SharedPreferences.getInstance()).getBool('enableAnalytics'),
      isTrue,
    );

    await config.setEnableAnalytics(false);
    expect(stats.analyticsPreferenceEnabled, isFalse);
    expect(stats.analyticsEnabled, isFalse);
  });

  test('analytics preference persists and restores in a new provider',
      () async {
    final original = ConfigProvider();
    await original.initialize();
    await original.setEnableAnalytics(true);

    final restored = ConfigProvider();
    await restored.initialize();

    expect(restored.enableAnalytics, isTrue);
  });

  test('legacy analytics preference is removed so reset stays durable',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'analytics': false,
    });
    final config = ConfigProvider();
    await config.initialize();

    expect(config.enableAnalytics, isFalse);
    expect((await SharedPreferences.getInstance()).containsKey('analytics'),
        isFalse);

    await config.resetToDefaults();
    final restored = ConfigProvider();
    await restored.initialize();

    expect(restored.enableAnalytics, isTrue);
  });
}
