import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/artwork.dart';
import '../models/promotion.dart';
import '../services/backend_api_service.dart';

class PromotionProvider extends ChangeNotifier {
  final BackendApiService _api;

  PromotionProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final Map<PromotionEntityType, List<PromotionPackage>> _packagesByType =
      <PromotionEntityType, List<PromotionPackage>>{};
  final List<PromotionRequest> _myRequests = <PromotionRequest>[];
  List<Artwork> _featuredArtworks = <Artwork>[];
  List<FeaturedPromotionItem> _featuredProfiles = <FeaturedPromotionItem>[];

  bool _packagesLoading = false;
  bool _requestsLoading = false;
  bool _featuredLoading = false;
  bool _submitting = false;
  String? _error;
  String _lastFeaturedLocale = 'en';

  bool get packagesLoading => _packagesLoading;
  bool get requestsLoading => _requestsLoading;
  bool get featuredLoading => _featuredLoading;
  bool get submitting => _submitting;
  String? get error => _error;
  String get lastFeaturedLocale => _lastFeaturedLocale;

  List<PromotionPackage> packagesFor(PromotionEntityType entityType) =>
      List.unmodifiable(
          _packagesByType[entityType] ?? const <PromotionPackage>[]);

  List<PromotionRequest> get myRequests => List.unmodifiable(_myRequests);
  List<Artwork> get featuredArtworks => List.unmodifiable(_featuredArtworks);
  List<FeaturedPromotionItem> get featuredProfiles =>
      List.unmodifiable(_featuredProfiles);

  Future<void> loadPackages(
    PromotionEntityType entityType, {
    bool force = false,
  }) async {
    if (_packagesLoading) return;
    if (!force && (_packagesByType[entityType]?.isNotEmpty ?? false)) return;

    _packagesLoading = true;
    _error = null;
    notifyListeners();
    try {
      final packages = await _api.getPromotionPackages(entityType: entityType);
      _packagesByType[entityType] = packages;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _packagesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRequests({bool force = false}) async {
    if (_requestsLoading) return;
    if (!force && _myRequests.isNotEmpty) return;

    _requestsLoading = true;
    _error = null;
    notifyListeners();
    try {
      final requests = await _api.getMyPromotionRequests();
      _myRequests
        ..clear()
        ..addAll(requests);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  Future<PromotionRequestSubmission?> submitPromotionRequest({
    required String targetEntityId,
    required PromotionEntityType entityType,
    required String packageId,
    required PromotionPaymentMethod paymentMethod,
    DateTime? requestedStartDate,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final submission = await _api.createPromotionRequest(
        targetEntityId: targetEntityId,
        entityType: entityType,
        packageId: packageId,
        paymentMethod: paymentMethod,
        requestedStartDate: requestedStartDate,
      );
      _myRequests.removeWhere((r) => r.id == submission.request.id);
      _myRequests.insert(0, submission.request);
      return submission;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> loadFeaturedHome({
    String locale = 'en',
    bool force = false,
  }) async {
    if (_featuredLoading) return;
    if (!force &&
        _featuredArtworks.isNotEmpty &&
        _featuredProfiles.isNotEmpty &&
        _lastFeaturedLocale == locale) {
      return;
    }

    _featuredLoading = true;
    _error = null;
    notifyListeners();
    String? artworkError;
    String? profileError;
    var loadedAny = false;

    try {
      try {
        final artworkItems = await _api.getPublicFeaturedHome(
          kind: PromotionEntityType.artwork,
          locale: locale,
        );
        _featuredArtworks = artworkItems
            .map(_featuredArtworkFromItem)
            .whereType<Artwork>()
            .toList(growable: false);
        loadedAny = true;
      } catch (e) {
        artworkError = e.toString();
      }

      try {
        _featuredProfiles = await _api.getPublicFeaturedHome(
          kind: PromotionEntityType.profile,
          locale: locale,
        );
        loadedAny = true;
      } catch (e) {
        profileError = e.toString();
      }

      _lastFeaturedLocale = locale;

      final errors = <String>[
        if (artworkError != null && artworkError!.trim().isNotEmpty)
          artworkError!,
        if (profileError != null && profileError!.trim().isNotEmpty)
          profileError!,
      ];

      if (!loadedAny && errors.isNotEmpty) {
        _error = errors.join(' | ');
      } else if (errors.isNotEmpty) {
        _error = errors.join(' | ');
      }
    } finally {
      _featuredLoading = false;
      notifyListeners();
    }
  }

  Artwork? _featuredArtworkFromItem(FeaturedPromotionItem item) {
    final raw = Map<String, dynamic>.from(item.raw);
    if (raw.isEmpty) return null;
    raw['promotion'] = item.promotion.toJson();
    raw['id'] ??= item.id;
    raw['title'] ??= item.title;
    raw['artist'] ??= item.subtitle ?? 'Unknown Artist';
    raw['description'] ??= '';
    try {
      final parsed = parseArtworkFromBackendJson(raw);
      if (parsed.id.trim().isEmpty) return null;
      return parsed;
    } catch (_) {
      return Artwork(
        id: item.id,
        title: item.title,
        artist: item.subtitle ?? 'Unknown Artist',
        description: '',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: DateTime.now(),
        imageUrl: item.imageUrl,
        promotion: item.promotion,
      );
    }
  }
}
