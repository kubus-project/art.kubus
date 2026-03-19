import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../screens/desktop/desktop_shell.dart';
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
  final shortAddress =
      '${address.substring(0, 8)}...${address.substring(address.length - 6)}';

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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.connectWalletMnemonicDialogWarning,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 16),
          Text(
            l10n.connectWalletMnemonicDialogConfirmPrompt,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.connectWalletMnemonicDialogConfirmHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
            style: GoogleFonts.inter(
              fontSize: 12,
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
          title: Text(
            l10n.connectWalletMnemonicDialogTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
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
                style: GoogleFonts.inter(
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: LiquidGlassPanel(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.connectWalletMnemonicDialogTitle,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: buildMnemonicContent(
                          sheetContext,
                          setDialogState,
                        ),
                      ),
                      const SizedBox(height: 20),
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
