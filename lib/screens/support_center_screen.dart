import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../providers/support_center_provider.dart';
import '../services/backend_api_service.dart';
import '../services/contextual_auth_gate.dart';
import '../utils/design_tokens.dart';
import '../widgets/inline_loading.dart';
import '../widgets/kubus_snackbar.dart';

/// Sections of the shared Help & support destination. Mobile settings, desktop
/// settings and the profile all open [SupportCenterScreen]; [initialSection]
/// selects the tab.
enum SupportSection { faq, contact, bug, requests }

/// Contract limits (Support Center backend contract, requester endpoints 1 and 4).
const int _maxSubjectLength = 255;
const int _maxMessageLength = 5000;

/// Requester-facing support hub: FAQ, contact and bug forms, and the signed-in
/// account's request history with replies. The request workflow itself lives
/// in [SupportCenterProvider]; this screen owns only form and presentation
/// state.
class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({
    super.key,
    this.initialSection = SupportSection.faq,
    this.resumeInterrupted = false,
    this.resumeTicketId,
  });

  final SupportSection initialSection;

  /// True when this screen was opened by the sign-in continuation. Only then
  /// may it restore a draft the gate interrupted; an ordinary open never does.
  final bool resumeInterrupted;

  /// The request whose reply was interrupted by sign-in, reopened on return.
  final String? resumeTicketId;

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  final _reply = TextEditingController();

  late SupportSection _section;
  bool _includePlatform = false;
  bool _submitting = false;
  String? _formError;
  String? _replyFormError;

  bool get _signedIn => BackendApiService().hasAuthSession;

  SupportCenterProvider get _support => context.read<SupportCenterProvider>();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    if (_section == SupportSection.requests) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _support.loadTickets();
      });
    }
    if (widget.resumeInterrupted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_resumeInterruptedDraft());
      });
    }
  }

  /// Restores a draft the sign-in gate interrupted, when this screen was opened
  /// by the continuation. Ordinary opens find nothing to restore.
  Future<void> _resumeInterruptedDraft() async {
    final support = _support;
    final draft = support.takeDraft(
      section: _section.name,
      ticketId: widget.resumeTicketId,
      currentUserId: await _currentUserId(),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _subject.text = draft.fields['subject'] ?? '';
      _message.text = draft.fields['message'] ?? '';
      _steps.text = draft.fields['steps'] ?? '';
      _expected.text = draft.fields['expected'] ?? '';
      _actual.text = draft.fields['actual'] ?? '';
      _reply.text = draft.fields['reply'] ?? '';
      _includePlatform = draft.includePlatform;
    });
    final ticketId = draft.ticketId;
    if (ticketId != null) {
      support.loadTickets();
      await support.openTicket(ticketId);
    }
  }

  /// The signed-in account, or null for a guest. Read the way the pending
  /// action provider reads it, so the two agree on ownership.
  Future<String?> _currentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = (prefs.getString('user_id') ?? '').trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// The raw contact or bug form text, kept so the restored form shows the
  /// same fields the visitor filled in (not the composed bug report).
  SupportDraft _contactDraft({required bool bug}) => SupportDraft(
        section: bug ? SupportSection.bug.name : SupportSection.contact.name,
        fields: <String, String>{
          'subject': _subject.text,
          'message': _message.text,
          if (bug) ...<String, String>{
            'steps': _steps.text,
            'expected': _expected.text,
            'actual': _actual.text,
          },
        },
        includePlatform: bug && _includePlatform,
      );

  @override
  void dispose() {
    for (final controller in [
      _subject,
      _message,
      _steps,
      _expected,
      _actual,
      _reply,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _go(SupportSection section) {
    setState(() {
      _section = section;
      _formError = null;
      _replyFormError = null;
    });
    final support = _support;
    support.closeTicket();
    if (section == SupportSection.requests) support.loadTickets();
  }

  /// Runs the existing protected-action flow for a visitor without a session.
  /// Returns true when the action may proceed now.
  ///
  /// A submit or reply passes [actionType] and [draft]. The draft is stashed
  /// before the gate can route away, because the sign-in redirect replaces this
  /// screen; the redirect reopens [SupportSection] with the same arguments and
  /// the continuation restores the draft there.
  Future<bool> _ensureSignedIn({
    PendingActionType? actionType,
    String? ticketId,
    SupportDraft? draft,
  }) async {
    // A Send can arrive before the stored session has loaded on a cold open;
    // the gate must not treat that visitor as a guest. The read is the same
    // bootstrap the rest of the app uses, and an unreadable session is a guest.
    try {
      await BackendApiService().ensureAuthLoaded();
    } catch (_) {
      // Fall through as a guest.
    }
    if (!mounted) return false;
    if (_signedIn) return true;
    final l10n = AppLocalizations.of(context)!;
    if (draft != null) _support.stashDraft(draft);
    final proceed = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.supportSignInActionLabel,
      actionType: actionType,
      targetType:
          actionType == null ? null : PendingActionTargetType.supportRequest,
      targetId: actionType == null ? null : (ticketId ?? 'new'),
      returnRoute: '/support',
      returnArguments: <String, String>{
        'section': _section.name,
        if (ticketId != null) 'ticketId': ticketId,
      },
      sourceScreen: 'support_center',
    );
    if (!mounted) return false;
    return proceed;
  }

  String _failureText(
    AppLocalizations l10n,
    SupportFailure failure,
    String generic,
  ) {
    return switch (failure) {
      SupportFailure.signIn => l10n.supportSignInRequired,
      SupportFailure.accountIdentity => l10n.supportErrorAccountIdentity,
      SupportFailure.notFound => l10n.supportErrorNotFound,
      SupportFailure.closed => l10n.supportErrorClosedReply,
      SupportFailure.invalid => l10n.supportErrorInvalid,
      SupportFailure.rateLimited => l10n.supportErrorRateLimited,
      SupportFailure.generic => generic,
    };
  }

  /// The sign-in card's action. The gate reports false even when the visitor
  /// completed the sign-in journey, so the history is refreshed whenever a
  /// session exists afterwards, not only when the gate returned true.
  Future<void> _signInThenRefresh() async {
    final support = _support;
    final tokenBefore = BackendApiService().getAuthToken();
    if (_signedIn && _sessionRefused(support)) {
      await _openSignIn(ticketId: support.openId);
      // Backing out of the sign-in route with the same refused session changes
      // nothing, so no request is repeated.
      if (BackendApiService().getAuthToken() == tokenBefore) return;
    } else {
      await _ensureSignedIn();
    }
    if (!mounted || !_signedIn) return;
    final id = support.openId;
    if (id != null) {
      await support.openTicket(id);
    } else {
      await support.loadTickets();
    }
  }

  /// True when the server refused the stored session (HTTP 401) for the
  /// history or the open request. The app still holds the token, so the
  /// protected-action gate would report a signed-in visitor and do nothing.
  bool _sessionRefused(SupportCenterProvider support) =>
      support.listFailure == SupportFailure.signIn ||
      support.ticketFailure == SupportFailure.signIn;

  /// Opens the sign-in route for a refused session, returning to this section
  /// (and the request, for a reply). The same route the other screens use for a
  /// 401; an interrupted draft is stashed first so it is restored on return.
  Future<void> _openSignIn({SupportDraft? draft, String? ticketId}) async {
    if (draft != null) _support.stashDraft(draft);
    await Navigator.of(context).pushNamed(
      '/sign-in',
      arguments: <String, Object?>{
        'redirectRoute': '/support',
        'redirectArguments': <String, String>{
          'section': _section.name,
          if (ticketId != null) 'ticketId': ticketId,
        },
      },
    );
  }

  /// Recovers from a 401 on a create or reply: a refused session goes to the
  /// sign-in route, a visitor without a session goes through the gate.
  Future<void> _recoverFromSignIn({
    PendingActionType? actionType,
    String? ticketId,
    required SupportDraft draft,
  }) async {
    if (!mounted) return;
    if (_signedIn) {
      await _openSignIn(draft: draft, ticketId: ticketId);
    } else {
      await _ensureSignedIn(
        actionType: actionType,
        ticketId: ticketId,
        draft: draft,
      );
    }
  }

  /// Keys for the form fields, so a failed submit can scroll to the first field
  /// that is still invalid. The Send button sits below a long bug report, so the
  /// summary at the top is not enough on its own.
  final _fieldKeys =
      <TextEditingController, GlobalKey<FormFieldState<String>>>{};

  GlobalKey<FormFieldState<String>> _fieldKey(TextEditingController c) =>
      _fieldKeys.putIfAbsent(c, () => GlobalKey<FormFieldState<String>>());

  void _revealFirstInvalidField({required bool bug}) {
    final controllers = <TextEditingController>[
      _subject,
      if (bug) ...<TextEditingController>[
        _message,
        _steps,
        _expected,
        _actual
      ] else
        _message,
    ];
    for (final controller in controllers) {
      final state = _fieldKey(controller).currentState;
      if (state == null || !state.hasError) continue;
      final context = _fieldKey(controller).currentContext;
      if (context == null) return;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.2,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
  }

  String _composeBugReport() {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    return [
      'Issue:\n${_message.text.trim()}',
      'Steps to reproduce:\n${_steps.text.trim()}',
      'Expected behavior:\n${_expected.text.trim()}',
      'Actual behavior:\n${_actual.text.trim()}',
      if (_includePlatform) 'Platform (consented): $platform',
    ].join('\n\n');
  }

  Future<void> _submitRequest() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final bug = _section == SupportSection.bug;

    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _formError = l10n.supportErrorInvalid);
      _revealFirstInvalidField(bug: bug);
      return;
    }
    final message = bug ? _composeBugReport() : _message.text.trim();
    if (message.length > _maxMessageLength) {
      setState(() => _formError = l10n.supportFormReportTooLong);
      return;
    }
    final actionType =
        bug ? PendingActionType.supportBug : PendingActionType.supportContact;
    if (!await _ensureSignedIn(
          actionType: actionType,
          draft: _contactDraft(bug: bug),
        ) ||
        !mounted) {
      return;
    }

    setState(() => _submitting = true);
    final failure = await _support.createTicket(
      subject: _subject.text.trim(),
      message: message,
      kind: bug ? 'bug' : 'support',
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure == null) {
      for (final controller in [
        _subject,
        _message,
        _steps,
        _expected,
        _actual
      ]) {
        controller.clear();
      }
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            bug ? l10n.supportBugSentToast : l10n.supportRequestSentToast,
          ),
        ),
      );
      _go(SupportSection.requests);
      return;
    }
    setState(() {
      _formError = _failureText(l10n, failure, l10n.supportErrorGeneric);
    });
    if (failure == SupportFailure.signIn) {
      await _recoverFromSignIn(
        actionType: actionType,
        draft: _contactDraft(bug: bug),
      );
    }
  }

  Future<void> _sendReply() async {
    final support = _support;
    final id = support.openId;
    if (support.replying || id == null || support.ticket == null) return;
    final l10n = AppLocalizations.of(context)!;
    final text = _reply.text.trim();
    if (text.isEmpty) {
      setState(() => _replyFormError = l10n.supportFormRequiredError);
      return;
    }
    if (text.length > _maxMessageLength) {
      setState(() => _replyFormError = l10n.supportFormMessageTooLong);
      return;
    }
    if (!await _ensureSignedIn(
          actionType: PendingActionType.supportReply,
          ticketId: id,
          draft: SupportDraft(
            section: SupportSection.requests.name,
            ticketId: id,
            fields: <String, String>{'reply': _reply.text},
          ),
        ) ||
        !mounted) {
      return;
    }

    setState(() => _replyFormError = null);
    final failure = await support.replyToTicket(id, text);
    if (!mounted) return;
    if (failure == null) _reply.clear();
    if (failure == SupportFailure.signIn) {
      await _recoverFromSignIn(
        actionType: PendingActionType.supportReply,
        ticketId: id,
        draft: SupportDraft(
          section: SupportSection.requests.name,
          ticketId: id,
          fields: <String, String>{'reply': _reply.text},
        ),
      );
    }
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    return '${parsed.day}.${parsed.month}.${parsed.year}';
  }

  String _statusLabel(AppLocalizations l10n, Object? status) {
    return switch (status?.toString()) {
      'pending' => l10n.supportStatusPending,
      'resolved' => l10n.supportStatusResolved,
      'closed' => l10n.supportStatusClosed,
      _ => l10n.supportStatusOpen,
    };
  }

  String _kindLabel(AppLocalizations l10n, Object? kind) {
    return kind == 'bug'
        ? l10n.supportRequestKindBug
        : l10n.supportRequestKindSupport;
  }

  String? _validateText(
    String? value,
    AppLocalizations l10n, {
    required int max,
    required String tooLong,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return l10n.supportFormRequiredError;
    if (text.length > max) return tooLong;
    return null;
  }

  /// A flat surface. Material (not a DecoratedBox) so ListTile and
  /// ExpansionTile can paint their ink on it.
  Widget _panel({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: child,
      ),
    );
  }

  Widget _heading(String text, {bool large = true}) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: large ? theme.textTheme.titleLarge : theme.textTheme.titleMedium,
      ),
    );
  }

  Widget _errorText(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.error,
              ),
        ),
      ),
    );
  }

  Widget _unavailableNotice(AppLocalizations l10n) {
    return _panel(child: Text(l10n.supportUnavailable));
  }

  Widget _signInCard(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(l10n.supportSignInTitle, large: false),
        const SizedBox(height: KubusSpacing.sm),
        Text(l10n.supportSignInBody),
        const SizedBox(height: KubusSpacing.md),
        FilledButton(
          onPressed: _signInThenRefresh,
          child: Text(l10n.supportSignInAction),
        ),
      ],
    );
  }

  Widget _faq(AppLocalizations l10n) {
    final entries = <(String, String)>[
      (l10n.supportFaqQuestion1, l10n.supportFaqAnswer1),
      (l10n.supportFaqQuestion2, l10n.supportFaqAnswer2),
      (l10n.supportFaqQuestion3, l10n.supportFaqAnswer3),
      (l10n.supportFaqQuestion4, l10n.supportFaqAnswer4),
      (l10n.supportFaqQuestion5, l10n.supportFaqAnswer5),
    ];
    return _panel(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            ExpansionTile(
              key: ValueKey<String>('support_faq_$i'),
              tilePadding: EdgeInsets.zero,
              title: Text(entries[i].$1),
              childrenPadding: const EdgeInsets.only(bottom: KubusSpacing.md),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(entries[i].$2)],
            ),
            if (i != entries.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _requestForm(AppLocalizations l10n, {required bool bug}) {
    return _panel(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              bug
                  ? l10n.supportCenterSectionBug
                  : l10n.supportCenterSectionContact,
            ),
            const SizedBox(height: KubusSpacing.md),
            if (_formError != null) _errorText(_formError!),
            _formField(
              _subject,
              label: l10n.supportFormSubjectLabel,
              maxLength: _maxSubjectLength,
              validator: (value) => _validateText(
                value,
                l10n,
                max: _maxSubjectLength,
                tooLong: l10n.supportFormSubjectTooLong,
              ),
            ),
            if (bug) ...[
              _formField(
                _message,
                label: l10n.supportBugWhatHappenedLabel,
                maxLines: 4,
                validator: (value) => _validateText(
                  value,
                  l10n,
                  max: _maxMessageLength,
                  tooLong: l10n.supportFormMessageTooLong,
                ),
              ),
              _formField(
                _steps,
                label: l10n.supportBugStepsLabel,
                maxLines: 3,
                validator: (value) => _validateText(
                  value,
                  l10n,
                  max: _maxMessageLength,
                  tooLong: l10n.supportFormMessageTooLong,
                ),
              ),
              _formField(
                _expected,
                label: l10n.supportBugExpectedLabel,
                maxLines: 2,
                validator: (value) => _validateText(
                  value,
                  l10n,
                  max: _maxMessageLength,
                  tooLong: l10n.supportFormMessageTooLong,
                ),
              ),
              _formField(
                _actual,
                label: l10n.supportBugActualLabel,
                maxLines: 2,
                validator: (value) => _validateText(
                  value,
                  l10n,
                  max: _maxMessageLength,
                  tooLong: l10n.supportFormMessageTooLong,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includePlatform,
                onChanged: _submitting
                    ? null
                    : (value) =>
                        setState(() => _includePlatform = value ?? false),
                title: Text(l10n.supportBugPlatformLabel),
                subtitle: Text(l10n.supportBugPlatformHint),
              ),
            ] else
              _formField(
                _message,
                label: l10n.supportFormMessageLabel,
                maxLines: 5,
                validator: (value) => _validateText(
                  value,
                  l10n,
                  max: _maxMessageLength,
                  tooLong: l10n.supportFormMessageTooLong,
                ),
              ),
            const SizedBox(height: KubusSpacing.sm),
            FilledButton.icon(
              onPressed: _submitting ? null : _submitRequest,
              icon: const Icon(Icons.send_outlined),
              label: Text(
                _submitting
                    ? l10n.supportFormSending
                    : (bug
                        ? l10n.supportFormSubmitBug
                        : l10n.supportFormSubmitContact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formField(
    TextEditingController controller, {
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
    int maxLength = _maxMessageLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: KubusSpacing.sm),
      child: TextFormField(
        key: _fieldKey(controller),
        controller: controller,
        enabled: !_submitting,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator,
      ),
    );
  }

  Widget _requestsList(AppLocalizations l10n, SupportCenterProvider support) {
    final tickets = support.tickets;
    final listFailure = support.listFailure;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _heading(l10n.supportCenterSectionRequests)),
              IconButton(
                onPressed: support.listLoading ? null : support.loadTickets,
                tooltip: l10n.supportRequestsRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (support.listLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
              child: Center(child: InlineLoading(width: 40, height: 40)),
            ),
          if (listFailure == SupportFailure.signIn)
            _signInCard(l10n)
          else if (listFailure != null)
            _failureWithRetry(
              _failureText(l10n, listFailure, l10n.supportErrorLoadRequests),
              listFailure,
              support.loadTickets,
              l10n,
            ),
          if (!support.listLoading &&
              listFailure == null &&
              tickets != null &&
              tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KubusSpacing.md),
              child: Text(l10n.supportRequestsEmpty),
            ),
          if (listFailure == null && tickets != null)
            for (final item in tickets) ...[
              const Divider(height: 1),
              _requestTile(item, l10n, support),
            ],
        ],
      ),
    );
  }

  Widget _requestTile(
    Map<String, dynamic> item,
    AppLocalizations l10n,
    SupportCenterProvider support,
  ) {
    final isBug = item['kind'] == 'bug';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isBug ? Icons.bug_report_outlined : Icons.support_agent_outlined,
      ),
      title: Text(item['subject']?.toString() ?? ''),
      subtitle: Text(
        '${_kindLabel(l10n, item['kind'])} · '
        '${_statusLabel(l10n, item['status'])} · '
        '${l10n.supportRequestUpdatedOn(_date(item['updated_at']))}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => support.openTicket(item['id'].toString()),
    );
  }

  Widget _failureWithRetry(
    String text,
    SupportFailure failure,
    VoidCallback retry,
    AppLocalizations l10n,
  ) {
    final retryable = failure == SupportFailure.generic ||
        failure == SupportFailure.rateLimited;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _errorText(text),
          if (retryable)
            OutlinedButton(onPressed: retry, child: Text(l10n.supportRetry)),
        ],
      ),
    );
  }

  Widget _backToList(AppLocalizations l10n, SupportCenterProvider support) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        tooltip: l10n.supportRequestsBack,
        onPressed: () {
          setState(() => _replyFormError = null);
          support.closeTicket();
        },
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _messageView(Map<dynamic, dynamic> raw, AppLocalizations l10n) {
    final fromSupport = raw['sender_type'] == 'admin';
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fromSupport ? l10n.supportSenderSupport : l10n.supportSenderYou}'
            ' · ${_date(raw['created_at'])}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: KubusSpacing.xxs),
          // User text is plain text: no markdown or HTML interpretation.
          Text(raw['message']?.toString() ?? ''),
        ],
      ),
    );
  }

  /// The reply error to show: a local validation message, else the server's
  /// failure for the last reply.
  String? _replyErrorText(
    AppLocalizations l10n,
    SupportCenterProvider support,
  ) {
    if (_replyFormError != null) return _replyFormError;
    final failure = support.replyFailure;
    if (failure == null) return null;
    return _failureText(l10n, failure, l10n.supportErrorGeneric);
  }

  Widget _requestDetail(AppLocalizations l10n, SupportCenterProvider support) {
    final ticket = support.ticket;
    final ticketFailure = support.ticketFailure;
    if (ticket == null) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _backToList(l10n, support),
            if (ticketFailure == SupportFailure.signIn)
              _signInCard(l10n)
            else if (ticketFailure != null)
              _failureWithRetry(
                _failureText(l10n, ticketFailure, l10n.supportErrorLoadRequest),
                ticketFailure,
                () => support.openTicket(support.openId!),
                l10n,
              )
            else if (support.ticketLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
                child: Center(child: InlineLoading(width: 40, height: 40)),
              ),
          ],
        ),
      );
    }

    final closed = ticket['status'] == 'closed';
    final rawMessages = ticket['messages'];
    final messages = rawMessages is List ? rawMessages : const <dynamic>[];
    final scheme = Theme.of(context).colorScheme;
    final replyError = _replyErrorText(l10n, support);
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backToList(l10n, support),
          _heading(ticket['subject']?.toString() ?? ''),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            '${_kindLabel(l10n, ticket['kind'])} · '
            '${_statusLabel(l10n, ticket['status'])}',
          ),
          Text(
            l10n.supportRequestOpenedOn(_date(ticket['created_at'])),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
          ),
          const Divider(height: KubusSpacing.xl),
          for (final raw in messages)
            if (raw is Map) _messageView(raw, l10n),
          if (support.ticketLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Center(child: InlineLoading(width: 40, height: 40)),
            ),
          if (ticketFailure != null)
            _errorText(
              _failureText(l10n, ticketFailure, l10n.supportErrorLoadRequest),
            ),
          const Divider(height: KubusSpacing.xl),
          if (replyError != null) _errorText(replyError),
          if (closed) _closedNotice(l10n) else _replyComposer(l10n, support),
        ],
      ),
    );
  }

  Widget _closedNotice(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(l10n.supportClosedTitle, large: false),
        const SizedBox(height: KubusSpacing.xs),
        Text(l10n.supportClosedHint),
        const SizedBox(height: KubusSpacing.md),
        OutlinedButton(
          onPressed: () => _go(SupportSection.contact),
          child: Text(l10n.supportClosedNewRequest),
        ),
      ],
    );
  }

  Widget _replyComposer(AppLocalizations l10n, SupportCenterProvider support) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reply,
          enabled: !support.replying,
          minLines: 3,
          maxLines: 6,
          maxLength: _maxMessageLength,
          decoration: InputDecoration(labelText: l10n.supportReplyLabel),
        ),
        const SizedBox(height: KubusSpacing.sm),
        FilledButton.icon(
          onPressed: support.replying ? null : _sendReply,
          icon: const Icon(Icons.send_outlined),
          label: Text(
            support.replying ? l10n.supportFormSending : l10n.supportReplySend,
          ),
        ),
      ],
    );
  }

  Widget _requests(AppLocalizations l10n, SupportCenterProvider support) {
    if (support.openId != null) return _requestDetail(l10n, support);
    return _requestsList(l10n, support);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final support = context.watch<SupportCenterProvider>();
    final sectionLabels = <SupportSection, String>{
      SupportSection.faq: l10n.supportCenterSectionFaq,
      SupportSection.contact: l10n.supportCenterSectionContact,
      SupportSection.bug: l10n.supportCenterSectionBug,
      SupportSection.requests: l10n.supportCenterSectionRequests,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportCenterTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(KubusSpacing.md),
              children: [
                // The four sections switch the panel below, so they are tabs
                // (not checkboxes): one selected tab at a time.
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  role: SemanticsRole.tabBar,
                  label: l10n.supportCenterSectionsLabel,
                  child: Wrap(
                    spacing: KubusSpacing.sm,
                    runSpacing: KubusSpacing.sm,
                    children: [
                      for (final section in SupportSection.values)
                        Semantics(
                          role: SemanticsRole.tab,
                          selected: _section == section,
                          label: sectionLabels[section],
                          onTap: () => _go(section),
                          // The chip's own checkbox-style node is replaced by
                          // this tab, so each section is announced once.
                          excludeSemantics: true,
                          child: ChoiceChip(
                            selected: _section == section,
                            label: Text(sectionLabels[section]!),
                            onSelected: (_) => _go(section),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                // With the feature off only the FAQ answers; the request
                // history makes no ticket calls at all.
                switch (_section) {
                  SupportSection.faq => _faq(l10n),
                  SupportSection.contact ||
                  SupportSection.bug =>
                    support.supportEnabled
                        ? _requestForm(
                            l10n,
                            bug: _section == SupportSection.bug,
                          )
                        : _unavailableNotice(l10n),
                  SupportSection.requests => support.supportEnabled
                      ? _requests(l10n, support)
                      : _unavailableNotice(l10n),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
