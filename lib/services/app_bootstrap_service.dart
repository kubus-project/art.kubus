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
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/recent_activity_provider.dart';
import '../providers/saved_items_provider.dart';
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

    await _runTask('wallet_init', walletProvider.initialize);

    final resolvedWallet = (walletAddress ?? '').trim().isNotEmpty
        ? walletAddress!.trim()
        : walletProvider.currentWalletAddress;

    await _runTask('auth_token', () => backend.ensureAuthLoaded(walletAddress: resolvedWallet));

    final shouldLoadWeb3 = AppConfig.enableWeb3;
    final shouldLoadCommunity = AppConfig.enableUserProfiles;

    final futures = <Future<void>>[
      _runTask('cache', cacheProvider.initialize),
      _runTask('saved_items', savedItemsProvider.initialize),
      _runTask('navigation', navigationProvider.initialize),
      _runTask('tasks', () => Future<void>.sync(taskProvider.initializeProgress)),
      _runTask('artworks', () => artworkProvider.loadArtworks(refresh: true)),
      _runTask('collectibles', () => collectiblesProvider.initialize(loadMockIfEmpty: AppConfig.isDevelopment)),
      _runTask('institutions', () => institutionProvider.initialize(seedMockIfEmpty: AppConfig.isDevelopment)),
    ];

    if (AppConfig.isFeatureEnabled('collabInvites')) {
      futures.add(_runTask('collab_invites', () async {
        await collabProvider.initialize(refresh: true);
        collabProvider.startInvitePolling();
      }));
    }

    if (shouldLoadCommunity) {
      futures.add(_runTask('recent_activity', () => recentActivityProvider.initialize(force: true)));
      futures.add(_runTask(
        'notifications',
        () => notificationProvider.initialize(walletOverride: resolvedWallet, force: true),
      ));
      futures.add(_runTask('community_groups', () => communityHubProvider.loadGroups(refresh: true)));
      futures.add(_runTask('chat', () => chatProvider.initialize(initialWallet: resolvedWallet)));
    }

    if (shouldLoadWeb3) {
      futures.add(_runTask('web3_provider', () => web3Provider.initialize(attemptRestore: true)));
      if (resolvedWallet != null && resolvedWallet.isNotEmpty) {
        futures.add(_runTask('wallet_refresh', () => walletProvider.refreshData()));
        futures.add(_runTask('profile_refresh', () async {
          await profileProvider.loadProfile(resolvedWallet);
          await profileProvider.refreshStats();
        }));
      }
    }

    await Future.wait(futures, eagerError: false);

    // Signal listeners (including desktop screens) that fresh data is ready.
    appRefreshProvider.triggerAll();
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
