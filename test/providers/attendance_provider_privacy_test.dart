import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _AttendanceApi implements BackendApiService {
  Map<String, dynamic>? location;
  int confirms = 0;
  int challenges = 0;
  bool rejectChallenge = false;

  @override
  Future<Map<String, dynamic>> getAttendanceChallenge({
    required String markerId,
    String? walletAddress,
  }) async {
    challenges++;
    if (rejectChallenge) throw StateError('synthetic challenge rejected');
    return <String, dynamic>{
      'markerId': markerId,
      'challengeToken': 'synthetic-challenge',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> confirmAttendance({
    required String markerId,
    required String challengeToken,
    required Map<String, dynamic> clientLocation,
    String? walletAddress,
  }) async {
    confirms++;
    location = clientLocation;
    expect(markerId, 'synthetic-marker');
    expect(challengeToken, 'synthetic-challenge');
    return <String, dynamic>{'attendanceRecorded': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('optional proximity still requires account authentication', () async {
    final api = _AttendanceApi();
    final provider = AttendanceProvider(api: api)
      ..updateProximity(
        markerId: 'synthetic-marker',
        lat: 1,
        lng: 2,
        distanceMeters: 1000,
        activationRadiusMeters: 50,
        requiresProximity: false,
      );
    addTearDown(provider.dispose);

    expect(await provider.confirmAttendance('synthetic-marker'), isNull);
    expect(api.challenges, 0);
    expect(api.confirms, 0);
  });

  test('optional proximity cannot bypass a rejected challenge', () async {
    final api = _AttendanceApi()..rejectChallenge = true;
    final provider = AttendanceProvider(api: api)
      ..bindAuthContext(isSignedIn: true, walletAddress: null)
      ..updateProximity(
        markerId: 'synthetic-marker',
        lat: 1,
        lng: 2,
        distanceMeters: 1000,
        activationRadiusMeters: 50,
        requiresProximity: false,
      );
    addTearDown(provider.dispose);

    await expectLater(provider.confirmAttendance('synthetic-marker'),
        throwsA(isA<StateError>()));
    expect(api.challenges, 1);
    expect(api.confirms, 0);
  });

  for (final requiresProximity in <bool>[false, true]) {
    test('confirm discloses location only when proximity is $requiresProximity',
        () async {
      final api = _AttendanceApi();
      final provider = AttendanceProvider(api: api)
        ..bindAuthContext(isSignedIn: true, walletAddress: null)
        ..updateProximity(
          markerId: 'synthetic-marker',
          lat: 1.25,
          lng: 2.5,
          distanceMeters: requiresProximity ? 10 : 1000,
          activationRadiusMeters: 50,
          requiresProximity: requiresProximity,
          accuracyMeters: 4,
          timestampMs: 123456789,
        );
      addTearDown(provider.dispose);

      expect(
          (await provider.confirmAttendance('synthetic-marker'))
              ?.attendanceRecorded,
          isTrue);
      expect(
          api.location,
          requiresProximity
              ? <String, dynamic>{
                  'lat': 1.25,
                  'lng': 2.5,
                  'timestampMs': 123456789,
                  'accuracy': 4.0
                }
              : isEmpty);
      await provider.confirmAttendance('synthetic-marker');
      expect(api.confirms, 1,
          reason: 'successful attendance remains idempotent');
    });
  }

  test('required proximity still blocks out-of-radius or stale observations',
      () async {
    final api = _AttendanceApi();
    final provider = AttendanceProvider(api: api)
      ..bindAuthContext(isSignedIn: true, walletAddress: null)
      ..updateProximity(
          markerId: 'synthetic-marker',
          lat: 1,
          lng: 2,
          distanceMeters: 100,
          activationRadiusMeters: 50,
          requiresProximity: true);
    addTearDown(provider.dispose);
    expect(await provider.confirmAttendance('synthetic-marker'), isNull);
    provider.stateFor('synthetic-marker').proximity =
        AttendanceProximitySnapshot(
      lat: 1,
      lng: 2,
      distanceMeters: 10,
      activationRadiusMeters: 50,
      requiresProximity: true,
      timestampMs: 123456789,
      observedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    expect(await provider.confirmAttendance('synthetic-marker'), isNull);
    expect(api.confirms, 0);
  });
}
