import 'dart:ui' as ui;

import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/navigation/kubus_mobile_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = <KubusMobileNavigationDestination>[
  KubusMobileNavigationDestination(
    key: Key('nav_map'),
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: 'Map',
  ),
  KubusMobileNavigationDestination(
    key: Key('nav_ar'),
    icon: Icons.view_in_ar_outlined,
    selectedIcon: Icons.view_in_ar,
    label: 'AR',
  ),
  KubusMobileNavigationDestination(
    key: Key('nav_community'),
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Skupnost',
  ),
  KubusMobileNavigationDestination(
    key: Key('nav_home'),
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  KubusMobileNavigationDestination(
    key: Key('nav_account'),
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Account',
  ),
];

Widget _harness({
  required int selected,
  required ValueChanged<int> onSelected,
  Brightness brightness = Brightness.light,
}) {
  final roles = brightness == Brightness.dark
      ? KubusColorRoles.dark
      : KubusColorRoles.light;
  return MaterialApp(
    theme: ThemeData(brightness: brightness, extensions: [roles]),
    home: Scaffold(
      bottomNavigationBar: KubusMobileNavigationBar(
        semanticLabel: 'Main navigation',
        destinations: _destinations,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('every destination is labeled and tappable at $width px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var tapped = -1;
      await tester.pumpWidget(
        _harness(selected: 3, onSelected: (i) => tapped = i),
      );

      for (final d in _destinations) {
        expect(find.text(d.label), findsOneWidget);
        final size = tester.getSize(find.byKey(d.key!));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('nav_community')));
      expect(tapped, 2);
    });
  }

  testWidgets('exposes button role and selected state, not toggle state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(selected: 0, onSelected: (_) {}));

    final selected = tester.getSemantics(find.byKey(const Key('nav_map')));
    expect(selected.label, 'Map');
    expect(selected.flagsCollection.isButton, isTrue);
    expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(selected.flagsCollection.isToggled, ui.Tristate.none);
    expect(selected.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final other = tester.getSemantics(find.byKey(const Key('nav_home')));
    expect(other.flagsCollection.isButton, isTrue);
    expect(other.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
    handle.dispose();
  });

  testWidgets('selected destination uses the family active role in dark theme',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        selected: 2,
        onSelected: (_) {},
        brightness: Brightness.dark,
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.people));
    expect(icon.color, KubusColorRoles.dark.active);
    final idle = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    expect(idle.color, KubusColorRoles.dark.foregroundMuted);
  });

  testWidgets('keeps a single-line label at 200% text scale without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _harness(selected: 0, onSelected: (_) {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
