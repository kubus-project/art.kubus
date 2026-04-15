import 'dart:convert';
import 'dart:async';
import 'package:art_kubus/widgets/glass_components.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../models/artwork.dart';
import '../../../models/artwork_comment.dart';
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
import '../../../utils/wallet_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/artwork_gallery_view.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/detail/detail_shell_components.dart';
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
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  late final ScrollController _commentsScrollController;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  String? _prefetchedAttendanceMarkerId;
  bool _artworkLoading = true;
  String? _artworkError;
  bool _commentsSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    _commentsScrollController = ScrollController();

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
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentsScrollController.dispose();
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
                      (constraints.maxWidth * 0.34).clamp(320.0, 420.0);
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
                        width: _commentsSidebarExpanded ? sidePanelWidth : 54,
                        child: _commentsSidebarExpanded
                            ? _buildCommentsPanel(
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
                        child: _buildCommentsPanel(
                          artwork,
                          artworkProvider,
                          isSignedIn,
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
              DetailContextCluster(
                compact: true,
                items: [
                  DetailContextItem(
                    icon: Icons.favorite,
                    value: '${artwork.likesCount}',
                  ),
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
              const SizedBox(height: DetailSpacing.md),
              _buildActionsRow(artwork, artworkProvider, isSignedIn),
            ],
          ),
        ),
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
    final urls = <String>[
      if (coverUrl != null && coverUrl.trim().isNotEmpty) coverUrl.trim(),
      ...artwork.galleryUrls.map((u) => u.trim()).where((u) => u.isNotEmpty),
    ];

    final seen = <String>{};
    final unique = <String>[];
    for (final url in urls) {
      if (seen.add(url)) unique.add(url);
    }

    if (unique.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: scheme.surfaceContainerHighest,
            child:
                Icon(Icons.image_not_supported, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ArtworkGalleryView(imageUrls: unique, height: 320);
  }

  Widget _buildArSetupSection(Artwork artwork) {
    if (!artwork.arEnabled) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final currentWallet = profileProvider.currentUser?.walletAddress ??
        walletProvider.currentWalletAddress;
    final isOwner = (currentWallet != null &&
        (artwork.walletAddress ?? '').isNotEmpty &&
        currentWallet.toLowerCase() == artwork.walletAddress!.toLowerCase());

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
                Text('AR experience', style: KubusTextStyles.sectionTitle),
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
              'Print or share a marker so people can scan and unlock AR.',
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            if (ready)
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ar'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan AR'),
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
                label: const Text('Finish AR setup'),
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
          kicker: category.isNotEmpty && category != 'General'
              ? category
              : null,
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
    final metadata = artwork.metadata;
    if (metadata == null) return const SizedBox.shrink();
    final raw = metadata['poap'];
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
      'Claimable after attendance confirmation.',
      if (rewardAmount != null) 'Reward: $rewardAmount',
      if (validFrom != null || validTo != null)
        'Valid: ${(validFrom != null) ? validFrom.toLocal().toIso8601String().split('T').first : '…'} → ${(validTo != null) ? validTo.toLocal().toIso8601String().split('T').first : '…'}',
      if (eventId != null && eventId.isNotEmpty) 'Event ID: $eventId',
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
            Text('POAP', style: KubusTextStyles.sectionTitle),
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
                  label: const Text('Open claim link'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showArPrimaryAction) ...[
          SizedBox(
            width: double.infinity,
            child: DetailActionButton(
              icon: Icons.view_in_ar,
              label: l10n.commonViewInAr,
              onPressed: () => Navigator.pushNamed(context, '/ar'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: DetailSpacing.sm),
        ],
        DetailSecondaryActionCluster(
          maxVisible: 5,
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
                  ? () => artworkProvider.toggleFavorite(artwork.id)
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
                if (_commentsScrollController.hasClients) {
                  _commentsScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
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

    if (marker == null || !KubusMarkerOverlayHelpers.canOpenStreetArtClaims(marker)) {
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
            ? 'Confirming…'
            : (alreadyAttended ? 'Already checked in' : 'Confirm attendance');
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
        const SnackBar(content: Text('Move closer to confirm attendance.')),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    try {
      final result = await attendanceProvider.confirmAttendance(markerId);
      if (!mounted) return;

      if (result == null) {
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('Unable to confirm attendance.')),
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
        wasIdempotent ? 'Already checked in.' : 'Attendance confirmed.'
      ];
      if (awarded != null && awarded > 0) {
        parts.add(
            '+${awarded.toStringAsFixed(awarded % 1 == 0 ? 0 : 1)} KUB8 (pending)');
      }
      if (poapStatus.isNotEmpty &&
          poapStatus != 'none' &&
          poapStatus != 'not_configured') {
        parts.add('POAP: $poapStatus');
      }

      SnackBarAction? action;
      if (claimUrl != null && claimUrl.isNotEmpty) {
        final uri = Uri.tryParse(claimUrl);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          action = SnackBarAction(
            label: 'Claim POAP',
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
        child: Tooltip(
          message: l10n.commonComments,
          child: IconButton(
            onPressed: () {
              setState(() {
                _commentsSidebarExpanded = true;
              });
            },
            icon: Icon(
              Icons.comment_outlined,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsPanel(
    Artwork artwork,
    ArtworkProvider provider,
    bool isSignedIn, {
    VoidCallback? onToggleVisibility,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final comments = provider.getComments(artwork.id);
    final isLoading = provider.isLoading('load_comments_${artwork.id}');
    final loadError = provider.commentLoadError(artwork.id);

    return DetailCard(
      padding: EdgeInsets.zero,
      borderRadius: DetailRadius.lg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DetailSpacing.lg, 14, DetailSpacing.lg, DetailSpacing.md),
            child: Row(
              children: [
                Text(
                  '${l10n.commonComments} (${artwork.commentsCount})',
                  style: DetailTypography.sectionTitle(context),
                ),
                const Spacer(),
                if (onToggleVisibility != null)
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: onToggleVisibility,
                    icon: const Icon(Icons.chevron_right),
                  ),
                IconButton(
                  tooltip: l10n.commonRefresh,
                  onPressed: () =>
                      provider.loadComments(artwork.id, force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Divider(
              height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
          Expanded(
            child: isLoading
                ? const Center(child: InlineLoading())
                : (loadError != null)
                    ? _buildCommentsError(loadError,
                        onRetry: () =>
                            provider.loadComments(artwork.id, force: true))
                    : (comments.isEmpty)
                        ? _buildCommentsEmpty()
                        : ListView(
                            controller: _commentsScrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: DetailSpacing.lg,
                                vertical: DetailSpacing.md),
                            children: [
                              for (final c in comments) ...[
                                ..._buildCommentTreeWidgets(
                                  artwork: artwork,
                                  comment: c,
                                  provider: provider,
                                  depth: 0,
                                ),
                              ],
                            ],
                          ),
          ),
          Divider(
              height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _buildCommentComposer(artwork, provider, isSignedIn),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsEmpty() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.postDetailNoCommentsTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.postDetailNoCommentsDescription,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsError(String message, {required VoidCallback onRetry}) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCommentTreeWidgets({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final widgets = <Widget>[
      _buildCommentTile(
        artwork: artwork,
        comment: comment,
        provider: provider,
        depth: depth,
      ),
      const SizedBox(height: DetailSpacing.md),
    ];

    for (final r in comment.replies) {
      widgets.addAll(
        _buildCommentTreeWidgets(
          artwork: artwork,
          comment: r,
          provider: provider,
          depth: depth + 1,
        ),
      );
    }

    return widgets;
  }

  Widget _buildCommentTile({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profile = context.read<ProfileProvider>().currentUser;
    final walletProvider = context.read<WalletProvider>();

    final currentWallet = WalletUtils.canonical(
      (profile?.walletAddress ?? walletProvider.currentWalletAddress ?? '')
          .toString(),
    );
    final currentId = WalletUtils.canonical((profile?.id ?? '').toString());
    final authorKey = WalletUtils.canonical(comment.userId);
    final canModify = authorKey.isNotEmpty &&
        (authorKey == currentWallet ||
            (currentId.isNotEmpty && authorKey == currentId));

    Future<void> showHistory() async {
      if (!comment.isEdited || comment.originalContent == null) return;
      await showKubusDialog<void>(
        context: context,
        builder: (dialogContext) {
          return KubusAlertDialog(
            title: Text(l10n.commentHistoryTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commentHistoryCurrentLabel,
                    style: KubusTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    comment.content,
                    style: KubusTextStyles.detailBody,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.commentHistoryOriginalLabel,
                    style: KubusTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    comment.originalContent ?? '',
                    style: KubusTextStyles.detailBody,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          );
        },
      );
    }

    Future<void> promptEdit() async {
      final messenger = ScaffoldMessenger.of(context);
      final controller = TextEditingController(text: comment.content);
      bool saving = false;
      await showKubusDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return KubusAlertDialog(
                title: Text(l10n.commentEditTitle),
                content: TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: l10n.postDetailWriteCommentHint),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final next = controller.text.trim();
                            if (next.isEmpty) return;
                            setDialogState(() => saving = true);
                            try {
                              await provider.editArtworkComment(
                                artworkId: artwork.id,
                                commentId: comment.id,
                                content: next,
                              );
                              if (!mounted) return;
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              messenger.showKubusSnackBar(SnackBar(
                                  content: Text(l10n.commentUpdatedToast)));
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showKubusSnackBar(
                                SnackBar(
                                  content: Text(l10n.commentEditFailedToast),
                                  backgroundColor: scheme.errorContainer,
                                ),
                              );
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                    child: Text(l10n.commonSave),
                  ),
                ],
              );
            },
          );
        },
      );
      controller.dispose();
    }

    Future<void> promptDelete() async {
      final messenger = ScaffoldMessenger.of(context);
      final confirmed = await showKubusDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return KubusAlertDialog(
            title: Text(l10n.commentDeleteConfirmTitle),
            content: Text(l10n.commentDeleteConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      try {
        await provider.deleteArtworkComment(
            artworkId: artwork.id, commentId: comment.id);
        if (!mounted) return;
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commentDeletedToast)));
      } catch (_) {
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.commentDeleteFailedToast),
            backgroundColor: scheme.errorContainer,
          ),
        );
      }
    }

    final isReply = depth > 0;

    return Padding(
      padding: EdgeInsets.only(left: depth * 48.0),
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(
              avatarUrl: comment.userAvatarUrl,
              wallet: comment.userId,
              radius: isReply ? 14 : 18,
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName,
                          style: KubusTextStyles.actionTileTitle.copyWith(
                            fontSize: KubusHeaderMetrics.sectionSubtitle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Text(
                        comment.timeAgo,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (comment.isEdited) ...[
                        const SizedBox(width: 8),
                        Text(
                          l10n.commonEditedTag,
                          style: KubusTextStyles.compactBadge.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      if (canModify)
                        PopupMenuButton<String>(
                          tooltip: l10n.commonMore,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await promptEdit();
                            } else if (value == 'delete') {
                              await promptDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                                value: 'edit', child: Text(l10n.commonEdit)),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.commonDelete)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (comment.isEdited && comment.originalContent != null)
                        ? showHistory
                        : null,
                    child: Text(
                      comment.content,
                      style: KubusTextStyles.detailBody.copyWith(
                        fontSize: KubusHeaderMetrics.sectionSubtitle,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            provider.toggleCommentLike(artwork.id, comment.id),
                        icon: Icon(
                          comment.isLikedByCurrentUser
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: comment.isLikedByCurrentUser
                              ? scheme.error
                              : scheme.onSurface.withValues(alpha: 0.8),
                        ),
                        tooltip: l10n.commonLikes,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (comment.likesCount > 0)
                        Text(
                          comment.likesCount.toString(),
                          style: KubusTextStyles.navMetaLabel.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _replyToCommentId = comment.id;
                            _replyToAuthorName = comment.userName;
                          });
                          _commentController.text = '@${comment.userName} ';
                          _commentController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: _commentController.text.length),
                          );
                          FocusScope.of(context)
                              .requestFocus(_commentFocusNode);
                        },
                        child: Text(
                          l10n.commonReply,
                          style: KubusTextStyles.navMetaLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentComposer(
      Artwork artwork, ArtworkProvider provider, bool isSignedIn) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final isSubmitting = provider.isLoading('comment_${artwork.id}');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToAuthorName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.postDetailReplyingToLabel(_replyToAuthorName!),
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: () {
                    setState(() {
                      _replyToAuthorName = null;
                      _replyToCommentId = null;
                    });
                    _commentController.clear();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.artworkCommentAddHint,
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md)),
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => _submitComment(artwork, provider, isSignedIn),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm + KubusSpacing.xs,
                  vertical: KubusSpacing.sm + KubusSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          InlineLoading(shape: BoxShape.circle, tileSize: 3.5),
                    )
                  : Icon(Icons.send, size: 18, color: scheme.onPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitComment(
      Artwork artwork, ArtworkProvider provider, bool isSignedIn) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isSignedIn) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast,
              style: KubusTypography.inter()),
          action: SnackBarAction(
            label: l10n.commonSignIn,
            onPressed: () {
              navigator.pushNamed(
                '/sign-in',
                arguments: {
                  'redirectRoute': '/artwork',
                  'redirectArguments': {'artworkId': artwork.id},
                },
              );
            },
          ),
        ),
      );
      return;
    }

    final parentId = _replyToCommentId;
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });

    try {
      await provider.addComment(
        artworkId: artwork.id,
        content: content,
        parentCommentId: parentId,
      );
      if (!mounted) return;
      _commentController.clear();
      // With oldest-first ordering, new comments appear at the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_commentsScrollController.hasClients) {
          _commentsScrollController.animateTo(
            _commentsScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.artworkCommentAddedToast,
              style: KubusTypography.inter()),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
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
              if (msg.isNotEmpty) {
                backendMessage =
                    msg.length > 140 ? '${msg.substring(0, 140)}\u2026' : msg;
              }
            }
          }
        } catch (_) {
          // Ignore body parse failures and fall back to a generic message.
        }
      }
      backendMessage = backendMessage
          ?.replaceAll('\u00C3\u00A2\u00E2\u201A\u00AC\u00C2\u00A6', '\u2026')
          .replaceAll(
            '\u00C3\u0192\u00C2\u00A2\u00C3\u00A2\u20AC\u0161\u00C2\u00AC\u00C3\u201A\u00C2\u00A6',
            '\u2026',
          );
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
                        'redirectArguments': {'artworkId': artwork.id},
                      },
                    );
                  },
                )
              : null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(l10n.commonSomethingWentWrong,
                style: KubusTypography.inter())),
      );
    }
  }
}
