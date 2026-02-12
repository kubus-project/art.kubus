import 'dart:async';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/map_marker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeMarkerApi implements MarkerBackendApi {
  // ignore: unused_element_parameter
  _FakeMarkerApi({this.token = 'token'});

  @override
  String? getAuthToken() => token;

  String token;

  int getMyCalls = 0;
  Completer<List<ArtMarker>>? getMyCompleter;
  List<ArtMarker> getMyResult = const <ArtMarker>[];

  int createCalls = 0;
  Completer<ArtMarker?>? createCompleter;
  ArtMarker? createResult;

  int updateCalls = 0;
  Completer<ArtMarker?>? updateCompleter;

  int deleteCalls = 0;
  Completer<bool>? deleteCompleter;

  @override
  Future<List<ArtMarker>> getMyArtMarkers() {
    getMyCalls += 1;
    final c = getMyCompleter;
    if (c != null) return c.future;
    return Future.value(getMyResult);
  }

  @override
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload) async {
    createCalls += 1;
    final c = createCompleter;
    if (c != null) return c.future;
    return Future.value(createResult);
  }

  @override
  Future<ArtMarker?> updateArtMarkerRecord(
      String markerId, Map<String, dynamic> updates) {
    updateCalls += 1;
    final c = updateCompleter;
    if (c != null) return c.future;
    return Future.value(null);
  }

  @override
  Future<bool> deleteArtMarkerRecord(String markerId) {
    deleteCalls += 1;
    final c = deleteCompleter;
    if (c != null) return c.future;
    return Future.value(false);
  }
}

ArtMarker _marker(String id,
    {String name = 'Old', String createdBy = 'wallet_1'}) {
  return ArtMarker(
    id: id,
    name: name,
    description: 'desc',
    position: const LatLng(1, 2),
    type: ArtMarkerType.other,
    createdAt: DateTime.utc(2025, 1, 1),
    createdBy: createdBy,
  );
}

void main() {
  test('MarkerManagementProvider.refresh dedupes in-flight and respects TTL',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    api.getMyCompleter = Completer<List<ArtMarker>>();

    final f1 = provider.refresh(force: true);
    final f2 = provider.refresh(force: true);

    expect(api.getMyCalls, 1);

    api.getMyCompleter!.complete(<ArtMarker>[_marker('m1')]);

    await Future.wait([f1, f2]);

    expect(provider.markers.length, 1);
    expect(provider.markers.first.id, 'm1');

    // TTL should prevent an immediate second call.
    await provider.refresh(force: false);
    expect(api.getMyCalls, 1);
  });

  test(
      'MarkerManagementProvider.deleteMarker is optimistic and reverts on failure',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    provider.ingestMarker(_marker('m1'));
    provider.ingestMarker(_marker('m2'));

    api.deleteCompleter = Completer<bool>();

    final future = provider.deleteMarker('m1');

    // Optimistic removal happens before awaiting the backend.
    expect(provider.markers.any((m) => m.id == 'm1'), false);

    api.deleteCompleter!.complete(false);
    final ok = await future;

    expect(ok, false);
    expect(provider.markers.any((m) => m.id == 'm1'), true);
  });

  test(
      'MarkerManagementProvider.updateMarker is optimistic and then applies server response',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    provider.ingestMarker(_marker('m1', name: 'Old'));

    api.updateCompleter = Completer<ArtMarker?>();

    final future =
        provider.updateMarker('m1', <String, dynamic>{'name': 'Optimistic'});

    // Optimistic update should be reflected immediately.
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Optimistic');

    api.updateCompleter!.complete(_marker('m1', name: 'Server'));
    final updated = await future;

    expect(updated, isNotNull);
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Server');
    expect(api.updateCalls, 1);
  });

  test(
      'MarkerManagementProvider.updateMarker keeps optimistic marker when backend returns null payload',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    provider.ingestMarker(_marker('m1', name: 'Old'));

    api.updateCompleter = Completer<ArtMarker?>();

    final future =
        provider.updateMarker('m1', <String, dynamic>{'name': 'Optimistic'});

    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Optimistic');

    api.updateCompleter!.complete(null);
    final updated = await future;

    expect(updated, isNotNull);
    expect(updated!.name, 'Optimistic');
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Optimistic');
    expect(api.updateCalls, 1);
  });

  test(
      'MarkerManagementProvider.updateMarker recovers from update exception via refresh',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    provider.ingestMarker(_marker('m1', name: 'Old'));
    api.getMyResult = <ArtMarker>[_marker('m1', name: 'Recovered')];

    api.updateCompleter = Completer<ArtMarker?>();
    final future =
        provider.updateMarker('m1', <String, dynamic>{'name': 'Optimistic'});

    // Optimistic update first.
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Optimistic');

    api.updateCompleter!
        .completeError(Exception('client timeout after successful PUT'));
    final updated = await future;

    expect(updated, isNotNull);
    expect(updated!.name, 'Optimistic');
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Optimistic');
    expect(api.updateCalls, 1);
    expect(api.getMyCalls, greaterThanOrEqualTo(1));
  });

  test(
      'MarkerManagementProvider.updateMarker does not reset edited name when refresh returns stale marker',
      () async {
    final api = _FakeMarkerApi();
    final provider = MarkerManagementProvider(
        api: api, mapMarkerService: MapMarkerService());

    provider.ingestMarker(_marker('m1', name: 'Old'));

    // Simulate stale read-after-write from refresh.
    api.getMyResult = <ArtMarker>[_marker('m1', name: 'Old')];
    api.updateCompleter = Completer<ArtMarker?>();

    final future =
        provider.updateMarker('m1', <String, dynamic>{'name': 'Edited'});

    api.updateCompleter!
        .completeError(Exception('client timeout after successful PUT'));
    final updated = await future;

    expect(updated, isNotNull);
    expect(updated!.name, 'Edited');
    expect(provider.markers.firstWhere((m) => m.id == 'm1').name, 'Edited');
  });
}
