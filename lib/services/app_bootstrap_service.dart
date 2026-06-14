import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/config.dart';
import '../providers/app_mode_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/cache_provider.dart';
import '../providers/collectibles_provider.dart';
import '../providers/collab_provider.dart';
import '../providers/events_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/institution_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/marker_management_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/profile_provider.dart';
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
  const AppBootstrapService({
    this.taskTimeout = const Duration(seconds: 12),
  });

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
    final profileProvider = context.read<ProfileProvider>();
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
      _runTask(
        'tasks',
        () => hasAuth
            ? taskProvider.refreshAchievementsForCurrentUser()
            : Future<void>.sync(taskProvider.initializeProgress),
      ),
    ];

    final p1 = <Future<void>>[
      _runTask('artworks', () => artworkProvider.loadArtworks(refresh: true)),
      _runTask(
        'collectibles',
        () => collectiblesProvider.initialize(
          loadMockIfEmpty: AppConfig.isDevelopment,
        ),
      ),
      _runTask(
          'institutions',
          () => institutionProvider.initialize(
              seedMockIfEmpty: AppConfig.isDevelopment)),
      _runTask('events', () => eventsProvider.initialize(refresh: true)),
    ];

    if (AppConfig.isFeatureEnabled('collabInvites') && hasAuth) {
      p1.add(_runTask('collab_invites', () async {
        await collabProvider.initialize(refresh: true);
        collabProvider.startInvitePolling();
      }));
    }

    if (shouldLoadCommunity) {
      if (hasAuth) {
        p1.add(_runTask(
          'secure_account_status',
          backend.syncSecureAccountStatusToPrefs,
        ));
      }
    }

    if (shouldLoadWeb3) {
      p1.add(_runTask('web3_provider',
          () => web3Provider.initialize(attemptRestore: true)));
      if (resolvedWallet != null && resolvedWallet.isNotEmpty) {
        p1.add(_runTask('wallet_refresh', () => walletProvider.refreshData()));
        p1.add(_runTask('profile_refresh', () async {
          await profileProvider.loadProfile(resolvedWallet);
          await profileProvider.refreshStats();
        }));
        p1.add(_runTask(
            'home_activity_stats_snapshot',
            () => statsProvider.ensureSnapshot(
                  entityType: 'user',
                  entityId: resolvedWallet,
                  metrics: homeActivityPublicSnapshotMetrics,
                  scope: 'public',
                )));
        p1.add(_runTask(
            'home_activity_discovered_snapshot',
            () => statsProvider.ensureSnapshot(
                  entityType: 'user',
                  entityId: resolvedWallet,
                  metrics: homeActivityPrivateSnapshotMetrics,
                  scope: 'private',
                )));
        p1.add(_runTask('my_exhibitions', () async {
          await exhibitionsProvider.loadExhibitions(
            refresh: true,
            mine: true,
            limit: 50,
          );
        }));
        p1.add(_runTask('home_program_views', () async {
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
        }));
      }
    }

    if (hasAuth) {
      p1.add(_runTask('marker_management',
          () => markerManagementProvider.initialize(force: true)));
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
          'AppBootstrapService: warm-up tiers complete (p0=${p0.length}, p1=${p1.length})');
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
