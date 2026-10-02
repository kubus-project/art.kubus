import 'package:art_kubus/services/spatial_transfer_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  SpatialTransferMeter meter() => SpatialTransferMeter(clock: () => now);

  setUp(() => now = DateTime.utc(2026, 1, 1));

  void advance(Duration by) => now = now.add(by);

  group('throughput', () {
    test('is unknown before there is anything to measure', () {
      final subject = meter();

      expect(subject.bytesPerSecond, isNull);

      subject.record(0);
      expect(subject.bytesPerSecond, isNull);
    });

    test('is unknown until the sample window is long enough', () {
      final subject = meter()..record(0);
      advance(const Duration(milliseconds: 500));
      subject.record(1024 * 1024);

      // Half a second of evidence is not a rate; reporting one here is how a
      // transfer ends up claiming 2 GB/s for its first chunk.
      expect(subject.bytesPerSecond, isNull);
    });

    test('is measured once there is enough evidence', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 4));
      subject.record(4 * 1000 * 1000);

      expect(subject.bytesPerSecond, closeTo(1000 * 1000, 1));
    });

    test('follows a transfer that genuinely slows down', () {
      final subject = meter(); // 10s window
      subject.record(0);
      advance(const Duration(seconds: 4));
      subject.record(40 * 1000 * 1000); // 10 MB/s
      expect(subject.bytesPerSecond, closeTo(10 * 1000 * 1000, 1));

      for (var i = 0; i < 6; i++) {
        advance(const Duration(seconds: 2));
        subject.record(40 * 1000 * 1000 + (i + 1) * 1000 * 1000); // 0.5 MB/s
      }

      expect(subject.bytesPerSecond, lessThan(2 * 1000 * 1000));
    });

    test(
        'a total that moves backwards rebuilds the rate instead of reporting '
        'a negative one', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 4));
      subject.record(8 * 1000 * 1000);
      expect(subject.bytesPerSecond, isNotNull);

      // A route change rewound the in-flight portion of the current file.
      advance(const Duration(seconds: 1));
      subject.record(6 * 1000 * 1000);

      expect(subject.bytesPerSecond, isNull);
    });
  });

  group('eta', () {
    test('is withheld until throughput is known', () {
      final subject = meter()..record(0);

      expect(subject.etaFor(100 * 1000 * 1000), isNull);

      advance(const Duration(milliseconds: 500));
      subject.record(1000 * 1000);
      expect(subject.etaFor(100 * 1000 * 1000), isNull);
    });

    test('is remaining bytes over measured throughput', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 4));
      subject.record(4 * 1000 * 1000); // 1 MB/s

      expect(subject.etaFor(19 * 1000 * 1000)?.inSeconds, 19);
    });

    test('is zero when nothing remains', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 4));
      subject.record(4 * 1000 * 1000);

      expect(subject.etaFor(0), Duration.zero);
    });

    test('is withheld while the transfer is stalled', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 4));
      subject.record(4 * 1000 * 1000);
      expect(subject.etaFor(10 * 1000 * 1000), isNotNull);

      advance(const Duration(seconds: 30));

      expect(subject.isStalled, isTrue);
      // A countdown against a transfer that has stopped is a lie the user can
      // watch happening.
      expect(subject.etaFor(10 * 1000 * 1000), isNull);
    });
  });

  group('stall detection', () {
    test('a transfer that is merely slow is not stalled', () {
      final subject = meter()..record(0);

      advance(const Duration(seconds: 10));
      subject.record(1024);

      expect(subject.isStalled, isFalse);
    });

    test('recovers once bytes move again', () {
      final subject = meter()..record(0);
      advance(const Duration(seconds: 30));
      expect(subject.isStalled, isTrue);

      subject.record(1024);

      expect(subject.isStalled, isFalse);
    });
  });

  test('a route change clears the rate but keeps the delivered total', () {
    final subject = meter()..record(0);
    advance(const Duration(seconds: 4));
    subject.record(4 * 1000 * 1000);
    expect(subject.bytesPerSecond, isNotNull);

    subject.resetRate();

    expect(subject.bytesPerSecond, isNull);
    expect(subject.deliveredBytes, 4 * 1000 * 1000);
  });
}
