import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'kubus_snackbar.dart';

/// The canonical published legal documents. Each page carries the English and
/// Slovenian text, so both locales link to the same URL. `takedownNotice` is
/// the notice-and-takedown section of the Terms; the page carries one anchor
/// per language.
enum LegalDocument { termsOfUse, privacyPolicy, takedownNotice }

abstract final class LegalLinks {
  static final Uri termsOfUse =
      Uri.parse('https://art.kubus.site/terms-of-use.html');
  static final Uri privacyPolicy =
      Uri.parse('https://art.kubus.site/privacy-policy.html');

  static Uri of(LegalDocument document, [String languageCode = 'en']) =>
      switch (document) {
        LegalDocument.termsOfUse => termsOfUse,
        LegalDocument.privacyPolicy => privacyPolicy,
        LegalDocument.takedownNotice => termsOfUse.replace(
            fragment: languageCode == 'sl'
                ? 'obvestilo-in-odstranitev'
                : 'notice-and-takedown'),
      };
}

/// Dialog action that opens the full published legal document externally.
class LegalDocumentLinkAction extends StatelessWidget {
  const LegalDocumentLinkAction({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (document) {
      LegalDocument.termsOfUse => l10n.settingsLegalOpenFullTerms,
      LegalDocument.privacyPolicy => l10n.settingsLegalOpenFullPrivacy,
      LegalDocument.takedownNotice => l10n.settingsLegalOpenTakedown,
    };
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri =
        LegalLinks.of(document, Localizations.localeOf(context).languageCode);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failure =
        AppLocalizations.of(context)!.settingsLegalOpenFailed(uri.toString());
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showKubusSnackBar(SnackBar(content: Text(failure)));
    }
  }
}
