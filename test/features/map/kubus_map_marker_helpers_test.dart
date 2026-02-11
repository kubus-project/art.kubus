import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
