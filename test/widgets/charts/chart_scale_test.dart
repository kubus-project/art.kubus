import 'dart:math' as math;

import 'package:art_kubus/widgets/charts/chart_scale.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isNiceStep(double step) {
  if (!step.isFinite || step <= 0) return false;
  final magnitude = math.pow(10, (math.log(step) / math.ln10).floorToDouble());
  final mantissa = step / magnitude;
  return [1.0, 2.0, 5.0, 10.0].any((nice) => (mantissa - nice).abs() < 1e-9);
}

void _expectValidDomain(ChartDomain domain) {
  expect(domain.min.isFinite, isTrue, reason: 'min must be finite');
  expect(domain.max.isFinite, isTrue, reason: 'max must be finite');
  expect(domain.max, greaterThan(domain.min));
  expect(domain.ticks.length, inInclusiveRange(4, 6),
      reason: 'ticks ${domain.ticks}');
  expect(domain.ticks.first, domain.min);
  expect(domain.ticks.last, domain.max);
  expect(_isNiceStep(domain.step), isTrue, reason: 'step ${domain.step}');
  for (final tick in domain.ticks) {
    expect(tick.isFinite, isTrue);
  }
}

void main() {
  group('niceStep', () {
    test('picks 1, 2 or 5 times a power of ten', () {
      expect(ChartScale.niceStep(100), closeTo(20, 1e-9));
      expect(ChartScale.niceStep(110), closeTo(50, 1e-9));
      expect(ChartScale.niceStep(7), closeTo(2, 1e-9));
      expect(ChartScale.niceStep(0.9), closeTo(0.2, 1e-9));
      expect(ChartScale.niceStep(1000), closeTo(200, 1e-9));
    });

    test('respects minStep for whole-number counts', () {
      expect(ChartScale.niceStep(2, minStep: 1), 1);
      expect(ChartScale.niceStep(0, minStep: 1), 1);
    });

    test('every step over many magnitudes is 1, 2 or 5 times a power of ten',
        () {
      for (var exponent = -3; exponent <= 6; exponent++) {
        for (final mantissa in [1.0, 1.7, 2.5, 3.9, 6.0, 9.4]) {
          final span = mantissa * math.pow(10, exponent).toDouble();
          expect(_isNiceStep(ChartScale.niceStep(span)), isTrue,
              reason: 'span $span');
        }
      }
    });
  });

  group('domain: nice ticks', () {
    test('zero-based counts get a nice top with headroom', () {
      final domain = ChartScale.domain(
        const <num>[0, 3, 7, 12, 9],
        minStep: 1,
      );
      expect(domain.min, 0);
      expect(domain.max, 15);
      expect(domain.ticks, <double>[0, 5, 10, 15]);
      expect(domain.hasData, isTrue);
      expect(domain.isClipped, isFalse);
    });

    test('a sweep of maxima always yields 4 to 6 nice ticks', () {
      for (final minStep in <double>[0, 1]) {
        for (var top = 1; top <= 4000; top += 7) {
          final domain = ChartScale.domain(<num>[0, top], minStep: minStep);
          _expectValidDomain(domain);
          expect(domain.min, lessThanOrEqualTo(0));
          expect(domain.max, greaterThanOrEqualTo(top));
        }
      }
    });

    test('fractional data gets fractional nice ticks without float noise', () {
      final domain = ChartScale.domain(const <num>[0.0, 0.3, 0.9]);
      _expectValidDomain(domain);
      for (final tick in domain.ticks) {
        expect(tick.toString().length, lessThan(12), reason: '$tick');
      }
    });

    test('negative values extend the domain below zero', () {
      final domain = ChartScale.domain(const <num>[-10, 5, -3, 8]);
      _expectValidDomain(domain);
      expect(domain.min, lessThanOrEqualTo(-10));
      expect(domain.max, greaterThanOrEqualTo(8));
      expect(domain.ticks, contains(0));
    });
  });

  group('domain: single point', () {
    test('pads around the point so it is not drawn on the axis', () {
      final domain = ChartScale.domain(
        const <num>[5],
        padFlat: true,
        minStep: 1,
      );
      expect(domain.hasData, isTrue);
      expect(domain.min, lessThan(5));
      expect(domain.max, greaterThan(5));
      _expectValidDomain(domain);
    });

    test('a single bar still starts from the baseline', () {
      final domain = ChartScale.domain(const <num>[5], minStep: 1);
      expect(domain.min, 0);
      expect(domain.max, greaterThan(5));
      _expectValidDomain(domain);
    });
  });

  group('domain: flat ranges', () {
    test('flat non-zero line is padded around the value', () {
      final domain = ChartScale.domain(
        const <num>[7, 7, 7],
        padFlat: true,
      );
      _expectValidDomain(domain);
      expect(domain.min, lessThan(7));
      expect(domain.max, greaterThan(7));
      expect(domain.min, greaterThan(0));
    });

    test('flat non-zero bars keep a zero baseline', () {
      final domain = ChartScale.domain(const <num>[7, 7, 7], minStep: 1);
      expect(domain.min, 0);
      expect(domain.max, greaterThan(7));
      _expectValidDomain(domain);
    });
  });

  group('domain: all zero and empty', () {
    test('all-zero data has no data and a baseline at zero', () {
      final domain = ChartScale.domain(const <num>[0, 0, 0], minStep: 1);
      expect(domain.hasData, isFalse);
      expect(domain.min, 0);
      expect(domain.max, greaterThan(0));
      expect(domain.ticks.first, 0);
      expect(domain.ticks.length, inInclusiveRange(4, 6));
      expect(domain.isClipped, isFalse);
    });

    test('empty input has no data and no NaN or infinity', () {
      final domain = ChartScale.domain(const <num>[]);
      expect(domain.hasData, isFalse);
      expect(domain.min.isFinite, isTrue);
      expect(domain.max.isFinite, isTrue);
      expect(domain.step.isFinite, isTrue);
      for (final tick in domain.ticks) {
        expect(tick.isFinite, isTrue);
      }
    });

    test('non-finite values are treated as zero and do not leak NaN', () {
      expect(
        ChartScale.sanitize(<double>[1, double.nan, double.infinity, -2]),
        <double>[1, 0, 0, -2],
      );
      final domain = ChartScale.domain(<double>[double.nan, double.nan]);
      expect(domain.hasData, isFalse);
      expect(domain.max.isFinite, isTrue);
    });
  });

  group('domain: outliers', () {
    List<num> withSpike() => <num>[
          for (var i = 0; i < 29; i++) 1 + (i % 4),
          500,
        ];

    test('an outlier-dominated series caps the domain at a robust bound', () {
      final values = withSpike();
      final domain = ChartScale.domain(values, minStep: 1);

      expect(domain.isClipped, isTrue);
      expect(domain.max, lessThan(50));
      expect(domain.isClippedValue(500), isTrue);
      expect(domain.isClippedValue(4), isFalse);
      expect(domain.plot(500), domain.max);
      expect(domain.plot(2), 2);
      // The true value is untouched; only the drawn point is clamped.
      expect(values.last, 500);
      _expectValidDomain(domain);
    });

    test('a series with a normal spread is not clipped', () {
      final domain = ChartScale.domain(
        const <num>[10, 12, 11, 13, 9, 14],
        minStep: 1,
      );
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(14));
    });

    test('clipping can be disabled', () {
      final domain = ChartScale.domain(withSpike(), clipOutliers: false);
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(500));
    });

    test('a spike on an all-zero base is not clipped to zero', () {
      final values = <num>[
        for (var i = 0; i < 19; i++) 0,
        50,
      ];
      final domain = ChartScale.domain(values, minStep: 1);
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(50));
    });
  });

  group('percentile', () {
    test('uses nearest rank, so one spike cannot define its own bound', () {
      expect(ChartScale.percentile(<double>[1, 2, 3, 4, 5], 0.5), 3);
      expect(ChartScale.percentile(<double>[1, 2, 3, 4, 5], 0.95), 5);
      expect(ChartScale.percentile(<double>[1, 2, 3, 4, 5], 0.2), 1);
      expect(
        ChartScale.percentile(
            <double>[for (var i = 0; i < 19; i++) 0, 50], 0.95),
        0,
      );
      expect(ChartScale.percentile(<double>[], 0.95), 0);
      expect(ChartScale.percentile(<double>[9], 0.95), 9);
    });
  });

  group('labelStride', () {
    test('thins labels only when they do not fit', () {
      expect(
        ChartScale.labelStride(count: 7, pointSpacing: 100, labelWidth: 30),
        1,
      );
      expect(
        ChartScale.labelStride(count: 30, pointSpacing: 11, labelWidth: 30),
        4,
      );
      expect(
        ChartScale.labelStride(count: 1, pointSpacing: 11, labelWidth: 30),
        1,
      );
      expect(
        ChartScale.labelStride(count: 5, pointSpacing: 0, labelWidth: 30),
        5,
      );
    });
  });

  group('barWidth and contentWidth', () {
    test('bars keep a reasonable thickness on wide and narrow plots', () {
      expect(ChartScale.barWidth(1000, 7), 24);
      expect(ChartScale.barWidth(200, 30), 6);
      expect(ChartScale.barWidth(0, 7), 6);
    });

    test('content width is capped at the maximum and never below minimum', () {
      expect(
        ChartScale.contentWidth(available: 1400, minWidth: 300),
        ChartScale.maxContentWidth,
      );
      expect(ChartScale.contentWidth(available: 300, minWidth: 500), 500);
      expect(ChartScale.contentWidth(available: 358, minWidth: 100), 358);
      expect(
        ChartScale.contentWidth(available: double.infinity, minWidth: 0),
        ChartScale.maxContentWidth,
      );
    });

    test('phones get fewer ticks than desktop', () {
      expect(ChartScale.ticksFor(320), 4);
      expect(ChartScale.ticksFor(390), 4);
      expect(ChartScale.ticksFor(1440), 5);
    });
  });

  group('compactLabel', () {
    test('uses compact thousands and keeps small values exact', () {
      expect(ChartScale.compactLabel(0, locale: 'en'), '0');
      expect(ChartScale.compactLabel(950, locale: 'en'), '950');
      expect(ChartScale.compactLabel(1200, locale: 'en'), '1.2K');
      expect(ChartScale.compactLabel(2500000, locale: 'en'), '2.5M');
      expect(ChartScale.compactLabel(0.5, locale: 'en'), '0.5');
      expect(ChartScale.compactLabel(double.nan, locale: 'en'), '');
    });

    test('follows the locale decimal separator', () {
      final english = ChartScale.compactLabel(1200, locale: 'en');
      final slovene = ChartScale.compactLabel(1200, locale: 'sl');
      expect(english, contains('.'));
      expect(slovene, isNot(equals(english)));
      expect(slovene, contains(','));
    });
  });
}
