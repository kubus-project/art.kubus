import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart';
import '../models/community_group.dart';
import '../services/backend_api_service.dart';

class CommunityPostDraft {
  final String category;
  final List<String> tags;
  final List<String> mentions;
  final CommunityGroupSummary? targetGroup;
  final CommunityArtworkReference? artwork;
  final CommunityLocation? location;
  final String? locationLabel;

  const CommunityPostDraft({
    this.category = 'post',
    this.tags = const [],
    this.mentions = const [],
    this.targetGroup,
    this.artwork,
    this.location,
    this.locationLabel,
  });

  CommunityPostDraft copyWith({
    String? category,
    List<String>? tags,
    List<String>? mentions,
    CommunityGroupSummary? targetGroup,
    bool clearGroup = false,
    CommunityArtworkReference? artwork,
    bool clearArtwork = false,
    CommunityLocation? location,
    bool clearLocation = false,
    String? locationLabel,
    bool clearLocationLabel = false,
  }) {
    return CommunityPostDraft(
      category: category ?? this.category,
      tags: tags != null ? List<String>.from(tags) : List<String>.from(this.tags),
      mentions:
          mentions != null ? List<String>.from(mentions) : List<String>.from(this.mentions),
      targetGroup: clearGroup ? null : (targetGroup ?? this.targetGroup),
      artwork: clearArtwork ? null : (artwork ?? this.artwork),
      location: clearLocation ? null : (location ?? this.location),
      locationLabel: clearLocationLabel ? null : (locationLabel ?? this.locationLabel),
    );
  }
}

class CommunityHubProvider extends ChangeNotifier {
  CommunityHubProvider({BackendApiService? apiService})
      : _apiService = apiService ?? BackendApiService();

  final BackendApiService _apiService;

  // ---------- Group directory state ----------
  static const int _groupsPageSize = 20;
  final List<CommunityGroupSummary> _groups = [];
  bool _groupsLoading = false;
  bool _groupsInitialized = false;
  bool _groupsHasMore = true;
  int _nextGroupsPage = 1;
  String _currentSearchQuery = '';
  String? _groupsError;

  List<CommunityGroupSummary> get groups => List.unmodifiable(_groups);
  bool get groupsLoading => _groupsLoading;
  bool get groupsInitialized => _groupsInitialized;
  bool get hasMoreGroups => _groupsHasMore;
  String? get groupsError => _groupsError;
  String get currentGroupSearchQuery => _currentSearchQuery;

  Future<void> loadGroups({bool refresh = false, String? search}) async {
    if (_groupsLoading) return;
    final normalizedSearch = search?.trim() ?? _currentSearchQuery;
    final shouldReset = refresh || normalizedSearch != _currentSearchQuery;
    final targetPage = shouldReset ? 1 : _nextGroupsPage;

    _groupsLoading = true;
    _groupsError = null;
    notifyListeners();

    try {
      final results = await _apiService.listCommunityGroups(
        page: targetPage,
        limit: _groupsPageSize,
        search: normalizedSearch.isEmpty ? null : normalizedSearch,
      );
      if (targetPage == 1) {
        _groups
          ..clear()
          ..addAll(results);
      } else {
        for (final summary in results) {
          final idx = _groups.indexWhere((g) => g.id == summary.id);
          if (idx != -1) {
            _groups[idx] = summary;
          } else {
            _groups.add(summary);
          }
        }
      }
      _groupsHasMore = results.length >= _groupsPageSize;
      _nextGroupsPage = targetPage + 1;
      _currentSearchQuery = normalizedSearch;
      _groupsInitialized = true;
    } catch (e) {
      _groupsError = e.toString();
      // Avoid noisy logs in release; failing to load groups is non-fatal.
      if (kDebugMode) {
        debugPrint('CommunityHubProvider.loadGroups failed: $e');
      }
      // Still mark initialized so the UI can render an empty state instead
      // of blocking forever on a missing backend capability.
      _groupsInitialized = true;
      _groupsHasMore = false;
    } finally {
      _groupsLoading = false;
      notifyListeners();
    }
  }

  void _replaceGroupSummary(CommunityGroupSummary summary) {
    final idx = _groups.indexWhere((g) => g.id == summary.id);
    if (idx != -1) {
      _groups[idx] = summary;
    } else {
      _groups.insert(0, summary);
    }
    notifyListeners();
  }

  Future<CommunityGroupSummary?> createGroup({
    required String name,
    String? description,
    bool isPublic = true,
    String? coverImage,
  }) async {
    final summary = await _apiService.createCommunityGroup(
      name: name,
      description: description,
      isPublic: isPublic,
      coverImage: coverImage,
    );
    if (summary != null) {
      _replaceGroupSummary(summary);
    }
    return summary;
  }

  Future<void> joinGroup(String groupId) async {
    final summary = await _apiService.joinCommunityGroup(groupId);
    if (summary != null) {
      _replaceGroupSummary(summary);
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final summary = await _apiService.leaveCommunityGroup(groupId);
    if (summary != null) {
      _replaceGroupSummary(summary);
    } else {
      final idx = _groups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        _groups[idx] = _groups[idx].copyWith(isMember: false);
        notifyListeners();
      }
    }
  }

  // ---------- Group posts state ----------
  static const int _groupPostsPageSize = 30;
  final Map<String, List<CommunityPost>> _groupPosts = {};
  final Map<String, bool> _groupPostsLoading = {};
  final Map<String, bool> _groupPostsHasMore = {};
  final Map<String, int> _groupPostsPage = {};
  final Map<String, String?> _groupPostsError = {};

  List<CommunityPost> groupPosts(String groupId) =>
      List.unmodifiable(_groupPosts[groupId] ?? const []);
  bool groupPostsLoading(String groupId) => _groupPostsLoading[groupId] ?? false;
  bool groupPostsHasMore(String groupId) => _groupPostsHasMore[groupId] ?? true;
  String? groupPostsError(String groupId) => _groupPostsError[groupId];

  Future<void> loadGroupPosts(String groupId, {bool refresh = false}) async {
    if (_groupPostsLoading[groupId] == true) return;
    final targetPage = refresh ? 1 : (_groupPostsPage[groupId] ?? 1);

    _groupPostsLoading[groupId] = true;
    _groupPostsError[groupId] = null;
    notifyListeners();

    try {
      final posts = await _apiService.getGroupPosts(
        groupId,
        page: targetPage,
        limit: _groupPostsPageSize,
      );
      if (targetPage == 1) {
        _groupPosts[groupId] = posts;
      } else {
        final existing = _groupPosts[groupId] ?? const [];
        _groupPosts[groupId] = [...existing, ...posts];
      }
      _groupPostsHasMore[groupId] = posts.length >= _groupPostsPageSize;
      _groupPostsPage[groupId] = targetPage + 1;
    } catch (e) {
      _groupPostsError[groupId] = e.toString();
      debugPrint('CommunityHubProvider.loadGroupPosts failed: $e');
    } finally {
      _groupPostsLoading[groupId] = false;
      notifyListeners();
    }
  }

  Future<CommunityPost?> submitGroupPost(
    String groupId, {
    required String content,
    String? imageUrl,
    List<String>? mediaUrls,
    List<String>? mediaCids,
    String? artworkId,
    String? postType,
    String category = 'post',
    List<String>? tags,
    List<String>? mentions,
    CommunityLocation? location,
    String? locationLabel,
  }) async {
    final created = await _apiService.createGroupPost(
      groupId,
      content: content,
      imageUrl: imageUrl,
      mediaUrls: mediaUrls,
      mediaCids: mediaCids,
      artworkId: artworkId,
      postType: postType,
      category: category,
      tags: tags,
      mentions: mentions,
      location: location,
      locationName: locationLabel ?? location?.name,
    );
    final existing = _groupPosts[groupId] ?? const [];
    _groupPosts[groupId] = [created, ...existing];
    _groupPostsHasMore[groupId] = true;
    final preview = GroupPostPreview(
      id: created.id,
      content: created.content,
      createdAt: created.timestamp,
    );
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      _groups[idx] = _groups[idx].copyWith(latestPost: preview);
    }
    notifyListeners();
    return created;
  }

  // ---------- Art feed state ----------
  List<CommunityPost> _artFeed = const [];
  bool _artFeedLoading = false;
  String? _artFeedError;
  CommunityLocation? _artFeedCenter;
  double _artFeedRadiusKm = 3;
  bool _artFeedHasMore = true;
  int _nextArtFeedPage = 1;
  int _artFeedPageSize = 20;

  List<CommunityPost> get artFeedPosts => _artFeed;
  bool get artFeedLoading => _artFeedLoading;
  String? get artFeedError => _artFeedError;
  CommunityLocation? get artFeedCenter => _artFeedCenter;
  double get artFeedRadiusKm => _artFeedRadiusKm;
  bool get artFeedHasMore => _artFeedHasMore;
  int get artFeedPageSize => _artFeedPageSize;

  Future<void> loadArtFeed({
    required double latitude,
    required double longitude,
    double radiusKm = 3,
    int limit = 20,
    bool refresh = false,
  }) async {
    if (_artFeedLoading) return;
    final targetPage = refresh ? 1 : _nextArtFeedPage;
    final pageSize = limit > 0 ? limit : _artFeedPageSize;
    _artFeedLoading = true;
    _artFeedError = null;
    notifyListeners();
    try {
      final incoming = await _apiService.getCommunityArtFeed(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        limit: pageSize,
        page: targetPage,
      );

      if (targetPage == 1) {
        _artFeed = incoming;
      } else if (incoming.isNotEmpty) {
        final existingIds = _artFeed.map((p) => p.id).toSet();
        final merged = <CommunityPost>[..._artFeed];
        for (final post in incoming) {
          if (existingIds.add(post.id)) {
            merged.add(post);
          }
        }
        _artFeed = merged;
      }

      _artFeedCenter = CommunityLocation(lat: latitude, lng: longitude);
      _artFeedRadiusKm = radiusKm;

      _artFeedHasMore = incoming.length >= pageSize;
      _nextArtFeedPage = _artFeedHasMore ? (targetPage + 1) : targetPage;
      _artFeedPageSize = pageSize;
    } catch (e) {
      _artFeedError = e.toString();
      if (kDebugMode) {
        debugPrint('CommunityHubProvider.loadArtFeed failed: $e');
      }
    } finally {
      _artFeedLoading = false;
      notifyListeners();
    }
  }

  // ---------- Composer draft state ----------
  CommunityPostDraft _draft = const CommunityPostDraft();
  CommunityPostDraft get draft => _draft;

  void resetDraft() {
    _draft = const CommunityPostDraft();
    notifyListeners();
  }

  void setDraftCategory(String category) {
    if (category.trim().isEmpty) return;
    if (_draft.category == category) return;
    _draft = _draft.copyWith(category: category);
    notifyListeners();
  }

  void setDraftGroup(CommunityGroupSummary? group) {
    _draft = _draft.copyWith(targetGroup: group, clearGroup: group == null);
    notifyListeners();
  }

  void setDraftArtwork(CommunityArtworkReference? artwork) {
    _draft = _draft.copyWith(artwork: artwork, clearArtwork: artwork == null);
    notifyListeners();
  }

  void setDraftLocation(CommunityLocation? location, {String? label}) {
    _draft = _draft.copyWith(
      location: location,
      clearLocation: location == null,
      locationLabel: label,
      clearLocationLabel: label == null,
    );
    notifyListeners();
  }

  void addTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;
    if (_draft.tags.contains(normalized)) return;
    final updated = [..._draft.tags, normalized];
    _draft = _draft.copyWith(tags: updated);
    notifyListeners();
  }

  void removeTag(String tag) {
    final updated = _draft.tags.where((t) => t != tag).toList();
    _draft = _draft.copyWith(tags: updated);
    notifyListeners();
  }

  void addMention(String handle) {
    final normalized = handle.trim();
    if (normalized.isEmpty) return;
    if (_draft.mentions.contains(normalized)) return;
    final updated = [..._draft.mentions, normalized];
    _draft = _draft.copyWith(mentions: updated);
    notifyListeners();
  }

  void removeMention(String handle) {
    final updated = _draft.mentions.where((m) => m != handle).toList();
    _draft = _draft.copyWith(mentions: updated);
    notifyListeners();
  }
}
