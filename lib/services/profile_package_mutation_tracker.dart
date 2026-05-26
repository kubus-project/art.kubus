import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart';
import '../models/achievements.dart';
import '../models/artwork.dart';
import '../models/collection_record.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../utils/wallet_utils.dart';
import 'profile_package_service.dart';

enum ProfilePackageMutationKind {
  profileChanged,
  profileMediaChanged,
  followStateChanged,
  postCreated,
  postUpdated,
  postDeleted,
  achievementResult,
  artworkCreated,
  artworkUpdated,
  artworkDeleted,
  artworkPublished,
  artworkUnpublished,
  collectionCreated,
  collectionUpdated,
  collectionDeleted,
  collectionMembershipChanged,
  eventCreated,
  eventUpdated,
  eventDeleted,
  eventPublished,
  eventUnpublished,
  showcaseChanged,
  publicStatsChanged,
}

class ProfilePackageMutationEvent {
  const ProfilePackageMutationEvent({
    required this.kind,
    required this.wallet,
    required this.hasAchievementResult,
    required this.timestamp,
  });

  final ProfilePackageMutationKind kind;
  final String wallet;
  final bool hasAchievementResult;
  final DateTime timestamp;
}

/// Single write-side contract for keeping public profile packages coherent.
///
/// Any backend write that can change a public profile header, stats,
/// achievements, posts, or showcase data should call this tracker instead of
/// calling [ProfilePackageService] directly. This keeps cache invalidation
/// policy explicit and gives debug builds a concise mutation trace. Providers
/// and UI code should use this gateway after successful writes; low-level
/// services may use it only when they are the reusable write boundary.
class ProfilePackageMutationTracker {
  ProfilePackageMutationTracker._();

  static final List<ProfilePackageMutationEvent> _debugEvents =
      <ProfilePackageMutationEvent>[];
  static void Function(ProfilePackageMutationEvent event)? _debugSink;

  @visibleForTesting
  static List<ProfilePackageMutationEvent> get debugEvents =>
      List<ProfilePackageMutationEvent>.unmodifiable(_debugEvents);

  @visibleForTesting
  static void setDebugSink(
    void Function(ProfilePackageMutationEvent event)? sink,
  ) {
    _debugSink = sink;
  }

  @visibleForTesting
  static void clearDebugEventsForTesting() {
    _debugEvents.clear();
    _debugSink = null;
  }

  static void profileChanged(String wallet) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.profileChanged, resolved);
    ProfilePackageService.invalidate(resolved);
  }

  static void profileMediaChanged(String wallet) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.profileMediaChanged, resolved);
    ProfilePackageService.invalidate(resolved);
  }

  static void followStateChanged({
    required String targetWallet,
    String? actorWallet,
    bool? isFollowing,
    int? followersCount,
    int? followingCount,
  }) {
    final target = _wallet(targetWallet);
    if (target == null) return;
    _debug(ProfilePackageMutationKind.followStateChanged, target);
    ProfilePackageService.patchUser(
      target,
      (current) => current.copyWith(
        isFollowing: isFollowing ?? current.isFollowing,
        followersCount: followersCount ?? current.followersCount,
      ),
    );
    if (followersCount != null) {
      ProfilePackageService.patchStats(target, <String, int>{
        'followers': followersCount,
      });
    }

    final actor = _wallet(actorWallet);
    if (actor != null && followingCount != null) {
      ProfilePackageService.patchStats(actor, <String, int>{
        'following': followingCount,
      });
    }
  }

  static void userPatched({
    required String wallet,
    required User Function(User current) patch,
  }) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.profileChanged, resolved);
    ProfilePackageService.patchUser(resolved, patch);
  }

  static void publicStatsChanged({
    required String wallet,
    required Map<String, int> patch,
  }) {
    final resolved = _wallet(wallet);
    if (resolved == null || patch.isEmpty) return;
    _debug(ProfilePackageMutationKind.publicStatsChanged, resolved);
    ProfilePackageService.patchStats(resolved, patch);
  }

  static void postCreated({
    required CommunityPost post,
    AchievementEventResult? achievementResult,
  }) {
    final wallet = _wallet(post.authorWallet ?? post.authorId);
    if (wallet == null) return;
    final result = achievementResult ?? post.achievementResult;
    _debug(
      ProfilePackageMutationKind.postCreated,
      wallet,
      hasAchievementResult: result != null,
    );
    ProfilePackageService.invalidatePosts(wallet);
    if (result != null) {
      ProfilePackageService.patchAchievementResult(wallet, result);
    }
  }

  static void postUpdated({required CommunityPost post}) {
    final wallet = _wallet(post.authorWallet ?? post.authorId);
    if (wallet == null) return;
    _debug(ProfilePackageMutationKind.postUpdated, wallet);
    ProfilePackageService.invalidatePosts(wallet);
  }

  static void postDeleted({required String authorWallet}) {
    final wallet = _wallet(authorWallet);
    if (wallet == null) return;
    _debug(ProfilePackageMutationKind.postDeleted, wallet);
    ProfilePackageService.invalidatePosts(wallet);
  }

  static void postsPatched({
    required String wallet,
    required List<CommunityPost> posts,
    bool updateCount = true,
  }) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.postUpdated, resolved);
    ProfilePackageService.patchPosts(
      resolved,
      posts,
      updateCount: updateCount,
    );
  }

  static void achievementResult({
    required String wallet,
    required AchievementEventResult result,
  }) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(
      ProfilePackageMutationKind.achievementResult,
      resolved,
      hasAchievementResult: true,
    );
    ProfilePackageService.patchAchievementResult(resolved, result);
  }

  static void achievementsChanged(String wallet) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.achievementResult, resolved);
    ProfilePackageService.invalidateAchievements(resolved);
  }

  static void showcaseChanged(String wallet) {
    final resolved = _wallet(wallet);
    if (resolved == null) return;
    _debug(ProfilePackageMutationKind.showcaseChanged, resolved);
    ProfilePackageService.invalidateShowcase(resolved);
  }

  static void artworkChanged(
    Artwork artwork, {
    ProfilePackageMutationKind kind = ProfilePackageMutationKind.artworkUpdated,
  }) {
    final wallet = _wallet(artwork.walletAddress);
    if (wallet == null) return;
    _debug(kind, wallet);
    ProfilePackageService.invalidateShowcase(wallet);
  }

  static void collectionChanged(
    CollectionRecord collection, {
    ProfilePackageMutationKind kind =
        ProfilePackageMutationKind.collectionUpdated,
  }) {
    final wallet = _wallet(collection.walletAddress);
    if (wallet == null) return;
    _debug(kind, wallet);
    ProfilePackageService.invalidateShowcase(wallet);
  }

  static void eventChanged(
    KubusEvent event, {
    ProfilePackageMutationKind kind = ProfilePackageMutationKind.eventUpdated,
  }) {
    final wallet = _wallet(event.host?.walletAddress ?? event.host?.id);
    if (wallet == null) return;
    _debug(kind, wallet);
    ProfilePackageService.invalidateShowcase(wallet);
  }

  static String? _wallet(String? wallet) {
    final resolved = WalletUtils.canonical(wallet ?? '');
    if (resolved.isEmpty) return null;
    return resolved;
  }

  static void _debug(
    ProfilePackageMutationKind kind,
    String wallet, {
    bool hasAchievementResult = false,
  }) {
    final event = ProfilePackageMutationEvent(
      kind: kind,
      wallet: wallet,
      hasAchievementResult: hasAchievementResult,
      timestamp: DateTime.now(),
    );
    _debugEvents.add(event);
    if (_debugEvents.length > 100) {
      _debugEvents.removeAt(0);
    }
    _debugSink?.call(event);
    if (!kDebugMode) return;
    final achievementSuffix = kind == ProfilePackageMutationKind.postCreated ||
            kind == ProfilePackageMutationKind.achievementResult
        ? ' achievement=$hasAchievementResult'
        : '';
    debugPrint(
      'ProfilePackageMutationTracker ${kind.name} '
      'wallet=$wallet$achievementSuffix',
    );
  }
}
