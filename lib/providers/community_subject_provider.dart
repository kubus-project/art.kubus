import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart';
import '../models/community_subject.dart';
import '../services/backend_api_service.dart';
import '../utils/media_url_resolver.dart';

class CommunitySubjectProvider extends ChangeNotifier {
  CommunitySubjectProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final BackendApiService _api;
  final Map<String, CommunitySubjectPreview> _cache = {};
  final Set<String> _resolving = <String>{};
  final Set<String> _pendingKeys = <String>{};
  final Map<String, CommunitySubjectRef> _pendingRefs = {};
  bool _resolveScheduled = false;

  CommunitySubjectPreview? previewFor(CommunitySubjectRef ref) {
    return _cache[ref.key];
  }

  void upsertPreview(CommunitySubjectPreview preview) {
    _cache[preview.ref.key] = preview;
    notifyListeners();
  }

  void primeFromPosts(Iterable<CommunityPost> posts) {
    bool seeded = false;
    final refs = <CommunitySubjectRef>[];
    for (final post in posts) {
      final ref = _subjectRefFromPost(post);
      if (ref == null) continue;
      refs.add(ref);
      if (ref.normalizedType == 'artwork' && post.artwork != null) {
        final key = ref.key;
        if (!_cache.containsKey(key)) {
          _cache[key] = CommunitySubjectPreview(
            ref: ref,
            title: post.artwork!.title,
            imageUrl: MediaUrlResolver.resolve(post.artwork!.imageUrl) ?? post.artwork!.imageUrl,
          );
          seeded = true;
        }
      }
    }
    if (seeded) {
      notifyListeners();
    }
    queueResolve(refs);
  }

  void queueResolve(Iterable<CommunitySubjectRef> refs) {
    for (final ref in refs) {
      final key = ref.key;
      if (_cache.containsKey(key) || _resolving.contains(key)) continue;
      if (_pendingKeys.add(key)) {
        _pendingRefs[key] = ref;
      }
    }
    if (_pendingKeys.isEmpty || _resolveScheduled) return;
    _resolveScheduled = true;
    Future.microtask(_flushPending);
  }

  Future<void> _flushPending() async {
    _resolveScheduled = false;
    if (_pendingKeys.isEmpty) return;

    final refs = List<CommunitySubjectRef>.from(_pendingRefs.values);
    _pendingKeys.clear();
    _pendingRefs.clear();

    for (final ref in refs) {
      _resolving.add(ref.key);
    }

    try {
      final payload = refs
          .map((ref) => {'type': ref.normalizedType, 'id': ref.id})
          .toList(growable: false);
      final response = await _api.resolveCommunitySubjects(subjects: payload);
      bool updated = false;
      for (final raw in response) {
        final preview = CommunitySubjectPreview.fromMap(raw);
        if (preview.ref.id.isEmpty || preview.ref.normalizedType.isEmpty) continue;
        final image = preview.imageUrl;
        final resolvedImage = image == null ? null : MediaUrlResolver.resolve(image) ?? image;
        final normalizedPreview = CommunitySubjectPreview(
          ref: CommunitySubjectRef(type: preview.ref.normalizedType, id: preview.ref.id),
          title: preview.title,
          subtitle: preview.subtitle,
          imageUrl: resolvedImage,
        );
        _cache[normalizedPreview.ref.key] = normalizedPreview;
        updated = true;
      }
      if (updated) {
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal; cache misses can be resolved on the next attempt.
    } finally {
      for (final ref in refs) {
        _resolving.remove(ref.key);
      }
    }
  }

  CommunitySubjectRef? _subjectRefFromPost(CommunityPost post) {
    final type = (post.subjectType ?? '').trim();
    final id = (post.subjectId ?? '').trim();
    if (type.isNotEmpty && id.isNotEmpty) {
      return CommunitySubjectRef(type: type, id: id);
    }
    if (post.artwork != null) {
      return CommunitySubjectRef(type: 'artwork', id: post.artwork!.id);
    }
    return null;
  }
}
