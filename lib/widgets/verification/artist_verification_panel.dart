import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account_verification.dart';
import '../../providers/account_verification_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/design_tokens.dart';
import '../common/keyboard_inset_padding.dart';
import '../common/kubus_screen_header.dart';
import '../dashboard/kubus_dashboard_chrome.dart';
import '../inline_loading.dart';
import '../kubus_button.dart';
import '../kubus_snackbar.dart';

/// Normalises a portfolio entry the way the backend does: a bare host gets
/// `https://`. Returns null when the result is not an http(s) URL with a host.
String? normalizeArtistPortfolioUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final hasScheme =
      RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(trimmed);
  final candidate = hasScheme ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return candidate;
}

/// Artist verification status and application form.
///
/// One panel for every signed-in account. It reads the server's answer from
/// [AccountVerificationProvider] and applies through the account-owned
/// application endpoint, so it looks and behaves the same for an account with
/// a wallet and one without. No wallet is ever requested.
class ArtistVerificationPanel extends StatelessWidget {
  const ArtistVerificationPanel({super.key, this.onSubmitted});

  /// Called after an application was sent (for example to advance onboarding).
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountVerificationProvider>();
    final status = provider.artistStatus;
    final notes = provider.artistApplication?.reviewerNotes;

    final String? statusLabel;
    final KubusStatusTone tone;
    final String? detail;
    final String ctaLabel;
    final IconData ctaIcon;
    VoidCallback? onPressed;
    var primary = false;

    if (provider.isUnavailable) {
      statusLabel = null;
      tone = KubusStatusTone.neutral;
      detail = l10n.verificationUnavailable;
      ctaLabel = l10n.verificationCtaRetry;
      ctaIcon = Icons.refresh_rounded;
      onPressed = () => provider.refresh();
    } else if (!provider.isReady) {
      statusLabel = null;
      tone = KubusStatusTone.neutral;
      detail = null;
      ctaLabel = l10n.verificationArtistCtaApply;
      ctaIcon = Icons.send_rounded;
    } else {
      switch (status) {
        case ArtistVerificationStatus.notApplied:
          statusLabel = l10n.verificationStatusNotApplied;
          tone = KubusStatusTone.neutral;
          detail = l10n.verificationArtistDetailNotApplied;
          ctaLabel = l10n.verificationArtistCtaApply;
          ctaIcon = Icons.send_rounded;
          primary = true;
        case ArtistVerificationStatus.pending:
          statusLabel = l10n.verificationStatusPending;
          tone = KubusStatusTone.warning;
          detail = l10n.verificationArtistDetailPending;
          ctaLabel = l10n.verificationArtistCtaPending;
          ctaIcon = Icons.hourglass_bottom;
        case ArtistVerificationStatus.approved:
          statusLabel = l10n.verificationStatusApproved;
          tone = KubusStatusTone.positive;
          detail = l10n.verificationArtistDetailApproved;
          ctaLabel = l10n.verificationArtistCtaApproved;
          ctaIcon = Icons.verified_outlined;
        case ArtistVerificationStatus.rejected:
          statusLabel = l10n.verificationStatusRejected;
          tone = KubusStatusTone.negative;
          detail = notes ?? l10n.verificationArtistDetailRejected;
          ctaLabel = l10n.verificationArtistCtaReapply;
          ctaIcon = Icons.send_rounded;
          primary = true;
        case ArtistVerificationStatus.revoked:
          statusLabel = l10n.verificationStatusRevoked;
          tone = KubusStatusTone.negative;
          detail = notes ?? l10n.verificationArtistDetailRevoked;
          ctaLabel = l10n.verificationArtistCtaReapply;
          ctaIcon = Icons.send_rounded;
          primary = true;
      }
      if (primary) {
        onPressed = () async {
          final sent = await showArtistApplicationSheet(context);
          if (sent) onSubmitted?.call();
        };
      }
    }

    return KubusStatusPanel(
      title: l10n.verificationArtistCardTitle,
      description: l10n.verificationArtistCardSubtitle,
      statusLabel: statusLabel,
      tone: tone,
      isLoading: provider.isLoading,
      detail: detail,
      action: KubusButton(
        onPressed: onPressed,
        label: ctaLabel,
        icon: ctaIcon,
        isFullWidth: true,
        variant:
            primary ? KubusButtonVariant.primary : KubusButtonVariant.secondary,
      ),
    );
  }
}

/// Opens the artist application form. Returns true once an application was
/// sent. The provider refuses to send a second one while an application is
/// pending or approved, so a double tap or a replay cannot queue twice.
Future<bool> showArtistApplicationSheet(BuildContext context) async {
  final provider = context.read<AccountVerificationProvider>();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<AccountVerificationProvider>.value(
      value: provider,
      child: const _ArtistApplicationSheet(),
    ),
  );
  return result == true;
}

class _ArtistApplicationSheet extends StatefulWidget {
  const _ArtistApplicationSheet();

  @override
  State<_ArtistApplicationSheet> createState() =>
      _ArtistApplicationSheetState();
}

class _ArtistApplicationSheetState extends State<_ArtistApplicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _portfolio = TextEditingController();
  final _medium = TextEditingController();
  final _statement = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _portfolio.dispose();
    _medium.dispose();
    _statement.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = context.read<AccountVerificationProvider>();
    final portfolio = normalizeArtistPortfolioUrl(_portfolio.text);
    if (portfolio == null) return;
    setState(() => _sending = true);
    try {
      final sent = await provider.submitArtistApplication(
        portfolioUrl: portfolio,
        medium: _medium.text.trim(),
        statement: _statement.text.trim(),
      );
      if (!mounted) return;
      // Null means the signed-in account changed while the request was in
      // flight: the result belongs to nobody on this screen, so say nothing.
      if (sent == null) {
        navigator.pop(false);
        return;
      }
      navigator.pop(true);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.verificationArtistSubmitted)),
      );
    } on BackendApiRequestException catch (error) {
      if (!mounted) return;
      // 409: an open application already exists. Show its real state.
      if (error.statusCode == 409) {
        await provider.refresh();
        if (mounted) navigator.pop(false);
        return;
      }
      setState(() => _sending = false);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.verificationSubmitFailed)),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Artist application failed: $error');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.verificationSubmitFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return KeyboardInsetPadding(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KubusRadius.xl),
            topRight: Radius.circular(KubusRadius.xl),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KubusSheetHeader(
                      title: l10n.verificationArtistFormTitle,
                      subtitle: l10n.verificationArtistFormSubtitle,
                      showHandle: false,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('artist-application-portfolio'),
                      controller: _portfolio,
                      enabled: !_sending,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText:
                            l10n.artistStudioApplicationFieldPortfolioLabel,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n
                              .artistStudioApplicationValidationPortfolio;
                        }
                        if (normalizeArtistPortfolioUrl(value) == null) {
                          return l10n.artistStudioAccountPortfolioInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    TextFormField(
                      key: const ValueKey('artist-application-medium'),
                      controller: _medium,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        labelText: l10n.artistStudioApplicationFieldMediumLabel,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? l10n.artistStudioApplicationValidationMedium
                              : null,
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    TextFormField(
                      key: const ValueKey('artist-application-statement'),
                      controller: _statement,
                      enabled: !_sending,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText:
                            l10n.artistStudioApplicationFieldStatementLabel,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value == null ||
                              value.trim().length < 20)
                          ? l10n
                              .artistStudioApplicationValidationStatementMinChars(
                                  20)
                          : null,
                    ),
                    const SizedBox(height: KubusSpacing.lg),
                    FilledButton(
                      key: const ValueKey('artist-application-submit'),
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const InlineLoading(width: 18, height: 18)
                          : Text(l10n.artistStudioApplicationSubmitButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
