import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Identity-dependent action a visitor attempted before having an account.
///
/// Only non-sensitive engagement actions are representable here. Wallet, DAO,
/// claim, purchase and other privileged flows are deliberately absent: those
/// must always be re-initiated with their own fresh confirmation after
/// authentication and are never carried across an auth boundary.
enum PendingActionType {
  save,
  like,
  follow,
  comment,
  contribute;

  String get storageValue => name;

  static PendingActionType? fromStorage(String? value) {
    final normalized = (value ?? '').trim();
    for (final type in PendingActionType.values) {
      if (type.storageValue == normalized) return type;
    }
    return null;
  }
}

/// Entity the pending action applies to.
enum PendingActionTargetType {
  artwork,
  event,
  exhibition,
  post,
  user,
  marker;

  String get storageValue => name;

  static PendingActionTargetType? fromStorage(String? value) {
    final normalized = (value ?? '').trim();
    for (final type in PendingActionTargetType.values) {
      if (type.storageValue == normalized) return type;
    }
    return null;
  }
}

/// Serialisable record of "what the visitor was trying to do" when the app
/// asked them to create an account.
///
/// Deliberately minimal: identifiers and an in-app return route only. It never
/// stores credentials, tokens, wallet material, precise location history or
/// executable callbacks, and it can never widen server-side authorization —
/// the backend re-checks the target and the caller on replay.
@immutable
class PendingActionIntent {
  const PendingActionIntent({
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.returnRoute,
    required this.sourceScreen,
    required this.createdAtUtc,
    this.targetLabel,
    this.markerId,
    this.sessionId,
    this.returnArguments = const <String, String>{},
  });

  /// How long a captured intent stays replayable. Long enough to survive an
  /// email verification round trip, short enough that a stale intent never
  /// surprises a returning user.
  static const Duration ttl = Duration(hours: 24);

  static const int _maxIdLength = 128;
  static const int _maxLabelLength = 120;
  static const int _maxRouteLength = 160;
  static const int _maxArgumentEntries = 6;

  final PendingActionType actionType;
  final PendingActionTargetType targetType;

  /// Stable backend identifier of the target entity.
  final String targetId;

  /// Human-readable target name, used only to render confirmation copy.
  final String? targetLabel;

  /// Canonical in-app route to return to. Always a local absolute path.
  final String returnRoute;

  /// String-only route arguments needed to rebuild [returnRoute].
  final Map<String, String> returnArguments;

  /// Screen the action was attempted from (telemetry dimension).
  final String sourceScreen;

  /// Optional map marker to reopen so the visitor lands back on the exact
  /// overlay they were looking at.
  final String? markerId;

  /// Telemetry session that captured the intent, so the guest session and the
  /// authenticated session stay correlatable.
  final String? sessionId;

  final DateTime createdAtUtc;

  bool get isValid => targetId.isNotEmpty && isSafeInternalRoute(returnRoute);

  bool isExpiredAt(DateTime nowUtc) =>
      nowUtc.difference(createdAtUtc.toUtc()) >= ttl;

  bool get isExpired => isExpiredAt(DateTime.now().toUtc());

  /// Stable key used for exactly-once bookkeeping.
  String get identityKey =>
      '${actionType.storageValue}:${targetType.storageValue}:$targetId';

  /// Rejects anything that could turn into an open redirect: absolute URLs,
  /// scheme-relative paths, backslash tricks and non-local paths.
  static bool isSafeInternalRoute(String? route) {
    final value = (route ?? '').trim();
    if (value.isEmpty || value.length > _maxRouteLength) return false;
    if (!value.startsWith('/')) return false;
    if (value.startsWith('//')) return false;
    if (value.contains('\\')) return false;
    if (value.contains('..')) return false;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    if (parsed.hasScheme || parsed.hasAuthority) return false;
    return true;
  }

  static String _clip(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }

  static Map<String, String> _sanitizeArguments(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      if (out.length >= _maxArgumentEntries) break;
      final key = entry.key.toString().trim();
      if (key.isEmpty || key.length > 32) continue;
      final value = entry.value;
      if (value == null) continue;
      final stringValue = _clip(value.toString(), _maxIdLength);
      if (stringValue.isEmpty) continue;
      out[key] = stringValue;
    }
    return Map<String, String>.unmodifiable(out);
  }

  PendingActionIntent copyWith({String? sessionId}) => PendingActionIntent(
        actionType: actionType,
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
        returnRoute: returnRoute,
        returnArguments: returnArguments,
        sourceScreen: sourceScreen,
        markerId: markerId,
        sessionId: sessionId ?? this.sessionId,
        createdAtUtc: createdAtUtc,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'action_type': actionType.storageValue,
        'target_type': targetType.storageValue,
        'target_id': targetId,
        if (targetLabel != null && targetLabel!.isNotEmpty)
          'target_label': targetLabel,
        'return_route': returnRoute,
        if (returnArguments.isNotEmpty) 'return_arguments': returnArguments,
        'source_screen': sourceScreen,
        if (markerId != null && markerId!.isNotEmpty) 'marker_id': markerId,
        if (sessionId != null && sessionId!.isNotEmpty) 'session_id': sessionId,
        'created_at': createdAtUtc.toUtc().toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  /// Rebuilds an intent from storage. Returns null for anything malformed,
  /// unknown or unsafe so a corrupted preference can never drive navigation.
  static PendingActionIntent? fromJson(Map<String, Object?> json) {
    final actionType = PendingActionType.fromStorage(
      json['action_type']?.toString(),
    );
    final targetType = PendingActionTargetType.fromStorage(
      json['target_type']?.toString(),
    );
    if (actionType == null || targetType == null) return null;

    final targetId = _clip((json['target_id'] ?? '').toString(), _maxIdLength);
    if (targetId.isEmpty) return null;

    final returnRoute = (json['return_route'] ?? '').toString().trim();
    if (!isSafeInternalRoute(returnRoute)) return null;

    final createdAt = DateTime.tryParse((json['created_at'] ?? '').toString());
    if (createdAt == null) return null;

    final label =
        _clip((json['target_label'] ?? '').toString(), _maxLabelLength);
    final marker = _clip((json['marker_id'] ?? '').toString(), _maxIdLength);
    final session = _clip((json['session_id'] ?? '').toString(), _maxIdLength);
    final sourceScreen =
        _clip((json['source_screen'] ?? '').toString(), _maxLabelLength);

    return PendingActionIntent(
      actionType: actionType,
      targetType: targetType,
      targetId: targetId,
      targetLabel: label.isEmpty ? null : label,
      returnRoute: returnRoute,
      returnArguments: _sanitizeArguments(json['return_arguments']),
      sourceScreen: sourceScreen.isEmpty ? 'unknown' : sourceScreen,
      markerId: marker.isEmpty ? null : marker,
      sessionId: session.isEmpty ? null : session,
      createdAtUtc: createdAt.toUtc(),
    );
  }

  static PendingActionIntent? decode(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return fromJson(decoded.map((k, v) => MapEntry(k.toString(), v)));
    } catch (_) {
      return null;
    }
  }

  /// Builds a sanitised intent from call sites. Returns null when the caller
  /// supplied an unusable target or an unsafe route.
  static PendingActionIntent? create({
    required PendingActionType actionType,
    required PendingActionTargetType targetType,
    required String targetId,
    required String returnRoute,
    required String sourceScreen,
    String? targetLabel,
    String? markerId,
    String? sessionId,
    Map<String, String> returnArguments = const <String, String>{},
    DateTime? nowUtc,
  }) {
    final id = _clip(targetId, _maxIdLength);
    if (id.isEmpty) return null;
    final route = returnRoute.trim();
    if (!isSafeInternalRoute(route)) return null;

    final label = _clip(targetLabel ?? '', _maxLabelLength);
    final marker = _clip(markerId ?? '', _maxIdLength);
    final session = _clip(sessionId ?? '', _maxIdLength);

    return PendingActionIntent(
      actionType: actionType,
      targetType: targetType,
      targetId: id,
      targetLabel: label.isEmpty ? null : label,
      returnRoute: route,
      returnArguments: _sanitizeArguments(returnArguments),
      sourceScreen: _clip(sourceScreen, _maxLabelLength).isEmpty
          ? 'unknown'
          : _clip(sourceScreen, _maxLabelLength),
      markerId: marker.isEmpty ? null : marker,
      sessionId: session.isEmpty ? null : session,
      createdAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PendingActionIntent &&
      other.actionType == actionType &&
      other.targetType == targetType &&
      other.targetId == targetId &&
      other.returnRoute == returnRoute &&
      other.markerId == markerId &&
      other.createdAtUtc.toUtc() == createdAtUtc.toUtc();

  @override
  int get hashCode => Object.hash(
        actionType,
        targetType,
        targetId,
        returnRoute,
        markerId,
        createdAtUtc.toUtc(),
      );
}
