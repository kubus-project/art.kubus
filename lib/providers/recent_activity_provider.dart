import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/recent_activity.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_action_service.dart';
import 'notification_provider.dart';

class RecentActivityProvider extends ChangeNotifier {
  RecentActivityProvider({
    BackendApiService? backendApiService,
    PushNotificationService? pushNotificationService,
    UserActionService? userActionService,
  })  : _backend = backendApiService ?? BackendApiService(),
        _pushNotifications = pushNotificationService ?? PushNotificationService(),
        _actions = userActionService ?? UserActionService();

  final BackendApiService _backend;
  final PushNotificationService _pushNotifications;
  final UserActionService _actions;

  final int _maxItems = 60;
  List<RecentActivity> _activities = const [];
  bool _isLoading = false;
  bool _initialized = false;
  bool _initializing = false;
  String? _error;
  DateTime? _lastSync;
  NotificationProvider? _notificationProvider;
  Timer? _refreshDebounce;

  List<RecentActivity> get activities => List.unmodifiable(_activities);
  List<RecentActivity> get unreadActivities =>
      List.unmodifiable(_activities.where((activity) => !activity.isRead));
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get hasUnread => _activities.any((activity) => !activity.isRead);

  Future<void> initialize({bool force = false}) async {
    if (_initializing) return;
    if (_initialized && !force) return;
    _initializing = true;
    try {
      await refresh(force: true);
      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  void bindNotificationProvider(NotificationProvider? provider) {
    if (_notificationProvider == provider) return;
    _notificationProvider?.removeListener(_handleNotificationProviderChange);
    _notificationProvider = provider;
    _notificationProvider?.addListener(_handleNotificationProviderChange);
    if (_notificationProvider?.hasNew ?? false) {
      refresh(force: true);
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_isLoading && !force) return;
    _isLoading = true;
    if (_activities.isEmpty) {
      notifyListeners();
    }

    try {
      await _backend.loadAuthToken();
      final remote = await _backend.getNotifications(limit: 100);
      final local = await _pushNotifications.getInAppNotifications();
      final actions = await _actions.getRecentActions(limit: 30);
      final mapped = _mapActivities([...remote, ...local, ...actions]);
      final merged = _preserveLocalReadState(mapped);
      _activities = merged.take(_maxItems).toList();
      _lastSync = DateTime.now();
      _error = null;
    } catch (e, st) {
      debugPrint('RecentActivityProvider.refresh error: $e\n$st');
      _error = 'Unable to load your recent activity';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAllReadLocally() {
    if (!hasUnread) return;
    _activities = _activities
        .map((activity) => activity.isRead
            ? activity
            : activity.copyWith(isRead: true))
        .toList(growable: false);
    notifyListeners();
  }

  void _handleNotificationProviderChange() {
    if ((_notificationProvider?.hasNew ?? false) == false) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      refresh();
    });
  }

  List<RecentActivity> _mapActivities(List<dynamic> rawList) {
    final List<RecentActivity> mapped = [];
    final Set<String> seen = <String>{};
    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      try {
        final activity = _mapSingle(map);
        if (activity == null) continue;
        if (seen.add(activity.id)) {
          mapped.add(activity);
        }
      } catch (e) {
        debugPrint('RecentActivityProvider: failed to map activity: $e');
      }
    }
    mapped.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return mapped;
  }

  List<RecentActivity> _preserveLocalReadState(List<RecentActivity> next) {
    if (_activities.isEmpty) {
      return next;
    }
    final Map<String, RecentActivity> existingById = {
      for (final activity in _activities) activity.id: activity,
    };

    return next
        .map((activity) {
          final previous = existingById[activity.id];
          if (previous == null) return activity;
          if (previous.isRead && !activity.isRead) {
            return activity.copyWith(isRead: true);
          }
          return activity;
        })
        .toList();
  }

  RecentActivity? _mapSingle(Map<String, dynamic> raw) {
    final type = _string(raw['type']) ?? _string(raw['interactionType']) ?? _string(raw['eventType']) ?? 'system';
    final data = _extractData(raw['data']);
    final sender = _extractData(raw['sender']);
    final actorName = _string(raw['actorName']) ?? _string(sender['displayName']) ?? _string(sender['username']) ?? _string(raw['userName']) ?? _string(raw['authorName']);
    final actorAvatar = _string(sender['avatar']) ?? _string(sender['avatarUrl']) ?? _string(raw['actorAvatar']);
    final timestamp = _parseTimestamp(raw['timestamp'] ?? raw['createdAt'] ?? raw['time'] ?? data['timestamp']);
    final id = _string(raw['id']) ?? _string(raw['notificationId']) ?? _buildSyntheticId(type, timestamp, actorName, data);
    var category = activityCategoryFromString(type);
    if (category == ActivityCategory.system) {
      final fallbackType = _string(data['interactionType']) ?? _string(data['eventType']) ?? _string(data['category']);
      if (fallbackType != null) {
        category = activityCategoryFromString(fallbackType);
      }
    }
    final resolvedTitle = _string(raw['title']) ?? _defaultTitle(category, actorName, data);
    final resolvedDescription = _string(raw['message']) ?? _string(raw['description']) ?? _defaultDescription(category, actorName, data);
    final actionUrl = _string(raw['actionUrl']) ?? _string(data['actionUrl']);
    final isRead = _bool(raw['isRead']) ?? _bool(raw['is_read']) ?? true;

    final metadata = <String, dynamic>{
      ...data,
      if (sender.isNotEmpty) 'sender': sender,
      if (raw.containsKey('extra')) 'extra': raw['extra'],
    };

    return RecentActivity(
      id: id,
      category: category,
      title: resolvedTitle,
      description: resolvedDescription,
      timestamp: timestamp,
      isRead: isRead,
      actorName: actorName,
      actorAvatar: actorAvatar,
      actionUrl: actionUrl,
      metadata: metadata,
    );
  }

  Map<String, dynamic> _extractData(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return {'raw': value};
      }
    }
    return const <String, dynamic>{};
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return value;
    }
    return value.toString();
  }

  bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) {
      final isSeconds = value < 10000000000;
      return DateTime.fromMillisecondsSinceEpoch(isSeconds ? value * 1000 : value);
    }
    if (value is num) {
      final millis = value.toInt();
      final isSeconds = millis < 10000000000;
      return DateTime.fromMillisecondsSinceEpoch(isSeconds ? millis * 1000 : millis);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _buildSyntheticId(String? type, DateTime timestamp, String? actor, Map<String, dynamic> data) {
    final parts = [
      type ?? 'system',
      timestamp.toIso8601String(),
      actor ?? '',
      data['targetId']?.toString() ?? data['postId']?.toString() ?? '',
    ];
    return parts.where((element) => element.isNotEmpty).join('-');
  }

  String _defaultTitle(ActivityCategory category, String? actor, Map<String, dynamic> data) {
    switch (category) {
      case ActivityCategory.like:
        return 'New Like';
      case ActivityCategory.comment:
        return 'New Comment';
      case ActivityCategory.discovery:
        return 'Artwork Discovered';
      case ActivityCategory.reward:
        return 'Reward Earned';
      case ActivityCategory.follow:
        return 'New Follower';
      case ActivityCategory.share:
        return 'Post Shared';
      case ActivityCategory.mention:
        return 'You were mentioned';
      case ActivityCategory.nft:
        return 'NFT Update';
      case ActivityCategory.ar:
        return 'AR Event';
      case ActivityCategory.save:
        final targetTitle = data['targetTitle'] ?? data['title'] ?? data['artworkTitle'] ?? data['targetType'] ?? 'item';
        return 'Saved ${targetTitle.toString()}';
      case ActivityCategory.achievement:
        return 'Achievement Unlocked';
      case ActivityCategory.system:
        return data['title']?.toString() ?? 'Activity';
    }
  }

  String _defaultDescription(ActivityCategory category, String? actor, Map<String, dynamic> data) {
    final actorName = actor ?? 'Someone';
    switch (category) {
      case ActivityCategory.like:
        return '$actorName liked your ${data['targetType'] ?? 'post'}';
      case ActivityCategory.comment:
        final comment = data['commentPreview'] ?? data['comment'];
        final snippet = comment?.toString() ?? 'commented on your post';
        return '$actorName: $snippet';
      case ActivityCategory.discovery:
        return data['artworkTitle'] != null
            ? 'Discovered ${data['artworkTitle']}'
            : 'A new artwork was discovered';
      case ActivityCategory.reward:
        final amount = data['amount'] ?? data['rewards'] ?? data['rewardTokens'];
        return amount != null ? '+$amount KUB8 awarded' : 'You earned new rewards';
      case ActivityCategory.follow:
        return '$actorName started following you';
      case ActivityCategory.share:
        return '$actorName shared your post';
      case ActivityCategory.mention:
        return '$actorName mentioned you';
      case ActivityCategory.nft:
        final status = data['status'] ?? 'update';
        return 'NFT $status for ${data['artworkTitle'] ?? 'an artwork'}';
      case ActivityCategory.ar:
        return data['eventTitle']?.toString() ?? 'New AR activity nearby';
      case ActivityCategory.save:
        final targetTitle = data['targetTitle'] ?? data['title'] ?? data['artworkTitle'] ?? data['targetType'] ?? 'item';
        return '$actorName saved ${targetTitle.toString()}';
      case ActivityCategory.achievement:
        return data['title'] != null
            ? '${data['title']} (+${data['rewardTokens'] ?? data['amount'] ?? 0} KUB8)'
            : 'You unlocked a new achievement';
      case ActivityCategory.system:
        return data['message']?.toString() ?? 'Stay tuned for more updates';
    }
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_handleNotificationProviderChange);
    _refreshDebounce?.cancel();
    super.dispose();
  }
}
