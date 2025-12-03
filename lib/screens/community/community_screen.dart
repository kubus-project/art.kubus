// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/empty_state_card.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'dart:io';
import 'dart:math' as math;
import '../../providers/themeprovider.dart';
import '../../providers/config_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../models/community_group.dart';
import '../../services/backend_api_service.dart';
import '../../services/push_notification_service.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'group_feed_screen.dart';
import '../../community/community_interactions.dart';
import '../../services/user_service.dart';
import '../../providers/app_refresh_provider.dart';
import '../../services/socket_service.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import 'messages_screen.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/app_animations.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';

enum CommunityFeedType {
  following,
  discover,
}

class _ComposerCategoryOption {
  final String value;
  final String label;
  final IconData icon;
  final String description;

  const _ComposerCategoryOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });
}

class CommunityScreen extends StatefulWidget {

  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
  with TickerProviderStateMixin {
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

  late TabController _tabController;

  final List<String> _tabs = ['Following', 'Discover', 'Groups', 'Art'];

  static const List<_ComposerCategoryOption> _composerCategories = [
    _ComposerCategoryOption(
      value: 'post',
      label: 'Post',
      icon: Icons.edit_outlined,
      description: 'Share an update with the community',
    ),
    _ComposerCategoryOption(
      value: 'art_drop',
      label: 'Art drop',
      icon: Icons.view_in_ar_outlined,
      description: 'Highlight a location-based activation',
    ),
    _ComposerCategoryOption(
      value: 'event',
      label: 'Event',
      icon: Icons.event_outlined,
      description: 'Announce meetups and gatherings',
    ),
    _ComposerCategoryOption(
      value: 'question',
      label: 'Question',
      icon: Icons.help_outline,
      description: 'Ask the community for feedback',
    ),
  ];

  // Community data
  List<CommunityPost> _communityPosts = [];
  List<CommunityPost> _followingFeedPosts = [];
  List<CommunityPost> _discoverFeedPosts = [];
  List<CommunityPost> _artFeedPosts = [];
  // How many posts to prefetch comments for (make configurable)
  final int _commentPrefetchCount = 8;
  final int _prefetchConcurrencyLimit = 3;
  final int _prefetchMaxRetries = 3;
  final int _prefetchBaseDelayMs = 300; // milliseconds
  bool _isLoading = false;
  bool _isLoadingFollowingFeed = false;
  bool _isLoadingDiscoverFeed = false;
  bool _isLoadingArtFeed = false;
  CommunityFeedType _activeFeed = CommunityFeedType.following;
  // Deduplication and local push are now handled centrally by NotificationProvider
  final Map<int, bool> _bookmarkedPosts = {};
  // Avatar cache removed - ChatProvider or UserService are used for user avatars
  // Scroll controller for the feed to detect when user is away from top
  late ScrollController _feedScrollController;
  late final TextEditingController _groupSearchController;
  Timer? _groupSearchDebounce;
  final Set<String> _groupActionsInFlight = <String>{};

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
  
  // Expandable FAB state
  bool _isFabExpanded = false;

  void _onGroupSearchChanged(String value) {
    _groupSearchDebounce?.cancel();
    _groupSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final hub = Provider.of<CommunityHubProvider>(context, listen: false);
        await hub.loadGroups(refresh: true, search: value.trim());
      } catch (e) {
        debugPrint('Failed to search community groups: $e');
      }
    });
  }

  Future<void> _ensureGroupsLoaded({bool force = false}) async {
    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      if (!force && (hub.groupsInitialized || hub.groupsLoading)) {
        return;
      }
      await hub.loadGroups(refresh: force);
    } catch (e) {
      debugPrint('Failed to load community groups: $e');
      _showSnack('Unable to refresh community groups right now.');
    }
  }

  Future<void> _handleGroupMembershipToggle(CommunityGroupSummary group) async {
    if (_groupActionsInFlight.contains(group.id)) return;
    setState(() {
      _groupActionsInFlight.add(group.id);
    });
    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      if (group.isMember) {
        await hub.leaveGroup(group.id);
      } else {
        await hub.joinGroup(group.id);
      }
    } catch (e) {
      debugPrint('Failed to update group membership: $e');
      _showSnack('Could not update your group membership. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _groupActionsInFlight.remove(group.id);
        });
      }
    }
  }

  List<Widget> _buildAuthorRoleBadges(CommunityPost post, {double fontSize = 10, bool useOnPrimary = false}) {
    final widgets = <Widget>[];
    if (post.authorIsArtist) {
      widgets.add(const SizedBox(width: 6));
      widgets.add(ArtistBadge(
        fontSize: fontSize,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        useOnPrimary: useOnPrimary,
        iconOnly: true,
      ));
    }
    if (post.authorIsInstitution) {
      widgets.add(const SizedBox(width: 6));
      widgets.add(InstitutionBadge(
        fontSize: fontSize,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        useOnPrimary: useOnPrimary,
        iconOnly: true,
      ));
    }
    return widgets;
  }

  void _openGroupFeed(CommunityGroupSummary group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupFeedScreen(group: group),
      ),
    );
  }

  Future<loc.LocationData?> _obtainCurrentLocation() async {
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showSnack('Enable location services to view nearby art posts.');
          return null;
        }
      }

      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        _showSnack('Location permission is required to load art near you.');
        return null;
      }

      final locationData = await location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        _showSnack('Unable to determine your current location.');
        return null;
      }
      return locationData;
    } catch (e) {
      debugPrint('Location error: $e');
      _showSnack('Unable to access location services.');
      return null;
    }
  }

  Future<void> _ensureArtFeedLoaded({bool force = false}) async {
    if (_isLoadingArtFeed && !force) return;
    if (!force && _artFeedPosts.isNotEmpty) return;

    setState(() {
      _isLoadingArtFeed = true;
      _artFeedError = null;
    });

    final locationData = await _obtainCurrentLocation();
    if (!mounted) return;
    if (locationData == null) {
      setState(() {
        _isLoadingArtFeed = false;
        _artFeedError = 'Location permission required to load art feed.';
      });
      return;
    }

    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      await hub.loadArtFeed(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
      );
      if (!mounted) return;
      setState(() {
        _artFeedLatitude = locationData.latitude;
        _artFeedLongitude = locationData.longitude;
        _artFeedPosts = List<CommunityPost>.from(hub.artFeedPosts);
        _isLoadingArtFeed = false;
        _artFeedError = hub.artFeedError;
      });
    } catch (e) {
      debugPrint('Failed to load art feed: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingArtFeed = false;
        _artFeedError = 'Failed to load nearby art posts.';
      });
      _showSnack('Unable to load nearby art posts. Please try again.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadCommunityData({bool? followingOnly, bool force = false}) async {
    final bool targetFollowing =
        followingOnly ?? (_activeFeed == CommunityFeedType.following);
    final bool isActiveFeed =
        (_activeFeed == CommunityFeedType.following && targetFollowing) ||
            (_activeFeed == CommunityFeedType.discover && !targetFollowing);

    if (targetFollowing) {
      if (_isLoadingFollowingFeed && !force) return;
    } else {
      if (_isLoadingDiscoverFeed && !force) return;
    }

    if (mounted) {
      setState(() {
        if (targetFollowing) {
          _isLoadingFollowingFeed = true;
        } else {
          _isLoadingDiscoverFeed = true;
        }
        if (isActiveFeed) {
          _isLoading = true;
        }
      });
    }

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final walletAddress = walletProvider.currentWalletAddress;

    try {
      final backendApi = BackendApiService();
      try {
        if (walletAddress != null && walletAddress.isNotEmpty) {
          await backendApi.ensureAuthLoaded(walletAddress: walletAddress);
        } else {
          await backendApi.loadAuthToken();
        }
        debugPrint('Auth token ready for community posts');
      } catch (e) {
        debugPrint('Auth token not ready for community posts: $e');
      }

      final posts = await backendApi.getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: targetFollowing,
      );
      debugPrint('📥 Loaded ${posts.length} posts from backend');

      await CommunityService.loadSavedInteractions(
        posts,
        walletAddress: walletAddress,
      );
      debugPrint('✅ Restored local interaction state for posts');

      if (mounted) {
        setState(() {
          if (targetFollowing) {
            _followingFeedPosts = posts;
            _isLoadingFollowingFeed = false;
            if (isActiveFeed) {
              _communityPosts = _followingFeedPosts;
              _isLoading = false;
            }
          } else {
            _discoverFeedPosts = posts;
            _isLoadingDiscoverFeed = false;
            if (isActiveFeed) {
              _communityPosts = _discoverFeedPosts;
              _isLoading = false;
            }
          }
        });
        if (targetFollowing && isActiveFeed) {
          _prefetchComments();
        }
      }
    } catch (e) {
      debugPrint('Error loading community data: $e');
      if (mounted) {
        setState(() {
          if (targetFollowing) {
            _isLoadingFollowingFeed = false;
          } else {
            _isLoadingDiscoverFeed = false;
          }
          if (isActiveFeed) {
            _communityPosts = [];
            _isLoading = false;
          }
        });
      }
    }
  }

  void _activateFeed(CommunityFeedType target) {
    if (!mounted) return;

    setState(() {
      _activeFeed = target;
      if (target == CommunityFeedType.following) {
        _communityPosts = _followingFeedPosts;
        _isLoading = _isLoadingFollowingFeed;
      } else {
        _communityPosts = _discoverFeedPosts;
        _isLoading = _isLoadingDiscoverFeed;
      }
    });

    if (target == CommunityFeedType.following) {
      if (_followingFeedPosts.isEmpty && !_isLoadingFollowingFeed) {
        _loadCommunityData(followingOnly: true);
      }
    } else {
      if (_discoverFeedPosts.isEmpty && !_isLoadingDiscoverFeed) {
        _loadCommunityData(followingOnly: false);
      }
    }
  }

  Future<void> _prefetchComments() async {
    try {
      final prefetchCount =
          math.min(_commentPrefetchCount, _communityPosts.length);
      final concurrency = _prefetchConcurrencyLimit;
      for (var i = 0; i < prefetchCount; i += concurrency) {
        final end = math.min(i + concurrency, prefetchCount);
        final batch = _communityPosts.sublist(i, end);
        await Future.wait(batch.map((post) async {
          int attempt = 0;
          while (attempt < _prefetchMaxRetries) {
            try {
              final comments =
                  await BackendApiService().getComments(postId: post.id);
              post.comments = comments;
              post.commentCount = post.comments.length;
              if (mounted) setState(() {});
              break;
            } catch (e) {
              attempt++;
              final delayMs = _prefetchBaseDelayMs * (1 << (attempt - 1));
              debugPrint(
                  'Prefetch comments failed for post ${post.id} (attempt $attempt): $e. Retrying in ${delayMs}ms');
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }
        }));
      }
    } catch (e) {
      debugPrint('Unexpected error in _prefetchComments: $e');
    }
  }

  Future<void> _reloadCommunityFeedsForWallet({String? walletAddress, bool force = false}) async {
    if (_communityReloadInFlight) return;
    _communityReloadInFlight = true;
    try {
      final normalized = walletAddress?.trim() ?? '';
      if (normalized.isNotEmpty) {
        try {
          await BackendApiService().ensureAuthLoaded(walletAddress: normalized);
        } catch (e) {
          debugPrint('CommunityScreen: ensureAuthLoaded failed for $normalized: $e');
        }
      }
      await _loadCommunityData(followingOnly: true, force: force);
      await _loadCommunityData(followingOnly: false, force: force);
    } finally {
      _communityReloadInFlight = false;
    }
  }

  void _onAppRefreshTriggered() {
    if (!mounted || _appRefreshProvider == null) return;
    final communityVersion = _appRefreshProvider!.communityVersion;
    final globalVersion = _appRefreshProvider!.globalVersion;
    final shouldRefresh =
        communityVersion != _lastCommunityRefreshVersion ||
        globalVersion != _lastGlobalRefreshVersion;
    _lastCommunityRefreshVersion = communityVersion;
    _lastGlobalRefreshVersion = globalVersion;
    if (!shouldRefresh) return;
    try {
      _lastWalletAddress =
          Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;
    } catch (_) {}
    _reloadCommunityFeedsForWallet(
      walletAddress: _lastWalletAddress,
      force: true,
    );
  }

  /// Public helper: open comments view for a post by id (if present in current feed)
  void openPostById(String postId) {
    final idx = _communityPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      // delay to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showComments(idx);
      });
    } else {
      // If not in feed, attempt to reload and then open
      (() async {
        await _loadCommunityData();
        final newIdx = _communityPosts.indexWhere((p) => p.id == postId);
        if (newIdx != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showComments(newIdx);
          });
        }
      })();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _groupSearchController = TextEditingController();
    // Load following feed by default
    _communityPosts = _followingFeedPosts;
    _activeFeed = CommunityFeedType.following;
    try {
      _lastWalletAddress =
          Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;
    } catch (_) {}
    _loadCommunityData(followingOnly: true);
    
    // Track this screen visit for quick actions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavigationProvider>(context, listen: false).trackScreenVisit('community');
    });
    
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

    // Listen for socket notifications to animate bell
    try {
      SocketService()
          .addNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    // Connect socket and listen for incoming posts to prepend to feed
    try {
      (() async {
        await SocketService().connect();
        SocketService().addPostListener(_handleIncomingPost);
      })();
    } catch (_) {}

    // Load initial unread notification count via provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider =
            Provider.of<NotificationProvider>(context, listen: false);
        await provider.refresh();
        if (!mounted) return;
        setState(() {
          _bellUnreadCount = provider.unreadCount;
        });
        provider.addListener(_onNotificationProviderChange);
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cp = Provider.of<ChatProvider>(context, listen: false);
        // Ensure ChatProvider is initialized so socket subscriptions and unread counts are active
        try {
          await cp.initialize();
        } catch (_) {}
        if (!mounted) return;
        _messageUnreadCount = cp.totalUnread;
        cp.addListener(_onChatProviderChanged);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureGroupsLoaded();
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
              parent: _messagePulseController, curve: animationTheme.defaultCurve));

      _animationController.forward();
    }
  }

  DateTime? _lastConfigChange;

  void _onConfigChanged() {
    // Debounce: only reload if at least 1 second has passed since last change
    final now = DateTime.now();
    if (_lastConfigChange != null &&
        now.difference(_lastConfigChange!).inSeconds < 1) {
      return;
    }
    _lastConfigChange = now;
    _loadCommunityData();
  }

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
    _composerTagController?.dispose();
    _composerMentionController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
      if (id == null) return;
      if (_recentlyCreatedPostIds.remove(id)) return;
      if (_communityPosts.any((p) => p.id == id)) return;
      try {
        final post = await BackendApiService().getCommunityPostById(id);
        if (_isDuplicatePost(post)) return;
        if (!mounted) return;

        final atTop = _feedScrollController.hasClients
            ? _feedScrollController.offset <= 120
            : true;
        if (atTop) {
          setState(() {
            _communityPosts.insert(0, post);
          });
        } else {
          // Buffer incoming post and show indicator
          setState(() {
            // Avoid duplicates in buffer
            if (!_bufferedIncomingPosts.any((p) => p.id == post.id)) {
              _bufferedIncomingPosts.insert(0, post);
            }
          });
        }
      } catch (e) {
        debugPrint('Failed to fetch incoming post $id: $e');
      }
    } catch (e) {
      debugPrint('CommunityScreen incoming post handler error: $e');
    }
  }

  bool _isDuplicatePost(CommunityPost candidate) {
    const proximity = Duration(seconds: 4);

    bool matches(CommunityPost existing) {
      final sameAuthor = existing.authorId == candidate.authorId;
      final sameContent = existing.content == candidate.content;
      final timestampDiff = existing.timestamp.difference(candidate.timestamp).abs();

      if (existing.id == candidate.id) return true;
      if (existing.originalPostId != null && existing.originalPostId == candidate.id) return true;
      if (candidate.originalPostId != null && candidate.originalPostId == existing.id) return true;
      return sameAuthor && sameContent && timestampDiff < proximity;
    }

    return _communityPosts.any(matches) || _bufferedIncomingPosts.any(matches);
  }

  void _prependBufferedPosts() {
    if (_bufferedIncomingPosts.isEmpty) return;
    setState(() {
      // Prepend buffered posts preserving order: newest first
      _communityPosts.insertAll(0, _bufferedIncomingPosts);
      _bufferedIncomingPosts.clear();
    });
    // Scroll to top for visibility
    try {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (_) {}
  }

  void _onWalletProviderChanged() async {
    try {
        final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
        final currentWallet = walletProvider.currentWalletAddress ?? '';
        final normalized = WalletUtils.normalize(currentWallet);
        final previous = WalletUtils.normalize(_lastWalletAddress);
        final hasChanged = previous != normalized;

      if (hasChanged) {
        _lastWalletAddress = normalized;
        await _reloadCommunityFeedsForWallet(
          walletAddress: normalized,
          force: true,
        );
        return;
      }

      if (_communityPosts.isNotEmpty) {
        await CommunityService.loadSavedInteractions(
          _communityPosts,
          walletAddress: normalized.isEmpty ? null : normalized,
        );
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to refresh saved interactions on wallet change: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildAppBar(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeedTab(),
                          _buildDiscoverTab(),
                          _buildGroupsTab(),
                          _buildArtTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => _buildFloatingActionButton(),
      ),
    );
  }

  Widget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    final animationTheme = context.animationTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            'Connect',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          // Search icon - unified TopBarIcon
          TopBarIcon(
            tooltip: 'Search',
            icon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: _showSearchBottomSheet,
          ),
          const SizedBox(width: 8),
          // Bell icon - unified TopBarIcon
          TopBarIcon(
            tooltip: 'Notifications',
            icon: AnimatedBuilder(
              animation: _bellController,
              builder: (ctx, child) {
                final scale = _bellScale.value;
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    _bellUnreadCount > 0
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: isSmallScreen ? 20 : 24,
                  ),
                );
              },
            ),
            onPressed: _showNotifications,
            badgeCount: _bellUnreadCount,
            badgeColor: themeProvider.accentColor,
          ),
          const SizedBox(width: 8),
          // Message icon - open messages screen as a full-screen modal
          Selector<ChatProvider, int>(
            selector: (_, cp) => cp.totalUnread,
            builder: (context, totalUnread, child) {
              // Animate when unread count increases
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (totalUnread > 0 && _messageScale.value == 1.0) {
                  _messagePulseController.forward(from: 0.0);
                }
              });
              return TopBarIcon(
                tooltip: 'Open messages',
                icon: ScaleTransition(
                  scale: _messageScale,
                  child: Icon(
                    totalUnread > 0
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    color: totalUnread > 0
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                onPressed: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Messages',
                    barrierColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(179),
                    transitionDuration: animationTheme.medium,
                    pageBuilder: (ctx, a1, a2) => const MessagesScreen(),
                    transitionBuilder: (ctx, anim1, anim2, child) {
                      final slideCurve = CurvedAnimation(
                        parent: anim1,
                        curve: animationTheme.defaultCurve,
                      );
                      final fadeCurve = CurvedAnimation(
                        parent: anim1,
                        curve: animationTheme.fadeCurve,
                      );
                      return Transform.translate(
                        offset: Offset(
                          0,
                          (1 - slideCurve.value) * MediaQuery.of(context).size.height,
                        ),
                        child: FadeTransition(
                          opacity: fadeCurve,
                          child: child,
                        ),
                      );
                    },
                  );
                },
                badgeCount: totalUnread,
                badgeColor: themeProvider.accentColor,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onSocketNotificationForCommunity(
      Map<String, dynamic> data) async {
    if (!mounted) return;
    try {
      _bellController.forward(from: 0.0);
      // UI will be refreshed by NotificationProvider which is already listening for socket events and
      // updating the unread count and showing local notifications. No local show/dedupe here.
    } catch (_) {}
  }

  void _onNotificationProviderChange() {
    if (!mounted) return;
    try {
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      setState(() {
        _bellUnreadCount = provider.unreadCount;
      });
    } catch (_) {}
  }

  void _onChatProviderChanged() {
    try {
      final cp = Provider.of<ChatProvider>(context, listen: false);
      final newCount = cp.totalUnread;
      if (newCount > _messageUnreadCount) {
        _messagePulseController.forward(from: 0.0);
      }
      _messageUnreadCount = newCount;
      setState(() {});
    } catch (_) {}
  }

  // Unread notification count is now managed via NotificationProvider.

  Widget _buildTabBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: isSmallScreen,
            tabAlignment:
                isSmallScreen ? TabAlignment.start : TabAlignment.fill,
            tabs: _tabs
                .map((tab) => Tab(
                      child: Text(
                        tab,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 9 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            indicator: BoxDecoration(
              color: themeProvider.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: EdgeInsets.all(isSmallScreen ? 2 : 4),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.inter(
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.normal,
            ),
            dividerHeight: 0,
          ),
        );
      },
    );
  }

  Widget _buildFeedTab() {
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: true),
      emptyIcon: Icons.feed,
      emptyTitle: 'No Posts Available',
      emptySubtitle: 'Follow creators to see their updates here.',
      showBufferedBanner: true,
    );
  }

  Widget _buildDiscoverTab() {
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: false),
      emptyIcon: Icons.travel_explore,
      emptyTitle: 'No Community Posts Yet',
      emptySubtitle: 'Posts from across kubus will appear here soon.',
    );
  }

  Widget _buildPostTimeline({
    required Future<void> Function() onRefresh,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showBufferedBanner = false,
  }) {
    if (_isLoading) {
      return const AppLoading();
    }

    if (_communityPosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: EmptyStateCard(
                icon: emptyIcon,
                title: emptyTitle,
                description: emptySubtitle,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView.builder(
            controller: showBufferedBanner ? _feedScrollController : null,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            itemCount: _communityPosts.length,
            itemBuilder: (context, index) => _buildPostCard(index),
          ),
          if (showBufferedBanner && _bufferedIncomingPosts.isNotEmpty)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _prependBufferedPosts,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Text(
                      '${_bufferedIncomingPosts.length} new post${_bufferedIncomingPosts.length > 1 ? 's' : ''} — Tap to show',
                      style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    return Consumer<CommunityHubProvider>(
      builder: (context, hub, _) {
        if (!hub.groupsInitialized && hub.groupsLoading) {
          return const AppLoading();
        }

        final hasGroups = hub.groups.isNotEmpty;
        final listView = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            _buildGroupSearchField(hub),
            const SizedBox(height: 12),
            if (hub.groupsError != null)
              _buildGroupErrorBanner(hub.groupsError!),
            if (!hasGroups)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: 'No groups yet',
                  description:
                      hub.currentGroupSearchQuery.isEmpty
                          ? 'Join a community to unlock curator chats, drops, and meetups.'
                          : 'No groups match “${hub.currentGroupSearchQuery}”. Try another search.',
                ),
              ),
            if (hasGroups)
              ...hub.groups.map((group) => _buildGroupCard(group)),
            if (hub.groupsLoading && hasGroups)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: InlineLoading(
                  expand: false,
                  shape: BoxShape.circle,
                  progress: null,
                  tileSize: 3.5,
                  color: Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
                ),
              ),
            if (!hub.groupsLoading && hasGroups && !hub.hasMoreGroups)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Text(
                    'You’ve reached the end of the directory.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        );

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 160 &&
                hub.hasMoreGroups &&
                !hub.groupsLoading) {
              hub.loadGroups(search: hub.currentGroupSearchQuery);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () => hub.loadGroups(
              refresh: true,
              search: hub.currentGroupSearchQuery,
            ),
            child: listView,
          ),
        );
      },
    );
  }

  Widget _buildGroupSearchField(CommunityHubProvider hub) {
    final query = hub.currentGroupSearchQuery;
    if (_groupSearchController.text != query) {
      _groupSearchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return TextField(
      controller: _groupSearchController,
      onChanged: _onGroupSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _groupSearchController.clear();
                  _onGroupSearchChanged('');
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        hintText: 'Search community groups',
        filled: true,
        fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
    );
  }

  Widget _buildGroupErrorBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _ensureGroupsLoaded(force: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(CommunityGroupSummary group) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isProcessing = _groupActionsInFlight.contains(group.id);
    final membershipLabel = group.isOwner
        ? 'Owner'
        : group.isMember
            ? 'Joined'
            : 'Join';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
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
                    Text(
                      group.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description?.isNotEmpty == true
                          ? group.description!
                          : 'No description yet',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: group.isOwner
                    ? null
                    : (isProcessing
                        ? null
                        : () => _handleGroupMembershipToggle(group)),
                icon: Icon(
                  group.isMember ? Icons.check : Icons.group_add,
                  size: 16,
                ),
                label: Text(membershipLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: group.isMember
                      ? scheme.surface
                      : themeProvider.accentColor,
                  foregroundColor: group.isMember
                      ? scheme.onSurface
                      : scheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  group.isPublic ? Icons.public : Icons.lock,
                  size: 16,
                ),
                label: Text(group.isPublic ? 'Public' : 'Private'),
              ),
              Chip(
                avatar: const Icon(Icons.people_alt, size: 16),
                label: Text('${group.memberCount} members'),
              ),
            ],
          ),
          if (group.latestPost != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest post',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.latestPost?.content ?? '—',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: scheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  if (group.latestPost?.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(group.latestPost!.createdAt!),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openGroupFeed(group),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('Open group feed'),
          ),
        ],
      ),
    );
  }

  Widget _buildArtTab() {
    if (_isLoadingArtFeed && _artFeedPosts.isEmpty) {
      return const AppLoading();
    }

    return RefreshIndicator(
      onRefresh: () => _ensureArtFeedLoaded(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildArtFeedHeader(),
          const SizedBox(height: 16),
          if (_artFeedError != null && _artFeedPosts.isEmpty)
            _buildArtStatusCard(
              icon: Icons.location_off_outlined,
              title: 'Location needed',
              description:
                  'We could not determine your current location. Enable permissions and try again.',
              actionLabel: 'Retry',
              onAction: () => _ensureArtFeedLoaded(force: true),
            )
          else if (_artFeedPosts.isEmpty)
            _buildArtStatusCard(
              icon: Icons.brush_outlined,
              title: 'No nearby activations',
              description:
                  'Walk a little or expand your radius to discover pop-up art moments around you.',
              actionLabel: 'Refresh',
              onAction: () => _ensureArtFeedLoaded(force: true),
            ),
          ..._artFeedPosts.map(_buildArtPostCard),
          if (_isLoadingArtFeed && _artFeedPosts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: InlineLoading(
                  expand: false,
                  shape: BoxShape.circle,
                  tileSize: 4,
                  progress: null,
                  color:
                      Provider.of<ThemeProvider>(context, listen: false).accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtFeedHeader() {
    final scheme = Theme.of(context).colorScheme;
    final radiusKm = Provider.of<CommunityHubProvider>(context, listen: false)
        .artFeedRadiusKm;
    String subtitle;
    if (_artFeedLatitude != null && _artFeedLongitude != null) {
      subtitle =
          'Center: ${_artFeedLatitude!.toStringAsFixed(3)}, ${_artFeedLongitude!.toStringAsFixed(3)}';
    } else {
      subtitle = 'Enable precise location to unlock nearby AR drops.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Art near you',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Showing activations within ${radiusKm.toStringAsFixed(1)} km',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _ensureArtFeedLoaded(force: true),
                icon: const Icon(Icons.near_me_outlined, size: 18),
                label: const Text('Refresh location'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Art feed beta',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We use your location only to highlight AR activations nearby and never store exact coordinates.',
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('About this feed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtStatusCard({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 42, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtPostCard(CommunityPost post) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = post.imageUrl ??
        (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: AvatarWidget(
              wallet: post.authorWallet ?? post.authorId,
              avatarUrl: post.authorAvatar,
              radius: 22,
              allowFabricatedFallback: true,
            ),
            title: Text(
              post.authorName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_getTimeAgo(post.timestamp)} • ${post.category}',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: 'Share',
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Check out this AR moment from ${post.authorName} on art.kubus!',
                ),
              ),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeProvider.accentColor.withValues(alpha: 0.3),
                          themeProvider.accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: InlineLoading(
                      expand: false,
                      progress: null,
                      shape: BoxShape.circle,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: themeProvider.accentColor.withValues(alpha: 0.15),
                  child: Icon(Icons.image_not_supported,
                      color: scheme.onPrimary),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (post.location != null || post.distanceKm != null)
                  Row(
                    children: [
                      Icon(Icons.place,
                          size: 18,
                          color: themeProvider.accentColor.withValues(alpha: 0.9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            post.location?.name,
                            post.distanceKm != null
                                ? '${post.distanceKm!.toStringAsFixed(1)} km away'
                                : null,
                          ].whereType<String>().join(' • '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.tags
                        .map((tag) => Chip(label: Text('#$tag')))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('View post'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: post.group != null
                          ? () => _openGroupFeed(
                                CommunityGroupSummary(
                                  id: post.group!.id,
                                  name: post.group!.name,
                                  slug: post.group!.slug,
                                  coverImage: post.group!.coverImage,
                                  description: post.group!.description,
                                  isPublic: true,
                                  ownerWallet: post.authorWallet ?? '',
                                  memberCount: 0,
                                  isMember: false,
                                  isOwner: false,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.groups_2_outlined, size: 18),
                      label: const Text('Group'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Use actual post data from backend
    if (index >= _communityPosts.length) {
      return const SizedBox.shrink();
    }

    final post = _communityPosts[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;

        return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
                onTap: () => _viewPostDetail(index),
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // (Removed repost indicator: top-level repost label and icon were redundant)
                          Row(
                            children: [
                              AvatarWidget(
                                // Always show reposter's avatar on the top-level post card
                                wallet: (post.authorWallet ?? post.authorId),
                                avatarUrl: post.authorAvatar,
                                radius: 20,
                                allowFabricatedFallback: true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _viewUserProfile(post.authorId),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              post.authorName,
                                              style: GoogleFonts.inter(
                                                fontSize: isSmallScreen ? 14 : 16,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          ..._buildAuthorRoleBadges(
                                            post,
                                            fontSize: isSmallScreen ? 8 : 9,
                                          ),
                                        ],
                                      ),
                                      if ((post.authorUsername ?? '').trim().isNotEmpty)
                                        Text(
                                          '@${post.authorUsername!.trim()}',
                                          style: GoogleFonts.inter(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                    ),
                              Text(
                                _getTimeAgo(post.timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Repost comment (if exists)
                          if (post.postType == 'repost' &&
                              post.content.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              post.content,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 13 : 15,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                          ],
                          // Category badge and post type indicator
                          if (post.category.isNotEmpty && post.category != 'post') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: themeProvider.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(post.category),
                                    size: 14,
                                    color: themeProvider.accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatCategoryLabel(post.category),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // If this is a repost - show original post in its own inner card
                          if (post.postType == 'repost' &&
                              post.originalPost != null) ...[
                            _buildRepostInnerCard(post.originalPost!),
                          ] else ...[
                            Text(
                              post.content,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 13 : 15,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                          if ((post.postType == 'repost' &&
                                  post.originalPost?.imageUrl != null) ||
                              (post.postType != 'repost' &&
                                  post.imageUrl != null)) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(
                                          post: (post.postType == 'repost' &&
                                                  post.originalPost != null)
                                              ? post.originalPost
                                              : post))),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  (post.postType == 'repost' &&
                                          post.originalPost != null)
                                      ? post.originalPost!.imageUrl!
                                      : post.imageUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.3),
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: InlineLoading(
                                                expand: true,
                                                shape: BoxShape.circle,
                                                tileSize: 4.0,
                                                progress: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? (loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!)
                                                    : null)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.3),
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            size: 60),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                          // Post metadata section: tags, mentions, location, artwork, group
                          if (post.postType != 'repost') ...[
                            // Tags
                            if (post.tags.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: post.tags.map((tag) => GestureDetector(
                                  onTap: () => _filterByTag(tag),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: themeProvider.accentColor,
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ],
                            // Mentions
                            if (post.mentions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: post.mentions.map((mention) => GestureDetector(
                                  onTap: () => _searchMention(mention),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '@$mention',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ],
                            // Location
                            if (post.location != null && (post.location!.name?.isNotEmpty == true || post.location!.lat != null)) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: post.location!.lat != null && post.location!.lng != null
                                    ? () => _openLocationOnMap(post.location!)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.tertiary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          post.location!.name ?? '${post.location!.lat!.toStringAsFixed(4)}, ${post.location!.lng!.toStringAsFixed(4)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (post.distanceKm != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${post.distanceKm!.toStringAsFixed(1)} km',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // Artwork reference
                            if (post.artwork != null) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openArtworkDetail(post.artwork!),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: themeProvider.accentColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: post.artwork!.imageUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.network(
                                                  post.artwork!.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Icon(
                                                    Icons.view_in_ar,
                                                    color: themeProvider.accentColor,
                                                    size: 22,
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.view_in_ar,
                                                color: themeProvider.accentColor,
                                                size: 22,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              post.artwork!.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Linked artwork',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // Group reference
                            if (post.group != null) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openGroupFromPost(post.group!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.groups_2,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          post.group!.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInteractionButton(
                                  post.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  '${post.likeCount}',
                                  onTap: () => _toggleLike(index),
                                  onCountTap: () => _showPostLikes(post.id),
                                  isActive: post.isLiked,
                                ),
                              ),
                              Expanded(
                                child: _buildInteractionButton(
                                  Icons.comment_outlined,
                                  '${post.commentCount}',
                                  onTap: () => _showComments(index),
                                ),
                              ),
                              Expanded(
                                child: _buildInteractionButton(
                                  Icons.repeat,
                                  '${post.shareCount}',
                                  onTap: () {
                                    final walletProvider =
                                        Provider.of<WalletProvider>(context,
                                            listen: false);
                                    final currentWallet =
                                        walletProvider.currentWalletAddress;
                                    if (post.postType == 'repost' &&
                                        post.authorWallet == currentWallet) {
                                      _showRepostOptions(post);
                                    } else {
                                      _showRepostModal(post);
                                    }
                                  },
                                  onCountTap: post.shareCount > 0
                                      ? () => _viewRepostsList(post)
                                      : null,
                                ),
                              ),
                              Expanded(
                                child: _buildInteractionButton(
                                  Icons.share_outlined,
                                  '',
                                  onTap: () => _sharePost(index),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _toggleBookmark(index),
                                icon: Icon(
                                  post.isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: post.isBookmarked
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ]))));
      },
    );
  }

  Widget _buildInteractionButton(IconData icon, String label,
      {VoidCallback? onTap, bool isActive = false, VoidCallback? onCountTap}) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final color = isActive
        ? accent
        : scheme.onSurface.withValues(alpha: label.isEmpty ? 0.5 : 0.65);
    final animationTheme = context.animationTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.18 : 1.0,
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              child: Icon(icon, color: color, size: 20),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCountTap ?? onTap,
                child: AnimatedDefaultTextStyle(
                  duration: animationTheme.short,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: color,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRepostInnerCard(CommunityPost originalPost) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final originalHandle = (originalPost.authorUsername ?? '').trim();

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: originalPost))),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: originalPost.authorWallet ?? originalPost.authorId,
                  avatarUrl: originalPost.authorAvatar,
                  radius: 16,
                  allowFabricatedFallback: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              originalPost.authorName,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: scheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._buildAuthorRoleBadges(
                            originalPost,
                            fontSize: 8,
                          ),
                        ],
                      ),
                      if (originalHandle.isNotEmpty)
                        Text(
                          '@$originalHandle',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface
                                  .withValues(alpha: 0.6)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  _getTimeAgo(originalPost.timestamp),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              originalPost.content,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
            ),
            if (originalPost.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  originalPost.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.image_not_supported,
                        color: themeProvider.accentColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final int tabIndex = _tabController.index;

    // Groups tab (index 2) and Art tab (index 3) get expandable FABs
    if (tabIndex == 2) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: 'Create',
        options: [
          _ExpandableFabOption(
            icon: Icons.group_add_outlined,
            label: 'Create group',
            onTap: () => _showCreateGroupSheet(),
          ),
          _ExpandableFabOption(
            icon: Icons.post_add_outlined,
            label: 'Group post',
            onTap: () {
              _handleGroupFabPressed();
            },
          ),
        ],
      );
    } else if (tabIndex == 3) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: 'Create',
        options: [
          _ExpandableFabOption(
            icon: Icons.place_outlined,
            label: 'Art drop',
            onTap: () => _handleArtFabPressed(),
          ),
          _ExpandableFabOption(
            icon: Icons.rate_review_outlined,
            label: 'Post review',
            onTap: () => _createNewPost(presetCategory: 'review', artContext: true),
          ),
        ],
      );
    }

    // Following/Discover tabs get simple FAB
    final fab = FloatingActionButton.extended(
      key: ValueKey('fab_$tabIndex'),
      heroTag: 'community_fab_$tabIndex',
      onPressed: _handleFeedFabPressed,
      backgroundColor: themeProvider.accentColor,
      icon: Icon(Icons.edit_outlined, color: scheme.onPrimary),
      label: Text(
        'New post',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: animationTheme.medium,
      reverseDuration: animationTheme.short,
      switchInCurve: animationTheme.emphasisCurve,
      switchOutCurve: animationTheme.fadeCurve,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: animationTheme.emphasisCurve,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: animationTheme.fadeCurve,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: fab,
    );
  }

  Widget _buildExpandableFab({
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required AppAnimationTheme animationTheme,
    required IconData mainIcon,
    required String mainLabel,
    required List<_ExpandableFabOption> options,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded options
        AnimatedSize(
          duration: animationTheme.medium,
          curve: animationTheme.emphasisCurve,
          child: _isFabExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(
                          milliseconds: animationTheme.medium.inMilliseconds + (index * 50),
                        ),
                        curve: animationTheme.emphasisCurve,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  option.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FloatingActionButton.small(
                                heroTag: 'fab_option_${option.label}',
                                onPressed: () {
                                  setState(() => _isFabExpanded = false);
                                  option.onTap();
                                },
                                backgroundColor: scheme.primaryContainer,
                                foregroundColor: scheme.onSurface,
                                child: Icon(option.icon, size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        // Main FAB
        FloatingActionButton.extended(
          heroTag: 'community_fab_expandable',
          onPressed: () {
            setState(() => _isFabExpanded = !_isFabExpanded);
          },
          backgroundColor: _isFabExpanded
              ? scheme.surfaceContainerHighest
              : themeProvider.accentColor,
          foregroundColor: _isFabExpanded
              ? scheme.onSurface
              : scheme.onPrimary,
          icon: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: animationTheme.short,
            child: Icon(_isFabExpanded ? Icons.close : mainIcon),
          ),
          label: AnimatedSwitcher(
            duration: animationTheme.short,
            child: Text(
              _isFabExpanded ? 'Close' : mainLabel,
              key: ValueKey(_isFabExpanded),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateGroupSheet() {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = true;
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          'Create Group',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Group Name',
                              hintText: 'e.g. AR Artists Ljubljana',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'What is this group about?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Public Group',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isPublic
                                  ? 'Anyone can join and view posts'
                                  : 'Members must be approved',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            value: isPublic,
                            onChanged: (val) => setModalState(() => isPublic = val),
                            activeThumbColor: themeProvider.accentColor,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isCreating || nameController.text.trim().isEmpty
                              ? null
                              : () async {
                                  setModalState(() => isCreating = true);
                                  try {
                                    final created = await hub.createGroup(
                                      name: nameController.text.trim(),
                                      description: descriptionController.text.trim().isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      isPublic: isPublic,
                                    );
                                    if (!mounted) return;
                                    Navigator.pop(sheetContext);
                                    if (created != null) {
                                      _showSnack('Group "${created.name}" created!');
                                      _openGroupFeed(created);
                                    }
                                  } catch (e) {
                                    setModalState(() => isCreating = false);
                                    _showSnack('Failed to create group: $e');
                                  }
                                },
                          child: isCreating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: InlineLoading(
                                    expand: true,
                                    shape: BoxShape.circle,
                                    tileSize: 3.5,
                                  ),
                                )
                              : const Text('Create Group'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleFeedFabPressed() {
    _createNewPost();
  }

  void _handleGroupFabPressed() {
    unawaited(_ensureGroupsLoaded());
    _createNewPost(presetCategory: 'group');
  }

  void _handleArtFabPressed() {
    _createNewPost(presetCategory: 'art_drop', artContext: true);
  }

  // Navigation and interaction methods
  void _showSearchBottomSheet() {
    if (!mounted) return;
    final sheetContext = context;
    // Basic profile search in bottom sheet. For now this displays profiles (users).
    // TODO: Expand to include artworks, institutions, and in-app screen search.
    final sheetSearchController = TextEditingController();
    final backend = BackendApiService();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: sheetContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: sheetSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search artists, artworks, collections...',
                    hintStyle: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 400 ? 14 : 16,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.primaryContainer,
                    contentPadding: EdgeInsets.symmetric(
                      vertical:
                          MediaQuery.of(context).size.width < 400 ? 12 : 16,
                      horizontal: 16,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                  ),
                  onChanged: (q) async {
                    final query = q.trim();
                    if (query.isEmpty) {
                      setModalState(() {
                        results.clear();
                      });
                      return;
                    }
                    try {
                      setModalState(() => isLoading = true);
                      final resp = await backend.search(
                          query: query, type: 'profiles', limit: 20);
                      final list = <Map<String, dynamic>>[];
                      if (resp['success'] == true) {
                        if (resp['results'] is Map<String, dynamic>) {
                          final data = resp['results'] as Map<String, dynamic>;
                          final profiles =
                              (data['profiles'] as List<dynamic>?) ??
                                  (data['results'] as List<dynamic>?) ??
                                  [];
                          for (final d in profiles) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        } else if (resp['data'] is List) {
                          for (final d in resp['data']) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        } else if (resp['data'] is Map<String, dynamic>) {
                          final data = resp['data'] as Map<String, dynamic>;
                          final profiles =
                              (data['profiles'] as List<dynamic>?) ?? [];
                          for (final d in profiles) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        }
                      }
                      if (!mounted) return;
                      setModalState(() {
                        results = list;
                        isLoading = false;
                      });
                    } catch (e) {
                      debugPrint('Community search error: $e');
                      if (mounted) setModalState(() => isLoading = false);
                    }
                  },
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No results',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: results.length,
                            itemBuilder: (ctx, idx) {
                              final s = results[idx];
                              final username = s['username'] ??
                                  s['wallet_address'] ??
                                  s['wallet'];
                              final display =
                                  s['displayName'] ?? s['display_name'] ?? '';
                              final avatar = s['avatar'] ??
                                  s['avatar_url'] ??
                                  s['profileImageUrl'] ??
                                  '';
                              final walletAddr = (s['wallet_address'] ??
                                          s['wallet'] ??
                                          s['walletAddress'])
                                      ?.toString() ??
                                  '';
                              final title = (display ?? username)?.toString();
                              final subtitle = walletAddr.isNotEmpty
                                  ? walletAddr
                                  : (username ?? '').toString();
                              return ListTile(
                                leading: AvatarWidget(
                                    avatarUrl: (avatar != null &&
                                            avatar.toString().isNotEmpty)
                                        ? avatar.toString()
                                        : null,
                                    wallet: subtitle,
                                    radius: 20,
                                    allowFabricatedFallback: false),
                                title: Text(title ?? ''),
                                subtitle: Text(subtitle),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (walletAddr.isNotEmpty) {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => UserProfileScreen(
                                                userId: walletAddr)));
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    final notificationService = PushNotificationService();
    final backend = BackendApiService();
    List<Map<String, dynamic>> combined = [];

    // Initial load function
    Future<List<Map<String, dynamic>>> loadNotifications() async {
      try {
        // Ensure auth token is loaded for user-specific notifications
        try {
          await backend.loadAuthToken();
          final token = backend.getAuthToken();
          debugPrint(
              '🔐 Auth token loaded for notifications: ${token != null ? (token.length > 16 ? '${token.substring(0, 8)}...' : token) : "<none>"}');
          // Optionally fetch which wallet this token maps to
          try {
            final me = await backend.getMyProfile();
            debugPrint(
                '🔍 Token maps to wallet: ${me['wallet'] ?? me['wallet_address']}');
          } catch (e) {
            debugPrint('⚠️ Unable to map token to profile: $e');
          }
        } catch (e) {
          debugPrint('⚠️ No auth token available: $e');
        }

        // Load local in-app notifications
        final local = await notificationService.getInAppNotifications();
        // Load server notifications (if authenticated)
        final remote = await backend.getNotifications(limit: 50);
        debugPrint(
            '📥 Loaded ${local.length} local + ${remote.length} remote notifications');
        // Normalize remote (ensure Map<String,dynamic>)
        final remapped =
            remote.map((e) => Map<String, dynamic>.from(e)).toList();
        final notifications = [...local, ...remapped];
        // Sort by timestamp desc if available
        notifications.sort((a, b) {
          final ta = a['timestamp'] ?? a['createdAt'] ?? '';
          final tb = b['timestamp'] ?? b['createdAt'] ?? '';
          try {
            final da = DateTime.parse(ta.toString());
            final db = DateTime.parse(tb.toString());
            return db.compareTo(da);
          } catch (_) {
            return 0;
          }
        });
        return notifications;
      } catch (e) {
        debugPrint('Failed to load notifications: $e');
        return [];
      }
    }

    combined = await loadNotifications();
    if (!mounted) return;

    // Clear bell unread count when opening notifications
    try {
      setState(() {
        _bellUnreadCount = 0;
      });
      Provider.of<NotificationProvider>(context, listen: false).markViewed();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Community Notifications',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // Removed 'Mark all read' per UX decision: notifications are marked as read when viewed
                  ],
                ),
              ),
              Expanded(
                child: combined.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async {
                          final refreshed = await loadNotifications();
                          setModalState(() {
                            combined = refreshed;
                          });
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Notifications',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You\'re all caught up!',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final refreshed = await loadNotifications();
                          setModalState(() {
                            combined = refreshed;
                          });
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemBuilder: (ctx, i) {
                            final n = combined[i];
                            final type =
                                (n['interactionType'] ?? n['type'] ?? '')
                                    .toString();
                            // Extract sender info from backend notification structure
                            final sender = n['sender'] as Map<String, dynamic>?;
                            final user = sender?['displayName'] as String? ??
                                sender?['username'] as String? ??
                                (n['userName'] ?? n['authorName'] ?? 'Someone')
                                    .toString();
                            final body = (n['comment'] ??
                                    n['message'] ??
                                    n['content'] ??
                                    '')
                                .toString();
                            final ts = (n['timestamp'] ?? n['createdAt'] ?? '')
                                .toString();
                            String time = ts.isNotEmpty ? ts : '';
                            try {
                              if (time.isNotEmpty) {
                                time = _getTimeAgo(DateTime.parse(time));
                              }
                            } catch (_) {}
                            final leadSeed = (sender?['wallet'] ??
                                    sender?['wallet_address'] ??
                                    sender?['walletAddress'] ??
                                    user)
                                .toString();
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.06)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  final postId = n['postId']?.toString();
                                  if (postId != null && postId.isNotEmpty) {
                                    final idx = _communityPosts
                                        .indexWhere((p) => p.id == postId);
                                    if (idx != -1) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        _showComments(idx);
                                      });
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  children: [
                                    AvatarWidget(
                                        wallet: leadSeed,
                                        radius: 20,
                                        allowFabricatedFallback: false),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            type == 'like'
                                                ? '$user liked your post'
                                                : type == 'comment'
                                                    ? '$user commented'
                                                    : type == 'reply'
                                                        ? '$user replied'
                                                        : type == 'mention'
                                                            ? '$user mentioned you'
                                                            : (n['type'] ??
                                                                    'Notification')
                                                                .toString(),
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(time,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (ctx, i) => Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.06)),
                          itemCount: combined.length,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewPost({
    CommunityGroupSummary? presetGroup,
    String? presetCategory,
    bool artContext = false,
  }) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    hub.resetDraft();

    final seedCategory =
        presetCategory ?? (artContext ? 'art_drop' : null);
    if (seedCategory != null && seedCategory.trim().isNotEmpty) {
      hub.setDraftCategory(seedCategory);
    }

    if (presetGroup != null) {
      hub.setDraftGroup(presetGroup);
    }

    _newPostController.clear();
    _selectedPostImage = null;
    _selectedPostImageBytes = null;
    _selectedPostVideo = null;

    // Dispose old controllers if they exist and create fresh ones
    _composerTagController?.dispose();
    _composerMentionController?.dispose();
    _composerTagController = TextEditingController();
    _composerMentionController = TextEditingController();
    final tagController = _composerTagController!;
    final mentionController = _composerMentionController!;

    final sheetFuture = showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Consumer<CommunityHubProvider>(
              builder: (context, provider, _) {
                final draft = provider.draft;
                return Container(
                  height: MediaQuery.of(context).size.height * 0.9,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      _buildComposerHandle(),
                      _buildComposerHeader(sheetContext),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildComposerCategorySelector(draft, provider),
                              const SizedBox(height: 16),
                              _buildComposerTextField(),
                              _animatedComposerSection(
                                show: _hasSelectedMedia,
                                sectionKey: 'composer_media',
                                child: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildComposerMediaPreview(setModalState),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildComposerAttachmentRow(setModalState),
                              const SizedBox(height: 20),
                              _buildComposerGroupSelector(draft, provider),
                              const SizedBox(height: 16),
                              _buildComposerArtworkSelector(draft),
                              const SizedBox(height: 16),
                              _buildComposerLocationSection(
                                  draft, setModalState),
                              const SizedBox(height: 16),
                              _buildChipEditor(
                                label: 'Tags',
                                hint: 'Add topic (e.g. kub8, spatial)',
                                values: draft.tags,
                                controller: tagController,
                                prefix: '#',
                                onAdd: (value) {
                                  final sanitized =
                                      value.replaceFirst('#', '');
                                  provider.addTag(sanitized);
                                },
                                onRemove: provider.removeTag,
                              ),
                              const SizedBox(height: 16),
                              _buildChipEditor(
                                label: 'Mentions',
                                hint: 'Add @handle',
                                values: draft.mentions,
                                controller: mentionController,
                                prefix: '@',
                                onAdd: (value) {
                                  final normalized = value.startsWith('@')
                                      ? value.substring(1)
                                      : value;
                                  provider.addMention(normalized);
                                },
                                onRemove: provider.removeMention,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isPostingNew
                                  ? null
                                  : () => _submitComposer(
                                        sheetContext: sheetContext,
                                        setModalState: setModalState,
                                        hub: provider,
                                      ),
                                child: AnimatedSwitcher(
                              duration: context.animationTheme.short,
                              switchInCurve:
                                context.animationTheme.defaultCurve,
                              switchOutCurve:
                                context.animationTheme.fadeCurve,
                                  child: _isPostingNew
                                      ? SizedBox(
                                          key: const ValueKey(
                                              'composer_posting_spinner'),
                                          width: 20,
                                          height: 20,
                                          child: InlineLoading(
                                            expand: true,
                                            shape: BoxShape.circle,
                                            tileSize: 3.5,
                                          ),
                                        )
                                      : const Text(
                                          'Post',
                                          key: ValueKey(
                                              'composer_post_label'),
                                        ),
                                ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    sheetFuture.whenComplete(() {
      // Don't dispose controllers here - they're class-level and will be
      // disposed when a new composer opens or in State.dispose()
      hub.resetDraft();
      if (mounted) {
        setState(() {
          _isPostingNew = false;
        });
      } else {
        _isPostingNew = false;
      }
    });
  }

  Widget _buildPostOption(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerHandle() {
    return Container(
      width: 48,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .outline
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _animatedComposerSection({
    required bool show,
    required Widget child,
    required String sectionKey,
    Duration? duration,
  }) {
    final animationTheme = context.animationTheme;
    final effectiveDuration = duration ?? animationTheme.medium;
    return AnimatedSwitcher(
      duration: effectiveDuration,
      reverseDuration: animationTheme.short,
      switchInCurve: animationTheme.defaultCurve,
      switchOutCurve: animationTheme.fadeCurve,
      child: show
          ? KeyedSubtree(
              key: ValueKey(sectionKey),
              child: child,
            )
          : const SizedBox.shrink(),
      transitionBuilder: (child, animation) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: animationTheme.fadeCurve,
          ),
          child: SlideTransition(
            position: animation.drive(
              slideTween.chain(
                CurveTween(curve: animationTheme.defaultCurve),
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildComposerHeader(BuildContext sheetContext) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Text(
            'Compose',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(sheetContext).maybePop(),
            icon: const Icon(Icons.close),
            color: scheme.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildComposerTextField() {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 400;
    return TextField(
      controller: _newPostController,
      minLines: 3,
      maxLines: null,
      decoration: InputDecoration(
        hintText: 'Share what you’re building, discovering, or activating…',
        hintStyle: GoogleFonts.inter(fontSize: isCompact ? 14 : 16),
        filled: true,
        fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCompact ? 12 : 18,
        ),
      ),
      style: GoogleFonts.inter(fontSize: isCompact ? 14 : 16, height: 1.4),
      textInputAction: TextInputAction.newline,
    );
  }

  bool get _hasSelectedMedia =>
      _selectedPostImageBytes != null || _selectedPostVideo != null;

  Widget _buildComposerMediaPreview(StateSetter setModalState) {
    final scheme = Theme.of(context).colorScheme;
    if (_selectedPostImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              _selectedPostImageBytes!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              tooltip: 'Remove image',
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.8),
              ),
              onPressed: () => setModalState(() {
                _selectedPostImage = null;
                _selectedPostImageBytes = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      );
    }
    if (_selectedPostVideo != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined,
                      size: 42,
                      color:
                          Provider.of<ThemeProvider>(context, listen: false)
                              .accentColor),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _selectedPostVideo!.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: 'Remove video',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: 0.8),
                ),
                onPressed: () => setModalState(() {
                  _selectedPostVideo = null;
                }),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildComposerAttachmentRow(StateSetter setModalState) {
    final scheme = Theme.of(context).colorScheme;
    final hasMedia = _hasSelectedMedia;
    final animationTheme = context.animationTheme;
    return AnimatedContainer(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      padding: EdgeInsets.all(hasMedia ? 8 : 0),
      decoration: BoxDecoration(
        color: hasMedia
            ? scheme.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPostOption(
              Icons.image_outlined,
              'Image',
              onTap: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  maxHeight: 1920,
                  imageQuality: 85,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setModalState(() {
                    _selectedPostImage = image;
                    _selectedPostImageBytes = bytes;
                    _selectedPostVideo = null;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPostOption(
              Icons.videocam_outlined,
              'Video',
              onTap: () async {
                final picker = ImagePicker();
                final video = await picker.pickVideo(
                  source: ImageSource.gallery,
                  maxDuration: const Duration(minutes: 5),
                );
                if (video != null) {
                  setModalState(() {
                    _selectedPostVideo = video;
                    _selectedPostImage = null;
                    _selectedPostImageBytes = null;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCategorySelector(
    CommunityPostDraft draft,
    CommunityHubProvider hub,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: _composerCategories.map((option) {
          final selected = draft.category == option.value;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedScale(
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              scale: selected ? 1.0 : 0.95,
              child: AnimatedOpacity(
                duration: animationTheme.short,
                opacity: selected ? 1.0 : 0.85,
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(option.icon,
                          size: 16,
                          color: selected
                              ? themeProvider.accentColor
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(option.label),
                    ],
                  ),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  selectedColor:
                      themeProvider.accentColor.withValues(alpha: 0.15),
                  onSelected: (_) => hub.setDraftCategory(option.value),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComposerGroupSelector(
    CommunityPostDraft draft,
    CommunityHubProvider hub,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final group = draft.targetGroup;
    final hasGroup = group != null;
    final animationTheme = context.animationTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final selection = await _showGroupPicker();
        if (selection != null) {
          hub.setDraftGroup(selection);
        }
      },
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasGroup
              ? scheme.primaryContainer.withValues(alpha: 0.25)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasGroup
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined, color: scheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group?.name ?? 'Target group',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group == null
                        ? 'Optional • Join a group to unlock curator chats.'
                        : 'Posting in ${group.name}. Tap to change or clear.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (group != null)
              IconButton(
                tooltip: 'Remove group',
                onPressed: () => hub.setDraftGroup(null),
                icon: const Icon(Icons.close),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerArtworkSelector(CommunityPostDraft draft) {
    final scheme = Theme.of(context).colorScheme;
    final artwork = draft.artwork;
    final hasArtwork = artwork != null;
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final selection = await _showArtworkPicker();
        if (selection != null) {
          hub.setDraftArtwork(selection);
        }
      },
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasArtwork
              ? scheme.primaryContainer.withValues(alpha: 0.25)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasArtwork
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            if (artwork?.imageUrl != null && artwork!.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  artwork.imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurface,
                  ),
                ),
              )
            else
              Icon(Icons.collections_outlined, color: scheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork?.title ?? 'Link artwork',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artwork == null
                        ? 'Add provenance to help collectors discover it.'
                        : 'Attached to ${artwork.title}.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (artwork != null)
              IconButton(
                tooltip: 'Remove artwork',
                onPressed: () => hub.setDraftArtwork(null),
                icon: const Icon(Icons.close),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerLocationSection(
    CommunityPostDraft draft,
    StateSetter setModalState,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final location = draft.location;
    final label = draft.locationLabel ?? location?.name;
    final animationTheme = context.animationTheme;
    final addButton = OutlinedButton.icon(
      key: const ValueKey('composer_location_add'),
      icon: const Icon(Icons.my_location_outlined),
      label: const Text('Attach current location'),
      onPressed: () => _captureDraftLocation(setModalState),
    );

    Widget currentChild;
    if (location == null) {
      currentChild = addButton;
    } else {
      final lat = location.lat;
      final lng = location.lng;
      currentChild = Container(
        key: const ValueKey('composer_location_attached'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: scheme.onSurface, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label ?? 'Attached location',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove location',
                  onPressed: () => Provider.of<CommunityHubProvider>(context,
                          listen: false)
                      .setDraftLocation(null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 4),
              Text(
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _promptLocationLabelEdit(location,
                      initialLabel: label),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: const Text('Rename'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _captureDraftLocation(setModalState),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: animationTheme.medium,
      switchInCurve: animationTheme.defaultCurve,
      switchOutCurve: animationTheme.fadeCurve,
      transitionBuilder: (child, animation) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: animationTheme.fadeCurve,
          ),
          child: SlideTransition(
            position: animation.drive(
              slideTween.chain(
                CurveTween(curve: animationTheme.defaultCurve),
              ),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: location == null
            ? const ValueKey('composer_location_add')
            : const ValueKey('composer_location_attached'),
        child: currentChild,
      ),
    );
  }

  Widget _buildChipEditor({
    required String label,
    required String hint,
    required List<String> values,
    required TextEditingController controller,
    required String prefix,
    required void Function(String value) onAdd,
    required void Function(String value) onRemove,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    final isMentions = label.toLowerCase() == 'mentions';
    final isTags = label.toLowerCase() == 'tags';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showSearchPicker(
                title: isMentions ? 'Search Users' : isTags ? 'Popular Tags' : 'Search',
                searchType: isMentions ? 'profiles' : isTags ? 'tags' : 'all',
                onSelect: (result) {
                  if (isMentions) {
                    final handle = result['username'] ?? result['wallet_address'] ?? result['id'] ?? '';
                    if (handle.toString().isNotEmpty) {
                      onAdd(handle.toString());
                    }
                  } else if (isTags) {
                    final tag = result['tag'] ?? result['name'] ?? result['value'] ?? '';
                    if (tag.toString().isNotEmpty) {
                      onAdd(tag.toString());
                    }
                  }
                },
              ),
              icon: Icon(Icons.search, size: 18, color: themeProvider.accentColor),
              label: Text(
                'Search',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: themeProvider.accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: animationTheme.short,
          switchInCurve: animationTheme.defaultCurve,
          switchOutCurve: animationTheme.fadeCurve,
          child: values.isNotEmpty
              ? Wrap(
                  key: ValueKey('${label}_chips'),
                  spacing: 8,
                  runSpacing: 8,
                  children: values.map((value) {
                    final display = prefix.isEmpty
                        ? value
                        : '$prefix${value.replaceAll(prefix, '')}';
                    return InputChip(
                      label: Text(display),
                      onDeleted: () => onRemove(value),
                    );
                  }).toList(),
                )
              : Text(
                  'No $label yet',
                  key: ValueKey('${label}_chips_empty'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final entry = controller.text.trim();
                if (entry.isEmpty) return;
                onAdd(entry);
                controller.clear();
              },
            ),
          ),
          onSubmitted: (value) {
            final entry = value.trim();
            if (entry.isEmpty) return;
            onAdd(entry);
            controller.clear();
          },
        ),
      ],
    );
  }

  void _showSearchPicker({
    required String title,
    required String searchType,
    required void Function(Map<String, dynamic> result) onSelect,
  }) {
    final searchController = TextEditingController();
    final backend = BackendApiService();
    List<Map<String, dynamic>> results = [];
    List<Map<String, dynamic>> suggestions = [];
    bool isLoading = false;
    bool showSuggestions = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

          // Load suggestions on first build
          if (showSuggestions && suggestions.isEmpty && !isLoading) {
            Future.microtask(() async {
              setModalState(() => isLoading = true);
              try {
                if (searchType == 'tags') {
                  // Get trending tags
                  final trending = await backend.getTrendingSearches(limit: 15);
                  if (mounted) {
                    setModalState(() {
                      suggestions = trending.map((t) => {
                        'tag': t['term'] ?? t['tag'] ?? t['query'] ?? '',
                        'count': t['count'] ?? t['search_count'] ?? 0,
                      }).where((t) => t['tag'].toString().isNotEmpty).toList();
                      isLoading = false;
                    });
                  }
                } else if (searchType == 'profiles') {
                  // Could load suggested users or leave empty for search-only
                  setModalState(() => isLoading = false);
                } else if (searchType == 'artworks') {
                  // Could load featured artworks
                  setModalState(() => isLoading = false);
                } else {
                  setModalState(() => isLoading = false);
                }
              } catch (e) {
                debugPrint('Failed to load suggestions: $e');
                if (mounted) setModalState(() => isLoading = false);
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: searchType == 'tags'
                            ? 'Search tags...'
                            : searchType == 'profiles'
                                ? 'Search users by name or @handle...'
                                : searchType == 'artworks'
                                    ? 'Search artworks...'
                                    : 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() {
                                    results.clear();
                                    showSuggestions = true;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
                      ),
                      onChanged: (query) async {
                        final q = query.trim();
                        if (q.isEmpty) {
                          setModalState(() {
                            results.clear();
                            showSuggestions = true;
                          });
                          return;
                        }
                        setModalState(() {
                          isLoading = true;
                          showSuggestions = false;
                        });
                        try {
                          final response = await backend.search(
                            query: q,
                            type: searchType == 'tags' ? 'all' : searchType,
                            limit: 20,
                          );
                          final list = <Map<String, dynamic>>[];
                          if (response['success'] == true) {
                            if (searchType == 'profiles') {
                              final profiles = _extractSearchResults(response, 'profiles');
                              list.addAll(profiles);
                            } else if (searchType == 'artworks') {
                              final artworks = _extractSearchResults(response, 'artworks');
                              list.addAll(artworks);
                            } else if (searchType == 'tags') {
                              // For tags, generate suggestions from query
                              list.add({'tag': q, 'count': 0, 'isCustom': true});
                              // Also check for tag matches in results
                              final tags = _extractSearchResults(response, 'tags');
                              list.addAll(tags);
                            } else {
                              final all = _extractSearchResults(response, 'all');
                              list.addAll(all);
                            }
                          }
                          if (mounted) {
                            setModalState(() {
                              results = list;
                              isLoading = false;
                            });
                          }
                        } catch (e) {
                          debugPrint('Search error: $e');
                          if (mounted) setModalState(() => isLoading = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isLoading
                        ? Center(
                            child: InlineLoading(
                              expand: false,
                              shape: BoxShape.circle,
                              tileSize: 4,
                            ),
                          )
                        : showSuggestions && suggestions.isNotEmpty
                            ? _buildSearchSuggestionsList(
                                suggestions: suggestions,
                                searchType: searchType,
                                themeProvider: themeProvider,
                                scheme: scheme,
                                onSelect: (result) {
                                  Navigator.pop(sheetContext);
                                  onSelect(result);
                                },
                              )
                            : results.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          searchType == 'tags'
                                              ? Icons.tag
                                              : searchType == 'profiles'
                                                  ? Icons.person_search
                                                  : Icons.search,
                                          size: 48,
                                          color: scheme.onSurface.withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchController.text.isEmpty
                                              ? 'Start typing to search'
                                              : 'No results found',
                                          style: GoogleFonts.inter(
                                            color: scheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildSearchResultsList(
                                    results: results,
                                    searchType: searchType,
                                    themeProvider: themeProvider,
                                    scheme: scheme,
                                    onSelect: (result) {
                                      Navigator.pop(sheetContext);
                                      onSelect(result);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _extractSearchResults(Map<String, dynamic> response, String type) {
    final list = <Map<String, dynamic>>[];
    try {
      if (response['results'] is Map<String, dynamic>) {
        final data = response['results'] as Map<String, dynamic>;
        final items = data[type] ?? data['results'] ?? [];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              list.add(item);
            }
          }
        }
      } else if (response['data'] is List) {
        for (final item in response['data']) {
          if (item is Map<String, dynamic>) {
            list.add(item);
          }
        }
      } else if (response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;
        final items = data[type] ?? [];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              list.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting search results: $e');
    }
    return list;
  }

  Widget _buildSearchSuggestionsList({
    required List<Map<String, dynamic>> suggestions,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: suggestions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              searchType == 'tags' ? 'Popular Tags' : 'Suggestions',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        final suggestion = suggestions[index - 1];
        return _buildSearchResultTile(
          result: suggestion,
          searchType: searchType,
          themeProvider: themeProvider,
          scheme: scheme,
          onTap: () => onSelect(suggestion),
        );
      },
    );
  }

  Widget _buildSearchResultsList({
    required List<Map<String, dynamic>> results,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildSearchResultTile(
          result: result,
          searchType: searchType,
          themeProvider: themeProvider,
          scheme: scheme,
          onTap: () => onSelect(result),
        );
      },
    );
  }

  Widget _buildSearchResultTile({
    required Map<String, dynamic> result,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    if (searchType == 'tags') {
      final tag = result['tag'] ?? result['name'] ?? '';
      final count = result['count'] ?? result['search_count'] ?? 0;
      final isCustom = result['isCustom'] == true;
      
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.tag,
            color: themeProvider.accentColor,
            size: 20,
          ),
        ),
        title: Text(
          '#$tag',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: isCustom
            ? Text(
                'Add as new tag',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            : count > 0
                ? Text(
                    '$count uses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                : null,
        trailing: const Icon(Icons.add_circle_outline, size: 20),
        onTap: onTap,
      );
    } else if (searchType == 'profiles') {
      final name = result['display_name'] ?? result['displayName'] ?? result['username'] ?? 'User';
      final handle = result['username'] ?? result['wallet_address'] ?? '';
      final avatar = result['avatar'] ?? result['avatar_url'] ?? result['profileImage'];

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: AvatarWidget(
          wallet: handle,
          avatarUrl: avatar,
          radius: 20,
          allowFabricatedFallback: true,
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: handle.isNotEmpty
            ? Text(
                '@$handle',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            : null,
        trailing: const Icon(Icons.add_circle_outline, size: 20),
        onTap: onTap,
      );
    } else if (searchType == 'artworks') {
      final title = result['title'] ?? 'Untitled';
      final artist = result['artist_name'] ?? result['artistName'] ?? 'Unknown';
      final image = result['image_url'] ?? result['imageUrl'] ?? result['thumbnailUrl'];

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image,
                      color: themeProvider.accentColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.view_in_ar,
                  color: themeProvider.accentColor,
                ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'by $artist',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: const Icon(Icons.add_circle_outline, size: 20),
        onTap: onTap,
      );
    }

    // Default tile
    return ListTile(
      title: Text(result.toString()),
      onTap: onTap,
    );
  }

  Future<CommunityGroupSummary?> _showGroupPicker() async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    await _ensureGroupsLoaded();
    if (!mounted) return null;
    final joined = hub.groups.where((g) => g.isMember || g.isOwner).toList();
    if (joined.isEmpty) {
      if (!mounted) return null;
      _showSnack('Join a group to target your drop.');
      return null;
    }
    return showModalBottomSheet<CommunityGroupSummary>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildComposerHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Select group',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: joined.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final group = joined[index];
                  return ListTile(
                    title: Text(group.name),
                    subtitle: Text(
                      group.description?.isNotEmpty == true
                          ? group.description!
                          : 'No description yet',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(ctx).pop(group),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<CommunityArtworkReference?> _showArtworkPicker() async {
    final walletProvider =
        Provider.of<WalletProvider>(context, listen: false);
    final wallet = walletProvider.currentWalletAddress;
    if (wallet == null || wallet.isEmpty) {
      _showSnack('Connect your wallet to link an artwork.');
      return null;
    }
    return showModalBottomSheet<CommunityArtworkReference>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildComposerHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Link artwork',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: BackendApiService()
                    .getArtistArtworks(wallet, limit: 50),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: InlineLoading(expand: false));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load artworks: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final artworks = snapshot.data ?? const [];
                  if (artworks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No artworks found. Mint or upload an artwork first.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: artworks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final raw = artworks[index];
                      final ref = CommunityArtworkReference(
                        id: (raw['id'] ?? raw['artworkId']).toString(),
                        title: (raw['title'] ?? 'Untitled').toString(),
                        imageUrl: (raw['imageUrl'] ??
                                raw['coverImage'] ??
                                raw['cover_image'])
                            ?.toString(),
                      );
                      return ListTile(
                        leading: ref.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ref.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              )
                            : const Icon(Icons.burst_mode_outlined),
                        title: Text(ref.title),
                        onTap: () => Navigator.of(ctx).pop(ref),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureDraftLocation(StateSetter setModalState) async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final locationData = await _obtainCurrentLocation();
    if (locationData == null) return;
    final lat = locationData.latitude;
    final lng = locationData.longitude;
    final label = (lat != null && lng != null)
        ? 'Drop @ ${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}'
        : 'Current location';
    hub.setDraftLocation(
      CommunityLocation(name: label, lat: lat, lng: lng),
      label: label,
    );
    setModalState(() {});
  }

  Future<void> _promptLocationLabelEdit(
    CommunityLocation? location, {
    String? initialLabel,
  }) async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final controller = TextEditingController(text: initialLabel ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this place'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Kubus HQ roof'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    hub.setDraftLocation(location, label: result);
  }

  Future<String?> _ensureWalletForPosting(BuildContext ctx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('wallet') ??
          prefs.getString('wallet_address') ??
          prefs.getString('walletAddress');
      if (walletAddress == null || walletAddress.isEmpty) {
        if (!mounted) return null;
        _showSnack('Please connect your wallet first.');
        return null;
      }
      await BackendApiService().loadAuthToken();
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        await BackendApiService().registerWallet(
          walletAddress: walletAddress,
          username:
              'user_${walletAddress.substring(0, math.min(8, walletAddress.length))}',
        );
      }
      return walletAddress;
    } catch (e) {
      if (!mounted) return null;
      _showSnack('Unable to authenticate: $e');
      return null;
    }
  }

  Future<List<String>> _uploadComposerMedia() async {
    final mediaUrls = <String>[];
    final api = BackendApiService();
    if (_selectedPostImage != null && _selectedPostImageBytes != null) {
      final fileName = _selectedPostImage!.name;
      final uploadResult = await api.uploadFile(
        fileBytes: _selectedPostImageBytes!,
        fileName: fileName,
        fileType: 'post-image',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url != null) {
        mediaUrls.add(url);
      } else {
        throw Exception('Image upload returned no URL');
      }
    }
    if (_selectedPostVideo != null) {
      final videoFile = File(_selectedPostVideo!.path);
      final uploadResult = await api.uploadFile(
        fileBytes: await videoFile.readAsBytes(),
        fileName: _selectedPostVideo!.name,
        fileType: 'post-video',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url != null) {
        mediaUrls.add(url);
      } else {
        throw Exception('Video upload returned no URL');
      }
    }
    return mediaUrls;
  }

  String _resolveComposerPostType() {
    if (_selectedPostVideo != null) return 'video';
    if (_selectedPostImage != null) return 'image';
    return 'text';
  }

  Future<CommunityPost> _submitCommunityPost({
    required CommunityHubProvider hub,
    required String content,
    required List<String> mediaUrls,
  }) async {
    final draft = hub.draft;
    final location = draft.location;
    final locationLabel = draft.locationLabel ?? location?.name;
    final artworkId = draft.artwork?.id;
    final postType = _resolveComposerPostType();
    final tags = draft.tags;
    final mentions = draft.mentions;
    final category = draft.category.isNotEmpty ? draft.category : 'post';

    if (draft.targetGroup != null) {
      final created = await hub.submitGroupPost(
        draft.targetGroup!.id,
        content: content,
        mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
        artworkId: artworkId,
        postType: postType,
        category: category,
        tags: tags,
        mentions: mentions,
        location: location,
        locationLabel: locationLabel,
      );
      if (created == null) {
        throw Exception('Group post creation failed');
      }
      return created;
    }

    return BackendApiService().createCommunityPost(
      content: content,
      mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
      artworkId: artworkId,
      postType: postType,
      category: category,
      tags: tags,
      mentions: mentions,
      location: location,
      locationName: locationLabel,
      locationLat: location?.lat,
      locationLng: location?.lng,
    );
  }

  Future<void> _submitComposer({
    required BuildContext sheetContext,
    required StateSetter setModalState,
    required CommunityHubProvider hub,
  }) async {
    final messenger = ScaffoldMessenger.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    var content = _newPostController.text.trim();
    if (content.isEmpty && !_hasSelectedMedia) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add text, an image, or a video.')),
      );
      return;
    }

    final walletAddress = await _ensureWalletForPosting(sheetContext);
    if (walletAddress == null) return;

    setModalState(() => _isPostingNew = true);

    try {
      final mediaUrls = await _uploadComposerMedia();
      if (content.isEmpty) {
        content = _selectedPostVideo != null
            ? '🎥'
            : (_selectedPostImage != null ? '📷' : 'Shared via art.kubus');
      }

      final groupName = hub.draft.targetGroup?.name;
      final isGroupPost = hub.draft.targetGroup != null;

      final createdPost = await _submitCommunityPost(
        hub: hub,
        content: content,
        mediaUrls: mediaUrls,
      );

      setModalState(() => _isPostingNew = false);
      if (!mounted) return;

      _handlePostSuccess(createdPost, isGroupPost: isGroupPost);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isGroupPost
                ? 'Shared inside ${groupName ?? "group"}. '
                : 'Post created successfully!',
          ),
        ),
      );
    } catch (e) {
      setModalState(() => _isPostingNew = false);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create post: $e')),
      );
    }
  }

  void _handlePostSuccess(CommunityPost createdPost,
      {required bool isGroupPost}) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    hub.resetDraft();
    if (!mounted) return;
    setState(() {
      _newPostController.clear();
      _selectedPostImage = null;
      _selectedPostImageBytes = null;
      _selectedPostVideo = null;
      if (!isGroupPost) {
        if (createdPost.id.isNotEmpty) {
          _recentlyCreatedPostIds.add(createdPost.id);
        }
        final updated = [createdPost, ..._communityPosts];
        _communityPosts = updated;
        if (_activeFeed == CommunityFeedType.following) {
          _followingFeedPosts = updated;
        } else {
          _discoverFeedPosts = updated;
        }
      }
    });
  }

  // Interaction methods
  void _toggleLike(int index) async {
    debugPrint('DEBUG: _toggleLike called for index: $index');
    if (index >= _communityPosts.length) {
      debugPrint(
          'DEBUG: Index $index is out of bounds (posts length: ${_communityPosts.length})');
      return;
    }

    final post = _communityPosts[index];
    final wasLiked = post.isLiked;
    debugPrint(
        'DEBUG: Post ${post.id} was liked: $wasLiked, count: ${post.likeCount}');
    final walletAddress = Provider.of<WalletProvider>(context, listen: false)
        .currentWalletAddress;

    try {
      // Let the service perform the toggle and persistence; it mutates `post` synchronously
      await CommunityService.togglePostLike(
        post,
        currentUserWallet: walletAddress,
      );
      debugPrint(
          'DEBUG: Service call completed successfully - liked: ${post.isLiked}, count: ${post.likeCount}');

      if (!mounted) return;
      // Rebuild UI to reflect the updated post state
      setState(() {});

      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasLiked ? 'Post liked!' : 'Post unliked!'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('DEBUG: Error in togglePostLike: $e');
      // CommunityService performs rollback on error; ensure UI is refreshed
      setState(() {});
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${!wasLiked ? 'like' : 'unlike'} post'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPostLikes(String postId) {
    _showLikesDialog(
      title: 'Post Likes',
      loader: () => BackendApiService().getPostLikes(postId),
    );
  }

  void _showCommentLikes(String commentId) {
    _showLikesDialog(
      title: 'Comment Likes',
      loader: () => BackendApiService().getCommentLikes(commentId),
    );
  }

  void _showLikesDialog(
      {required String title,
      required Future<List<CommunityLikeUser>> Function() loader}) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final future = loader();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.onSurface,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CommunityLikeUser>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: InlineLoading(
                              expand: true,
                              shape: BoxShape.circle,
                              tileSize: 4.0),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.error, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load likes',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: 'No likes yet',
                          description: 'Be the first to like this post.',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => Divider(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3)),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final subtitleParts = <String>[];
                        if (user.username != null &&
                            user.username!.isNotEmpty) {
                          subtitleParts.add('@${user.username}');
                        }
                        if (user.walletAddress != null &&
                            user.walletAddress!.isNotEmpty) {
                          final wallet = user.walletAddress!;
                          if (wallet.length > 8) {
                            subtitleParts.add(
                                '${wallet.substring(0, 4)}...${wallet.substring(wallet.length - 4)}');
                          } else {
                            subtitleParts.add(wallet);
                          }
                        }
                        if (user.likedAt != null) {
                          subtitleParts.add(_getTimeAgo(user.likedAt!));
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            allowFabricatedFallback: true,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : 'Unnamed User',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: subtitleParts.isNotEmpty
                              ? Text(
                                  subtitleParts.join(' • '),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_CommentAuthorContext?> _resolveCommentAuthorContext() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUserId = prefs.getString('user_id');
    final username = prefs.getString('username') ?? 'Current User';
    String? walletAddress = prefs.getString('wallet') ??
        prefs.getString('wallet_address') ??
        prefs.getString('walletAddress');

    if ((currentUserId == null || currentUserId.isEmpty) &&
        walletAddress != null &&
        walletAddress.isNotEmpty) {
      currentUserId = walletAddress;
    }

    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    final String resolvedUserId = currentUserId;

    final String resolvedWallet =
        (walletAddress != null && walletAddress.isNotEmpty)
            ? walletAddress
            : currentUserId;
    final String canonicalWallet = resolvedWallet;
    String? cachedAvatar;
    try {
      cachedAvatar = canonicalWallet.isNotEmpty
          ? UserService.getCachedUser(canonicalWallet)?.profileImageUrl
          : null;
    } catch (_) {
      cachedAvatar = null;
    }

    return _CommentAuthorContext(
      userId: resolvedUserId,
      walletAddress: canonicalWallet.isNotEmpty ? canonicalWallet : null,
      displayName: username.isNotEmpty ? username : 'Current User',
      avatarUrl: cachedAvatar,
    );
  }

  void _toggleBookmark(int index) async {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];
    final savedItemsProvider =
        Provider.of<SavedItemsProvider>(context, listen: false);

    try {
      await savedItemsProvider.setPostSaved(post.id, post.isBookmarked);
      if (!mounted) return;

      setState(() {
        _bookmarkedPosts[index] = post.isBookmarked;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.isBookmarked ? 'Post bookmarked!' : 'Bookmark removed!',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not update bookmark'),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showComments(int index) async {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];
    debugPrint('🔵 _showComments called for post ${post.id}');

    // Fetch comments from backend to ensure we have fresh, nested replies and author avatars
    try {
      debugPrint('   📥 Fetching comments from backend...');
      final backendComments =
          await BackendApiService().getComments(postId: post.id);
      debugPrint(
          '   ✅ Received ${backendComments.length} root comments from backend');

      // Count total comments including nested replies
      int totalComments = backendComments.length;
      for (final comment in backendComments) {
        totalComments += comment.replies.length;
        debugPrint(
            '   Comment ${comment.id} has ${comment.replies.length} replies');
      }
      debugPrint('   Total comments (including nested): $totalComments');

      // Replace current comments with backend-provided nested comments
      post.comments = backendComments;
      post.commentCount = totalComments;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to load backend comments for post ${post.id}: $e');
    }

    final TextEditingController commentController = TextEditingController();
    String? replyToCommentId; // Track which comment is being replied to

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${post.commentCount} comments',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: post.comments.length,
                  itemBuilder: (context, commentIndex) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar (if available) or fallback initial avatar
                        AvatarWidget(
                          wallet: post.comments[commentIndex].authorWallet ??
                              post.comments[commentIndex].authorId,
                          avatarUrl: post.comments[commentIndex].authorAvatar,
                          radius: 16,
                          allowFabricatedFallback: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.comments[commentIndex].authorName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                post.comments[commentIndex].content,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getTimeAgo(
                                    post.comments[commentIndex].timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Comment actions: like and reply
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      post.comments[commentIndex].isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 18,
                                      color: post.comments[commentIndex].isLiked
                                          ? Colors.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                    ),
                                    onPressed: () async {
                                      // Optimistic toggle
                                      setModalState(() {
                                        post.comments[commentIndex].isLiked =
                                            !post
                                                .comments[commentIndex].isLiked;
                                        post.comments[commentIndex].likeCount +=
                                            post.comments[commentIndex].isLiked
                                                ? 1
                                                : -1;
                                      });
                                      try {
                                        await CommunityService
                                            .toggleCommentLike(
                                                post.comments[commentIndex],
                                                post.id);
                                      } catch (e) {
                                        // rollback on error
                                        setModalState(() {
                                          post.comments[commentIndex].isLiked =
                                              !post.comments[commentIndex]
                                                  .isLiked;
                                          post.comments[commentIndex]
                                              .likeCount += post
                                                  .comments[commentIndex]
                                                  .isLiked
                                              ? 1
                                              : -1;
                                        });
                                        // Show error feedback
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to update like: $e'),
                                              backgroundColor: Colors.red,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showCommentLikes(
                                        post.comments[commentIndex].id),
                                    child: Text(
                                      '${post.comments[commentIndex].likeCount}',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      // Set reply parent and prefill mention
                                      final authorName = post
                                          .comments[commentIndex].authorName;
                                      final fallbackId =
                                          post.comments[commentIndex].authorId;
                                      String mention;
                                      if (authorName.isNotEmpty) {
                                        final sanitized =
                                            authorName.replaceAll(' ', '');
                                        mention =
                                            '@${sanitized.length > 20 ? sanitized.substring(0, 20) : sanitized} ';
                                      } else if (fallbackId.isNotEmpty) {
                                        mention =
                                            '@${fallbackId.substring(0, 8)} ';
                                      } else {
                                        mention = '';
                                      }
                                      setModalState(() {
                                        replyToCommentId = post
                                            .comments[commentIndex]
                                            .id; // Track parent comment
                                        commentController.text = mention;
                                        // place cursor at end
                                        commentController.selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset: commentController
                                                        .text.length));
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply_outlined,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6)),
                                        const SizedBox(width: 6),
                                        Text('Reply',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Nested replies (rendered indented)
                              if (post.comments[commentIndex].replies
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: post.comments[commentIndex].replies
                                      .map((reply) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AvatarWidget(
                                            wallet: reply.authorWallet ??
                                                reply.authorId,
                                            avatarUrl: reply.authorAvatar,
                                            radius: 12,
                                            allowFabricatedFallback: true,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(reply.authorName,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface)),
                                                const SizedBox(height: 4),
                                                Text(reply.content,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.8))),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Text(
                                                        _getTimeAgo(
                                                            reply.timestamp),
                                                        style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.5))),
                                                    const SizedBox(width: 16),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                          icon: Icon(
                                                            reply.isLiked
                                                                ? Icons.favorite
                                                                : Icons
                                                                    .favorite_border,
                                                            size: 14,
                                                            color: reply.isLiked
                                                                ? Colors.red
                                                                : Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6),
                                                          ),
                                                          onPressed: () async {
                                                            setModalState(() {
                                                              reply.isLiked =
                                                                  !reply
                                                                      .isLiked;
                                                              reply.likeCount +=
                                                                  reply.isLiked
                                                                      ? 1
                                                                      : -1;
                                                            });
                                                            try {
                                                              await CommunityService
                                                                  .toggleCommentLike(
                                                                      reply,
                                                                      post.id);
                                                            } catch (e) {
                                                              setModalState(() {
                                                                reply.isLiked =
                                                                    !reply
                                                                        .isLiked;
                                                                reply.likeCount +=
                                                                    reply.isLiked
                                                                        ? 1
                                                                        : -1;
                                                              });
                                                              // Show error feedback
                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                        'Failed to update like: $e'),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                    duration: const Duration(
                                                                        seconds:
                                                                            2),
                                                                  ),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTap: () =>
                                                              _showCommentLikes(
                                                                  reply.id),
                                                          child: Text(
                                                            '${reply.likeCount}',
                                                            style: GoogleFonts.inter(
                                                                fontSize: 12,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Comment input section
              Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply indicator (shows when replying to a comment)
                    if (replyToCommentId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeProvider>(context)
                              .accentColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply,
                                size: 16,
                                color: Provider.of<ThemeProvider>(context)
                                    .accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to comment',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Provider.of<ThemeProvider>(context)
                                      .accentColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  replyToCommentId = null;
                                  commentController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        // Current user avatar
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, _) {
                            final currentUser = profileProvider.currentUser;
                            final avatarUrl = currentUser?.avatar;
                            final displayName = currentUser?.displayName ??
                                currentUser?.username ??
                                'U';

                            return CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Provider.of<ThemeProvider>(context)
                                      .accentColor,
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Provider.of<ThemeProvider>(context)
                                      .accentColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (value) async {
                              if (value.trim().isNotEmpty) {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final authorContext =
                                      await _resolveCommentAuthorContext();
                                  if (authorContext == null) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please complete onboarding or re-login to comment.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  debugPrint(
                                      '💬 Adding comment with parentCommentId: $replyToCommentId');
                                  await CommunityService.addComment(
                                    post,
                                    value.trim(),
                                    authorContext.displayName,
                                    currentUserId: authorContext.userId,
                                    parentCommentId:
                                        replyToCommentId, // Pass parent comment ID for nesting
                                    userName: authorContext.displayName,
                                    authorWallet: authorContext.walletAddress,
                                    authorAvatar: authorContext.avatarUrl,
                                  );
                                  // Refresh comments from backend to ensure server state (avatars, real ids)
                                  try {
                                    final backendComments =
                                        await BackendApiService()
                                            .getComments(postId: post.id);
                                    post.comments = backendComments;
                                    post.commentCount = post.comments.length;
                                  } catch (e) {
                                    debugPrint(
                                        'Warning: failed to refresh comments after submit: $e');
                                  }
                                  if (!mounted) return;
                                  // Reset reply state
                                  replyToCommentId = null;
                                  setModalState(() {});
                                  setState(() {});
                                  commentController.clear();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Comment added!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to add comment: $e'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Provider.of<ThemeProvider>(context).accentColor,
                                Provider.of<ThemeProvider>(context)
                                    .accentColor
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              if (commentController.text.trim().isNotEmpty) {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final commentText =
                                      commentController.text.trim();
                                  final authorContext =
                                      await _resolveCommentAuthorContext();
                                  if (authorContext == null) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please complete onboarding or re-login to comment.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  debugPrint(
                                      '💬 Adding comment (button) with parentCommentId: $replyToCommentId');
                                  await CommunityService.addComment(
                                    post,
                                    commentText,
                                    authorContext.displayName,
                                    currentUserId: authorContext.userId,
                                    parentCommentId:
                                        replyToCommentId, // Pass parent comment ID for nesting
                                    userName: authorContext.displayName,
                                    authorWallet: authorContext.walletAddress,
                                    authorAvatar: authorContext.avatarUrl,
                                  );
                                  // Refresh comments to reflect server state
                                  try {
                                    final backendComments =
                                        await BackendApiService()
                                            .getComments(postId: post.id);
                                    post.comments = backendComments;
                                    post.commentCount = post.comments.length;
                                  } catch (e) {
                                    debugPrint(
                                        'Warning: failed to refresh comments after send: $e');
                                  }
                                  if (!mounted) return;

                                  // Reset reply state
                                  replyToCommentId = null;
                                  setModalState(() {});
                                  setState(() {});
                                  commentController.clear();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Comment added!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to add comment: $e'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              Icons.send,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                      ], // End of Row children
                    ), // End of Row
                  ], // End of Column children
                ), // End of Column
              ), // End of Container
            ], // End of main Column children
          ),
        ),
      ),
    );
  }

  void _sharePost(int index) async {
    if (index >= _communityPosts.length) return;
    final post = _communityPosts[index];
    _showShareModal(post);
  }

  void _showShareModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Share Post',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for profiles...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.primaryContainer,
                  ),
                  onChanged: (query) async {
                    if (query.trim().isEmpty) {
                      setModalState(() {
                        searchResults.clear();
                      });
                      return;
                    }
                    setModalState(() => isSearching = true);
                    try {
                      final resp = await BackendApiService()
                          .search(query: query, type: 'profiles', limit: 20);
                      final list = <Map<String, dynamic>>[];
                      if (resp['success'] == true && resp['results'] is Map) {
                        final profiles =
                            (resp['results']['profiles'] as List?) ?? [];
                        for (final p in profiles) {
                          try {
                            list.add(p as Map<String, dynamic>);
                          } catch (_) {}
                        }
                      }
                      setModalState(() {
                        searchResults = list;
                        isSearching = false;
                      });
                    } catch (e) {
                      setModalState(() => isSearching = false);
                    }
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(Icons.link, color: theme.colorScheme.primary),
                      title: Text('Copy Link', style: GoogleFonts.inter()),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final sheetNavigator = Navigator.of(sheetContext);
                        await Clipboard.setData(ClipboardData(
                            text: 'https://app.kubus.site/post/${post.id}'));
                        if (!mounted) return;
                        sheetNavigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                          ),
                        );

                        // Track analytics
                        BackendApiService().trackAnalyticsEvent(
                          eventType: 'share_copy_link',
                          postId: post.id,
                          metadata: {'method': 'copy_link'},
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.share, color: theme.colorScheme.primary),
                      title: Text('Share via...', style: GoogleFonts.inter()),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final shareText =
                            '${post.content}\n\n- ${post.authorName} on app.kubus\n\nhttps://app.kubus.site/post/${post.id}';
                        await SharePlus.instance
                            .share(ShareParams(text: shareText));
                        BackendApiService().trackAnalyticsEvent(
                          eventType: 'share_external',
                          postId: post.id,
                          metadata: {'method': 'platform_share'},
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (searchController.text.isNotEmpty) ...[
                const Divider(),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : searchResults.isEmpty
                          ? Center(
                              child: EmptyStateCard(
                                icon: Icons.person_search,
                                title: 'No profiles found',
                                description: 'Try a different search term',
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: searchResults.length,
                              itemBuilder: (ctx, idx) {
                                final profile = searchResults[idx];
                                final walletAddr = profile['wallet_address'] ??
                                    profile['walletAddress'] ??
                                    profile['wallet'] ??
                                    profile['walletAddr'];
                                final username = profile['username'] ??
                                    walletAddr ??
                                    'unknown';
                                final display = profile['displayName'] ??
                                    profile['display_name'] ??
                                    username;
                                final avatar =
                                    profile['avatar'] ?? profile['avatar_url'];
                                return ListTile(
                                  leading: AvatarWidget(
                                      wallet: username,
                                      avatarUrl: avatar,
                                      radius: 20),
                                  title: Text(display ?? 'Unnamed',
                                      style: GoogleFonts.inter()),
                                  subtitle: Text('@$username',
                                      style: GoogleFonts.inter(fontSize: 12)),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);
                                    final messenger =
                                        ScaffoldMessenger.of(context);

                                    try {
                                      // Share post via DM
                                      await BackendApiService().sharePostViaDM(
                                        postId: post.id,
                                        recipientWallet: walletAddr ?? username,
                                        message: 'Check out this post!',
                                      );
                                      BackendApiService().trackAnalyticsEvent(
                                        eventType: 'share_dm',
                                        postId: post.id,
                                        metadata: {
                                          'recipient': walletAddr ?? username
                                        },
                                      );

                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Shared post with @$username',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to share: $e'),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRepostModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final repostContentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Repost',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                    Row(
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel', style: GoogleFonts.inter())),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final content = repostContentController.text.trim();
                            Navigator.pop(sheetContext);
                            final messenger =
                                ScaffoldMessenger.of(context);

                            try {
                              // Create repost via backend
                              final createdRepost =
                                  await BackendApiService().createRepost(
                                originalPostId: post.id,
                                content: content.isNotEmpty ? content : null,
                              );
                              BackendApiService().trackAnalyticsEvent(
                                eventType: 'repost_created',
                                postId: post.id,
                                metadata: {'has_comment': content.isNotEmpty},
                              );

                              if (!mounted) return;
                              // Insert repost into feed immediately for instant feedback
                              setState(() {
                                _communityPosts.insert(0, createdRepost);
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(content.isEmpty
                                      ? 'Reposted!'
                                      : 'Reposted with comment!'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to repost: $e'),
                                ),
                              );
                            }
                          },
                          child: Text('Repost', style: GoogleFonts.inter()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: repostContentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add your thoughts (optional)...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Reposting:',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AvatarWidget(
                                    wallet: post.authorId,
                                    avatarUrl: post.authorAvatar,
                                    radius: 16,
                                    enableProfileNavigation: false),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(post.authorName,
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(_getTimeAgo(post.timestamp),
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(post.content,
                                style: GoogleFonts.inter(fontSize: 14),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis),
                            if (post.imageUrl != null &&
                                post.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(post.imageUrl!,
                                    fit: BoxFit.cover,
                                    height: 120,
                                    width: double.infinity),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  void _viewRepostsList(CommunityPost post) async {
    if (!mounted) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reposted by',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: BackendApiService().getPostReposts(postId: post.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading reposts',
                            style: GoogleFonts.inter()));
                  }
                  final reposts = snapshot.data ?? [];
                  if (reposts.isEmpty) {
                    return Center(
                      child: EmptyStateCard(
                        icon: Icons.repeat,
                        title: 'No reposts yet',
                        description: 'This post has not been reposted yet.',
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: reposts.length,
                    itemBuilder: (ctx, idx) {
                      final repost = reposts[idx];
                      final user = repost['user'] as Map<String, dynamic>?;
                      final username = user?['username'] ??
                          user?['walletAddress'] ??
                          'Unknown';
                      final displayName = user?['displayName'] ?? username;
                      final avatar = user?['avatar'];
                      final comment = repost['repostComment'] as String?;
                      final createdAt =
                          DateTime.tryParse(repost['createdAt'] ?? '');

                      return ListTile(
                        leading: AvatarWidget(
                            wallet: username, avatarUrl: avatar, radius: 20),
                        title: Text(displayName,
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username',
                                style: GoogleFonts.inter(fontSize: 12)),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(comment,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(_getTimeAgo(createdAt),
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)))
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepostOptions(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  Text('Unrepost', style: GoogleFonts.inter(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _unrepostPost(post);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              title: Text('Cancel', style: GoogleFonts.inter()),
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _unrepostPost(CommunityPost post) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unrepost', style: GoogleFonts.inter()),
        content: Text('Are you sure you want to remove this repost?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Unrepost', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BackendApiService().deleteRepost(post.id);
      BackendApiService().trackAnalyticsEvent(
        eventType: 'repost_deleted',
        postId: post.originalPostId ?? post.id,
        metadata: {'repost_id': post.id},
      );

      await _loadCommunityData();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Repost removed')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to unrepost: $e')),
      );
    }
  }

  void _viewPostDetail(int index) {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];

    // Open full post detail screen instead of dialog
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  // ==================== Post metadata helpers ====================

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ar_drop':
      case 'art_drop':
        return Icons.place_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'poll':
        return Icons.poll_outlined;
      case 'question':
        return Icons.help_outline;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'review':
        return Icons.rate_review_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _formatCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'ar_drop':
      case 'art_drop':
        return 'AR Drop';
      case 'event':
        return 'Event';
      case 'poll':
        return 'Poll';
      case 'question':
        return 'Question';
      case 'announcement':
        return 'Announcement';
      case 'review':
        return 'Review';
      default:
        return category.replaceAll('_', ' ').split(' ').map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
    }
  }

  void _filterByTag(String tag) {
    // TODO: Implement tag filtering - for now show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Search posts with #$tag'),
        action: SnackBarAction(
          label: 'Search',
          onPressed: () {
            // Could open search with pre-filled tag
            _showSearchBottomSheet();
          },
        ),
      ),
    );
  }

  void _searchMention(String mention) {
    // Navigate to user profile search
    _viewUserProfile(mention);
  }

  void _openLocationOnMap(CommunityLocation location) {
    // TODO: Navigate to map screen centered on location
    if (location.lat != null && location.lng != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location: ${location.name ?? 'Map view'}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Could navigate to map screen
            },
          ),
        ),
      );
    }
  }

  void _openArtworkDetail(CommunityArtworkReference artwork) {
    // Navigate to artwork detail screen
    Navigator.pushNamed(context, '/artwork', arguments: {'artworkId': artwork.id});
  }

  void _openGroupFromPost(CommunityGroupReference group) {
    // Navigate to group feed
    _openGroupFeed(CommunityGroupSummary(
      id: group.id,
      name: group.name,
      slug: group.slug,
      coverImage: group.coverImage,
      description: group.description,
      isPublic: true,
      ownerWallet: '',
      memberCount: 0,
      isMember: false,
      isOwner: false,
    ));
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _ExpandableFabOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExpandableFabOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _CommentAuthorContext {
  final String userId;
  final String? walletAddress;
  final String displayName;
  final String? avatarUrl;

  const _CommentAuthorContext({
    required this.userId,
    required this.displayName,
    this.walletAddress,
    this.avatarUrl,
  });
}
