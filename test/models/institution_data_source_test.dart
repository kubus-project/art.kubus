import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/widgets/common/marker_attribution_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> _osmSource({
  Object? fields = const ['name', 'coordinates'],
  Object? exportUrl = '/api/open-data/institutions-odbl.geojson',
  Object? licenseUrl = 'https://opendatacommons.org/licenses/odbl/1-0/',
  Object? sourceUrls = const ['https://www.openstreetmap.org/node/1'],
}) =>
    {
      'id': 'osm',
      'attribution': '© OpenStreetMap contributors',
      'attributionLine': 'Data © OpenStreetMap contributors (ODbL)',
      'license': 'ODbL-1.0',
      'licenseUrl': licenseUrl,
      'copyrightUrl': 'https://www.openstreetmap.org/copyright',
      'exportUrl': exportUrl,
      'sourceUrls': sourceUrls,
      'fields': fields,
    };

Map<String, dynamic> _payload({Object? dataSources}) => {
      'id': 'inst-1',
      'name': 'Museum',
      'description': '',
      'type': 'museum',
      'address': 'Main Street 1',
      'latitude': 46.05,
      'longitude': 14.5,
      'contactEmail': '',
      'website': '',
      'stats': {
        'totalVisitors': 0,
        'activeEvents': 0,
        'artworkViews': 0,
        'revenue': 0,
        'visitorGrowth': 0,
        'revenueGrowth': 0,
      },
      'createdAt': '2026-07-01T10:00:00.000Z',
      if (dataSources != null) 'dataSources': dataSources,
    };

void main() {
  group('Institution data sources (ODbL credit)', () {
    test('reads the OpenStreetMap credit, licence and export offer', () {
      final institution =
          Institution.fromJson(_payload(dataSources: [_osmSource()]));
      final source = institution.openStreetMapSource!;

      expect(
          source.attributionLine, 'Data © OpenStreetMap contributors (ODbL)');
      expect(source.license, 'ODbL-1.0');
      expect(
          source.licenseUrl, 'https://opendatacommons.org/licenses/odbl/1-0/');
      expect(source.copyrightUrl, 'https://www.openstreetmap.org/copyright');
      expect(source.sourceUrls, ['https://www.openstreetmap.org/node/1']);
      expect(source.fields, ['name', 'coordinates']);
      expect(
        source.exportUri('https://api.kubus.site/')?.toString(),
        'https://api.kubus.site/api/open-data/institutions-odbl.geojson',
      );
    });

    test('a payload without data sources has none', () {
      expect(Institution.fromJson(_payload()).dataSources, isEmpty);
      expect(Institution.fromJson(_payload()).openStreetMapSource, isNull);
      expect(Institution.fromJson(_payload(dataSources: 'nope')).dataSources,
          isEmpty);
    });

    test('a source with no derived field is not a source', () {
      final institution = Institution.fromJson(
          _payload(dataSources: [_osmSource(fields: const <String>[])]));
      expect(institution.dataSources, isEmpty);
    });

    test('never follows a foreign origin or an unsafe link', () {
      final institution = Institution.fromJson(_payload(dataSources: [
        _osmSource(
          exportUrl: 'https://evil.example/data.geojson',
          licenseUrl: 'javascript:alert(1)',
          sourceUrls: const [
            'https://user:pw@example.test/x',
            'https://www.openstreetmap.org/way/2',
          ],
        ),
      ]));
      final source = institution.openStreetMapSource!;
      expect(source.exportPath, isNull);
      expect(source.exportUri('https://api.kubus.site'), isNull);
      expect(source.licenseUrl, isNull);
      expect(source.sourceUrls, ['https://www.openstreetmap.org/way/2']);
    });

    test('survives a JSON round trip', () {
      final institution =
          Institution.fromJson(_payload(dataSources: [_osmSource()]));
      final again = Institution.fromJson(institution.toJson());
      expect(again.dataSources, institution.dataSources);
      expect(
          institution.copyWith(name: 'X').dataSources, institution.dataSources);
    });

    test('an institution map marker credit reaches the map card rows', () {
      // The backend stamps this on institution markers while OSM facts remain.
      final marker = ArtMarker(
        id: 'm1',
        name: 'Museum',
        description: '',
        position: const LatLng(46.05, 14.5),
        type: ArtMarkerType.institution,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
        createdBy: 'system',
        metadata: const {
          'subjectType': 'institution',
          'sourceAttribution': 'Data © OpenStreetMap contributors (ODbL)',
          'sourceLicense': 'ODbL-1.0',
        },
      );
      expect(
        MarkerAttributionSection.rowValuesForMarkerAndArtwork(marker, null),
        contains('Data © OpenStreetMap contributors (ODbL)'),
      );
    });
  });
}
