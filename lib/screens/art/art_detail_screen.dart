import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/artwork_creator_byline.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/artwork.dart';
import '../../models/artwork_comment.dart';
import '../../services/backend_api_service.dart';
import '../../services/nft_minting_service.dart';
import '../../models/collectible.dart';
import '../../utils/app_animations.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/rarity_ui.dart';
import '../../utils/map_navigation.dart';
import '../../widgets/collaboration_panel.dart';
import '../../config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

class ArtDetailScreen extends StatefulWidget {
  final String artworkId;

  const ArtDetailScreen({super.key, required this.artworkId});

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
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.artDetailLoadingTitle, style: GoogleFonts.outfit()),
            ),
            body: const Center(child: InlineLoading()),
          );
        }

        if (_artworkError != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.artDetailTitle, style: GoogleFonts.outfit()),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _artworkError!,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
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
            appBar: AppBar(
              title: Text(l10n.artworkNotFound, style: GoogleFonts.outfit()),
            ),
            body: Center(
              child: Text(l10n.artworkNotFound),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                        padding: const EdgeInsets.all(24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildArtPreview(artwork),
                            const SizedBox(height: 24),
                            _buildArtInfo(artwork),
                            const SizedBox(height: 24),
                            _buildDescription(artwork),
                            const SizedBox(height: 24),
                            _buildSocialStats(artwork),
                            const SizedBox(height: 24),
                            _buildActionButtons(artwork),
                            const SizedBox(height: 24),
                            if (AppConfig.isFeatureEnabled('collabInvites')) ...[
                              CollaborationPanel(
                                entityType: 'artworks',
                                entityId: artwork.id,
                              ),
                              const SizedBox(height: 24),
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
          floatingActionButton: (_showComments && isSignedIn) ? _buildCommentFAB(artwork) : null,
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
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      actions: [
        Consumer<ArtworkProvider>(
          builder: (context, provider, child) {
            return IconButton(
              onPressed: () => provider.toggleFavorite(artwork.id),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  artwork.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: artwork.isFavorite ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                RarityUi.artworkColor(context, artwork.rarity).withValues(alpha: 0.3),
                RarityUi.artworkColor(context, artwork.rarity).withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: RarityUi.artworkColor(context, artwork.rarity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RarityUi.artworkColor(context, artwork.rarity).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                artwork.arEnabled ? Icons.view_in_ar : Icons.palette,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtPreview(Artwork artwork) {
    final rarityColor = RarityUi.artworkColor(context, artwork.rarity);
    final coverUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.3),
          width: 2,
        ),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
            _buildPreviewCoverImage(coverUrl, rarityColor),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            // Rarity badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rarityColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  artwork.rarity.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Status badge
            if (artwork.isDiscovered)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'DISCOVERED',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // AR badge
            if (artwork.arEnabled)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_in_ar, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'AR ENABLED',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCoverImage(String? imageUrl, Color fallbackColor) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fallbackColor.withValues(alpha: 0.25),
            fallbackColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.white.withValues(alpha: 0.9),
          size: 40,
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    return Image.network(
      imageUrl,
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
              color: Theme.of(context).colorScheme.primary,
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
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ArtworkCreatorByline(
          artwork: artwork,
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildInfoChip(Icons.category, artwork.category),
            if (artwork.averageRating != null)
              _buildInfoChip(Icons.star, '${artwork.averageRating?.toStringAsFixed(1)} (${artwork.ratingsCount})'),
            _buildInfoChip(Icons.access_time, artwork.createdAt.toString().split(' ')[0]),
          ],
        ),
        const SizedBox(height: 16),
        if (artwork.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: artwork.tags.map((tag) => _buildTag(tag)).toList(),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '#$tag',
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription(Artwork artwork) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          artwork.description,
          style: GoogleFonts.outfit(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialStats(Artwork artwork) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.favorite, artwork.likesCount, 'Likes'),
          _buildStatItem(Icons.comment, artwork.commentsCount, 'Comments'),
          _buildStatItem(Icons.visibility, artwork.viewsCount, 'Views'),
          _buildStatItem(Icons.explore, artwork.discoveryCount, 'Discoveries'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Artwork artwork) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer<ArtworkProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton.icon(
                    onPressed: () => provider.toggleLike(artwork.id),
                    icon: Icon(
                      artwork.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                      color: artwork.isLikedByCurrentUser ? Colors.red : null,
                    ),
                    label: Text(
                      artwork.isLikedByCurrentUser ? 'Liked' : 'Like',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: artwork.isLikedByCurrentUser 
                          ? Colors.red.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainer,
                      foregroundColor: artwork.isLikedByCurrentUser 
                          ? Colors.red 
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showComments = !_showComments;
                  });

                  if (_showComments) {
                    context.read<ArtworkProvider>().loadComments(widget.artworkId);
                  }
                },
                icon: Icon(
                  _showComments ? Icons.comment : Icons.comment_outlined,
                ),
                label: Text(
                  _showComments ? 'Hide Comments' : 'Comments',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (artwork.arEnabled)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/ar'),
                  icon: const Icon(Icons.view_in_ar),
                  label: Text(
                    'Experience AR',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (artwork.arEnabled) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showNavigationOptions(artwork),
                icon: const Icon(Icons.navigation),
                label: Text(
                  'Navigate',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showMintNFTDialog(artwork),
            icon: const Icon(Icons.diamond),
            label: Text(
              'Mint as NFT',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFFFD93D),
              foregroundColor: Colors.black,
            ),
          ),
        ),
      ],
    );
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
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => provider.loadComments(artwork.id, force: true),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: InlineLoading()),
          )
        else if (comments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.postDetailNoCommentsTitle,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.postDetailNoCommentsDescription,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...comments.map((comment) => _buildCommentItem(comment, provider)),
        const SizedBox(height: 12),
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
              label: Text(
                l10n.commonSignIn,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(ArtworkComment comment, ArtworkProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currentUser = context.read<ProfileProvider>().currentUser;
    final canModify = currentUser != null &&
        (currentUser.id == comment.userId || currentUser.walletAddress == comment.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                avatarUrl: comment.userAvatarUrl,
                wallet: comment.userId,
                radius: 16,
                enableProfileNavigation: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          comment.timeAgo,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (comment.isEdited) ...[
                          const SizedBox(width: 8),
                          Text(
                            l10n.commonEditedTag,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
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
                      final controller = TextEditingController(text: comment.content);
                      bool saving = false;

                      await showDialog<void>(
                        context: context,
                        barrierDismissible: !saving,
                        builder: (dialogContext) {
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return AlertDialog(
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
                                        : () => Navigator.of(dialogContext).pop(),
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
                                                artworkId: widget.artworkId,
                                                commentId: comment.id,
                                                content: next,
                                              );
                                              if (!mounted) return;
                                              if (!dialogContext.mounted) return;
                                              Navigator.of(dialogContext).pop();
                                              messenger.showSnackBar(
                                                SnackBar(content: Text(l10n.commentUpdatedToast)),
                                              );
                                            } catch (_) {
                                              if (!mounted) return;
                                              messenger.showSnackBar(
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
                      if (!mounted) return;
                      navigator; // keep reference (no-op)
                    } else if (value == 'delete') {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
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
                          artworkId: widget.artworkId,
                          commentId: comment.id,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.commentDeletedToast)),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        messenger.showSnackBar(
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
                onPressed: () => provider.toggleCommentLike(widget.artworkId, comment.id),
                icon: Icon(
                  comment.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: comment.isLikedByCurrentUser ? Colors.red : null,
                ),
              ),
              if (comment.likesCount > 0)
                Text(
                  comment.likesCount.toString(),
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (comment.isEdited && comment.originalContent != null)
                ? () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: Text(l10n.commentHistoryTitle),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.commentHistoryCurrentLabel,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  comment.content,
                                  style: GoogleFonts.outfit(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.commentHistoryOriginalLabel,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  comment.originalContent ?? '',
                                  style: GoogleFonts.outfit(fontSize: 14),
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
                : null,
            child: Text(
              comment.content,
              style: GoogleFonts.outfit(fontSize: 14),
            ),
          ),
        ],
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n.commonCancel,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<ArtworkProvider>(
                        builder: (context, provider, child) {
                          return ElevatedButton(
                            onPressed: () => _submitComment(artwork, provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: provider.isLoading('comment_${artwork.id}')
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: InlineLoading(shape: BoxShape.circle, tileSize: 4.0, color: Colors.white),
                                  )
                                : Text(
                                    l10n.artworkCommentPostButton,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if (!profileProvider.isSignedIn) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast, style: GoogleFonts.outfit()),
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

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final walletAddress = profileProvider.currentUser?.walletAddress ?? walletProvider.currentWalletAddress;
    final displayName = profileProvider.currentUser?.displayName
        ?? profileProvider.currentUser?.username
        ?? (walletAddress != null && walletAddress.length >= 8 ? 'User ${walletAddress.substring(0, 8)}...' : 'User');
    final optimisticId = walletAddress ?? profileProvider.currentUser?.id ?? 'current_user';

    try {
      await provider.addComment(
        artwork.id,
        content,
        optimisticId,
        displayName,
      );

      if (!mounted) return;
      _commentController.clear();
      navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.artworkCommentAddedToast, style: GoogleFonts.outfit()),
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
              final msg = (decoded['error'] ?? decoded['message'] ?? '').toString().trim();
              if (msg.isNotEmpty) {
                backendMessage = msg.length > 140 ? '${msg.substring(0, 140)}…' : msg;
              }
            }
          }
        } catch (_) {
          // Ignore body parse failures and fall back to a generic message.
        }
      }

      final fallbackMessage = authRequired
          ? l10n.communityCommentAuthRequiredToast
          : (backendMessage ?? '${l10n.commonSomethingWentWrong} (${e.statusCode})');
      messenger.showSnackBar(
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            looksLikeNetwork
                ? 'Network error while posting comment (backend unreachable / blocked).'
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String title) async {
    Navigator.pop(context);
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final googleMapsAppUrl = 'comgooglemaps://?q=$lat,$lng';
    
    try {
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
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
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
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
        final webMapsUrl = 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=15';
        if (await canLaunchUrl(Uri.parse(webMapsUrl))) {
          await launchUrl(Uri.parse(webMapsUrl), mode: LaunchMode.externalApplication);
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
      ScaffoldMessenger.of(context).showSnackBar(
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please connect your wallet first', style: GoogleFonts.outfit()),
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
    CollectibleRarity selectedRarity = _convertArtworkRarity(artwork.rarity);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<CollectibleRarity>(
                  initialValue: selectedRarity,
                  decoration: InputDecoration(
                    labelText: 'Rarity',
                    labelStyle: GoogleFonts.outfit(),
                    border: const OutlineInputBorder(),
                  ),
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: CollectibleRarity.values.map((rarity) {
                    return DropdownMenuItem(
                      value: rarity,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: RarityUi.collectibleColor(context, rarity),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rarity.toString().split('.').last.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRarity = value);
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
                  royaltyPercentage: double.tryParse(royaltyController.text) ?? 10.0,
                  type: selectedType,
                  rarity: selectedRarity,
                );
              },
              child: Text('Mint NFT', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
    required CollectibleRarity rarity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('wallet_address') ?? '';
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 56, height: 56, child: InlineLoading(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary, tileSize: 8.0)),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
        rarity: rarity,
        requiresARInteraction: artwork.arEnabled,
        type: type,
        totalSupply: totalSupply,
        mintPrice: mintPrice,
        royaltyPercentage: royaltyPercentage,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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

  CollectibleRarity _convertArtworkRarity(ArtworkRarity artworkRarity) {
    switch (artworkRarity) {
      case ArtworkRarity.common:
        return CollectibleRarity.common;
      case ArtworkRarity.rare:
        return CollectibleRarity.rare;
      case ArtworkRarity.epic:
        return CollectibleRarity.epic;
      case ArtworkRarity.legendary:
        return CollectibleRarity.legendary;
    }
  }

}
