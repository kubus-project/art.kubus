import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/user_profile_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('openInDesktopShell renders content inside DesktopSubScreen',
      (tester) async {
    Widget? currentScreen;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return DesktopShellScope(
              pushScreen: (screen) => setState(() => currentScreen = screen),
              popScreen: () => setState(() => currentScreen = null),
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: currentScreen != null,
              child: Scaffold(
                body: currentScreen ??
                    Builder(
                      builder: (innerContext) => Center(
                        child: ElevatedButton(
                          onPressed: () {
                            openInDesktopShell(
                              innerContext,
                              title: 'Profile',
                              child: const Text('Inner content'),
                            );
                          },
                          child: const Text('Open'),
                        ),
                      ),
                    ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Inner content'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('popDesktopShellAware prefers shell stack over navigator',
      (tester) async {
    var shellPopCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShellScope(
          pushScreen: (_) {},
          popScreen: () => shellPopCount += 1,
          navigateToRoute: (_) {},
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: true,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => popDesktopShellAware(context),
                  child: const Text('Back'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(shellPopCount, 1);
  });

  testWidgets('UserProfileNavigation opens desktop profiles inside shell',
      (tester) async {
    Widget? pushedScreen;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: DesktopShellScope(
            pushScreen: (screen) => pushedScreen = screen,
            popScreen: () {},
            navigateToRoute: (_) {},
            openNotifications: () {},
            openFunctionsPanel: (_, {content}) {},
            setFunctionsPanelContent: (_) {},
            closeFunctionsPanel: () {},
            canPop: false,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      UserProfileNavigation.open(
                        context,
                        userId: 'wallet_123',
                      );
                    },
                    child: const Text('Open profile'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pump();

    expect(pushedScreen, isA<desktop_profile.UserProfileScreen>());
    expect(pushedScreen, isNot(isA<DesktopSubScreen>()));
  });

  testWidgets(
      'UserProfileNavigation keeps community overlay presentation inside modal profiles',
      (tester) async {
    Widget? pushedScreen;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: DesktopShellScope(
              pushScreen: (screen) => pushedScreen = screen,
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: false,
              child: DesktopProfilePresentationScope(
                presentation: DesktopProfilePresentation.communityOverlay,
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () {
                          UserProfileNavigation.open(
                            context,
                            userId: 'wallet_123',
                          );
                        },
                        child: const Text('Open overlay profile'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open overlay profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(pushedScreen, isNull);
    expect(find.byType(desktop_profile.UserProfileScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesktopProfilePresentationScope &&
            widget.presentation ==
                DesktopProfilePresentation.communityOverlay,
      ),
      findsNWidgets(2),
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
