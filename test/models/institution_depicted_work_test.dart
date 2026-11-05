import 'package:art_kubus/models/institution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('depicted works keep named architecture and artwork creators only', () {
    final attribution = InstitutionImageAttribution.fromJson({
      'credit': 'Photographer, CC BY 4.0',
      'author': 'Photographer',
      'sourceUrl': 'https://commons.wikimedia.org/wiki/File:X.jpg',
      'licenseUrl': 'https://creativecommons.org/licenses/by/4.0/',
      'depictedWorks': [
        {'type': 'architecture', 'author': ' Edvard Ravnikar '},
        {'type': 'sculpture', 'author': 'A Sculptor'},
        {'type': 'logo_or_signage', 'author': 'Sign maker'},
        {'type': 'architecture', 'author': ''},
        'not a map',
      ],
    });
    expect(attribution.depictedWorks, const [
      InstitutionDepictedWork(type: 'architecture', author: 'Edvard Ravnikar'),
      InstitutionDepictedWork(type: 'sculpture', author: 'A Sculptor'),
    ]);
    expect(attribution.depictedWorks.first.isArchitecture, isTrue);
    final roundTrip =
        InstitutionImageAttribution.fromJson(attribution.toJson());
    expect(roundTrip, attribution);
  });

  test('missing depicted works are an empty list', () {
    expect(InstitutionImageAttribution.fromJson({'credit': 'x'}).depictedWorks,
        isEmpty);
  });

  test('an attribution with only an author is not empty and shows the author',
      () {
    final attribution =
        InstitutionImageAttribution.fromJson({'author': 'Jane Photographer'});
    expect(attribution.isEmpty, isFalse);
    expect(attribution.displayCredit, 'Jane Photographer');
  });

  test('an attribution with only depicted works is not empty', () {
    final attribution = InstitutionImageAttribution.fromJson({
      'depictedWorks': [
        {'type': 'architecture', 'author': 'Edvard Ravnikar'},
      ],
    });
    expect(attribution.isEmpty, isFalse);
    expect(attribution.displayCredit, isNull);
    expect(attribution.depictedWorks.single.author, 'Edvard Ravnikar');
  });

  test('an attribution with nothing usable is empty', () {
    expect(InstitutionImageAttribution.fromJson({}).isEmpty, isTrue);
    expect(
        InstitutionImageAttribution.fromJson({
          'author': '  ',
          'depictedWorks': [
            {'type': 'architecture', 'author': ''},
          ],
        }).isEmpty,
        isTrue);
  });

  test('Commons file pages yield the decoded title without the File: prefix',
      () {
    expect(
      InstitutionImageAttribution.commonsFileTitleOf(
        'https://commons.wikimedia.org/wiki/File:Narodna_galerija_Ljubljana_2015.jpg',
      ),
      'Narodna galerija Ljubljana 2015.jpg',
    );
    expect(
      InstitutionImageAttribution.commonsFileTitleOf(
        'https://commons.wikimedia.org/wiki/File:Ljubljana_%C5%A0kofja_Loka.jpg',
      ),
      'Ljubljana Škofja Loka.jpg',
    );
    expect(
      const InstitutionImageAttribution(
        sourceUrl: 'https://commons.wikimedia.org/wiki/File:A_B.png',
      ).commonsFileTitle,
      'A B.png',
    );
  });

  test('other source URLs keep the generic label (no title)', () {
    const urls = <String>[
      'https://example.test/source',
      'https://commons.wikimedia.org/wiki/Category:Ljubljana',
      'https://commons.wikimedia.org/w/index.php?title=File:A.jpg',
      'https://en.wikipedia.org/wiki/File:A.jpg',
      'https://commons.wikimedia.org/wiki/File:',
      'https://commons.wikimedia.org/wiki/File:___',
    ];
    for (final url in urls) {
      expect(InstitutionImageAttribution.commonsFileTitleOf(url), isNull,
          reason: url);
    }
    expect(InstitutionImageAttribution.commonsFileTitleOf(null), isNull);
  });
}
