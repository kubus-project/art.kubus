import 'package:art_kubus/widgets/map/glass/kubus_map_native_backdrop_channel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('art.kubus/map_native_backdrop');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    KubusMapNativeBackdropChannel.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  KubusMapBackdropRegion region({
    String id = 'panel',
    Rect rect = const Rect.fromLTWH(8, 64, 374, 76),
  }) {
    return KubusMapBackdropRegion(
      id: id,
      rect: rect,
      borderRadius: BorderRadius.circular(16),
      blurSigma: 12,
    );
  }

  test('probeSupport confirms native host on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      return null;
    });

    expect(await KubusMapNativeBackdropChannel.probeSupport(), isTrue);
    expect(KubusMapNativeBackdropChannel.isSupported, isTrue);
  });

  test('non-iOS platforms never report native host support', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await KubusMapNativeBackdropChannel.probeSupport(), isFalse);
    expect(KubusMapNativeBackdropChannel.isSupported, isFalse);
  });

  test('missing native handler resolves to unsupported (fail-safe)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // No mock handler registered => MissingPluginException.
    expect(await KubusMapNativeBackdropChannel.probeSupport(), isFalse);
    expect(KubusMapNativeBackdropChannel.isSupported, isFalse);
  });

  test('syncRegions sends region geometry to the native host', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') return true;
      return null;
    });

    await KubusMapNativeBackdropChannel.probeSupport();
    await KubusMapNativeBackdropChannel.syncRegions(
      enabled: true,
      regions: [region()],
    );

    final sync = calls.singleWhere((c) => c.method == 'syncRegions');
    final args = sync.arguments as Map;
    final regions = args['regions'] as List;
    final payload = regions.single as Map;
    expect(payload['id'], 'panel');
    expect(payload['left'], 8.0);
    expect(payload['top'], 64.0);
    expect(payload['width'], 374.0);
    expect(payload['height'], 76.0);
    expect(payload['cornerRadius'], 16.0);
    expect(payload['blurSigma'], 12.0);
  });

  test('disabled or empty sync clears native regions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'isSupported') return true;
      return null;
    });

    await KubusMapNativeBackdropChannel.probeSupport();
    await KubusMapNativeBackdropChannel.syncRegions(
      enabled: false,
      regions: [region()],
    );
    await KubusMapNativeBackdropChannel.syncRegions(
      enabled: true,
      regions: const [],
    );

    expect(methods.where((m) => m == 'clearRegions').length, 2);
  });

  test('channel failure during sync demotes support', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      throw PlatformException(code: 'boom');
    });

    await KubusMapNativeBackdropChannel.probeSupport();
    expect(KubusMapNativeBackdropChannel.isSupported, isTrue);

    await KubusMapNativeBackdropChannel.syncRegions(
      enabled: true,
      regions: [region()],
    );
    expect(KubusMapNativeBackdropChannel.isSupported, isFalse);
  });
}
