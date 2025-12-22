import 'package:flutter/foundation.dart';

import '../models/collection_record.dart';
import '../services/backend_api_service.dart';

class CollectionsProvider extends ChangeNotifier {
  final BackendApiService _api;

  CollectionsProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  final Map<String, CollectionRecord> _byId = <String, CollectionRecord>{};
  final Set<String> _loadingIds = <String>{};
  final Map<String, String> _errorsById = <String, String>{};

  CollectionRecord? getCollectionById(String id) => _byId[id.trim()];

  bool isLoading(String id) => _loadingIds.contains(id.trim());

  String? errorFor(String id) => _errorsById[id.trim()];

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

    _setLoading(collectionId, true);
    _errorsById.remove(collectionId);
    try {
      await _api.updateCollection(
        collectionId: collectionId,
        name: name,
        description: description,
        isPublic: isPublic,
        thumbnailUrl: thumbnailUrl,
      );
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

    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      for (final artworkId in unique) {
        await _api.addArtworkToCollection(
          collectionId: id,
          artworkId: artworkId,
        );
      }
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

  Future<CollectionRecord?> removeArtwork({
    required String collectionId,
    required String artworkId,
  }) async {
    final id = collectionId.trim();
    if (id.isEmpty || artworkId.trim().isEmpty) return null;

    _setLoading(id, true);
    _errorsById.remove(id);
    try {
      await _api.removeArtworkFromCollection(
        collectionId: id,
        artworkId: artworkId,
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

  Future<CollectionRecord> _loadCollection(String collectionId) async {
    final data = await _api.getCollection(collectionId);
    final record = CollectionRecord.fromMap(data);
    _byId[collectionId] = record;
    return record;
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
