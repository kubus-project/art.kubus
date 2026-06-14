import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

enum WalletRecoveryFallbackChoice {
  recoveryPassword,
  recoveryPhrase,
  readOnly,
}

Future<String?> showWalletBackupPasswordPrompt({
  required BuildContext context,
  required String title,
  required String description,
  bool confirm = false,
  String? actionLabel,
}) async {
  final firstController = TextEditingController();
  final secondController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  try {
    return await showKubusDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;

        return KubusAlertDialog(
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
                const SizedBox(height: KubusSpacing.md),
                TextFormField(
                  controller: firstController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: confirm
                        ? l10n.walletBackupRecoveryPasswordLabel
                        : l10n.commonPassword,
                  ),
                  validator: (value) {
                    final password = (value ?? '').trim();
                    if (password.length < 8) {
                      return l10n.walletBackupPasswordTooShortError;
                    }
                    return null;
                  },
                ),
                if (confirm) ...<Widget>[
                  const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
                  TextFormField(
                    controller: secondController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.commonConfirmPassword,
                    ),
                    validator: (value) {
                      if ((value ?? '') != firstController.text) {
                        return l10n.walletBackupPasswordsMismatchError;
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
  } finally {
    firstController.dispose();
    secondController.dispose();
  }
}

Future<WalletRecoveryFallbackChoice?> showWalletRecoveryFallbackChoicePrompt({
  required BuildContext context,
  required String title,
  required String description,
  bool showRecoveryPassword = true,
  bool showRecoveryPhrase = true,
  bool showReadOnly = true,
}) {
  return showKubusDialog<WalletRecoveryFallbackChoice>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      final scheme = Theme.of(dialogContext).colorScheme;

      Widget choiceButton({
        required Widget child,
        required VoidCallback onPressed,
        required bool primary,
      }) {
        final button = primary
            ? FilledButton(onPressed: onPressed, child: child)
            : OutlinedButton(onPressed: onPressed, child: child);
        return SizedBox(width: double.infinity, child: button);
      }

      final choices = <Widget>[
        if (showRecoveryPassword)
          choiceButton(
            primary: true,
            onPressed: () => Navigator.of(dialogContext)
                .pop(WalletRecoveryFallbackChoice.recoveryPassword),
            child: Text(l10n.walletRecoveryUsePasswordAction),
          ),
        if (showRecoveryPhrase)
          choiceButton(
            primary: !showRecoveryPassword,
            onPressed: () => Navigator.of(dialogContext)
                .pop(WalletRecoveryFallbackChoice.recoveryPhrase),
            child: Text(l10n.walletRecoveryImportPhraseAction),
          ),
        if (showReadOnly)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(WalletRecoveryFallbackChoice.readOnly),
              child: Text(l10n.walletRecoveryContinueReadOnlyAction),
            ),
          ),
      ];

      return KubusAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              description,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.walletRecoveryReadOnlyDescription,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.66),
                height: 1.35,
              ),
            ),
            if (showRecoveryPhrase) ...<Widget>[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.walletRecoveryPhraseMustMatchDescription,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.66),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: KubusSpacing.md),
            ...choices.expand(
              (choice) => <Widget>[
                choice,
                const SizedBox(height: KubusSpacing.sm),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      );
    },
  );
}

Future<String?> showWalletRecoveryPhraseImportPrompt({
  required BuildContext context,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  try {
    return await showKubusDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;

        return KubusAlertDialog(
          title: Text(l10n.walletRecoveryImportPhraseAction),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.walletRecoveryPhraseMustMatchDescription,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.walletRecoveryPhraseLabel,
                    hintText: l10n.connectWalletImportHint,
                  ),
                  validator: (value) {
                    final normalized =
                        (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
                    if (normalized.isEmpty) {
                      return l10n.connectWalletImportEmptyMnemonicError;
                    }
                    final words = normalized
                        .split(' ')
                        .where((word) => word.isNotEmpty)
                        .length;
                    if (words != 12 && words != 24) {
                      return l10n
                          .connectWalletImportInvalidMnemonicWordCountError(
                        words,
                      );
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
                Navigator.of(dialogContext).pop(
                  controller.text.trim().replaceAll(RegExp(r'\s+'), ' '),
                );
              },
              child: Text(l10n.walletRecoveryImportPhraseAction),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<String?> showWalletBackupTextPrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String description,
  String? initialValue,
  String? actionLabel,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final formKey = GlobalKey<FormState>();

  try {
    return await showKubusDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;

        return KubusAlertDialog(
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
                const SizedBox(height: KubusSpacing.md),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(labelText: label),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return l10n.walletBackupPromptRequiredError(label);
                    }
                    if (trimmed.length > 120) {
                      return l10n.walletBackupPromptTooLongError(label);
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
  } finally {
    controller.dispose();
  }
}
