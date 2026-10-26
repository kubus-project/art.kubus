// Browser regression for the backdrop host. Keep this library's file name off the
// `host.dart` suffix: flutter_tools serves any module URL containing `host.dart.js`
// from the test harness bundle (flutter_web_platform.dart, _handleStaticArtifact), so
// a compiled library named `*host.dart` never loads and the suite stalls at "loading".
@TestOn('browser')
library;

import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_mount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('backdrop host mounts in a browser test', (tester) async {
    final controller = KubusMapBackdropHostController();
    await tester.pumpWidget(
      MaterialApp(
        home: KubusMapPlatformBackdropHost(
          controller: controller,
          enabled: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(KubusMapPlatformBackdropHost), findsOneWidget);
  });
}
