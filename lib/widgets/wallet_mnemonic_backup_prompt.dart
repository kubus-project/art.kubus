import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../screens/desktop/desktop_shell.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
import 'kubus_button.dart';

Future<bool> showWalletMnemonicBackupPrompt({
  required BuildContext context,
  required String mnemonic,
  required String address,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final isDesktop = DesktopBreakpoints.isDesktop(context);
  final confirmController = TextEditingController();
  bool confirmed = false;
  final trimmedAddress = address.trim();
  final shortAddress = trimmedAddress.length <= 14
      ? trimmedAddress
      : '${trimmedAddress.substring(0, 8)}...'
          '${trimmedAddress.substring(trimmedAddress.length - 6)}';

  Widget buildMnemonicContent(
    BuildContext innerContext,
    StateSetter setDialogState,
  ) {
    final scheme = Theme.of(innerContext).colorScheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: KubusHeaderMetrics.actionIcon,
                ),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.connectWalletMnemonicDialogWarning,
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              border: Border.all(color: scheme.outline),
            ),
            child: SelectableText(
              mnemonic,
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Text(
            l10n.connectWalletMnemonicDialogConfirmPrompt,
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.connectWalletMnemonicDialogConfirmHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
            ),
            onChanged: (value) {
              setDialogState(() {
                confirmed = value.trim() == mnemonic;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            l10n.connectWalletMnemonicDialogAddressLabel(shortAddress),
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> showDesktopMnemonicDialog() {
    return showKubusDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => KubusAlertDialog(
          title: Text(l10n.connectWalletMnemonicDialogTitle),
          content: buildMnemonicContent(dialogContext, setDialogState),
          actions: [
            ElevatedButton(
              onPressed:
                  confirmed ? () => Navigator.pop(dialogContext, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
              child: Text(
                l10n.connectWalletMnemonicDialogConfirmButton,
                style: KubusTypography.textTheme.labelLarge?.copyWith(
                  color: confirmed ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> showMobileMnemonicSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setDialogState) {
          final scheme = Theme.of(sheetContext).colorScheme;
          return FractionallySizedBox(
            heightFactor: 0.94,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KubusSpacing.md,
                  KubusSpacing.md,
                  KubusSpacing.md,
                  KubusSpacing.lg,
                ),
                child: LiquidGlassPanel(
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  padding: const EdgeInsets.fromLTRB(
                    KubusChromeMetrics.cardPadding,
                    KubusChromeMetrics.cardPadding,
                    KubusChromeMetrics.cardPadding,
                    KubusSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.connectWalletMnemonicDialogTitle,
                        style: KubusTextStyles.sheetTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      Expanded(
                        child: buildMnemonicContent(
                          sheetContext,
                          setDialogState,
                        ),
                      ),
                      const SizedBox(height: KubusChromeMetrics.cardPadding),
                      KubusButton(
                        onPressed: confirmed
                            ? () => Navigator.pop(sheetContext, true)
                            : null,
                        label: l10n.connectWalletMnemonicDialogConfirmButton,
                        isFullWidth: true,
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  final didConfirm = isDesktop
      ? await showDesktopMnemonicDialog()
      : await showMobileMnemonicSheet();

  confirmController.dispose();
  return didConfirm == true;
}
