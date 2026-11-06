import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/account_closure_coordinator.dart';
import '../services/backend_api_service.dart';
import '../services/settings_service.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
import 'kubus_snackbar.dart';

/// Test seam. When set, [confirmAndCloseAccount] uses this coordinator.
@visibleForTesting
AccountClosureCoordinator? debugAccountClosureCoordinator;

/// One coordinator for the app, so single-flight covers both settings screens.
final AccountClosureCoordinator _sharedAccountClosureCoordinator =
    AccountClosureCoordinator(api: BackendApiService());

/// Account-closure entry point shared by desktop and mobile settings.
///
/// Shows two confirmations. The second one stays open while the closure runs,
/// with its buttons disabled and the busy state announced. The outcome is
/// applied the same way on both platforms.
Future<void> confirmAndCloseAccount(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final walletProvider = Provider.of<WalletProvider>(context, listen: false);
  final notificationProvider =
      Provider.of<NotificationProvider>(context, listen: false);
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final coordinator =
      debugAccountClosureCoordinator ?? _sharedAccountClosureCoordinator;

  Future<void> applyOutcome(AccountClosureOutcome outcome) async {
    switch (outcome) {
      case AccountClosureAccepted():
        await SettingsService.resetApp(
          walletProvider: walletProvider,
          backendApi: BackendApiService(),
          notificationProvider: notificationProvider,
          profileProvider: profileProvider,
        );
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.settingsAccountDeletedToast),
            duration: const Duration(seconds: 3),
          ),
        );
        navigator.pushNamedAndRemoveUntil('/account-closure', (_) => false);
        break;
      case AccountClosurePending():
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.settingsDeleteAccountPendingToast)),
        );
        navigator.pushNamedAndRemoveUntil('/account-closure', (_) => false);
        break;
      case AccountClosureFailed(:final reason):
        switch (reason) {
          case AccountClosureFailure.prepareRejected:
            messenger.showKubusSnackBar(
              SnackBar(
                content: Text(l10n.settingsDeleteAccountNotStartedToast),
              ),
            );
            break;
          case AccountClosureFailure.sessionChanged:
            // The result belongs to a session that is no longer current.
            break;
        }
        break;
      case AccountClosureAlreadyInProgress():
        break;
    }
  }

  final agreed = await showKubusDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return KubusAlertDialog(
        size: KubusDialogSize.compact,
        backgroundColor: scheme.surface,
        title: Text(
          l10n.settingsDeleteAccountDialogTitle,
          style: KubusTypography.inter(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsDeleteAccountDialogBody,
          style: KubusTypography.inter(color: scheme.onSurface),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(color: scheme.outline),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settingsDeleteForeverButton),
          ),
        ],
      );
    },
  );
  if (agreed != true || !context.mounted) return;

  await showKubusDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AccountClosureConfirmDialog(
      coordinator: coordinator,
      onOutcome: applyOutcome,
    ),
  );
}

class _AccountClosureConfirmDialog extends StatefulWidget {
  const _AccountClosureConfirmDialog({
    required this.coordinator,
    required this.onOutcome,
  });

  final AccountClosureCoordinator coordinator;
  final Future<void> Function(AccountClosureOutcome outcome) onOutcome;

  @override
  State<_AccountClosureConfirmDialog> createState() =>
      _AccountClosureConfirmDialogState();
}

class _AccountClosureConfirmDialogState
    extends State<_AccountClosureConfirmDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final outcome = await widget.coordinator.run();
    // Apply first, then close this dialog if it is still open. A navigation
    // that clears the stack removes it on its own.
    await widget.onOutcome(outcome);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: KubusAlertDialog(
        size: KubusDialogSize.compact,
        backgroundColor: scheme.surface,
        title: Text(
          l10n.settingsFinalConfirmationTitle,
          style: KubusTypography.inter(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: _busy
            ? Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.settingsDeleteAccountBusy,
                        style: KubusTypography.inter(color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                l10n.settingsDeleteAccountFinalConfirmationBody,
                style: KubusTypography.inter(color: scheme.onSurface),
              ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(color: scheme.outline),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _confirm,
            child: Text(
              l10n.settingsConfirmButton,
              style: KubusTypography.inter(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
