import 'package:flutter/material.dart';

import '../models/recent_activity.dart';
import '../screens/post_detail_screen.dart';
import '../screens/art_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/saved_items_screen.dart';
import '../web3/wallet.dart';
import '../web3/achievements/achievements_page.dart';
import '../web3/marketplace/marketplace.dart';

class ActivityNavigation {
  ActivityNavigation._();

  static Future<bool> open(BuildContext context, RecentActivity activity) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final metadata = Map<String, dynamic>.from(activity.metadata);
    final actionUrl = activity.actionUrl ?? _string(metadata['actionUrl']);

    if (await _handleActionUrl(navigator, actionUrl, metadata)) {
      return true;
    }

    switch (activity.category) {
      case ActivityCategory.like:
      case ActivityCategory.comment:
      case ActivityCategory.share:
      case ActivityCategory.mention:
        final postId = _extractPostId(metadata);
        if (postId != null) {
          await _openPost(navigator, postId);
          return true;
        }
        break;
      case ActivityCategory.discovery:
      case ActivityCategory.nft:
      case ActivityCategory.ar:
        final artworkId = _extractArtworkId(metadata);
        if (artworkId != null) {
          await _openArtwork(navigator, artworkId);
          return true;
        }
        break;
      case ActivityCategory.reward:
        await _openWallet(navigator);
        return true;
      case ActivityCategory.follow:
        final userId = _extractUserId(metadata);
        if (userId != null) {
          await _openUserProfile(navigator, userId);
          return true;
        }
        break;
      case ActivityCategory.save:
        await _openCollections(navigator);
        return true;
      case ActivityCategory.achievement:
        await _openAchievements(navigator);
        return true;
      case ActivityCategory.system:
        break;
    }

    final fallback = _extractUserId(metadata) ?? _extractPostId(metadata) ?? _extractArtworkId(metadata);
    if (fallback != null) {
      if (fallback == _extractUserId(metadata)) {
        await _openUserProfile(navigator, fallback);
        return true;
      }
      if (fallback == _extractPostId(metadata)) {
        await _openPost(navigator, fallback);
        return true;
      }
      if (fallback == _extractArtworkId(metadata)) {
        await _openArtwork(navigator, fallback);
        return true;
      }
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Unable to open this activity right now.')),
    );
    return false;
  }

  static Future<bool> _handleActionUrl(
    NavigatorState navigator,
    String? actionUrl,
    Map<String, dynamic> metadata,
  ) async {
    if (actionUrl == null || actionUrl.isEmpty) {
      return false;
    }

    if (actionUrl.startsWith('app://')) {
      return _openAppScheme(navigator, actionUrl, metadata);
    }

    if (actionUrl.startsWith('/')) {
      return _openRelativePath(navigator, actionUrl, metadata);
    }

    return false;
  }

  static Future<bool> _openAppScheme(
    NavigatorState navigator,
    String url,
    Map<String, dynamic> metadata,
  ) async {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }

    final target = uri.host.toLowerCase();
    final segments = uri.pathSegments;
    final slug = segments.isNotEmpty ? segments.first : null;

    switch (target) {
      case 'posts':
      case 'post':
      case 'community':
        final postId = slug ?? _extractPostId(metadata);
        if (postId != null) {
          await _openPost(navigator, postId);
          return true;
        }
        break;
      case 'artwork':
      case 'artworks':
        final artworkId = slug ?? _extractArtworkId(metadata);
        if (artworkId != null) {
          await _openArtwork(navigator, artworkId);
          return true;
        }
        break;
      case 'user':
      case 'profile':
        final userId = slug ?? _extractUserId(metadata);
        if (userId != null) {
          await _openUserProfile(navigator, userId);
          return true;
        }
        break;
      case 'rewards':
      case 'wallet':
        await _openWallet(navigator);
        return true;
      case 'collections':
        await _openCollections(navigator);
        return true;
      case 'achievement':
      case 'achievements':
        await _openAchievements(navigator);
        return true;
      case 'trade':
      case 'marketplace':
        await _openMarketplace(navigator);
        return true;
    }
    return false;
  }

  static Future<bool> _openRelativePath(
    NavigatorState navigator,
    String url,
    Map<String, dynamic> metadata,
  ) async {
    final trimmed = url.startsWith('/') ? url.substring(1) : url;
    final parts = trimmed.split('?').first.split('/').where((segment) => segment.isNotEmpty).toList();
    if (parts.isEmpty) return false;

    final root = parts.first.toLowerCase();
    switch (root) {
      case 'community':
        if (parts.length >= 3 && parts[1].toLowerCase() == 'posts') {
          final postId = parts[2];
          await _openPost(navigator, postId);
          return true;
        }
        break;
      case 'artworks':
        if (parts.length >= 2) {
          await _openArtwork(navigator, parts[1]);
          return true;
        }
        break;
      case 'profile':
      case 'users':
        if (parts.length >= 2) {
          await _openUserProfile(navigator, parts[1]);
          return true;
        }
        break;
      case 'wallet':
      case 'rewards':
        await _openWallet(navigator);
        return true;
      case 'collections':
        await _openCollections(navigator);
        return true;
    }
    return false;
  }

  static Future<void> _openPost(NavigatorState navigator, String postId) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }

  static Future<void> _openArtwork(NavigatorState navigator, String artworkId) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => ArtDetailScreen(artworkId: artworkId)),
    );
  }

  static Future<void> _openUserProfile(NavigatorState navigator, String userId) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  static Future<void> _openWallet(NavigatorState navigator) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => const Wallet()),
    );
  }

  static Future<void> _openCollections(NavigatorState navigator) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => const SavedItemsScreen()),
    );
  }

  static Future<void> _openAchievements(NavigatorState navigator) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => const AchievementsPage()),
    );
  }

  static Future<void> _openMarketplace(NavigatorState navigator) async {
    await navigator.push(
      MaterialPageRoute(builder: (_) => const Marketplace()),
    );
  }

  static String? _extractPostId(Map<String, dynamic> metadata) {
    return _firstNonEmpty([
      metadata['postId'],
      metadata['targetId'] != null && _string(metadata['targetType']) == 'post' ? metadata['targetId'] : null,
    ]);
  }

  static String? _extractArtworkId(Map<String, dynamic> metadata) {
    return _firstNonEmpty([
      metadata['artworkId'],
      metadata['artwork_id'],
      metadata['targetId'] != null && _string(metadata['targetType']) == 'artwork' ? metadata['targetId'] : null,
    ]);
  }

  static String? _extractUserId(Map<String, dynamic> metadata) {
    final sender = metadata['sender'];
    if (sender is Map) {
      final senderId = _firstNonEmpty([
        sender['walletAddress'],
        sender['wallet_address'],
        sender['wallet'],
        sender['id'],
      ]);
      if (senderId != null) {
        return senderId;
      }
    }
    return _firstNonEmpty([
      metadata['userId'],
      metadata['user_id'],
      metadata['targetWallet'],
      metadata['followerWallet'],
    ]);
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final str = _string(value);
      if (str != null && str.isNotEmpty) {
        return str;
      }
    }
    return null;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return str;
  }
}
