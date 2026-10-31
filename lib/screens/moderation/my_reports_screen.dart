import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/content_report_service.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/kubus_snackbar.dart';

String _statusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'triaged':
      return l10n.moderationStatusTriaged;
    case 'resolved':
      return l10n.moderationStatusResolved;
    case 'closed':
      return l10n.moderationStatusClosed;
    default:
      return l10n.moderationStatusOpen;
  }
}

String _outcomeLabel(AppLocalizations l10n, String outcome) {
  switch (outcome) {
    case 'no_action':
      return l10n.moderationOutcomeNoAction;
    case 'content_removed':
      return l10n.moderationOutcomeContentRemoved;
    case 'content_restricted':
      return l10n.moderationOutcomeContentRestricted;
    case 'account_action':
      return l10n.moderationOutcomeAccountAction;
    case 'referred':
      return l10n.moderationOutcomeReferred;
    default:
      return l10n.moderationOutcomeOther;
  }
}

/// The signed-in person's own side of moderation: the reports they filed (with
/// the decision and its reasons, and one request for a second look) and the
/// decisions that affect their own content (with the statement of reasons and
/// one appeal). Nothing here names who reported what.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, this.service});

  final ContentReportService? service;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final ContentReportService _service =
      widget.service ?? ContentReportService();
  bool _loading = true;
  ModerationActionOutcome? _error;
  ModerationOverview _overview = const ModerationOverview();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      final overview = result.overview;
      if (overview != null) {
        _overview = overview;
      } else {
        _error = result.outcome;
      }
    });
  }

  /// Asks for the explanation, then sends it. The appeal needs one; a second
  /// look does not.
  Future<void> _askAndSend({
    required String title,
    required bool noteRequired,
    required Future<ModerationActionOutcome> Function(String note) send,
  }) async {
    final note = await showKubusDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(title: title, required: noteRequired),
    );
    if (note == null || !mounted) return;
    final outcome = await send(note);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final text = switch (outcome) {
      ModerationActionOutcome.done => l10n.moderationActionSent,
      ModerationActionOutcome.alreadyDone => l10n.moderationActionAlreadySent,
      ModerationActionOutcome.notAvailable => l10n.moderationActionUnavailable,
      ModerationActionOutcome.signInRequired => l10n.moderationSignInRequired,
      _ => l10n.commonActionFailedToast,
    };
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
    if (outcome == ModerationActionOutcome.done ||
        outcome == ModerationActionOutcome.alreadyDone) {
      await _load();
    }
  }

  Widget _reasons(AppLocalizations l10n, String? text) {
    if ((text ?? '').trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: KubusSpacing.xs),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '${l10n.moderationReasonsLabel}: ',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: text!.trim()),
      ])),
    );
  }

  Widget _reportTile(AppLocalizations l10n, ReporterReport report) {
    final outcome = report.outcome;
    return Card(
      key: ValueKey<String>('my-report-${report.id}'),
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outcome == null
                  ? _statusLabel(l10n, report.status)
                  : '${_statusLabel(l10n, report.status)} · ${_outcomeLabel(l10n, outcome)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _reasons(l10n, report.outcomeReason),
            if (report.reconsiderationRequested)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xs),
                child: Text(l10n.moderationReconsiderationRequested),
              )
            else if (report.canRequestReconsideration)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: ValueKey<String>('reconsider-${report.id}'),
                  onPressed: () => _askAndSend(
                    title: l10n.moderationRequestReconsideration,
                    noteRequired: false,
                    send: (note) =>
                        _service.requestReconsideration(report.id, note: note),
                  ),
                  child: Text(l10n.moderationRequestReconsideration),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _decisionTile(AppLocalizations l10n, DecisionAboutMe decision) {
    final result = decision.appealResult;
    return Card(
      key: ValueKey<String>('decision-${decision.id}'),
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_outcomeLabel(l10n, decision.outcome),
                style: Theme.of(context).textTheme.titleSmall),
            _reasons(l10n, decision.statementOfReasons),
            if (result != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xs),
                child: Text(result == 'reversed'
                    ? l10n.moderationAppealReversed
                    : l10n.moderationAppealUpheld),
              ),
              _reasons(l10n, decision.appealResultReason),
            ] else if (decision.appealRequested)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xs),
                child: Text(l10n.moderationAppealSent),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: ValueKey<String>('appeal-${decision.id}'),
                  onPressed: () => _askAndSend(
                    title: l10n.moderationAppeal,
                    noteRequired: true,
                    send: (note) => _service.appeal(decision.id, note: note),
                  ),
                  child: Text(l10n.moderationAppeal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: InlineLoading());
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error == ModerationActionOutcome.signInRequired
                    ? l10n.moderationSignInRequired
                    : l10n.moderationLoadFailed,
                textAlign: TextAlign.center,
              ),
              if (error != ModerationActionOutcome.signInRequired)
                TextButton(
                  onPressed: _load,
                  child: Text(l10n.commonRetry),
                ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(KubusSpacing.md),
      children: [
        Semantics(
          header: true,
          child: Text(l10n.moderationDecisionsHeading,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: KubusSpacing.sm),
        if (_overview.decisions.isEmpty)
          Text(l10n.moderationNoDecisions)
        else
          for (final decision in _overview.decisions)
            _decisionTile(l10n, decision),
        const SizedBox(height: KubusSpacing.lg),
        Semantics(
          header: true,
          child: Text(l10n.moderationReportsHeading,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: KubusSpacing.sm),
        if (_overview.reports.isEmpty)
          Text(l10n.moderationNoReports)
        else
          for (final report in _overview.reports) _reportTile(l10n, report),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationScreenTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _body(l10n),
          ),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.required});

  final String title;
  final bool required;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final empty = _note.text.trim().isEmpty;
    return KubusAlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey<String>('moderation-note'),
        controller: _note,
        minLines: 3,
        maxLines: 6,
        maxLength: 2000,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: l10n.moderationNoteHint,
          helperText: widget.required ? l10n.moderationNoteRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('moderation-note-send'),
          onPressed: widget.required && empty
              ? null
              : () => Navigator.pop(context, _note.text.trim()),
          child: Text(l10n.commonSend),
        ),
      ],
    );
  }
}
