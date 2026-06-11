import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exhibition relations parsing', () {
    test('parses eventIds and merges legacy eventId', () {
      final exhibition = Exhibition.fromJson(const {
        'id': 'x-1',
        'title': 'Show',
        'eventId': 'legacy-event',
        'eventIds': ['e-1', 'e-2'],
      });

      expect(exhibition.eventIds, ['e-1', 'e-2', 'legacy-event']);
      expect(exhibition.eventId, 'legacy-event');
    });

    test('does not duplicate legacy eventId already present in eventIds', () {
      final exhibition = Exhibition.fromJson(const {
        'id': 'x-1',
        'title': 'Show',
        'event_id': 'e-1',
        'event_ids': ['e-1', 'e-2'],
      });

      expect(exhibition.eventIds, ['e-1', 'e-2']);
    });

    test('parses linkedEvents payloads', () {
      final exhibition = Exhibition.fromJson(const {
        'id': 'x-1',
        'title': 'Show',
        'linkedEvents': [
          {'id': 'e-1', 'title': 'Opening', 'relationType': 'opening'},
        ],
      });

      expect(exhibition.linkedEvents, hasLength(1));
      expect(exhibition.linkedEvents.first.title, 'Opening');
      expect(exhibition.linkedEvents.first.relationType, 'opening');
    });
  });

  group('KubusEvent program relation parsing', () {
    test('parses relationType and sortOrder', () {
      final event = KubusEvent.fromJson(const {
        'id': 'e-1',
        'title': 'Guided tour',
        'relation_type': 'guided_tour',
        'sort_order': 3,
      });

      expect(event.relationType, 'guided_tour');
      expect(event.sortOrder, 3);
    });

    test('defaults sortOrder to 0 and keeps relationType null', () {
      final event = KubusEvent.fromJson(const {
        'id': 'e-1',
        'title': 'Plain event',
      });

      expect(event.relationType, isNull);
      expect(event.sortOrder, 0);
    });
  });

  group('EventPoapStatus parsing', () {
    test('parses full claim status payload', () {
      final status = EventPoapStatus.fromJson(const {
        'eventId': 'e-1',
        'eventStatus': 'published',
        'claimed': true,
        'poap': {
          'id': 'a-1',
          'code': 'event_poap_e-1',
          'title': 'Opening Badge',
          'description': 'Was there.',
          'rewardKub8': 25,
          'rarity': 'rare',
          'subjectId': 'e-1',
          'proofType': 'marker_attendance',
          'isPoap': true,
        },
        'eligibility': {
          'state': 'claimed',
          'reason': 'claim_recorded',
          'canClaim': false,
          'proofType': 'marker_attendance',
          'linkedMarkerCount': 2,
          'latestAttendance': {
            'markerId': 'm-1',
            'attendedAt': '2026-06-01T12:00:00Z',
          },
        },
        'achievement': {
          'duplicate': false,
          'unlocked': [
            {'code': 'event_attendee', 'kub8Reward': 50},
          ],
          'totalKub8Earned': 75,
        },
      });

      expect(status.eventId, 'e-1');
      expect(status.claimed, isTrue);
      expect(status.canClaim, isFalse);
      expect(status.poap.title, 'Opening Badge');
      expect(status.poap.rewardKub8, 25);
      expect(status.poap.eventId, 'e-1');
      expect(status.poap.proofType, 'marker_attendance');
      expect(status.linkedMarkerCount, 2);
      expect(status.latestAttendanceMarkerId, 'm-1');
      expect(status.latestAttendanceAt, isNotNull);
      expect(status.unlockedAchievementsCount, 1);
      expect(status.totalKub8Earned, 75);
    });

    test('parses scan-proof eligibility', () {
      final status = EventPoapStatus.fromJson(const {
        'eventId': 'e-1',
        'eventStatus': 'published',
        'claimed': false,
        'poap': {
          'id': 'a-1',
          'code': 'event_poap_e-1',
          'title': 'Badge',
          'rewardKub8': 0,
          'rarity': 'common',
          'isPoap': true,
        },
        'eligibility': {
          'state': 'needs_scan_proof',
          'reason': 'scan_proof_required',
          'canClaim': false,
          'proofType': 'scan_proof',
          'linkedMarkerCount': 0,
        },
      });

      expect(status.claimed, isFalse);
      expect(status.canClaim, isFalse);
      expect(status.eligibilityReason, 'scan_proof_required');
      expect(status.proofType, 'scan_proof');
      expect(status.unlockedAchievementsCount, 0);
      expect(status.totalKub8Earned, isNull);
    });
  });
}
