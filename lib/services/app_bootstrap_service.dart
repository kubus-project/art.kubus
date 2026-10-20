import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/config.dart';
import '../providers/app_mode_provider.dart';
import '../providers/availability_operator_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/cache_provider.dart';
import '../providers/collectibles_provider.dart';
import '../providers/collab_provider.dart';
import '../providers/events_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/institution_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/marker_management_provider.dart';
import '../providers/kubus_node_provider.dart';
import '../providers/spatial_library_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/promotion_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/web3provider.dart';
import '../core/startup_trace.dart';
import '../utils/home_activity_cards.dart';
import 'backend_api_service.dart';

/// Centralized bootstrapper that preloads the core providers before the user
/// reaches the main UI. Screen-specific providers still own heavyweight
/// feed, notification, chat, and group loading so first paint stays lean.
class AppBootstrapService {
  const AppBootstrapService({this.taskTimeout = const Duration(seconds: 12)});

  final Duration taskTimeout;

  Future<void> warmUp({
    required BuildContext context,
    String? walletAddress,
  }) async {
    StartupTrace.mark('deferred warm-up start');
    final backend = BackendApiService();
    final appModeProvider = context.read<AppModeProvider>();

    // Providers
    final artworkProvider = context.read<ArtworkProvider>();
    final navigationProvider = context.read<NavigationProvider>();
    final walletProvider = context.read<WalletProvider>();
    final web3Provider = context.read<Web3Provider>();
    final cacheProvider = context.read<CacheProvider>();
    final savedItemsProvider = context.read<SavedItemsProvider>();
    final collectiblesProvider = context.read<CollectiblesProvider>();
    final eventsProvider = context.read<EventsProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final taskProvider = context.read<TaskProvider>();
    final collabProvider = context.read<CollabProvider>();
    final statsProvider = context.read<StatsProvider>();
    final presenceProvider = context.read<PresenceProvider>();
    final markerManagementProvider = context.read<MarkerManagementProvider>();
    final kubusNodeProvider = context.read<KubusNodeProvider>();
    final spatialLibraryProvider = context.read<SpatialLibraryProvider>();
    final availabilityOperatorProvider =
        context.read<AvailabilityOperatorProvider>();
    final promotionProvider = context.read<PromotionProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    await _runTask('wallet_init', walletProvider.initialize);
    await _runTask('app_mode', appModeProvider.initialize);

    final resolvedWallet = (walletAddress ?? '').trim().isNotEmpty
        ? walletAddress!.trim()
        : walletProvider.currentWalletAddress;

    var hasAuth = false;
    await _runTask('auth_token', () async {
      hasAuth = await backend.restoreExistingSession();
      if (hasAuth) {
        await walletProvider.restoreAccountShellFromBackend(
          allowRefresh: false,
          loadWalletData: false,
        );
      }
    });

    final shouldLoadWeb3 = AppConfig.enableWeb3;
    final shouldLoadCommunity = AppConfig.enableUserProfiles;

    final p0 = <Future<void>>[
      _runTask('app_mode_refresh', appModeProvider.refreshMode),
      _runTask('cache', cacheProvider.initialize),
      _runTask('saved_items', savedItemsProvider.initialize),
      _runTask('navigation', navigationProvider.initialize),
      _runTask('stats', statsProvider.initialize),
      _runTask('presence', presenceProvider.initialize),
      if (AppConfig.isFeatureEnabled('availabilityNodes'))
        _runTask('kubus_node', kubusNodeProvider.initialize),
      _runTask('spatial_library', spatialLibraryProvider.initialize),
      if (AppConfig.isFeatureEnabled('availabilityNodes') &&
          hasAuth &&
          (resolvedWallet ?? '').trim().isNotEmpty)
        _runTask(
          'availability_operator',
          () => availabilityOperatorProvider.loadTokens(
            walletAddress: resolvedWallet!.trim(),
          ),
        ),
      _runTask(
        'tasks',
        () => hasAuth
            ? taskProvider.refreshAchievementsForCurrentUser()
            : Future<void>.sync(taskProvider.initializeProgress),
      ),
    ];

    final p1 = <Future<void>>[
      // Global promotion config, warmed centrally rather than by whichever
      // widget happens to open first. This also resumes a KUB8 transfer that a
      // previous run submitted but never got to verify, so the promotion is
      // never presented as unpaid to someone who already paid for it.
      _runTask('promotions', promotionProvider.loadConfig),
      // Reuse the Map/home provider cache rather than force a second page-1 query.
      _runTask('artworks', () => artworkProvider.loadArtworks()),
      _runTask(
        'collectibles',
        () => collectiblesProvider.initialize(
          loadMockIfEmpty: AppConfig.isDevelopment,
        ),
      ),
      _runTask(
        'institutions',
        () => institutionProvider.initialize(
          seedMockIfEmpty: AppConfig.isDevelopment,
        ),
      ),
      _runTask('events', () => eventsProvider.initialize(refresh: true)),
    ];

    // A restored session needs its notification state (authoritative unread
    // summary, user-room socket) without waiting for Settings or a wallet
    // reconnect; initialize() is a no-op without a session.
    if (hasAuth) {
      p1.add(_runTask('notifications', notificationProvider.initialize));
    }

    if (AppConfig.isFeatureEnabled('collabInvites') && hasAuth) {
      p1.add(
        _runTask('collab_invites', () async {
          await collabProvider.initialize(refresh: true);
          collabProvider.startInvitePolling();
        }),
      );
    }

    if (shouldLoadCommunity) {
      if (hasAuth) {
        p1.add(
          _runTask(
            'secure_account_status',
            backend.syncSecureAccountStatusToPrefs,
          ),
        );
      }
    }

    if (shouldLoadWeb3) {
      p1.add(
        _runTask(
          'web3_provider',
          () => web3Provider.initialize(attemptRestore: true),
        ),
      );
      if (resolvedWallet != null && resolvedWallet.isNotEmpty) {
        p1.add(
          _runTask(
            'wallet_collectible_index',
            () => collectiblesProvider.refreshWalletCollectibleIndex(
              resolvedWallet,
            ),
          ),
        );
        // Do not globally refresh wallet balances/transactions or reload the
        // profile a second time. Initializer already hydrates account/profile
        // state; wallet and profile views own explicit foreground refreshes.
        // In particular, refreshData() fans out into multiple Solana RPCs
        // and off-chain metadata gateway requests on every app entry.
        p1.add(
          _runTask(
            'home_activity_stats_snapshot',
            () => statsProvider.ensureSnapshot(
              entityType: 'user',
              entityId: resolvedWallet,
              metrics: homeActivityPublicSnapshotMetrics,
              scope: 'public',
            ),
          ),
        );
        p1.add(
          _runTask(
            'home_activity_discovered_snapshot',
            () => statsProvider.ensureSnapshot(
              entityType: 'user',
              entityId: resolvedWallet,
              metrics: homeActivityPrivateSnapshotMetrics,
              scope: 'private',
            ),
          ),
        );
        p1.add(
          _runTask('my_exhibitions', () async {
            await exhibitionsProvider.loadExhibitions(
              refresh: true,
              mine: true,
              limit: 50,
            );
          }),
        );
        p1.add(
          _runTask('home_program_views', () async {
            final nowUtc = DateTime.now().toUtc();
            await statsProvider.ensureSeries(
              entityType: 'user',
              entityId: resolvedWallet,
              metric: 'viewsReceived',
              bucket: 'month',
              timeframe: 'all',
              from: homeActivityProgramViewsFromUtc().toIso8601String(),
              to: homeActivityProgramViewsToUtc(nowUtc).toIso8601String(),
              groupBy: 'targetType',
              scope: 'private',
            );
          }),
        );
      }
    }

    if (hasAuth) {
      p1.add(
        _runTask(
          'marker_management',
          () => markerManagementProvider.initialize(force: true),
        ),
      );
    }

    await Future.wait(p0, eagerError: false);
    StartupTrace.mark('deferred warm-up p0 done');

    if (p1.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await Future.wait(p1, eagerError: false);
    }

    StartupTrace.mark('deferred warm-up end');
    if (kDebugMode) {
      debugPrint(
        'AppBootstrapService: warm-up tiers complete (p0=${p0.length}, p1=${p1.length})',
      );
    }
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
