/// Parses an HTTP `Retry-After` value into the wait it requests.
///
/// Accepts delta-seconds (`"120"`) and IMF-fixdate
/// (`"Sun, 06 Nov 1994 08:49:37 GMT"`). Returns null when the value is absent
/// or unusable, so callers can fall back to the structured response body.
Duration? parseHttpRetryAfter(String? raw, {DateTime? now}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  final seconds = int.tryParse(value);
  if (seconds != null) {
    return seconds < 0 ? null : Duration(seconds: seconds);
  }

  final match = _imfFixdate.firstMatch(value);
  if (match == null) return null;
  final monthIndex = _months.indexOf(match.group(2)!);
  if (monthIndex < 0) return null;
  final retryAt = DateTime.utc(
    int.parse(match.group(3)!),
    monthIndex + 1,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
  final wait = retryAt.difference((now ?? DateTime.now()).toUtc());
  return wait.isNegative ? Duration.zero : wait;
}

final RegExp _imfFixdate = RegExp(
  r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
