import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _markerPayload({
  String name = 'Updated',
  String description = 'desc',
  double latitude = 46.05,
  double longitude = 14.5,
  String markerType = 'artwork',
  String category = 'General',
  bool isPublic = true,
  bool isActive = true,
  bool requiresProximity = true,
  double activationRadius = 50,
  Map<String, dynamic>? metadata,
}) {
  return <String, dynamic>{
    'id': 'm1',
    'name': name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'markerType': markerType,
    'type': 'geolocation',
    'category': category,
    'metadata': metadata ?? const <String, dynamic>{},
    'activationRadius': activationRadius,
    'requiresProximity': requiresProximity,
    'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
    'createdBy': 'wallet_1',
    'isPublic': isPublic,
    'isActive': isActive,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
      'updateArtMarkerRecord treats 204 as success and resolves marker via GET fallback',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');

    int putCalls = 0;
    int getCalls = 0;

    api.setHttpClient(MockClient((request) async {
      if (request.method.toUpperCase() == 'PUT' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        putCalls += 1;
        return http.Response('', 204);
      }

      if (request.method.toUpperCase() == 'GET' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        getCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': _markerPayload(name: 'New'),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('Unexpected request', 500);
    }));

    final updated =
        await api.updateArtMarkerRecord('m1', <String, dynamic>{'name': 'New'});

    expect(updated, isNotNull);
    expect(updated!.name, 'New');
    expect(putCalls, 1);
    expect(getCalls, 1);
  });

  test(
      'updateArtMarkerRecord falls back to GET when 200 response has no marker payload',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');

    int putCalls = 0;
    int getCalls = 0;

    api.setHttpClient(MockClient((request) async {
      if (request.method.toUpperCase() == 'PUT' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        putCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'message': 'updated'}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method.toUpperCase() == 'GET' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        getCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': _markerPayload(name: 'New'),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('Unexpected request', 500);
    }));

    final updated =
        await api.updateArtMarkerRecord('m1', <String, dynamic>{'name': 'New'});

    expect(updated, isNotNull);
    expect(updated!.name, 'New');
    expect(putCalls, 1);
    expect(getCalls, 1);
  });

  test('updateArtMarkerRecord accepts full marker payload from PUT response',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');

    int putCalls = 0;
    int getCalls = 0;
    final updates = <String, dynamic>{
      'name': 'Edited marker',
      'description': 'Edited description',
      'category': 'Event',
      'latitude': 46.11,
      'longitude': 14.66,
      'markerType': 'event',
      'isPublic': false,
      'isActive': false,
      'requiresProximity': false,
      'activationRadius': 75,
      'metadata': <String, dynamic>{'subjectType': 'event'},
    };

    api.setHttpClient(MockClient((request) async {
      if (request.method.toUpperCase() == 'PUT' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        putCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': _markerPayload(
              name: 'Edited marker',
              description: 'Edited description',
              latitude: 46.11,
              longitude: 14.66,
              markerType: 'event',
              category: 'Event',
              isPublic: false,
              isActive: false,
              requiresProximity: false,
              activationRadius: 75,
              metadata: <String, dynamic>{'subjectType': 'event'},
            ),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method.toUpperCase() == 'GET' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        getCalls += 1;
        return http.Response('Unexpected fallback', 500);
      }

      return http.Response('Unexpected request', 500);
    }));

    final updated = await api.updateArtMarkerRecord('m1', updates);

    expect(updated, isNotNull);
    expect(updated!.name, 'Edited marker');
    expect(updated.description, 'Edited description');
    expect(updated.position.latitude, 46.11);
    expect(updated.position.longitude, 14.66);
    expect(updated.category, 'Event');
    expect(updated.isPublic, isFalse);
    expect(updated.isActive, isFalse);
    expect(updated.requiresProximity, isFalse);
    expect(updated.activationRadius, 75);
    expect(updated.metadata?['subjectType'], 'event');
    expect(putCalls, 1);
    expect(getCalls, 0);
  });

  test(
      'updateArtMarkerRecord throws when authoritative read does not reflect requested updates',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');

    int putCalls = 0;
    int getCalls = 0;

    api.setHttpClient(MockClient((request) async {
      if (request.method.toUpperCase() == 'PUT' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        putCalls += 1;
        return http.Response('', 204);
      }

      if (request.method.toUpperCase() == 'GET' &&
          request.url.path.endsWith('/api/art-markers/m1')) {
        getCalls += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': _markerPayload(name: 'StaleName'),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('Unexpected request', 500);
    }));

    await expectLater(
      api.updateArtMarkerRecord('m1', <String, dynamic>{'name': 'New'}),
      throwsA(isA<BackendApiRequestException>()),
    );
    expect(putCalls, 1);
    expect(getCalls, 1);
  });
}
