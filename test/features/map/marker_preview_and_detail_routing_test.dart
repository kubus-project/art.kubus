import 'dart:io';

import 'package:art_kubus/features/map/shared/map_marker_overlay_presentation.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/screens/map_core/map_ui_state_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Hotfix requirements A and C:
///  * every marker type enters `markerPreview` on initial selection,
///  * hydration updates the already-visible quick card,
///  * a 404 hydration result leaves `markerPreview` visible,
///  * a resolved event/exhibition routes to its own detail surface,
///  * an orphaned subject routes to the shared generic marker-detail surface and
///    never to the removed alert dialog.
ArtMarker _marker({
  String id = 'marker-1',
  required ArtMarkerType type,
  Map<String, dynamic>? metadata,
  String name = 'Ponjava VI',
  String description = 'Marker description.',
}) {
  return ArtMarker(
    id: id,
    name: name,
    description: description,
    position: const LatLng(46.0569, 14.5058),
    type: type,
    createdAt: DateTime.utc(2026, 7, 1),
    createdBy: 'tester',
    metadata: metadata,
  );
}

void main() {
  group('initial selection enters markerPreview for every marker type', () {
    for (final type in ArtMarkerType.values) {
      test('marker type ${type.name}', () {
        final coordinator = MapUiStateCoordinator();
        addTearDown(coordinator.dispose);

        final marker = _marker(id: 'marker-${type.name}', type: type);
        coordinator.setMarkerSelection(
          selectionToken: 1,
          selectedMarkerId: marker.id,
          selectedMarker: marker,
          stackedMarkers: <ArtMarker>[marker],
          stackIndex: 0,
          selectedAt: DateTime.utc(2026, 7, 1),
        );

        expect(
          coordinator.value.contextSurface,
          MapContextSurface.markerPreview,
          reason: '${type.name} must open the floating quick card',
        );
        expect(
            coordinator.value.markerSelection.hasRenderableSelection, isTrue);
      });
    }

    test('event marker carrying an exhibition subject still previews first',
        () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      // The verified production shape: markerType=event, subjectType=exhibition,
      // subjectId pointing at a deleted exhibition.
      final marker = ArtMarker.fromMap(<String, dynamic>{
        'id': '312d350e-72a7-47f9-9654-b9a2eaf2e9d1',
        'name': 'Ponjava VI',
        'description': 'Marker description.',
        'latitude': 46.0569,
        'longitude': 14.5058,
        'markerType': 'event',
        'createdAt': '2026-07-01T10:00:00.000Z',
        'createdBy': 'tester',
        'metadata': <String, dynamic>{
          'subjectType': 'exhibition',
          'subjectId': '8a1d8347-fada-4755-95d2-6024519c93cd',
        },
      });

      coordinator.setMarkerSelection(
        selectionToken: 7,
        selectedMarkerId: marker.id,
        selectedMarker: marker,
        stackedMarkers: <ArtMarker>[marker],
        stackIndex: 0,
        selectedAt: DateTime.utc(2026, 7, 1),
      );

      expect(coordinator.value.contextSurface, MapContextSurface.markerPreview);
    });
  });

  group('hydration outcome and the visible preview', () {
    ArtMarker exhibitionMarker() => _marker(
          type: ArtMarkerType.exhibition,
          metadata: const <String, dynamic>{
            'subjectType': 'exhibition',
            'subjectId': 'exh-1',
            'locationName': 'Kino Siska',
            'startsAt': '2026-08-01T18:00:00.000Z',
            'endsAt': '2026-08-10T20:00:00.000Z',
          },
        );

    test('an unhydrated exhibition preview still shows marker-carried context',
        () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: exhibitionMarker(),
      );

      expect(
        presentation.linkedSubject.kind,
        MapMarkerOverlayLinkedSubjectKind.exhibition,
      );
      expect(presentation.title, 'Ponjava VI');
      expect(presentation.description, 'Marker description.');
      // Location + schedule fall back to the marker's own metadata.
      expect(presentation.linkedSubject.subtitle, contains('Kino Siska'));
      expect(presentation.linkedSubject.subtitle, contains('2026-08'));
      // The More info action still targets the exhibition surface.
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.exhibition,
      );
    });

    test('successful hydration upgrades the preview to canonical entity data',
        () {
      final hydrated = Exhibition(
        id: 'exh-1',
        title: 'Canonical exhibition title',
        description: 'Canonical exhibition description.',
        locationName: 'Moderna galerija',
        startsAt: DateTime.utc(2026, 9, 1),
        endsAt: DateTime.utc(2026, 9, 30),
        coverUrl: '/uploads/exhibition-cover.png',
      );

      final presentation = resolveMarkerOverlayPresentation(
        marker: exhibitionMarker(),
        exhibition: hydrated,
      );

      expect(presentation.title, 'Canonical exhibition title');
      expect(presentation.description, 'Canonical exhibition description.');
      expect(presentation.linkedSubject.subtitle, contains('Moderna galerija'));
      expect(presentation.mediaUrl, '/uploads/exhibition-cover.png');
    });

    test('successful event hydration upgrades the preview', () {
      final marker = _marker(
        type: ArtMarkerType.event,
        metadata: const <String, dynamic>{
          'subjectType': 'event',
          'subjectId': 'evt-1',
        },
      );
      final hydrated = KubusEvent(
        id: 'evt-1',
        title: 'Canonical event title',
        description: 'Canonical event description.',
        locationName: 'Metelkova',
        city: 'Ljubljana',
        startsAt: DateTime.utc(2026, 8, 5),
        coverUrl: '/uploads/event-cover.png',
      );

      final presentation = resolveMarkerOverlayPresentation(
        marker: marker,
        event: hydrated,
      );

      expect(presentation.title, 'Canonical event title');
      expect(presentation.description, 'Canonical event description.');
      expect(presentation.linkedSubject.subtitle, contains('Metelkova'));
      expect(presentation.mediaUrl, '/uploads/event-cover.png');
      expect(presentation.primaryTarget, MapMarkerOverlayPrimaryTarget.event);
    });

    test('a 404 hydration result leaves the preview surface untouched', () {
      final coordinator = MapUiStateCoordinator();
      addTearDown(coordinator.dispose);

      final marker = exhibitionMarker();
      coordinator.setMarkerSelection(
        selectionToken: 1,
        selectedMarkerId: marker.id,
        selectedMarker: marker,
        stackedMarkers: <ArtMarker>[marker],
        stackIndex: 0,
        selectedAt: DateTime.utc(2026, 7, 1),
      );
      expect(coordinator.value.contextSurface, MapContextSurface.markerPreview);

      // A failed hydration performs no surface transition at all; the marker
      // card keeps rendering from marker metadata.
      final presentation = resolveMarkerOverlayPresentation(marker: marker);
      expect(coordinator.value.contextSurface, MapContextSurface.markerPreview);
      expect(presentation.title.isNotEmpty, isTrue);
      expect(presentation.description.isNotEmpty, isTrue);
    });
  });

  group('linked-subject kind falls back to the marker type', () {
    test('event marker without a subject declaration stays an event', () {
      final marker = _marker(type: ArtMarkerType.event);
      expect(
        resolveMarkerOverlayLinkedSubjectKind(marker),
        MapMarkerOverlayLinkedSubjectKind.event,
      );
    });

    test('exhibition marker without a subject declaration stays an exhibition',
        () {
      final marker = _marker(type: ArtMarkerType.exhibition);
      expect(
        resolveMarkerOverlayLinkedSubjectKind(marker),
        MapMarkerOverlayLinkedSubjectKind.exhibition,
      );
    });

    test('street-art and artwork markers keep the artwork/none presentation',
        () {
      expect(
        resolveMarkerOverlayLinkedSubjectKind(
          _marker(type: ArtMarkerType.streetArt),
        ),
        MapMarkerOverlayLinkedSubjectKind.none,
      );
      expect(
        resolveMarkerOverlayLinkedSubjectKind(
          ArtMarker(
            id: 'm',
            name: 'n',
            description: '',
            position: const LatLng(0.1, 0.1),
            type: ArtMarkerType.artwork,
            artworkId: 'art-1',
            createdAt: DateTime.utc(2026),
            createdBy: 'tester',
          ),
        ),
        MapMarkerOverlayLinkedSubjectKind.artwork,
      );
    });

    test('an absent subject id downgrades the primary target to marker info',
        () {
      final marker = _marker(
        type: ArtMarkerType.event,
        metadata: const <String, dynamic>{'subjectType': 'event'},
      );
      final presentation = resolveMarkerOverlayPresentation(marker: marker);
      expect(
        presentation.primaryTarget,
        MapMarkerOverlayPrimaryTarget.markerInfo,
      );
    });
  });

  group('the legacy marker-info dialog is gone from both map screens', () {
    late String mobileSource;
    late String desktopSource;

    setUpAll(() {
      mobileSource = File('lib/screens/map_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      desktopSource = File('lib/screens/desktop/desktop_map_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
    });

    test('no screen defines or calls _showMarkerInfoFallback', () {
      expect(mobileSource, isNot(contains('_showMarkerInfoFallback')));
      expect(desktopSource, isNot(contains('_showMarkerInfoFallback')));
    });

    test('no screen opens a dialog from the marker-open path', () {
      String markerOpenRegion(String source) {
        final start = source.indexOf('Future<void> _openMarkerPrimaryTarget(');
        expect(start, greaterThanOrEqualTo(0));
        final end = source.indexOf(
          'MarkerSubjectData _snapshotMarkerSubjectData()',
          start,
        );
        return source.substring(start, end > start ? end : source.length);
      }

      for (final region in <String>[
        markerOpenRegion(mobileSource),
        markerOpenRegion(desktopSource),
      ]) {
        expect(region, isNot(contains('showKubusDialog')));
        expect(region, isNot(contains('KubusAlertDialog')));
        expect(region, contains('_openMarkerInfoDetail'));
      }
    });

    test('every unresolved-subject branch routes to _openMarkerInfoDetail', () {
      for (final source in <String>[mobileSource, desktopSource]) {
        // markerInfo primary target, missing event, missing institution,
        // missing artwork, missing exhibition summary, failed exhibition fetch.
        final routed =
            RegExp(r'_openMarkerInfoDetail\(').allMatches(source).length;
        expect(
          routed,
          greaterThanOrEqualTo(6),
          reason: 'each fallback branch must reach the shared detail surface',
        );
      }
    });

    test('mobile pushes a full-detail page and desktop docks a panel', () {
      expect(mobileSource, contains('MarkerInfoDetailScreen('));
      expect(desktopSource, contains('MarkerInfoDetailPanel('));
      expect(desktopSource, contains('_presentMarkerInfoDetails('));
    });

    test('desktop clears marker info whenever other details are presented', () {
      // Otherwise the left panel could render stale marker information behind a
      // freshly opened artwork/event/exhibition panel.
      final assignments =
          RegExp(r'_selectedMarkerInfo = null;').allMatches(desktopSource);
      expect(assignments.length, greaterThanOrEqualTo(6));
    });
  });
}
