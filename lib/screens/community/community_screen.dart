// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore

import 'package:art_kubus/widgets/glass_components.dart';
// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../config/config.dart';
import '../../utils/wallet_utils.dart';
import '../../utils/search_suggestions.dart';
import '../../utils/user_profile_navigation.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/common/keyboard_inset_padding.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/profile_identity_summary.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/community/community_post_options_sheet.dart';
import '../../widgets/community/community_subject_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'dart:io';
import '../../providers/themeprovider.dart';
import '../../providers/config_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../providers/community_comments_provider.dart';
import '../../providers/community_interactions_provider.dart';
import '../../providers/community_subject_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/community_group.dart';
import '../../services/backend_api_service.dart';
import '../../services/community_post_save_controller.dart';
import '../../services/contextual_auth_gate.dart';
import '../../services/profile_package_mutation_tracker.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart' as share_types;
import '../../services/block_list_service.dart';
import '../map_screen.dart';
import 'post_detail_screen.dart';
import 'group_feed_screen.dart';
import '../web3/achievements/achievements_page.dart';
import '../../community/community_interactions.dart';
import '../../providers/app_refresh_provider.dart';
import '../../services/socket_service.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recent_activity_provider.dart';
import '../../providers/chat_provider.dart';
import 'messages_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/app_animations.dart';
import '../../utils/activity_navigation.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/community_screen_utils.dart';
import '../../utils/home/home_quick_action_executor.dart';
import '../../utils/home/home_quick_action_models.dart';
import '../../utils/institution_navigation.dart';
import '../../widgets/community/community_composer_controls.dart';
import '../../widgets/community/community_composer_layout.dart';
import '../../widgets/community/community_expandable_fab.dart';
import '../../widgets/community/community_group_card.dart';
import '../../widgets/community/community_group_picker_content.dart';
import '../../widgets/community/community_likes_sheet.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/community_subject_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/profile_identity_navigation.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/community/community_season0_banner.dart';
import '../../widgets/community/community_search_actions.dart';
import '../../widgets/community/community_search_bar.dart';
import '../season0/season0_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../widgets/search/kubus_search_config.dart';
import '../../widgets/search/kubus_search_controller.dart';
import '../../widgets/search/kubus_search_result.dart';
import '../../widgets/search/kubus_general_search.dart' as kubus_search;
import '../../widgets/notifications/kubus_notifications_sheet.dart';

part 'community_screen_parts/community_screen_p1.dart';
part 'community_screen_parts/community_screen_p2.dart';
part 'community_screen_parts/community_screen_p3.dart';
part 'community_screen_parts/community_screen_p4.dart';
part 'community_screen_parts/community_screen_p5.dart';
enum CommunityFeedType {
  following,
  discover,
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with TickerProviderStateMixin {
  /// setState shim for methods extracted into part-file extensions
  /// (State.setState is @protected and not callable from extensions).
  void _applyState(VoidCallback fn) => setState(fn);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _bellController;
  late Animation<double> _bellScale;
  late AnimationController _messagePulseController;
  late Animation<double> _messageScale;
  int _messageUnreadCount = 0;
  int _bellUnreadCount = 0;
  bool _animationsInitialized = false;
  int _lastHandledComposerOpenNonce = 0;

  late TabController _tabController;

  static const int _tabCount = 4;

  // Community data
  List<CommunityPost> _communityPosts = [];
  List<CommunityPost> _followingFeedPosts = [];
  List<CommunityPost> _discoverFeedPosts = [];
  List<CommunityPost> _artFeedPosts = [];
  final Set<String> _expandedCommentPostIds = <String>{};
  final Map<String, TextEditingController> _inlineCommentControllers =
      <String, TextEditingController>{};
  final Map<String, String?> _inlineReplyToCommentIds = <String, String?>{};
  bool _isLoading = false;
  bool _isLoadingFollowingFeed = false;
  bool _isLoadingDiscoverFeed = false;
  bool _followingFeedLoaded = false;
  bool _discoverFeedLoaded = false;
  bool _isLoadingArtFeed = false;
  CommunityFeedType _activeFeed = CommunityFeedType.following;
  // Deduplication and local push are now handled centrally by NotificationProvider
  final Map<int, bool> _bookmarkedPosts = {};
  // Avatar cache removed - ChatProvider or UserService are used for user avatars
  // Scroll controller for the feed to detect when user is away from top
  late ScrollController _feedScrollController;
  bool _artFeedLoadMoreInFlight = false;
  late final TextEditingController _groupSearchController;
  late final KubusSearchController _communitySearchController;
  Timer? _groupSearchDebounce;
  final Set<String> _groupActionsInFlight = <String>{};
  final Set<String> _deleteDialogOpenPostIds = <String>{};
  final Set<String> _deleteInFlightPostIds = <String>{};

  // Buffered incoming posts when user is scrolled away from top
  final List<CommunityPost> _bufferedIncomingPosts = [];
  // Keep ids of posts we just created locally to suppress duplicate socket echoes
  final Set<String> _recentlyCreatedPostIds = <String>{};
  String? _artFeedError;

  // New post state
  final TextEditingController _newPostController = TextEditingController();
  TextEditingController? _composerTagController;
  TextEditingController? _composerMentionController;
  bool _isPostingNew = false;
  XFile? _selectedPostImage;
  Uint8List? _selectedPostImageBytes; // Store bytes for preview
  XFile? _selectedPostVideo;
  // Location selected by user when creating a new post; may be null.
  // selectedLocation removed; location name is used in the UI when creating posts
  double? _artFeedLatitude;
  double? _artFeedLongitude;
  String? _lastWalletAddress;
  AppRefreshProvider? _appRefreshProvider;
  int _lastCommunityRefreshVersion = 0;
  int _lastGlobalRefreshVersion = 0;
  bool _communityReloadInFlight = false;
  bool _combinedFeedLoadInFlight = false;

  // Expandable FAB state
  bool _isFabExpanded = false;



















  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _groupSearchController = TextEditingController();
    _communitySearchController = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.community,
        limit: 12,
      ),
    );
    _communitySearchController
        .addListener(_handleCommunitySearchControllerChanged);
    // Load following feed by default
    _communityPosts = _followingFeedPosts;
    _activeFeed = CommunityFeedType.following;
    try {
      _lastWalletAddress = Provider.of<WalletProvider>(context, listen: false)
          .currentWalletAddress;
    } catch (_) {}
    _startInitialCommunityLoad();

    // Listen for tab changes to load appropriate content
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final idx = _tabController.index;
      if (idx == 0) {
        _activateFeed(CommunityFeedType.following);
      } else if (idx == 1) {
        _activateFeed(CommunityFeedType.discover);
      } else if (idx == 2) {
        _ensureGroupsLoaded();
      } else if (idx == 3) {
        _ensureArtFeedLoaded();
      }
    });

    // Initialize bookmark and follow data
    for (int i = 0; i < 10; i++) {
      _bookmarkedPosts[i] = false;
    }

    // Feed scroll controller to detect whether user is at top
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(() {
      try {
        // If user scrolled to near-top and we have buffered posts, prepend them
        if (_feedScrollController.hasClients &&
            _feedScrollController.offset <= 120 &&
            _bufferedIncomingPosts.isNotEmpty) {
          _prependBufferedPosts();
        }
      } catch (_) {}
    });

    // Listen for config provider changes to reload data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      configProvider.addListener(_onConfigChanged);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        walletProvider.addListener(_onWalletProviderChanged);
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _appRefreshProvider =
            Provider.of<AppRefreshProvider>(context, listen: false);
        _lastCommunityRefreshVersion =
            _appRefreshProvider?.communityVersion ?? 0;
        _lastGlobalRefreshVersion = _appRefreshProvider?.globalVersion ?? 0;
        _appRefreshProvider?.addListener(_onAppRefreshTriggered);
      } catch (_) {}
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationsInitialized) {
      _animationsInitialized = true;
      final animationTheme = context.animationTheme;

      _animationController = AnimationController(
        duration: animationTheme.long,
        vsync: this,
      );

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

      _bellController = AnimationController(
        duration: animationTheme.short,
        vsync: this,
      );

      _bellScale = Tween<double>(begin: 1.0, end: 1.18).animate(CurvedAnimation(
        parent: _bellController,
        curve: animationTheme.emphasisCurve,
      ));

      _messagePulseController = AnimationController(
        duration: animationTheme.short,
        vsync: this,
      );
      _messageScale = Tween<double>(begin: 1.0, end: 1.12).animate(
          CurvedAnimation(
              parent: _messagePulseController,
              curve: animationTheme.defaultCurve));

      _animationController.forward();
    }
  }

  DateTime? _lastConfigChange;


  // Helper to get user avatar from backend
  // _getUserAvatar removed (unused) — avatars are now resolved via UserService and ChatProvider caching

  @override
  void dispose() {
    // Remove config provider listener
    try {
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      configProvider.removeListener(_onConfigChanged);
    } catch (e) {
      // Provider may not be available during dispose
    }

    _animationController.dispose();
    try {
      SocketService()
          .removeNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    try {
      Provider.of<NotificationProvider>(context, listen: false)
          .removeListener(_onNotificationProviderChange);
    } catch (_) {}
    _bellController.dispose();
    _messagePulseController.dispose();
    try {
      Provider.of<ChatProvider>(context, listen: false)
          .removeListener(_onChatProviderChanged);
    } catch (_) {}
    try {
      Provider.of<WalletProvider>(context, listen: false)
          .removeListener(_onWalletProviderChanged);
    } catch (_) {}
    try {
      _appRefreshProvider?.removeListener(_onAppRefreshTriggered);
    } catch (_) {}
    try {
      SocketService().removePostListener(_handleIncomingPost);
    } catch (_) {}
    try {
      _feedScrollController.dispose();
    } catch (_) {}
    _groupSearchDebounce?.cancel();
    _groupSearchController.dispose();
    _communitySearchController
      ..removeListener(_handleCommunitySearchControllerChanged)
      ..dispose();
    _composerTagController?.dispose();
    _composerMentionController?.dispose();
    for (final controller in _inlineCommentControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }






  @override
  Widget build(BuildContext context) {
    final composerOpenNonce = context
        .select<CommunityHubProvider, int>((hub) => hub.composerOpenNonce);
    _maybeHandleComposerOpenRequest(composerOpenNonce);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: NestedScrollView(
                      controller: _feedScrollController,
                      headerSliverBuilder:
                          (BuildContext context, bool innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: _buildAppBar(),
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeedTab(),
                          _buildDiscoverTab(),
                          _buildGroupsTab(),
                          _buildArtTab(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            kubus_search.KubusSearchResultsOverlay(
              controller: _communitySearchController,
              accentColor: context.read<ThemeProvider>().accentColor,
              minCharsHint: AppLocalizations.of(context)!
                  .desktopCommunitySearchMinCharsHint,
              noResultsText:
                  AppLocalizations.of(context)!.communitySearchEmptyNoResults,
              maxWidth: 520,
              onResultTap: (result) {
                unawaited(_handleCommunitySearchResultTap(result));
              },
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: KubusLayout.mainBottomNavBarHeight,
            ),
            child: _buildFloatingActionButton(),
          );
        },
      ),
    );
  }







  // Unread notification count is now managed via NotificationProvider.












  String get _communitySearchQuery {
    return _communitySearchController.state.query.trim();
  }

  String get _normalizedCommunityFeedQuery {
    final query = _communitySearchQuery.toLowerCase();
    return query.startsWith('#') ? query.substring(1) : query;
  }




















  bool get _hasSelectedMedia =>
      _selectedPostImageBytes != null || _selectedPostVideo != null;













































}

