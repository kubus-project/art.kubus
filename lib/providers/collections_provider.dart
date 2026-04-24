import 'package:flutter/foundation.dart';

import '../models/collection_record.dart';
import '../services/backend_api_service.dart';

class CollectionsProvider extends ChangeNotifier {
  final BackendApiService _api;

  CollectionsProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  final List<CollectionRecord> _collections = <CollectionRecord>[];
  bool _listLoading = false;
  bool _listInitialized = false;
  String? _listError;

  final Map<String, CollectionRecord> _byId = <String, CollectionRecord>{};
  final Set<String> _loadingIds = <String>{};
  final Map<String, String> _errorsById = <String, String>{};

  List<CollectionRecord> get collections => List.unmodifiable(_collections);
  bool get listLoading => _listLoading;
  bool get listInitialized => _listInitialized;
  String? get listError => _listError;

  CollectionRecord? getCollectionById(String id) => _byId[id.trim()];

  bool isLoading(String id) => _loadingIds.contains(id.trim());

  String? errorFor(String id) => _errorsById[id.trim()];

  Future<void> loadCollections({
    bool refresh = false,
    String? walletAddress,
    int page = 1,
    int limit = 50,
  }) async {
    if (_listLoading) return;
    if (_listInitialized && !refresh) return;
    _listLoading = true;
    _listError = null;
    notifyListeners();

    try {
      final raw = await _api.getCollections(
        walletAddress: walletAddress,
        page: page,
        limit: limit,
      );
      final records = raw.map(CollectionRecord.fromMap).toList(growable: false);
      _collections
        ..clear()
        ..addAll(records);
      for (final record in records) {
        _byId[record.id] = record;
      }
      _listInitialized = true;
    } catch (e) {
      _listError = e.toString();
    } finally {
      _listLoading = false;
      notifyListeners();
    }
  }

  Future<CollectionRecord?> fetchCollection(String id, {bool force = false}) async {
    final collectionId = id.trim();
    if (collectionId.isEmpty) return null;
    if (!force && _byId.containsKey(collectionId)) return _byId[collectionId];

    _setLoading(collectionId, true);
    _errorsById.remove(collectionId);

    try {
      final record = await _loadCollection(collectionId);
      notifyListeners();
      return record;
    } catch (e) {
      _errorsById[collectionId] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(collectionId, false);
    }
  }

  Future<CollectionRecord?> updateCollection({
    required String id,
    String? name,
    String? description,
    bool? isPublic,
    String? thumbnailUrl,
  }) async {
    final collectionId = id.trim();
    if (collectionId.isEmpty) return null;

    final previous = _byId[collectionId];
    _setLoading(collectionId, true);
    _errorsById.remove(collectionId);
    try {
      final response = await _api.updateCollection(
        collectionId: collectionId,
        name: name,
        description: description,
        isPublic: isPublic,
        thumbnailUrl: thumbnailUrl,
      );
      final record = _mergeCollectionResponse(
        collectionId: collectionId,
        response: response,
        previous: previous,
        name: name,
        description: description,
        isPublic: isPublic,
        thumbnailUrl: thumbnailUrl,
      );
      _upsertCollection(record);
      notifyListeners();
      return record;
    } catch (e) {
      _errorsById[collectionId] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(collectionId, false);
    }
  }

  Future<String?> uploadCollectionThumbnail({
    required Uint8List bytes,
    required String fileName,
  }) async {
    // CollectionsProvider is per-collection loading, but uploads are a single request.
    // We don't have a collectionId yet (creator flow) so we do not mark an id as loading.
    try {
      final result = await _api.uploadFile(
        fileBytes: bytes,
        fileName: fileName,
        fileType: 'collection_cover',
        metadata: const <String, String>{
          'folder': 'collections/covers',
        },
      );
      final url = result['uploadedUrl']?.toString();
      return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<CollectionRecord?> addArtwork({
    required String collectionId,
    required String artworkId,
    String? notes,
  }) async {
    final id = collectionId.trim();
    if (id.isEmpty || artworkId.trim().isEmpty) return null;

    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      await _api.addArtworkToCollection(
        collectionId: id,
        artworkId: artworkId,
        notes: notes,
      );
      final record = await _loadCollection(id);
      notifyListeners();
      return record;
    } catch (e) {
      _errorsById[id] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(id, false);
    }
  }

  Future<CollectionRecord?> addArtworks({
    required String collectionId,
    required List<String> artworkIds,
  }) async {
    final id = collectionId.trim();
    final unique = artworkIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (id.isEmpty || unique.isEmpty) return null;

    final previous = _byId[id];
    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      for (final artworkId in unique) {
        await _api.addArtworkToCollection(
          collectionId: id,
          artworkId: artworkId,
        );
      }
      CollectionRecord? record;
      try {
        record = await _loadCollection(id);
      } catch (_) {
        record = _bumpArtworkCount(previous, unique.length);
      }
      _upsertCollection(record);
          notifyListeners();
      return record;
    } catch (e) {
      _errorsById[id] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(id, false);
    }
  }

  Future<CollectionRecord?> removeArtwork({
    required String collectionId,
    required String artworkId,
  }) async {
    final id = collectionId.trim();
    if (id.isEmpty || artworkId.trim().isEmpty) return null;

    final previous = _byId[id];
    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      await _api.removeArtworkFromCollection(
        collectionId: id,
        artworkId: artworkId,
      );
      CollectionRecord? record;
      try {
        record = await _loadCollection(id);
      } catch (_) {
        record = _removeArtworkLocally(previous, artworkId);
      }
      _upsertCollection(record);
          notifyListeners();
      return record;
    } catch (e) {
      _errorsById[id] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(id, false);
    }
  }

  Future<void> deleteCollection(String collectionId) async {
    final id = collectionId.trim();
    if (id.isEmpty) return;

    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      await _api.deleteCollection(id);
      _collections.removeWhere((item) => item.id == id);
      _byId.remove(id);
      notifyListeners();
    } catch (e) {
      _errorsById[id] = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(id, false);
    }
  }

  Future<CollectionRecord> _loadCollection(String collectionId) async {
    final data = await _api.getCollection(collectionId);
    final record = CollectionRecord.fromMap(data);
    _upsertCollection(record);
    return record;
  }

  CollectionRecord _mergeCollectionResponse({
    required String collectionId,
    required Map<String, dynamic> response,
    required CollectionRecord? previous,
    String? name,
    String? description,
    bool? isPublic,
    String? thumbnailUrl,
  }) {
    final parsed = CollectionRecord.fromMap(response);
    final resolvedId = parsed.id.isNotEmpty ? parsed.id : collectionId;
    final base = previous ??
        CollectionRecord(
          id: resolvedId,
          walletAddress: '',
          name: '',
          description: null,
          isPublic: isPublic ?? true,
          artworkCount: 0,
          thumbnailUrl: thumbnailUrl,
        );

    return base.copyWith(
      name: parsed.name.isNotEmpty
          ? parsed.name
          : (name ?? base.name),
      description: parsed.description ?? description ?? base.description,
      isPublic: parsed.id.isNotEmpty ? parsed.isPublic : (isPublic ?? base.isPublic),
      artworkCount: parsed.artworkCount != 0 ? parsed.artworkCount : base.artworkCount,
      thumbnailUrl: parsed.thumbnailUrl ?? thumbnailUrl ?? base.thumbnailUrl,
      artworks: parsed.artworks.isNotEmpty ? parsed.artworks : base.artworks,
      updatedAt: parsed.updatedAt ?? DateTime.now(),
    );
  }

  CollectionRecord _bumpArtworkCount(CollectionRecord? previous, int delta) {
    final base = previous ??
        const CollectionRecord(
          id: '',
          walletAddress: '',
          name: '',
          isPublic: true,
          artworkCount: 0,
        );
    return base.copyWith(
      artworkCount: base.artworkCount + delta,
      updatedAt: DateTime.now(),
    );
  }

  CollectionRecord _removeArtworkLocally(CollectionRecord? previous, String artworkId) {
    final base = previous ??
        const CollectionRecord(
          id: '',
          walletAddress: '',
          name: '',
          isPublic: true,
          artworkCount: 0,
        );
    final nextArtworks = base.artworks
        .where((item) => item.id.trim() != artworkId.trim())
        .toList(growable: false);
    return base.copyWith(
      artworks: nextArtworks,
      artworkCount: base.artworkCount > 0 ? base.artworkCount - 1 : 0,
      updatedAt: DateTime.now(),
    );
  }

  void _upsertCollection(CollectionRecord record) {
    final id = record.id.trim();
    if (id.isEmpty) return;
    _byId[id] = record;
    final index = _collections.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _collections[index] = record;
    } else {
      _collections.insert(0, record);
    }
  }

  void _setLoading(String id, bool value) {
    if (value) {
      _loadingIds.add(id);
    } else {
      _loadingIds.remove(id);
    }
    notifyListeners();
  }
}
