import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/config.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/cache_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/collectibles_provider.dart';
import '../providers/community_hub_provider.dart';
import '../providers/collab_provider.dart';
import '../providers/institution_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/marker_management_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/recent_activity_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/web3provider.dart';
import 'backend_api_service.dart';

/// Centralized bootstrapper that preloads the core providers before the user
/// reaches the main UI. This keeps home/community/notification data in sync
/// without requiring the user to manually refresh after launch.
class AppBootstrapService {
  const AppBootstrapService({
    this.taskTimeout = const Duration(seconds: 12),
  });

  final Duration taskTimeout;

  Future<void> warmUp({
    required BuildContext context,
    String? walletAddress,
  }) async {
    final backend = BackendApiService();

    // Providers
    final artworkProvider = context.read<ArtworkProvider>();
    final recentActivityProvider = context.read<RecentActivityProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final navigationProvider = context.read<NavigationProvider>();
    final communityHubProvider = context.read<CommunityHubProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final web3Provider = context.read<Web3Provider>();
    final chatProvider = context.read<ChatProvider>();
    final cacheProvider = context.read<CacheProvider>();
    final savedItemsProvider = context.read<SavedItemsProvider>();
    final collectiblesProvider = context.read<CollectiblesProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final taskProvider = context.read<TaskProvider>();
    final appRefreshProvider = context.read<AppRefreshProvider>();
    final collabProvider = context.read<CollabProvider>();
    final statsProvider = context.read<StatsProvider>();
    final presenceProvider = context.read<PresenceProvider>();
    final markerManagementProvider = context.read<MarkerManagementProvider>();

    await _runTask('wallet_init', walletProvider.initialize);

    final resolvedWallet = (walletAddress ?? '').trim().isNotEmpty
        ? walletAddress!.trim()
        : walletProvider.currentWalletAddress;

    await _runTask('auth_token', () => backend.ensureAuthLoaded(walletAddress: resolvedWallet));

    final shouldLoadWeb3 = AppConfig.enableWeb3;
    final shouldLoadCommunity = AppConfig.enableUserProfiles;

    final p0 = <Future<void>>[
      _runTask('cache', cacheProvider.initialize),
      _runTask('saved_items', savedItemsProvider.initialize),
      _runTask('navigation', navigationProvider.initialize),
      _runTask('stats', statsProvider.initialize),
      _runTask('presence', presenceProvider.initialize),
      _runTask('tasks', () => Future<void>.sync(taskProvider.initializeProgress)),
    ];

    final p1 = <Future<void>>[
      _runTask('artworks', () => artworkProvider.loadArtworks(refresh: true)),
      _runTask('collectibles', () => collectiblesProvider.initialize(loadMockIfEmpty: AppConfig.isDevelopment)),
      _runTask('institutions', () => institutionProvider.initialize(seedMockIfEmpty: AppConfig.isDevelopment)),
    ];

    final hasAuth = (backend.getAuthToken() ?? '').trim().isNotEmpty;
    if (AppConfig.isFeatureEnabled('collabInvites') && hasAuth) {
      p1.add(_runTask('collab_invites', () async {
        await collabProvider.initialize(refresh: true);
        collabProvider.startInvitePolling();
      }));
    }

    if (shouldLoadCommunity) {
      p1.add(_runTask('recent_activity', () => recentActivityProvider.initialize(force: true)));
      p1.add(_runTask(
        'notifications',
        () => notificationProvider.initialize(walletOverride: resolvedWallet, force: true),
      ));
      p1.add(_runTask('community_groups', () => communityHubProvider.loadGroups(refresh: true)));
      p1.add(_runTask('chat', () => chatProvider.initialize(initialWallet: resolvedWallet)));
    }

    if (shouldLoadWeb3) {
      p1.add(_runTask('web3_provider', () => web3Provider.initialize(attemptRestore: true)));
      if (resolvedWallet != null && resolvedWallet.isNotEmpty) {
        p1.add(_runTask('wallet_refresh', () => walletProvider.refreshData()));
        p1.add(_runTask('profile_refresh', () async {
          await profileProvider.loadProfile(resolvedWallet);
          await profileProvider.refreshStats();
        }));
        p1.add(_runTask('stats_snapshot', () => statsProvider.ensureSnapshot(
              entityType: 'user',
              entityId: resolvedWallet,
              metrics: const ['followers', 'following', 'posts', 'artworks', 'viewsReceived'],
              scope: 'public',
            )));
      }
    }

    if (hasAuth) {
      p1.add(_runTask('marker_management', () => markerManagementProvider.initialize(force: true)));
    }

    await Future.wait(p0, eagerError: false);

    if (p1.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await Future.wait(p1, eagerError: false);
    }

    if (kDebugMode) {
      debugPrint('AppBootstrapService: warm-up tiers complete (p0=${p0.length}, p1=${p1.length})');
    }

    // Signal listeners with view-aware targeted refreshes (avoid global fan-out).
    appRefreshProvider.triggerNotifications(onlyIfActive: true);
    appRefreshProvider.triggerChat(onlyIfActive: true);
    appRefreshProvider.triggerCommunity(onlyIfActive: true);
    appRefreshProvider.triggerProfile(onlyIfActive: true);
  }

  Future<void> _runTask(String label, FutureOr<void> Function() task) async {
    try {
      await Future<void>.sync(task).timeout(taskTimeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AppBootstrapService: $label failed: $e');
        debugPrint('$st');
      }
    }
  }
}
