import 'dart:io';

import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:flutter_test/flutter_test.dart';

/// `docs/design/PRODUCT_V5_MOTION_CONTRACT.md` is the single source of truth
/// for PRODUCT hover motion. Its constants block must equal the code, and the
/// other PRODUCT documents must defer to it instead of restating the numbers.
void main() {
  const contractPath = 'docs/design/PRODUCT_V5_MOTION_CONTRACT.md';

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
    expect(doc['floatPeriodMs'],
        KubusHoverResponse.floatPeriod.inMilliseconds.toDouble());
    expect(
        doc['entryMs'], KubusHoverResponse.duration.inMilliseconds.toDouble());
  });

  test('the float never drops a surface below its resting line', () {
    expect(
      KubusHoverResponse.floatAmplitude,
      lessThan(KubusHoverResponse.liftDistance),
    );
  });

  test('other PRODUCT documents defer to the contract', () {
    for (final path in const [
      'docs/design/PRODUCT_V5_SEMANTIC_VISUAL_SYSTEM.md',
      'docs/design/PRODUCT_V5_ART_DIRECTION_RESTORATION.md',
      'docs/design/PRODUCT_V5_CHARACTER_REBALANCE.md',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('PRODUCT_V5_MOTION_CONTRACT.md'),
        reason: '$path must point at the motion contract',
      );
    }
  });

  test('the browser gate and its gallery exist and stay in step', () {
    final script =
        File('scripts/qa/product_motion_acceptance.mjs').readAsStringSync();
    final gallery =
        File('tool/qa/product_motion_gallery_main.dart').readAsStringSync();
    final ids = RegExp(r"id: '([\w-]+)'")
        .allMatches(script)
        .map((m) => m.group(1)!)
        .toList();
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(gallery, contains("'$id'"),
          reason: 'gallery is missing the "$id" case');
    }
  });
}
