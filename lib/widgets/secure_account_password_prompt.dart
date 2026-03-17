import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

bool shouldPromptForGooglePasswordUpgrade(Map<String, dynamic> payload) {
  final data = _mapOrNull(payload['data']) ?? payload;
  final securityStatus = _mapOrNull(data['securityStatus']) ??
      _mapOrNull(payload['securityStatus']);
  if (securityStatus == null) return false;
  return data['isNewUser'] == true &&
      securityStatus['hasEmail'] == true &&
      securityStatus['hasPassword'] != true;
}

Future<void> maybeShowGooglePasswordUpgradePrompt(
  BuildContext context,
  Map<String, dynamic> payload,
) async {
  if (!AppConfig.isFeatureEnabled('emailAuth') ||
      !shouldPromptForGooglePasswordUpgrade(payload) ||
      !context.mounted) {
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final shouldOpen = await showKubusDialog<bool>(
    context: context,
    builder: (dialogContext) => KubusAlertDialog(
      backgroundColor: scheme.surface,
      title: Text(
        l10n.authSecureAccountAddPasswordTitle,
        style: GoogleFonts.inter(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        l10n.authSecureAccountPromptAddPasswordBody,
        style: GoogleFonts.inter(
          color: scheme.onSurface.withValues(alpha: 0.78),
          height: 1.4,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonSkipForNow),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.commonContinue),
        ),
      ],
    ),
  );

  if (shouldOpen != true || !context.mounted) return;
  await Navigator.of(context).pushNamed('/secure-account');
}
