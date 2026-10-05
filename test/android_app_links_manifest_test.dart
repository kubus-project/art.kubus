import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  const canonicalPrefixes = <String>{
    '/en/artworks/',
    '/sl/umetnine/',
    '/en/profiles/',
    '/sl/profili/',
    '/en/events/',
    '/sl/dogodki/',
    '/en/exhibitions/',
    '/sl/razstave/',
    '/en/posts/',
    '/sl/objave/',
    '/en/collections/',
    '/sl/zbirke/',
    '/en/map/',
    '/sl/zemljevid/',
    '/en/collectibles/',
    '/sl/zbirateljski-predmeti/',
  };

  const retainedLegacyPrefixes = <String>{
    '/marker/',
    '/m/',
    '/artwork/',
    '/a/',
    '/post/',
    '/p/',
    '/profile/',
    '/user/',
    '/u/',
    '/collection/',
    '/c/',
    '/event/',
    '/events/',
    '/e/',
    '/exhibition/',
    '/exhibitions/',
    '/x/',
    '/n/',
  };

  test(
      'verified App Link filter claims only the supported HTTPS host and routes',
      () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final appLinkFilters = manifest.findAllElements('intent-filter').where(
      (filter) {
        final data = filter.findAllElements('data');
        return filter.getAttribute('android:autoVerify') == 'true' &&
            data.any((element) =>
                element.getAttribute('android:host') == 'app.kubus.site');
      },
    );

    expect(appLinkFilters, hasLength(1));
    final filter = appLinkFilters.single;
    expect(
      filter.findAllElements('action').map(
            (element) => element.getAttribute('android:name'),
          ),
      contains('android.intent.action.VIEW'),
    );
    expect(
      filter.findAllElements('category').map(
            (element) => element.getAttribute('android:name'),
          ),
      containsAll(<String>[
        'android.intent.category.DEFAULT',
        'android.intent.category.BROWSABLE',
      ]),
    );

    final dataElements = filter.findAllElements('data').toList();
    expect(dataElements, isNotEmpty);
    for (final element in dataElements) {
      expect(element.getAttribute('android:scheme'), 'https');
      expect(element.getAttribute('android:host'), 'app.kubus.site');
      final prefix = element.getAttribute('android:pathPrefix');
      final exact = element.getAttribute('android:path');
      expect((prefix != null) != (exact != null), isTrue);
      expect(element.getAttribute('android:host'), isNot('*.kubus.site'));
    }

    final pathPrefixes = dataElements
        .map((element) => element.getAttribute('android:pathPrefix'))
        .whereType<String>()
        .toSet();
    expect(pathPrefixes, containsAll(canonicalPrefixes));
    expect(pathPrefixes, containsAll(retainedLegacyPrefixes));
    expect(pathPrefixes, isNot(contains('/')));
    expect(pathPrefixes, isNot(contains('/en/')));
    expect(pathPrefixes, isNot(contains('/sl/')));
    expect(pathPrefixes, isNot(contains('/.well-known/')));
    expect(pathPrefixes,
        equals({...canonicalPrefixes, ...retainedLegacyPrefixes}));
    final exactPaths = dataElements
        .map((element) => element.getAttribute('android:path'))
        .whereType<String>()
        .toSet();
    expect(exactPaths,
        equals({'/sign-in', '/register', '/verify-email', '/reset-password'}));
  });
}
