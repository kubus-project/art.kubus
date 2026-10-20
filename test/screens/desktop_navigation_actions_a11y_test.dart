import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_navigation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The desktop rail's bell and gear were icon-only controls with no accessible
/// name, in both the expanded and the collapsed rail. Each is now a named
/// button with a hover tooltip, and reports whether its screen is the selected
/// one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRail(
    WidgetTester tester, {
    required bool expanded,
    Locale locale = const Locale('en'),
    int messageUnreadCount = 0,
    List<DesktopNavItem> items = const <DesktopNavItem>[],
    bool notificationsSelected = false,
    VoidCallback? onNotifications,
    VoidCallback? onSettings,
  }) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AnimationController(
      vsync: tester,
      duration: Duration.zero,
      value: expanded ? 1 : 0,
    );
    addTearDown(controller.dispose);
    final notificationProvider = NotificationProvider()
      ..setAuthenticatedSessionForTesting(wallet: 'test-wallet')
      ..handleUnreadSummaryForTesting(<String, dynamic>{
        'notificationUnreadCount': 0,
        'messageUnreadCount': messageUnreadCount,
        'totalUnreadCount': messageUnreadCount,
        'generatedAt': DateTime.utc(2026).toIso8601String(),
      });
    addTearDown(notificationProvider.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationProvider>.value(
            value: notificationProvider,
          ),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => CollabProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerLeft,
              child: DesktopNavigation(
                items: items,
                activeAccent: Colors.teal,
                selectedIndex: 0,
                onItemSelected: (_) {},
                isExpanded: expanded,
                expandAnimation: controller,
                onToggleExpand: () {},
                onProfileTap: () {},
                onSettingsTap: onSettings ?? () {},
                onNotificationsTap: onNotifications ?? () {},
                onWalletTap: () {},
                isProfileSelected: false,
                isNotificationsSelected: notificationsSelected,
                isSettingsSelected: false,
                isCollabInvitesSelected: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final expanded in <bool>[true, false]) {
    for (final locale in const [Locale('en'), Locale('sl')]) {
      testWidgets(
          '${expanded ? 'expanded' : 'collapsed'} rail ${locale.languageCode}: '
          'bell and gear are named buttons', (tester) async {
        final semantics = tester.ensureSemantics();
        var bell = 0;
        var gear = 0;
        await pumpRail(
          tester,
          expanded: expanded,
          locale: locale,
          onNotifications: () => bell++,
          onSettings: () => gear++,
        );
        final l10n =
            AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

        final bellNode = tester.getSemantics(
          find.bySemanticsLabel(l10n.commonNotifications),
        );
        final gearNode = tester.getSemantics(
          find.bySemanticsLabel(l10n.navigationScreenSettings),
        );
        expect(bellNode.flagsCollection.isButton, isTrue);
        expect(gearNode.flagsCollection.isButton, isTrue);

        await tester.tap(find.bySemanticsLabel(l10n.commonNotifications));
        await tester.tap(find.bySemanticsLabel(l10n.navigationScreenSettings));
        expect((bell, gear), (1, 1));
        semantics.dispose();
      });
    }
  }

  testWidgets('the selected destination is reported as selected',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRail(tester, expanded: true, notificationsSelected: true);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    final node = tester.getSemantics(
      find.bySemanticsLabel(l10n.commonNotifications),
    );
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('messages badge shows authoritative unread count and semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRail(
      tester,
      expanded: true,
      messageUnreadCount: 2,
      items: const <DesktopNavItem>[
        DesktopNavItem(
          icon: Icons.mail_outline,
          activeIcon: Icons.mail,
          labelKey: DesktopNavLabelKey.messages,
          route: '/messages',
        ),
      ],
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

    expect(find.text('2'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              '${l10n.desktopShellNavMessages}, '
              '${l10n.desktopMessagesUnreadSemantics(2)}',
            ),
          )
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('messages badge stays hidden when authoritative count is zero',
      (tester) async {
    await pumpRail(
      tester,
      expanded: true,
      items: const <DesktopNavItem>[
        DesktopNavItem(
          icon: Icons.mail_outline,
          activeIcon: Icons.mail,
          labelKey: DesktopNavLabelKey.messages,
          route: '/messages',
        ),
      ],
    );

    expect(find.text('0'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(l10n.desktopShellNavMessages),
          )
          .flagsCollection
          .isButton,
      isTrue,
    );
  });

  testWidgets('hovering the rail icons shows a tooltip with the same name',
      (tester) async {
    await pumpRail(tester, expanded: false);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    final gear = find.byIcon(Icons.settings_outlined);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(gear));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(gear));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(l10n.navigationScreenSettings), findsWidgets);
    await mouse.removePointer();
  });
}
