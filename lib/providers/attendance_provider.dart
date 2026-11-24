import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/attestation.dart';
import 'profile_provider.dart';
import '../services/account_identity.dart';
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
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final expiresRaw = (data['expiresAt'] ?? data['expires_at'])?.toString();
    final attendedAtRaw =
        (data['attendedAt'] ?? data['attended_at'])?.toString();
    return AttendanceChallengeDto(
      markerId: (data['markerId'] ?? data['marker_id'] ?? '').toString(),
      alreadyAttended:
          (data['alreadyAttended'] ?? data['already_attended']) == true,
      attendedAt:
          attendedAtRaw != null ? DateTime.tryParse(attendedAtRaw) : null,
      challengeToken:
          (data['challengeToken'] ?? data['challenge_token'] ?? '').toString(),
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
  final List<UnifiedAttestation> attestations;
  final Map<String, dynamic>? poap;
  final Map<String, dynamic>? kub8;
  final Map<String, dynamic>? subject;

  const AttendanceConfirmDto({
    required this.attendanceRecorded,
    required this.viewedAdded,
    required this.discoveryPathUpdated,
    required this.achievementsUnlocked,
    required this.attestations,
    this.poap,
    this.kub8,
    this.subject,
  });

  factory AttendanceConfirmDto.fromApi(Map<String, dynamic> json) {
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final parsedAttestations = () {
      final raw = data['attestations'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) =>
                UnifiedAttestation.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }

      // Backward compatibility for older payloads that only returned
      // attendance/POAP/achievement fields.
      final poap = (data['poap'] is Map)
          ? Map<String, dynamic>.from(data['poap'] as Map)
          : null;
      final subject = (data['subject'] is Map)
          ? Map<String, dynamic>.from(data['subject'] as Map)
          : null;
      final markerId = (subject?['markerId'] ?? '').toString();
      final subjectType = (subject?['subjectType'] ?? 'art_marker').toString();
      final subjectId = (subject?['subjectId'] ?? markerId).toString();

      final fallback = <UnifiedAttestation>[];
      if (markerId.isNotEmpty) {
        fallback.add(
          UnifiedAttestation.fromJson(<String, dynamic>{
            'id': 'attendance:$markerId',
            'type': 'attendance',
            'subjectType': subjectType,
            'subjectId': subjectId,
            'status':
                data['attendanceRecorded'] == true ? 'recorded' : 'idempotent',
            'usage': const <String>['trust', 'eligibility', 'discovery'],
            'mint': const <String, dynamic>{
              'eligible': false,
              'policy': 'none',
              'status': 'not_minted',
            },
            'metadata': <String, dynamic>{
              'attendanceRecorded': data['attendanceRecorded'] == true,
              'viewedAdded': data['viewedAdded'] == true,
            },
          }),
        );
      }
      if (poap != null) {
        final status = (poap['status'] ?? '').toString().trim();
        if (status.isNotEmpty &&
            status != 'none' &&
            status != 'not_configured') {
          fallback.add(
            UnifiedAttestation.fromJson(<String, dynamic>{
              'id': 'poap:${poap['eventId'] ?? markerId}',
              'type': 'participation_proof',
              'subjectType': 'event_drop',
              'subjectId': (poap['eventId'] ?? markerId).toString(),
              'status': status,
              'usage': const <String>['trust', 'visibility', 'discovery'],
              'mint': <String, dynamic>{
                'eligible': poap['eventId'] != null ||
                    (poap['claimUrl']?.toString().isNotEmpty ?? false),
                'policy': 'optional',
                'status': status == 'claimed' ? 'minted' : 'not_minted',
              },
              'metadata': poap,
            }),
          );
        }
      }
      return fallback;
    }();

    return AttendanceConfirmDto(
      attendanceRecorded: data['attendanceRecorded'] == true,
      viewedAdded: data['viewedAdded'] == true,
      discoveryPathUpdated: data['discoveryPathUpdated'] == true,
      achievementsUnlocked: (data['achievementsUnlocked'] is List)
          ? List<dynamic>.from(data['achievementsUnlocked'] as List)
          : const <dynamic>[],
      attestations: parsedAttestations,
      poap: (data['poap'] is Map)
          ? Map<String, dynamic>.from(data['poap'] as Map)
          : null,
      kub8: (data['kub8'] is Map)
          ? Map<String, dynamic>.from(data['kub8'] as Map)
          : null,
      subject: (data['subject'] is Map)
          ? Map<String, dynamic>.from(data['subject'] as Map)
          : null,
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
  final Map<String, AttendanceMarkerState> _statesByMarkerId =
      <String, AttendanceMarkerState>{};

  // The owner of "who is signed in", and the wallet handed in with it. The
  // wallet is kept only to reset per-account state when it changes.
  ProfileProvider? _identityOwner;
  String? _walletAddress;

  // The account the user-specific state belongs to. A walletless switch leaves
  // the wallet empty on both sides, so only the account identity can tell two
  // accounts apart. A same-account change (wallet link, token refresh) keeps it.
  String _identityKey = AccountIdentity.accountKey;

  // Bumped whenever user-scoped state is cleared. A challenge fetch started
  // before a bump belongs to the account or wallet that was cleared, so when it
  // returns it must not write into the state of the current one.
  int _identityEpoch = 0;

  AttendanceProvider({BackendApiService? api})
      : _api = api ?? BackendApiService() {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
    super.dispose();
  }

  void bindAuthContext({
    required ProfileProvider identityOwner,
    required String? walletAddress,
  }) {
    _identityOwner = identityOwner;
    final isSignedIn = identityOwner.isSignedIn;
    final normalizedWallet = (walletAddress ?? '').trim();
    final accountKey = AccountIdentity.accountKey;
    // Linking a wallet to the account already signed in changes nothing the
    // account owns, and must not drop its in-flight confirm.
    final walletLinkedToSameAccount = (_walletAddress ?? '').isEmpty &&
        normalizedWallet.isNotEmpty &&
        isSignedIn &&
        accountKey.isNotEmpty &&
        accountKey == _identityKey;
    final walletChanged = (_walletAddress ?? '') != normalizedWallet &&
        !walletLinkedToSameAccount;

    _walletAddress = normalizedWallet;

    if (walletChanged || (!isSignedIn && _hasUserScopedState)) {
      _clearUserScopedState();
      if (hasListeners) notifyListeners();
    }
  }

  void _handleAccountIdentityChanged() {
    final key = AccountIdentity.accountKey;
    // An empty key (sign-out) always clears: a silent guest to account
    // sign-in leaves the held key empty while signed in.
    if (key.isNotEmpty && key == _identityKey) return;
    _identityKey = key;
    _clearUserScopedState();
    if (hasListeners) notifyListeners();
  }

  bool get _hasUserScopedState => _statesByMarkerId.values.any((state) =>
      state.challenge != null ||
      state.lastConfirm != null ||
      state.isFetchingChallenge ||
      state.isConfirming ||
      state.lastError != null);

  void _clearUserScopedState() {
    _identityEpoch += 1;
    // Keep proximity snapshots (they are map-driven), but clear any
    // user-specific challenge/confirm state to avoid cross-session leakage.
    for (final entry in _statesByMarkerId.entries) {
      entry.value.challenge = null;
      entry.value.lastConfirm = null;
      entry.value.isFetchingChallenge = false;
      entry.value.isConfirming = false;
      entry.value.lastError = null;
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
      if ((previous.distanceMeters - next.distanceMeters).abs() >= 5.0) {
        return true;
      }
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
    if (!(_identityOwner?.isSignedIn ?? false)) return null;

    final state = stateFor(id);
    final existing = state.challenge;
    if (existing != null && !existing.isExpired) {
      return existing;
    }

    if (state.isFetchingChallenge) return state.challenge;

    final epoch = _identityEpoch;
    state.isFetchingChallenge = true;
    state.lastError = null;
    if (hasListeners) notifyListeners();

    try {
      final raw = await _api.getAttendanceChallenge(
        markerId: id,
        walletAddress: _walletAddress,
      );
      // Issued under a previous account: neither kept nor handed to the
      // current one, which then asks for its own challenge.
      if (epoch != _identityEpoch) return null;
      final dto = AttendanceChallengeDto.fromApi(raw);
      state.challenge = dto;
      return dto;
    } catch (e) {
      if (epoch != _identityEpoch) return null;
      state.lastError = e.toString();
      if (kDebugMode) {
        AppConfig.debugPrint('AttendanceProvider.ensureChallenge failed: $e');
      }
      rethrow;
    } finally {
      // A stale fetch must not clear the flags of a fetch the current account
      // started for the same marker after the switch.
      if (epoch == _identityEpoch) {
        state.isFetchingChallenge = false;
        if (hasListeners) notifyListeners();
      }
    }
  }

  Future<AttendanceConfirmDto?> confirmAttendance(String markerId) async {
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return null;
    }
    final id = markerId.trim();
    if (id.isEmpty) return null;
    if (!(_identityOwner?.isSignedIn ?? false)) return null;

    final state = stateFor(id);
    if (state.isConfirming) return state.lastConfirm;

    final snapshot = state.proximity;
    if (snapshot == null) return null;

    // Client-side guard to avoid unnecessary requests when we know it's invalid.
    if (snapshot.requiresProximity &&
        (!state.hasFreshProximity || !snapshot.withinRadius)) {
      return null;
    }

    final challenge = await ensureChallenge(id);
    if (challenge == null) return null;
    if (challenge.alreadyAttended) {
      return state.lastConfirm;
    }

    final epoch = _identityEpoch;
    state.isConfirming = true;
    state.lastError = null;
    if (hasListeners) notifyListeners();

    try {
      final raw = await _api.confirmAttendance(
        markerId: id,
        challengeToken: challenge.challengeToken,
        // Only disclose location when the marker requires proximity proof.
        // The server still decides whether that proof is required and valid.
        clientLocation: snapshot.requiresProximity
            ? snapshot.toClientLocationPayload()
            : const <String, dynamic>{},
        walletAddress: _walletAddress,
      );
      // Confirmed under a previous account: nothing is recorded for the
      // current one.
      if (epoch != _identityEpoch) return null;
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
      if (epoch != _identityEpoch) return null;
      state.lastError = e.toString();
      if (kDebugMode) {
        AppConfig.debugPrint('AttendanceProvider.confirmAttendance failed: $e');
      }
      rethrow;
    } finally {
      // A stale confirm must not clear the flag of a confirm the current
      // account started for the same marker after the switch.
      if (epoch == _identityEpoch) {
        state.isConfirming = false;
        if (hasListeners) notifyListeners();
      }
    }
  }
}
