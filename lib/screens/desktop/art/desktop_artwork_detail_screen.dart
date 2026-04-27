import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../models/artwork.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../config/config.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/map_data_controller.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../features/map/shared/map_screen_shared_helpers.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/artwork_gallery_view.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../../../widgets/detail/artwork_engagement_sections.dart';
import '../../web3/artist/artwork_ar_manager_screen.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../../widgets/map/dialogs/street_art_claims_dialog.dart';

class DesktopArtworkDetailScreen extends StatefulWidget {
  final String artworkId;
  final bool showAppBar;
  final String? attendanceMarkerId;

  const DesktopArtworkDetailScreen({
    super.key,
    required this.artworkId,
    this.showAppBar = false,
    this.attendanceMarkerId,
  });

  @override
  State<DesktopArtworkDetailScreen> createState() =>
      _DesktopArtworkDetailScreenState();
}

class _DesktopArtworkDetailScreenState
    extends State<DesktopArtworkDetailScreen> {
  final ArtworkCommentsPanelController _commentsPanelController =
      ArtworkCommentsPanelController();
  String? _prefetchedAttendanceMarkerId;
  bool _artworkLoading = true;
  String? _artworkError;
  bool _commentsSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadArtworkDetails();
      if (!mounted) return;
      context.read<ArtworkProvider>().incrementViewCount(widget.artworkId);
      context.read<ArtworkProvider>().loadComments(widget.artworkId);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadArtworkDetails() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<ArtworkProvider>();
    final existing = provider.getArtworkById(widget.artworkId);

    if (existing != null) {
      if (mounted) {
        setState(() {
          _artworkLoading = false;
          _artworkError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _artworkLoading = true;
        _artworkError = null;
      });
    }

    try {
      await provider.fetchArtworkIfNeeded(widget.artworkId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkError = l10n.artDetailLoadFailedMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _artworkLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer2<ArtworkProvider, ProfileProvider>(
      builder: (context, artworkProvider, profileProvider, child) {
        final artwork = artworkProvider.getArtworkById(widget.artworkId);
        final isSignedIn = profileProvider.isSignedIn;

        if (_artworkLoading) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title: KubusHeaderText(
                      title: l10n.artDetailLoadingTitle,
                      kind: KubusHeaderKind.screen,
                      compact: true,
                    ),
                  )
                : null,
            body: const Center(child: InlineLoading()),
          );
        }

        if (_artworkError != null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title: KubusHeaderText(
                      title: l10n.artDetailTitle,
                      kind: KubusHeaderKind.screen,
                      compact: true,
                    ),
                  )
                : null,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _artworkError!,
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadArtworkDetails,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          );
        }

        if (artwork == null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title: KubusHeaderText(
                      title: l10n.artworkNotFound,
                      kind: KubusHeaderKind.screen,
                      compact: true,
                    ),
                  )
                : null,
            body: Center(
              child: Text(
                l10n.artworkNotFound,
                style: KubusTextStyles.screenTitle,
              ),
            ),
          );
        }

        final coverUrl = ArtworkMediaResolver.resolveCover(
          artwork: artwork,
          metadata: artwork.metadata,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.showAppBar
              ? AppBar(
                  title: KubusHeaderText(
                    title: artwork.title,
                    kind: KubusHeaderKind.screen,
                    compact: true,
                  ),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.all(DetailSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showTwoColumns = constraints.maxWidth >= 900;
                if (showTwoColumns) {
                  final sidePanelWidth =
                      (constraints.maxWidth * 0.34).clamp(332.0, 430.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildLeftPane(
                          artwork: artwork,
                          coverUrl: coverUrl,
                          artworkProvider: artworkProvider,
                          isSignedIn: isSignedIn,
                        ),
                      ),
                      const SizedBox(width: DetailSpacing.lg),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: _commentsSidebarExpanded ? sidePanelWidth : 72,
                        child: _commentsSidebarExpanded
                            ? _buildDesktopSidePanel(
                                artwork,
                                artworkProvider,
                                isSignedIn,
                                onToggleVisibility: () {
                                  setState(() {
                                    _commentsSidebarExpanded = false;
                                  });
                                },
                              )
                            : _buildCommentsSidebarToggleButton(),
                      ),
                    ],
                  );
                }

                final commentsHeight =
                    (constraints.maxHeight * 0.55).clamp(360.0, 560.0);
                return Column(
                  children: [
                    Expanded(
                      child: _buildLeftPane(
                        artwork: artwork,
                        coverUrl: coverUrl,
                        artworkProvider: artworkProvider,
                        isSignedIn: isSignedIn,
                      ),
                    ),
                    const SizedBox(height: DetailSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: commentsHeight,
                        width: double.infinity,
                        child: ArtworkCommentsExpandableCard(
                          artwork: artwork,
                          isSignedIn: isSignedIn,
                          controller: _commentsPanelController,
                          layoutMode: ArtworkCommentsLayoutMode.fill,
                          signInArguments: {
                            'redirectRoute': '/artwork',
                            'redirectArguments': {
                              'artworkId': artwork.id,
                              'attendanceMarkerId': widget.attendanceMarkerId ??
                                  artwork.arMarkerId,
                            },
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPane({
    required Artwork artwork,
    required String? coverUrl,
    required ArtworkProvider artworkProvider,
    required bool isSignedIn,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      children: [
        _buildMedia(artwork, coverUrl),
        const SizedBox(height: DetailSpacing.lg),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(artwork),
              const SizedBox(height: DetailSpacing.md),
              DetailSectionLabel(label: l10n.commonDetails),
              DetailContextCluster(
                compact: true,
                items: [
                  DetailContextItem(
                    icon: Icons.visibility,
                    value: '${artwork.viewsCount}',
                  ),
                  if (artwork.discoveryCount > 0)
                    DetailContextItem(
                      icon: Icons.explore,
                      value: '${artwork.discoveryCount}',
                    ),
                  if (artwork.actualRewards > 0)
                    DetailContextItem(
                      icon: Icons.token,
                      value: '${artwork.actualRewards}',
                      label: 'KUB8',
                    ),
                ],
              ),
              const SizedBox(height: DetailSpacing.lg),
              _buildActionsRow(artwork, artworkProvider, isSignedIn),
            ],
          ),
        ),
        _buildGallerySection(artwork, coverUrl),
        _buildAttendanceConfirmSection(
            artwork: artwork, isSignedIn: isSignedIn),
        _buildArSetupSection(artwork),
        _buildDescription(artwork),
        _buildPoapInfoCard(artwork),
      ],
    );
  }

  Widget _buildMedia(Artwork artwork, String? coverUrl) {
    final scheme = Theme.of(context).colorScheme;
    final primaryCover = <String>[
      if (coverUrl != null && coverUrl.trim().isNotEmpty) coverUrl.trim(),
      ...artwork.galleryUrls.map((u) => u.trim()).where((u) => u.isNotEmpty),
    ].firstWhere(
      (url) => url.isNotEmpty,
      orElse: () => '',
    );

    if (primaryCover.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: AspectRatio(
          aspectRatio: 14 / 9,
          child: Container(
            color: scheme.surfaceContainerHighest,
            child:
                Icon(Icons.image_not_supported, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tunedCoverHeight =
            (constraints.maxWidth / (14 / 9)).clamp(220.0, 320.0).toDouble();
        return ArtworkGalleryView(
          imageUrls: [primaryCover],
          height: tunedCoverHeight,
        );
      },
    );
  }

  Widget _buildGallerySection(Artwork artwork, String? coverUrl) {
    final l10n = AppLocalizations.of(context)!;
    final normalizedCover = (coverUrl ?? '').trim();
    final urls = artwork.galleryUrls
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && u != normalizedCover)
        .toList(growable: false);

    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: DetailSpacing.lg),
      child: DetailCard(
        child: DetailSection(
          title: l10n.artistStudioTabGallery,
          collapsible: true,
          initiallyExpanded: true,
          child: Padding(
            padding: const EdgeInsets.only(top: DetailSpacing.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final galleryHeight =
                    (constraints.maxWidth / 1.9).clamp(180.0, 260.0).toDouble();
                return ArtworkGalleryView(
                  imageUrls: urls,
                  height: galleryHeight,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidePanel(
    Artwork artwork,
    ArtworkProvider provider,
    bool isSignedIn, {
    VoidCallback? onToggleVisibility,
  }) {
    final showCollaboration =
        AppConfig.isFeatureEnabled('collabInvites') && isSignedIn;

    return Column(
      children: [
        if (showCollaboration) ...[
          ArtworkCollaboratorsExpandableCard(
            artwork: artwork,
            initiallyExpanded: false,
          ),
          const SizedBox(height: DetailSpacing.md),
        ],
        Expanded(
          child: ArtworkCommentsExpandableCard(
            artwork: artwork,
            isSignedIn: isSignedIn,
            controller: _commentsPanelController,
            onClose: onToggleVisibility,
            layoutMode: ArtworkCommentsLayoutMode.fill,
            signInArguments: {
              'redirectRoute': '/artwork',
              'redirectArguments': {
                'artworkId': artwork.id,
                'attendanceMarkerId':
                    widget.attendanceMarkerId ?? artwork.arMarkerId,
              },
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArSetupSection(Artwork artwork) {
    if (!artwork.arEnabled) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final viewerWallet = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: walletProvider.currentWalletAddress,
      userId: profileProvider.currentUser?.id,
    );
    final ownerWallet = WalletUtils.canonical(artwork.walletAddress);
    final isOwner = viewerWallet.isNotEmpty &&
      ownerWallet.isNotEmpty &&
      WalletUtils.equals(viewerWallet, ownerWallet);

    String statusLabel() {
      switch (artwork.arStatus) {
        case ArtworkArStatus.ready:
          return 'AR ready';
        case ArtworkArStatus.draft:
          return 'AR draft';
        case ArtworkArStatus.error:
          return 'AR needs attention';
        case ArtworkArStatus.none:
          return 'AR not set';
      }
    }

    Color statusColor() {
      switch (artwork.arStatus) {
        case ArtworkArStatus.ready:
          return scheme.primary;
        case ArtworkArStatus.error:
          return scheme.error;
        case ArtworkArStatus.draft:
        case ArtworkArStatus.none:
          return scheme.outline;
      }
    }

    final color = statusColor();
    final ready = artwork.arStatus == ArtworkArStatus.ready;

    return Padding(
      padding: const EdgeInsets.only(top: DetailSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_in_ar_rounded, color: color),
                const SizedBox(width: KubusSpacing.sm),
                Text(l10n.mapMarkerLayerArExperience,
                  style: KubusTextStyles.sectionTitle),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.md,
                    vertical: KubusSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel(),
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.arModeScanDescription,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            if (ready)
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ar'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l10n.commonViewInAr),
              )
            else if (isOwner)
              OutlinedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ArtworkArManagerScreen(artworkId: artwork.id),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.commonOpen),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Artwork artwork) {
    final category = artwork.category.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailIdentityBlock(
          title: artwork.title,
          kicker:
              category.isNotEmpty && category != 'General' ? category : null,
        ),
        const SizedBox(height: DetailSpacing.sm),
        ArtworkCreatorByline(
          artwork: artwork,
          style: DetailTypography.caption(context),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildDescription(Artwork artwork) {
    final text = (artwork.description).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: DetailSpacing.lg),
      child: DetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Description'),
            const SizedBox(height: DetailSpacing.sm),
            Text(text, style: DetailTypography.body(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPoapInfoCard(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    final metadata = artwork.metadata;
    if (metadata == null) return const SizedBox.shrink();
    final raw = metadata['poap'] ?? {};
    if (raw is! Map) return const SizedBox.shrink();

    final poap = Map<String, dynamic>.from(raw);
    final enabled = poap['enabled'] == true ||
        poap['poapEnabled'] == true ||
        poap['poap_enabled'] == true;
    final eventId = (poap['eventId'] ?? poap['poapEventId'] ?? poap['event_id'])
        ?.toString()
        .trim();
    final claimUrl =
        (poap['claimUrl'] ?? poap['poapClaimUrl'] ?? poap['claim_url'])
            ?.toString()
            .trim();
    final rewardAmount = poap['rewardAmount'] ?? poap['poapRewardAmount'];
    final validFromRaw =
        (poap['validFrom'] ?? poap['poapValidFrom'])?.toString();
    final validToRaw = (poap['validTo'] ?? poap['poapValidTo'])?.toString();
    final validFrom =
        validFromRaw != null ? DateTime.tryParse(validFromRaw) : null;
    final validTo = validToRaw != null ? DateTime.tryParse(validToRaw) : null;

    final hasReference = (eventId != null && eventId.isNotEmpty) ||
        (claimUrl != null && claimUrl.isNotEmpty);
    if (!enabled && !hasReference) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final infoLines = <String>[
      l10n.exhibitionDetailPoapAttendanceHint,
      if (rewardAmount != null)
        l10n.exhibitionDetailAttendanceRewardPending(rewardAmount.toString()),
      if (validFrom != null || validTo != null)
        '${l10n.commonAvailable}: ${(validFrom != null) ? validFrom.toLocal().toIso8601String().split('T').first : '…'} → ${(validTo != null) ? validTo.toLocal().toIso8601String().split('T').first : '…'}',
      if (eventId != null && eventId.isNotEmpty) '${l10n.commonEvent}: $eventId',
    ];

    final uri = (claimUrl != null && claimUrl.isNotEmpty)
        ? Uri.tryParse(claimUrl)
        : null;
    final canOpenClaim =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return Padding(
      padding: const EdgeInsets.only(top: DetailSpacing.lg),
      child: DetailCard(
        padding: const EdgeInsets.all(KubusSpacing.md),
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.exhibitionDetailPoapTitle,
                style: KubusTextStyles.sectionTitle),
            const SizedBox(height: DetailSpacing.sm),
            Text(infoLines.join('\n'), style: DetailTypography.body(context)),
            if (canOpenClaim) ...[
              const SizedBox(height: DetailSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => unawaited(
                    launchUrl(uri, mode: LaunchMode.externalApplication),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.commonOpen),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow(
      Artwork artwork, ArtworkProvider artworkProvider, bool isSignedIn) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final canInteract = isSignedIn;
    final showArPrimaryAction =
        artwork.arEnabled && AppConfig.isFeatureEnabled('ar');

    final markerIdCandidate = (artwork.arMarkerId ?? '').toString().trim();
    final canShowStreetArtClaimCta =
        AppConfig.isFeatureEnabled('streetArtClaims') &&
            markerIdCandidate.isNotEmpty;

    Future<void> requireSignInToast() async {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast,
              style: KubusTypography.inter()),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return DetailActionsSection(
      title: l10n.commonActions,
      maxVisibleActions: 5,
      primaryAction: showArPrimaryAction
          ? SizedBox(
              width: double.infinity,
              child: DetailActionButton(
                icon: Icons.view_in_ar,
                label: l10n.commonViewInAr,
                onPressed: () => Navigator.pushNamed(context, '/ar'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : null,
      actions: [
        DetailSecondaryAction(
          icon: artwork.isLikedByCurrentUser
              ? Icons.favorite
              : Icons.favorite_border,
          label: '${artwork.likesCount}',
          onTap: canInteract
              ? () => artworkProvider.toggleLike(artwork.id)
              : requireSignInToast,
          isActive: artwork.isLikedByCurrentUser,
          activeColor: Theme.of(context).colorScheme.error,
          tooltip: l10n.commonLikes,
        ),
        DetailSecondaryAction(
          icon: artwork.isFavoriteByCurrentUser
              ? Icons.bookmark
              : Icons.bookmark_border,
          label: l10n.commonSave,
          onTap: canInteract
              ? () => artworkProvider.toggleArtworkSaved(artwork.id)
              : requireSignInToast,
          isActive: artwork.isFavoriteByCurrentUser,
          tooltip: l10n.commonSave,
        ),
        DetailSecondaryAction(
          icon: Icons.comment_outlined,
          label: '${artwork.commentsCount}',
          onTap: () {
            if (!_commentsSidebarExpanded &&
                MediaQuery.sizeOf(context).width >= 900) {
              setState(() {
                _commentsSidebarExpanded = true;
              });
            }
            _commentsPanelController.openAndScrollToTop();
          },
          tooltip: l10n.commonComments,
        ),
        DetailSecondaryAction(
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onTap: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.artwork(
                artworkId: artwork.id,
                title: artwork.title,
              ),
              sourceScreen: 'desktop_art_detail',
            );
          },
          tooltip: l10n.commonShare,
        ),
        if (canShowStreetArtClaimCta)
          DetailSecondaryAction(
            icon: Icons.fact_check_outlined,
            label: l10n.mapMarkerClaimButton,
            onTap: () => unawaited(
              _openStreetArtClaimsForMarkerId(markerIdCandidate),
            ),
            tooltip: l10n.mapMarkerClaimButton,
          ),
      ],
    );
  }

  Future<void> _openStreetArtClaimsForMarkerId(String markerId) async {
    if (!AppConfig.isFeatureEnabled('streetArtClaims')) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final marker = await MapDataController().getArtMarkerById(markerId);
    if (!mounted) return;

    if (marker == null ||
        !KubusMarkerOverlayHelpers.canOpenStreetArtClaims(marker)) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonNotAvailable)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    final isMarkerOwner = KubusMarkerOverlayHelpers.markerOwnedByCurrentUser(
      marker: marker,
      walletAddress: context.read<WalletProvider>().currentWalletAddress,
      currentUserId: context.read<ProfileProvider>().currentUser?.id,
    );

    await StreetArtClaimsDialog.show(
      context: context,
      marker: marker,
      isMarkerOwner: isMarkerOwner,
      canUseDaoReviewActions: false,
    );
  }

  Widget _buildAttendanceConfirmSection({
    required Artwork artwork,
    required bool isSignedIn,
  }) {
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return const SizedBox.shrink();
    }

    if (!isSignedIn) {
      return const SizedBox.shrink();
    }

    final markerIdCandidate =
        (widget.attendanceMarkerId ?? artwork.arMarkerId)?.toString().trim();
    if (markerIdCandidate == null || markerIdCandidate.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

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

        return Padding(
          padding: const EdgeInsets.only(top: DetailSpacing.md),
          child: DetailActionButton(
            icon: icon,
            label: label,
            backgroundColor: alreadyAttended
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : scheme.primary,
            foregroundColor:
                alreadyAttended ? scheme.onSurfaceVariant : scheme.onPrimary,
            onPressed: (alreadyAttended || isConfirming)
                ? null
                : () => unawaited(
                      _confirmAttendance(
                        markerId: markerIdCandidate,
                        artwork: artwork,
                      ),
                    ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAttendance({
    required String markerId,
    required Artwork artwork,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final attendanceProvider = context.read<AttendanceProvider>();
    final state = attendanceProvider.stateFor(markerId);
    final proximity = state.proximity;

    if (proximity == null ||
        !state.hasFreshProximity ||
        !proximity.withinRadius) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionDetailAttendanceMoveCloserHint)),
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
            content:
                Text(l10n.exhibitionDetailAttendanceUnableToConfirmToast),
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

      final poap = result.poap;
      final poapStatus = (poap?['status'] ?? '').toString().trim();
      final claimUrl =
          (poap?['claimUrl'] ?? poap?['claim_url'])?.toString().trim();

      final wasIdempotent =
          result.attendanceRecorded != true && result.viewedAdded != true;
      final parts = <String>[
        wasIdempotent
            ? l10n.exhibitionDetailAttendanceAlreadyCheckedIn
            : l10n.exhibitionDetailAttendanceConfirmedToast
      ];
      if (awarded != null && awarded > 0) {
        parts.add(l10n.exhibitionDetailAttendanceRewardPending(
          awarded.toStringAsFixed(awarded % 1 == 0 ? 0 : 1),
        ));
      }
      if (poapStatus.isNotEmpty &&
          poapStatus != 'none' &&
          poapStatus != 'not_configured') {
        parts.add('${l10n.exhibitionDetailPoapTitle}: $poapStatus');
      }

      SnackBarAction? action;
      if (claimUrl != null && claimUrl.isNotEmpty) {
        final uri = Uri.tryParse(claimUrl);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          action = SnackBarAction(
            label: l10n.exhibitionDetailPoapClaimAction,
            onPressed: () => unawaited(
              launchUrl(uri, mode: LaunchMode.externalApplication),
            ),
          );
        }
      }

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(parts.join(' · '), style: KubusTypography.inter()),
          action: action,
          duration: const Duration(seconds: 4),
        ),
        tone: KubusSnackBarTone.success,
      );

      unawaited(
        context
            .read<ArtworkProvider>()
            .refreshArtwork(artwork.id)
            .catchError((e) {
          AppConfig.debugPrint(
            'DesktopArtworkDetailScreen: refreshArtwork failed: $e',
          );
          return null;
        }),
      );
      final wallet = context.read<WalletProvider>().currentWalletAddress;
      if (wallet != null && wallet.trim().isNotEmpty) {
        unawaited(context.read<TaskProvider>().loadProgressFromBackend(wallet));
      }
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      final authRequired = e.statusCode == 401 || e.statusCode == 403;
      String? backendMessage;
      if (!authRequired) {
        try {
          final raw = (e.body ?? '').trim();
          if (raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final msg = (decoded['error'] ?? decoded['message'] ?? '')
                  .toString()
                  .trim();
              if (msg.isNotEmpty) backendMessage = msg;
            }
          }
        } catch (_) {
          // ignore
        }
      }

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            authRequired
                ? l10n.communityCommentAuthRequiredToast
                : (backendMessage ??
                    '${l10n.commonSomethingWentWrong} (${e.statusCode})'),
            style: KubusTypography.inter(),
          ),
          action: authRequired
              ? SnackBarAction(
                  label: l10n.commonSignIn,
                  onPressed: () {
                    navigator.pushNamed(
                      '/sign-in',
                      arguments: {
                        'redirectRoute': '/artwork',
                        'redirectArguments': {
                          'artworkId': artwork.id,
                          'attendanceMarkerId': markerId,
                        },
                      },
                    );
                  },
                )
              : null,
        ),
        tone:
            authRequired ? KubusSnackBarTone.warning : KubusSnackBarTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(l10n.commonSomethingWentWrong,
                style: KubusTypography.inter())),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Widget _buildCommentsSidebarToggleButton() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return DetailCard(
      padding: EdgeInsets.zero,
      borderRadius: DetailRadius.lg,
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: l10n.commonComments,
            child: InkWell(
              borderRadius: BorderRadius.circular(DetailRadius.lg),
              onTap: () {
                setState(() {
                  _commentsSidebarExpanded = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DetailSpacing.xs,
                  vertical: DetailSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      color: scheme.onSurface,
                    ),
                    const SizedBox(height: DetailSpacing.xs),
                    Text(
                      l10n.commonComments,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DetailTypography.label(context).copyWith(
                        fontSize: KubusHeaderMetrics.sectionSubtitle - 3,
                        color: scheme.onSurfaceVariant,
                      ),
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
