import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../services/content_report_service.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';

/// Localized label for a report category.
String reportCategoryLabel(AppLocalizations l10n, ReportCategory category) {
  switch (category) {
    case ReportCategory.illegalContent:
      return l10n.reportCategoryIllegalContent;
    case ReportCategory.copyright:
      return l10n.reportCategoryCopyright;
    case ReportCategory.privacy:
      return l10n.reportCategoryPrivacy;
    case ReportCategory.harassment:
      return l10n.reportCategoryHarassment;
    case ReportCategory.spam:
      return l10n.reportCategorySpam;
    case ReportCategory.impersonation:
      return l10n.reportCategoryImpersonation;
    case ReportCategory.safety:
      return l10n.reportCategorySafety;
    case ReportCategory.other:
      return l10n.reportCategoryOther;
  }
}

/// Asks what is wrong with a post or an account and returns the completed
/// report, or null when the person cancels. Notice-type categories (illegal
/// content, copyright) require an explanation and an explicit good-faith
/// statement; the dialog does not enable "Send" until they are given.
Future<ContentReportDraft?> showReportContentDialog(
  BuildContext context, {
  String? subject,
}) {
  return showKubusDialog<ContentReportDraft>(
    context: context,
    builder: (_) => _ReportContentDialog(subject: subject),
  );
}

class _ReportContentDialog extends StatefulWidget {
  const _ReportContentDialog({this.subject});

  final String? subject;

  @override
  State<_ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<_ReportContentDialog> {
  ReportCategory? _category;
  bool _goodFaith = false;
  final TextEditingController _details = TextEditingController();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    _email.dispose();
    super.dispose();
  }

  ContentReportDraft? get _draft {
    final category = _category;
    if (category == null) return null;
    final details = _details.text.trim();
    final email = _email.text.trim();
    final draft = ContentReportDraft(
      category: category,
      details: details.isEmpty ? null : details,
      goodFaithStatement: category.needsGoodFaithStatement && _goodFaith,
      contactEmail: email.isEmpty ? null : email,
    );
    return draft.isComplete ? draft : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final category = _category;
    final needsStatement = category?.needsGoodFaithStatement ?? false;
    final email = _email.text.trim();
    final emailInvalid =
        email.isNotEmpty && !ContentReportDraft.isValidEmail(email);
    final draft = _draft;

    return KubusAlertDialog(
      scrollable: true,
      title: Text(l10n.reportContentTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((widget.subject ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Text(widget.subject!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          Semantics(
            container: true,
            label: l10n.reportContentCategoryLabel,
            child: Text(l10n.reportContentCategoryLabel,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioGroup<ReportCategory>(
            groupValue: category,
            onChanged: (value) => setState(() => _category = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in ReportCategory.values)
                  RadioListTile<ReportCategory>(
                    key: ValueKey<String>('report-category-${option.wire}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: option,
                    title: Text(reportCategoryLabel(l10n, option)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          TextField(
            key: const ValueKey<String>('report-details'),
            controller: _details,
            minLines: 2,
            maxLines: 5,
            maxLength: 5000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.reportContentDetailsLabel,
              helperText:
                  needsStatement ? l10n.reportContentDetailsRequired : null,
              helperMaxLines: 3,
            ),
          ),
          if (needsStatement)
            CheckboxListTile(
              key: const ValueKey<String>('report-good-faith'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _goodFaith,
              onChanged: (value) => setState(() => _goodFaith = value ?? false),
              title: Text(l10n.reportContentGoodFaith),
            ),
          const SizedBox(height: KubusSpacing.sm),
          TextField(
            key: const ValueKey<String>('report-contact-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.reportContentContactLabel,
              errorText: emailInvalid ? l10n.reportContentContactInvalid : null,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(l10n.reportContentAccountNote,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('report-submit'),
          onPressed: draft == null ? null : () => Navigator.pop(context, draft),
          child: Text(l10n.reportContentSubmit),
        ),
      ],
    );
  }
}
