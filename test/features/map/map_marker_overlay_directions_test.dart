import 'package:art_kubus/features/map/shared/map_marker_overlay_actions.dart';
import 'package:art_kubus/features/map/shared/map_marker_overlay_presentation.dart';
import 'package:art_kubus/features/map/shared/marker_overlay_card_metrics.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/widgets/common/kubus_marker_overlay_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalSavedItemsRepository extends SavedItemsRepository {
  _LocalSavedItemsRepository() : super(api: BackendApiService());

  @override
  Future<bool> hasBackendSession() async => true;

  @override
  Future<List<SavedItemRecord>> loadCachedItems() async =>
      const <SavedItemRecord>[];

  @override
  Future<void> cacheItems(List<SavedItemRecord> items) async {}

  @override
  Future<SavedItemRecord> save(SavedItemRecord item) async => item;

  @override
  Future<void> unsave(SavedItemType type, String id) async {}
}

const _ljubljana = LatLng(46.0569, 14.5058);

ArtMarker _marker({
  ArtMarkerType type = ArtMarkerType.artwork,
  LatLng position = _ljubljana,
  Map<String, dynamic>? metadata,
}) {
  return ArtMarker(
    id: 'marker-1',
    name: 'Vodnik mural',
    description: 'A mural.',
    position: position,
    type: type,
    createdAt: DateTime(2024),
    createdBy: 'uploader-wallet',
    metadata: metadata,
  );
}

Artwork _artwork() => Artwork(
      id: 'art-1',
      title: 'Vodnik mural',
      artist: 'Miron Milić',
      description: 'A mural.',
      position: _ljubljana,
      rewards: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      category: 'Mural',
    );

class _Capture extends StatelessWidget {
  const _Capture({
    required this.marker,
    required this.sink,
    this.artwork,
    this.event,
  });

  final ArtMarker marker;
  final Artwork? artwork;
  final KubusEvent? event;
  final void Function(List<MarkerOverlayActionSpec>) sink;

  @override
  Widget build(BuildContext context) {
    sink(
      buildMarkerOverlayActions(
        context: context,
        marker: marker,
        artwork: artwork,
        event: event,
        exhibition: null,
        canPresentExhibition: false,
        baseColor: Colors.blue,
        sourceScreen: 'test',
        onClaimTap: () {},
      ),
    );
    return const SizedBox.shrink();
  }
}

Future<List<MarkerOverlayActionSpec>> _actions(
  WidgetTester tester, {
  required ArtMarker marker,
  Artwork? artwork,
  KubusEvent? event,
}) async {
  late List<MarkerOverlayActionSpec> captured;
  final saved = SavedItemsProvider(repository: _LocalSavedItemsRepository());
  addTearDown(saved.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<ArtworkProvider>(
          create: (_) => ArtworkProvider(),
        ),
        ChangeNotifierProvider<SavedItemsProvider>.value(value: saved),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _Capture(
            marker: marker,
            artwork: artwork,
            event: event,
            sink: (a) => captured = a,
          ),
        ),
      ),
    ),
  );
  return captured;
}

List<String?> _ids(List<MarkerOverlayActionSpec> actions) =>
    actions.map((a) => a.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('directions eligibility', () {
    testWidgets('an artwork marker with a coordinate offers directions',
        (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork(),
      );
      expect(_ids(actions), contains('marker_directions'));
    });

    testWidgets('every subject kind with a coordinate offers directions',
        (tester) async {
      // Institution markers carry no artwork and previously had no actions at
      // all; directions is the one thing they all share.
      final institution = await _actions(
        tester,
        marker: _marker(type: ArtMarkerType.institution),
      );
      expect(_ids(institution), <String?>['marker_directions']);

      final event = await _actions(
        tester,
        marker: _marker(
          type: ArtMarkerType.event,
          metadata: const <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'event-1',
          },
        ),
        event: const KubusEvent(id: 'event-1', title: 'City Walk'),
      );
      expect(_ids(event).first, 'marker_directions');
    });

    testWidgets('no directions without a usable coordinate', (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(position: const LatLng(0, 0)),
        artwork: _artwork(),
      );
      expect(_ids(actions), isNot(contains('marker_directions')));
      // The engagement actions are unaffected.
      expect(_ids(actions), contains('marker_save'));
    });

    testWidgets(
        'a located institution with a null-island marker has no actions',
        (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(
          type: ArtMarkerType.institution,
          position: const LatLng(0, 0),
        ),
      );
      expect(actions, isEmpty);
    });

    testWidgets('the height estimator agrees with the builder', (tester) async {
      final cases = <({ArtMarker marker, Artwork? artwork, KubusEvent? event})>[
        (marker: _marker(), artwork: _artwork(), event: null),
        (
          marker: _marker(type: ArtMarkerType.institution),
          artwork: null,
          event: null
        ),
        (
          marker: _marker(
            type: ArtMarkerType.institution,
            position: const LatLng(0, 0),
          ),
          artwork: null,
          event: null
        ),
        (
          marker: _marker(position: const LatLng(0, 0)),
          artwork: _artwork(),
          event: null
        ),
      ];
      for (final c in cases) {
        final actions = await _actions(
          tester,
          marker: c.marker,
          artwork: c.artwork,
          event: c.event,
        );
        expect(
          markerOverlayHasSecondaryActions(
            marker: c.marker,
            artwork: c.artwork,
            event: c.event,
            exhibition: null,
            canPresentExhibition: false,
            canClaimStreetArt: false,
          ),
          actions.isNotEmpty,
          reason: '${c.marker.type} @ ${c.marker.position}',
        );
      }
    });
  });

  group('authorship adds no action', () {
    testWidgets(
        'a recorded, unknown or wallet-only artist yields the same actions',
        (tester) async {
      final recorded = _ids(await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork(),
      ));
      final unknown = _ids(await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork().copyWith(artist: ''),
      ));
      final walletOnly = _ids(await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork().copyWith(
          artist: '',
          walletAddress: 'uploader-wallet',
        ),
      ));
      // Authorship is shown as text on the card, never as an action: no artist
      // profile is linked, so nothing may be derived from who made the work.
      expect(recorded, <String?>[
        'marker_directions',
        'marker_save',
        'marker_share',
        'marker_like',
      ]);
      expect(unknown, recorded);
      expect(walletOnly, recorded);
    });
  });

  group('ordering and accessibility', () {
    testWidgets('directions precede the engagement actions', (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork(),
      );
      expect(
        _ids(actions),
        <String?>[
          'marker_directions',
          'marker_save',
          'marker_share',
          'marker_like',
        ],
      );
    });

    testWidgets('every action is spoken in words, never as an internal id',
        (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork(),
      );
      for (final a in actions) {
        final spoken = a.semanticsLabel ?? a.label;
        expect(spoken.trim(), isNotEmpty, reason: '${a.id}');
        expect(spoken, isNot(startsWith('marker_')), reason: '${a.id}');
        expect(spoken, isNot(contains('_')), reason: '${a.id}');
      }
    });

    testWidgets('directions name the destination for assistive tech',
        (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(),
        artwork: _artwork(),
      );
      final directions = actions.firstWhere((a) => a.id == 'marker_directions');
      expect(directions.semanticsLabel, 'Navigate to Vodnik mural');
      expect(directions.tooltip, 'Get directions');
    });

    testWidgets('a destination label never falls back to the uploader',
        (tester) async {
      final actions = await _actions(
        tester,
        marker: _marker(type: ArtMarkerType.institution),
      );
      final directions = actions.single;
      expect(directions.semanticsLabel, isNot(contains('uploader-wallet')));
    });
  });

  group('place line', () {
    test('an artwork marker says where it is', () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          metadata: const <String, dynamic>{
            'locationName': 'Ljubljana, Slovenia',
          },
        ),
        artwork: _artwork(),
      );
      expect(presentation.placeText, 'Ljubljana, Slovenia');
    });

    test('is absent when the marker names no place', () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(),
        artwork: _artwork(),
      );
      expect(presentation.placeText, isNull);
    });

    test('is not repeated when the linked subject already carries the venue',
        () {
      final presentation = resolveMarkerOverlayPresentation(
        marker: _marker(
          type: ArtMarkerType.event,
          metadata: const <String, dynamic>{
            'subjectType': 'event',
            'subjectId': 'event-1',
            'locationName': 'Cankarjev dom',
          },
        ),
        event: const KubusEvent(
          id: 'event-1',
          title: 'City Walk',
          locationName: 'Cankarjev dom',
        ),
      );
      expect(presentation.linkedSubject.subtitle, contains('Cankarjev dom'));
      expect(presentation.placeText, isNull);
    });

    test('the estimator reserves a row for it, and only when shown', () {
      final withPlace = MarkerOverlayCardMetrics.resolveContentSpec(
        marker: _marker(
          metadata: const <String, dynamic>{'locationName': 'Ljubljana'},
        ),
        artwork: _artwork(),
      );
      final without = MarkerOverlayCardMetrics.resolveContentSpec(
        marker: _marker(),
        artwork: _artwork(),
      );
      expect(withPlace.hasPlace, isTrue);
      expect(without.hasPlace, isFalse);
      expect(
        MarkerOverlayCardMetrics.headerHeight(withPlace, 1.0),
        greaterThan(MarkerOverlayCardMetrics.headerHeight(without, 1.0)),
      );
    });
  });
}
