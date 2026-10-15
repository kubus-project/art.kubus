import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default Material controls (no widget-level focus styling) must draw a
/// keyboard focus indicator from the app theme alone, and must not draw one
/// for pointer focus. The indicator is sampled from the composited pixels.
final _boundaryKey = GlobalKey();

double _luminance(List<int> c) {
  double channel(int v) {
    final x = v / 255.0;
    return x <= 0.03928
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c[0]) +
      0.7152 * channel(c[1]) +
      0.0722 * channel(c[2]);
}

double _contrast(List<int> a, List<int> b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<List<int>> _pixel(WidgetTester tester, int x, int y) async {
  return (await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    final bytes = data!.buffer.asUint8List();
    return [bytes[offset], bytes[offset + 1], bytes[offset + 2]];
  }))!;
}

Widget _page(ThemeData theme, Widget child) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Contrast between the indicator sample (inside the control, at [insetPx])
/// and the page sample just outside its left edge, from the composited frame.
Future<double> _indicatorRatio(
  WidgetTester tester,
  Rect rect, {
  required double insetPx,
}) async {
  final y = rect.center.dy.round();
  final inside = await _pixel(tester, (rect.left + insetPx).round(), y);
  final outside = await _pixel(tester, (rect.left - 3).round(), y);
  return _contrast(inside, outside);
}

Future<ThemeData> _appTheme(WidgetTester tester, {required bool dark}) async {
  return (await tester.runAsync(() async {
    final provider = ThemeProvider();
    while (!provider.isInitialized) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return dark ? provider.darkTheme : provider.lightTheme;
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final dark in [true, false]) {
    final label = dark ? 'dark' : 'light';

    testWidgets(
        '$label: keyboard focus draws a >=3:1 side on a default '
        'IconButton; pointer focus does not', (tester) async {
      final theme = await _appTheme(tester, dark: dark);
      Widget button() =>
          IconButton(icon: const Icon(Icons.close), onPressed: () {});

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(_page(theme, button()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(IconButton));
      // The 2px side sits on the stadium edge: sample 1px inside it.
      expect(
        await _indicatorRatio(tester, rect, insetPx: 5),
        greaterThanOrEqualTo(3.0),
      );

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(_page(theme, button()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(await _indicatorRatio(tester, rect, insetPx: 5), lessThan(1.5));
    });

    testWidgets(
        '$label: keyboard focus fills a default ListTile to >=3:1; '
        'pointer focus does not', (tester) async {
      final theme = await _appTheme(tester, dark: dark);
      Widget tile() => SizedBox(
            width: 300,
            child: ListTile(title: const Text('Ticket'), onTap: () {}),
          );

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(_page(theme, tile()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(ListTile));
      expect(
        await _indicatorRatio(tester, rect, insetPx: 3),
        greaterThanOrEqualTo(3.0),
      );

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(_page(theme, tile()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(await _indicatorRatio(tester, rect, insetPx: 3), lessThan(1.5));
    });

    testWidgets('$label: keyboard focus fills a default ChoiceChip to >=3:1',
        (tester) async {
      final theme = await _appTheme(tester, dark: dark);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(_page(
        theme,
        ChoiceChip(
          label: const Text('Recent'),
          selected: false,
          onSelected: (_) {},
        ),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(ChoiceChip));
      expect(
        await _indicatorRatio(tester, rect, insetPx: 4),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets(
        '$label: keyboard focus fills a default TabBar tab to >=3:1; '
        'pointer focus does not', (tester) async {
      // The focused tab is the unselected first tab (initialIndex 1), so its
      // only indicator is the focus fill. Its label is avoided by sampling
      // near the top of the tab; the same point in a pointer-focus frame is
      // the unfilled page the fill sits on.
      final theme = await _appTheme(tester, dark: dark);
      Widget tabs() => DefaultTabController(
            length: 2,
            initialIndex: 1,
            child: const SizedBox(
              width: 300,
              child: TabBar(tabs: [Tab(text: 'Feed'), Tab(text: 'Messages')]),
            ),
          );

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(_page(theme, tabs()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(Tab).first);
      final point = Offset(rect.center.dx - 12, rect.top + 6);
      final lit = await _pixel(tester, point.dx.round(), point.dy.round());

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(_page(theme, tabs()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final page = await _pixel(tester, point.dx.round(), point.dy.round());

      expect(_contrast(lit, page), greaterThanOrEqualTo(3.0));
      // Pointer focus leaves the tab unfilled: same point as the page corner.
      final corner = await _pixel(tester, 2, 2);
      expect(_contrast(page, corner), lessThan(1.5));
    });
  }
}
