import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/recent_activity.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/activity_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}


void main() {
  testWidgets(
    'ActivityNavigation.open uses DesktopShellScope when available (no fullscreen push)',
    (tester) async {
      final observer = _RecordingNavigatorObserver();

      final pushedScreens = <Widget>[];
      void pushScreen(Widget screen) => pushedScreens.add(screen);

      late BuildContext buttonContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: DesktopShellScope(
            pushScreen: pushScreen,
            popScreen: () {},
            navigateToRoute: (_) {},
            openNotifications: () {},
            openFunctionsPanel: (_, {Widget? content}) {},
            setFunctionsPanelContent: (_) {},
            closeFunctionsPanel: () {},
            canPop: true,
            child: Builder(
              builder: (context) {
                buttonContext = context;
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final activity = RecentActivity(
                          id: 'a1',
                          title: 'New comment',
                          description: 'Someone commented',
                          timestamp: DateTime.now(),
                          category: ActivityCategory.comment,
                          isRead: false,
                          metadata: const <String, dynamic>{
                            'postId': 'post_123',
                          },
                        );

                        await ActivityNavigation.open(context, activity);
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // MaterialApp pushes an initial route; record baseline pushes so we can
      // assert we do not add a fullscreen push when DesktopShellScope is present.
      final baselinePushes = observer.pushCount;

      expect(pushedScreens, isEmpty);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // DesktopShellScope should have been used instead of a Navigator push.
      expect(pushedScreens.length, 1);
      expect(observer.pushCount, baselinePushes);

      // Also sanity check we were operating from a context that can see the scope.
      expect(DesktopShellScope.of(buttonContext), isNotNull);
    },
  );
}
