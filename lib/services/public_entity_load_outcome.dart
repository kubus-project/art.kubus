import 'backend_api_service.dart';

/// Result of a public-entity load (profile, marker) that must tell "the entity
/// does not exist" apart from "the lookup failed this time".
///
/// General callers keep their nullable contracts. Only the public-entry paths
/// read this type, so a transient failure can drive the takeover to its failed
/// state instead of being reported as a missing entity.
sealed class PublicEntityLoadOutcome<T extends Object> {
  const PublicEntityLoadOutcome();

  /// The loaded value, or null when the entity was not found or the lookup
  /// failed transiently.
  T? get valueOrNull => switch (this) {
        PublicEntityFound<T>(:final value) => value,
        _ => null,
      };
}

final class PublicEntityFound<T extends Object>
    extends PublicEntityLoadOutcome<T> {
  const PublicEntityFound(this.value);

  final T value;
}

/// The API answered that the entity is absent (404) or refused to disclose it
/// (other 4xx answers). The entity is not shown, as before.
final class PublicEntityNotFound<T extends Object>
    extends PublicEntityLoadOutcome<T> {
  const PublicEntityNotFound();
}

/// The lookup did not get an answer: rate limiting (429), request timeout (408),
/// server or gateway failure (5xx), transport failure, or an unrecognised error.
/// The entity may well exist, so it must never be reported as not found.
final class PublicEntityTransientFailure<T extends Object>
    extends PublicEntityLoadOutcome<T> {
  const PublicEntityTransientFailure({required this.reason, this.statusCode});

  final String reason;
  final int? statusCode;
}

/// Classifies an error thrown by a public-entity read.
PublicEntityLoadOutcome<T> classifyPublicEntityLoadError<T extends Object>(
  Object error,
) {
  final status = _statusOf(error);
  if (status != null && _isAnswer(status)) {
    return const PublicEntityNotFound();
  }
  if (status != null) {
    return PublicEntityTransientFailure<T>(
      reason: 'HTTP $status',
      statusCode: status,
    );
  }
  if (_isRateLimited(error)) {
    return const PublicEntityTransientFailure(
      reason: 'rate limited',
      statusCode: 429,
    );
  }
  return PublicEntityTransientFailure<T>(
    reason: 'request failed: ${error.runtimeType}',
  );
}

/// A 4xx other than the retryable 408 and 429 is the API's answer.
bool _isAnswer(int status) =>
    status == 404 ||
    (status >= 400 && status < 500 && status != 408 && status != 429);

int? _statusOf(Object error) {
  if (error is BackendApiRequestException) {
    return error.statusCode == 0 ? null : error.statusCode;
  }
  final match = RegExp(r'Request failed: (\d{3})').firstMatch(error.toString());
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

bool _isRateLimited(Object error) =>
    error.toString().contains('Rate limit exceeded');
