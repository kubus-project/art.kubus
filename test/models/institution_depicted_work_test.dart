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
}
