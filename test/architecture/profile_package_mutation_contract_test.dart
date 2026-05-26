import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile package cache mutations go through mutation tracker', () {
    final allowed = {
      'lib/providers/profile_package_controller.dart',
      'lib/services/profile_package_mutation_tracker.dart',
      'lib/services/profile_package_service.dart',
    };
    final mutationCalls = RegExp(
      r'ProfilePackageService\.(invalidate|invalidateMany|'
      r'invalidateAchievements|invalidatePosts|invalidateShowcase|'
      r'patchUser|patchStats|patchPosts|patchAchievementResult)\s*\(',
    );

    final offenders = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = _slash(file.path);
      if (allowed.contains(path)) continue;
      final contents = file.readAsStringSync();
      if (mutationCalls.hasMatch(contents)) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Profile-affecting cache writes must use '
          'ProfilePackageMutationTracker so invalidation policy stays '
          'centralized and debuggable.',
    );
  });

  test('profile-affecting screen writes are tracker-aware', () {
    const providerManagedScreens = {
      'lib/screens/web3/artist/artist_portfolio_screen.dart',
    };
    final writeCalls = RegExp(
      r'(createCommunityPost|createGroupPost|updateCommunityPost|'
      r'deleteCommunityPost|deleteRepost|deleteArtwork|'
      r'addComment|deleteComment)\s*\(',
    );

    final offenders = <String>[];
    for (final root in const ['lib/screens']) {
      for (final file in _dartFilesUnder(root)) {
        final path = _slash(file.path);
        if (providerManagedScreens.contains(path)) continue;
        final contents = file.readAsStringSync();
        if (!writeCalls.hasMatch(contents)) continue;
        if (!contents.contains('ProfilePackageMutationTracker')) {
          offenders.add(path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Screens that perform profile-affecting writes must call the '
          'profile package mutation tracker in the same write flow.',
    );
  });

  test('profile-affecting providers are tracker-aware or documented boundaries',
      () {
    final writeCalls = RegExp(
      r'(createCommunityPost|createGroupPost|updateCommunityPost|'
      r'deleteCommunityPost|deleteRepost|followUserWithResponse|'
      r'unfollowUserWithResponse|toggleFollowWithResult|createArtworkRecord|'
      r'updateArtwork|deleteArtwork|publishArtwork|unpublishArtwork|'
      r'createCollection|updateCollection|deleteCollection|'
      r'addArtworkToCollection|removeArtworkFromCollection|createEvent|'
      r'updateEvent|deleteEvent|saveProfile|saveProfileMedia|'
      r'recordAchievementEvent)\s*\(',
    );
    const documentedBoundaries = {
      'lib/providers/community_comments_provider.dart',
      'lib/providers/collectibles_provider.dart',
      'lib/providers/institution_provider.dart',
    };

    final offenders = <String>[];
    for (final root in const ['lib/providers', 'lib/services']) {
      for (final file in _dartFilesUnder(root)) {
        final path = _slash(file.path);
        if (path.contains('backend_api_service')) continue;
        if (path == 'lib/services/profile_package_service.dart') continue;
        if (path == 'lib/services/profile_package_mutation_tracker.dart') {
          continue;
        }
        if (documentedBoundaries.contains(path)) continue;
        final contents = file.readAsStringSync();
        if (!writeCalls.hasMatch(contents)) continue;
        if (!contents.contains('ProfilePackageMutationTracker')) {
          offenders.add(path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Provider/service write boundaries that can affect profile packages '
          'must be tracker-aware. Excluded files are provider-mediated or '
          'local-only boundaries that do not have enough wallet context to '
          'touch profile packages directly.',
    );
  });
}

Iterable<File> _dartFilesUnder(String root) sync* {
  final directory = Directory(root);
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _slash(String path) => path.replaceAll(r'\', '/');
