import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/street_art_claim.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/screens/map_markers/manage_markers_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/map_marker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class _FakeMarkerApi implements MarkerBackendApi {
  int getMyCalls = 0;
  List<ArtMarker> getMyResult = const <ArtMarker>[];

  @override
  String? getAuthToken() => 'token';

  @override
  Future<List<ArtMarker>> getMyArtMarkers() async {
    getMyCalls += 1;
    return getMyResult;
  }

  @override
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload) async {
    return null;
  }

  @override
  Future<ArtMarker?> updateArtMarkerRecord(
    String markerId,
    Map<String, dynamic> updates,
  ) async {
    return null;
  }

  @override
  Future<bool> deleteArtMarkerRecord(String markerId) async {
    return false;
  }

  @override
  Future<StreetArtClaim> submitStreetArtClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<StreetArtClaim>> getStreetArtClaims(String markerId) async {
    return const <StreetArtClaim>[];
  }

  @override
  Future<StreetArtClaim?> reviewStreetArtClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
  }) async {
    return null;
  }
}

ArtMarker _marker(String name) {
  return ArtMarker(
    id: 'marker-1',
    name: name,
    description: 'Marker description',
    position: const LatLng(46.0569, 14.5058),
    type: ArtMarkerType.artwork,
    createdAt: DateTime.utc(2025, 1, 1),
    createdBy: 'wallet_1',
  );
}

void main() {
  testWidgets(
    'mobile ManageMarkersScreen refreshes list from saved editor route result',
    (tester) async {
      final api = _FakeMarkerApi();
      final provider = MarkerManagementProvider(
        api: api,
        mapMarkerService: MapMarkerService(),
      );
      final oldMarker = _marker('Old marker');
      final savedMarker = _marker('Edited marker');
      provider.ingestMarker(oldMarker);
      api.getMyResult = <ArtMarker>[savedMarker];

      await tester.pumpWidget(
        ChangeNotifierProvider<MarkerManagementProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ManageMarkersScreen(),
          ),
        ),
      );

      expect(find.text('Old marker'), findsOneWidget);

      await tester.tap(find.text('Old marker'));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      navigator.pop(savedMarker);

      await tester.pumpAndSettle();

      expect(api.getMyCalls, 1);
      expect(find.text('Edited marker'), findsOneWidget);
      expect(find.text('Old marker'), findsNothing);
    },
  );
}
