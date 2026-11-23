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
  // The write succeeded but the follow-up read did not. The saved draft stays
  // on screen with a soft retry instead of an error state.
  bool _refreshFailed = false;
  // The draft read failed after a write, so the revision on screen is behind
  // the server's. Edits wait for a successful refresh instead of conflicting.
  bool _draftStale = false;
  List<String>? _automaticOrder;
  String? _pendingSave;
  String? _pendingPublish;

  bool get isCurrent => !_disposed && _epoch == _api.authSessionEpoch;
  bool get busy => isCurrent && _busy;
  bool get dirty => isCurrent && _dirty;
  DraftGallery? get draft => isCurrent ? _draft : null;
  PublishedGallery? get published => isCurrent ? _published : null;
  GalleryLayout? get editing => isCurrent ? _editing : null;
  Object? get error => isCurrent ? _error : null;
  bool get refreshFailed => isCurrent && _refreshFailed;
  bool get needsRefresh => isCurrent && _draftStale;

  /// The host's automatic artwork order when a read has shown it: a draft with
  /// no saved layout, or an automatic published gallery. Null when unknown.
  List<String>? get automaticArtworkOrder => isCurrent ? _automaticOrder : null;

  Future<void> reload() => _operation(() async {
        final loaded = await _fetch();
        if (!isCurrent) return;
        _published = loaded.published;
        _draft = loaded.draft;
        _editing = _draft?.layout;
        _dirty = false;
        _refreshFailed = false;
        _draftStale = false;
        _pendingSave = null;
        _pendingPublish = null;
        _error = loaded.error;
        _learnAutomaticOrder();
      });

  void edit(GalleryLayout? layout) {
    if (!isCurrent || _busy || _draftStale || _draft == null) return;
    _editing = layout;
    _dirty = true;
    _pendingSave = null;
    _error = null;
    notifyListeners();
  }

  Future<void> save() async {
    final base = draft;
    if (base == null || !dirty || _draftStale) return;
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
        _draftStale ||
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

  /// Reads the host again after a write the server accepted. A read that fails
  /// is not allowed to turn that success into an error: what was just saved
  /// stays visible and [refreshFailed] asks for a retry.
  Future<void> _refreshAfterWrite() async {
    final saved = _editing;
    final base = _draft;
    final loaded = await _fetch();
    if (!isCurrent) return;
    _pendingSave = null;
    _pendingPublish = null;
    _dirty = false;
    _error = null;
    _refreshFailed = loaded.publicFailed || loaded.draftFailed;
    _draftStale = loaded.draftFailed;
    if (!loaded.publicFailed) _published = loaded.published;
    if (loaded.draftFailed) {
      _draft = base?.withLayout(saved);
      _editing = saved;
    } else {
      _draft = loaded.draft;
      _editing = _draft?.layout;
    }
    _learnAutomaticOrder();
  }

  /// Retries the read that failed after a successful write.
  Future<void> retryRefresh() async {
    if (!_refreshFailed) return reload();
    await _operation(() async {
      final saved = _editing;
      final base = _draft;
      final loaded = await _fetch();
      if (!isCurrent) return;
      _refreshFailed = loaded.publicFailed || loaded.draftFailed;
      _draftStale = loaded.draftFailed;
      if (!loaded.publicFailed) _published = loaded.published;
      if (!loaded.draftFailed) {
        _draft = loaded.draft;
        _editing = _draft?.layout;
        _dirty = false;
      } else {
        _draft = base?.withLayout(saved);
      }
      _learnAutomaticOrder();
    });
  }

  void _learnAutomaticOrder() {
    final draft = _draft;
    final published = _published;
    if (draft != null && draft.layout == null) {
      _automaticOrder = draft.artworkIds;
    } else if (published != null && published.automatic) {
      _automaticOrder = published.artworkIds;
    }
  }

  Future<
      ({
        PublishedGallery? published,
        DraftGallery? draft,
        Object? error,
        bool publicFailed,
        bool draftFailed,
      })> _fetch() async {
    PublishedGallery? publicResult;
    DraftGallery? privateResult;
    Object? failure;
    var publicFailed = false;
    var draftFailed = false;
    try {
      publicResult = await _api.getPublishedGallery(host);
    } catch (error) {
      failure = error;
      publicFailed = true;
    }
    if (signedIn && isCurrent) {
      try {
        privateResult = await _api.getGalleryDraft(host);
      } catch (error) {
        failure ??= error;
        draftFailed = true;
      }
    }
    return (
      published: publicResult,
      draft: privateResult,
      error: failure,
      publicFailed: publicFailed,
      draftFailed: draftFailed,
    );
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
