import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/map_marker_subject.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/custom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('resolveArtMarkerIcon maps each marker type to expected icon', () {
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.artwork),
      Icons.auto_awesome,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.institution),
      Icons.museum_outlined,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.event),
      Icons.event_available,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.streetArt),
      CustomIcons.fragrance,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.exhibition),
      CustomIcons.wallArt,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.residency),
      Icons.apartment,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.drop),
      Icons.wallet_giftcard,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.experience),
      Icons.view_in_ar,
    );
    expect(
      KubusMapMarkerHelpers.resolveArtMarkerIcon(ArtMarkerType.other),
      Icons.location_on_outlined,
    );
  });

  test('markerTypeLabel returns localized labels for each marker type',
      () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.artwork),
      l10n.mapMarkerTypeArtworks,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.institution),
      l10n.mapMarkerTypeInstitutions,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.event),
      l10n.mapMarkerTypeEvents,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.exhibition),
      l10n.commonExhibition,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.residency),
      l10n.mapMarkerTypeResidencies,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.drop),
      l10n.mapMarkerTypeDrops,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.experience),
      l10n.mapMarkerTypeExperiences,
    );
    expect(
      KubusMapMarkerHelpers.markerTypeLabel(l10n, ArtMarkerType.other),
      l10n.mapMarkerTypeMisc,
    );
  });

  test('exhibition icon resolvers use wall_art', () {
    expect(AppColorUtils.exhibitionIcon, CustomIcons.wallArt);
    expect(AppColorUtils.markerSubjectIcon('exhibition'), CustomIcons.wallArt);
  });

  test('street and public art icon resolvers use fragrance', () {
    expect(AppColorUtils.streetArtIcon, CustomIcons.fragrance);
    expect(
        AppColorUtils.markerSubjectIcon('street_art'), CustomIcons.fragrance);
    expect(
        AppColorUtils.markerSubjectIcon('public_art'), CustomIcons.fragrance);
  });

  test('street-art creation adds an artwork only when none is linked', () {
    final linkedArtwork = Artwork(
      id: 'art-1',
      title: 'Linked',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.05, 14.5),
      rewards: 0,
      createdAt: DateTime(2026),
    );

    expect(
      KubusMapMarkerCreationHelpers.shouldCreateStreetArtArtwork(
        markerType: ArtMarkerType.streetArt,
        subjectType: MarkerSubjectType.streetArt,
        linkedArtwork: null,
      ),
      isTrue,
    );
    expect(
      KubusMapMarkerCreationHelpers.shouldCreateStreetArtArtwork(
        markerType: ArtMarkerType.streetArt,
        subjectType: MarkerSubjectType.streetArt,
        linkedArtwork: linkedArtwork,
      ),
      isFalse,
    );
    expect(
      KubusMapMarkerCreationHelpers.shouldCreateStreetArtArtwork(
        markerType: ArtMarkerType.other,
        subjectType: MarkerSubjectType.misc,
        linkedArtwork: null,
      ),
      isFalse,
    );
  });

  test('street-art artwork rollback stops once marker persistence is attempted',
      () {
    final artwork = Artwork(
      id: 'art-rollback',
      title: 'Pending marker artwork',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.05, 14.5),
      rewards: 0,
      createdAt: DateTime(2026),
    );

    expect(
      KubusMapMarkerCreationHelpers.shouldRollbackStreetArtArtwork(
        artwork: artwork,
        markerPersistenceAttempted: false,
      ),
      isTrue,
    );
    expect(
      KubusMapMarkerCreationHelpers.shouldRollbackStreetArtArtwork(
        artwork: artwork,
        markerPersistenceAttempted: true,
      ),
      isFalse,
    );
  });
}
