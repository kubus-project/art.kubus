import 'dart:io';

import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:flutter_test/flutter_test.dart';

/// `docs/DESIGN_SYSTEM.md` is the single source of truth for PRODUCT visual
/// semantics and hover motion. Its constants block must equal the code, and its
/// interaction rules must keep touch, disabled and reduced-motion behavior clear.
void main() {
  const contractPath = 'docs/DESIGN_SYSTEM.md';

  Map<String, double> constants() {
    final doc = File(contractPath).readAsStringSync();
    final block = RegExp(r'```text\n((?:\w+: [\d.]+\n)+)```').firstMatch(doc);
    expect(block, isNotNull, reason: 'the constants block is missing');
    return {
      for (final line in block!.group(1)!.trim().split('\n'))
        line.split(': ')[0]: double.parse(line.split(': ')[1]),
    };
  }

  test('the contract constants equal KubusHoverResponse', () {
    final doc = constants();
    expect(doc['liftDistance'], KubusHoverResponse.liftDistance);
    expect(doc['floatAmplitude'], KubusHoverResponse.floatAmplitude);
    expect(
      doc['floatPeriodMs'],
      KubusHoverResponse.floatPeriod.inMilliseconds.toDouble(),
    );
    expect(
      doc['entryMs'],
      KubusHoverResponse.duration.inMilliseconds.toDouble(),
    );
  });

  test('the float never drops a surface below its resting line', () {
    expect(
      KubusHoverResponse.floatAmplitude,
      lessThan(KubusHoverResponse.liftDistance),
    );
  });

  test('the canonical document owns the complete interaction contract', () {
    final doc =
        File(contractPath).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
    expect(
        doc, contains('single source of truth for PRODUCT visual semantics'));
    expect(doc, contains('Reduced motion gives'));
    expect(
        doc,
        contains(
            'Touch-only interfaces never receive continuous hover motion'));
    expect(doc, contains('Disabled or loading tiles do not lift'));
    expect(doc, contains('both dense and expressive stat-card layouts answer'));
    expect(doc, contains('`KubusActionSidebarTile` stays a flat tinting row'));
    expect(
        doc,
        contains(
            '`KubusEntityCard` uses its own one-shot lift/media response'));
    expect(doc, contains('`DesktopActionButton` keeps its button response'));
    expect(
      doc,
      contains('`DesktopCard`, rails, forms and list rows stay flat'),
    );
    expect(doc, contains('`KubusAtmosphere` and heroes are identity fields'));
    for (final retired in const [
      'docs/design/PRODUCT_V5_MOTION_CONTRACT.md',
      'docs/design/PRODUCT_V5_SEMANTIC_VISUAL_SYSTEM.md',
      'docs/design/PRODUCT_V5_ART_DIRECTION_RESTORATION.md',
      'docs/design/PRODUCT_V5_CHARACTER_REBALANCE.md',
    ]) {
      expect(
        File(retired).existsSync(),
        isFalse,
        reason: '$retired must not become a second active authority',
      );
    }
  });

  test('the browser gate and its gallery exist and stay in step', () {
    final script = File(
      'scripts/qa/product_motion_acceptance.mjs',
    ).readAsStringSync();
    final gallery = File(
      'tool/qa/product_motion_gallery_main.dart',
    ).readAsStringSync();
    final ids = RegExp(
      r"id: '([\w-]+)'",
    ).allMatches(script).map((m) => m.group(1)!).toList();
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(
        gallery,
        contains("'$id'"),
        reason: 'gallery is missing the "$id" case',
      );
    }
  });
}
