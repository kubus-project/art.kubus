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
  for (final entry in <ShareDeepLinkTarget, String>{
    const ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1'): '/a/a1',
    const ShareDeepLinkTarget(type: ShareEntityType.profile, id: 'u1'): '/u/u1',
    const ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1'): '/m/m1',
  }.entries) {
    testWidgets(
      'outside-shell ${entry.key.type.name} replay keeps canonical route '
      'identity',
      (tester) async {
        final observer = _RecordingNavigatorObserver();
        late BuildContext outsideShellContext;

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
        await ShareDeepLinkNavigation.open(outsideShellContext, entry.key);

        expect(observer.pushedNames, isNotEmpty);
        expect(observer.pushedNames.last, entry.value);
        expect(observer.pushedNames, isNot(contains('/main')));
      },
    );
  }
}
