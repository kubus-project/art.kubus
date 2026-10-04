import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../models/profile_package.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/block_list_service.dart';
import '../../services/contextual_auth_gate.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../utils/design_tokens.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/kubus_entity_semantics.dart';
import '../../widgets/common/kubus_entity_card.dart';
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
import '../../providers/public_entity_takeover_provider.dart';
import '../../core/conversation_navigator.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/user_activity_status_line.dart';
import '../../widgets/profile_artist_info_fields.dart';
import '../../widgets/common/kubus_stat_card.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/profile_identity_block.dart';
import '../../widgets/detail/profile_relationship_actions.dart';
import '../../widgets/profile/profile_identity_hero.dart';
import '../../widgets/profile/profile_posts_preview_section.dart';
import 'profile_posts_screen.dart';
import '../../widgets/detail/profile_utility_actions.dart';
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
import '../../widgets/public_entity_takeover_ready.dart';

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

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? user;
  late final ProfilePackageController _profileController;
  bool isLoading = true;
  List<CommunityPost> _posts = [];
  bool _postsLoading = true;
  String? _postsError;
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
    // No scroll-driven paging here. The profile shows a bounded post preview
    // so the closing statistics stay reachable; the dedicated post-history
    // screen owns paging.
    _scrollController = ScrollController();
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
    // Listen for incoming posts via socket to update profile feed in real-time.
    // The try/catch must live *inside* the async closure: wrapping the
    // invocation instead only guards the synchronous act of starting the
    // Future, so a connect() failure would escape as an uncaught zone error.
    (() async {
      try {
        await SocketService().connect();
        if (!mounted) return;
        SocketService().addPostListener(_handleIncomingPost);
      } catch (_) {}
    })();
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
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonFollow.toLowerCase(),
      returnRoute: '/u/${Uri.encodeComponent(widget.userId)}',
      actionType: PendingActionType.follow,
      targetType: PendingActionTargetType.user,
      targetId: profile.id,
      targetLabel: profile.name,
      sourceScreen: 'user_profile',
    );
    if (!authenticated || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    setState(() => _isFollowMutationInFlight = true);

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

    final isCanonicalPublicEntry = isCanonicalPublicEntityEntry(
      context,
      type: 'profile',
      id: widget.userId,
    );
    final roles = KubusColorRoles.of(context);

    final scaffold = Scaffold(
      backgroundColor:
          isCanonicalPublicEntry ? roles.surface : Colors.transparent,
      appBar: AppBar(
        backgroundColor:
            isCanonicalPublicEntry ? roles.surface : Colors.transparent,
        elevation: 0,
        surfaceTintColor: isCanonicalPublicEntry ? roles.surface : null,
        scrolledUnderElevation: 0,
        flexibleSpace: isCanonicalPublicEntry
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: roles.rule),
                  ),
                ),
              )
            : const KubusGlassAppBarBackdrop(showBottomDivider: true),
        title: Text(
          isCanonicalPublicEntry
              ? 'art.kubus'
              : user!.name.isNotEmpty
                  ? user!.name
                  : l10n.userProfileTitle,
          style: isCanonicalPublicEntry
              ? KubusTextStyles.screenTitle.copyWith(
                  color: roles.foreground,
                )
              : KubusTextStyles.mobileAppBarTitle,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: KubusSpacing.sm),
            child: ProfileUtilityActions(
              actions: [
                ProfileUtilityAction(
                  icon: Icons.more_horiz,
                  tooltip: l10n.commonMore,
                  onPressed: _showMoreOptions,
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color:
            isCanonicalPublicEntry ? roles.active : themeProvider.accentColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isCanonicalPublicEntry ? KubusSpacing.md : DetailSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isCanonicalPublicEntry)
                  _buildCanonicalPublicEntryProfileHero(
                    isArtist: isArtist,
                    isInstitution: isInstitution,
                    l10n: l10n,
                  )
                else
                  _buildProfileHeader(
                    themeProvider,
                    isArtist: isArtist,
                    isInstitution: isInstitution,
                  ),
                const SizedBox(height: DetailSpacing.md),
                if (isCanonicalPublicEntry) ...[
                  if (_canonicalPublicCoverUrl != null) ...[
                    _buildCanonicalPublicCoverMedia(
                      _canonicalPublicCoverUrl!,
                    ),
                    const SizedBox(height: DetailSpacing.md),
                  ],
                  if (isArtist) ...[
                    _buildArtistHighlightsGrid(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                  ],
                  if (isInstitution)
                    _buildInstitutionHighlights(l10n)
                  else if (!isArtist && (user?.showAchievements ?? true))
                    _buildAchievements(themeProvider, l10n),
                  const SizedBox(height: DetailSpacing.md),
                  _buildStatsRow(l10n),
                ] else ...[
                  // Identity, practice, work, public contribution, community,
                  // recognition, then the numbers. An artist's section is
                  // their portfolio; an institution's is its programme; a
                  // profile that is neither is not given empty artist bands.
                  if (isArtist) ...[
                    _buildArtistHighlightsGrid(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                    _buildArtistEventsShowcase(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                  ],
                  if (isInstitution) ...[
                    _buildInstitutionHighlights(l10n),
                    const SizedBox(height: DetailSpacing.xl),
                  ],
                  _buildAddedPublicArtSection(l10n),
                ],
                const SizedBox(height: DetailSpacing.xl),
                _buildPostsSection(l10n),
                if (!isCanonicalPublicEntry) ...[
                  if (user?.showAchievements ?? true) ...[
                    const SizedBox(height: DetailSpacing.xl),
                    _buildAchievements(themeProvider, l10n),
                  ],
                  // The closing composition: large, expressive, and reachable
                  // because the posts above it are bounded.
                  const SizedBox(height: DetailSpacing.xl),
                  _buildStatsRow(l10n),
                ],
                if (isCanonicalPublicEntry && isArtist) ...[
                  const SizedBox(height: DetailSpacing.xl),
                  _buildArtistEventsShowcase(l10n),
                ],
                const SizedBox(height: DetailSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
    final content = isCanonicalPublicEntry
        ? scaffold
        : ColoredBox(color: roles.ground, child: scaffold);
    return PublicEntityTakeoverReady(
      type: ShareEntityType.profile,
      entityId: widget.userId,
      child: content,
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

  /// Identity first: the cover is the canvas, the avatar and the glass
  /// identity plate sit on it, and Follow/Message belong to the same
  /// composition. Practice follows directly underneath.
  Widget _buildProfileHeader(ThemeProvider themeProvider,
      {required bool isArtist, required bool isInstitution}) {
    final l10n = AppLocalizations.of(context)!;
    final coverImageUrl = _normalizeMediaUrl(user!.coverImageUrl);
    final coverUrlIsKnownBad =
        coverImageUrl != null && coverImageUrl == _failedCoverImageUrl;
    const avatarRadius = 42.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileIdentityHero(
          displayName: user!.name,
          handle: user!.username,
          isVerified: user!.isVerified,
          isArtist: isArtist,
          isInstitution: isInstitution,
          coverImageUrl: coverUrlIsKnownBad ? null : coverImageUrl,
          coverSemanticLabel: user!.name,
          onCoverError: () => _noteFailedCoverImage(coverImageUrl),
          roleLabel: _profileRoleLabel(
            l10n,
            isArtist: isArtist,
            isInstitution: isInstitution,
          ),
          avatarRadius: avatarRadius,
          avatar: AvatarWidget(
            wallet: user!.id,
            avatarUrl: user!.profileImageUrl,
            radius: avatarRadius,
            borderWidth: 0,
            borderColor: Colors.transparent,
            enableProfileNavigation: false,
            heroTag: widget.heroTag,
          ),
          actions: ProfileRelationshipActions(
            isFollowing: user!.isFollowing,
            isFollowLoading: _isFollowMutationInFlight,
            onFollow: () => unawaited(_toggleFollow()),
            onMessage: () => unawaited(_openMessageConversation(l10n)),
            followLabel: l10n.userProfileFollowButton,
            followingLabel: l10n.userProfileFollowingButton,
            messageLabel: l10n.userProfileMessageButtonLabel,
          ),
        ),
        const SizedBox(height: DetailSpacing.lg),
        _buildPracticeBlock(l10n, isArtist: isArtist),
      ],
    );
  }

  void _noteFailedCoverImage(String? url) {
    if (url == null || url.isEmpty) return;
    if (_failedCoverImageUrl == url) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _failedCoverImageUrl = url);
    });
  }

  String _profileRoleLabel(
    AppLocalizations l10n, {
    required bool isArtist,
    required bool isInstitution,
  }) {
    if (isInstitution) return l10n.settingsRoleInstitutionTitle;
    if (isArtist) return l10n.settingsRoleArtistTitle;
    return l10n.userProfileTitle;
  }

  /// Practice before paperwork: the biography carries the weight, the practice
  /// fields support it, and activity and the join date are the quiet last
  /// line rather than cards of their own.
  Widget _buildPracticeBlock(
    AppLocalizations l10n, {
    required bool isArtist,
  }) {
    final roles = KubusColorRoles.of(context);
    final bio = user!.bio.trim();
    final placeLabel = _publicEntryPlaceLabel();
    final hasPracticeFields =
        user!.fieldOfWork.isNotEmpty || user!.yearsActive > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio.isNotEmpty) ...[
          ExpandableDetailText(
            text: bio,
            collapsedMaxLines: 5,
            textAlign: TextAlign.start,
            alignment: CrossAxisAlignment.start,
            style: KubusTextStyles.lede.copyWith(color: roles.foreground),
          ),
          const SizedBox(height: DetailSpacing.md),
        ],
        if (hasPracticeFields) ...[
          ProfileArtistInfoFields(
            fieldOfWork: user!.fieldOfWork,
            yearsActive: user!.yearsActive,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        if (placeLabel != null) ...[
          _buildPublicEntryPlaceLine(placeLabel),
          const SizedBox(height: KubusSpacing.sm),
        ],
        // Secondary by construction: one quiet caption line, not two cards.
        Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.xs,
          children: [
            UserActivityStatusLine(
              walletAddress: user!.id,
              textAlign: TextAlign.start,
              textStyle: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundSubtle,
              ),
            ),
            Text(
              _formatJoinedLabel(l10n, user!.joinedDate),
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundSubtle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCanonicalPublicEntryProfileHero({
    required bool isArtist,
    required bool isInstitution,
    required AppLocalizations l10n,
  }) {
    final profile = user!;
    final roles = KubusColorRoles.of(context);
    final placeLabel = _publicEntryPlaceLabel();
    final roleLabel = isInstitution
        ? l10n.settingsRoleInstitutionTitle
        : isArtist
            ? l10n.settingsRoleArtistTitle
            : l10n.userProfileTitle;
    final titleStyle = KubusTextStyles.responsiveTitleStyle(
      context,
      KubusTypography.content(
        fontSize: 40,
        fontWeight: FontWeight.w700,
      ),
      availableWidth: MediaQuery.sizeOf(context).width - (KubusSpacing.md * 2),
    ).copyWith(height: 1.02, letterSpacing: -0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: KubusSpacing.lg),
        Text(
          roleLabel.toUpperCase(),
          style: KubusTextStyles.structuralLabel.copyWith(
            color: roles.foregroundMuted,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        ProfileIdentityBlock(
          displayName: profile.name,
          handle: profile.username,
          isVerified: profile.isVerified,
          isArtist: isArtist,
          isInstitution: isInstitution,
          density: ProfileIdentityDensity.spacious,
          nameStyle: titleStyle,
          handleStyle: KubusTextStyles.metadataRegister,
          nameColor: roles.foreground,
          handleColor: roles.foregroundMuted,
        ),
        if (placeLabel != null) ...[
          const SizedBox(height: KubusSpacing.sm),
          _buildPublicEntryPlaceLine(placeLabel),
        ],
        if (isArtist) ...[
          const SizedBox(height: KubusSpacing.md),
          _buildPublicEntryArtCount(l10n),
        ],
        Container(
          height: KubusSizes.hairline,
          margin: const EdgeInsets.symmetric(vertical: KubusSpacing.md),
          color: roles.rule,
        ),
        if (profile.bio.trim().isNotEmpty)
          ExpandableDetailText(
            text: profile.bio.trim(),
            collapsedMaxLines: 5,
            style: KubusTextStyles.lede.copyWith(color: roles.foreground),
          ),
        if (isArtist &&
            (profile.fieldOfWork.isNotEmpty || profile.yearsActive > 0)) ...[
          const SizedBox(height: KubusSpacing.md),
          ProfileArtistInfoFields(
            fieldOfWork: profile.fieldOfWork,
            yearsActive: profile.yearsActive,
            textAlign: TextAlign.left,
          ),
        ],
        const SizedBox(height: KubusSpacing.md),
        ProfileRelationshipActions(
          isFollowing: profile.isFollowing,
          isFollowLoading: _isFollowMutationInFlight,
          onFollow: () => unawaited(_toggleFollow()),
          onMessage: () => unawaited(_openMessageConversation(l10n)),
          followLabel: l10n.userProfileFollowButton,
          followingLabel: l10n.userProfileFollowingButton,
          messageLabel: l10n.userProfileMessageButtonLabel,
        ),
      ],
    );
  }

  String? get _canonicalPublicCoverUrl {
    final profile = user;
    if (profile == null) return null;
    final url = _normalizeMediaUrl(profile.coverImageUrl);
    if (url == null || url.isEmpty || url == _failedCoverImageUrl) {
      return null;
    }
    return url;
  }

  Widget _buildCanonicalPublicCoverMedia(String imageUrl) {
    final roles = KubusColorRoles.of(context);
    return AspectRatio(
      aspectRatio: 0.78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          semanticLabel: user?.name,
          errorBuilder: (context, error, stackTrace) {
            if (_failedCoverImageUrl != imageUrl) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _failedCoverImageUrl = imageUrl);
              });
            }
            return ColoredBox(
              color: roles.surfaceRaised,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: roles.foregroundMuted,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _publicEntryPlaceLabel() {
    try {
      return context
          .read<PublicEntityTakeoverProvider>()
          .publicPlaceLabelForCanonicalPath(
            type: 'profile',
            id: widget.userId,
            pathname: Uri.base.path,
          );
    } catch (_) {
      return null;
    }
  }

  Widget _buildPublicEntryPlaceLine(String label) {
    final roles = KubusColorRoles.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.place_outlined,
            size: 17,
            color: roles.foregroundMuted,
          ),
        ),
        const SizedBox(width: KubusSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: KubusTextStyles.bodySmall.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPublicEntryArtCount(AppLocalizations l10n) {
    final roles = KubusColorRoles.of(context);
    return Row(
      children: [
        Text(
          _formatCount(_publicStreetArtAddedCount),
          style: KubusTypography.content(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ).copyWith(color: roles.foreground),
        ),
        const SizedBox(width: KubusSpacing.md),
        Flexible(
          child: Text(
            l10n.profilePerformancePublicStreetArtAddedTitle,
            style: KubusTextStyles.metadataRegister.copyWith(
              color: roles.foregroundMuted,
            ),
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
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: KubusSpacing.md,
          crossAxisSpacing: KubusSpacing.md,
          // Measured tile height so wrapped labels and large text fit.
          mainAxisExtent: KubusStatCard.centeredExtent(
            context,
            valueStyle: _profileStatValueStyle,
            titleStyle: _profileStatTitleStyle,
            padding: _profileStatPadding,
          ),
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

  static const EdgeInsets _profileStatPadding = EdgeInsets.all(KubusSpacing.md);

  TextStyle get _profileStatTitleStyle =>
      KubusTextStyles.detailCaption.copyWith(fontSize: 11.5);

  TextStyle get _profileStatValueStyle => KubusTextStyles.detailCardTitle
      .copyWith(fontSize: 16, fontWeight: FontWeight.w700);

  Widget _buildProfileStatCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return KubusStatCard(
      title: title,
      value: value,
      icon: icon,
      accent: _accentForProfileStat(icon),
      layout: KubusStatCardLayout.centered,
      minHeight: 86,
      padding: _profileStatPadding,
      titleMaxLines: 2,
      onTap: onTap,
      titleStyle: _profileStatTitleStyle,
      valueStyle: _profileStatValueStyle,
    );
  }

  // Mirrors desktop_user_profile_screen's _profileStatAccentForIcon so the
  // stat grid is color-coded the same way on every layout, instead of
  // falling back to the generic ColorScheme roles (which read as one flat
  // hue in this app's dark theme).
  Color _accentForProfileStat(IconData icon) {
    final roles = KubusColorRoles.of(context);
    if (icon == Icons.palette_outlined || icon == AppColorUtils.streetArtIcon) {
      return roles.web3ArtistStudioAccent;
    }
    if (icon == Icons.article_outlined) {
      return roles.statBlue;
    }
    if (icon == Icons.people_outline) {
      return roles.statCoral;
    }
    if (icon == Icons.person_add_alt_outlined) {
      return roles.statTeal;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Future<void> _openMessageConversation(AppLocalizations l10n) async {
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      requirements: ProtectedActionRequirements.participant,
      context,
      actionLabel: l10n.userProfileMessageButtonLabel.toLowerCase(),
      returnRoute: '/u/${Uri.encodeComponent(widget.userId)}',
    );
    if (!authenticated || !mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // navigator variable no longer used; ConversationNavigator handles
    // navigation.
    final messenger = ScaffoldMessenger.of(context);
    final chatAuth = chatProvider.isAuthenticated;
    try {
      final conv = await chatProvider.createConversation('', false, [user!.id]);
      if (conv != null) {
        if (!mounted) return;
        final preloaded = Provider.of<ChatProvider>(context, listen: false)
            .getPreloadedProfileMapsForConversation(conv.id);
        // Ensure we pass non-empty members and sensible fallbacks for
        // avatars / display names.
        final rawMembers =
            (preloaded['members'] as List<dynamic>?)?.cast<String>() ??
                <String>[];
        final members = rawMembers.isNotEmpty ? rawMembers : <String>[user!.id];
        final rawAvatars = (preloaded['avatars'] as Map<String, String?>?) ??
            <String, String?>{};
        final avatars = Map<String, String?>.from(rawAvatars);
        if (!avatars.containsKey(members.first) ||
            (avatars[members.first] == null ||
                avatars[members.first]!.isEmpty)) {
          avatars[members.first] = user!.profileImageUrl;
        }
        final rawNames = (preloaded['names'] as Map<String, String?>?) ??
            <String, String?>{};
        final names = Map<String, String?>.from(rawNames);
        if (!names.containsKey(members.first) ||
            (names[members.first] == null || names[members.first]!.isEmpty)) {
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
                content: Text(l10n.userProfileMessageLoginRequiredToast),
              ),
            );
          }
        } else {
          if (mounted) {
            messenger.showKubusSnackBar(
              SnackBar(
                content: Text(l10n.userProfileConversationOpenFailedToast),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('UserProfileScreen: failed to open conversation: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.userProfileConversationOpenGenericErrorToast),
        ),
      );
    }
  }

  /// Canonical identity followed by the canonical Follow/Message relationship
  /// actions, rendered below the cover. [ProfileIdentityBlock] guarantees the
  /// handle its own never-ellipsized line, so neither the actions nor the role
  /// badges can truncate it.
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
      // Visitors should not scroll past an empty-state card for a
      // section the profile owner has no content in.
      showWhenEmpty: false,
    );
  }

  /// A bounded preview, never a feed. See [ProfilePostsPreviewSection].
  Widget _buildPostsSection(AppLocalizations l10n) {
    return ProfilePostsPreviewSection(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      posts: _posts,
      isLoading: _postsLoading,
      error: _postsError,
      onRetry: _loadPosts,
      totalCount: user?.postsCount,
      accentColor:
          Provider.of<ThemeProvider>(context, listen: false).accentColor,
      emptyDescription: l10n.userProfileNoPostsDescription(user!.name),
      onOpenPost: (post) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PostDetailScreen(post: post),
        ),
      ),
      onViewAll: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ProfilePostsScreen(
            userId: widget.userId,
            username: user?.username,
            displayName: user?.name,
          ),
        ),
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
      kind: KubusEntityKind.artwork,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: card.subtitle,
      meta: l10n.userProfileLikesLabel(card.likesCount),
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
      kind: KubusEntityKind.collection,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: l10n.userProfileArtworksCountLabel(card.artworkCount),
      meta: card.description ?? l10n.userProfileCuratedByLabel(user!.name),
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
      kind: KubusEntityKind.event,
      imageUrl: card.imageUrl,
      title: card.title,
      subtitle: dateLabel,
      meta: card.location ?? l10n.commonTba,
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

  /// One shared entity preview for every showcase rail on this screen: the
  /// media is the subject, the title and its context read off the plate, and
  /// the category accent and glyph come from [KubusEntitySemantics].
  Widget _buildShowcaseCard({
    required KubusEntityKind kind,
    String? imageUrl,
    required String title,
    required String subtitle,
    required String meta,
    VoidCallback? onTap,
  }) {
    return KubusEntityCard(
      variant: KubusEntityCardVariant.media,
      kind: kind,
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      meta: meta,
      onTap: onTap,
      width: 200,
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
