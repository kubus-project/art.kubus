import 'package:art_kubus/utils/profile_showcase_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileArtworkShowcaseData _card(Map<String, dynamic> data) =>
    ProfileArtworkShowcaseData.fromMap(
      data,
      fallbackTitle: 'Untitled',
      fallbackSubtitle: 'Artwork',
    );

void main() {
  test('a documented record credits its recorded artist', () {
    final card = _card(<String, dynamic>{
      'id': 'a1',
      'title': 'Mural',
      'category': 'Street art',
      'relationship': 'documented',
      'artistName': 'Mural Hand',
    });
    expect(card.subtitle, 'Mural Hand');
  });

  test('an authored record keeps its category subtitle', () {
    final card = _card(<String, dynamic>{
      'id': 'a2',
      'title': 'Own work',
      'category': 'Painting',
      'relationship': 'authored',
      'artistName': 'Ana Artist',
    });
    expect(card.subtitle, 'Painting');
  });

  test('a documented record with no recorded artist falls back as before', () {
    final card = _card(<String, dynamic>{
      'id': 'a3',
      'title': 'Unknown mural',
      'category': 'Street art',
      'relationship': 'documented',
      'artistName': null,
    });
    expect(card.subtitle, 'Street art');
  });
}
