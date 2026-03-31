import 'dart:async';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/street_art_claim.dart';
import 'package:art_kubus/providers/street_art_claims_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMarkerApi implements MarkerBackendApi {
  _FakeMarkerApi({this.token = 'token'});

  @override
  String? getAuthToken() => token;

  String token;

  int getClaimsCalls = 0;
  Completer<List<StreetArtClaim>>? getClaimsCompleter;
  List<StreetArtClaim> getClaimsResult = const <StreetArtClaim>[];

  int submitClaimCalls = 0;
  Completer<StreetArtClaim>? submitClaimCompleter;
  StreetArtClaim? submitClaimResult;

  int reviewClaimCalls = 0;
  Completer<StreetArtClaim?>? reviewClaimCompleter;
  StreetArtClaim? reviewClaimResult;

  @override
  Future<List<StreetArtClaim>> getStreetArtClaims(String markerId) {
    getClaimsCalls += 1;
    final completer = getClaimsCompleter;
    if (completer != null) return completer.future;
    return Future<List<StreetArtClaim>>.value(getClaimsResult);
  }

  @override
  Future<StreetArtClaim> submitStreetArtClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
  }) {
    submitClaimCalls += 1;
    final completer = submitClaimCompleter;
    if (completer != null) return completer.future;
    return Future<StreetArtClaim>.value(
      submitClaimResult ?? _claim('claim_submitted', markerId),
    );
  }

  @override
  Future<StreetArtClaim?> reviewStreetArtClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
  }) {
    reviewClaimCalls += 1;
    final completer = reviewClaimCompleter;
    if (completer != null) return completer.future;
    return Future<StreetArtClaim?>.value(reviewClaimResult);
  }

  // Unused MarkerBackendApi methods in this provider test file.
  @override
  Future<List<ArtMarker>> getMyArtMarkers() =>
      Future<List<ArtMarker>>.value(const <ArtMarker>[]);

  @override
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload) =>
      Future<ArtMarker?>.value(null);

  @override
  Future<ArtMarker?> updateArtMarkerRecord(
    String markerId,
    Map<String, dynamic> updates,
  ) =>
      Future<ArtMarker?>.value(null);

  @override
  Future<bool> deleteArtMarkerRecord(String markerId) =>
      Future<bool>.value(true);
}

StreetArtClaim _claim(String id, String markerId) {
  return StreetArtClaim(
    id: id,
    markerId: markerId,
    claimantWallet: 'wallet_2',
    reason: 'I painted this mural and can verify location/time.',
    status: StreetArtClaimStatus.pendingOwnerReview,
    reviewStage: StreetArtClaimStage.ownerReview,
    createdAt: DateTime.utc(2025, 1, 1),
  );
}

void main() {
  test(
      'StreetArtClaimsProvider.loadClaims does not short-circuit when auth token is not preloaded',
      () async {
    final api = _FakeMarkerApi(token: '');
    final provider = StreetArtClaimsProvider(api: api);

    api.getClaimsResult = <StreetArtClaim>[_claim('claim_lazy', 'marker_0')];

    await provider.loadClaims('marker_0', force: true);

    expect(api.getClaimsCalls, 1);
    final claims = provider.claimsForMarker('marker_0');
    expect(claims.length, 1);
    expect(claims.first.id, 'claim_lazy');
  });

  test('StreetArtClaimsProvider.loadClaims dedupes in-flight requests',
      () async {
    final api = _FakeMarkerApi();
    final provider = StreetArtClaimsProvider(api: api);

    api.getClaimsCompleter = Completer<List<StreetArtClaim>>();

    final f1 = provider.loadClaims('marker_1', force: true);
    final f2 = provider.loadClaims('marker_1', force: false);

    expect(api.getClaimsCalls, 1);

    api.getClaimsCompleter!
        .complete(<StreetArtClaim>[_claim('claim_1', 'marker_1')]);

    await Future.wait(<Future<void>>[f1, f2]);

    final claims = provider.claimsForMarker('marker_1');
    expect(claims.length, 1);
    expect(claims.first.id, 'claim_1');
  });

  test('StreetArtClaimsProvider.submitClaim updates marker claim list',
      () async {
    final api = _FakeMarkerApi();
    final provider = StreetArtClaimsProvider(api: api);

    api.submitClaimResult = _claim('claim_new', 'marker_2');
    api.getClaimsResult = <StreetArtClaim>[api.submitClaimResult!];

    final created = await provider.submitClaim(
      markerId: 'marker_2',
      reason: 'I am the original artist of this wall piece.',
      refresh: true,
    );

    expect(created, isNotNull);
    expect(api.submitClaimCalls, 1);

    final claims = provider.claimsForMarker('marker_2');
    expect(claims.any((entry) => entry.id == 'claim_new'), true);
  });

  test('StreetArtClaimsProvider.reviewClaim updates existing claim', () async {
    final api = _FakeMarkerApi();
    final provider = StreetArtClaimsProvider(api: api);

    api.getClaimsResult = <StreetArtClaim>[_claim('claim_3', 'marker_3')];
    await provider.loadClaims('marker_3', force: true);

    api.reviewClaimResult = StreetArtClaim(
      id: 'claim_3',
      markerId: 'marker_3',
      claimantWallet: 'wallet_2',
      reason: 'I painted this mural and can verify location/time.',
      status: StreetArtClaimStatus.approved,
      reviewStage: StreetArtClaimStage.resolved,
      createdAt: DateTime.utc(2025, 1, 1),
      resolvedAt: DateTime.utc(2025, 1, 2),
    );
    api.getClaimsResult = <StreetArtClaim>[api.reviewClaimResult!];

    final updated = await provider.reviewClaim(
      markerId: 'marker_3',
      claimId: 'claim_3',
      action: StreetArtClaimReviewAction.approve,
      refresh: true,
    );

    expect(updated, isNotNull);
    expect(api.reviewClaimCalls, 1);

    final claims = provider.claimsForMarker('marker_3');
    expect(claims.length, 1);
    expect(claims.first.status, StreetArtClaimStatus.approved);
    expect(claims.first.reviewStage, StreetArtClaimStage.resolved);
  });
}
