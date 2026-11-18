import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/gallery_presentation.dart';

class GalleryController extends ChangeNotifier {
  GalleryController({
    required GalleryApi api,
    required this.host,
    required this.signedIn,
  })  : _api = api,
        _epoch = api.authSessionEpoch;

  final GalleryApi _api;
  final GalleryHost host;
  final bool signedIn;
  final int _epoch;
  bool _disposed = false;
  bool _busy = false;
  bool _dirty = false;
  DraftGallery? _draft;
  PublishedGallery? _published;
  GalleryLayout? _editing;
  Object? _error;
  String? _pendingSave;
  String? _pendingPublish;

  bool get isCurrent => !_disposed && _epoch == _api.authSessionEpoch;
  bool get busy => isCurrent && _busy;
  bool get dirty => isCurrent && _dirty;
  DraftGallery? get draft => isCurrent ? _draft : null;
  PublishedGallery? get published => isCurrent ? _published : null;
  GalleryLayout? get editing => isCurrent ? _editing : null;
  Object? get error => isCurrent ? _error : null;

  Future<void> reload() => _operation(() async {
        final loaded = await _fetch();
        if (!isCurrent) return;
        _published = loaded.published;
        _draft = loaded.draft;
        _editing = _draft?.layout;
        _dirty = false;
        _pendingSave = null;
        _pendingPublish = null;
        _error = loaded.error;
      });

  void edit(GalleryLayout? layout) {
    if (!isCurrent || _busy || _draft == null) return;
    _editing = layout;
    _dirty = true;
    _pendingSave = null;
    _error = null;
    notifyListeners();
  }

  Future<void> save() async {
    final base = draft;
    if (base == null || !dirty) return;
    await _operation(() async {
      _pendingSave ??= _mutationId();
      await _api.saveGalleryDraft(
        host,
        expectedRevision: base.revision,
        mutationId: _pendingSave!,
        layout: _editing,
      );
      if (!isCurrent) return;
      await _refreshAfterWrite();
    });
  }

  Future<void> publish() async {
    final base = draft;
    if (base == null ||
        !base.canPublish ||
        !base.hasUnpublishedChanges ||
        dirty) {
      return;
    }
    await _operation(() async {
      _pendingPublish ??= _mutationId();
      await _api.publishGallery(
        host,
        expectedRevision: base.revision,
        mutationId: _pendingPublish!,
      );
      if (!isCurrent) return;
      await _refreshAfterWrite();
    });
  }

  Future<void> _refreshAfterWrite() async {
    final loaded = await _fetch();
    if (!isCurrent) return;
    _published = loaded.published;
    _draft = loaded.draft;
    _editing = _draft?.layout;
    _dirty = false;
    _pendingSave = null;
    _pendingPublish = null;
    _error = loaded.error;
  }

  Future<({PublishedGallery? published, DraftGallery? draft, Object? error})>
      _fetch() async {
    PublishedGallery? publicResult;
    DraftGallery? privateResult;
    Object? failure;
    try {
      publicResult = await _api.getPublishedGallery(host);
    } catch (error) {
      failure = error;
    }
    if (signedIn && isCurrent) {
      try {
        privateResult = await _api.getGalleryDraft(host);
      } catch (error) {
        failure ??= error;
      }
    }
    return (published: publicResult, draft: privateResult, error: failure);
  }

  Future<void> _operation(Future<void> Function() work) async {
    if (!isCurrent || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await work();
    } catch (error) {
      if (!isCurrent) return;
      _error = error;
      if (error is GalleryRequestException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404)) {
        _draft = null;
        _editing = null;
        _dirty = false;
        _pendingSave = null;
        _pendingPublish = null;
      }
    } finally {
      _busy = false;
      if (isCurrent) notifyListeners();
    }
  }

  static String _mutationId() {
    final random = Random.secure();
    return base64Url.encode(List.generate(18, (_) => random.nextInt(256)));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
