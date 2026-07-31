import 'package:art_kubus/features/map/shared/map_marker_overlay_actions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only repository: `saveItem` updates provider state optimistically, so
/// the test never needs a backend round trip.
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

ArtMarker _linkedMarker({required String subjectType, required String id}) {
  return ArtMarker(
    id: 'marker-1',
    name: 'Marker',
    description: '',
    position: const LatLng(46.0569, 14.5058),
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024),
    createdBy: 'tester',
    metadata: <String, dynamic>{
      'subjectType': subjectType,
      'subjectId': id,
    },
  );
}

/// Renders the action specs without holding any state of its own, so a repaint
/// can only come from a provider subscription established inside
/// `buildMarkerOverlayActions`.
class _ActionsHost extends StatelessWidget {
  const _ActionsHost({
    required this.marker,
    this.event,
    this.exhibition,
  });

  final ArtMarker marker;
  final KubusEvent? event;
  final Exhibition? exhibition;

  @override
  Widget build(BuildContext context) {
    final actions = buildMarkerOverlayActions(
      context: context,
      marker: marker,
      artwork: null,
      event: event,
      exhibition: exhibition,
      canPresentExhibition: false,
      baseColor: Colors.blue,
      sourceScreen: 'test_marker',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final action in actions)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(action.icon, key: Key('icon:${action.semanticsLabel}')),
              Text(action.label),
            ],
          ),
      ],
    );
  }
}

Future<void> _pumpHost(WidgetTester tester, SavedItemsProvider saved,
    {required Widget host}) {
  return tester.pumpWidget(
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
        home: Scaffold(body: host),
      ),
    ),
  );
}

IconData _iconFor(WidgetTester tester, String semanticsLabel) {
  final icon = tester.widget<Icon>(find.byKey(Key('icon:$semanticsLabel')));
  return icon.icon!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('event Save action follows SavedItemsProvider changes',
      (tester) async {
    final saved = SavedItemsProvider(
      repository: _LocalSavedItemsRepository(),
    );
    addTearDown(saved.dispose);

    await _pumpHost(
      tester,
      saved,
      host: _ActionsHost(
        marker: _linkedMarker(subjectType: 'event', id: 'event-1'),
        event: const KubusEvent(id: 'event-1', title: 'City Walk'),
      ),
    );

    expect(_iconFor(tester, 'marker_event_save'), Icons.bookmark_border);

    // No setState from the host: only a provider subscription can repaint this.
    await saved.setEventSaved('event-1', true);
    await tester.pump();

    expect(_iconFor(tester, 'marker_event_save'), Icons.bookmark);
  });

  testWidgets('exhibition Save action follows SavedItemsProvider changes',
      (tester) async {
    final saved = SavedItemsProvider(
      repository: _LocalSavedItemsRepository(),
    );
    addTearDown(saved.dispose);

    await _pumpHost(
      tester,
      saved,
      host: _ActionsHost(
        marker: _linkedMarker(subjectType: 'exhibition', id: 'exhibition-1'),
        exhibition: const Exhibition(id: 'exhibition-1', title: 'Group Show'),
      ),
    );

    expect(_iconFor(tester, 'marker_exhibition_save'), Icons.bookmark_border);

    await saved.setExhibitionSaved('exhibition-1', true);
    await tester.pump();

    expect(_iconFor(tester, 'marker_exhibition_save'), Icons.bookmark);
  });
}
