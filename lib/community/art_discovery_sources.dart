import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/map/session/kubus_map_session_memory.dart';
import '../models/exhibition.dart';
import '../providers/artwork_provider.dart';
import '../providers/community_art_discovery_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/backend_api_service.dart';
import '../services/user_service.dart';
import '../services/walking_location_service.dart';
import '../utils/wallet_utils.dart';
import 'art_discovery.dart';

const String _savedLatKey = 'art_discovery_last_lat';
const String _savedLngKey = 'art_discovery_last_lng';

/// A map camera zoomed out further than this is the opening world, not an
/// area the visitor chose.
const double _minMeaningfulMapZoom = 5;

/// Wires [CommunityArtDiscoveryProvider] to the live app: the public
/// community and artwork APIs, the visitor's own follows and saves, the map's
/// current area and (only when already allowed, or when asked for) the device.
///
/// Everything it reads from the widget tree is captured here, before the first
/// await, so the returned callbacks never touch a [BuildContext] later.
ArtDiscoverySources buildLiveArtDiscoverySources(BuildContext context) {
  final api = BackendApiService();
  final artworks = context.read<ArtworkProvider>();
  final saved = context.read<SavedItemsProvider>();
  final profile = context.read<ProfileProvider>();
  final wallet = context.read<WalletProvider>();
  KubusMapSessionMemory? mapMemory;
  try {
    mapMemory = context.read<KubusMapSessionMemory>();
  } catch (_) {
    mapMemory = null;
  }

  return ArtDiscoverySources(
    artFeed: (lat, lng, radiusKm, {int limit = 30}) => api.getCommunityArtFeed(
      latitude: lat,
      longitude: lng,
      radiusKm: radiusKm,
      limit: limit,
      includeGeneral: true,
    ),
    publicPosts: ({int limit = 30}) => api.getCommunityPosts(
      page: 1,
      limit: limit,
      surface: 'discover',
      sort: 'recent',
    ),
    artworks: () async {
      if (artworks.artworks.isEmpty) {
        await artworks.loadArtworks();
      }
      return artworks.artworks;
    },
    exhibitions: (location, radiusKm) async {
      final List<Exhibition> list = await api.listExhibitions(
        lat: location?.latitude,
        lng: location?.longitude,
        radiusKm: location == null ? null : radiusKm,
        limit: 20,
      );
      return list;
    },
    signals: () async {
      final walletAddress =
          profile.currentWalletAddress ?? wallet.currentWalletAddress;
      final followed = <String>{};
      if (walletAddress != null && walletAddress.trim().isNotEmpty) {
        try {
          // The shared follow graph: backend list, else the per-wallet cache,
          // so a transient outage does not silently change the ranking.
          final known = await UserService.getKnownFollowingUsers(
            walletAddress: walletAddress,
          );
          for (final raw in known ?? const <String>[]) {
            final key = WalletUtils.canonical(raw);
            if (key.isNotEmpty) followed.add(key);
          }
        } catch (_) {
          // Follows are a personalisation signal, never a requirement.
        }
      }
      return ArtDiscoverySignals(
        followedWallets: followed,
        savedArtworkIds: saved.savedArtworkIds,
        savedPostIds: saved.savedPostIds,
        savedExhibitionIds: saved.savedExhibitionIds,
      );
    },
    selectedArea: () => null,
    mapCenter: () {
      final camera = mapMemory?.camera;
      if (camera == null || camera.zoom < _minMeaningfulMapZoom) return null;
      return ArtDiscoveryLocation(
        latitude: camera.center.latitude,
        longitude: camera.center.longitude,
        source: ArtDiscoveryLocationSource.mapCenter,
      );
    },
    deviceLocation: ({required bool prompt}) => _deviceLocation(prompt: prompt),
    savedLocation: _savedLocation,
    saveLocation: _saveLocation,
  );
}

Future<ArtDiscoveryLocation?> _deviceLocation({required bool prompt}) async {
  try {
    final result = await GeolocatorWalkingLocationService.shared
        .acquireLiveFix(requestPermission: prompt);
    if (!result.isAvailable) return null;
    final position = result.fix!.position;
    return ArtDiscoveryLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      source: ArtDiscoveryLocationSource.device,
    );
  } catch (_) {
    return null;
  }
}

Future<ArtDiscoveryLocation?> _savedLocation() async {
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble(_savedLatKey);
  final lng = prefs.getDouble(_savedLngKey);
  if (lat == null || lng == null) return null;
  return ArtDiscoveryLocation(
    latitude: lat,
    longitude: lng,
    source: ArtDiscoveryLocationSource.saved,
  );
}

Future<void> _saveLocation(ArtDiscoveryLocation location) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_savedLatKey, location.latitude);
  await prefs.setDouble(_savedLngKey, location.longitude);
}
