import 'dart:math' as math;

import 'package:intl/intl.dart';

/// The one scale helper for analytics charts.
///
/// Pure Dart on purpose: tick steps, domains, outlier clipping, label stride
/// and compact numbers are decided here and unit-tested without a widget tree.
/// Chart widgets read a [ChartDomain] and only draw it.
abstract final class ChartScale {
  ChartScale._();

  /// Widest plotting area. Wider containers keep the chart left-aligned at
  /// this width instead of stretching a skinny strip across 1440 px.
  static const double maxContentWidth = 960;

  /// Containers narrower than this are "compact" (phones): fewer ticks.
  static const double compactWidth = 420;

  /// Values above `outlierRatio * cutoff` are clipped to a robust top instead
  /// of flattening the rest of the series. The cutoff is described on
  /// [_outlierCutoff].
  static const double outlierRatio = 4;

  /// Series with at least this many values take the nearest-rank p95 of all of
  /// them as the outlier cutoff. Below it the top value is left out first: the
  /// nearest-rank p95 of fewer than 20 values is the maximum itself, so a spike
  /// would otherwise be compared with itself and never clip.
  static const int robustMinSamples = 20;

  /// Fewest values that can judge an outlier: the top value plus at least three
  /// values to compare it with. Shorter series are never clipped.
  static const int outlierMinSamples = 4;

  /// Headroom above the top value so a peak never sits on the frame.
  static const double headroom = 1.15;

  static const int _maxTicks = 6;
  static const int _minTicks = 4;

  /// Tick count for a container of [availableWidth] logical pixels.
  static int ticksFor(double availableWidth) {
    return availableWidth < compactWidth ? 4 : 5;
  }

  /// Replaces non-finite values (NaN, infinities) with 0 and keeps length, so
  /// series stay aligned with their x labels.
  static List<double> sanitize(Iterable<num> values) {
    return <double>[
      for (final value in values)
        if (value.toDouble().isFinite) value.toDouble() else 0.0,
    ];
  }

  /// A 1, 2 or 5 times a power of ten step that keeps [span] within roughly
  /// [targetTicks] intervals. [minStep] keeps count data on whole numbers.
  static double niceStep(
    double span, {
    int targetTicks = 5,
    double minStep = 0,
  }) {
    final size = span.abs();
    if (!size.isFinite || size <= 0) return math.max(minStep, 1);
    final rough = size / targetTicks;
    final magnitude = _powerOfTen((math.log(rough) / math.ln10) + 1e-12);
    final normalized = rough / magnitude;
    final unit = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;
    return math.max(unit * magnitude, minStep);
  }

  /// Nearest-rank percentile of an ascending [sorted] list, p in 0..1. Nearest
  /// rank (not interpolated), so the result is always a value from the list.
  static double percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final rank = (p.clamp(0.0, 1.0) * sorted.length).ceil();
    final index = (rank - 1).clamp(0, sorted.length - 1);
    return sorted[index];
  }

  /// Computes the y domain for [values] (all series together).
  ///
  /// - No values, or all zero: [ChartDomain.hasData] is false. The domain is
  ///   0 to a small nice top, so a baseline can still be drawn.
  /// - Flat non-zero values: with [padFlat] the domain is padded around the
  ///   value (lines). Without it the domain runs from 0 to the value (bars).
  /// - Otherwise: nice ticks from [includeZero] (or the data minimum), with
  ///   headroom above the top.
  /// - Outlier-dominated data (top > [outlierRatio] x cutoff): the domain stops
  ///   at a robust bound and [ChartDomain.clipAbove] marks where values are
  ///   clipped. True values stay available to the caller for tooltips. The
  ///   cutoff depends on the sample count (see [_outlierCutoff]).
  static ChartDomain domain(
    Iterable<num> values, {
    int targetTicks = 5,
    bool includeZero = true,
    bool padFlat = false,
    double minStep = 0,
    bool clipOutliers = true,
  }) {
    final data = sanitize(values);
    final hasData = data.any((value) => value != 0);
    if (!hasData) {
      final top = minStep > 0 ? minStep * targetTicks : 1.0;
      return _fit(0, top,
          targetTicks: targetTicks, minStep: minStep, hasData: false);
    }

    var lo = data.reduce(math.min);
    var hi = data.reduce(math.max);

    if (lo == hi) {
      if (padFlat) {
        final pad = math.max(lo.abs() * 0.2, minStep);
        return _fit(lo - pad, hi + pad,
            targetTicks: targetTicks, minStep: minStep, hasData: true);
      }
      // Bars: a flat non-zero series still starts at the baseline.
      lo = math.min(0, lo);
      hi = math.max(0, hi);
    } else if (includeZero) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }

    final sorted = List<double>.of(data)..sort();
    final cutoff = _outlierCutoff(sorted);
    final clipped = clipOutliers && cutoff > 0 && hi > outlierRatio * cutoff;
    hi = clipped ? lo + (cutoff - lo) * headroom : lo + (hi - lo) * headroom;

    final fitted =
        _fit(lo, hi, targetTicks: targetTicks, minStep: minStep, hasData: true);
    if (!clipped) return fitted;
    return ChartDomain(
      min: fitted.min,
      max: fitted.max,
      step: fitted.step,
      ticks: fitted.ticks,
      hasData: true,
      clipAbove: fitted.max,
    );
  }

  /// Label stride so [labelWidth] (plus [gap]) fits between points that are
  /// [pointSpacing] apart. Returns 1 when every label fits.
  static int labelStride({
    required int count,
    required double pointSpacing,
    required double labelWidth,
    double gap = 8,
  }) {
    if (count <= 1) return 1;
    if (!pointSpacing.isFinite || pointSpacing <= 0) return count;
    final needed = math.max(labelWidth, 1) + gap;
    return math.max(1, (needed / pointSpacing).ceil());
  }

  /// Plot width for [count] bars: about 60% of a slot, capped so bars keep a
  /// reasonable thickness on wide screens.
  static double barWidth(double plotWidth, int count) {
    if (count <= 0 || !plotWidth.isFinite || plotWidth <= 0) return 6;
    return (plotWidth / count * 0.6).clamp(6.0, 24.0).toDouble();
  }

  /// Width of the chart content inside a container of [available] width.
  /// Never narrower than [minWidth] (the chart then scrolls), never wider
  /// than [maxContentWidth].
  static double contentWidth({
    required double available,
    required double minWidth,
  }) {
    final capped = available.isFinite
        ? math.min(available, maxContentWidth)
        : maxContentWidth;
    return math.max(minWidth, capped);
  }

  /// Compact axis label in [locale] (a language code such as `en` or `sl`).
  /// Thousands use the locale's compact form (1.2K, 1,2 tis.); small values
  /// keep their decimals.
  static String compactLabel(num value, {required String locale}) {
    final number = value.toDouble();
    if (!number.isFinite) return '';
    if (number.abs() >= 1000) {
      return NumberFormat.compact(locale: locale).format(number);
    }
    final whole = number == number.roundToDouble();
    final format = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = whole ? 0 : 2;
    return format.format(number);
  }

  static ChartDomain _fit(
    double lo,
    double hi, {
    required int targetTicks,
    required double minStep,
    required bool hasData,
  }) {
    var low = lo;
    var high = hi;
    if (minStep > 0 && high - low < minStep * (targetTicks - 1)) {
      high = low + minStep * (targetTicks - 1);
    }
    if (high <= low) high = low + 1;

    var step = niceStep(high - low, targetTicks: targetTicks, minStep: minStep);
    for (var attempt = 0; attempt < 6; attempt++) {
      final snappedLow = (low / step).floorToDouble() * step;
      final snappedHigh = (high / step).ceilToDouble() * step;
      final count = ((snappedHigh - snappedLow) / step).round() + 1;
      if (count > _maxTicks) {
        step = _nextStep(step);
        continue;
      }
      if (count < _minTicks && attempt == 0) {
        step = _previousStep(step, minStep);
        continue;
      }
      final ticks = <double>[
        for (var k = 0; k < count; k++) _clean(snappedLow + k * step, step),
      ];
      return ChartDomain(
        min: ticks.first,
        max: ticks.last,
        step: step,
        ticks: ticks,
        hasData: hasData,
      );
    }
    // Unreachable in practice; fall back to a coarse but valid domain.
    final coarse = niceStep(high - low, targetTicks: 2, minStep: minStep);
    final snappedLow = (low / coarse).floorToDouble() * coarse;
    final snappedHigh = (high / coarse).ceilToDouble() * coarse;
    final ticks = <double>[
      for (var v = snappedLow; v <= snappedHigh + coarse / 2; v += coarse)
        _clean(v, coarse),
    ];
    return ChartDomain(
      min: ticks.first,
      max: ticks.last,
      step: coarse,
      ticks: ticks,
      hasData: hasData,
    );
  }

  /// The value the top point is judged against, or 0 when no robust reference
  /// exists (fewer than [outlierMinSamples] values, so 0 never clips).
  ///
  /// Short series (fewer than [robustMinSamples]) take the nearest-rank p95 of
  /// the values without the top one. For those counts that is the second
  /// highest value, so the top value clips only when it is more than
  /// [outlierRatio] times the next highest. Long series take the plain
  /// nearest-rank p95. From 20 to 39 values that is also the second highest,
  /// so the rule does not change at the boundary.
  static double _outlierCutoff(List<double> sorted) {
    if (sorted.length < outlierMinSamples) return 0;
    if (sorted.length >= robustMinSamples) return percentile(sorted, 0.95);
    return percentile(sorted.sublist(0, sorted.length - 1), 0.95);
  }

  static double _powerOfTen(double exponent) {
    return math.pow(10, exponent.floorToDouble()).toDouble();
  }

  static double _nextStep(double step) {
    final magnitude = _powerOfTen((math.log(step) / math.ln10) + 1e-12);
    final mantissa = (step / magnitude).round();
    if (mantissa <= 1) return 2 * magnitude;
    if (mantissa <= 2) return 5 * magnitude;
    return 10 * magnitude;
  }

  static double _previousStep(double step, double minStep) {
    final magnitude = _powerOfTen((math.log(step) / math.ln10) + 1e-12);
    final mantissa = (step / magnitude).round();
    final previous = mantissa >= 5
        ? 2 * magnitude
        : mantissa >= 2
            ? magnitude
            : magnitude / 2;
    return math.max(previous, minStep);
  }

  /// Removes floating point noise (0.30000000000000004) from tick values.
  static double _clean(double value, double step) {
    final decimals = step >= 1 ? 0 : (-math.log(step) / math.ln10).ceil() + 2;
    final factor = math.pow(10, decimals).toDouble();
    final cleaned = (value * factor).roundToDouble() / factor;
    return cleaned == 0 ? 0 : cleaned;
  }
}

/// A resolved y domain for one chart.
class ChartDomain {
  const ChartDomain({
    required this.min,
    required this.max,
    required this.step,
    required this.ticks,
    required this.hasData,
    this.clipAbove,
  });

  final double min;
  final double max;
  final double step;

  /// Tick values from [min] to [max], inclusive, 4 to 6 of them.
  final List<double> ticks;

  /// False when the input had no non-zero value (draw an empty state).
  final bool hasData;

  /// Non-null when outliers were clipped: values above it are drawn at it.
  final double? clipAbove;

  bool get isClipped => clipAbove != null;

  /// Clamps [value] into the domain so it can be drawn.
  double plot(double value) => math.min(math.max(value, min), max);

  /// True when [value] lies above the clipped top and needs a marker.
  bool isClippedValue(double value) => clipAbove != null && value > max;
}
