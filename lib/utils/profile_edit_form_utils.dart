import 'package:art_kubus/l10n/app_localizations.dart';

class ProfileEditFormUtils {
  static const int usernameMinLength = 3;
  static const int bioMaxLength = 500;

  static String? validateUsername(
    AppLocalizations l10n,
    String? value,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return l10n.profileEditUsernameRequiredError;
    }
    if (trimmed.length < usernameMinLength) {
      return l10n.profileEditUsernameMinLengthError;
    }
    return null;
  }

  static String? validateDisplayName(
    AppLocalizations l10n,
    String? value,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return l10n.profileEditDisplayNameRequiredError;
    }
    return null;
  }

  static String? validateYearsActive(
    AppLocalizations l10n,
    String? value,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final years = int.tryParse(trimmed);
    if (years == null || years < 0) {
      return l10n.profileEditArtistYearsActiveInvalidError;
    }
    return null;
  }

  static String normalizeWebsiteForSave(String rawValue) {
    final normalized = normalizeWebsite(rawValue);
    return normalized ?? rawValue.trim();
  }

  static String? validateWebsite(
    AppLocalizations l10n,
    String? value,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return normalizeWebsite(trimmed) == null
        ? l10n.profileEditSocialUrlInvalidError
        : null;
  }

  static String? normalizeWebsite(String? rawValue) {
    final trimmed = rawValue?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(RegExp(r'\s'))) {
      return null;
    }

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
    final withScheme = hasScheme
        ? trimmed
        : (trimmed.startsWith('//') ? 'https:$trimmed' : 'https://$trimmed');
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null) return null;

    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (parsed.host.trim().isEmpty) {
      return null;
    }
    return parsed.toString();
  }
}
