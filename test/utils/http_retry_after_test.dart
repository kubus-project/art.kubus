import 'package:art_kubus/utils/http_retry_after.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses delta-seconds', () {
    expect(parseHttpRetryAfter('120'), const Duration(seconds: 120));
    expect(parseHttpRetryAfter(' 0 '), Duration.zero);
  });

  test('rejects missing, empty, negative and garbage values', () {
    expect(parseHttpRetryAfter(null), isNull);
    expect(parseHttpRetryAfter(''), isNull);
    expect(parseHttpRetryAfter('-5'), isNull);
    expect(parseHttpRetryAfter('soon'), isNull);
  });

  test('parses an IMF-fixdate relative to the supplied clock', () {
    final now = DateTime.utc(1994, 11, 6, 8, 40, 37);
    expect(
      parseHttpRetryAfter('Sun, 06 Nov 1994 08:49:37 GMT', now: now),
      const Duration(minutes: 9),
    );
  });

  test('clamps an IMF-fixdate in the past to zero', () {
    final now = DateTime.utc(2030, 1, 1);
    expect(
      parseHttpRetryAfter('Sun, 06 Nov 1994 08:49:37 GMT', now: now),
      Duration.zero,
    );
  });
}
