import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/home/home_promotion_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_font_loader.dart';

/// Visual verification for the Home discovery rails introduced by PR #48.
///
/// Renders a populated rail containing **all five** entity types side by side in
/// both light and dark themes so the semantic accent colours can be compared
/// directly, and writes the captures to `output/qa/home-rails/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outputDir = Directory('output/qa/home-rails');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  tearDownAll(() {
    File('${outputDir.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'commit': _git(['rev-parse', 'HEAD']),
        'branch': _git(['rev-parse', '--abbrev-ref', 'HEAD']),
        'captures': captures,
      }),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('populated rail — ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(1000, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Matches the theming used by `test/widgets/home/home_promotion_rail_test.dart`:
      // the real `KubusColorRoles` extension supplies the semantic accents under
      // test, without pulling in the Google Fonts text theme (which cannot be
      // fetched from a test process).
      final isDark = brightness == Brightness.dark;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            extensions: [isDark ? KubusColorRoles.dark : KubusColorRoles.light],
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: HomePromotionRailList(
                items: _allEntityTypes,
                placeholderIconBuilder: _iconFor,
                profileFallbackLabel: 'Artist',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final name = 'home-rail-${brightness.name}';
      final bytes = await _capture(tester);
      File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
      captures.add({'name': name, 'brightness': brightness.name});

      // Every entity type must be present and colour must never be the only
      // signal: each card also carries a type-specific icon.
      for (final type in PromotionEntityType.values) {
        expect(find.text(_labelFor(type)), findsOneWidget);
        expect(find.byIcon(_iconFor(type)), findsWidgets);
      }
    });
  }

  test('every entity type resolves to a distinct accent in both themes', () {
    for (final roles in <KubusColorRoles>[
      KubusColorRoles.light,
      KubusColorRoles.dark,
    ]) {
      final accents = {
        for (final type in PromotionEntityType.values)
          type: _accent(type, roles),
      };
      expect(
        accents.values.toSet().length,
        PromotionEntityType.values.length,
        reason: 'rail accents must stay visually distinguishable',
      );
    }
  });
}

Color _accent(PromotionEntityType type, KubusColorRoles roles) {
  // Mirrors HomeRailSemantics.accentFor; asserted separately so a silent
  // remapping there is caught by the semantics unit test, not hidden here.
  switch (type) {
    case PromotionEntityType.artwork:
      return roles.statTeal;
    case PromotionEntityType.profile:
      return roles.statBlue;
    case PromotionEntityType.institution:
      return roles.statGreen;
    case PromotionEntityType.event:
      return roles.statCoral;
    case PromotionEntityType.exhibition:
      return roles.achievementGold;
  }
}

String _labelFor(PromotionEntityType type) => switch (type) {
      PromotionEntityType.artwork => 'Mural on Metelkova',
      PromotionEntityType.profile => 'Ana Kovač',
      PromotionEntityType.institution => 'MSUM Metelkova',
      PromotionEntityType.event => 'Night of Murals',
      PromotionEntityType.exhibition => 'Concrete Canvases',
    };

IconData _iconFor(PromotionEntityType type) => switch (type) {
      PromotionEntityType.artwork => Icons.palette_outlined,
      PromotionEntityType.profile => Icons.person_outline,
      PromotionEntityType.institution => Icons.apartment_outlined,
      PromotionEntityType.event => Icons.event_outlined,
      PromotionEntityType.exhibition => Icons.museum_outlined,
    };

final List<HomeRailItem> _allEntityTypes = PromotionEntityType.values
    .map(
      (type) => HomeRailItem.fromJson(<String, dynamic>{
        'id': type.apiValue,
        'entityType': type.apiValue,
        'title': _labelFor(type),
        'stats': <String, dynamic>{},
      }),
    )
    .toList(growable: false);

Future<List<int>> _capture(WidgetTester tester) async {
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

String _git(List<String> args) {
  try {
    return (Process.runSync('git', args).stdout as String).trim();
  } catch (_) {
    return '';
  }
}
