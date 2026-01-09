import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../services/backend_api_service.dart';

class SupportTicketDialog extends StatefulWidget {
  final String? initialEmail;
  final String? initialSubject;
  final String? initialMessage;

  const SupportTicketDialog({
    super.key,
    this.initialEmail,
    this.initialSubject,
    this.initialMessage,
  });

  @override
  State<SupportTicketDialog> createState() => _SupportTicketDialogState();
}

class _SupportTicketDialogState extends State<SupportTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _subjectController = TextEditingController(text: widget.initialSubject ?? '');
    _messageController = TextEditingController(text: widget.initialMessage ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await BackendApiService().createSupportTicket(
        email: _emailController.text,
        subject: _subjectController.text,
        message: _messageController.text,
      );

      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonSavedToast)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(
        l10n.settingsAboutSupportTileTitle,
        style: GoogleFonts.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.commonEmail,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: l10n.commonTitle,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return l10n.commonRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: l10n.commonDescription,
                  ),
                  maxLines: 6,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return l10n.commonRequired;
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            l10n.commonCancel,
            style: GoogleFonts.inter(color: scheme.outline),
          ),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? Text(l10n.commonWorking)
              : Text(l10n.commonSend),
        ),
      ],
    );
  }
}
