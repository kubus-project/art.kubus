import 'package:flutter/foundation.dart';

import 'share_types.dart';

enum AppRouteIntentType {
  marker,
  artwork,
  event,
  post,
  profile,
  exhibition,
  collection,
  nft,
  map,
}

@immutable
class AppRouteIntent {
  const AppRouteIntent._({
    required this.type,
    this.id,
    this.lat,
    this.lng,
    this.zoom,
  });

  const AppRouteIntent.marker(String markerId)
      : this._(type: AppRouteIntentType.marker, id: markerId);

  const AppRouteIntent.artwork(String artworkId)
      : this._(type: AppRouteIntentType.artwork, id: artworkId);

  const AppRouteIntent.event(String eventId)
      : this._(type: AppRouteIntentType.event, id: eventId);

  const AppRouteIntent.post(String postId)
      : this._(type: AppRouteIntentType.post, id: postId);

  const AppRouteIntent.profile(String profileId)
      : this._(type: AppRouteIntentType.profile, id: profileId);

  const AppRouteIntent.exhibition(String exhibitionId)
      : this._(type: AppRouteIntentType.exhibition, id: exhibitionId);

  const AppRouteIntent.collection(String collectionId)
      : this._(type: AppRouteIntentType.collection, id: collectionId);

  const AppRouteIntent.nft(String nftId)
      : this._(type: AppRouteIntentType.nft, id: nftId);

  const AppRouteIntent.map({
    this.lat,
    this.lng,
    this.zoom,
  }) : type = AppRouteIntentType.map,
       id = null;

  final AppRouteIntentType type;
  final String? id;
  final double? lat;
  final double? lng;
  final double? zoom;
}

@immutable
class ShareDeepLinkTarget {
  final ShareEntityType type;
  final String id;
  final String? attendanceMarkerId;
  final bool claimReady;

  const ShareDeepLinkTarget({
    required this.type,
    required this.id,
    this.attendanceMarkerId,
    this.claimReady = false,
  });

  const ShareDeepLinkTarget.exhibitionClaimReady({
    required String exhibitionId,
    required String attendanceMarkerId,
  }) : this(
          type: ShareEntityType.exhibition,
          id: exhibitionId,
          attendanceMarkerId: attendanceMarkerId,
          claimReady: true,
        );

  bool get isClaimReadyExhibition {
    return type == ShareEntityType.exhibition &&
        claimReady &&
        (attendanceMarkerId ?? '').trim().isNotEmpty;
  }
}

class ShareDeepLinkCodec {
  const ShareDeepLinkCodec();

  AppRouteIntent? parseIntent(Uri uri) {
    final segments = uri.pathSegments
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    if (segments.isNotEmpty && segments.first.toLowerCase() == 'map') {
      final lat = _tryParseDouble(uri.queryParameters['lat']);
      final lng = _tryParseDouble(uri.queryParameters['lng']);
      final zoom = _tryParseDouble(
        uri.queryParameters['z'] ?? uri.queryParameters['zoom'],
      );
      if (lat != null && lng != null) {
        return AppRouteIntent.map(lat: lat, lng: lng, zoom: zoom);
      }
    }

    if (segments.length >= 2) {
      for (var i = 0; i < segments.length - 1; i++) {
        final head = segments[i].toLowerCase();
        final intentType = _intentTypeForHead(head);
        if (intentType == null) continue;

        final rawId = segments[i + 1];
        if (rawId.isEmpty) continue;

        final id = Uri.decodeComponent(rawId).trim();
        if (id.isEmpty) continue;

        return _intentFromType(
          intentType,
          id,
          uri: uri,
          segmentIndex: i,
        );
      }
    }

    final queryType = _intentTypeForHead((uri.queryParameters['type'] ?? ''));
    final queryId = Uri.decodeComponent((uri.queryParameters['id'] ?? '').trim());
    if (queryType != null && queryId.isNotEmpty) {
      return _intentFromType(queryType, queryId, uri: uri);
    }

    return null;
  }

  ShareDeepLinkTarget? parseShareTarget(Uri uri) {
    final intent = parseIntent(uri);
    if (intent == null) return null;
    final mapped = _shareTypeForIntent(intent.type);
    final id = intent.id;
    if (mapped == null || id == null || id.isEmpty) return null;
    final claimReady = intent.type == AppRouteIntentType.exhibition &&
        (uri.queryParameters['handoff']?.toLowerCase() == 'claim-ready' ||
            uri.queryParameters['claimReady'] == 'true' ||
            uri.queryParameters['claim_ready'] == 'true' ||
            _claimReadyMarkerFromUri(uri) != null);
    final attendanceMarkerId = intent.type == AppRouteIntentType.exhibition
        ? _claimReadyMarkerFromUri(uri)
        : null;

    return ShareDeepLinkTarget(
      type: mapped,
      id: id,
      attendanceMarkerId: attendanceMarkerId,
      claimReady: claimReady,
    );
  }

  Uri buildUriForTarget(Uri baseUri, ShareTarget target) {
    final normalizedPath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final relativePath = canonicalPathFor(target.type, target.shareId);
    final parsed = Uri.parse(relativePath);
    return baseUri.replace(
      path: '$normalizedPath${parsed.path}',
      queryParameters: parsed.queryParameters.isEmpty
          ? null
          : parsed.queryParameters,
    );
  }

  String canonicalPathForTarget(ShareDeepLinkTarget target) {
    final basePath = canonicalPathFor(target.type, target.id);
    if (target.isClaimReadyExhibition) {
      final markerId = Uri.encodeComponent(target.attendanceMarkerId!.trim());
      return '$basePath?handoff=claim-ready&attendanceMarkerId=$markerId';
    }
    return basePath;
  }

  String canonicalPathFor(ShareEntityType type, String id) {
    final encodedId = Uri.encodeComponent(id.trim());
    return '/${_canonicalHeadForType(type)}/$encodedId';
  }

  AppRouteIntent _intentFromType(
    AppRouteIntentType type,
    String id, {
    Uri? uri,
    int? segmentIndex,
  }) {
    switch (type) {
      case AppRouteIntentType.marker:
        return AppRouteIntent.marker(id);
      case AppRouteIntentType.artwork:
        return AppRouteIntent.artwork(id);
      case AppRouteIntentType.event:
        return AppRouteIntent.event(id);
      case AppRouteIntentType.post:
        return AppRouteIntent.post(id);
      case AppRouteIntentType.profile:
        return AppRouteIntent.profile(id);
      case AppRouteIntentType.exhibition:
        final claimReady = _isClaimReadyUri(uri, segmentIndex: segmentIndex);
        final markerId = _claimReadyMarkerFromUri(uri);
        if (claimReady && (markerId ?? '').trim().isNotEmpty) {
          return AppRouteIntent.exhibition(id);
        }
        return AppRouteIntent.exhibition(id);
      case AppRouteIntentType.collection:
        return AppRouteIntent.collection(id);
      case AppRouteIntentType.nft:
        return AppRouteIntent.nft(id);
      case AppRouteIntentType.map:
        return const AppRouteIntent.map();
    }
  }

  bool _isClaimReadyUri(Uri? uri, {int? segmentIndex}) {
    if (uri == null) return false;
    final handoff = (uri.queryParameters['handoff'] ?? '').trim().toLowerCase();
    if (handoff == 'claim-ready') return true;
    final claimReady = (uri.queryParameters['claimReady'] ?? uri.queryParameters['claim_ready'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (claimReady == 'true') return true;
    if (segmentIndex != null && uri.pathSegments.length > segmentIndex + 2) {
      final segment = uri.pathSegments[segmentIndex + 2].trim().toLowerCase();
      if (segment == 'claim-ready' || segment == 'claim_ready') return true;
    }
    return false;
  }

  String? _claimReadyMarkerFromUri(Uri? uri) {
    if (uri == null) return null;
    final markerFromQuery = (uri.queryParameters['attendanceMarkerId'] ??
            uri.queryParameters['attendance_marker_id'] ??
            uri.queryParameters['markerId'] ??
            uri.queryParameters['marker_id'])
        ?.trim();
    if (markerFromQuery != null && markerFromQuery.isNotEmpty) {
      return markerFromQuery;
    }

    final segments = uri.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i].toLowerCase();
      if (segment == 'claim-ready' || segment == 'claim_ready') {
        final candidate = segments[i + 1].trim();
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }

    return null;
  }

  ShareEntityType? _shareTypeForIntent(AppRouteIntentType type) {
    switch (type) {
      case AppRouteIntentType.marker:
        return ShareEntityType.marker;
      case AppRouteIntentType.artwork:
        return ShareEntityType.artwork;
      case AppRouteIntentType.event:
        return ShareEntityType.event;
      case AppRouteIntentType.post:
        return ShareEntityType.post;
      case AppRouteIntentType.profile:
        return ShareEntityType.profile;
      case AppRouteIntentType.exhibition:
        return ShareEntityType.exhibition;
      case AppRouteIntentType.collection:
        return ShareEntityType.collection;
      case AppRouteIntentType.nft:
        return ShareEntityType.nft;
      case AppRouteIntentType.map:
        return null;
    }
  }

  AppRouteIntentType? _intentTypeForHead(String headRaw) {
    final head = headRaw.trim().toLowerCase();
    switch (head) {
      case 'p':
        return AppRouteIntentType.post;
      case 'a':
        return AppRouteIntentType.artwork;
      case 'm':
        return AppRouteIntentType.marker;
      case 'c':
        return AppRouteIntentType.collection;
      case 'e':
        return AppRouteIntentType.event;
      case 'x':
        return AppRouteIntentType.exhibition;
      case 'u':
        return AppRouteIntentType.profile;
      case 'n':
        return AppRouteIntentType.nft;
      default:
        return null;
    }
  }

  String _canonicalHeadForType(ShareEntityType type) {
    switch (type) {
      case ShareEntityType.marker:
        return 'm';
      case ShareEntityType.artwork:
        return 'a';
      case ShareEntityType.event:
        return 'e';
      case ShareEntityType.post:
        return 'p';
      case ShareEntityType.profile:
        return 'u';
      case ShareEntityType.exhibition:
        return 'x';
      case ShareEntityType.collection:
        return 'c';
      case ShareEntityType.nft:
        return 'n';
    }
  }

  double? _tryParseDouble(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}

class ShareDeepLinkParser {
  const ShareDeepLinkParser();

  ShareDeepLinkTarget? parse(Uri uri) {
    return const ShareDeepLinkCodec().parseShareTarget(uri);
  }
}
