import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/inline_loading.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../config/config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/community_hub_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../providers/community_subject_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/community_comments_provider.dart';
import '../../../providers/community_interactions_provider.dart';
import '../../../community/community_interactions.dart';
import '../../../models/community_group.dart';
import '../../../models/conversation.dart';
import '../../../models/promotion.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/profile_package_mutation_tracker.dart';
import '../../../services/block_list_service.dart';
import '../../../services/community_post_save_controller.dart';
import '../../../services/user_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart' as share_types;
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/user_activity_status_line.dart';
import '../../../widgets/community/community_post_card.dart';
import '../../../widgets/community/community_author_role_badges.dart';
import '../../../widgets/community/community_post_options_sheet.dart';
import '../../../widgets/community/community_subject_picker.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/artwork_navigation.dart';
import '../../../utils/community_screen_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/home/home_quick_action_executor.dart';
import '../../../utils/home/home_quick_action_models.dart';
import '../../../utils/institution_navigation.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/creator_display_format.dart';
import '../../../utils/search_suggestions.dart';
import '../../../utils/user_profile_navigation.dart';
import '../../../utils/profile_identity_navigation.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/community_subject_navigation.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/community/community_composer_controls.dart';
import '../../../widgets/community/community_composer_layout.dart';
import '../../../widgets/search/kubus_general_search.dart' as kubus_search;
import '../../../widgets/search/kubus_search_config.dart';
import '../../../widgets/search/kubus_search_controller.dart';
import '../../../widgets/search/kubus_search_result.dart';
import '../../../widgets/community/community_search_actions.dart';
import '../../../widgets/community/community_search_bar.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../../widgets/community/community_expandable_fab.dart';
import '../../../widgets/community/community_group_card.dart';
import '../../../widgets/community/community_group_picker_content.dart';
import '../../../widgets/community/community_likes_sheet.dart';
import '../../../widgets/profile_identity_summary.dart';
import '../../community/group_feed_screen.dart';
import '../../community/conversation_screen.dart';
import '../../community/post_detail_screen.dart';
import '../../download_app_screen.dart';
import '../../map_screen.dart';
import '../../season0/season0_screen.dart';
import '../../web3/achievements/achievements_page.dart';
import '../../../widgets/community/community_season0_banner.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

part 'desktop_community_screen_parts/desktop_community_screen_p1.dart';
part 'desktop_community_screen_parts/desktop_community_screen_p2.dart';
part 'desktop_community_screen_parts/desktop_community_screen_p3.dart';
part 'desktop_community_screen_parts/desktop_community_screen_p4.dart';
part 'desktop_community_screen_parts/desktop_community_screen_p5.dart';
part 'desktop_community_screen_parts/desktop_community_screen_p6.dart';
class _ComposerImagePayload {
  final Uint8List bytes;
  final String fileName;

  const _ComposerImagePayload({
    required this.bytes,
    required this.fileName,
  });
}

/// Desktop community screen with Twitter/Instagram-style feed
/// Features multi-column layout with trending and suggestions
class DesktopCommunityScreen extends StatefulWidget {
  const DesktopCommunityScreen({super.key});

  @override
  State<DesktopCommunityScreen> createState() => _DesktopCommunityScreenState();
}

class _DesktopCommunityScreenState extends State<DesktopCommunityScreen>
    with TickerProviderStateMixin {
  /// setState shim for methods extracted into part-file extensions
  /// (State.setState is @protected and not callable from extensions).
  void _applyState(VoidCallback fn) => setState(fn);

  late AnimationController _animationController;
  late TabController _tabController;
  late TextEditingController _groupSearchController;
  late KubusSearchController _communitySearchController;
  late TextEditingController _messageSearchController;
  Timer? _groupSearchDebounce;
  bool _isFabExpanded = false;
  final List<String> _tabs = ['discover', 'following', 'groups', 'art'];
  final BackendApiService _backendApi = BackendApiService();
  bool _showComposeDialog = false;
  bool _showMessagesPanel = false;
  bool _isComposerExpanded = false;
  bool _isPosting = false;
  int _lastHandledComposerOpenNonce = 0;
  final TextEditingController _composeController = TextEditingController();
  final List<_ComposerImagePayload> _selectedImages = [];
  String? _selectedLocation;
  String _selectedCategory = 'post';
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  List<Map<String, dynamic>> _trendingTopics = [];
  bool _isLoadingTrending = false;
  String? _trendingError;
  bool _trendingFromFeed = false;
  List<Map<String, dynamic>> _suggestedArtists = [];
  bool _isLoadingSuggestions = false;
  String? _suggestionsError;
  String? _activeConversationId;
  String _messageSearchQuery = '';
  final List<_PaneRoute> _paneStack = [];
  final Map<String, _TagFeedState> _tagFeeds = {};
  String _discoverSortMode = 'hybrid';
  String _followingSortMode = 'hybrid';
  String _artSortMode = 'hybrid';


  AppRefreshProvider? _appRefreshProvider;
  int _lastCommunityRefreshVersion = 0;
  int _lastGlobalRefreshVersion = 0;
  bool _refreshInFlight = false;
  Set<String> _followingWallets = <String>{};
  final Set<String> _followRequestsInFlight = <String>{};
  final Set<String> _deleteDialogOpenPostIds = <String>{};
  final Set<String> _deleteInFlightPostIds = <String>{};

  // Feed state for different tabs
  List<CommunityPost> _discoverPosts = [];
  List<CommunityPost> _followingPosts = [];
  bool _isLoadingDiscover = false;
  bool _isLoadingFollowing = false;
  bool _discoverFeedLoaded = false;
  bool _followingFeedLoaded = false;
  String? _discoverError;
  String? _followingError;

  // Inline comments state (matching mobile behavior)
  final Set<String> _expandedCommentPostIds = <String>{};
  final Map<String, TextEditingController> _inlineCommentControllers =
      <String, TextEditingController>{};
  final Map<String, String?> _inlineReplyToCommentIds = <String, String?>{};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_isFabExpanded) {
        setState(() => _isFabExpanded = false);
      }
      setState(() {}); // refresh FAB options per tab like mobile
      _ensureActiveTabLoaded();
    });
    _groupSearchController = TextEditingController();
    _communitySearchController = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.community,
        limit: 12,
      ),
    );
    _communitySearchController.addListener(_handleSearchControllerChanged);
    _messageSearchController = TextEditingController();
    _messageSearchController.addListener(_handleMessageSearchChanged);
    _animationController.forward();

    // Load community feed data first; sidebar/profile work is deferred until
    // the active feed has had a chance to render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialCommunityLoad();

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
  void dispose() {
    _appRefreshProvider?.removeListener(_onAppRefreshTriggered);
    _animationController.dispose();
    _tabController.dispose();
    _groupSearchDebounce?.cancel();
    _groupSearchController.dispose();
    _communitySearchController
      ..removeListener(_handleSearchControllerChanged)
      ..dispose();
    _messageSearchController.removeListener(_handleMessageSearchChanged);
    _messageSearchController.dispose();
    _tagController.dispose();
    _mentionController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CommunityHubProvider>();
    _maybeHandleComposerOpenRequest(hub);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final isMedium = screenWidth >= 900 && screenWidth < 1200;

    return DesktopProfilePresentationScope(
      presentation: DesktopProfilePresentation.communityOverlay,
      child: PopScope(
        canPop: _paneStack.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_paneStack.isNotEmpty) {
            _popPane();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main feed
                  Expanded(
                    flex: isLarge ? 3 : 2,
                    child: _buildMainFeed(themeProvider, animationTheme),
                  ),

                  // Right sidebar
                  if (isMedium || isLarge)
                    SizedBox(
                      width: isLarge ? 360 : 300,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : scheme.outline.withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                        ),
                        child: LiquidGlassPanel(
                          padding: EdgeInsets.zero,
                          margin: EdgeInsets.zero,
                          borderRadius: BorderRadius.zero,
                          showBorder: false,
                          backgroundColor: scheme.surface
                              .withValues(alpha: isDark ? 0.16 : 0.10),
                          child: _buildRightSidebar(themeProvider),
                        ),
                      ),
                    ),
                ],
              ),

              kubus_search.KubusSearchResultsOverlay(
                controller: _communitySearchController,
                accentColor: themeProvider.accentColor,
                minCharsHint: AppLocalizations.of(context)!
                    .desktopCommunitySearchMinCharsHint,
                noResultsText: AppLocalizations.of(context)!
                    .desktopCommunitySearchNoResults,
                maxWidth: 320,
                onResultTap: (result) {
                  unawaited(_handleSearchResultTap(result));
                },
              ),

              // Compose dialog
              if (_showComposeDialog) _buildComposeDialog(themeProvider),
            ],
          ),
        ),
      ),
    );
  }




























































































































}

enum _PaneViewType { tagFeed, postDetail, conversation }

class _PaneRoute {
  const _PaneRoute.tag(this.tag)
      : type = _PaneViewType.tagFeed,
        post = null,
        conversation = null,
        initialAction = null;

  const _PaneRoute.post(this.post, {this.initialAction})
      : type = _PaneViewType.postDetail,
        tag = null,
        conversation = null;

  const _PaneRoute.conversation(this.conversation)
      : type = _PaneViewType.conversation,
        tag = null,
        post = null,
        initialAction = null;

  final _PaneViewType type;
  final String? tag;
  final CommunityPost? post;
  final Conversation? conversation;
  final PostDetailInitialAction? initialAction;

  String get viewKey {
    switch (type) {
      case _PaneViewType.tagFeed:
        return 'tag-${(tag ?? '').toLowerCase()}';
      case _PaneViewType.postDetail:
        return 'post-${post?.id ?? ''}-${initialAction?.name ?? 'view'}';
      case _PaneViewType.conversation:
        return 'conversation-${conversation?.id ?? ''}';
    }
  }
}

class _TagFeedState {
  final List<CommunityPost> posts;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;
  final bool followingOnly;
  final bool arOnly;
  final String sortMode; // 'popularity' or 'recent'

  const _TagFeedState({
    this.posts = const <CommunityPost>[],
    this.isLoading = false,
    this.error,
    this.lastFetched,
    this.followingOnly = false,
    this.arOnly = false,
    this.sortMode = 'popularity',
  });

  _TagFeedState copyWith({
    List<CommunityPost>? posts,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool? followingOnly,
    bool? arOnly,
    String? sortMode,
  }) {
    return _TagFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
      followingOnly: followingOnly ?? this.followingOnly,
      arOnly: arOnly ?? this.arOnly,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

/// Dialog to start a new conversation
class _NewConversationDialog extends StatefulWidget {
  final ThemeProvider themeProvider;
  final Function(String) onStartConversation;

  const _NewConversationDialog({
    required this.themeProvider,
    required this.onStartConversation,
  });

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final BackendApiService _backendApi = BackendApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final resp =
            await _backendApi.search(query: query, type: 'profiles', limit: 20);
        final parsed = _parseProfileSearchResults(resp);
        if (!mounted) return;
        setState(() {
          _searchResults = parsed;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _parseProfileSearchResults(
      Map<String, dynamic> payload) {
    final results = <Map<String, dynamic>>[];

    void addEntries(List<dynamic>? entries) {
      if (entries == null) return;
      for (final item in entries) {
        if (item is Map<String, dynamic>) {
          results.add(item);
        } else if (item is Map) {
          final mapped = <String, dynamic>{};
          item.forEach((key, value) {
            mapped[key.toString()] = value;
          });
          results.add(mapped);
        }
      }
    }

    final dynamic resultsNode = payload['results'];
    if (resultsNode is Map<String, dynamic>) {
      addEntries((resultsNode['profiles'] as List?) ??
          (resultsNode['results'] as List?));
    } else if (resultsNode is List) {
      addEntries(resultsNode);
    }

    final dynamic dataNode = payload['data'];
    if (dataNode is Map<String, dynamic>) {
      addEntries(
          (dataNode['profiles'] as List?) ?? (dataNode['results'] as List?));
    } else if (dataNode is List) {
      addEntries(dataNode);
    }

    if (results.isEmpty) {
      addEntries(payload['profiles'] as List?);
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: KubusHeaderText(
                    title: AppLocalizations.of(context)!
                        .desktopCommunityNewMessageTitle,
                    kind: KubusHeaderKind.section,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.18),
                ),
              ),
              child: LiquidGlassPanel(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(KubusRadius.md),
                blurSigma: KubusGlassStyle.resolve(
                  context,
                  surfaceType: KubusGlassSurfaceType.card,
                  tintBase: Theme.of(context).colorScheme.surface,
                ).blurSigma,
                fallbackMinOpacity: KubusGlassStyle.resolve(
                  context,
                  surfaceType: KubusGlassSurfaceType.card,
                  tintBase: Theme.of(context).colorScheme.surface,
                ).fallbackMinOpacity,
                showBorder: false,
                backgroundColor: KubusGlassStyle.resolve(
                  context,
                  surfaceType: KubusGlassSurfaceType.card,
                  tintBase: Theme.of(context).colorScheme.surface,
                ).tintColor,
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: AppLocalizations.of(context)!
                          .desktopCommunitySearchUsersHint,
                      hintStyle: KubusTextStyles.sectionSubtitle.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    style: KubusTextStyles.sectionSubtitle,
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _isLoading
                  ? const Center(child: InlineLoading(width: 40, height: 40))
                  : _isSearching && _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)!
                                    .desktopCommunitySearchUsersToMessageHint,
                                style: KubusTextStyles.sectionSubtitle.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final wallet = (user['wallet_address'] ??
                                        user['walletAddress'] ??
                                        user['wallet'] ??
                                        user['id'])
                                    ?.toString() ??
                                '';
                            final rawUsername =
                                (user['username'] ?? '').toString().trim();
                            final username = rawUsername.startsWith('@')
                                ? rawUsername.substring(1).trim()
                                : rawUsername;
                            final displayName =
                                (user['displayName'] ?? user['display_name'])
                                    ?.toString()
                                    .trim();
                            final formatted = CreatorDisplayFormat.format(
                              fallbackLabel: wallet.isNotEmpty
                                  ? maskWallet(wallet)
                                  : AppLocalizations.of(context)!.commonUser,
                              displayName: displayName,
                              username: username,
                              wallet: wallet,
                            );
                            final subtitle = formatted.secondary ??
                                (wallet.isNotEmpty ? maskWallet(wallet) : null);
                            final avatarUrl = user['avatar'] ??
                                user['avatar_url'] ??
                                user['profileImageUrl'] ??
                                user['profileImage'];
                            return ListTile(
                              leading: AvatarWidget(
                                wallet: wallet,
                                avatarUrl: avatarUrl?.toString(),
                                radius: 20,
                                allowFabricatedFallback: true,
                              ),
                              title: Text(formatted.primary),
                              subtitle: subtitle == null || subtitle.isEmpty
                                  ? null
                                  : Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: wallet.isEmpty
                                  ? null
                                  : () => widget.onStartConversation(wallet),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchResult {
  final Conversation conversation;
  final double score;
  final String? highlight;

  const _ConversationSearchResult({
    required this.conversation,
    required this.score,
    this.highlight,
  });
}
