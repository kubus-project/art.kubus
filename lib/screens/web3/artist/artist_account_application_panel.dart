import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/artist_application.dart';
import '../../../services/backend_api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/kubus_snackbar.dart';

typedef ArtistApplicationFetch = Future<ArtistApplicationSummary?> Function();
typedef ArtistApplicationSubmit = Future<ArtistApplicationSummary> Function({
  required String portfolioUrl,
  required String medium,
  required String statement,
});

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

/// Artist application status and form for a signed-in account without a
/// wallet. It replaces the wallet-keyed governance card for those accounts, so
/// no "connect a wallet to apply" call to action is shown.
///
/// [fetch] and [submit] default to the account endpoints
/// (`GET /api/dao/artist-applications/mine`, `POST /api/dao/artist-applications`)
/// and can be injected. Any failure to load shows a calm "unavailable right
/// now" state instead of an error.
class ArtistAccountApplicationPanel extends StatefulWidget {
  const ArtistAccountApplicationPanel({super.key, this.fetch, this.submit});

  final ArtistApplicationFetch? fetch;
  final ArtistApplicationSubmit? submit;

  @override
  State<ArtistAccountApplicationPanel> createState() =>
      _ArtistAccountApplicationPanelState();
}

class _ArtistAccountApplicationPanelState
    extends State<ArtistAccountApplicationPanel> {
  ArtistApplicationSummary? _application;
  bool _loading = true;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fetch = widget.fetch ?? BackendApiService().getMyArtistApplication;
    try {
      final application = await fetch();
      if (!mounted) return;
      setState(() {
        _application = application;
        _unavailable = false;
        _loading = false;
      });
    } catch (error) {
      // A missing route on an older backend, an outage or an expired session
      // all read the same to the applicant: try again later.
      if (kDebugMode) {
        debugPrint('ArtistAccountApplicationPanel: load failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _application = null;
        _unavailable = true;
        _loading = false;
      });
    }
  }

  Future<void> _openForm() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final portfolioController = TextEditingController();
    final mediumController = TextEditingController();
    final statementController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            return SingleChildScrollView(
              child: BackdropGlassSheet(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                showHandle: false,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KubusSheetHeader(
                        title: l10n.artistStudioApplicationModalTitle,
                        subtitle: l10n.artistStudioApplicationModalSubtitle,
                        showHandle: false,
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      TextFormField(
                        controller: portfolioController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldPortfolioLabel,
                          border: const OutlineInputBorder(),
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
                        controller: mediumController,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldMediumLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? l10n.artistStudioApplicationValidationMedium
                                : null,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      TextFormField(
                        controller: statementController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              l10n.artistStudioApplicationFieldStatementLabel,
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null ||
                                value.trim().length < 20)
                            ? l10n
                                .artistStudioApplicationValidationStatementMinChars(
                                    20)
                            : null,
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: KubusButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final portfolio = normalizeArtistPortfolioUrl(
                                    portfolioController.text,
                                  );
                                  if (portfolio == null) return;
                                  final navigator = Navigator.of(sheetContext);
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final submit = widget.submit ??
                                        BackendApiService()
                                            .submitArtistApplication;
                                    final application = await submit(
                                      portfolioUrl: portfolio,
                                      medium: mediumController.text.trim(),
                                      statement:
                                          statementController.text.trim(),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _application = application;
                                      _unavailable = false;
                                    });
                                    navigator.pop();
                                    messenger.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(l10n
                                            .artistStudioApplicationSubmittedToast),
                                      ),
                                    );
                                  } catch (error) {
                                    if (kDebugMode) {
                                      debugPrint(
                                        'ArtistAccountApplicationPanel: submit failed: $error',
                                      );
                                    }
                                    // Keep the sheet open so the applicant can
                                    // correct the form or try again.
                                    setModalState(() => isSubmitting = false);
                                    messenger.showKubusSnackBar(
                                      SnackBar(
                                        content: Text(l10n
                                            .artistStudioApplicationSubmissionFailedToast),
                                      ),
                                    );
                                  }
                                },
                          label: l10n.artistStudioApplicationSubmitButton,
                          icon: Icons.send_rounded,
                          isLoading: isSubmitting,
                          isFullWidth: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final application = _application;
    final isPending = application?.isPending ?? false;
    final isApproved = application?.isApproved ?? false;
    final isRejected = application?.isRejected ?? false;
    final canApply =
        !_loading && !_unavailable && (application == null || isRejected);

    final String? statusLabel;
    final KubusStatusTone tone;
    final String? detail;
    final String ctaLabel;
    final IconData ctaIcon;

    if (_unavailable) {
      statusLabel = null;
      tone = KubusStatusTone.neutral;
      detail = l10n.artistStudioAccountApplicationUnavailable;
      ctaLabel = l10n.artistStudioAccountCtaRetry;
      ctaIcon = Icons.refresh_rounded;
    } else if (_loading) {
      statusLabel = null;
      tone = KubusStatusTone.neutral;
      detail = null;
      ctaLabel = l10n.artistStudioAccountCtaApply;
      ctaIcon = Icons.send_rounded;
    } else if (application == null) {
      statusLabel = l10n.artistStudioDaoStatusNotApplied;
      tone = KubusStatusTone.neutral;
      detail = l10n.artistStudioAccountDetailNotApplied;
      ctaLabel = l10n.artistStudioAccountCtaApply;
      ctaIcon = Icons.send_rounded;
    } else if (isApproved) {
      statusLabel = l10n.artistStudioDaoStatusApproved;
      tone = KubusStatusTone.positive;
      detail =
          application.reviewerNotes ?? l10n.artistStudioAccountDetailApproved;
      ctaLabel = l10n.artistStudioCtaApprovedByDao;
      ctaIcon = Icons.verified_outlined;
    } else if (isPending) {
      statusLabel = l10n.artistStudioDaoStatusPending;
      tone = KubusStatusTone.warning;
      detail =
          application.reviewerNotes ?? l10n.artistStudioAccountDetailPending;
      ctaLabel = l10n.artistStudioCtaPendingDaoReview;
      ctaIcon = Icons.hourglass_bottom;
    } else {
      statusLabel = l10n.artistStudioDaoStatusRejected;
      tone = KubusStatusTone.negative;
      detail =
          application.reviewerNotes ?? l10n.artistStudioAccountDetailRejected;
      ctaLabel = l10n.artistStudioCtaResubmitForReview;
      ctaIcon = Icons.send_rounded;
    }

    return KubusStatusPanel(
      title: l10n.artistStudioDaoCardTitle,
      description: l10n.artistStudioDaoCardSubtitle,
      statusLabel: statusLabel,
      tone: tone,
      isLoading: _loading,
      detail: detail,
      action: KubusButton(
        onPressed: canApply
            ? _openForm
            : _unavailable
                ? () {
                    setState(() {
                      _loading = true;
                      _unavailable = false;
                    });
                    _load();
                  }
                : null,
        label: ctaLabel,
        icon: ctaIcon,
        isFullWidth: true,
        variant: canApply
            ? KubusButtonVariant.primary
            : KubusButtonVariant.secondary,
      ),
    );
  }
}
