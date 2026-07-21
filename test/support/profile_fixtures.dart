import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart';

/// Deterministic profile fixtures shared by the direct profile-screen widget
/// tests and the authenticated profile visual-QA matrix.
///
/// Every fixture is pure data — no network, no clock, no randomness — so the
/// same scenario renders byte-identically in `flutter test` and in the QA
/// screenshot matrix. Fixtures are injected exclusively through the screens'
/// existing `initialCriticalPackage` / `initialExtendedPackageFuture` test
/// seams; nothing here weakens or bypasses production authentication.
class ProfileFixtures {
  ProfileFixtures._();

  /// Frozen timestamp so `fetchedAt`-derived text never varies between runs.
  static final DateTime fetchedAt = DateTime.utc(2026, 7, 21, 9);

  /// A real-shaped Solana wallet used as the viewed profile identifier.
  static const String wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

  /// A second wallet for the "wallet fallback" scenario (no human username).
  static const String walletFallbackId =
      '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM';

  /// Server-generated username shape (`adjectivesubject_hash`) produced by the
  /// backend's `generateUsername()` — a legitimate, displayable handle.
  static const String generatedServerUsername = 'luminousmonoprint_a4f2';

  /// Client-side provisional identifier shape (`user_<wallet prefix>`), which
  /// the backend refuses to persist from the edit flow.
  static const String provisionalUsername = 'user_7xKXtg2C';

  /// Longest username the canonical policy accepts (exactly 50 characters,
  /// matching the `character varying(50)` username columns).
  static const String maxLengthUsername =
      'ana_kovac_the_extremely_prolific_street_muralist_x';

  /// 35 characters, continuous alphanumerics — legitimate under the canonical
  /// policy but historically swallowed by the broad wallet heuristic.
  static const String longAlphanumericUsername = 'annakovacstreetmuralistljubljana2026';

  static User user({
    String id = wallet,
    String name = 'Ana Kovač',
    String username = generatedServerUsername,
    String bio = 'Street muralist working across Ljubljana and Trieste.',
    String? profileImageUrl,
    String? coverImageUrl,
    bool isFollowing = false,
    bool isVerified = false,
    bool isArtist = false,
    bool isInstitution = false,
    bool showAchievements = false,
    int followersCount = 1284,
    int followingCount = 312,
    int postsCount = 47,
    List<String> fieldOfWork = const <String>['Mural', 'Installation'],
    int yearsActive = 9,
  }) {
    return User(
      id: id,
      name: name,
      username: username,
      bio: bio,
      profileImageUrl: profileImageUrl,
      coverImageUrl: coverImageUrl,
      fieldOfWork: fieldOfWork,
      yearsActive: yearsActive,
      followersCount: followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
      isFollowing: isFollowing,
      isVerified: isVerified,
      isArtist: isArtist,
      isInstitution: isInstitution,
      showAchievements: showAchievements,
      joinedDate: '2019-04-02',
    );
  }

  static ProfileCriticalPackage critical({User? user}) {
    final resolved = user ?? ProfileFixtures.user();
    return ProfileCriticalPackage(
      user: resolved,
      achievementProgress: const [],
      achievementDefinitions: const [],
      publicStats: <String, int>{
        'publicStreetArtAdded': 12,
        'followers': resolved.followersCount,
        'following': resolved.followingCount,
        'posts': resolved.postsCount,
      },
      fetchedAt: fetchedAt,
      isComplete: true,
    );
  }

  /// Empty-but-resolved extended package so screens leave their loading state
  /// without ever touching the network.
  static ProfileExtendedPackage extended() {
    return ProfileExtendedPackage(
      initialPosts: const [],
      fetchedAt: fetchedAt,
    );
  }
}
