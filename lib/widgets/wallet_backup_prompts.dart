import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Future<String?> showWalletBackupPasswordPrompt({
  required BuildContext context,
  required String title,
  required String description,
  bool confirm = false,
  String? actionLabel,
}) {
  final firstController = TextEditingController();
  final secondController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final scheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                description,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: firstController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText:
                      confirm ? 'Recovery password' : l10n.commonPassword,
                ),
                validator: (value) {
                  final password = (value ?? '').trim();
                  if (password.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  return null;
                },
              ),
              if (confirm) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  controller: secondController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.commonConfirmPassword,
                  ),
                  validator: (value) {
                    if ((value ?? '') != firstController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(dialogContext).pop(firstController.text.trim());
            },
            child: Text(actionLabel ?? l10n.commonContinue),
          ),
        ],
      );
    },
  );
}

Future<String?> showWalletBackupTextPrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String description,
  String? initialValue,
  String? actionLabel,
}) {
  final controller = TextEditingController(text: initialValue ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final scheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                description,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: label),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) {
                    return '$label is required.';
                  }
                  if (trimmed.length > 120) {
                    return '$label must be 120 characters or less.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: Text(actionLabel ?? l10n.commonSave),
          ),
        ],
      );
    },
  );
}
