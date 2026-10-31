import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../screens/support_center_screen.dart';
import '../services/account_data_export_service.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
import 'inline_loading.dart';

enum _ExportChoice { contactSupport }

/// "Download a copy of my data" for the signed-in account, shared by the mobile
/// and desktop settings. The file is assembled by the server; the secondary
/// action keeps the support form available for anything the file does not hold.
Future<void> showAccountDataExportDialog(
  BuildContext context, {
  AccountDataExportService? service,
}) async {
  final choice = await showKubusDialog<_ExportChoice>(
    context: context,
    builder: (_) => _AccountDataExportDialog(
        service: service ?? AccountDataExportService()),
  );
  if (choice == _ExportChoice.contactSupport && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          const SupportCenterScreen(initialSection: SupportSection.contact),
    ));
  }
}

class _AccountDataExportDialog extends StatefulWidget {
  const _AccountDataExportDialog({required this.service});

  final AccountDataExportService service;

  @override
  State<_AccountDataExportDialog> createState() =>
      _AccountDataExportDialogState();
}

class _AccountDataExportDialogState extends State<_AccountDataExportDialog> {
  bool _busy = false;
  AccountDataExportOutcome? _outcome;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final outcome = await widget.service.run();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  String? _statusText(AppLocalizations l10n) {
    if (_busy) return l10n.settingsExportPreparing;
    switch (_outcome) {
      case null:
        return null;
      case AccountDataExportOutcome.saved:
        return l10n.settingsExportReady;
      case AccountDataExportOutcome.signInRequired:
        return l10n.settingsExportSignInRequired;
      case AccountDataExportOutcome.tooManyRequests:
        return l10n.settingsExportTooManyRequests;
      case AccountDataExportOutcome.failed:
        return l10n.settingsExportFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final status = _statusText(l10n);
    final saved = _outcome == AccountDataExportOutcome.saved;

    return KubusAlertDialog(
      size: KubusDialogSize.compact,
      backgroundColor: scheme.surface,
      title: Text(
        l10n.settingsExportDataDialogTitle,
        style: KubusTypography.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsExportDataDialogBody,
            style: KubusTypography.inter(color: scheme.onSurface),
          ),
          if (status != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_busy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: InlineLoading(tileSize: 6),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      style: KubusTypography.inter(
                        color: _outcome == null || saved
                            ? scheme.onSurface
                            : scheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: saved
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l10n.commonCancel,
                  style: KubusTypography.inter(color: scheme.outline),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () =>
                        Navigator.of(context).pop(_ExportChoice.contactSupport),
                child: Text(l10n.settingsExportButton),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                onPressed: _busy ? null : _download,
                child: Text(l10n.settingsExportDownloadButton),
              ),
            ],
    );
  }
}
