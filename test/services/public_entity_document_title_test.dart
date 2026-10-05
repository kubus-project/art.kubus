import 'package:art_kubus/services/public_entity_takeover_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = '/en/artworks/record-1';
  Map<String, dynamic> bootstrap() => {
        'version': 2,
        'identity': {
          'type': 'artwork',
          'id': 'record-1',
          'locale': 'en',
          'canonicalPath': path,
        },
        'presentation': {
          'version': 2,
          'type': 'artwork',
          'id': 'record-1',
          'canonicalPath': path,
        },
      };
  String? resolve(Map<String, dynamic>? raw,
          {String pathname = path,
          String? title = 'River Memory by Maja Novak | art.kubus'}) =>
      validatedPublicEntityDocumentTitle(
          bootstrap: raw, pathname: pathname, title: title);

  test('preserves semantic title for the exact supported entry', () {
    expect(resolve(bootstrap()), 'River Memory by Maja Novak | art.kubus');
  });
  test('does not retain entity title after navigating to another URL', () {
    expect(resolve(bootstrap(), pathname: '/en'), isNull);
  });
  test('rejects mismatched identity, locale, version and presentation', () {
    for (final field in ['type', 'id', 'locale', 'canonicalPath']) {
      final raw = bootstrap();
      (raw['identity'] as Map)[field] = 'mismatch';
      expect(resolve(raw), isNull);
    }
    final raw = bootstrap()..['version'] = 99;
    expect(resolve(raw), isNull);
    final mismatched = bootstrap();
    (mismatched['presentation'] as Map)['version'] = 1;
    expect(resolve(mismatched), isNull);
  });
  test('falls back for absent, empty or oversized metadata', () {
    expect(resolve(null), isNull);
    expect(resolve(bootstrap(), title: ''), isNull);
    expect(resolve(bootstrap(), title: 'x' * 513), isNull);
  });
}
