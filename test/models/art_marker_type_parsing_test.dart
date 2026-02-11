import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ArtMarker parse(Map<String, dynamic> json) {
    return ArtMarker.fromMap(<String, dynamic>{
      'id': json['id'] ?? 'marker_1',
      'name': json['name'] ?? 'Marker',
      'description': json['description'] ?? '',
      'latitude': 46.056946,
      'longitude': 14.505751,
      'markerType': json['markerType'],
      'type': json['type'] ?? 'geolocation',
      'category': json['category'] ?? 'General',
      'metadata': json['metadata'] ?? const <String, dynamic>{},
      'createdAt': '2026-01-01T00:00:00.000Z',
      'createdBy': 'tester',
    });
  }

  test('parses artwork markerType as artwork (not experience)', () {
    final marker = parse(<String, dynamic>{
      'markerType': 'artwork',
      'type': 'geolocation',
      'metadata': const <String, dynamic>{'subjectType': 'artwork'},
    });

    expect(marker.type, ArtMarkerType.artwork);
  });

  test('parses event and institution marker types correctly', () {
    final event = parse(<String, dynamic>{'markerType': 'event'});
    final institution = parse(<String, dynamic>{'markerType': 'institution'});

    expect(event.type, ArtMarkerType.event);
    expect(institution.type, ArtMarkerType.institution);
  });

  test('uses metadata subjectType when markerType/type are transport values',
      () {
    final marker = parse(<String, dynamic>{
      'markerType': 'geolocation',
      'type': 'geolocation',
      'metadata': const <String, dynamic>{'subjectType': 'institution'},
    });

    expect(marker.type, ArtMarkerType.institution);
  });

  test('keeps AR/XR marker tokens mapped to experience', () {
    final ar = parse(<String, dynamic>{'markerType': 'ar'});
    final xr = parse(<String, dynamic>{'markerType': 'xr_installation'});
    final explicit = parse(<String, dynamic>{'markerType': 'experience'});

    expect(ar.type, ArtMarkerType.experience);
    expect(xr.type, ArtMarkerType.experience);
    expect(explicit.type, ArtMarkerType.experience);
  });
}
