import 'package:art_kubus/features/map/detail/marker_info_detail_presentation.dart';
import 'package:art_kubus/features/map/shared/map_marker_overlay_presentation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/widgets/common/marker_attribution_section.dart';
import 'package:art_kubus/widgets/detail/detail_shell_components.dart';
import 'package:art_kubus/widgets/map/panels/marker_info_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hotfix requirement C: the generic marker-detail surface must present the
/// marker's own information — title, description, cover, location/date metadata,
/// attribution, actions — and clearly say the linked entity is unavailable
/// instead of pretending a canonical entity exists.
ArtMarker _orphanedExhibitionMarker() {
  return ArtMarker.fromMap(<String, dynamic>{
    'id': '312d350e-72a7-47f9-9654-b9a2eaf2e9d1',
    'name': 'Ponjava VI',
    'description': 'A canvas installation stretched between two facades.',
    'latitude': 46.0569,
    'longitude': 14.5058,
    'markerType': 'event',
    'createdAt': '2026-07-01T10:00:00.000Z',
    'updatedAt': '2026-07-02T10:00:00.000Z',
    'createdBy': 'tester',
    'metadata': <String, dynamic>{
      'subjectType': 'exhibition',
      'subjectId': '8a1d8347-fada-4755-95d2-6024519c93cd',
      'subjectCategory': 'Group show',
      'locationName': 'Kino Siska',
      'startsAt': '2026-08-01T18:00:00.000Z',
      'endsAt': '2026-08-10T20:00:00.000Z',
      'artistName': 'Klara Perusek',
      'imageAuthor': 'Kino Siska',
      'imageLicense': 'CC BY-SA 4.0',
      'sourceAttribution': 'OpenStreetMap contributors',
    },
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

Future<MarkerInfoDetail> _resolve(
  WidgetTester tester,
  ArtMarker marker, {
  KubusEvent? event,
  bool unavailable = true,
  String? distanceLabel,
}) async {
  late MarkerInfoDetail detail;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) {
          detail = resolveMarkerInfoDetail(
            marker: marker,
            l10n: AppLocalizations.of(context)!,
            event: event,
            distanceLabel: distanceLabel,
            linkedSubjectUnavailable: unavailable,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return detail;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveMarkerInfoDetail', () {
    testWidgets('carries marker metadata when the entity is orphaned',
        (tester) async {
      final marker = _orphanedExhibitionMarker();
      final detail = await _resolve(tester, marker, distanceLabel: '420 m');

      expect(detail.title, 'Ponjava VI');
      expect(
        detail.description,
        'A canvas installation stretched between two facades.',
      );
      expect(detail.locationLabel, 'Kino Siska');
      expect(detail.dateRangeLabel, contains('2026-08'));
      expect(detail.categoryLabel, 'Group show');
      expect(detail.distanceLabel, '420 m');
      expect(detail.linkedSubjectUnavailable, isTrue);
      expect(detail.linkedKind, MapMarkerOverlayLinkedSubjectKind.exhibition);
      expect(detail.kicker, isNotEmpty);
      expect(detail.subjectTypeLabel, isNotNull);
    });

    testWidgets('prefers canonical entity values when one was hydrated',
        (tester) async {
      final marker = ArtMarker.fromMap(<String, dynamic>{
        'id': 'marker-2',
        'name': 'Marker name',
        'description': 'Marker description.',
        'latitude': 46.0,
        'longitude': 14.5,
        'markerType': 'event',
        'createdAt': '2026-07-01T10:00:00.000Z',
        'createdBy': 'tester',
        'metadata': <String, dynamic>{
          'subjectType': 'event',
          'subjectId': 'evt-1',
          'locationName': 'Marker place',
        },
      });
      final detail = await _resolve(
        tester,
        marker,
        event: KubusEvent(
          id: 'evt-1',
          title: 'Canonical event',
          description: 'Canonical description.',
          locationName: 'Canonical place',
          startsAt: DateTime.utc(2026, 9, 1),
          endsAt: DateTime.utc(2026, 9, 2),
        ),
        unavailable: false,
      );

      expect(detail.title, 'Canonical event');
      expect(detail.description, 'Canonical description.');
      expect(detail.locationLabel, 'Canonical place');
      expect(detail.linkedSubjectUnavailable, isFalse);
    });
  });

  group('MarkerInfoDetailSections', () {
    testWidgets('renders marker metadata, attribution, and actions',
        (tester) async {
      final marker = _orphanedExhibitionMarker();
      final detail = await _resolve(tester, marker, distanceLabel: '420 m');
      var shareTaps = 0;

      await tester.pumpWidget(
        _host(
          MarkerInfoDetailSections(
            detail: detail,
            actions: <MarkerInfoDetailAction>[
              MarkerInfoDetailAction(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () => shareTaps += 1,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ponjava VI'), findsOneWidget);
      expect(
        find.text('A canvas installation stretched between two facades.'),
        findsOneWidget,
      );
      expect(find.textContaining('Kino Siska'), findsWidgets);
      expect(find.textContaining('2026-08'), findsWidgets);
      expect(find.text('Group show'), findsOneWidget);
      expect(find.text('420 m'), findsOneWidget);
      expect(find.byType(MarkerAttributionSection), findsOneWidget);
      expect(find.textContaining('Klara Perusek'), findsWidgets);
      expect(find.byType(DetailIdentityBlock), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pump();
      expect(shareTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('states that the linked entry is unavailable', (tester) async {
      final marker = _orphanedExhibitionMarker();
      final detail = await _resolve(tester, marker);

      await tester.pumpWidget(
        _host(
          MarkerInfoDetailSections(
            detail: detail,
            actions: const <MarkerInfoDetailAction>[],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('marker_info_detail_unlinked_notice'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides the unavailable notice for a resolved subject',
        (tester) async {
      final marker = _orphanedExhibitionMarker();
      final detail = await _resolve(tester, marker, unavailable: false);

      await tester.pumpWidget(
        _host(
          MarkerInfoDetailSections(
            detail: detail,
            actions: const <MarkerInfoDetailAction>[],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('marker_info_detail_unlinked_notice'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'falls back to a placeholder when the marker has no description',
        (tester) async {
      final marker = ArtMarker.fromMap(<String, dynamic>{
        'id': 'marker-3',
        'name': 'Bare marker',
        'description': '',
        'latitude': 46.0,
        'longitude': 14.5,
        'markerType': 'other',
        'createdAt': '2026-07-01T10:00:00.000Z',
        'createdBy': 'tester',
      });
      final detail = await _resolve(tester, marker, unavailable: false);

      await tester.pumpWidget(
        _host(
          MarkerInfoDetailSections(
            detail: detail,
            actions: const <MarkerInfoDetailAction>[],
          ),
        ),
      );
      await tester.pump();

      expect(detail.hasDescription, isFalse);
      expect(find.text('Bare marker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
