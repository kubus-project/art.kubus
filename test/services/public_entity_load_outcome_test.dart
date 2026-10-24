import 'dart:async';
import 'dart:io';

import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/public_entity_load_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('classifyPublicEntityLoadError', () {
    test('a 404 is an answer: the entity is not found', () {
      final outcome = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        const BackendApiRequestException(
          statusCode: 404,
          path: '/api/profiles/p1',
        ),
      );
      expect(outcome, isA<PublicEntityNotFound<ProfileCriticalPackage>>());

      final fromMessage = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        Exception('Request failed: 404'),
      );
      expect(fromMessage, isA<PublicEntityNotFound<ProfileCriticalPackage>>());
    });

    test(
        'other 4xx answers (for example a refused private entity) are not found',
        () {
      final outcome = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        Exception('Request failed: 403'),
      );
      expect(outcome, isA<PublicEntityNotFound<ProfileCriticalPackage>>());
    });

    test('a 429 from the API is transient', () {
      final fromMessage = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        Exception('Request failed: 429'),
      );
      expect(fromMessage,
          isA<PublicEntityTransientFailure<ProfileCriticalPackage>>());
      final fromRequest = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        const BackendApiRequestException(
          statusCode: 429,
          path: '/api/art-markers/m1',
        ),
      );
      expect(fromRequest, isA<PublicEntityTransientFailure>());
      expect(
        (fromRequest as PublicEntityTransientFailure).statusCode,
        429,
      );
    });

    test('the rate-limit message thrown by the local limiter is transient', () {
      final outcome = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        Exception('Rate limit exceeded. Please retry in ~4m 10s.'),
      );
      expect(outcome, isA<PublicEntityTransientFailure>());
    });

    test('408, 5xx and gateway failures are transient', () {
      for (final status in <int>[408, 500, 502, 503, 504]) {
        final outcome = classifyPublicEntityLoadError<ProfileCriticalPackage>(
          Exception('Request failed: $status'),
        );
        expect(outcome, isA<PublicEntityTransientFailure>(),
            reason: 'status $status');
      }
    });

    test('a transport failure with no status is transient', () {
      final errors = <Object>[
        const SocketException('connection refused'),
        http.ClientException('Failed host lookup'),
        TimeoutException('timed out'),
        const BackendApiRequestException(statusCode: 0, path: '/api/x'),
        Exception('Request failed for https://api/x: SocketException'),
      ];
      for (final error in errors) {
        expect(
          classifyPublicEntityLoadError<ProfileCriticalPackage>(error),
          isA<PublicEntityTransientFailure>(),
          reason: '$error',
        );
      }
    });

    test('an unrecognised error is transient, never a missing entity', () {
      final outcome = classifyPublicEntityLoadError<ProfileCriticalPackage>(
        StateError('unexpected payload'),
      );
      expect(outcome, isA<PublicEntityTransientFailure>());
    });
  });

  group('PublicEntityLoadOutcome', () {
    test('valueOrNull yields the value only for a found outcome', () {
      expect(const PublicEntityFound<String>('a').valueOrNull, 'a');
      expect(const PublicEntityNotFound<String>().valueOrNull, isNull);
      expect(
        const PublicEntityTransientFailure<String>(reason: 'rate limited')
            .valueOrNull,
        isNull,
      );
    });
  });
}
