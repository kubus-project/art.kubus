import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/share_deep_link_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('outside-shell artwork replay keeps canonical route identity',
      (tester) async {
    final observer = _RecordingNavigatorObserver();
    late BuildContext outsideShellContext;
    const target =
        ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1');

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            outsideShellContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    observer.pushedNames.clear();
    await ShareDeepLinkNavigation.open(outsideShellContext, target);

    expect(observer.pushedNames, isNotEmpty);
    expect(observer.pushedNames.last, '/a/a1');
    expect(observer.pushedNames, isNot(contains('/main')));
  });
}
