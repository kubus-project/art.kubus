import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../services/backend_api_service.dart';

class AttendanceProximitySnapshot {
  final double lat;
  final double lng;
  final double distanceMeters;
  final double activationRadiusMeters;
  final bool requiresProximity;
  final double? accuracyMeters;
  final int timestampMs;
  final DateTime observedAt;

  const AttendanceProximitySnapshot({
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.activationRadiusMeters,
    required this.requiresProximity,
    required this.timestampMs,
    required this.observedAt,
    this.accuracyMeters,
  });

  bool get withinRadius {
    if (!requiresProximity) return true;
    return distanceMeters <= activationRadiusMeters;
  }

  Map<String, dynamic> toClientLocationPayload() {
    return <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'timestampMs': timestampMs,
      if (accuracyMeters != null) 'accuracy': accuracyMeters,
    };
  }
}

class AttendanceChallengeDto {
  final String markerId;
  final bool alreadyAttended;
  final DateTime? attendedAt;
  final String challengeToken;
  final DateTime expiresAt;

  const AttendanceChallengeDto({
    required this.markerId,
    required this.alreadyAttended,
    required this.challengeToken,
    required this.expiresAt,
    this.attendedAt,
  });

  factory AttendanceChallengeDto.fromApi(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? Map<String, dynamic>.from(json['data'] as Map) : json;
    final expiresRaw = (data['expiresAt'] ?? data['expires_at'])?.toString();
    final attendedAtRaw = (data['attendedAt'] ?? data['attended_at'])?.toString();
    return AttendanceChallengeDto(
      markerId: (data['markerId'] ?? data['marker_id'] ?? '').toString(),
      alreadyAttended: (data['alreadyAttended'] ?? data['already_attended']) == true,
      attendedAt: attendedAtRaw != null ? DateTime.tryParse(attendedAtRaw) : null,
      challengeToken: (data['challengeToken'] ?? data['challenge_token'] ?? '').toString(),
      expiresAt: expiresRaw != null
          ? (DateTime.tryParse(expiresRaw) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class AttendanceConfirmDto {
  final bool attendanceRecorded;
  final bool viewedAdded;
  final bool discoveryPathUpdated;
  final List<dynamic> achievementsUnlocked;
  final Map<String, dynamic>? poap;
  final Map<String, dynamic>? kub8;
  final Map<String, dynamic>? subject;

  const AttendanceConfirmDto({
    required this.attendanceRecorded,
    required this.viewedAdded,
    required this.discoveryPathUpdated,
    required this.achievementsUnlocked,
    this.poap,
    this.kub8,
    this.subject,
  });

  factory AttendanceConfirmDto.fromApi(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? Map<String, dynamic>.from(json['data'] as Map) : json;
    return AttendanceConfirmDto(
      attendanceRecorded: data['attendanceRecorded'] == true,
      viewedAdded: data['viewedAdded'] == true,
      discoveryPathUpdated: data['discoveryPathUpdated'] == true,
      achievementsUnlocked: (data['achievementsUnlocked'] is List)
          ? List<dynamic>.from(data['achievementsUnlocked'] as List)
          : const <dynamic>[],
      poap: (data['poap'] is Map) ? Map<String, dynamic>.from(data['poap'] as Map) : null,
      kub8: (data['kub8'] is Map) ? Map<String, dynamic>.from(data['kub8'] as Map) : null,
      subject: (data['subject'] is Map) ? Map<String, dynamic>.from(data['subject'] as Map) : null,
    );
  }
}

class AttendanceMarkerState {
  AttendanceProximitySnapshot? proximity;
  AttendanceChallengeDto? challenge;
  AttendanceConfirmDto? lastConfirm;
  bool isFetchingChallenge = false;
  bool isConfirming = false;
  String? lastError;

  bool get hasFreshProximity {
    final snapshot = proximity;
    if (snapshot == null) return false;
    final age = DateTime.now().difference(snapshot.observedAt);
    return age.inSeconds <= 90;
  }

  bool get canAttemptConfirm {
    final snapshot = proximity;
    if (snapshot == null) return false;
    if (!hasFreshProximity) return false;
    return snapshot.withinRadius;
  }
}

class AttendanceProvider extends ChangeNotifier {
  final BackendApiService _api;
  final Map<String, AttendanceMarkerState> _statesByMarkerId = <String, AttendanceMarkerState>{};

  bool _isSignedIn = false;
  String? _walletAddress;

  AttendanceProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  void bindAuthContext({
    required bool isSignedIn,
    required String? walletAddress,
  }) {
    final normalizedWallet = (walletAddress ?? '').trim();
    final walletChanged = (_walletAddress ?? '') != normalizedWallet;
    final signedInChanged = _isSignedIn != isSignedIn;

    _isSignedIn = isSignedIn;
    _walletAddress = normalizedWallet;

    if (walletChanged || (!isSignedIn && signedInChanged)) {
      // Keep proximity snapshots (they are map-driven), but clear any
      // user-specific challenge/confirm state to avoid cross-session leakage.
      for (final entry in _statesByMarkerId.entries) {
        entry.value.challenge = null;
        entry.value.lastConfirm = null;
        entry.value.isFetchingChallenge = false;
        entry.value.isConfirming = false;
        entry.value.lastError = null;
      }
      if (hasListeners) notifyListeners();
    }
  }

  AttendanceMarkerState stateFor(String markerId) {
    final id = markerId.trim();
    return _statesByMarkerId.putIfAbsent(id, () => AttendanceMarkerState());
  }

  AttendanceProximitySnapshot? proximityFor(String markerId) =>
      stateFor(markerId).proximity;

  void updateProximity({
    required String markerId,
    required double lat,
    required double lng,
    required double distanceMeters,
    required double activationRadiusMeters,
    required bool requiresProximity,
    double? accuracyMeters,
    int? timestampMs,
  }) {
    final id = markerId.trim();
    if (id.isEmpty) return;
    final state = stateFor(id);
    final previous = state.proximity;
    final next = AttendanceProximitySnapshot(
      lat: lat,
      lng: lng,
      distanceMeters: distanceMeters,
      activationRadiusMeters: activationRadiusMeters,
      requiresProximity: requiresProximity,
      accuracyMeters: accuracyMeters,
      timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      observedAt: DateTime.now(),
    );

    state.proximity = next;

    final shouldNotify = () {
      if (!hasListeners) return false;
      if (previous == null) return true;
      if (previous.withinRadius != next.withinRadius) return true;
      if ((previous.distanceMeters - next.distanceMeters).abs() >= 5.0) return true;
      return false;
    }();

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<AttendanceChallengeDto?> ensureChallenge(String markerId) async {
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return null;
    }
    final id = markerId.trim();
    if (id.isEmpty) return null;
    if (!_isSignedIn) return null;

    final state = stateFor(id);
    final existing = state.challenge;
    if (existing != null && !existing.isExpired) {
      return existing;
    }

    if (state.isFetchingChallenge) return state.challenge;

    state.isFetchingChallenge = true;
    state.lastError = null;
    if (hasListeners) notifyListeners();

    try {
      final raw = await _api.getAttendanceChallenge(
        markerId: id,
        walletAddress: _walletAddress,
      );
      final dto = AttendanceChallengeDto.fromApi(raw);
      state.challenge = dto;
      return dto;
    } catch (e) {
      state.lastError = e.toString();
      if (kDebugMode) {
        AppConfig.debugPrint('AttendanceProvider.ensureChallenge failed: $e');
      }
      rethrow;
    } finally {
      state.isFetchingChallenge = false;
      if (hasListeners) notifyListeners();
    }
  }

  Future<AttendanceConfirmDto?> confirmAttendance(String markerId) async {
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return null;
    }
    final id = markerId.trim();
    if (id.isEmpty) return null;
    if (!_isSignedIn) return null;

    final state = stateFor(id);
    if (state.isConfirming) return state.lastConfirm;

    final snapshot = state.proximity;
    if (snapshot == null) return null;

    // Client-side guard to avoid unnecessary requests when we know it's invalid.
    if (snapshot.requiresProximity && (!state.hasFreshProximity || !snapshot.withinRadius)) {
      return null;
    }

    final challenge = await ensureChallenge(id);
    if (challenge == null) return null;
    if (challenge.alreadyAttended) {
      return state.lastConfirm;
    }

    state.isConfirming = true;
    state.lastError = null;
    if (hasListeners) notifyListeners();

    try {
      final raw = await _api.confirmAttendance(
        markerId: id,
        challengeToken: challenge.challengeToken,
        clientLocation: snapshot.toClientLocationPayload(),
        walletAddress: _walletAddress,
      );
      final dto = AttendanceConfirmDto.fromApi(raw);
      state.lastConfirm = dto;

      // Mark locally as attended so the UI can become idempotent immediately.
      state.challenge = AttendanceChallengeDto(
        markerId: id,
        alreadyAttended: true,
        attendedAt: challenge.attendedAt ?? DateTime.now().toUtc(),
        challengeToken: challenge.challengeToken,
        expiresAt: challenge.expiresAt,
      );

      return dto;
    } catch (e) {
      state.lastError = e.toString();
      if (kDebugMode) {
        AppConfig.debugPrint('AttendanceProvider.confirmAttendance failed: $e');
      }
      rethrow;
    } finally {
      state.isConfirming = false;
      if (hasListeners) notifyListeners();
    }
  }
}

