import 'package:art_kubus/models/institution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Event.fromBackendJson accepts real api event field names', () {
    final event = Event.fromBackendJson({
      'id': 'event-1',
      'title': 'Opening Night',
      'description': 'Public opening',
      'type': 'gallery_opening',
      'category': 'mixed_media',
      'institution_id': 'inst-1',
      'starts_at': '2026-08-01T18:00:00.000Z',
      'ends_at': '2026-08-01T20:30:00.000Z',
      'location_name': 'Main Hall',
      'lat': '46.0511',
      'lng': '14.5051',
      'cover_url': '/uploads/events/opening.png',
      'price': '12.5',
      'capacity': '120',
      'current_attendees': '34',
      'allow_registration': false,
      'created_at': '2026-07-01T10:00:00.000Z',
      'host_user_id': 'host-1',
    });

    expect(event.id, 'event-1');
    expect(event.type, EventType.galleryOpening);
    expect(event.category, EventCategory.mixedMedia);
    expect(event.institutionId, 'inst-1');
    expect(event.location, 'Main Hall');
    expect(event.latitude, 46.0511);
    expect(event.longitude, 14.5051);
    expect(event.imageUrls, contains('/uploads/events/opening.png'));
    expect(event.price, 12.5);
    expect(event.capacity, 120);
    expect(event.currentAttendees, 34);
    expect(event.allowRegistration, isFalse);
    expect(event.createdBy, 'host-1');
  });
}
