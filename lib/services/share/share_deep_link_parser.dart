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
  })  : type = AppRouteIntentType.map,
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
  final String? claimProofToken;
  final String? handoffToken;
  final String? proofSource;

  const ShareDeepLinkTarget({
    required this.type,
    required this.id,
    this.attendanceMarkerId,
    this.claimReady = false,
    this.claimProofToken,
    this.handoffToken,
    this.proofSource,
  });

  const ShareDeepLinkTarget.exhibitionClaimReady({
    required String exhibitionId,
    required String attendanceMarkerId,
    String? claimProofToken,
    String? handoffToken,
    String? proofSource,
  }) : this(
          type: ShareEntityType.exhibition,
          id: exhibitionId,
          attendanceMarkerId: attendanceMarkerId,
          claimReady: true,
          claimProofToken: claimProofToken,
          handoffToken: handoffToken,
          proofSource: proofSource,
        );

  ShareDeepLinkTarget copyWith({
    ShareEntityType? type,
    String? id,
    String? attendanceMarkerId,
    bool? claimReady,
    String? claimProofToken,
    String? handoffToken,
    String? proofSource,
  }) {
    return ShareDeepLinkTarget(
      type: type ?? this.type,
      id: id ?? this.id,
      attendanceMarkerId: attendanceMarkerId ?? this.attendanceMarkerId,
      claimReady: claimReady ?? this.claimReady,
      claimProofToken: claimProofToken ?? this.claimProofToken,
      handoffToken: handoffToken ?? this.handoffToken,
      proofSource: proofSource ?? this.proofSource,
    );
  }

  bool get isClaimReadyExhibition {
    return type == ShareEntityType.exhibition &&
        claimReady &&
        ((attendanceMarkerId ?? '').trim().isNotEmpty ||
            (claimProofToken ?? '').trim().isNotEmpty ||
            (handoffToken ?? '').trim().isNotEmpty);
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
    final queryId =
        Uri.decodeComponent((uri.queryParameters['id'] ?? '').trim());
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
    final claimProofToken = _proofTokenFromUri(uri);
    final handoffToken = _handoffTokenFromUri(uri);
    final proofSource = _proofSourceFromUri(uri);
    final explicitClaimReady =
        uri.queryParameters['handoff']?.toLowerCase() == 'claim-ready' ||
            uri.queryParameters['claimReady'] == 'true' ||
            uri.queryParameters['claim_ready'] == 'true';
    final claimReady = intent.type == AppRouteIntentType.exhibition &&
        (explicitClaimReady ||
            (claimProofToken ?? '').isNotEmpty ||
            (handoffToken ?? '').isNotEmpty);
    final attendanceMarkerId = intent.type == AppRouteIntentType.exhibition
        ? _claimReadyMarkerFromUri(uri)
        : null;

    return ShareDeepLinkTarget(
      type: mapped,
      id: id,
      attendanceMarkerId: attendanceMarkerId,
      claimReady: claimReady,
      claimProofToken: claimProofToken,
      handoffToken: handoffToken,
      proofSource: proofSource,
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
      queryParameters:
          parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
    );
  }

  String canonicalPathForTarget(
    ShareDeepLinkTarget target, {
    bool includeProofTokens = true,
  }) {
    final basePath = canonicalPathFor(target.type, target.id);
    if (target.isClaimReadyExhibition) {
      final query = <String, String>{'handoff': 'claim-ready'};
      final markerId = (target.attendanceMarkerId ?? '').trim();
      if (markerId.isNotEmpty) {
        query['attendanceMarkerId'] = markerId;
      }
      if (includeProofTokens) {
        final claimProofToken = (target.claimProofToken ?? '').trim();
        if (claimProofToken.isNotEmpty) {
          query['claimProofToken'] = claimProofToken;
        }
        final handoffToken = (target.handoffToken ?? '').trim();
        if (handoffToken.isNotEmpty) {
          query['handoffToken'] = handoffToken;
        }
      }
      final proofSource = (target.proofSource ?? '').trim();
      if (proofSource.isNotEmpty) {
        query['proofSource'] = proofSource;
      }
      return Uri(path: basePath, queryParameters: query).toString();
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
    final claimReady = (uri.queryParameters['claimReady'] ??
            uri.queryParameters['claim_ready'])
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

  String? _proofTokenFromUri(Uri? uri) {
    if (uri == null) return null;
    final value = (uri.queryParameters['claimProofToken'] ??
            uri.queryParameters['claim_proof_token'] ??
            uri.queryParameters['scanProofToken'] ??
            uri.queryParameters['scan_proof_token'] ??
            uri.queryParameters['proofToken'] ??
            uri.queryParameters['proof_token'])
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _handoffTokenFromUri(Uri? uri) {
    if (uri == null) return null;
    final value = (uri.queryParameters['handoffToken'] ??
            uri.queryParameters['handoff_token'] ??
            uri.queryParameters['scanHandoffToken'] ??
            uri.queryParameters['scan_handoff_token'])
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _proofSourceFromUri(Uri? uri) {
    if (uri == null) return null;
    final value = (uri.queryParameters['proofSource'] ??
            uri.queryParameters['proof_source'] ??
            uri.queryParameters['source'])
        ?.trim();
    return value == null || value.isEmpty ? null : value;
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
