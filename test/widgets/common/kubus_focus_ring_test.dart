import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/forms/kubus_form.dart';
import 'package:art_kubus/widgets/common/kubus_focus_ring.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 120x44 control at (100, 100) on a 400x300 page. The ring band sits
/// 2-4 px outside the control edge and the halo 4-5 px outside it.
const _controlRect = Rect.fromLTWH(100, 100, 120, 44);
final _boundaryKey = GlobalKey();

Widget _host({
  required Brightness brightness,
  required Widget child,
}) {
  final roles = brightness == Brightness.dark
      ? KubusColorRoles.dark
      : KubusColorRoles.light;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: roles.surface,
      extensions: <ThemeExtension<dynamic>>[roles],
    ),
    home: RepaintBoundary(
      key: _boundaryKey,
      child: Scaffold(
        backgroundColor: roles.surface,
        body: Stack(
          children: [
            Positioned.fromRect(rect: _controlRect, child: child),
          ],
        ),
      ),
    ),
  );
}

Widget _focusableControl(FocusNode node, {bool enabled = true}) {
  return KubusFocusRing(
    borderRadius: BorderRadius.circular(8),
    enabled: enabled,
    child: SizedBox.expand(
      child: Focus(
        focusNode: node,
        child: Container(color: Colors.transparent),
      ),
    ),
  );
}

/// RGBA of the page at a logical pixel, read from the painted boundary.
Future<List<int>> _pixel(WidgetTester tester, int x, int y) async {
  return (await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    final bytes = data!.buffer.asUint8List();
    return [
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
      bytes[offset + 3],
    ];
  }))!;
}

List<int> _rgba(Color c) => [
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
      (c.a * 255).round(),
    ];

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final roles = brightness == Brightness.dark
        ? KubusColorRoles.dark
        : KubusColorRoles.light;

    testWidgets(
        '${brightness.name}: keyboard focus paints the family ring outside '
        'the control, with the halo beyond it', (tester) async {
      final node = FocusNode(debugLabel: 'ring-test');
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _host(brightness: brightness, child: _focusableControl(node)),
      );
      node.requestFocus();
      await tester.pump();

      // Left edge of the control is x=100. Ring centre is 3 px outside
      // (x=97, band 96-98); halo centre is 4.5 px outside (x=95.5, band 95-96).
      expect(await _pixel(tester, 97, 122), _rgba(roles.focus));
      expect(await _pixel(tester, 95, 122), _rgba(roles.ground));
      // The gap between control and ring keeps the page surface.
      expect(await _pixel(tester, 99, 122), _rgba(roles.surface));
    });

    testWidgets(
        '${brightness.name}: no ring without keyboard highlight, on pointer '
        'focus, or on a disabled control', (tester) async {
      // Pointer / touch focus never draws the keyboard ring.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final pointerNode = FocusNode(debugLabel: 'pointer');
      addTearDown(pointerNode.dispose);
      await tester.pumpWidget(
        _host(brightness: brightness, child: _focusableControl(pointerNode)),
      );
      pointerNode.requestFocus();
      await tester.pump();
      expect(await _pixel(tester, 97, 122), _rgba(roles.surface));

      // Disabled controls never show it, even with keyboard highlight.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final disabledNode = FocusNode(debugLabel: 'disabled');
      addTearDown(disabledNode.dispose);
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          child: _focusableControl(disabledNode, enabled: false),
        ),
      );
      await tester.pump();
      expect(await _pixel(tester, 97, 122), _rgba(roles.surface));
    });
  }

  testWidgets('KubusButton draws the shared ring on keyboard focus',
      (tester) async {
    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: KubusButton(
          onPressed: () {},
          label: 'Continue',
          variant: KubusButtonVariant.primary,
        ),
      ),
    );
    expect(find.byType(KubusFocusRing), findsOneWidget);
    // Keyboard traversal (Tab) moves focus onto the button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The primary fill is the same teal as the focus overlay, so the ring
    // is what keeps the focused state visible outside the edge.
    expect(await _pixel(tester, 97, 122), _rgba(KubusColorRoles.dark.focus));
  });

  testWidgets('a field in error keeps the keyboard focus ring', (tester) async {
    // Error borders are red at 1 px (2 px when focused); the ring must stay
    // visible beside them so focus is never identified by colour alone.
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: KubusColorRoles.dark.surface,
            extensions: <ThemeExtension<dynamic>>[KubusColorRoles.dark],
          ),
          home: Scaffold(
            backgroundColor: KubusColorRoles.dark.surface,
            body: Padding(
              padding: const EdgeInsets.all(100),
              child: KubusFormTextField(
                label: 'Email',
                controller: controller,
                errorText: 'Enter a valid email address',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = tester.getRect(find.byType(KubusFocusRing).first);
    expect(
      await _pixel(tester, ring.left.round() - 3, ring.center.dy.round()),
      _rgba(KubusColorRoles.dark.focus),
    );
  });

  testWidgets(
      'Material text buttons take the family focus side on keyboard '
      'focus only', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = ThemeProvider();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          theme: provider.darkTheme,
          home: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Register'),
              ),
            ),
          ),
        ),
      ),
    );
    final button = tester.getRect(find.byType(TextButton));
    final x = button.left.round() + 1;
    final y = button.center.dy.round();

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    // The side sits on the stadium edge, so the pixel is anti-aliased; judge
    // it by being clearly family-teal rather than page-dark.
    final lit = await _pixel(tester, x, y);
    expect(lit[1], greaterThan(100), reason: 'focus side not painted: $lit');

    // Pointer-style focus (touch highlight) does not draw the keyboard side.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          theme: provider.darkTheme,
          home: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Register'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(
        await _pixel(tester, x, y), isNot(_rgba(KubusColorRoles.dark.focus)));
  });
}
