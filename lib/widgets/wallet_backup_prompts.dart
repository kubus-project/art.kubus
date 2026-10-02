import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

enum WalletRecoveryFallbackChoice {
  recoveryPassword,
  recoveryPhrase,
  readOnly,
}

/// Asks for the wallet backup password.
///
/// The controllers deliberately belong to a [StatefulWidget] rather than to
/// this function. Disposing them in a `finally` after `await showKubusDialog`
/// looks equivalent but is not: the future completes when the route is
/// *popped*, while the dialog is still running its exit animation with the
/// fields — and their controllers — still mounted. That produced a real
/// "A TextEditingController was used after being disposed" on device. A
/// `State.dispose()` runs only once the widget is genuinely gone from the
/// tree, which is exactly the lifetime these controllers need.
Future<String?> showWalletBackupPasswordPrompt({
  required BuildContext context,
  required String title,
  required String description,
  bool confirm = false,
  String? actionLabel,
}) {
  return showKubusDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _WalletBackupPasswordDialog(
      title: title,
      description: description,
      confirm: confirm,
      actionLabel: actionLabel,
    ),
  );
}

class _WalletBackupPasswordDialog extends StatefulWidget {
  const _WalletBackupPasswordDialog({
    required this.title,
    required this.description,
    required this.confirm,
    this.actionLabel,
  });

  final String title;
  final String description;
  final bool confirm;
  final String? actionLabel;

  @override
  State<_WalletBackupPasswordDialog> createState() =>
      _WalletBackupPasswordDialogState();
}

class _WalletBackupPasswordDialogState
    extends State<_WalletBackupPasswordDialog> {
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _secondController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return KubusAlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.description,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            TextFormField(
              controller: _firstController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.confirm
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
            if (widget.confirm) ...<Widget>[
              const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
              TextFormField(
                controller: _secondController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.commonConfirmPassword,
                ),
                validator: (value) {
                  if ((value ?? '') != _firstController.text) {
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(_firstController.text.trim());
          },
          child: Text(widget.actionLabel ?? l10n.commonContinue),
        ),
      ],
    );
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

/// Asks for a recovery phrase. Controller lifetime is owned by the dialog
/// widget for the reason documented on [showWalletBackupPasswordPrompt].
Future<String?> showWalletRecoveryPhraseImportPrompt({
  required BuildContext context,
}) {
  return showKubusDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _WalletRecoveryPhraseDialog(),
  );
}

class _WalletRecoveryPhraseDialog extends StatefulWidget {
  const _WalletRecoveryPhraseDialog();

  @override
  State<_WalletRecoveryPhraseDialog> createState() =>
      _WalletRecoveryPhraseDialogState();
}

class _WalletRecoveryPhraseDialogState
    extends State<_WalletRecoveryPhraseDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return KubusAlertDialog(
      title: Text(l10n.walletRecoveryImportPhraseAction),
      content: Form(
        key: _formKey,
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
              controller: _controller,
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
                  return l10n.connectWalletImportInvalidMnemonicWordCountError(
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              _controller.text.trim().replaceAll(RegExp(r'\s+'), ' '),
            );
          },
          child: Text(l10n.walletRecoveryImportPhraseAction),
        ),
      ],
    );
  }
}

/// Asks for a single line of backup metadata. Controller lifetime is owned by
/// the dialog widget for the reason documented on
/// [showWalletBackupPasswordPrompt].
Future<String?> showWalletBackupTextPrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String description,
  String? initialValue,
  String? actionLabel,
}) {
  return showKubusDialog<String>(
    context: context,
    builder: (dialogContext) => _WalletBackupTextDialog(
      title: title,
      label: label,
      description: description,
      initialValue: initialValue,
      actionLabel: actionLabel,
    ),
  );
}

class _WalletBackupTextDialog extends StatefulWidget {
  const _WalletBackupTextDialog({
    required this.title,
    required this.label,
    required this.description,
    this.initialValue,
    this.actionLabel,
  });

  final String title;
  final String label;
  final String description;
  final String? initialValue;
  final String? actionLabel;

  @override
  State<_WalletBackupTextDialog> createState() =>
      _WalletBackupTextDialogState();
}

class _WalletBackupTextDialogState extends State<_WalletBackupTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return KubusAlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.description,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.label),
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) {
                  return l10n.walletBackupPromptRequiredError(widget.label);
                }
                if (trimmed.length > 120) {
                  return l10n.walletBackupPromptTooLongError(widget.label);
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(widget.actionLabel ?? l10n.commonSave),
        ),
      ],
    );
  }
}
