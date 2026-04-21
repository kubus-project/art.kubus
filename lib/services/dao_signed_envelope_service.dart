import 'dart:convert';

import '../models/dao.dart';
import 'telemetry/telemetry_uuid.dart';

class DAOSignedEnvelopeService {
  const DAOSignedEnvelopeService();

  Future<DAOSignedEnvelope> signEnvelope({
    required DAOSignedActionType actionType,
    required String walletAddress,
    required Future<String> Function(String message) signMessage,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? references,
    String? actionId,
    String? nonce,
    String? referenceId,
    String? referenceCid,
    DateTime? timestamp,
  }) async {
    final normalizedPayload = _normalizePayload(payload);
    final normalizedReferences = _normalizePayload(references ?? const {});
    final resolvedTimestamp = (timestamp ?? DateTime.now()).toUtc();
    final envelope = DAOSignedEnvelope.unsigned(
      actionId: actionId ?? TelemetryUuid.v4(),
      actionType: actionType,
      walletAddress: walletAddress.trim(),
      publicKey: walletAddress.trim(),
      timestamp: resolvedTimestamp,
      nonce: nonce ?? TelemetryUuid.v4(),
      payload: normalizedPayload,
      references: normalizedReferences,
      referenceId: referenceId,
      referenceCid: referenceCid,
    );
    final signature = await signMessage(_stableJsonEncode(envelope.toSigningPayloadJson()));
    return envelope.withSignature(signature);
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> value) {
    final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
    final normalized = <String, dynamic>{};
    for (final key in sortedKeys) {
      normalized[key] = _normalizeJsonValue(value[key]);
    }
    return normalized;
  }

  static dynamic _normalizeJsonValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _normalizePayload(value);
    }
    if (value is Map) {
      return _normalizePayload(
        value.map((key, entry) => MapEntry(key.toString(), entry)),
      );
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
  }

  static String _stableJsonEncode(dynamic value) {
    return jsonEncode(_normalizeJsonValue(value));
  }
}
