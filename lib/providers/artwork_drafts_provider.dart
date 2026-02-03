import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/artwork.dart';
import '../services/backend_api_service.dart';

class ArtworkDraftGalleryItem {
  final Uint8List bytes;
  final String fileName;
  final int? width;
  final int? height;
  final String? mimeType;
  final int? sizeBytes;

  const ArtworkDraftGalleryItem({
    required this.bytes,
    required this.fileName,
    this.width,
    this.height,
    this.mimeType,
    this.sizeBytes,
  });
}

class ArtworkDraftState {
  String title = '';
  String description = '';
  String category = 'Digital Art';
  String tagsCsv = '';

  bool isPublic = true;

  String? locationName;
  double? latitude;
  double? longitude;

  Uint8List? coverBytes;
  String? coverFileName;
  int? coverWidth;
  int? coverHeight;

  final List<ArtworkDraftGalleryItem> gallery = [];

  ArtworkPoapMode poapMode = ArtworkPoapMode.none;
  String poapEventId = '';
  String poapClaimUrl = '';
  String poapTitle = '';
  String poapDescription = '';
  int poapClaimDurationDays = 7;
  Uint8List? poapImageBytes;
  String? poapImageFileName;
  int? poapImageWidth;
  int? poapImageHeight;
  int poapRewardAmount = 1;
  DateTime? poapValidFrom;
  DateTime? poapValidTo;

  bool arEnabled = false;

  bool mintNftAfterPublish = false;
  String nftSeriesName = '';
  String nftSeriesDescription = '';
  int nftTotalSupply = 100;
  double nftMintPrice = 50.0;
  double nftRoyaltyPercent = 10.0;

  int currentStep = 0;
  bool isSubmitting = false;
  double uploadProgress = 0;
  String? submitError;
}

class ArtworkDraftsProvider extends ChangeNotifier {
  final BackendApiService _api;
  final Map<String, ArtworkDraftState> _drafts = {};
  final Map<String, Map<String, dynamic>> _feeCache = {};
  final Map<String, DateTime> _feeCacheUpdatedAt = {};

  ArtworkDraftsProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  String createDraft() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // Random.secure() is not supported on Flutter web.
    // On Flutter web, Random.nextInt(max) has a max range constraint and
    // passing 2^32 (or values that may coerce to 0) can throw RangeError.
    // A 31-bit range is sufficient for entropy when combined with the timestamp.
    final rand = Random().nextInt(1 << 31);
    final id = 'draft_${now}_$rand';
    _drafts[id] = ArtworkDraftState();
    notifyListeners();
    return id;
  }

  ArtworkDraftState? getDraft(String draftId) => _drafts[draftId];

  void disposeDraft(String draftId) {
    _drafts.remove(draftId);
    notifyListeners();
  }

  void setStep(String draftId, int step) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (draft.currentStep == step) return;
    draft.currentStep = step;
    notifyListeners();
  }

  void updateBasics({
    required String draftId,
    String? title,
    String? description,
    String? category,
    String? tagsCsv,
    bool? isPublic,
  }) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (title != null) draft.title = title;
    if (description != null) draft.description = description;
    if (category != null) draft.category = category;
    if (tagsCsv != null) draft.tagsCsv = tagsCsv;
    if (isPublic != null) draft.isPublic = isPublic;
    notifyListeners();
  }

  void updateLocation({
    required String draftId,
    String? locationName,
    double? latitude,
    double? longitude,
  }) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    draft.locationName = locationName;
    draft.latitude = latitude;
    draft.longitude = longitude;
    notifyListeners();
  }

  void setCover({
    required String draftId,
    required Uint8List bytes,
    required String fileName,
    int? width,
    int? height,
  }) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    draft.coverBytes = bytes;
    draft.coverFileName = fileName;
    draft.coverWidth = width;
    draft.coverHeight = height;
    notifyListeners();
  }

  void clearCover(String draftId) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    draft.coverBytes = null;
    draft.coverFileName = null;
    draft.coverWidth = null;
    draft.coverHeight = null;
    notifyListeners();
  }

  void addGalleryItems(String draftId, List<ArtworkDraftGalleryItem> items) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (items.isEmpty) return;
    draft.gallery.addAll(items);
    notifyListeners();
  }

  void removeGalleryItem(String draftId, int index) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (index < 0 || index >= draft.gallery.length) return;
    draft.gallery.removeAt(index);
    notifyListeners();
  }

  void reorderGallery(String draftId, int oldIndex, int newIndex) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (oldIndex < 0 || oldIndex >= draft.gallery.length) return;
    var targetIndex = newIndex;
    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex > draft.gallery.length) targetIndex = draft.gallery.length;
    if (oldIndex < targetIndex) targetIndex -= 1;
    final item = draft.gallery.removeAt(oldIndex);
    draft.gallery.insert(targetIndex, item);
    notifyListeners();
  }

  void updateOptionalFeatures({
    required String draftId,
    ArtworkPoapMode? poapMode,
    String? poapEventId,
    String? poapClaimUrl,
    String? poapTitle,
    String? poapDescription,
    int? poapClaimDurationDays,
    int? poapRewardAmount,
    DateTime? poapValidFrom,
    DateTime? poapValidTo,
    bool? arEnabled,
    bool? mintNftAfterPublish,
    String? nftSeriesName,
    String? nftSeriesDescription,
    int? nftTotalSupply,
    double? nftMintPrice,
    double? nftRoyaltyPercent,
  }) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    if (poapMode != null) draft.poapMode = poapMode;
    if (poapEventId != null) draft.poapEventId = poapEventId;
    if (poapClaimUrl != null) draft.poapClaimUrl = poapClaimUrl;
    if (poapTitle != null) draft.poapTitle = poapTitle;
    if (poapDescription != null) draft.poapDescription = poapDescription;
    if (poapClaimDurationDays != null) {
      draft.poapClaimDurationDays = poapClaimDurationDays < 1 ? 1 : poapClaimDurationDays;
    }
    if (poapRewardAmount != null) draft.poapRewardAmount = poapRewardAmount;
    draft.poapValidFrom = poapValidFrom ?? draft.poapValidFrom;
    draft.poapValidTo = poapValidTo ?? draft.poapValidTo;
    if (arEnabled != null) draft.arEnabled = arEnabled;
    if (mintNftAfterPublish != null) draft.mintNftAfterPublish = mintNftAfterPublish;
    if (nftSeriesName != null) draft.nftSeriesName = nftSeriesName;
    if (nftSeriesDescription != null) draft.nftSeriesDescription = nftSeriesDescription;
    if (nftTotalSupply != null && nftTotalSupply >= 1) draft.nftTotalSupply = nftTotalSupply;
    if (nftMintPrice != null && nftMintPrice >= 0) draft.nftMintPrice = nftMintPrice;
    if (nftRoyaltyPercent != null) {
      draft.nftRoyaltyPercent = nftRoyaltyPercent.clamp(0, 100).toDouble();
    }
    notifyListeners();
  }

  void setPoapImage({
    required String draftId,
    required Uint8List bytes,
    required String fileName,
    int? width,
    int? height,
  }) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    draft.poapImageBytes = bytes;
    draft.poapImageFileName = fileName;
    draft.poapImageWidth = width;
    draft.poapImageHeight = height;
    notifyListeners();
  }

  void clearPoapImage(String draftId) {
    final draft = _drafts[draftId];
    if (draft == null) return;
    draft.poapImageBytes = null;
    draft.poapImageFileName = null;
    draft.poapImageWidth = null;
    draft.poapImageHeight = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> estimatePoapFees(ArtworkPoapMode mode) async {
    if (mode == ArtworkPoapMode.none) return null;
    final action = mode == ArtworkPoapMode.kubusPoap ? 'kubus_poap_create' : 'poap_claim';
    final cacheKey = 'fees:none:$action';
    final now = DateTime.now();
    final cachedAt = _feeCacheUpdatedAt[cacheKey];
    if (cachedAt != null && now.difference(cachedAt) < const Duration(minutes: 10)) {
      return _feeCache[cacheKey];
    }

    final result = await _api.estimateFees(network: 'none', action: action);
    if (result == null) return null;
    _feeCache[cacheKey] = result;
    _feeCacheUpdatedAt[cacheKey] = now;
    return result;
  }

  List<String> _parseTagsCsv(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return <String>[];
    return trimmed
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<Artwork?> submitDraft({
    required String draftId,
    required String walletAddress,
  }) async {
    final draft = _drafts[draftId];
    if (draft == null) return null;
    if (draft.isSubmitting) return null;

    final wallet = walletAddress.trim();
    if (wallet.isEmpty) return null;

    draft.isSubmitting = true;
    draft.submitError = null;
    draft.uploadProgress = 0;
    notifyListeners();

    try {
      final coverBytes = draft.coverBytes;
      if (coverBytes == null) {
        draft.submitError = 'Cover image is required.';
        return null;
      }

      await _api.ensureAuthLoaded(walletAddress: wallet);

      draft.uploadProgress = 0.05;
      notifyListeners();

      final coverUpload = await _api.uploadFile(
        fileBytes: coverBytes,
        fileName: draft.coverFileName ?? 'artwork_cover.png',
        fileType: 'image',
        metadata: {
          'source': 'artwork_creator',
          'folder': 'artworks/covers',
        },
        walletAddress: wallet,
      );

      final coverUrl = coverUpload['uploadedUrl'] as String?
          ?? coverUpload['data']?['url'] as String?;
      if (coverUrl == null || coverUrl.trim().isEmpty) {
        draft.submitError = 'Failed to upload cover image.';
        return null;
      }

      final galleryUrls = <String>[];
      final galleryMeta = <Map<String, dynamic>>[];
      final totalGallery = draft.gallery.length;
      for (var i = 0; i < totalGallery; i++) {
        final item = draft.gallery[i];
        final baseProgress = 0.10 + (0.75 * (i / max(1, totalGallery)));
        draft.uploadProgress = baseProgress;
        notifyListeners();

        final uploaded = await _api.uploadFile(
          fileBytes: item.bytes,
          fileName: item.fileName,
          fileType: 'image',
          metadata: {
            'source': 'artwork_creator',
            'folder': 'artworks/gallery',
            'index': i.toString(),
          },
          walletAddress: wallet,
        );

        final url = uploaded['uploadedUrl'] as String?
            ?? uploaded['data']?['url'] as String?;
        if (url == null || url.trim().isEmpty) {
          draft.submitError = 'Failed to upload a gallery image. Please try again.';
          return null;
        }
        galleryUrls.add(url);
        galleryMeta.add({
          'url': url,
          if (item.width != null) 'width': item.width,
          if (item.height != null) 'height': item.height,
          if (item.mimeType != null) 'mimeType': item.mimeType,
          if (item.sizeBytes != null) 'sizeBytes': item.sizeBytes,
          'fileName': item.fileName,
          'order': i,
        });
      }

      draft.uploadProgress = 0.88;
      notifyListeners();

      final title = draft.title.trim();
      final description = draft.description.trim();
      if (title.isEmpty || description.isEmpty) {
        draft.submitError = 'Title and description are required.';
        return null;
      }

      final poapMode = draft.poapMode;
      final poapEventId = draft.poapEventId.trim();
      final poapClaimUrl = draft.poapClaimUrl.trim();
      final poapRewardAmount = max(1, draft.poapRewardAmount);

      if (poapMode == ArtworkPoapMode.existingPoap) {
        if (!AppConfig.isFeatureEnabled('attendance')) {
          draft.submitError = 'Attendance rewards are currently unavailable.';
          return null;
        }
        if (poapEventId.isEmpty && poapClaimUrl.isEmpty) {
          draft.submitError = 'Please provide a POAP Event ID or a Claim URL.';
          return null;
        }
      }

      if (poapMode == ArtworkPoapMode.kubusPoap && !AppConfig.isFeatureEnabled('attendance')) {
        draft.submitError = 'Attendance rewards are currently unavailable.';
        return null;
      }

      final lat = draft.latitude;
      final lng = draft.longitude;
      if (lat != null || lng != null) {
        if (lat == null || lng == null) {
          draft.submitError = 'Please provide both latitude and longitude (or leave both empty).';
          return null;
        }
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          draft.submitError = 'Location coordinates are invalid.';
          return null;
        }
      }

      String? poapImageUrl;
      final wantsPoap = poapMode != ArtworkPoapMode.none;
      if (wantsPoap) {
        final poapBytes = draft.poapImageBytes;
        if (poapBytes != null && poapBytes.isNotEmpty) {
          draft.uploadProgress = 0.80;
          notifyListeners();
          final uploaded = await _api.uploadFile(
            fileBytes: poapBytes,
            fileName: draft.poapImageFileName ?? 'poap_badge.png',
            fileType: 'image',
            metadata: {
              'source': 'artwork_creator',
              'folder': 'poap/images',
            },
            walletAddress: wallet,
          );
          poapImageUrl = uploaded['uploadedUrl'] as String?
              ?? uploaded['data']?['url'] as String?;
          if (poapImageUrl == null || poapImageUrl.trim().isEmpty) {
            draft.submitError = 'Failed to upload POAP image. Please try again.';
            return null;
          }
        } else {
          poapImageUrl = coverUrl;
        }
      }

      DateTime? poapValidFrom = draft.poapValidFrom;
      DateTime? poapValidTo = draft.poapValidTo;
      if (poapMode == ArtworkPoapMode.kubusPoap) {
        final claimDays = max(1, draft.poapClaimDurationDays);
        poapValidFrom ??= DateTime.now().toUtc();
        poapValidTo ??= poapValidFrom.add(Duration(days: claimDays));
      }

      final poapTitle = draft.poapTitle.trim().isNotEmpty ? draft.poapTitle.trim() : title;
      final poapDescription = draft.poapDescription.trim().isNotEmpty ? draft.poapDescription.trim() : description;

      final artwork = await _api.createArtworkRecord(
        title: title,
        description: description,
        imageUrl: coverUrl,
        walletAddress: wallet,
        category: draft.category,
        tags: _parseTagsCsv(draft.tagsCsv),
        galleryUrls: galleryUrls,
        galleryMeta: galleryMeta,
        isPublic: draft.isPublic,
        enableAR: draft.arEnabled && AppConfig.isFeatureEnabled('ar'),
        // AR model is managed separately; do not attach model here.
        poapMode: poapMode,
        poapEnabled: poapMode != ArtworkPoapMode.none,
        poapEventId: poapMode == ArtworkPoapMode.existingPoap ? poapEventId : null,
        poapClaimUrl: poapMode == ArtworkPoapMode.existingPoap ? poapClaimUrl : null,
        poapTitle: wantsPoap ? poapTitle : null,
        poapDescription: wantsPoap ? poapDescription : null,
        poapImageUrl: poapImageUrl,
        poapValidFrom: poapValidFrom,
        poapValidTo: poapValidTo,
        poapRewardAmount: poapRewardAmount,
        locationName: draft.locationName?.trim().isNotEmpty == true ? draft.locationName!.trim() : null,
        latitude: lat,
        longitude: lng,
        metadata: {
          'source': 'artwork_creator_v2',
        },
      );

      draft.uploadProgress = 1;
      notifyListeners();

      return artwork;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtworkDraftsProvider: submitDraft failed: $e');
      }
      draft.submitError = 'Failed to publish artwork. Please try again.';
      return null;
    } finally {
      draft.isSubmitting = false;
      notifyListeners();
    }
  }
}
