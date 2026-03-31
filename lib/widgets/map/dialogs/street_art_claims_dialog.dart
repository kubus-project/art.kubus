import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/street_art_claim.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/street_art_claims_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../glass_components.dart';
import '../../kubus_snackbar.dart';

class StreetArtClaimsDialog extends StatefulWidget {
  const StreetArtClaimsDialog({
    super.key,
    required this.marker,
    required this.isMarkerOwner,
    this.canUseDaoReviewActions = false,
  });

  final ArtMarker marker;
  final bool isMarkerOwner;
  final bool canUseDaoReviewActions;

  static Future<void> show({
    required BuildContext context,
    required ArtMarker marker,
    required bool isMarkerOwner,
    bool canUseDaoReviewActions = false,
  }) {
    return showKubusDialog<void>(
      context: context,
      builder: (_) => StreetArtClaimsDialog(
        marker: marker,
        isMarkerOwner: isMarkerOwner,
        canUseDaoReviewActions: canUseDaoReviewActions,
      ),
    );
  }

  @override
  State<StreetArtClaimsDialog> createState() => _StreetArtClaimsDialogState();
}

class _StreetArtClaimsDialogState extends State<StreetArtClaimsDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _evidenceController = TextEditingController();
  final TextEditingController _profileNameController = TextEditingController();

  bool _didRequestInitialLoad = false;

  @override
  void initState() {
    super.initState();

    final profileProvider = context.read<ProfileProvider>();
    final fallbackProfileName =
        profileProvider.currentUser?.displayName.trim() ?? '';
    if (fallbackProfileName.isNotEmpty) {
      _profileNameController.text = fallbackProfileName;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadClaims(force: true);
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _evidenceController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadClaims({bool force = false}) async {
    if (_didRequestInitialLoad && !force) return;
    _didRequestInitialLoad = true;

    final provider = context.read<StreetArtClaimsProvider>();
    await provider.loadClaims(widget.marker.id, force: force);
  }

  Future<void> _submitClaim() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerClaimReasonMinError(10))),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    final provider = context.read<StreetArtClaimsProvider>();
    final claim = await provider.submitClaim(
      markerId: widget.marker.id,
      reason: reason,
      evidenceUrl: _emptyToNull(_evidenceController.text),
      claimantProfileName: _emptyToNull(_profileNameController.text),
      refresh: true,
    );

    if (!mounted) return;

    if (claim != null) {
      _reasonController.clear();
      _evidenceController.clear();
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerClaimSubmittedToast)),
        tone: KubusSnackBarTone.success,
      );
      return;
    }

    final error = provider.errorForMarker(widget.marker.id) ?? '';
    final normalized = error.toLowerCase();
    if (normalized.contains('verified artists')) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerClaimNotEligibleToast)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }
    if (normalized.contains('active claim')) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerClaimAlreadyActiveToast)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.commonActionFailedToast)),
      tone: KubusSnackBarTone.error,
    );
  }

  Future<void> _reviewClaim(
    StreetArtClaim claim,
    StreetArtClaimReviewAction action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final note = await _promptReviewNote(action);
    if (!mounted) return;
    if (note == null) return;

    final provider = context.read<StreetArtClaimsProvider>();
    final updated = await provider.reviewClaim(
      markerId: widget.marker.id,
      claimId: claim.id,
      action: action,
      note: note.isEmpty ? null : note,
      refresh: true,
    );

    if (!mounted) return;
    if (updated != null) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerClaimActionSuccessToast)),
        tone: KubusSnackBarTone.success,
      );
      return;
    }

    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.commonActionFailedToast)),
      tone: KubusSnackBarTone.error,
    );
  }

  Future<String?> _promptReviewNote(StreetArtClaimReviewAction action) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    String actionLabel(StreetArtClaimReviewAction value) {
      switch (value) {
        case StreetArtClaimReviewAction.approve:
          return l10n.mapMarkerClaimActionApprove;
        case StreetArtClaimReviewAction.reject:
          return l10n.mapMarkerClaimActionReject;
        case StreetArtClaimReviewAction.escalate:
          return l10n.mapMarkerClaimActionEscalate;
        case StreetArtClaimReviewAction.approveDao:
          return l10n.mapMarkerClaimActionApproveDao;
        case StreetArtClaimReviewAction.rejectDao:
          return l10n.mapMarkerClaimActionRejectDao;
      }
    }

    try {
      final result = await showKubusDialog<String?>(
        context: context,
        builder: (dialogContext) => KubusAlertDialog(
          title: Text(actionLabel(action)),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.mapMarkerClaimNoteLabel,
                border: OutlineInputBorder(
                  borderRadius: KubusRadius.circular(KubusRadius.md),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(actionLabel(action)),
            ),
          ],
        ),
      );
      return result;
    } finally {
      controller.dispose();
    }
  }

  String? _emptyToNull(String? input) {
    final value = (input ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String _shortWallet(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 12) return trimmed;
    return '${trimmed.substring(0, 6)}…${trimmed.substring(trimmed.length - 4)}';
  }

  String _statusLabel(AppLocalizations l10n, StreetArtClaimStatus status) {
    switch (status) {
      case StreetArtClaimStatus.pendingOwnerReview:
        return l10n.mapMarkerClaimStatusPendingOwnerReview;
      case StreetArtClaimStatus.pendingDaoReview:
        return l10n.mapMarkerClaimStatusPendingDaoReview;
      case StreetArtClaimStatus.approved:
        return l10n.mapMarkerClaimStatusApproved;
      case StreetArtClaimStatus.rejectedOwner:
        return l10n.mapMarkerClaimStatusRejectedOwner;
      case StreetArtClaimStatus.rejectedDao:
        return l10n.mapMarkerClaimStatusRejectedDao;
      case StreetArtClaimStatus.unknown:
        return l10n.commonUnknown;
    }
  }

  String _stageLabel(AppLocalizations l10n, StreetArtClaimStage stage) {
    switch (stage) {
      case StreetArtClaimStage.ownerReview:
        return l10n.mapMarkerClaimStageOwnerReview;
      case StreetArtClaimStage.daoReview:
        return l10n.mapMarkerClaimStageDaoReview;
      case StreetArtClaimStage.resolved:
        return l10n.mapMarkerClaimStageResolved;
      case StreetArtClaimStage.unknown:
        return l10n.commonUnknown;
    }
  }

  bool _canOwnerReview(StreetArtClaim claim) {
    return widget.isMarkerOwner &&
        claim.reviewStage == StreetArtClaimStage.ownerReview &&
        claim.isOpen;
  }

  bool _canDaoReview(StreetArtClaim claim) {
    return widget.canUseDaoReviewActions &&
        claim.reviewStage == StreetArtClaimStage.daoReview &&
        claim.isOpen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<StreetArtClaimsProvider>(
      builder: (context, provider, _) {
        final claims = provider.claimsForMarker(widget.marker.id);
        final isLoading = provider.isLoading(widget.marker.id);
        final isSubmitting = provider.isSubmitting(widget.marker.id);
        final error = provider.errorForMarker(widget.marker.id);

        return KubusAlertDialog(
          title: Text(l10n.mapMarkerClaimsDialogTitle),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isMarkerOwner) ...[
                  Text(
                    l10n.mapMarkerClaimSubmitTitle,
                    style: KubusTypography.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextField(
                    controller: _reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.mapMarkerClaimReasonLabel,
                      border: OutlineInputBorder(
                        borderRadius: KubusRadius.circular(KubusRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextField(
                    controller: _evidenceController,
                    decoration: InputDecoration(
                      labelText: l10n.mapMarkerClaimEvidenceUrlLabel,
                      border: OutlineInputBorder(
                        borderRadius: KubusRadius.circular(KubusRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextField(
                    controller: _profileNameController,
                    decoration: InputDecoration(
                      labelText: l10n.mapMarkerClaimProfileNameLabel,
                      border: OutlineInputBorder(
                        borderRadius: KubusRadius.circular(KubusRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: isSubmitting ? null : _submitClaim,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gavel_outlined),
                      label: Text(l10n.mapMarkerClaimSubmitButton),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                ],
                if (error != null && error.trim().isNotEmpty) ...[
                  Text(
                    error,
                    style: KubusTypography.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                ],
                SizedBox(
                  height: 340,
                  child: isLoading
                      ? Center(
                          child: Text(
                            l10n.mapMarkerClaimLoading,
                            style: KubusTypography.textTheme.bodyMedium,
                          ),
                        )
                      : claims.isEmpty
                          ? Center(
                              child: Text(
                                l10n.mapMarkerClaimNoClaims,
                                style: KubusTypography.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              itemCount: claims.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final claim = claims[index];
                                final claimant =
                                    (claim.claimantProfileName ?? '').trim()
                                            .isNotEmpty
                                        ? claim.claimantProfileName!.trim()
                                        : _shortWallet(claim.claimantWallet);

                                final canOwnerReview = _canOwnerReview(claim);
                                final canDaoReview = _canDaoReview(claim);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      claimant,
                                      style: KubusTypography.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: KubusSpacing.xxs),
                                    Text(
                                      '${_statusLabel(l10n, claim.status)} • ${_stageLabel(l10n, claim.reviewStage)}',
                                      style: KubusTypography.textTheme.bodySmall
                                          ?.copyWith(
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: KubusSpacing.xs),
                                    Text(
                                      claim.reason,
                                      style:
                                          KubusTypography.textTheme.bodyMedium,
                                    ),
                                    if ((claim.evidenceUrl ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: KubusSpacing.xs,
                                        ),
                                        child: Text(
                                          claim.evidenceUrl!,
                                          style:
                                              KubusTypography.textTheme.bodySmall,
                                        ),
                                      ),
                                    if (canOwnerReview) ...[
                                      const SizedBox(height: KubusSpacing.sm),
                                      Wrap(
                                        spacing: KubusSpacing.xs,
                                        runSpacing: KubusSpacing.xs,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => unawaited(
                                              _reviewClaim(
                                                claim,
                                                StreetArtClaimReviewAction
                                                    .approve,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.mapMarkerClaimActionApprove,
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => unawaited(
                                              _reviewClaim(
                                                claim,
                                                StreetArtClaimReviewAction
                                                    .reject,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.mapMarkerClaimActionReject,
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => unawaited(
                                              _reviewClaim(
                                                claim,
                                                StreetArtClaimReviewAction
                                                    .escalate,
                                              ),
                                            ),
                                            child: Text(
                                              l10n.mapMarkerClaimActionEscalate,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (canDaoReview) ...[
                                      const SizedBox(height: KubusSpacing.sm),
                                      Wrap(
                                        spacing: KubusSpacing.xs,
                                        runSpacing: KubusSpacing.xs,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => unawaited(
                                              _reviewClaim(
                                                claim,
                                                StreetArtClaimReviewAction
                                                    .approveDao,
                                              ),
                                            ),
                                            child: Text(
                                              l10n
                                                  .mapMarkerClaimActionApproveDao,
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => unawaited(
                                              _reviewClaim(
                                                claim,
                                                StreetArtClaimReviewAction
                                                    .rejectDao,
                                              ),
                                            ),
                                            child: Text(
                                              l10n
                                                  .mapMarkerClaimActionRejectDao,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.commonClose),
            ),
          ],
        );
      },
    );
  }
}
