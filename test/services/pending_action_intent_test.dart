import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/services/pending_action_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingActionIntent _intent({
  String targetId = 'artwork-1',
  String returnRoute = '/a/artwork-1',
  DateTime? createdAt,
}) {
  return PendingActionIntent(
    actionType: PendingActionType.save,
    targetType: PendingActionTargetType.artwork,
    targetId: targetId,
    returnRoute: returnRoute,
    sourceScreen: 'map_marker',
    createdAtUtc: createdAt ?? DateTime.now().toUtc(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('return route safety', () {
    test('accepts local absolute paths', () {
      expect(PendingActionIntent.isSafeInternalRoute('/map'), isTrue);
      expect(PendingActionIntent.isSafeInternalRoute('/a/artwork-1'), isTrue);
      expect(PendingActionIntent.isSafeInternalRoute('/m/marker-9'), isTrue);
    });

    test('rejects anything that could become an open redirect', () {
      // Absolute URLs and scheme-relative paths are the classic vectors.
      expect(
        PendingActionIntent.isSafeInternalRoute('https://evil.example/map'),
        isFalse,
      );
      expect(
          PendingActionIntent.isSafeInternalRoute('//evil.example'), isFalse);
      expect(
        PendingActionIntent.isSafeInternalRoute('javascript:alert(1)'),
        isFalse,
      );
      expect(
          PendingActionIntent.isSafeInternalRoute(r'/\evil.example'), isFalse);
      expect(PendingActionIntent.isSafeInternalRoute('/../../etc/passwd'),
          isFalse);
      expect(PendingActionIntent.isSafeInternalRoute('map'), isFalse);
      expect(PendingActionIntent.isSafeInternalRoute(''), isFalse);
      expect(PendingActionIntent.isSafeInternalRoute(null), isFalse);
      expect(
        PendingActionIntent.isSafeInternalRoute('/${'x' * 400}'),
        isFalse,
      );
    });

    test('create returns null for an unsafe route or empty target', () {
      expect(
        PendingActionIntent.create(
          actionType: PendingActionType.save,
          targetType: PendingActionTargetType.artwork,
          targetId: 'artwork-1',
          returnRoute: 'https://evil.example',
          sourceScreen: 'map',
        ),
        isNull,
      );
      expect(
        PendingActionIntent.create(
          actionType: PendingActionType.save,
          targetType: PendingActionTargetType.artwork,
          targetId: '   ',
          returnRoute: '/map',
          sourceScreen: 'map',
        ),
        isNull,
      );
    });
  });

  group('serialisation', () {
    test('round-trips through storage', () {
      final intent = PendingActionIntent.create(
        actionType: PendingActionType.follow,
        targetType: PendingActionTargetType.user,
        targetId: 'wallet-1',
        targetLabel: 'Ana Novak',
        returnRoute: '/u/wallet-1',
        sourceScreen: 'user_profile',
        markerId: 'marker-3',
        sessionId: 'session-1',
        returnArguments: <String, String>{'tab': 'about'},
      )!;

      final decoded = PendingActionIntent.decode(intent.encode())!;

      expect(decoded.actionType, PendingActionType.follow);
      expect(decoded.targetType, PendingActionTargetType.user);
      expect(decoded.targetId, 'wallet-1');
      expect(decoded.targetLabel, 'Ana Novak');
      expect(decoded.returnRoute, '/u/wallet-1');
      expect(decoded.markerId, 'marker-3');
      expect(decoded.sessionId, 'session-1');
      expect(decoded.returnArguments['tab'], 'about');
    });

    test('rejects corrupt, unknown or unsafe stored values', () {
      expect(PendingActionIntent.decode('not json'), isNull);
      expect(PendingActionIntent.decode('[]'), isNull);
      expect(
        PendingActionIntent.decode(
          '{"action_type":"transfer_funds","target_type":"artwork","target_id":"a",'
          '"return_route":"/a/a","created_at":"2026-07-30T00:00:00Z"}',
        ),
        isNull,
      );
      // A tampered route must not survive a round trip.
      expect(
        PendingActionIntent.decode(
          '{"action_type":"save","target_type":"artwork","target_id":"a",'
          '"return_route":"https://evil.example","created_at":"2026-07-30T00:00:00Z"}',
        ),
        isNull,
      );
    });

    test('drops oversized and non-string route arguments', () {
      final intent = PendingActionIntent.create(
        actionType: PendingActionType.save,
        targetType: PendingActionTargetType.artwork,
        targetId: 'artwork-1',
        returnRoute: '/a/artwork-1',
        sourceScreen: 'map',
        returnArguments: <String, String>{
          'a': '1',
          'b': '2',
          'c': '3',
          'd': '4',
          'e': '5',
          'f': '6',
          'g': '7',
          'h': '8',
        },
      )!;

      expect(intent.returnArguments.length, lessThanOrEqualTo(6));
    });

    test('never stores anything credential-shaped', () {
      final intent = _intent();
      final json = intent.toJson();
      for (final key in json.keys) {
        expect(
          key,
          isNot(anyOf(
            contains('password'),
            contains('token'),
            contains('secret'),
            contains('mnemonic'),
            contains('email'),
            contains('lat'),
            contains('lng'),
          )),
        );
      }
    });
  });

  group('expiry', () {
    test('is live inside the TTL', () {
      final intent = _intent(
        createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );
      expect(intent.isExpired, isFalse);
    });

    test('expires after the TTL', () {
      final intent = _intent(
        createdAt: DateTime.now().toUtc().subtract(
              PendingActionIntent.ttl + const Duration(minutes: 1),
            ),
      );
      expect(intent.isExpired, isTrue);
    });
  });

  group('PendingActionService', () {
    const service = PendingActionService();

    test('saves and reads back a valid intent', () async {
      final intent = _intent();
      expect(await service.save(intent), isTrue);

      final read = await service.read();
      expect(read, isNotNull);
      expect(read!.targetId, 'artwork-1');
    });

    test('drops an expired intent on read instead of returning it', () async {
      final stale = _intent(
        createdAt: DateTime.now().toUtc().subtract(
              PendingActionIntent.ttl + const Duration(hours: 1),
            ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PendingActionService.storageKey, stale.encode());

      expect(await service.read(), isNull);
      // ...and the stale value is cleared, not left to be re-read.
      expect(prefs.getString(PendingActionService.storageKey), isNull);
    });

    test('drops a corrupted stored value', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PendingActionService.storageKey, '{{{not json');

      expect(await service.read(), isNull);
      expect(prefs.getString(PendingActionService.storageKey), isNull);
    });

    test('marks completion so the same action cannot run twice', () async {
      final intent = _intent();
      await service.save(intent);
      expect(await service.isCompleted(intent), isFalse);

      await service.markCompleted(intent);

      expect(await service.isCompleted(intent), isTrue);
      expect(await service.read(), isNull);
    });

    test('saving a fresh intent clears a previous completion marker', () async {
      final intent = _intent();
      await service.markCompleted(intent);
      expect(await service.isCompleted(intent), isTrue);

      await service.save(intent);

      // A deliberately re-captured intent must be actionable again.
      expect(await service.isCompleted(intent), isFalse);
    });

    test('refuses to store an invalid intent', () async {
      final invalid = PendingActionIntent(
        actionType: PendingActionType.save,
        targetType: PendingActionTargetType.artwork,
        targetId: '',
        returnRoute: '/a/x',
        sourceScreen: 'map',
        createdAtUtc: DateTime.now().toUtc(),
      );

      expect(await service.save(invalid), isFalse);
      expect(await service.read(), isNull);
    });
  });
}
