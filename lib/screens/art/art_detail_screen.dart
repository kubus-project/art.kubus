import 'dart:convert';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/artwork_creator_byline.dart';
import '../../widgets/detail/detail_shell_components.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/artwork.dart';
import '../../models/artwork_comment.dart';
import '../../services/backend_api_service.dart';
import '../../services/nft_minting_service.dart';
import '../../models/collectible.dart';
import '../../utils/app_animations.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/map_navigation.dart';
import '../../utils/artwork_edit_navigation.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/collaboration_panel.dart';
import '../../config/config.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
 

class ArtDetailScreen extends StatefulWidget {
  final String artworkId;
  final String? attendanceMarkerId;

  const ArtDetailScreen({
    super.key,
    required this.artworkId,
    this.attendanceMarkerId,
  });

  @override
  State<ArtDetailScreen> createState() => _ArtDetailScreenState();
}

class _ArtDetailScreenState extends State<ArtDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _commentController;
  late ScrollController _scrollController;
  bool _showComments = false;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  String? _prefetchedAttendanceMarkerId;
  bool _animationsInitialized = false;
  bool _artworkLoading = true;
  String? _artworkError;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Defer context-dependent work until after the first frame so inherited
    // widgets (localizations/theme) are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadArtworkDetails();
      context.read<ArtworkProvider>().incrementViewCount(widget.artworkId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_animationsInitialized) {
      final animationTheme = context.animationTheme;

      _animationController.duration = animationTheme.long;

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.fadeCurve,
      ));

      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.defaultCurve,
      ));

      _animationController.forward();
      _animationsInitialized = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer2<ArtworkProvider, ProfileProvider>(
      builder: (context, artworkProvider, profileProvider, child) {
        final artwork = artworkProvider.getArtworkById(widget.artworkId);
        final isSignedIn = profileProvider.isSignedIn;

        if (_artworkLoading) {
          return AnimatedGradientBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(
                  l10n.artDetailLoadingTitle,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
              ),
              body: const Center(child: InlineLoading()),
            ),
          );
        }

        if (_artworkError != null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text(l10n.artDetailTitle,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(DetailSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: DetailSpacing.lg),
                    Text(
                      _artworkError!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DetailSpacing.xl),
                    FilledButton.icon(
                      onPressed: _loadArtworkDetails,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.commonRetry,
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (artwork == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text(l10n.artworkNotFound,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(DetailSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: DetailSpacing.lg),
                    Text(
                      l10n.artworkNotFound,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AnimatedGradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildAppBar(artwork),
                        SliverPadding(
                          padding: const EdgeInsets.all(DetailSpacing.xl),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildArtInfo(artwork),
                              const SizedBox(height: DetailSpacing.xl),
                              _buildDescription(artwork),
                              const SizedBox(height: DetailSpacing.xl),
                              _buildSocialStats(artwork),
                              const SizedBox(height: DetailSpacing.xl),
                              _buildActionButtons(artwork),
                              const SizedBox(height: DetailSpacing.xl),
                              if (AppConfig.isFeatureEnabled('collabInvites')) ...[
                                CollaborationPanel(
                                  entityType: 'artworks',
                                  entityId: artwork.id,
                                ),
                                const SizedBox(height: DetailSpacing.xl),
                              ],
                              _buildCommentsSection(artwork, artworkProvider),
                              const SizedBox(height: 100), // Bottom padding
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            floatingActionButton:
                (_showComments && isSignedIn) ? _buildCommentFAB(artwork) : null,
          ),
        );
      },
    );
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
    } catch (e) {
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

  Widget _buildAppBar(Artwork artwork) {
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);

    return SliverAppBar(
      expandedHeight: 320,
      floating: false,
      pinned: true,
      backgroundColor: scheme.surface,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.artwork(artworkId: artwork.id, title: artwork.title),
              sourceScreen: 'art_detail',
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined),
          ),
        ),
        Consumer<ArtworkProvider>(
          builder: (context, provider, child) {
            return IconButton(
              onPressed: () => provider.toggleFavorite(artwork.id),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  artwork.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: artwork.isFavorite ? scheme.error : null,
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreviewCoverImage(coverUrl),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCoverImage(String? imageUrl) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = (imageUrl ?? '').trim();
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: scheme.outline.withValues(alpha: 0.8),
          size: 40,
        ),
      ),
    );

    if (resolved.isEmpty) {
      return placeholder;
    }

    return Image.network(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: InlineLoading(
              shape: BoxShape.circle,
              color: scheme.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtInfo(Artwork artwork) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          artwork.title,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: DetailSpacing.sm),
        ArtworkCreatorByline(
          artwork: artwork,
          style: DetailTypography.caption(context),
        ),
        const SizedBox(height: DetailSpacing.lg),
        Wrap(
          spacing: DetailSpacing.sm,
          runSpacing: DetailSpacing.sm,
          children: [
            _buildInfoChip(Icons.category_outlined, artwork.category),
            if (artwork.averageRating != null)
              _buildInfoChip(Icons.star_rounded,
                  '${artwork.averageRating?.toStringAsFixed(1)} (${artwork.ratingsCount})'),
            _buildInfoChip(Icons.schedule_outlined,
                artwork.createdAt.toString().split(' ')[0]),
          ],
        ),
        const SizedBox(height: DetailSpacing.lg),
        if (artwork.tags.isNotEmpty)
          Wrap(
            spacing: DetailSpacing.sm,
            runSpacing: DetailSpacing.sm,
            children: artwork.tags.map((tag) => _buildTag(tag)).toList(),
          ),
        _buildPoapInfoCard(artwork),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DetailSpacing.md, vertical: DetailSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DetailRadius.xl),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: DetailSpacing.xs),
          Text(label, style: DetailTypography.label(context)),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DetailSpacing.sm + 2, vertical: DetailSpacing.xs + 1),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DetailRadius.lg),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        '#$tag',
        style: DetailTypography.label(context).copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
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
    final validFromRaw = (poap['validFrom'] ?? poap['poapValidFrom'])?.toString();
    final validToRaw = (poap['validTo'] ?? poap['poapValidTo'])?.toString();
    final validFrom = validFromRaw != null ? DateTime.tryParse(validFromRaw) : null;
    final validTo = validToRaw != null ? DateTime.tryParse(validToRaw) : null;

    final hasReference =
        (eventId != null && eventId.isNotEmpty) || (claimUrl != null && claimUrl.isNotEmpty);
    if (!enabled && !hasReference) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final infoLines = <String>[
      'Claimable after attendance confirmation.',
      if (rewardAmount != null) 'Reward: $rewardAmount',
      if (validFrom != null || validTo != null)
        'Valid: ${(validFrom != null) ? validFrom.toLocal().toIso8601String().split('T').first : '…'} → ${(validTo != null) ? validTo.toLocal().toIso8601String().split('T').first : '…'}',
      if (eventId != null && eventId.isNotEmpty) 'Event ID: $eventId',
    ];

    final uri = (claimUrl != null && claimUrl.isNotEmpty) ? Uri.tryParse(claimUrl) : null;
    final canOpenClaim =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DetailSpacing.lg),
        DetailCard(
          padding: const EdgeInsets.all(DetailSpacing.md),
          backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POAP', style: DetailTypography.sectionTitle(context)),
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
      ],
    );
  }

  Widget _buildDescription(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.commonDescription,
            style: DetailTypography.sectionTitle(context)),
        const SizedBox(height: DetailSpacing.md),
        Text(artwork.description, style: DetailTypography.body(context)),
      ],
    );
  }

  Widget _buildSocialStats(Artwork artwork) {
    return DetailCard(
      padding: const EdgeInsets.symmetric(
          vertical: DetailSpacing.lg, horizontal: DetailSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.favorite_rounded, artwork.likesCount, 'Likes'),
          _buildStatDivider(),
          _buildStatItem(Icons.chat_bubble_outline_rounded,
              artwork.commentsCount, 'Comments'),
          _buildStatDivider(),
          _buildStatItem(
              Icons.visibility_outlined, artwork.viewsCount, 'Views'),
          _buildStatDivider(),
          _buildStatItem(
              Icons.explore_outlined, artwork.discoveryCount, 'Discoveries'),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 32,
      width: 1,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: scheme.primary.withValues(alpha: 0.8)),
        const SizedBox(height: DetailSpacing.xs),
        Text(
          count.toString(),
          style: DetailTypography.cardTitle(context),
        ),
        const SizedBox(height: 2),
        Text(label, style: DetailTypography.label(context)),
      ],
    );
  }

  Widget _buildActionButtons(Artwork artwork) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final currentWallet =
        profileProvider.currentUser?.walletAddress ?? walletProvider.currentWalletAddress;
    final isOwner = (currentWallet != null &&
        (artwork.walletAddress ?? '').isNotEmpty &&
        currentWallet.toLowerCase() == artwork.walletAddress!.toLowerCase());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer<ArtworkProvider>(
                builder: (context, provider, child) {
                  final isLiked = artwork.isLikedByCurrentUser;
                  return DetailActionButton(
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: isLiked
                        ? l10n.artworkDetailLiked
                        : l10n.artworkDetailLike,
                    isActive: isLiked,
                    activeColor: scheme.error,
                    onPressed: () => provider.toggleLike(artwork.id),
                  );
                },
              ),
            ),
            const SizedBox(width: DetailSpacing.md),
            Expanded(
              child: DetailActionButton(
                icon: _showComments
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                label: _showComments
                    ? l10n.artworkDetailHideComments
                    : l10n.commonComments,
                isActive: _showComments,
                activeColor: scheme.primary,
                onPressed: () {
                  setState(() {
                    _showComments = !_showComments;
                  });
                  if (_showComments) {
                    context
                        .read<ArtworkProvider>()
                        .loadComments(widget.artworkId);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: DetailSpacing.md),
        Row(
          children: [
            if (isOwner) ...[
              Expanded(
                child: DetailActionButton(
                  icon: Icons.edit_outlined,
                  label: l10n.commonEdit,
                  onPressed: () => openArtworkEditor(context, artwork.id, source: 'art_detail'),
                ),
              ),
              const SizedBox(width: DetailSpacing.md),
            ],
            Expanded(
              child: DetailActionButton(
                icon: artwork.isPublic ? Icons.visibility_off : Icons.publish_outlined,
                label: artwork.isPublic ? l10n.commonUnpublish : l10n.commonPublish,
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
                foregroundColor: scheme.primary,
                onPressed: !isOwner
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final provider = context.read<ArtworkProvider>();
                        try {
                          final updated = artwork.isPublic
                              ? await provider.unpublishArtwork(artwork.id)
                              : await provider.publishArtwork(artwork.id);
                          if (!mounted) return;
                          messenger.showKubusSnackBar(
                            SnackBar(
                              content: Text(
                                updated != null ? l10n.commonSavedToast : l10n.commonActionFailedToast,
                              ),
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          messenger.showKubusSnackBar(
                            SnackBar(content: Text(l10n.commonActionFailedToast)),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
        _buildAttendanceConfirmSection(artwork),
        Row(
          children: [
            if (artwork.arEnabled)
              Expanded(
                child: DetailActionButton(
                  icon: Icons.view_in_ar_rounded,
                  label: l10n.commonViewInAr,
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, '/ar'),
                ),
              ),
            if (artwork.arEnabled) const SizedBox(width: DetailSpacing.md),
            Expanded(
              child: DetailActionButton(
                icon: Icons.navigation_rounded,
                label: l10n.commonNavigate,
                backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.6),
                foregroundColor: scheme.onSecondaryContainer,
                onPressed: () => _showNavigationOptions(artwork),
              ),
            ),
          ],
        ),
        const SizedBox(height: DetailSpacing.md),
        SizedBox(
          width: double.infinity,
          child: DetailActionButton(
            icon: Icons.diamond_rounded,
            label: l10n.artworkDetailMintNft,
            backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.85),
            foregroundColor: scheme.onTertiaryContainer,
            onPressed: () => _showMintNFTDialog(artwork),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceConfirmSection(Artwork artwork) {
    if (!AppConfig.isFeatureEnabled('attendance')) {
      return const SizedBox(height: DetailSpacing.md);
    }

    final markerIdCandidate = (widget.attendanceMarkerId ?? artwork.arMarkerId)
        ?.toString()
        .trim();
    if (markerIdCandidate == null || markerIdCandidate.isEmpty) {
      return const SizedBox(height: DetailSpacing.md);
    }

    final isSignedIn = context.watch<ProfileProvider>().isSignedIn;
    if (!isSignedIn) {
      return const SizedBox(height: DetailSpacing.md);
    }

    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, _) {
        final state = attendanceProvider.stateFor(markerIdCandidate);
        final proximity = state.proximity;
        if (proximity == null || !state.canAttemptConfirm) {
          return const SizedBox(height: DetailSpacing.md);
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

        return Column(
          children: [
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
                              _confirmAttendance(
                                markerId: markerIdCandidate,
                                artwork: artwork,
                              ),
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DetailSpacing.md),
          ],
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

    if (proximity == null || !state.hasFreshProximity || !proximity.withinRadius) {
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
      final awarded = rawAmount is num ? rawAmount.toDouble() : double.tryParse('${rawAmount ?? ''}');

      final poap = result.poap;
      final poapStatus = (poap?['status'] ?? '').toString().trim();
      final claimUrl = (poap?['claimUrl'] ?? poap?['claim_url'])?.toString().trim();

      final wasIdempotent = result.attendanceRecorded != true && result.viewedAdded != true;
      final parts = <String>[wasIdempotent ? 'Already checked in.' : 'Attendance confirmed.'];
      if (awarded != null && awarded > 0) {
        parts.add('+${awarded.toStringAsFixed(awarded % 1 == 0 ? 0 : 1)} KUB8 (pending)');
      }
      if (poapStatus.isNotEmpty && poapStatus != 'none' && poapStatus != 'not_configured') {
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
          content: Text(parts.join(' · ')),
          action: action,
          duration: const Duration(seconds: 4),
        ),
        tone: KubusSnackBarTone.success,
      );

      unawaited(
        context.read<ArtworkProvider>().refreshArtwork(artwork.id).catchError((e) {
          AppConfig.debugPrint('ArtDetailScreen: refreshArtwork failed: $e');
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
              final msg = (decoded['error'] ?? decoded['message'] ?? '').toString().trim();
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
                : (backendMessage ?? '${l10n.commonSomethingWentWrong} (${e.statusCode})'),
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
        tone: authRequired ? KubusSnackBarTone.warning : KubusSnackBarTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSomethingWentWrong)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Widget _buildCommentsSection(Artwork artwork, ArtworkProvider provider) {
    if (!_showComments) return const SizedBox.shrink();

    final comments = provider.getComments(artwork.id);
    final isLoading = provider.isLoading('load_comments_${artwork.id}');
    final error = provider.commentLoadError(artwork.id);
    final isSignedIn = context.watch<ProfileProvider>().isSignedIn;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.commonComments} (${artwork.commentsCount})',
          style: DetailTypography.sectionTitle(context),
        ),
        const SizedBox(height: DetailSpacing.lg),
        if (error != null)
          DetailCard(
            padding: const EdgeInsets.all(DetailSpacing.md),
            child: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: DetailSpacing.sm),
                Expanded(
                  child: Text(error, style: DetailTypography.body(context)),
                ),
                TextButton(
                  onPressed: () =>
                      provider.loadComments(artwork.id, force: true),
                  child: Text(l10n.commonRetry,
                      style: DetailTypography.button(context)),
                ),
              ],
            ),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DetailSpacing.lg),
            child: Center(child: InlineLoading()),
          )
        else if (comments.isEmpty)
          DetailCard(
            padding: const EdgeInsets.all(DetailSpacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.postDetailNoCommentsTitle,
                    style: DetailTypography.cardTitle(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DetailSpacing.xs),
                  Text(
                    l10n.postDetailNoCommentsDescription,
                    style: DetailTypography.caption(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...comments.expand(
            (comment) => _buildCommentTree(
              artwork: artwork,
              comment: comment,
              provider: provider,
              depth: 0,
            ),
          ),
        const SizedBox(height: DetailSpacing.md),
        if (!isSignedIn)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pushNamed(
                  '/sign-in',
                  arguments: {
                    'redirectRoute': '/artwork',
                    'redirectArguments': {'artworkId': artwork.id},
                  },
                );
              },
              icon: const Icon(Icons.login),
              label: Text(l10n.commonSignIn,
                  style: DetailTypography.button(context)),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCommentTree({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final widgets = <Widget>[
      _buildCommentItem(
        artwork: artwork,
        comment: comment,
        provider: provider,
        depth: depth,
      ),
    ];

    for (final r in comment.replies) {
      widgets.addAll(
        _buildCommentTree(
          artwork: artwork,
          comment: r,
          provider: provider,
          depth: depth + 1,
        ),
      );
    }

    return widgets;
  }

  Widget _buildCommentItem({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currentUser = context.read<ProfileProvider>().currentUser;
    final walletProvider = context.read<WalletProvider>();
    final currentWallet = WalletUtils.canonical(
      (currentUser?.walletAddress ?? walletProvider.currentWalletAddress ?? '').toString(),
    );
    final currentId = WalletUtils.canonical((currentUser?.id ?? '').toString());
    final authorKey = WalletUtils.canonical(comment.userId);

    final canModify = authorKey.isNotEmpty &&
        (authorKey == currentWallet || (currentId.isNotEmpty && authorKey == currentId));

    final isReply = depth > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: depth * 56.0,
        bottom: DetailSpacing.md,
      ),
      child: DetailCard(
        padding: const EdgeInsets.all(DetailSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  avatarUrl: comment.userAvatarUrl,
                  wallet: comment.userId,
                  radius: isReply ? 12 : 16,
                  enableProfileNavigation: true,
                ),
                const SizedBox(width: DetailSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.userName,
                          style: DetailTypography.cardTitle(context)),
                      Row(
                        children: [
                          Text(comment.timeAgo,
                              style: DetailTypography.label(context)),
                          if (comment.isEdited) ...[
                            const SizedBox(width: DetailSpacing.sm),
                            Text(l10n.commonEditedTag,
                                style: DetailTypography.label(context)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  PopupMenuButton<String>(
                    tooltip: l10n.commonMore,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final controller =
                            TextEditingController(text: comment.content);
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
                                      hintText: l10n.postDetailWriteCommentHint,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: saving
                                          ? null
                                          : () =>
                                              Navigator.of(dialogContext).pop(),
                                      child: Text(l10n.commonCancel),
                                    ),
                                    FilledButton(
                                      onPressed: saving
                                          ? null
                                          : () async {
                                              final next =
                                                  controller.text.trim();
                                              if (next.isEmpty) return;
                                              setDialogState(
                                                  () => saving = true);
                                              try {
                                                await provider
                                                    .editArtworkComment(
                                                  artworkId: widget.artworkId,
                                                  commentId: comment.id,
                                                  content: next,
                                                );
                                                if (!mounted) return;
                                                if (!dialogContext.mounted) {
                                                  return;
                                                }
                                                Navigator.of(dialogContext)
                                                    .pop();
                                                messenger.showKubusSnackBar(
                                                  SnackBar(
                                                      content: Text(l10n
                                                          .commentUpdatedToast)),
                                                );
                                              } catch (_) {
                                                if (!mounted) return;
                                                messenger.showKubusSnackBar(
                                                  SnackBar(
                                                    content: Text(l10n
                                                        .commentEditFailedToast),
                                                    backgroundColor:
                                                        scheme.errorContainer,
                                                  ),
                                                );
                                              } finally {
                                                if (dialogContext.mounted) {
                                                  setDialogState(
                                                      () => saving = false);
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
                        if (!mounted) return;
                        navigator; // keep reference (no-op)
                      } else if (value == 'delete') {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirmed = await showKubusDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return KubusAlertDialog(
                              title: Text(l10n.commentDeleteConfirmTitle),
                              content: Text(l10n.commentDeleteConfirmMessage),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(l10n.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
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
                            artworkId: widget.artworkId,
                            commentId: comment.id,
                          );
                          if (!mounted) return;
                          messenger.showKubusSnackBar(
                            SnackBar(content: Text(l10n.commentDeletedToast)),
                          );
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
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.commonEdit),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
                IconButton(
                  onPressed: () =>
                      provider.toggleCommentLike(widget.artworkId, comment.id),
                  icon: Icon(
                    comment.isLikedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: comment.isLikedByCurrentUser ? scheme.error : null,
                  ),
                ),
                if (comment.likesCount > 0)
                  Text(
                    comment.likesCount.toString(),
                    style: DetailTypography.label(context),
                  ),
              ],
            ),
            const SizedBox(height: DetailSpacing.sm),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (comment.isEdited && comment.originalContent != null)
                  ? () {
                      showKubusDialog<void>(
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
                                    style: DetailTypography.cardTitle(context),
                                  ),
                                  const SizedBox(height: DetailSpacing.sm),
                                  SelectableText(
                                    comment.content,
                                    style: DetailTypography.body(context),
                                  ),
                                  const SizedBox(height: DetailSpacing.lg),
                                  Text(
                                    l10n.commentHistoryOriginalLabel,
                                    style: DetailTypography.cardTitle(context),
                                  ),
                                  const SizedBox(height: DetailSpacing.sm),
                                  SelectableText(
                                    comment.originalContent ?? '',
                                    style: DetailTypography.body(context),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Text(l10n.commonClose),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  : null,
              child:
                  Text(comment.content, style: DetailTypography.body(context)),
            ),
            const SizedBox(height: DetailSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _replyToCommentId = comment.id;
                      _replyToAuthorName = comment.userName;
                    });
                    _commentController.text = '@${comment.userName} ';
                    _commentController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _commentController.text.length),
                    );
                    _showAddCommentDialog(artwork);
                  },
                  child: Text(l10n.commonReply, style: DetailTypography.button(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentFAB(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    return FloatingActionButton.extended(
      onPressed: () => _showAddCommentDialog(artwork),
      icon: const Icon(Icons.add_comment),
      label: Text(
        l10n.artworkCommentAddButton,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showAddCommentDialog(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.artworkCommentAddTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_replyToAuthorName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.postDetailReplyingToLabel(_replyToAuthorName!),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _replyToAuthorName = null;
                              _replyToCommentId = null;
                            });
                            _commentController.clear();
                          },
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.artworkCommentAddHint,
                    hintStyle: GoogleFonts.outfit(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _commentController.clear();
                          setState(() {
                            _replyToAuthorName = null;
                            _replyToCommentId = null;
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n.commonCancel,
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<ArtworkProvider>(
                        builder: (context, provider, child) {
                          final scheme = Theme.of(context).colorScheme;
                          return ElevatedButton(
                            onPressed: () => _submitComment(artwork, provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: provider.isLoading('comment_${artwork.id}')
                              ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: InlineLoading(
                                        shape: BoxShape.circle,
                                        tileSize: 4.0,
                                  color: scheme.onPrimary),
                                  )
                                : Text(
                                    l10n.artworkCommentPostButton,
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitComment(Artwork artwork, ArtworkProvider provider) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    if (!profileProvider.isSignedIn) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast,
              style: GoogleFonts.outfit()),
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
          duration: const Duration(seconds: 3),
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
      navigator.pop();

      messenger.showKubusSnackBar(
        SnackBar(
          content:
              Text(l10n.artworkCommentAddedToast, style: GoogleFonts.outfit()),
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
                    msg.length > 140 ? '${msg.substring(0, 140)}â€¦' : msg;
              }
            }
          }
        } catch (_) {
          // Ignore body parse failures and fall back to a generic message.
        }
      }

      backendMessage = backendMessage?.replaceAll('Ã¢â‚¬Â¦', 'â€¦');

      final fallbackMessage = authRequired
          ? l10n.communityCommentAuthRequiredToast
          : (backendMessage ??
              '${l10n.commonSomethingWentWrong} (${e.statusCode})');
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            fallbackMessage,
            style: GoogleFonts.outfit(),
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
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final looksLikeNetwork = raw.contains('XMLHttpRequest error') ||
          raw.contains('ClientException') ||
          raw.contains('Failed to fetch') ||
          raw.contains('fetch failed') ||
          raw.contains('Failed host lookup') ||
          raw.contains('Connection refused') ||
          raw.contains('NetworkError') ||
          raw.contains('CORS');
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            looksLikeNetwork
                ? l10n.commonNetworkErrorToast
                : l10n.commonSomethingWentWrong,
            style: GoogleFonts.outfit(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showNavigationOptions(Artwork artwork) {
    final l10n = AppLocalizations.of(context)!;
    final lat = artwork.position.latitude;
    final lng = artwork.position.longitude;
    final artTitle = artwork.title;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Navigate to $artTitle',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildNavigationOption(
                      icon: Icons.map_outlined,
                      title: l10n.commonOpenOnMap,
                      onTap: () {
                        Navigator.pop(context);
                        MapNavigation.open(
                          this.context,
                          center: artwork.position,
                          zoom: 16,
                          autoFollow: false,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.map,
                      title: 'Google Maps',
                      onTap: () => _openInGoogleMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.apple,
                      title: 'Apple Maps',
                      onTap: () => _openInAppleMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.location_on,
                      title: 'Other Maps',
                      onTap: () => _openInDefaultMaps(lat, lng, artTitle),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationOption(
                      icon: Icons.copy,
                      title: 'Copy Coordinates',
                      onTap: () => _copyCoordinates(lat, lng),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final googleMapsAppUrl = 'comgooglemaps://?q=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Could not open Google Maps');
      }
    } catch (e) {
      _showErrorDialog('Error opening Google Maps: $e');
    }
  }

  Future<void> _openInAppleMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
    final appleMapsAppUrl = 'maps://?q=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(appleMapsAppUrl))) {
        await launchUrl(Uri.parse(appleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Could not open Apple Maps');
      }
    } catch (e) {
      _showErrorDialog('Error opening Apple Maps: $e');
    }
  }

  Future<void> _openInDefaultMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final defaultMapsUrl = 'geo:$lat,$lng?q=$lat,$lng($title)';

    try {
      if (await canLaunchUrl(Uri.parse(defaultMapsUrl))) {
        await launchUrl(Uri.parse(defaultMapsUrl));
      } else {
        // Fallback to web maps
        final webMapsUrl =
            'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=15';
        if (await canLaunchUrl(Uri.parse(webMapsUrl))) {
          await launchUrl(Uri.parse(webMapsUrl),
              mode: LaunchMode.externalApplication);
        } else {
          _showErrorDialog('Could not open maps application');
        }
      }
    } catch (e) {
      _showErrorDialog('Error opening maps: $e');
    }
  }

  Future<void> _copyCoordinates(double lat, double lng) async {
    Navigator.pop(context);
    final coordinates = '$lat, $lng';
    await Clipboard.setData(ClipboardData(text: coordinates));

    if (mounted) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            'Coordinates copied to clipboard: $coordinates',
            style: GoogleFonts.outfit(),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Navigation Error',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMintNFTDialog(Artwork artwork) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final walletAddress = prefs.getString('wallet_address');

    if (userId == null || walletAddress == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text('Please connect your wallet first',
                style: GoogleFonts.outfit()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    final nameController = TextEditingController(text: artwork.title);
    final descController = TextEditingController(text: artwork.description);
    final supplyController = TextEditingController(text: '100');
    final priceController = TextEditingController(text: '50.0');
    final royaltyController = TextEditingController(text: '10');

    CollectibleType selectedType = CollectibleType.nft;

    showKubusDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Mint NFT Series',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create an NFT series for this artwork',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Series Name',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: supplyController,
                  decoration: InputDecoration(
                    labelText: 'Total Supply',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Mint Price (SOL)',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: royaltyController,
                  decoration: InputDecoration(
                    labelText: 'Royalty %',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                    helperText: 'Creator royalty on secondary sales (0-100)',
                    helperStyle: GoogleFonts.outfit(fontSize: 12),
                  ),
                  style: GoogleFonts.outfit(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CollectibleType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'NFT Type',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: CollectibleType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.toString().split('.').last.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD93D),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _mintNFT(
                  artwork: artwork,
                  name: nameController.text,
                  description: descController.text,
                  totalSupply: int.tryParse(supplyController.text) ?? 100,
                  mintPrice: double.tryParse(priceController.text) ?? 0.1,
                  royaltyPercentage:
                      double.tryParse(royaltyController.text) ?? 10.0,
                  type: selectedType,
                );
              },
              child: Text('Mint NFT',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mintNFT({
    required Artwork artwork,
    required String name,
    required String description,
    required int totalSupply,
    required double mintPrice,
    required double royaltyPercentage,
    required CollectibleType type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('wallet_address') ?? '';
    if (!mounted) return;

    showKubusDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 56,
                height: 56,
                child: InlineLoading(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    tileSize: 8.0)),
            const SizedBox(height: 16),
            Text(
              'Minting NFT...',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final mintingService = NFTMintingService();
      final result = await mintingService.mintNFT(
        artworkId: artwork.id,
        artworkTitle: artwork.title,
        artistName: artwork.artist,
        ownerAddress: walletAddress,
        seriesName: name,
        seriesDescription: description,
        rarity: CollectibleRarity.rare,
        requiresARInteraction: artwork.arEnabled,
        type: type,
        totalSupply: totalSupply,
        mintPrice: mintPrice,
        royaltyPercentage: royaltyPercentage,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        if (result.success) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NFT minted successfully!',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                'Failed to mint NFT: ${result.error}',
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(
              'Error minting NFT: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

}
