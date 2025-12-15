import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collab_invite.dart';
import '../models/collab_member.dart';
import '../config/config.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';

class CollabProvider extends ChangeNotifier {
  final BackendApiService _api;
  final PushNotificationService _notifications;

  CollabProvider({BackendApiService? api, PushNotificationService? notifications})
      : _api = api ?? BackendApiService(),
        _notifications = notifications ?? PushNotificationService();

  final Map<String, List<CollabMember>> _membersByEntityKey = <String, List<CollabMember>>{};
  final List<CollabInvite> _invitesInbox = <CollabInvite>[];
  final Set<String> _knownInviteIds = <String>{};

  Timer? _invitePollingTimer;
  bool _pollingInFlight = false;
  bool _knownInvitesHydrated = false;
  bool _readyToNotifyNewInvites = false;

  DateTime? _inviteBackoffUntil;
  Duration _inviteBackoff = Duration.zero;

  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  List<CollabInvite> get invitesInbox => List.unmodifiable(_invitesInbox);

  int get pendingInviteCount => _invitesInbox.where((i) => i.isPending).length;

  static String _key(String entityType, String entityId) => '${entityType.trim()}:${entityId.trim()}';

  List<CollabMember> collaboratorsFor(String entityType, String entityId) {
    return List.unmodifiable(_membersByEntityKey[_key(entityType, entityId)] ?? const <CollabMember>[]);
  }

  Future<void> initialize({bool refresh = false}) async {
    if (_initialized && !refresh) return;
    _initialized = true;
    await _hydrateKnownInvitesOnce();
    await refreshInvites(notifyOnNew: false);
    _readyToNotifyNewInvites = true;
  }

  Future<void> refreshInvites({bool showLoadingIndicator = true, bool notifyOnNew = false}) async {
    await _refreshInvitesInternal(
      showLoadingIndicator: showLoadingIndicator,
      notifyOnNew: notifyOnNew,
    );
  }

  void startInvitePolling({Duration interval = const Duration(seconds: 75)}) {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return;
    _invitePollingTimer?.cancel();
    _invitePollingTimer = Timer.periodic(interval, (_) {
      if (_pollingInFlight) return;

      final until = _inviteBackoffUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        return;
      }

      _pollingInFlight = true;
      unawaited(
        _refreshInvitesInternal(showLoadingIndicator: false, notifyOnNew: true).whenComplete(() {
          _pollingInFlight = false;
        }),
      );
    });
  }

  void stopInvitePolling() {
    _invitePollingTimer?.cancel();
    _invitePollingTimer = null;
  }

  Future<void> _refreshInvitesInternal({required bool showLoadingIndicator, required bool notifyOnNew}) async {
    if (showLoadingIndicator) {
      _setLoading(true);
    }
    _error = null;

    try {
      final invites = await _api.listMyCollabInvites();

      // Successful response: clear any transient backoff.
      _inviteBackoffUntil = null;
      _inviteBackoff = Duration.zero;

      final newPendingInvites = invites
          .where((i) => i.isPending && i.id.trim().isNotEmpty && !_knownInviteIds.contains(i.id))
          .toList(growable: false);

      _invitesInbox
        ..clear()
        ..addAll(invites);
      notifyListeners();

      for (final invite in invites) {
        final id = invite.id.trim();
        if (id.isEmpty) continue;
        _knownInviteIds.add(id);
      }
      unawaited(_persistKnownInvites());

      if (notifyOnNew &&
          _readyToNotifyNewInvites &&
          _knownInvitesHydrated &&
          AppConfig.isFeatureEnabled('collabInviteNotifications') &&
          newPendingInvites.isNotEmpty) {
        await _emitInviteNotifications(newPendingInvites);
      }
    } catch (e) {
      if (e is BackendApiRequestException && e.statusCode == 503) {
        // Server temporarily unavailable: keep existing inbox and back off.
        final next = _inviteBackoff == Duration.zero
            ? const Duration(seconds: 60)
            : Duration(seconds: (_inviteBackoff.inSeconds * 2).clamp(60, 900));
        _inviteBackoff = next;
        _inviteBackoffUntil = DateTime.now().add(next);

        _error = 'Invites temporarily unavailable';
        notifyListeners();
        return;
      }

      _error = e.toString();
      notifyListeners();
    } finally {
      if (showLoadingIndicator) {
        _setLoading(false);
      }
    }
  }

  Future<void> _hydrateKnownInvitesOnce() async {
    if (_knownInvitesHydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('collab_known_invite_ids_v1') ?? const <String>[];
      for (final id in stored) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) continue;
        _knownInviteIds.add(trimmed);
      }
    } catch (_) {
      // Best-effort; if hydration fails we'll still function, but may notify more than desired.
    } finally {
      _knownInvitesHydrated = true;
    }
  }

  Future<void> _persistKnownInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _knownInviteIds.toList(growable: false);
      final capped = list.length > 200 ? list.sublist(list.length - 200) : list;
      await prefs.setStringList('collab_known_invite_ids_v1', capped);
    } catch (_) {
      // Ignore persistence errors.
    }
  }

  Future<void> _emitInviteNotifications(List<CollabInvite> newPendingInvites) async {
    // Ensure notification service is ready (no-op if already initialized).
    unawaited(_notifications.initialize());

    final limited = newPendingInvites.take(3);
    for (final invite in limited) {
      final invitedBy = invite.invitedBy;
      final inviterName = (invitedBy?.displayName ?? '').trim().isNotEmpty
          ? invitedBy!.displayName!.trim()
          : ((invitedBy?.username ?? '').trim().isNotEmpty ? '@${invitedBy!.username}' : null);

      await _notifications.showCollabInviteNotification(
        inviteId: invite.id,
        entityType: invite.entityType,
        entityId: invite.entityId,
        role: invite.role,
        inviterName: inviterName,
      );
    }
  }

  Future<List<CollabMember>> loadCollaborators(String entityType, String entityId, {bool refresh = true}) async {
    _setLoading(true);
    _error = null;
    try {
      final members = await _api.listCollaborators(entityType, entityId);
      _membersByEntityKey[_key(entityType, entityId)] = members;
      notifyListeners();
      return members;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<CollabInvite?> inviteCollaborator({
    required String entityType,
    required String entityId,
    required String invitedIdentifier,
    required String role,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final invite = await _api.inviteCollaborator(entityType, entityId, invitedIdentifier, role);
      // Best effort: refresh invites for invited user is not possible client-side; refresh ours anyway.
      await refreshInvites();
      return invite;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.acceptInvite(inviteId);
      await refreshInvites();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> declineInvite(String inviteId) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.declineInvite(inviteId);
      await refreshInvites();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCollaboratorRole({
    required String entityType,
    required String entityId,
    required String memberUserId,
    required String role,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.updateCollaboratorRole(entityType, entityId, memberUserId, role);
      await loadCollaborators(entityType, entityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeCollaborator({
    required String entityType,
    required String entityId,
    required String memberUserId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.removeCollaborator(entityType, entityId, memberUserId);
      await loadCollaborators(entityType, entityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool next) {
    if (_isLoading == next) return;
    _isLoading = next;
    notifyListeners();
  }

  @override
  void dispose() {
    stopInvitePolling();
    super.dispose();
  }
}
