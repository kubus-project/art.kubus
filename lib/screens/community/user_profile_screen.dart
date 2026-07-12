import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../models/profile_package.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/block_list_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/design_tokens.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/profile_showcase_normalizer.dart';
import '../../community/community_interactions.dart';
import '../../providers/themeprovider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/app_refresh_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/community_interactions_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/profile_package_controller.dart';
import '../../core/conversation_navigator.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/user_activity_status_line.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/profile_artist_info_fields.dart';
import '../../widgets/common/kubus_stat_card.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/shared_section_widgets.dart';
import 'post_detail_screen.dart';
import '../../utils/artwork_navigation.dart';
import '../art/collection_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../../providers/wallet_provider.dart';
import '../../services/socket_service.dart';
import 'profile_screen_methods.dart';
import '../../models/dao.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../widgets/profile/profile_achievements_preview_section.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final String? heroTag;
  final ProfilePackage? initialPackage;
  final Future<ProfilePackage?>? initialPackageFuture;
  final ProfileCriticalPackage? initialCriticalPackage;
  final Future<ProfileCriticalPackage?>? initialCriticalPackageFuture;
  final Future<ProfileExtendedPackage?>? initialExtendedPackageFuture;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.heroTag,
    this.initialPackage,
    this.initialPackageFuture,
    this.initialCriticalPackage,
    this.initialCriticalPackageFuture,
    this.initialExtendedPackageFuture,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  User? user;
  late final ProfilePackageController _profileController;
  bool isLoading = true;
  List<CommunityPost> _posts = [];
  bool _postsLoading = true;
  bool _isLastPage = false;
  bool _loadingMore = false;
  String? _postsError;
  late AnimationController _followButtonController;
  late Animation<double> _followButtonAnimation;
  late ScrollController _scrollController;
  bool _artistDataLoading = false;
  bool _artistDataLoaded = false;
  int _publicStreetArtAddedCount = 0;
  List<Map<String, dynamic>> _artistArtworks = [];
  List<Map<String, dynamic>> _artistCollections = [];
  List<Map<String, dynamic>> _artistEvents = [];
  String? _failedCoverImageUrl;
  bool _isFollowMutationInFlight = false;

  @override
  void initState() {
    super.initState();
    _followButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _followButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _followButtonController, curve: Curves.easeInOut),
    );
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
    _profileController = ProfilePackageController(
      walletAddress: widget.userId,
      username: widget.username,
      initialCriticalPackage: widget.initialCriticalPackage,
      initialCriticalPackageFuture: widget.initialCriticalPackageFuture,
      initialExtendedPackageFuture: widget.initialExtendedPackageFuture,
      initialPackage: widget.initialPackage,
      initialPackageFuture: widget.initialPackageFuture,
    );
    _profileController.addListener(_syncProfileControllerState);
    _syncProfileControllerState();
    unawaited(_profileController.load());
    // Listen for incoming posts via socket to update profile feed in real-time
    try {
      (() async {
        await SocketService().connect();
        SocketService().addPostListener(_handleIncomingPost);
      })();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final wp = Provider.of<WalletProvider>(context, listen: false);
        wp.addListener(_onWalletChanged);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _profileController.removeListener(_syncProfileControllerState);
    _profileController.dispose();
    _followButtonController.dispose();
    try {
      Provider.of<WalletProvider>(context, listen: false)
          .removeListener(_onWalletChanged);
    } catch (_) {}
    try {
      SocketService().removePostListener(_handleIncomingPost);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _syncProfileControllerState() {
    if (!mounted) return;
    setState(() {
      user = _profileController.user;
      isLoading = _profileController.isLoadingCritical;
      _posts = _profileController.posts;
      _postsLoading = _profileController.postsLoading;
      _isLastPage = _profileController.isLastPage;
      _loadingMore = _profileController.loadingMore;
      _postsError = _profileController.postsError;
      _publicStreetArtAddedCount = _profileController.publicStreetArtAddedCount;
      _artistArtworks = _profileController.artistArtworks;
      _artistCollections = _profileController.artistCollections;
      _artistEvents = _profileController.artistEvents;
      _artistDataLoaded = _profileController.artistDataLoaded;
      _artistDataLoading = _profileController.artistDataLoading;
    });
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    await _profileController.handleIncomingPostData(data);
  }

  void _onWalletChanged() async {
    try {
      await _profileController.refreshPostInteractions(
        interactionsProvider: context.read<CommunityInteractionsProvider>(),
        savedItemsProvider: context.read<SavedItemsProvider>(),
      );
    } catch (e) {
      debugPrint('Failed to refresh post interactions on wallet change: $e');
    }
  }

  Future<void> _loadUserStats(
      {bool skipFollowersOverwrite = false, bool forceRefresh = false}) async {
    await _profileController.loadStats(
      statsProvider: context.read<StatsProvider>(),
      skipFollowersOverwrite: skipFollowersOverwrite,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadPosts() async {
    final l10n = AppLocalizations.of(context)!;
    await _profileController.loadPosts(
      interactionsProvider: context.read<CommunityInteractionsProvider>(),
      savedItemsProvider: context.read<SavedItemsProvider>(),
      errorMessage: l10n.userProfilePostsLoadFailedDescription,
    );
  }

  Future<void> _loadMorePosts() async {
    final l10n = AppLocalizations.of(context)!;
    await _profileController.loadMorePosts(
      interactionsProvider: context.read<CommunityInteractionsProvider>(),
      savedItemsProvider: context.read<SavedItemsProvider>(),
      errorMessage: l10n.userProfilePostsLoadMoreFailedDescription,
    );
  }

  Future<void> _handleRefresh() async {
    await _profileController.refresh();
    final profile = user;
    if (!mounted || profile == null) return;
    try {
      await ProfileScreenMethods.prefetchOtherUserProfileData(
        context,
        walletAddress: profile.id,
        force: true,
        prefetchStatsSnapshot: false,
      );
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final profile = user;
    if (profile == null || _isFollowMutationInFlight) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    setState(() => _isFollowMutationInFlight = true);

    _followButtonController.forward().then((_) {
      if (mounted) {
        _followButtonController.reverse();
      }
    });

    UserFollowMutationResult mutation;
    try {
      mutation = await UserService.toggleFollowWithResult(
        profile.id,
        displayName: profile.name,
        username: profile.username,
        avatarUrl: profile.profileImageUrl,
      );
    } catch (e) {
      debugPrint(
          'UserProfileScreen: failed to toggle follow for ${profile.id}: $e');
      if (!mounted) return;

      final message = e.toString().contains('401')
          ? l10n.userProfileSignInToFollowToast
          : l10n.userProfileFollowUpdateFailedToast;

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: theme.colorScheme.error,
        ),
      );

      await _refreshFollowStateFromServer();
      await _loadUserStats(skipFollowersOverwrite: true, forceRefresh: true);
      if (mounted) {
        setState(() => _isFollowMutationInFlight = false);
      }
      return;
    }

    if (!mounted) return;

    final currentUser = user ?? profile;

    _profileController.patchUser((_) {
      return currentUser.copyWith(
        isFollowing: mutation.isFollowing,
        followersCount: mutation.followersCount ?? currentUser.followersCount,
        followingCount: mutation.followingCount ?? currentUser.followingCount,
      );
    });

    if (!mutation.hasCanonicalCounters) {
      await _refreshFollowStateFromServer();
    }

    if (!mounted) return;

    messenger.showKubusSnackBar(
      SnackBar(
        content: Text(
          (user?.isFollowing ?? mutation.isFollowing)
              ? l10n.userProfileNowFollowingToast(user!.name)
              : l10n.userProfileUnfollowedToast(user!.name),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      context.read<AppRefreshProvider>().triggerCommunity();
      context.read<AppRefreshProvider>().triggerProfile();
    } catch (_) {}

    await _loadUserStats(forceRefresh: true);
    if (!mounted) return;

    try {
      unawaited(ProfileScreenMethods.prefetchOtherUserProfileData(
        context,
        walletAddress: user!.id,
        force: true,
        prefetchStatsSnapshot: false,
      ));
    } catch (_) {}

    if (mounted) {
      setState(() => _isFollowMutationInFlight = false);
    }
  }

  Future<void> _refreshFollowStateFromServer() async {
    await _profileController.refreshFollowStateFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace:
              const KubusGlassAppBarBackdrop(showBottomDivider: true),
          title: Text(
            l10n.userProfileTitle,
            style: KubusTextStyles.mobileAppBarTitle,
          ),
        ),
        body: const AppLoading(),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace:
              const KubusGlassAppBarBackdrop(showBottomDivider: true),
          title: Text(
            l10n.userProfileTitle,
            style: KubusTextStyles.mobileAppBarTitle,
          ),
        ),
        body: Center(
          child: Text(l10n.userProfileNotFound),
        ),
      );
    }

    // Determine artist/institution status from User model + DAO reviews (like profile_screen.dart)
    final daoProvider = Provider.of<DAOProvider>(context);
    final DAOReview? daoReview = daoProvider.findReviewForWallet(user!.id);

    final isArtist = user!.isArtist ||
        (daoReview != null &&
            daoReview.isArtistApplication &&
            daoReview.isApproved);
    final isInstitution = user!.isInstitution ||
        (daoReview != null &&
            daoReview.isInstitutionApplication &&
            daoReview.isApproved);

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace:
              const KubusGlassAppBarBackdrop(showBottomDivider: true),
          title: Text(
            user!.name.isNotEmpty ? user!.name : l10n.userProfileTitle,
            style: KubusTextStyles.mobileAppBarTitle,
          ),
          actions: [
            IconButton(
              tooltip: l10n.commonMore,
              onPressed: _showMoreOptions,
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: themeProvider.accentColor,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DetailSpacing.xl),
              child: Column(
                children: [
                  _buildProfileHeader(
                    themeProvider,
                    isArtist: isArtist,
                    isInstitution: isInstitution,
                  ),
                  const SizedBox(height: DetailSpacing.md),
                  _buildStatsRow(l10n),
                  const SizedBox(height: DetailSpacing.md),
                  _buildAddedPublicArtSection(l10n),
                  const SizedBox(height: DetailSpacing.lg),
                  _buildActionButtons(themeProvider, l10n),
                  const SizedBox(height: DetailSpacing.lg),
                  if (isArtist) ...[
                    _buildArtistHighlightsGrid(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                  ],
                  isInstitution
                      ? _buildInstitutionHighlights(l10n)
                      : ((user?.showAchievements ?? true)
                          ? _buildAchievements(themeProvider, l10n)
                          : const SizedBox.shrink()),
                  const SizedBox(height: DetailSpacing.xl),
                  _buildPostsSection(l10n),
                  if (isArtist) ...[
                    const SizedBox(height: DetailSpacing.xl),
                    _buildArtistEventsShowcase(l10n),
                  ],
                  const SizedBox(height: DetailSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMoreOptions() async {
    final l10n = AppLocalizations.of(context)!;
    final target =
        ShareTarget.profile(walletAddress: user!.id, title: user!.name);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        final surface = Theme.of(sheetContext).colorScheme.surface;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: BackdropGlassSheet(
              padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
              backgroundColor: surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: Text(l10n.commonShare,
                        style: KubusTextStyles.sectionTitle),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ShareService().showShareSheet(
                        context,
                        target: target,
                        sourceScreen: 'user_profile',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(l10n.userProfileMoreOptionsBlockUser,
                        style: KubusTextStyles.sectionTitle),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showBlockConfirmation();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: Text(l10n.userProfileMoreOptionsReportUser,
                        style: KubusTextStyles.sectionTitle),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showReportDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(ThemeProvider themeProvider,
      {required bool isArtist, required bool isInstitution}) {
    final l10n = AppLocalizations.of(context)!;
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final coverUrlIsKnownBad =
        coverImageUrl != null && coverImageUrl == _failedCoverImageUrl;
    final hasCoverImage = coverImageUrl != null &&
        coverImageUrl.isNotEmpty &&
        !coverUrlIsKnownBad;
    const avatarRadius = 45.0;
    const avatarCornerRadiusFactor = AvatarWidget.defaultCornerRadiusFactor;
    const avatarRingPadding = 4.0;

    final avatarRingShapeRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarRadius + avatarRingPadding,
      cornerRadiusFactor: avatarCornerRadiusFactor,
    );
    final scheme = Theme.of(context).colorScheme;
    final username = user!.username.trim();
    final usernameLabel = username.isEmpty
        ? ''
        : (username.startsWith('@') ? username : '@$username');
    final titleColor = hasCoverImage ? Colors.white : scheme.onSurface;
    final subtitleColor = hasCoverImage
        ? Colors.white.withValues(alpha: 0.82)
        : scheme.onSurface.withValues(alpha: 0.70);

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: hasCoverImage ? 220 : 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KubusRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: !hasCoverImage
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          themeProvider.accentColor.withValues(alpha: 0.3),
                          themeProvider.accentColor.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.xl),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasCoverImage)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final cacheWidth =
                              (constraints.maxWidth * dpr).round();
                          final cacheHeight =
                              (constraints.maxHeight * dpr).round();
                          return Image.network(
                            coverImageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                            cacheHeight: cacheHeight > 0 ? cacheHeight : null,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              if (_failedCoverImageUrl != coverImageUrl) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() =>
                                      _failedCoverImageUrl = coverImageUrl);
                                });
                              }
                              return const SizedBox.expand();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox.expand();
                            },
                          );
                        },
                      ),
                    if (hasCoverImage)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: KubusSpacing.lg,
              right: KubusSpacing.lg,
              bottom: KubusSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(
                        avatarRingShapeRadius,
                      ),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.24),
                        width: KubusSizes.hairline + 0.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .shadowColor
                              .withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(avatarRingPadding),
                      child: AvatarWidget(
                        wallet: user!.id,
                        avatarUrl: user!.profileImageUrl,
                        radius: avatarRadius,
                        borderWidth: 0,
                        borderColor: Colors.transparent,
                        cornerRadiusFactor: avatarCornerRadiusFactor,
                        enableProfileNavigation: false,
                        heroTag: widget.heroTag,
                      ),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user!.name,
                                style: KubusTextStyles.screenTitle.copyWith(
                                  color: titleColor,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user!.isVerified) ...[
                              const SizedBox(width: KubusSpacing.sm),
                              Icon(
                                Icons.verified,
                                color: hasCoverImage
                                    ? Colors.white
                                    : themeProvider.accentColor,
                                size: KubusHeaderMetrics.actionIcon,
                              ),
                            ],
                            if (isArtist) ...[
                              const SizedBox(width: KubusSpacing.sm),
                              const ArtistBadge(),
                            ],
                            if (isInstitution) ...[
                              const SizedBox(width: KubusSpacing.sm),
                              const InstitutionBadge(),
                            ],
                          ],
                        ),
                        if (usernameLabel.isNotEmpty) ...[
                          const SizedBox(height: KubusSpacing.xs),
                          Text(
                            usernameLabel,
                            style: KubusTextStyles.profileHandle.copyWith(
                              color: subtitleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.md),
        LiquidGlassCard(
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.lg,
            vertical: KubusSpacing.md,
          ),
          child: Column(
            children: [
              UserActivityStatusLine(
                walletAddress: user!.id,
                textAlign: TextAlign.center,
                textStyle: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              if (user!.bio.trim().isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  user!.bio,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: KubusSpacing.sm),
              ProfileArtistInfoFields(
                fieldOfWork: user!.fieldOfWork,
                yearsActive: user!.yearsActive,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                _formatJoinedLabel(l10n, user!.joinedDate),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatJoinedLabel(AppLocalizations l10n, String rawJoinedDate) {
    final trimmed = rawJoinedDate.trim();
    if (trimmed.isEmpty) {
      return l10n.userProfileJoinedLabel('');
    }

    final joinedPrefixRegex = RegExp(r'^joined\s+', caseSensitive: false);
    final normalizedDate = trimmed.replaceFirst(joinedPrefixRegex, '').trim();
    return l10n.userProfileJoinedLabel(
      normalizedDate.isEmpty ? trimmed : normalizedDate,
    );
  }

  Widget _buildStatsRow(AppLocalizations l10n) {
    final artworksCount = Provider.of<ArtworkProvider>(context, listen: true)
        .artworksForWallet(user!.id)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: KubusSpacing.md,
          crossAxisSpacing: KubusSpacing.md,
          childAspectRatio: compact ? 1.12 : 1.28,
          children: [
            _buildProfileStatCard(
              title: l10n.userProfilePostsStatLabel,
              value: _formatCount(user!.postsCount),
              icon: Icons.article_outlined,
            ),
            _buildProfileStatCard(
              title: l10n.userProfileFollowersStatLabel,
              value: _formatCount(user!.followersCount),
              icon: Icons.people_outline,
              onTap: () {
                ProfileScreenMethods.showFollowers(
                  context,
                  walletAddress: user!.id,
                );
              },
            ),
            _buildProfileStatCard(
              title: l10n.userProfileFollowingStatLabel,
              value: _formatCount(user!.followingCount),
              icon: Icons.person_add_alt_outlined,
              onTap: () {
                ProfileScreenMethods.showFollowing(
                  context,
                  walletAddress: user!.id,
                );
              },
            ),
            _buildProfileStatCard(
              title: l10n.userProfileArtworksTitle,
              value: _formatCount(artworksCount),
              icon: Icons.palette_outlined,
              onTap: () {
                ProfileScreenMethods.showArtworks(
                  context,
                  walletAddress: user!.id,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileStatCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final accent = _accentForProfileStat(icon);
    return KubusStatCard(
      title: title,
      value: value,
      icon: icon,
      accent: accent,
      layout: KubusStatCardLayout.centered,
      minHeight: 86,
      padding: const EdgeInsets.all(KubusSpacing.md),
      titleMaxLines: 2,
      centeredWatermarkScale: 0.86,
      onTap: onTap,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: 11.5,
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Color _accentForProfileStat(IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    if (icon == Icons.people_outline || icon == Icons.person_add_alt_outlined) {
      return scheme.tertiary;
    }
    if (icon == Icons.palette_outlined || icon == AppColorUtils.streetArtIcon) {
      return scheme.primary;
    }
    return scheme.secondary;
  }

  Widget _buildActionButtons(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ScaleTransition(
              scale: _followButtonAnimation,
              child: ElevatedButton(
                onPressed: _isFollowMutationInFlight ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: user!.isFollowing
                      ? Theme.of(context).colorScheme.surface
                      : themeProvider.accentColor,
                  foregroundColor: user!.isFollowing
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.white,
                  side: user!.isFollowing
                      ? BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.2),
                          width: 1.5,
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: user!.isFollowing ? 0 : 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                child: _isFollowMutationInFlight
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: InlineLoading(tileSize: 4, color: user!.isFollowing
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.white),
                      )
                    : Text(
                        user!.isFollowing
                            ? l10n.userProfileFollowingButton
                            : l10n.userProfileFollowButton,
                        style: KubusTextStyles.actionTileTitle,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isFollowMutationInFlight
                ? null
                : () async {
                    final chatProvider =
                        Provider.of<ChatProvider>(context, listen: false);
                    // navigator variable no longer used; ConversationNavigator handles navigation
                    final messenger = ScaffoldMessenger.of(context);
                    final chatAuth = chatProvider.isAuthenticated;
                    final l10n = AppLocalizations.of(context)!;
                    try {
                      final conv = await chatProvider
                          .createConversation('', false, [user!.id]);
                      if (conv != null) {
                        if (!mounted) return;
                        final preloaded = Provider.of<ChatProvider>(context,
                                listen: false)
                            .getPreloadedProfileMapsForConversation(conv.id);
                        // Ensure we pass non-empty members and sensible fallbacks for avatars / display names
                        final rawMembers =
                            (preloaded['members'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                <String>[];
                        final members = rawMembers.isNotEmpty
                            ? rawMembers
                            : <String>[user!.id];
                        final rawAvatars =
                            (preloaded['avatars'] as Map<String, String?>?) ??
                                <String, String?>{};
                        final avatars = Map<String, String?>.from(rawAvatars);
                        if (!avatars.containsKey(members.first) ||
                            (avatars[members.first] == null ||
                                avatars[members.first]!.isEmpty)) {
                          avatars[members.first] = user!.profileImageUrl;
                        }
                        final rawNames =
                            (preloaded['names'] as Map<String, String?>?) ??
                                <String, String?>{};
                        final names = Map<String, String?>.from(rawNames);
                        if (!names.containsKey(members.first) ||
                            (names[members.first] == null ||
                                names[members.first]!.isEmpty)) {
                          names[members.first] = user!.name;
                        }
                        await ConversationNavigator.openConversationWithPreload(
                          context,
                          conv,
                          preloadedMembers: members,
                          preloadedAvatars: avatars,
                          preloadedDisplayNames: names,
                        );
                      } else {
                        if (!chatAuth) {
                          if (mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.userProfileMessageLoginRequiredToast,
                                ),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.userProfileConversationOpenFailedToast,
                                ),
                              ),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint(
                          'UserProfileScreen: failed to open conversation: $e');
                      if (!mounted) return;
                      messenger.showKubusSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.userProfileConversationOpenGenericErrorToast,
                          ),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                width: 1.5,
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
            ),
            child: const Icon(Icons.message),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedPublicArtSection(AppLocalizations l10n) {
    return _buildProfileStatCard(
      title: l10n.profilePerformancePublicStreetArtAddedTitle,
      value: _formatCount(_publicStreetArtAddedCount),
      icon: AppColorUtils.streetArtIcon,
    );
  }

  Widget _buildAchievements(
      ThemeProvider themeProvider, AppLocalizations l10n) {
    if (!(user?.showAchievements ?? true)) {
      return const SizedBox.shrink();
    }

    return ProfileAchievementsPreviewSection(
      mode: ProfileAchievementsPreviewMode.publicProfile,
      dataState: _profileController.achievementPreviewDataState,
      publicProgress: _profileController.package?.achievementProgress,
      publicDefinitions: _profileController.package?.achievementDefinitions,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      showWhenEmpty: true,
    );
  }

  Widget _buildPostsSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userProfilePostsTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (_postsLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(child: InlineLoading(width: 40, height: 40)),
            )
          else if (_postsError != null)
            _buildEmptyStateCard(
              l10n: l10n,
              title: l10n.userProfilePostsLoadFailedTitle,
              description: _postsError!,
              icon: Icons.cloud_off,
              showAction: true,
              actionLabel: l10n.commonRetry,
              onActionTap: _loadPosts,
            )
          else if (_posts.isEmpty)
            _buildEmptyStateCard(
              l10n: l10n,
              title: l10n.userProfileNoPostsTitle,
              description: l10n.userProfileNoPostsDescription(user!.name),
              icon: Icons.article,
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = _posts[index];
                final themeProvider =
                    Provider.of<ThemeProvider>(context, listen: false);
                return CommunityPostCard(
                  post: post,
                  accentColor: themeProvider.accentColor,
                  onOpenPostDetail: (target) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(post: target),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          if (_loadingMore)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: InlineLoading(tileSize: 4)),
            )
          else if (_isLastPage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                l10n.userProfileNoMorePostsLabel,
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildArtistHighlightsGrid(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.userProfileArtistHighlightsTitle,
            subtitle: l10n.userProfileArtistHighlightsSubtitle(user!.name),
            kind: KubusHeaderKind.section,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileArtworksTitle,
            items: _artistArtworks,
            emptyLabel: l10n.userProfileNoArtworksYetLabel(user!.name),
            emptyIcon: Icons.image_outlined,
            builder: _buildArtworkCard,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: l10n.userProfileNoCollectionsYetLabel(user!.name),
            emptyIcon: Icons.collections_outlined,
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistEventsShowcase(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.userProfileEventsTitle,
            subtitle: l10n.userProfileEventsSubtitleFeaturing(user!.name),
            kind: KubusHeaderKind.section,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileEventsTitle,
            items: _artistEvents,
            emptyLabel: l10n.userProfileNoUpcomingEventsYetLabel(user!.name),
            emptyIcon: Icons.event,
            builder: _buildEventCard,
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionHighlights(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.userProfileInstitutionHighlightsTitle,
            subtitle: l10n.userProfileInstitutionHighlightsSubtitle(user!.name),
            kind: KubusHeaderKind.section,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileEventsTitle,
            items: _artistEvents,
            emptyLabel: l10n.userProfileNoUpcomingEventsYetLabel(user!.name),
            emptyIcon: Icons.event,
            builder: _buildEventCard,
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          _buildShowcaseSection(
            l10n: l10n,
            title: l10n.userProfileCollectionsTitle,
            items: _artistCollections,
            emptyLabel: l10n.userProfileNoCollectionsYetLabel(user!.name),
            emptyIcon: Icons.collections_outlined,
            builder: _buildCollectionCard,
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseSection({
    required AppLocalizations l10n,
    required String title,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) builder,
    required String emptyLabel,
    required IconData emptyIcon,
  }) {
    return SharedShowcaseSection<Map<String, dynamic>>(
      title: title,
      items: items,
      itemBuilder: (context, item) => builder(item),
      isLoading: _artistDataLoading && !_artistDataLoaded,
      emptyTitle: l10n.userProfileNoItemsTitle(title),
      emptyDescription: emptyLabel,
      emptyIcon: emptyIcon,
      loadingHeight: 180,
      listHeight: 210,
    );
  }

  Widget _buildArtworkCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileArtworkShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.commonUntitled,
      fallbackSubtitle: l10n.commonDigital,
    );

    return _buildShowcaseCard(
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: card.subtitle,
      footer: l10n.userProfileLikesLabel(card.likesCount),
      onTap: card.id != null
          ? () {
              openArtwork(context, card.id!, source: 'user_profile');
            }
          : null,
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileCollectionShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.userProfileCollectionFallbackTitle,
    );

    return _buildShowcaseCard(
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: l10n.userProfileArtworksCountLabel(card.artworkCount),
      footer: card.description ?? l10n.userProfileCuratedByLabel(user!.name),
      onTap: (card.id != null && card.id!.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CollectionDetailScreen(collectionId: card.id!),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final card = ProfileEventShowcaseData.fromMap(
      data,
      fallbackTitle: l10n.userProfileEventFallbackTitle,
      fallbackLocation: l10n.commonTba,
    );
    final dateLabel = _formatDateLabel(l10n, card.startDate);

    return _buildShowcaseCard(
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: dateLabel,
      footer: card.location ?? l10n.commonTba,
      onTap: (card.id != null && card.id!.isNotEmpty)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: card.id!),
                ),
              );
            }
          : null,
    );
  }

  Widget _buildShowcaseCard({
    String? imageUrl,
    required String title,
    required String subtitle,
    required String footer,
    VoidCallback? onTap,
  }) {
    return SharedShowcaseCard(
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      footer: footer,
      onTap: onTap,
      width: 200,
      imageHeight: 110,
    );
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  String _formatDateLabel(AppLocalizations l10n, dynamic value) {
    if (value == null) return l10n.commonTba;
    try {
      final date = value is DateTime ? value : DateTime.parse(value.toString());
      return MaterialLocalizations.of(context).formatMediumDate(date);
    } catch (_) {
      return l10n.commonTba;
    }
  }

  Widget _buildEmptyStateCard({
    required AppLocalizations l10n,
    required String title,
    required String description,
    IconData icon = Icons.info_outline,
    bool showAction = false,
    String? actionLabel,
    Future<void> Function()? onActionTap,
  }) {
    return EmptyStateCard(
      icon: icon,
      title: title,
      description: description,
      showAction: showAction,
      actionLabel: showAction ? (actionLabel ?? l10n.commonRetry) : null,
      onAction: onActionTap != null ? () => onActionTap() : null,
    );
  }

  void _showBlockConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(
          l10n.userProfileBlockDialogTitle(user!.name),
          style: KubusTextStyles.sectionTitle,
        ),
        content: Text(
          l10n.userProfileBlockDialogDescription,
          style: KubusTextStyles.sectionSubtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final targetWallet =
                  WalletUtils.canonical(user?.id ?? widget.userId);
              if (targetWallet.isEmpty) {
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showKubusSnackBar(SnackBar(
                    content: Text(l10n.userProfileUnableToBlockToast)));
                return;
              }

              try {
                await BlockListService().blockWallet(targetWallet);
              } catch (e) {
                debugPrint('UserProfileScreen: failed to block user: $e');
                if (!mounted) return;
                Navigator.pop(context);
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.userProfileBlockFailedToast)));
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              messenger.showKubusSnackBar(
                SnackBar(
                    content: Text(l10n
                        .userProfileBlockedToast(user?.name ?? targetWallet))),
              );
            },
            child: Text(l10n.userProfileBlockButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(
          l10n.userProfileReportDialogTitle(user!.name),
          style: KubusTextStyles.sectionTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.userProfileReportDialogQuestion,
              style: KubusTextStyles.sectionSubtitle,
            ),
            const SizedBox(height: 16),
            _buildReportOption(dialogContext, l10n.userProfileReportReasonSpam),
            _buildReportOption(
                dialogContext, l10n.userProfileReportReasonInappropriate),
            _buildReportOption(
                dialogContext, l10n.userProfileReportReasonHarassment),
            _buildReportOption(
                dialogContext, l10n.userProfileReportReasonOther),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(BuildContext dialogContext, String reason) {
    return ListTile(
      title: Text(reason),
      onTap: () async {
        final l10n = AppLocalizations.of(context)!;
        final messenger = ScaffoldMessenger.of(context);
        final targetWallet = WalletUtils.canonical(user?.id ?? widget.userId);

        Navigator.pop(dialogContext);

        if (targetWallet.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(
                content: Text(l10n.commonActionFailedToast),
                duration: const Duration(seconds: 2)),
          );
          return;
        }

        try {
          await CommunityService.reportUser(
            targetWallet,
            reason,
            details: user?.name,
          );
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(
                content: Text(l10n.userProfileReportSubmittedToast),
                duration: const Duration(seconds: 2)),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(
                content: Text(l10n.commonActionFailedToast),
                duration: const Duration(seconds: 2)),
          );
        }
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
