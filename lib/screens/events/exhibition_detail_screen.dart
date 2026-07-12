import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/widgets/glass_components.dart';

import '../../models/event.dart';
import '../../models/exhibition.dart';
import '../../models/promotion.dart';
import '../../models/artwork.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/attestation_provider.dart';
import '../../providers/collab_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/profile_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../../services/backend_api_service.dart'
    show BackendApiRequestException;
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/poap_detail_card.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/design_tokens.dart';
import '../../config/config.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../widgets/promotion/promotion_builder_sheet.dart';
import '../../widgets/common/subject_options_sheet.dart';
import 'event_detail_screen.dart';

class ExhibitionDetailScreen extends StatefulWidget {
  final String exhibitionId;
  final Exhibition? initialExhibition;
  final String? attendanceMarkerId;
  final bool autoClaimPoap;
  final String? claimProofToken;
  final String? handoffToken;
  final String? proofSource;
  final bool embedded;

  const ExhibitionDetailScreen({
    super.key,
    required this.exhibitionId,
    this.initialExhibition,
    this.attendanceMarkerId,
    this.autoClaimPoap = false,
    this.claimProofToken,
    this.handoffToken,
    this.proofSource,
    this.embedded = false,
  });

  @override
  State<ExhibitionDetailScreen> createState() => _ExhibitionDetailScreenState();
}

class _ExhibitionDetailScreenState extends State<ExhibitionDetailScreen> {
  String? _prefetchedAttendanceMarkerId;
  bool _isClaimingPoap = false;
  bool _autoClaimAttempted = false;
  bool _scanProofExchangeAttempted = false;
  String? _claimProofToken;
  final Set<String> _deleteDialogOpenExhibitionIds = <String>{};
  final Set<String> _deleteInFlightExhibitionIds = <String>{};

  String get _effectiveProofSource {
    final source = (widget.proofSource ?? '').trim();
    return source.isNotEmpty ? source : 'system_camera_deeplink';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ExhibitionsProvider>();
      unawaited(provider.recordExhibitionView(widget.exhibitionId,
          source: 'exhibition_detail'));
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final provider = context.read<ExhibitionsProvider>();
    try {
      await provider.fetchExhibition(widget.exhibitionId, force: true);
    } catch (_) {
      // Provider handles errors.
    }
    // Program events and POAP are optional sections; their failures stay
    // local to their cards and never block the page.
    try {
      await provider.listExhibitionEvents(widget.exhibitionId, refresh: true);
    } catch (e) {
      debugPrint('ExhibitionDetailScreen: program load failed: $e');
    }
    try {
      await provider.fetchExhibitionPoap(widget.exhibitionId, force: true);
      await _maybeAutoClaimPoap();
    } catch (e) {
      debugPrint('ExhibitionDetailScreen: POAP load failed: $e');
    }
  }

  Future<void> _maybeAutoClaimPoap() async {
    if (!widget.autoClaimPoap || _autoClaimAttempted) return;

    final markerId = (widget.attendanceMarkerId ?? '').trim();
    final existingProof =
        (_claimProofToken ?? widget.claimProofToken ?? '').trim();
    final handoff = (widget.handoffToken ?? '').trim();
    if (markerId.isEmpty && existingProof.isEmpty && handoff.isEmpty) return;

    final provider = context.read<ExhibitionsProvider>();
    final currentPoap = provider.poapStatusFor(widget.exhibitionId);
    if (currentPoap == null || currentPoap.claimed) {
      return;
    }
    final hasProofContext = existingProof.isNotEmpty || handoff.isNotEmpty;
    if (!currentPoap.canClaim && !hasProofContext) {
      return;
    }

    _autoClaimAttempted = true;
    await _claimExhibitionPoap();
  }

  Future<String?> _ensureClaimProofToken() async {
    final current = (_claimProofToken ?? widget.claimProofToken ?? '').trim();
    if (current.isNotEmpty) {
      _claimProofToken = current;
      return current;
    }

    final handoff = (widget.handoffToken ?? '').trim();
    final markerId = (widget.attendanceMarkerId ?? '').trim();
    if (handoff.isEmpty || markerId.isEmpty || _scanProofExchangeAttempted) {
      return null;
    }

    _scanProofExchangeAttempted = true;
    final provider = context.read<ExhibitionsProvider>();
    final payload = await provider.createScanClaimProof(
      exhibitionId: widget.exhibitionId,
      markerId: markerId,
      proofSource: _effectiveProofSource,
      handoffToken: handoff,
    );
    final token = (payload?['claimProofToken'] ??
            payload?['scanProofToken'] ??
            payload?['claim_proof_token'] ??
            payload?['scan_proof_token'])
        ?.toString()
        .trim();
    if (token != null && token.isNotEmpty) {
      _claimProofToken = token;
      return token;
    }
    return null;
  }

  bool _canManageExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    // Keep in sync with backend `canEditEntity` (curator+) while preserving legacy `host`.
    return role == 'owner' ||
        role == 'admin' ||
        role == 'publisher' ||
        role == 'editor' ||
        role == 'curator' ||
        role == 'host';
  }

  bool _canPublishExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    // Keep in sync with backend `canPublishEntity` (publisher+).
    return role == 'owner' || role == 'admin' || role == 'publisher';
  }

  bool _canPromoteExhibition(Exhibition exhibition) {
    return _canPublishExhibition(exhibition.myRole) &&
        exhibition.isPublished &&
        exhibition.id.trim().isNotEmpty;
  }

  Future<void> _openPromotionFlow(Exhibition exhibition) async {
    if (!_canPromoteExhibition(exhibition)) return;
    await showPromotionBuilderSheet(
      context: context,
      entityType: PromotionEntityType.exhibition,
      entityId: exhibition.id,
      entityLabel: exhibition.title,
    );
  }

  List<Widget> _buildHeaderActions(
    AppLocalizations l10n,
    Exhibition ex,
  ) {
    return [
      IconButton(
        tooltip: l10n.exhibitionDetailInvitesTooltip,
        onPressed: () {
          final shellScope = DesktopShellScope.of(context);
          if (shellScope != null) {
            shellScope.pushScreen(
              DesktopSubScreen(
                title: l10n.exhibitionDetailInvitesTooltip,
                child: const InvitesInboxScreen(embedded: true),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InvitesInboxScreen()),
          );
        },
        icon: const Icon(Icons.inbox_outlined),
      ),
      IconButton(
        tooltip: l10n.exhibitionDetailRefreshTooltip,
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
    ];
  }

  Future<void> _togglePublish(Exhibition exhibition, bool publish) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();

    final nextStatus = publish ? 'published' : 'draft';
    if ((exhibition.status ?? '').trim().toLowerCase() == nextStatus) return;

    try {
      await provider.updateExhibition(
          exhibition.id, <String, dynamic>{'status': nextStatus});
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.commonSavedToast, style: KubusTypography.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.commonActionFailedToast,
              style: KubusTypography.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteExhibition(Exhibition exhibition) async {
    if (_deleteDialogOpenExhibitionIds.contains(exhibition.id) ||
        _deleteInFlightExhibitionIds.contains(exhibition.id)) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<ExhibitionsProvider>();

    _deleteDialogOpenExhibitionIds.add(exhibition.id);
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(l10n.exhibitionDetailDeleteDialogTitle),
        content:
            Text(l10n.exhibitionDetailDeleteDialogContent(exhibition.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    ).whenComplete(() {
      _deleteDialogOpenExhibitionIds.remove(exhibition.id);
    });
    if (confirmed != true) return;
    if (_deleteInFlightExhibitionIds.contains(exhibition.id)) return;

    _deleteInFlightExhibitionIds.add(exhibition.id);
    try {
      await provider.deleteExhibition(exhibition.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionDetailDeletedToast)),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    } finally {
      _deleteInFlightExhibitionIds.remove(exhibition.id);
    }
  }

  Future<void> _showExhibitionManagementActions(
    Exhibition ex, {
    required bool canManage,
    required bool canPublish,
    required bool canPromote,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showSubjectOptionsSheet(
      context: context,
      title: ex.title,
      subtitle: l10n.commonActions,
      actions: [
        SubjectOptionsAction(
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onSelected: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.exhibition(
                exhibitionId: widget.exhibitionId,
                title: ex.title,
              ),
              sourceScreen: 'exhibition_detail',
            );
          },
        ),
        if (canManage)
          SubjectOptionsAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: l10n.commonEdit,
            onSelected: () =>
                CreatorShellNavigation.openExhibitionCreatorWorkspace(
              context,
              initialExhibition: ex,
            ),
          ),
        if (canManage)
          SubjectOptionsAction(
            id: 'change_cover',
            icon: Icons.image_outlined,
            label: l10n.commonChangeCover,
            onSelected: () => _changeCover(ex),
          ),
        if (canManage)
          SubjectOptionsAction(
            id: 'link_artworks',
            icon: Icons.link_outlined,
            label: l10n.commonLink,
            onSelected: () => _showLinkArtworksDialog(ex),
          ),
        if (canPublish)
          SubjectOptionsAction(
            id: ex.isPublished ? 'unpublish' : 'publish',
            icon: ex.isPublished
                ? Icons.visibility_off_outlined
                : Icons.publish_outlined,
            label: ex.isPublished ? l10n.commonUnpublish : l10n.commonPublish,
            onSelected: () => _togglePublish(ex, !ex.isPublished),
          ),
        if (canPromote)
          SubjectOptionsAction(
            id: 'promote',
            icon: Icons.campaign_outlined,
            label: l10n.exhibitionDetailPromoteTooltip,
            onSelected: () => _openPromotionFlow(ex),
          ),
        if (canManage)
          SubjectOptionsAction(
            id: 'delete',
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            isDestructive: true,
            onSelected: () => _deleteExhibition(ex),
          ),
      ],
    );
  }

  Future<void> _claimExhibitionPoap() async {
    if (_isClaimingPoap) return;

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();
    final attestationProvider = context.read<AttestationProvider>();
    final currentPoap = provider.poapStatusFor(widget.exhibitionId);
    if (currentPoap?.claimed == true) return;

    setState(() {
      _isClaimingPoap = true;
    });

    try {
      final proofToken = await _ensureClaimProofToken();
      if (!mounted) return;

      final status = await provider.claimExhibitionPoap(
        widget.exhibitionId,
        attendanceMarkerId: widget.attendanceMarkerId,
        claimProofToken: proofToken,
        proofSource: proofToken == null ? null : _effectiveProofSource,
      );
      if (!mounted) return;

      if (status == null) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.exhibitionDetailPoapClaimFailedToast,
                style: KubusTypography.inter()),
            behavior: SnackBarBehavior.floating,
          ),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }

      unawaited(attestationProvider.refresh(force: true));

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
              status.eligibilityReason == 'already_claimed'
                  ? l10n.scanProofAlreadyClaimedToast
                  : l10n.exhibitionDetailPoapClaimSuccessToast,
              style: KubusTypography.inter()),
          behavior: SnackBarBehavior.floating,
        ),
        tone: KubusSnackBarTone.success,
      );
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      String? backendMessage;
      try {
        final raw = (e.body ?? '').trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final details = decoded['details'];
            final code =
                details is Map ? (details['code'] ?? '').toString().trim() : '';
            if (code == 'scan_proof_expired' ||
                code == 'scan_handoff_expired' ||
                code == 'scan_handoff_consumed') {
              backendMessage = l10n.scanProofExpiredToast;
            } else if (code == 'poap_in_person_proof_required') {
              backendMessage =
                  l10n.exhibitionDetailPoapEligibilityAttendanceHint;
            } else if (code == 'marker_not_linked_to_exhibition') {
              backendMessage =
                  l10n.exhibitionDetailPoapEligibilityMarkerLinkHint;
            } else if (code == 'exhibition_not_published') {
              backendMessage =
                  l10n.exhibitionDetailPoapEligibilityNotPublishedHint;
            } else if (code.startsWith('scan_proof_') ||
                code.startsWith('scan_handoff_')) {
              backendMessage = l10n.scanProofExpiredToast;
            }
          }
        }
      } catch (_) {
        // ignore
      }

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            backendMessage ?? l10n.exhibitionDetailPoapClaimFailedToast,
            style: KubusTypography.inter(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        tone: KubusSnackBarTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailPoapClaimFailedToast,
              style: KubusTypography.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingPoap = false;
        });
      }
    }
  }

  Future<void> _changeCover(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      final fileName = (file?.name ?? '').trim();

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.commonActionFailedToast,
                style: KubusTypography.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final url = await provider.uploadExhibitionCover(
        bytes: bytes,
        fileName: fileName.isEmpty ? 'cover.jpg' : fileName,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.commonActionFailedToast,
                style: KubusTypography.inter()),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await provider
          .updateExhibition(exhibition.id, <String, dynamic>{'coverUrl': url});

      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.commonSavedToast, style: KubusTypography.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.commonActionFailedToast,
              style: KubusTypography.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showLinkArtworksDialog(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    final artworkProvider = context.read<ArtworkProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final collabProvider = context.read<CollabProvider>();

    // Ensure we have a reasonably fresh list of artworks for selection.
    // (This screen does not guarantee ArtworkProvider has been initialized.)
    if (artworkProvider.artworks.isEmpty) {
      try {
        await artworkProvider.loadArtworks(refresh: true);
      } catch (_) {
        // ArtworkProvider reports its own errors; fall through.
      }
    }

    // Best-effort: ensure collaborator list is loaded so we can filter eligible artworks.
    // This is UX-only filtering; server enforces ownership.
    try {
      await collabProvider.loadCollaborators('exhibitions', exhibition.id);
    } catch (_) {
      // Provider handles error state.
    }

    if (!mounted) return;

    final members =
        collabProvider.collaboratorsFor('exhibitions', exhibition.id);
    final allowedUserIds =
        members.map((m) => m.userId.trim()).where((v) => v.isNotEmpty).toSet();
    final allowedWalletsLower = members
        .map((m) => (m.user?.walletAddress ?? '').trim().toLowerCase())
        .where((v) => v.isNotEmpty)
        .toSet();

    bool isMemberOwned(Artwork art) {
      final meta = art.metadata ?? const <String, dynamic>{};
      final creatorId =
          (meta['creatorId'] ?? meta['creator_id'])?.toString().trim();
      if (creatorId != null &&
          creatorId.isNotEmpty &&
          allowedUserIds.contains(creatorId)) {
        return true;
      }
      final wallet = (meta['walletAddress'] ?? meta['wallet_address'])
          ?.toString()
          .trim()
          .toLowerCase();
      if (wallet != null &&
          wallet.isNotEmpty &&
          allowedWalletsLower.contains(wallet)) {
        return true;
      }
      return false;
    }

    final artworks =
        List<Artwork>.from(artworkProvider.artworks.where(isMemberOwned));
    if (artworks.isEmpty) {
      if (mounted) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.exhibitionDetailNoArtworksAvailableToLinkToast,
                style: KubusTypography.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selectedIds = <String>{};

    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return KubusAlertDialog(
              title: Text(l10n.exhibitionDetailAddArtworksDialogTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: artworks.length,
                  itemBuilder: (context, index) {
                    final art = artworks[index];
                    final checked = selectedIds.contains(art.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            selectedIds.add(art.id);
                          } else {
                            selectedIds.remove(art.id);
                          }
                        });
                      },
                      title: Text(
                        art.title,
                        style:
                            KubusTypography.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        art.artist.isNotEmpty ? art.artist : '\u2014',
                        style: KubusTypography.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.75)),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child:
                      Text(l10n.commonCancel, style: KubusTypography.inter()),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonLink,
                      style:
                          KubusTypography.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await exhibitionsProvider.linkExhibitionArtworks(
          exhibition.id, selectedIds.toList());
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailArtworksLinkedToast,
              style: KubusTypography.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailLinkArtworksFailedToast,
              style: KubusTypography.inter()),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openEvent(KubusEvent event) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: event.title,
          child: EventDetailScreen(eventId: event.id, initialEvent: event),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(eventId: event.id, initialEvent: event),
      ),
    );
  }

  Future<void> _showLinkEventsDialog(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final eventsProvider = context.read<EventsProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();

    if (!eventsProvider.initialized) {
      try {
        await eventsProvider.initialize();
      } catch (_) {
        // Provider reports its own errors; fall through to what we have.
      }
    }
    if (!mounted) return;

    bool canManageEvent(KubusEvent event) {
      final role = (event.myRole ?? '').trim().toLowerCase();
      return role == 'owner' ||
          role == 'admin' ||
          role == 'publisher' ||
          role == 'editor' ||
          role == 'curator';
    }

    final alreadyLinked = exhibitionsProvider
        .programEventsFor(exhibition.id)
        .map((e) => e.id)
        .toSet();
    final candidates = eventsProvider.events
        .where((e) => canManageEvent(e) && !alreadyLinked.contains(e.id))
        .toList();

    if (candidates.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionCreatorNoEventsToLink)),
      );
      return;
    }

    final selectedIds = <String>{};
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return KubusAlertDialog(
              title: Text(l10n.selectEventsDialogTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final event = candidates[index];
                    final checked = selectedIds.contains(event.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            selectedIds.add(event.id);
                          } else {
                            selectedIds.remove(event.id);
                          }
                        });
                      },
                      title: Text(
                        event.title,
                        style:
                            KubusTypography.inter(fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child:
                      Text(l10n.commonCancel, style: KubusTypography.inter()),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonLink,
                      style:
                          KubusTypography.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedIds.isEmpty) return;

    try {
      await exhibitionsProvider.linkExhibitionEvents(
          exhibition.id, selectedIds.toList());
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
        tone: KubusSnackBarTone.success,
      );
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(e.userMessage)),
        tone: KubusSnackBarTone.error,
      );
    } catch (e) {
      debugPrint('ExhibitionDetailScreen: link events failed: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _unlinkProgramEvent(
      Exhibition exhibition, KubusEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();
    try {
      await provider.unlinkExhibitionEvent(exhibition.id, event.id);
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (e) {
      debugPrint('ExhibitionDetailScreen: unlink event failed: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _createProgramEvent(Exhibition exhibition) async {
    await CreatorShellNavigation.openEventCreatorWorkspace(context);
    if (!mounted) return;
    // Refresh in case the creator linked the new event to this exhibition.
    unawaited(
      context
          .read<ExhibitionsProvider>()
          .listExhibitionEvents(exhibition.id, refresh: true)
          .catchError((_) => const <KubusEvent>[]),
    );
  }

  Widget _buildAttendanceConfirmSection() {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return const SizedBox.shrink();
    }

    final markerIdCandidate = (widget.attendanceMarkerId ?? '').trim();
    if (markerIdCandidate.isEmpty) {
      return const SizedBox.shrink();
    }

    final isSignedIn = context.watch<ProfileProvider>().isSignedIn;
    if (!isSignedIn) {
      return const SizedBox.shrink();
    }

    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, _) {
        final state = attendanceProvider.stateFor(markerIdCandidate);
        final proximity = state.proximity;
        if (proximity == null || !state.canAttemptConfirm) {
          return const SizedBox.shrink();
        }

        if (state.challenge == null &&
            !state.isFetchingChallenge &&
            _prefetchedAttendanceMarkerId != markerIdCandidate) {
          _prefetchedAttendanceMarkerId = markerIdCandidate;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              attendanceProvider
                  .ensureChallenge(markerIdCandidate)
                  .catchError((_) => null),
            );
          });
        }

        final scheme = Theme.of(context).colorScheme;
        final alreadyAttended = state.challenge?.alreadyAttended == true;
        final isConfirming = state.isConfirming;

        final label = isConfirming
            ? l10n.exhibitionDetailAttendanceConfirmingAction
            : (alreadyAttended
                ? l10n.exhibitionDetailAttendanceAlreadyCheckedIn
                : l10n.exhibitionDetailAttendanceConfirmAction);
        final icon = isConfirming
            ? Icons.hourglass_top
            : (alreadyAttended ? Icons.check_circle : Icons.verified_user);

        return Column(
          children: [
            const SizedBox(height: DetailSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: DetailActionButton(
                    icon: icon,
                    label: label,
                    backgroundColor: alreadyAttended
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                        : scheme.primary,
                    foregroundColor: alreadyAttended
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimary,
                    onPressed: (alreadyAttended || isConfirming)
                        ? null
                        : () => unawaited(
                              _confirmAttendance(markerIdCandidate),
                            ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAttendance(String markerId) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final attendanceProvider = context.read<AttendanceProvider>();
    final state = attendanceProvider.stateFor(markerId);
    final proximity = state.proximity;

    if (proximity == null ||
        !state.hasFreshProximity ||
        !proximity.withinRadius) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.exhibitionDetailAttendanceMoveCloserHint),
        ),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    try {
      final result = await attendanceProvider.confirmAttendance(markerId);
      if (!mounted) return;

      if (result == null) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.exhibitionDetailAttendanceUnableToConfirmToast),
          ),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }

      final kub8 = result.kub8;
      final rawAmount = kub8?['awardedAmount'] ?? kub8?['awarded_amount'];
      final awarded = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse('${rawAmount ?? ''}');

      final wasIdempotent =
          result.attendanceRecorded != true && result.viewedAdded != true;
      final parts = <String>[
        wasIdempotent
            ? l10n.exhibitionDetailAttendanceAlreadyCheckedInToast
            : l10n.exhibitionDetailAttendanceConfirmedToast
      ];
      if (awarded != null && awarded > 0) {
        parts.add(
          l10n.exhibitionDetailAttendanceRewardPending(
            awarded.toStringAsFixed(awarded % 1 == 0 ? 0 : 1),
          ),
        );
      }

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(parts.join(' · ')),
          duration: const Duration(seconds: 4),
        ),
        tone: KubusSnackBarTone.success,
      );

      final exhibitionsProvider = context.read<ExhibitionsProvider>();
      final refreshedPoap = await exhibitionsProvider.fetchExhibitionPoap(
        widget.exhibitionId,
        force: true,
      );
      if (!mounted) return;
      if (refreshedPoap?.claimed != true && refreshedPoap?.canClaim == true) {
        unawaited(_claimExhibitionPoap());
      }
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      final message = e.statusCode == 403
          ? l10n.exhibitionDetailAttendanceMoveCloserHint
          : l10n.exhibitionDetailAttendanceUnableToConfirmToast;

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(message),
        ),
        tone: KubusSnackBarTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSomethingWentWrong)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ExhibitionsProvider>();
    final isSignedIn = context.watch<ProfileProvider>().isSignedIn;

    final ex = provider.exhibitions.firstWhere(
      (e) => e.id == widget.exhibitionId,
      orElse: () =>
          widget.initialExhibition ??
          Exhibition(id: widget.exhibitionId, title: l10n.commonExhibition),
    );

    final poap = provider.poapStatusFor(widget.exhibitionId);

    final canManage = _canManageExhibition(ex.myRole);
    final canPublish = _canPublishExhibition(ex.myRole);
    final canPromote = _canPromoteExhibition(ex);
    final headerActions = _buildHeaderActions(
      l10n,
      ex,
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(ex.title,
                  style: KubusTypography.inter(fontWeight: FontWeight.w600)),
              actions: const [],
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(DetailSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final topActions = Padding(
                  padding: const EdgeInsets.only(bottom: DetailSpacing.md),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 4,
                      children: [
                        ...headerActions,
                        IconButton(
                          tooltip: l10n.commonActions,
                          onPressed: () => _showExhibitionManagementActions(
                            ex,
                            canManage: canManage,
                            canPublish: canPublish,
                            canPromote: canPromote,
                          ),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ],
                    ),
                  ),
                );

                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExhibitionDetailsCard(
                      exhibition: ex,
                      poap: poap,
                      isSignedIn: isSignedIn,
                      isClaimingPoap: _isClaimingPoap,
                      isPoapLoading: provider.isPoapLoading,
                      canManage: canManage,
                      onClaimPoap:
                          poap?.claimed == true ? null : _claimExhibitionPoap,
                      showAttendanceHint:
                          (widget.attendanceMarkerId ?? '').trim().isNotEmpty,
                    ),
                    _buildAttendanceConfirmSection(),
                  ],
                );

                final artworksCard = DetailCard(
                  borderRadius: DetailRadius.md,
                  padding: DetailSpacing.editorialCardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: l10n.exhibitionDetailArtworksTitle,
                        trailing: null,
                      ),
                      const SizedBox(height: DetailSpacing.sm),
                      Text(
                        canManage
                            ? l10n.exhibitionDetailArtworksManageHint
                            : l10n.exhibitionDetailArtworksViewHint,
                        style: DetailTypography.caption(context),
                      ),
                      const SizedBox(height: DetailSpacing.lg),
                      _LinkedArtworksList(exhibition: ex),
                    ],
                  ),
                );

                final programCard = _ProgramSection(
                  exhibition: ex,
                  canManage: canManage,
                  onOpenEvent: _openEvent,
                  onLinkEvent: () => _showLinkEventsDialog(ex),
                  onCreateEvent: () => _createProgramEvent(ex),
                  onUnlinkEvent: (event) => _unlinkProgramEvent(ex, event),
                );

                final collab = CollaborationPanel(
                  entityType: 'exhibitions',
                  entityId: widget.exhibitionId,
                  myRole: ex.myRole,
                );

                if (isWide) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  topActions,
                                  details,
                                  const SizedBox(height: DetailSpacing.cardGap),
                                  programCard,
                                  const SizedBox(height: DetailSpacing.cardGap),
                                  artworksCard,
                                ],
                              ),
                            ),
                            const SizedBox(width: DetailSpacing.xl),
                            Expanded(
                              flex: 3,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 380),
                                child: collab,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.isDetailLoading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: InlineLoading(height: 4, borderRadius: BorderRadius.circular(2), color: scheme.primary),
                        ),
                    ],
                  );
                }

                return ListView(
                  children: [
                    topActions,
                    details,
                    const SizedBox(height: DetailSpacing.cardGap),
                    programCard,
                    const SizedBox(height: DetailSpacing.cardGap),
                    artworksCard,
                    const SizedBox(height: DetailSpacing.cardGap),
                    collab,
                    if (provider.isDetailLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: DetailSpacing.lg),
                        child: InlineLoading(height: 4, borderRadius: BorderRadius.circular(2), color: scheme.primary),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedArtworksList extends StatefulWidget {
  const _LinkedArtworksList({required this.exhibition});

  final Exhibition exhibition;

  @override
  State<_LinkedArtworksList> createState() => _LinkedArtworksListState();
}

class _LinkedArtworksListState extends State<_LinkedArtworksList> {
  final Set<String> _requested = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchMissingArtworks();
    });
  }

  @override
  void didUpdateWidget(covariant _LinkedArtworksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exhibition.id != widget.exhibition.id) {
      _requested.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchMissingArtworks();
    });
  }

  void _prefetchMissingArtworks() {
    final provider = context.read<ArtworkProvider>();
    for (final rawId in widget.exhibition.artworkIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      if (_requested.contains(id)) continue;
      if (provider.getArtworkById(id) != null) continue;
      _requested.add(id);
      unawaited(provider.fetchArtworkIfNeeded(id).catchError((_) => null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final artworkProvider = context.watch<ArtworkProvider>();

    final ids = widget.exhibition.artworkIds;
    if (ids.isEmpty) {
      return Text(
        l10n.exhibitionDetailNoArtworksLinkedYet,
        style: KubusTypography.inter(
          fontSize: 13,
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    final tiles = <Widget>[];
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      final art = artworkProvider.getArtworkById(id);
      final title = (art?.title ?? '').trim().isNotEmpty
          ? art!.title
          : l10n.commonUntitled;
      final subtitle = art?.artist.isNotEmpty == true ? art!.artist : id;
      final imageUrl = ArtworkMediaResolver.resolveCover(artwork: art);

      tiles.add(
        DetailArtworkCard(
          title: title,
          subtitle: subtitle,
          imageUrl: imageUrl,
          onTap: () {
            openArtwork(context, id, source: 'exhibition_detail');
          },
        ),
      );
      tiles.add(const SizedBox(height: DetailSpacing.lg));
    }

    if (tiles.isNotEmpty) tiles.removeLast();
    return Column(children: tiles);
  }
}

class _ExhibitionDetailsCard extends StatelessWidget {
  const _ExhibitionDetailsCard({
    required this.exhibition,
    required this.poap,
    required this.isSignedIn,
    required this.isClaimingPoap,
    required this.onClaimPoap,
    required this.showAttendanceHint,
    this.isPoapLoading = false,
    this.canManage = false,
  });

  final Exhibition exhibition;
  final ExhibitionPoapStatus? poap;
  final bool isSignedIn;
  final bool isClaimingPoap;
  final VoidCallback? onClaimPoap;
  final bool showAttendanceHint;
  final bool isPoapLoading;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);

    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final start =
          exhibition.startsAt != null ? _fmtDate(exhibition.startsAt!) : null;
      final end =
          exhibition.endsAt != null ? _fmtDate(exhibition.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' \u2192 ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final location = (exhibition.locationName ?? '').trim().isNotEmpty
        ? exhibition.locationName!.trim()
        : null;

    final hostName = exhibition.host == null
        ? null
        : (exhibition.host!.displayName ??
            exhibition.host!.username ??
            l10n.commonUnknown);
    final hostLabel =
        hostName == null ? null : l10n.exhibitionDetailHostedBy(hostName);

    List<DetailContextItem> buildPoapContextItems() {
      final items = <DetailContextItem>[];
      if (poap?.proofType?.trim().isNotEmpty == true) {
        items.add(
          DetailContextItem(
            icon: Icons.verified_outlined,
            value: l10n.exhibitionDetailPoapProofTypeMarkerAttendance,
          ),
        );
      }
      if ((poap?.linkedMarkerCount ?? 0) > 0) {
        items.add(
          DetailContextItem(
            icon: Icons.route_outlined,
            value: poap!.linkedMarkerCount.toString(),
            label: l10n.exhibitionDetailPoapLinkedMarkersLabel,
          ),
        );
      }
      if (poap?.latestAttendanceAt != null) {
        final latest = MaterialLocalizations.of(context)
            .formatMediumDate(poap!.latestAttendanceAt!.toLocal());
        items.add(
          DetailContextItem(
            icon: Icons.schedule_outlined,
            value: latest,
            label: l10n.exhibitionDetailPoapLatestCheckInLabel,
          ),
        );
      }
      return items;
    }

    String? poapEligibilityLabel() {
      if (poap == null) return null;
      if (poap!.claimed) {
        return l10n.exhibitionDetailPoapEligibilityClaimed;
      }
      if (poap!.canClaim) {
        return l10n.exhibitionDetailPoapEligibilityVerified;
      }
      switch ((poap!.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapEligibilitySignedOut;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublished;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkRequired;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceRequired;
        default:
          return l10n.exhibitionDetailPoapEligibilityVisitRequired;
      }
    }

    String? poapEligibilityHint() {
      if (poap == null || poap!.claimed) return null;
      if (poap!.canClaim) {
        return l10n.exhibitionDetailPoapEligibilityClaimReadyHint;
      }
      switch ((poap!.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapSignedOutHint;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublishedHint;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkHint;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceHint;
        default:
          return showAttendanceHint
              ? l10n.exhibitionDetailPoapAttendanceHint
              : null;
      }
    }

    // Editorial overview: identity, cover, key metadata and the context count
    // live together in one calm zone.
    final overviewCard = DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailIdentityBlock(
            title: exhibition.title,
            kicker: l10n.commonExhibition,
            subtitle: hostLabel,
            trailing: null,
          ),
          const SizedBox(height: DetailSpacing.heroGap),
          if (coverUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(DetailRadius.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined,
                        size: 48,
                        color: scheme.onSurface.withValues(alpha: 0.35)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DetailSpacing.heroGap),
          ],
          DetailMetadataBlock(
            items: [
              if (dateRange != null)
                DetailMetaItem(icon: Icons.schedule_outlined, label: dateRange),
              if (location != null)
                DetailMetaItem(icon: Icons.place_outlined, label: location),
              DetailMetaItem(
                icon: AppColorUtils.exhibitionIcon,
                label: l10n.exhibitionDetailStatusRowLabel(
                  _labelForStatus(l10n, exhibition.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: DetailSpacing.lg),
          DetailContextCluster(
            items: [
              DetailContextItem(
                icon: Icons.art_track,
                value: '${exhibition.artworkIds.length}',
                label: l10n.exhibitionDetailArtworksTitle,
              ),
            ],
            compact: true,
          ),
        ],
      ),
    );

    // Editorial description gets its own roomy card so long copy can expand
    // cleanly without crowding the overview metadata.
    final hasDescription = (exhibition.description ?? '').trim().isNotEmpty;
    final aboutCard = hasDescription
        ? DetailCard(
            borderRadius: DetailRadius.md,
            padding: DetailSpacing.editorialCardPadding,
            child: ExpandableDetailText(
              text: exhibition.description!.trim(),
            ),
          )
        : null;

    // POAP lives in its own section instead of being squeezed under the
    // identity block.
    Widget? poapCard;
    if (poap?.poap == null && isPoapLoading) {
      poapCard = const DetailCard(
        borderRadius: DetailRadius.md,
        padding: DetailSpacing.editorialCardPadding,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: InlineLoading(tileSize: 4),
          ),
        ),
      );
    } else if (poap?.poap == null && canManage) {
      poapCard = DetailCard(
        borderRadius: DetailRadius.md,
        padding: DetailSpacing.editorialCardPadding,
        child: Row(
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 20, color: scheme.onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: DetailSpacing.md),
            Expanded(
              child: Text(
                l10n.exhibitionDetailPoapNoneConfiguredOwnerHint,
                style: DetailTypography.caption(context),
              ),
            ),
          ],
        ),
      );
    } else if (poap?.poap != null) {
      poapCard = DetailCard(
        borderRadius: DetailRadius.md,
        padding: DetailSpacing.editorialCardPadding,
        child: PoapDetailCard(
          title: l10n.exhibitionDetailPoapTitle,
          description: poap!.poap.description?.trim().isNotEmpty == true
              ? poap!.poap.description!.trim()
              : l10n.exhibitionDetailPoapDescription,
          code: poap!.poap.code,
          iconUrl: poap!.poap.iconUrl,
          rarityLabel: poap!.poap.rarity,
          rewardLabel: poap!.poap.rewardKub8 > 0
              ? '+${poap!.poap.rewardKub8} KUB8'
              : null,
          stateLabel: poap!.claimed
              ? l10n.exhibitionDetailPoapClaimedStatus
              : l10n.exhibitionDetailPoapNotClaimedStatus,
          eligibilityLabel: poapEligibilityLabel(),
          eligibilityHint: poapEligibilityHint(),
          signedOutHint:
              isSignedIn ? null : l10n.exhibitionDetailPoapSignedOutHint,
          contextItems: buildPoapContextItems(),
          isClaimed: poap!.claimed,
          canClaim: !poap!.claimed && poap!.canClaim && isSignedIn,
          isClaiming: isClaimingPoap,
          onClaim: onClaimPoap,
          claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
          claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        overviewCard,
        if (aboutCard != null) ...[
          const SizedBox(height: DetailSpacing.cardGap),
          aboutCard,
        ],
        if (poapCard != null) ...[
          const SizedBox(height: DetailSpacing.cardGap),
          poapCard,
        ],
      ],
    );
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _labelForStatus(AppLocalizations l10n, String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return l10n.commonUnknown;
    if (v == 'published') return l10n.commonPublished;
    if (v == 'draft') return l10n.commonDraft;
    return v;
  }
}

String localizedEventRelationTypeLabel(AppLocalizations l10n, String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'opening':
      return l10n.eventRelationTypeOpening;
    case 'artist_talk':
      return l10n.eventRelationTypeArtistTalk;
    case 'guided_tour':
      return l10n.eventRelationTypeGuidedTour;
    case 'workshop':
      return l10n.eventRelationTypeWorkshop;
    case 'performance':
      return l10n.eventRelationTypePerformance;
    case 'lecture':
      return l10n.eventRelationTypeLecture;
    case 'screening':
      return l10n.eventRelationTypeScreening;
    case 'other':
      return l10n.eventRelationTypeOther;
    case 'program':
    case 'legacy':
    default:
      return l10n.eventRelationTypeProgram;
  }
}

class _ProgramSection extends StatelessWidget {
  const _ProgramSection({
    required this.exhibition,
    required this.canManage,
    required this.onOpenEvent,
    required this.onLinkEvent,
    required this.onCreateEvent,
    required this.onUnlinkEvent,
  });

  final Exhibition exhibition;
  final bool canManage;
  final ValueChanged<KubusEvent> onOpenEvent;
  final VoidCallback onLinkEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<KubusEvent> onUnlinkEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ExhibitionsProvider>();
    final events = provider.programEventsFor(exhibition.id);
    final eventsProvider = context.watch<EventsProvider>();

    return DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: l10n.exhibitionDetailProgramTitle,
                  trailing: null,
                ),
              ),
              if (provider.isRelationSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: InlineLoading(tileSize: 4),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.lg),
          if (events.isEmpty)
            Text(
              l10n.exhibitionDetailProgramEmpty,
              style: DetailTypography.caption(context),
            )
          else
            ...events.expand((event) sync* {
              yield _ProgramEventCard(
                event: event,
                hasPoap: eventsProvider.poapStatusFor(event.id) != null,
                canManage: canManage,
                onOpen: () => onOpenEvent(event),
                onUnlink: () => onUnlinkEvent(event),
              );
              if (event != events.last) {
                yield const SizedBox(height: DetailSpacing.lg);
              }
            }),
          if (canManage) ...[
            const SizedBox(height: DetailSpacing.lg),
            Wrap(
              spacing: DetailSpacing.sm,
              runSpacing: DetailSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: onLinkEvent,
                  icon: const Icon(Icons.link_outlined, size: 18),
                  label: Text(l10n.exhibitionDetailProgramLinkEvent),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateEvent,
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: Text(l10n.exhibitionDetailProgramCreateEvent),
                ),
              ],
            ),
          ],
          if (events.isEmpty && !canManage)
            const SizedBox.shrink()
          else if (events.isNotEmpty && canManage) ...[
            const SizedBox(height: DetailSpacing.xs),
            Text(
              l10n.exhibitionDetailProgramManage,
              style: DetailTypography.caption(context).copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgramEventCard extends StatelessWidget {
  const _ProgramEventCard({
    required this.event,
    required this.hasPoap,
    required this.canManage,
    required this.onOpen,
    required this.onUnlink,
  });

  final KubusEvent event;
  final bool hasPoap;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    String? dateLabel;
    if (event.startsAt != null) {
      dateLabel = MaterialLocalizations.of(context)
          .formatMediumDate(event.startsAt!.toLocal());
    }
    final location = (event.locationName ?? '').trim();
    final statusLabel = (event.status ?? '').trim().toLowerCase() == 'published'
        ? l10n.commonPublished
        : ((event.status ?? '').trim().toLowerCase() == 'draft'
            ? l10n.commonDraft
            : null);

    return DetailCard(
      borderRadius: DetailRadius.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.lg,
        vertical: DetailSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: DetailTypography.cardTitle(context)),
                    const SizedBox(height: DetailSpacing.md),
                    Wrap(
                      spacing: DetailSpacing.md,
                      runSpacing: DetailSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          localizedEventRelationTypeLabel(
                              l10n, event.relationType),
                          style: DetailTypography.caption(context).copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dateLabel != null)
                          Text(dateLabel,
                              style: DetailTypography.caption(context)),
                        if (location.isNotEmpty)
                          Text(location,
                              style: DetailTypography.caption(context)),
                        if (statusLabel != null)
                          Text(statusLabel,
                              style: DetailTypography.caption(context)),
                        if (hasPoap)
                          Icon(Icons.confirmation_number_outlined,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.65)),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: l10n.exhibitionDetailProgramRemoveEvent,
                  onPressed: onUnlink,
                  icon: const Icon(Icons.link_off_outlined, size: 18),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(l10n.exhibitionDetailProgramOpenEvent),
            ),
          ),
        ],
      ),
    );
  }
}

// Remove old _InfoRow since we now use InfoRow from detail_shell_components
