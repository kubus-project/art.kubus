import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../models/artwork.dart';
import '../models/dao.dart';
import '../models/institution.dart';
import '../models/exhibition.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/dao_provider.dart';
import '../providers/institution_provider.dart';
import '../providers/wallet_provider.dart';
import '../config/config.dart';
import 'wallet_utils.dart';

class MarkerSubjectData {
  final List<Artwork> artworks;
  final List<Exhibition> exhibitions;
  final List<Institution> institutions;
  final List<Event> events;
  final List<Delegate> delegates;
  final bool wasRefreshed;

  const MarkerSubjectData({
    required this.artworks,
    required this.exhibitions,
    required this.institutions,
    required this.events,
    required this.delegates,
    this.wasRefreshed = false,
  });

  bool get hasOwnedArtworks => artworks.isNotEmpty;
}

/// Centralized loader for marker subject inputs used by both mobile and desktop map screens.
class MarkerSubjectLoader {
  final BuildContext context;

  const MarkerSubjectLoader(this.context);

  MarkerSubjectData snapshot() {
    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final walletProvider = context.read<WalletProvider>();
    final wallet = walletProvider.currentWalletAddress;

    return MarkerSubjectData(
      artworks: _filterOwnedArtworks(artworkProvider.artworks, wallet),
      exhibitions: AppConfig.isFeatureEnabled('exhibitions')
          ? List<Exhibition>.from(exhibitionsProvider.exhibitions)
          : const <Exhibition>[],
      institutions: List<Institution>.from(institutionProvider.institutions),
      events: List<Event>.from(institutionProvider.events),
      delegates: List<Delegate>.from(daoProvider.delegates),
    );
  }

  Future<MarkerSubjectData?> refresh({bool force = false}) async {
    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final walletProvider = context.read<WalletProvider>();
    final wallet = walletProvider.currentWalletAddress;

    final shouldLoadArtworks = force || artworkProvider.artworks.isEmpty;
    final shouldLoadWalletArtworks = wallet != null && wallet.isNotEmpty;
    final shouldLoadInstitutions =
        force || institutionProvider.institutions.isEmpty || institutionProvider.events.isEmpty;
    final shouldLoadDelegates = force || daoProvider.delegates.isEmpty;
    final exhibitionsEnabled = AppConfig.isFeatureEnabled('exhibitions');
    final shouldLoadExhibitions = exhibitionsEnabled && (force || !exhibitionsProvider.initialized);

    final fetches = <Future<void>>[];
    if (shouldLoadArtworks) {
      fetches.add(artworkProvider.loadArtworks(refresh: force));
    }
    if (shouldLoadWalletArtworks) {
      fetches.add(artworkProvider.loadArtworksForWallet(wallet, force: force));
    }
    if (shouldLoadInstitutions) {
      fetches.add(institutionProvider.refreshData());
    }
    if (shouldLoadDelegates) {
      fetches.add(daoProvider.refreshData(force: true));
    }

    if (shouldLoadExhibitions) {
      fetches.add(exhibitionsProvider.initialize(refresh: true));
    }

    if (fetches.isEmpty) {
      return null;
    }

    try {
      await Future.wait(fetches);
      return MarkerSubjectData(
        artworks: _filterOwnedArtworks(artworkProvider.artworks, wallet),
        exhibitions: exhibitionsEnabled
            ? List<Exhibition>.from(exhibitionsProvider.exhibitions)
            : const <Exhibition>[],
        institutions: List<Institution>.from(institutionProvider.institutions),
        events: List<Event>.from(institutionProvider.events),
        delegates: List<Delegate>.from(daoProvider.delegates),
        wasRefreshed: true,
      );
    } catch (e) {
      debugPrint('MarkerSubjectLoader.refresh error: $e');
      return null;
    }
  }

  List<Artwork> _filterOwnedArtworks(List<Artwork> artworks, String? walletAddress) {
    final normalizedWallet = WalletUtils.canonical(walletAddress);
    if (normalizedWallet.isEmpty) return const <Artwork>[];

    return artworks.where((artwork) {
      final meta = artwork.metadata ?? <String, dynamic>{};
      final candidates = <String?>[
        meta['walletAddress']?.toString(),
        meta['wallet_address']?.toString(),
        meta['wallet']?.toString(),
        meta['ownerWallet']?.toString(),
        meta['creatorWallet']?.toString(),
        meta['createdBy']?.toString(),
        meta['created_by']?.toString(),
        artwork.discoveryUserId,
      ];

      for (final candidate in candidates) {
        if (candidate == null) continue;
        if (WalletUtils.equals(candidate, normalizedWallet)) {
          return true;
        }
      }
      final resolved = WalletUtils.resolveFromMap(meta);
      if (WalletUtils.equals(resolved, normalizedWallet)) {
        return true;
      }
      return false;
    }).toList();
  }
}
