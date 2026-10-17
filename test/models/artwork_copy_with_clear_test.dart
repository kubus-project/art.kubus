import 'package:art_kubus/models/artwork.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Artwork build() => Artwork(
        id: 'art-1',
        title: 'Title',
        artist: 'Artist',
        description: 'Desc',
        position: const LatLng(46.0, 14.0),
        rewards: 0,
        createdAt: DateTime.utc(2025, 1, 1),
        price: 42.5,
        arScale: 2.0,
      );

  test('copyWith keeps price and arScale for a null argument', () {
    final copy = build().copyWith(title: 'New');
    expect(copy.price, 42.5);
    expect(copy.arScale, 2.0);
  });

  test('clearPrice and clearArScale explicitly clear the nullable fields', () {
    final copy = build().copyWith(clearPrice: true, clearArScale: true);
    expect(copy.price, isNull);
    expect(copy.arScale, isNull);
  });
}
