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

  group('domain: short series outliers', () {
    test('a spike more than 4x the next value is clipped in a 7-day series',
        () {
      final values = <num>[3, 8, 5, 13, 9, 120, 17];
      final domain = ChartScale.domain(values, minStep: 1);

      expect(domain.isClipped, isTrue);
      expect(domain.max, lessThan(120));
      expect(domain.max, greaterThanOrEqualTo(17));
      expect(domain.isClippedValue(120), isTrue);
      expect(domain.isClippedValue(17), isFalse);
      expect(domain.plot(120), domain.max);
      _expectValidDomain(domain);
    });

    test('a spike within 4x of the next value is drawn in full', () {
      final domain = ChartScale.domain(
        const <num>[3, 8, 5, 13, 9, 40, 17],
        minStep: 1,
      );
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(40));
      _expectValidDomain(domain);
    });

    test('two equal high values do not clip each other', () {
      final domain = ChartScale.domain(
        const <num>[2, 2, 2, 50, 50, 2, 2],
        minStep: 1,
      );
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(50));
    });

    test('a lone spike on a zero base is not clipped to zero', () {
      final domain = ChartScale.domain(
        const <num>[0, 0, 0, 0, 0, 0, 50],
        minStep: 1,
      );
      expect(domain.isClipped, isFalse);
      expect(domain.max, greaterThanOrEqualTo(50));
    });

    test('series shorter than four values are never clipped', () {
      expect(
        ChartScale.domain(const <num>[1, 100], minStep: 1).isClipped,
        isFalse,
      );
      expect(
        ChartScale.domain(const <num>[1, 1, 100], minStep: 1).isClipped,
        isFalse,
      );
    });

    test('the rule does not jump between 19 and 20 values', () {
      List<num> ofOnes(int count, List<num> tail) => <num>[
            for (var i = 0; i < count - tail.length; i++) 1,
            ...tail,
          ];

      // One spike: clipped on both sides of the boundary.
      expect(
        ChartScale.domain(ofOnes(19, const <num>[50]), minStep: 1).isClipped,
        isTrue,
      );
      expect(
        ChartScale.domain(ofOnes(20, const <num>[50]), minStep: 1).isClipped,
        isTrue,
      );
      // Two equal spikes: not clipped on either side.
      expect(
        ChartScale.domain(ofOnes(19, const <num>[50, 50]), minStep: 1)
            .isClipped,
        isFalse,
      );
      expect(
        ChartScale.domain(ofOnes(20, const <num>[50, 50]), minStep: 1)
            .isClipped,
        isFalse,
      );
    });

    test('a long series with one spike clips against its p95', () {
      final domain = ChartScale.domain(
        <num>[for (var i = 0; i < 39; i++) 1 + (i % 3), 80],
        minStep: 1,
      );
      expect(domain.isClipped, isTrue);
      expect(domain.isClippedValue(80), isTrue);
      _expectValidDomain(domain);
    });
  });

  group('domain: line and bar share one scale', () {
    final inputs = <String, List<num>>{
      'week': <num>[3, 8, 5, 13, 9, 21, 17],
      'short spike': <num>[3, 8, 5, 13, 9, 120, 17],
      'two-series week': <num>[3, 8, 5, 13, 9, 21, 17, 2, 4, 3, 6, 5, 2, 4],
      'zero based': <num>[0, 0, 0, 0, 0, 0, 50],
      'long spike': <num>[for (var i = 0; i < 30; i++) (i * 37 % 23), 400],
      'fractional': <double>[0.0, 0.3, 0.9, 0.4],
    };

    for (final targetTicks in const <int>[4, 5]) {
      test('same domain for the same non-flat data (ticks $targetTicks)', () {
        for (final entry in inputs.entries) {
          final line = ChartScale.domain(
            entry.value,
            targetTicks: targetTicks,
            minStep: 1,
            padFlat: true,
          );
          final bar = ChartScale.domain(
            entry.value,
            targetTicks: targetTicks,
            minStep: 1,
            padFlat: false,
            clipOutliers: true,
          );
          reason(String field) => '${entry.key}: $field';
          expect(line.min, bar.min, reason: reason('min'));
          expect(line.max, bar.max, reason: reason('max'));
          expect(line.step, bar.step, reason: reason('step'));
          expect(line.ticks, bar.ticks, reason: reason('ticks'));
          expect(line.clipAbove, bar.clipAbove, reason: reason('clipAbove'));
          expect(line.hasData, bar.hasData, reason: reason('hasData'));
        }
      });
    }

    test('flat data is the one exception: lines pad, bars keep the baseline',
        () {
      final line = ChartScale.domain(const <num>[7, 7, 7], padFlat: true);
      final bar = ChartScale.domain(const <num>[7, 7, 7]);
      expect(line.min, greaterThan(0));
      expect(bar.min, 0);
    });
  });

  group('domain: negative and non-finite guards', () {
    test('negative values keep a valid domain and no clip below zero', () {
      final domain = ChartScale.domain(const <num>[-100, -4, -6, -5]);
      _expectValidDomain(domain);
      expect(domain.isClipped, isFalse);
      expect(domain.min, lessThanOrEqualTo(-100));
      expect(domain.max, greaterThanOrEqualTo(0));
    });

    test('a single negative point pads around the value', () {
      final domain = ChartScale.domain(
        const <num>[-4],
        padFlat: true,
        minStep: 1,
      );
      expect(domain.hasData, isTrue);
      expect(domain.min, lessThan(-4));
      expect(domain.max, greaterThan(-4));
      _expectValidDomain(domain);
    });

    test('NaN and infinity next to a short spike are ignored for the cutoff',
        () {
      final domain = ChartScale.domain(
        <double>[3, double.nan, 8, 5, double.infinity, 9, 120, 17],
        minStep: 1,
      );
      _expectValidDomain(domain);
      expect(domain.isClipped, isTrue);
      expect(domain.min, 0);
    });

    test('negative infinity input has no data and a finite domain', () {
      final domain = ChartScale.domain(
        <double>[double.negativeInfinity, double.negativeInfinity],
      );
      expect(domain.hasData, isFalse);
      expect(domain.max.isFinite, isTrue);
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

  group('labelIndices', () {
    test('keeps the stride grid and adds the newest bucket when it fits', () {
      // 30 points, a grid label every 5th bucket, 10 px apart: a 24 px label
      // plus gap needs 32 px, and the newest bucket is 5 slots after the last
      // grid label (index 25), i.e. 50 px away.
      final labelled = ChartScale.labelIndices(
        count: 30,
        stride: 5,
        pointSpacing: 10,
        labelWidth: 24,
      );
      expect(labelled, <int>{0, 5, 10, 15, 20, 25, 29});
    });

    test('replaces the last grid label when the newest would collide', () {
      // Newest bucket is only 2 slots after the last grid label (index 28):
      // 20 px, too close for a 24 px label, so the newest takes its place.
      final labelled = ChartScale.labelIndices(
        count: 31,
        stride: 7,
        pointSpacing: 10,
        labelWidth: 24,
      );
      expect(labelled, <int>{0, 7, 14, 21, 30});
      expect(labelled, isNot(contains(28)));
    });

    test('does not change a series whose grid already ends on the newest', () {
      expect(
        ChartScale.labelIndices(
          count: 29,
          stride: 7,
          pointSpacing: 10,
          labelWidth: 24,
        ),
        <int>{0, 7, 14, 21, 28},
      );
    });

    test('labels every bucket when the stride is one, and a lone bucket', () {
      expect(
        ChartScale.labelIndices(
          count: 7,
          stride: 1,
          pointSpacing: 40,
          labelWidth: 20,
        ),
        <int>{0, 1, 2, 3, 4, 5, 6},
      );
      expect(
        ChartScale.labelIndices(
          count: 1,
          stride: 4,
          pointSpacing: 0,
          labelWidth: 20,
        ),
        <int>{0},
      );
      expect(
        ChartScale.labelIndices(
          count: 0,
          stride: 4,
          pointSpacing: 10,
          labelWidth: 20,
        ),
        isEmpty,
      );
    });
  });
}
