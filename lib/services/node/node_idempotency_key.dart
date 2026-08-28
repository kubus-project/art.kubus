import 'dart:math';

/// A client-generated key the Node deduplicates a mutating operation against.
///
/// This exists as a type rather than a `String?` field because the difference
/// between "absent" and "present but blank" decides whether the transport
/// resolver is allowed to replay a request on another rung. A blank string is
/// not a weaker key — it is no key at all, and treating it as one is how a
/// retry after an ambiguous failure turns into a second capture or a second
/// job. Constructing the value is the only way to get one, so the check cannot
/// be forgotten at a call site.
class NodeIdempotencyKey {
  const NodeIdempotencyKey._(this.value);

  /// Builds a key, rejecting anything the Node could not deduplicate against.
  ///
  /// Throws [ArgumentError] rather than returning null: a caller that asked
  /// for a key has already decided this operation must not be duplicated, so
  /// silently degrading to "unkeyed" would remove the protection it asked for.
  factory NodeIdempotencyKey(String value) {
    final key = tryParse(value);
    if (key == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Not a usable idempotency key. Expected $minLength-$maxLength '
            'characters from [A-Za-z0-9-._~:], with no surrounding whitespace.',
      );
    }
    return key;
  }

  /// Builds a key from an untrusted or optional source, or null if unusable.
  ///
  /// Blank, whitespace-only, oversized and malformed values all collapse to
  /// null, which the request treats as "no key" — the safe reading, because an
  /// unkeyed mutation is never retried across transports.
  static NodeIdempotencyKey? tryParse(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length != value.length) return null;
    if (trimmed.length < minLength || trimmed.length > maxLength) return null;
    if (!_allowed.hasMatch(trimmed)) return null;
    return NodeIdempotencyKey._(trimmed);
  }

  /// Derives a stable key from an operation and the thing it acts on.
  ///
  /// Preferred over [random] whenever the operation already has a natural
  /// identity — committing draft `d1` is the same intent whether it is retried
  /// two seconds or two app launches later, so the key must survive a restart
  /// for the Node's deduplication to be worth anything.
  factory NodeIdempotencyKey.forOperation(
    String operation, {
    required String scope,
  }) {
    final normalized = '${_slug(operation)}.${_slug(scope)}';
    if (_slug(operation).isEmpty || _slug(scope).isEmpty) {
      throw ArgumentError(
        'An idempotency key needs a non-empty operation and scope; '
        'got operation="$operation", scope="$scope".',
      );
    }
    return NodeIdempotencyKey(_pad(normalized));
  }

  /// Mints a fresh key for an operation with no stable natural identity.
  ///
  /// The caller must hold the returned key for the whole operation, including
  /// retries. Generating a new one per attempt defeats deduplication entirely.
  factory NodeIdempotencyKey.random(String operation, {Random? random}) {
    final source = random ?? Random.secure();
    final suffix = List<int>.generate(16, (_) => source.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return NodeIdempotencyKey(_pad('${_slug(operation)}.$suffix'));
  }

  /// Shortest key accepted. Long enough that a truncated or placeholder value
  /// cannot pass for a real one.
  static const int minLength = 8;

  /// Longest key accepted, bounding both the HTTP header and the WebRTC frame
  /// header the Node has to parse.
  static const int maxLength = 128;

  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9\-._~:]+$');
  static final RegExp _disallowed = RegExp(r'[^A-Za-z0-9\-._~:]+');

  /// The validated key, safe to place in an HTTP header or a protocol frame.
  final String value;

  static String _slug(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(_disallowed, '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  /// Keeps a short but legitimate derived key above [minLength] without
  /// changing what it identifies.
  static String _pad(String input) =>
      input.length >= minLength ? input : input.padRight(minLength, '0');

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is NodeIdempotencyKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
