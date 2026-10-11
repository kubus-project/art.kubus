import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../services/backend_api_service.dart';

/// Failure categories for Support Center requests, mapped from the backend
/// contract's status codes so every entry point shows the same copy.
enum SupportFailure {
  signIn,
  accountIdentity,
  notFound,
  closed,
  invalid,
  rateLimited,
  generic,
}

SupportFailure classifySupportFailure(Object error) {
  if (error is BackendApiRequestException) {
    switch (error.statusCode) {
      case 400:
        return SupportFailure.invalid;
      case 401:
        return SupportFailure.signIn;
      case 403:
        return SupportFailure.accountIdentity;
      case 404:
        return SupportFailure.notFound;
      case 409:
        return SupportFailure.closed;
      case 429:
        return SupportFailure.rateLimited;
    }
  }
  return SupportFailure.generic;
}

/// A Support request or reply that the sign-in gate interrupted.
///
/// Held in memory only, so the visitor's text never reaches storage (the same
/// rule the pending-action intents follow). The sign-in redirect replaces the
/// Support screen, which is why the draft lives here rather than in the screen.
@immutable
class SupportDraft {
  const SupportDraft({
    required this.section,
    required this.fields,
    this.ticketId,
    this.includePlatform = false,
  });

  /// [SupportSection] name the draft belongs to: contact, bug or requests.
  final String section;

  /// Raw field text by name: subject, message, steps, expected, actual, reply.
  final Map<String, String> fields;

  /// The request a reply belongs to; null for a new request.
  final String? ticketId;

  final bool includePlatform;
}

/// Requester-side Support Center workflow: the signed-in account's request
/// history, one request's conversation, and the create and reply actions.
///
/// Screens own form and presentation state only. Every remote call goes
/// through [BackendApiService]; failures are kept as [SupportFailure] so each
/// entry point maps them to the same copy.
///
/// Replies and detail loads are only applied while they still belong to the
/// open request: a slower response for a request the visitor has left never
/// replaces the one on screen.
class SupportCenterProvider extends ChangeNotifier {
  SupportCenterProvider({bool? supportEnabled})
      : _supportEnabled =
            supportEnabled ?? AppConfig.isFeatureEnabled('supportTickets');

  final bool _supportEnabled;

  List<Map<String, dynamic>>? _tickets;
  bool _listLoading = false;
  SupportFailure? _listFailure;

  String? _openId;
  Map<String, dynamic>? _ticket;
  bool _ticketLoading = false;
  SupportFailure? _ticketFailure;

  /// Incremented by every detail load and by [closeTicket]. A response is
  /// applied only when its token is still the latest one.
  int _detailToken = 0;

  bool _replying = false;
  SupportFailure? _replyFailure;

  /// Whether the Support Center is switched on for this build.
  bool get supportEnabled => _supportEnabled;

  bool get signedIn => BackendApiService().hasAuthSession;

  List<Map<String, dynamic>>? get tickets => _tickets;
  bool get listLoading => _listLoading;
  SupportFailure? get listFailure => _listFailure;

  String? get openId => _openId;
  Map<String, dynamic>? get ticket => _ticket;
  bool get ticketLoading => _ticketLoading;
  SupportFailure? get ticketFailure => _ticketFailure;

  bool get replying => _replying;
  SupportFailure? get replyFailure => _replyFailure;

  /// The interrupted draft, with the account that wrote it (null for a guest).
  ({SupportDraft draft, String? ownerUserId})? _stash;

  /// Holds [draft] until the sign-in continuation restores it. Overwrites any
  /// earlier stash: only the most recent interrupted action is continuable.
  void stashDraft(SupportDraft draft, {String? ownerUserId}) {
    _stash = (draft: draft, ownerUserId: ownerUserId);
  }

  /// Returns and clears the stashed draft when it belongs to [section] and
  /// [ticketId] and was written by [currentUserId] or by a guest. A draft that
  /// belongs to another account is dropped; one for another screen stays put.
  SupportDraft? takeDraft({
    required String section,
    String? ticketId,
    String? currentUserId,
  }) {
    final stash = _stash;
    if (stash == null) return null;
    final owner = stash.ownerUserId;
    if (owner != null && owner != (currentUserId ?? '').trim()) {
      _stash = null;
      return null;
    }
    final draft = stash.draft;
    if (draft.section != section || draft.ticketId != ticketId) return null;
    _stash = null;
    return draft;
  }

  /// Drops any interrupted draft, e.g. when the visitor cancels the continuation.
  void clearDraft() {
    _stash = null;
  }

  /// The signed-in account's requests, newest update first. Does nothing
  /// while the feature is off, so a disabled build sends no ticket traffic.
  Future<void> loadTickets() async {
    if (!_supportEnabled || _listLoading) return;
    _listLoading = true;
    _listFailure = null;
    notifyListeners();
    try {
      // A cold open can reach here before the stored session is read; the
      // session must be known before deciding guest or signed in.
      await BackendApiService().ensureAuthLoaded();
      if (!signedIn) {
        _tickets = null;
        _listFailure = SupportFailure.signIn;
        return;
      }
      _tickets = await BackendApiService().getMySupportTickets();
    } catch (error) {
      _listFailure = classifySupportFailure(error);
    } finally {
      _listLoading = false;
      notifyListeners();
    }
  }

  /// Loads one request with its conversation. A response that arrives after
  /// the visitor has opened a different request, or left the detail, is
  /// dropped.
  Future<void> openTicket(String id) async {
    if (!_supportEnabled) return;
    final token = ++_detailToken;
    _openId = id;
    // Never show the previous request's conversation under a new id.
    if (_ticket?['id']?.toString() != id) _ticket = null;
    _ticketLoading = true;
    _ticketFailure = null;
    notifyListeners();
    try {
      final ticket = await BackendApiService().getMySupportTicket(id);
      if (token != _detailToken) return;
      _ticket = ticket;
    } catch (error) {
      if (token != _detailToken) return;
      final failure = classifySupportFailure(error);
      // The detail endpoint answers 400 only for a malformed id: report it as
      // a missing request, not as a form problem.
      _ticketFailure =
          failure == SupportFailure.invalid ? SupportFailure.notFound : failure;
    } finally {
      if (token == _detailToken) {
        _ticketLoading = false;
        notifyListeners();
      }
    }
  }

  /// Leaves the open request. Any load or reply still in flight for it is
  /// ignored when it returns.
  void closeTicket() {
    _detailToken++;
    _openId = null;
    _ticket = null;
    _ticketLoading = false;
    _ticketFailure = null;
    _replyFailure = null;
    notifyListeners();
  }

  /// Creates a support or bug request. Returns null when the server stored
  /// it, otherwise the failure to show. Never retried: the contract has no
  /// idempotency key, so a resend could open a duplicate request.
  Future<SupportFailure?> createTicket({
    required String subject,
    required String message,
    required String kind,
  }) async {
    try {
      await BackendApiService().createSupportTicket(
        subject: subject,
        message: message,
        kind: kind,
      );
      return null;
    } catch (error) {
      return classifySupportFailure(error);
    }
  }

  /// Adds a reply to request [id]. Returns null when the server stored it.
  ///
  /// The reply is sent once and never retried. On success, or on a 409 that
  /// means the request closed meanwhile, the request is reloaded so the screen
  /// shows what the server holds.
  Future<SupportFailure?> replyToTicket(String id, String text) async {
    // A second send while one is in flight must not reach the server.
    if (_replying) return SupportFailure.generic;
    _replying = true;
    _replyFailure = null;
    notifyListeners();

    SupportFailure? failure;
    try {
      await BackendApiService().replyToSupportTicket(id, text);
    } catch (error) {
      failure = classifySupportFailure(error);
    }

    _replying = false;
    _replyFailure = failure;
    final stillOpen = _openId == id;
    if (stillOpen && (failure == null || failure == SupportFailure.closed)) {
      // Reloads and notifies. The reply error stays until the next action.
      await openTicket(id);
      return failure;
    }
    notifyListeners();
    return failure;
  }
}
