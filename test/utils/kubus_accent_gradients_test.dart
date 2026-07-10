import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/kubus_accent_gradients.dart';

void main() {
  test('curated set is stable and distinct', () {
    expect(KubusAccentGradients.all.length, 8);
    final starts =
        KubusAccentGradients.all.map((g) => g.start.toARGB32()).toSet();
    expect(starts.length, 8, reason: 'no duplicate gradient starts');
  });

  test('linear gradient exposes start and end', () {
    final g = KubusAccentGradients.cyanBlue;
    expect(g.linear.colors.first, g.start);
    expect(g.linear.colors.last, g.end);
  });

  test('accent is readable on dark backgrounds (lighter than start)', () {
    for (final g in KubusAccentGradients.all) {
      expect(
        g.accent.computeLuminance(),
        greaterThanOrEqualTo(g.start.computeLuminance()),
        reason: '${g.debugName} accent must not be darker than start',
      );
    }
  });
}
