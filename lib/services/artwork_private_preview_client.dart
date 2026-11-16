import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/artwork.dart';
import 'account_identity.dart';
import 'backend_api_service.dart';

/// Request-time access to draft artwork previews. Only descriptors are cached;
/// private image bytes stay with the requesting widget in memory.
class ArtworkPrivatePreviewClient {
  static const int maxCachedDescriptors = 24;
  ArtworkPrivatePreviewClient({
    ArtworkPrivatePreviewApi? api,
    bool listenForIdentityChanges = true,
  }) : _api = api ?? BackendApiService(),
       _listening = listenForIdentityChanges {
    if (_listening) AccountIdentity.addListener(_handleIdentityChanged);
  }

  static final ArtworkPrivatePreviewClient shared =
      ArtworkPrivatePreviewClient();

  final ArtworkPrivatePreviewApi _api;
  final bool _listening;
  final Map<String, Future<ArtworkMediaPreviewDescriptor?>> _descriptors = {};
  int _generation = 0;

  @visibleForTesting
  int get descriptorCacheSize => _descriptors.length;

  void _handleIdentityChanged() {
    _generation += 1;
    _descriptors.clear();
  }

  Future<List<int>> loadBytes({
    required String artworkId,
    required String slot,
    required bool isPublic,
    ArtworkMediaPreviewDescriptor? knownDescriptor,
    bool descriptorProvided = false,
  }) async {
    if (isPublic) throw StateError('Public artwork uses its normal media path');
    final id = artworkId.trim();
    final accountKey = AccountIdentity.accountKey;
    if (id.isEmpty || accountKey.isEmpty) {
      throw StateError('Authentication required');
    }
    final generation = _generation;
    final descriptor = knownDescriptor ??
        (descriptorProvided
            ? null
            : await _descriptorFor(id));
    _ensureCurrent(generation, accountKey);
    if (descriptor == null || descriptor.auth != 'bearer') {
      throw StateError('Private preview unavailable');
    }
    final path = descriptor.pathFor(slot);
    if (path == null || !_matchesSubject(id, slot, path)) {
      throw StateError('Private preview unavailable');
    }
    final bytes = await _api.getArtworkPrivateMediaBytes(
      artworkId: id,
      slot: slot,
      descriptorPath: path,
    );
    _ensureCurrent(generation, accountKey);
    return bytes;
  }

  Future<ArtworkMediaPreviewDescriptor?> _descriptorFor(String id) async {
    var pending = _descriptors[id];
    if (pending == null) {
      if (_descriptors.length >= maxCachedDescriptors) {
        _descriptors.remove(_descriptors.keys.first);
      }
      pending = _loadDescriptor(id);
      _descriptors[id] = pending;
    }
    return pending;
  }

  Future<ArtworkMediaPreviewDescriptor?> _loadDescriptor(String id) async {
    final generation = _generation;
    final accountKey = AccountIdentity.accountKey;
    try {
      final artwork = await _api.getArtworkDetailWithMediaPreview(id);
      _ensureCurrent(generation, accountKey);
      if (artwork.id != id || artwork.isPublic) return null;
      return artwork.mediaPreview;
    } catch (_) {
      if (generation == _generation &&
          accountKey == AccountIdentity.accountKey) {
        _descriptors.remove(id);
      }
      rethrow;
    }
  }

  void _ensureCurrent(int generation, String accountKey) {
    if (generation != _generation ||
        accountKey.isEmpty ||
        accountKey != AccountIdentity.accountKey) {
      throw StateError('Artwork preview session changed');
    }
  }

  bool _matchesSubject(String id, String slot, String path) {
    final validSlot =
        slot == 'cover' ||
        slot == 'poap' ||
        RegExp(r'^gallery-(?:[0-9]|[1-9][0-9])$').hasMatch(slot);
    return validSlot &&
        path == '/api/artworks/${Uri.encodeComponent(id)}/media/$slot';
  }

  @visibleForTesting
  void clearForTesting() => _handleIdentityChanged();

  void dispose() {
    if (_listening) AccountIdentity.removeListener(_handleIdentityChanged);
    _descriptors.clear();
    _generation += 1;
  }
}
