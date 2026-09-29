import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/detail/profile_utility_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_screen_harness.dart';

/// Wave 5A: pushed inside the desktop shell, the owner profile has ONE
/// header row (Back, title, utilities); there is no second action-only band.
void main() {
  Finder utilityButtons() => find.descendant(
        of: find.byType(ProfileUtilityActions),
        matching: find.byType(IconButton),
      );

  for (final width in <double>[900, 1024, 1280, 1440, 1920]) {
    testWidgets('in-shell owner profile has one header row @ ${width.toInt()}',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopOwnerInShell,
        size: Size(width, 900),
      );

      expect(find.byType(DesktopSubScreen), findsOneWidget);
      expect(find.byType(KubusScreenHeaderBar), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget,
          reason: 'one visible Profile title');
      expect(find.byIcon(Icons.arrow_back), findsOneWidget,
          reason: 'one Back control');

      // One utility toolbar, and it lives inside the header bar.
      expect(find.byType(ProfileUtilityActions), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KubusScreenHeaderBar),
          matching: find.byType(ProfileUtilityActions),
        ),
        findsOneWidget,
        reason: 'actions share the header ownership layer',
      );

      // Same row: the actions and the title overlap vertically.
      final title = tester.getRect(find.text('Profile'));
      final actions = tester.getRect(find.byType(ProfileUtilityActions));
      expect(actions.top, lessThan(title.bottom));
      expect(actions.bottom, greaterThan(title.top));
      expect(actions.left, greaterThan(title.right));

      final header = tester.getRect(find.byType(KubusScreenHeaderBar));
      expect(actions.bottom, lessThanOrEqualTo(header.bottom));
      expectNoUnexpectedRenderErrors();
    });
  }

  testWidgets('utility actions: 44 px targets, flat, analytics feature-gated',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopOwnerInShell,
      size: const Size(1440, 900),
    );
    final expected = AppConfig.isFeatureEnabled('analytics') ? 4 : 3;
    expect(utilityButtons(), findsNWidgets(expected));
    expect(
      find.descendant(
        of: find.byType(ProfileUtilityActions),
        matching: find.byIcon(Icons.analytics_outlined),
      ),
      AppConfig.isFeatureEnabled('analytics') ? findsOneWidget : findsNothing,
    );
    for (final element in utilityButtons().evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
    // No glass: utility chrome is a plain Material icon button.
    expect(
      find.descendant(
        of: find.byType(ProfileUtilityActions),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('keyboard focus reaches the utilities and draws the teal ring',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopOwnerInShell,
      size: const Size(1440, 900),
    );
    final roles = KubusColorRoles.of(
      tester.element(find.byType(ProfileUtilityActions)),
    );
    bool focusInActions() {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      return find
          .descendant(
            of: find.byType(ProfileUtilityActions),
            matching: find.byElementPredicate((e) => e == focused),
          )
          .evaluate()
          .isNotEmpty;
    }

    for (var i = 0; i < 12 && !focusInActions(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusInActions(), isTrue, reason: 'Tab reaches a utility action');

    final focusedButton = utilityButtons().evaluate().firstWhere((element) {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          (focused as Element).debugGetDiagnosticChain().contains(element);
    });
    final material = find
        .descendant(
          of: find.byWidget(focusedButton.widget),
          matching: find.byType(Material),
        )
        .first;
    final shape = tester.widget<Material>(material).shape! as OutlinedBorder;
    expect(shape.side.color, roles.focus);
  });

  testWidgets('standalone owner profile keeps its own title and utilities',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopOwner,
      size: const Size(1440, 900),
    );
    expect(find.byType(DesktopSubScreen), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byType(ProfileUtilityActions), findsOneWidget);
    final title = tester.getRect(find.text('Profile'));
    final actions = tester.getRect(find.byType(ProfileUtilityActions));
    expect(actions.top, lessThan(title.bottom + 24),
        reason: 'title and utilities share the standalone header row');
  });
}
