import '../services/backend_api_service.dart';
import '../config/config.dart';

class UserProfile {
  final String id;
  final String walletAddress;
  final String username;
  final String displayName;
  final String bio;
  final String avatar;
  final String? coverImage;
  final Map<String, String> social;
  final bool isArtist;
  final bool isInstitution;
  final ArtistInfo? artistInfo;
  final ProfilePreferences? preferences;
  final UserStats? stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.walletAddress,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.avatar,
    this.coverImage,
    this.social = const {},
    this.isArtist = false,
    this.isInstitution = false,
    this.artistInfo,
    this.preferences,
    this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? walletAddress,
    String? username,
    String? displayName,
    String? bio,
    String? avatar,
    String? coverImage,
    Map<String, String>? social,
    bool? isArtist,
    bool? isInstitution,
    ArtistInfo? artistInfo,
    ProfilePreferences? preferences,
    UserStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatar: avatar ?? this.avatar,
      coverImage: coverImage ?? this.coverImage,
      social: social ?? this.social,
      isArtist: isArtist ?? this.isArtist,
      isInstitution: isInstitution ?? this.isInstitution,
      artistInfo: artistInfo ?? this.artistInfo,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // JSON serialization
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse date fields that might be null or already Date objects
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    // Safely convert social map to Map<String, String>
    final rawSocial = json['social'];
    final Map<String, String> socialMap = {};
    if (rawSocial is Map) {
      rawSocial.forEach((k, v) {
        socialMap[k.toString()] = v == null ? '' : v.toString();
      });
    }

    final coverRaw = json['coverImage'] ?? json['cover_image_url'];

    return UserProfile(
      id: (json['id'] ?? '').toString(),
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['display_name'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      avatar: (json['avatar'] ?? json['avatar_url'] ?? '').toString(),
      coverImage: coverRaw?.toString(),
      social: socialMap,
      isArtist: json['isArtist'] ?? json['is_artist'] ?? false,
      isInstitution: json['isInstitution'] ?? json['is_institution'] ?? false,
      artistInfo: json['artistInfo'] != null ? ArtistInfo.fromJson(json['artistInfo']) : null,
      preferences: json['preferences'] != null ? ProfilePreferences.fromJson(json['preferences']) : null,
      stats: json['stats'] != null ? UserStats.fromJson(json['stats']) : null,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatar': avatar,
      'coverImage': coverImage,
      'social': social,
      'isArtist': isArtist,
      'isInstitution': isInstitution,
      'artistInfo': artistInfo?.toJson(),
      'preferences': preferences?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

}

class ArtistInfo {
  final bool verified;
  final String? verificationNFT;
  final List<String> specialty;
  final int yearsActive;
  final bool featured;
  final int artworksCount;
  final int followersCount;

  ArtistInfo({
    this.verified = false,
    this.verificationNFT,
    this.specialty = const [],
    this.yearsActive = 0,
    this.featured = false,
    this.artworksCount = 0,
    this.followersCount = 0,
  });

  factory ArtistInfo.fromJson(Map<String, dynamic> json) {
    return ArtistInfo(
      verified: json['verified'] ?? false,
      verificationNFT: json['verificationNFT'] ?? json['verification_nft'],
      specialty: List<String>.from(json['specialty'] ?? []),
      yearsActive: json['yearsActive'] ?? json['years_active'] ?? 0,
      featured: json['featured'] ?? false,
      artworksCount: json['artworksCount'] ?? json['artworks_count'] ?? 0,
      followersCount: json['followersCount'] ?? json['followers_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verified': verified,
      'verificationNFT': verificationNFT,
      'specialty': specialty,
      'yearsActive': yearsActive,
      'featured': featured,
      'artworksCount': artworksCount,
      'followersCount': followersCount,
    };
  }
}

class ProfilePreferences {
  final String privacy;
  final bool notifications;
  final String theme;
  final bool showActivityStatus;
  final bool showCollection;
  final bool allowMessages;
  /// UX persona (onboarding). A hint for what to emphasize in the UI.
  ///
  /// Expected values: "lover", "creator", "institution".
  final String? persona;

  ProfilePreferences({
    this.privacy = 'public',
    this.notifications = true,
    this.theme = 'auto',
    this.showActivityStatus = true,
    this.showCollection = true,
    this.allowMessages = true,
    this.persona,
  });

  ProfilePreferences copyWith({
    String? privacy,
    bool? notifications,
    String? theme,
    bool? showActivityStatus,
    bool? showCollection,
    bool? allowMessages,
    String? persona,
  }) {
    return ProfilePreferences(
      privacy: privacy ?? this.privacy,
      notifications: notifications ?? this.notifications,
      theme: theme ?? this.theme,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      showCollection: showCollection ?? this.showCollection,
      allowMessages: allowMessages ?? this.allowMessages,
      persona: persona ?? this.persona,
    );
  }

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      privacy: json['privacy'] ?? 'public',
      notifications: json['notifications'] ?? true,
      theme: json['theme'] ?? 'auto',
      showActivityStatus: json['showActivityStatus'] ?? json['show_activity_status'] ?? true,
      showCollection: json['showCollection'] ?? json['show_collection'] ?? true,
      allowMessages: json['allowMessages'] ?? json['allow_messages'] ?? true,
      persona: (json['persona'] ?? json['userPersona'] ?? json['user_persona'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privacy': privacy,
      'notifications': notifications,
      'theme': theme,
      'showActivityStatus': showActivityStatus,
      'showCollection': showCollection,
      'allowMessages': allowMessages,
      if (persona != null) 'persona': persona,
    };
  }
}

class UserStats {
  final int artworksDiscovered;
  final int artworksCreated;
  final int nftsOwned;
  final double kub8Balance;
  final int achievementsUnlocked;
  final int followersCount;
  final int followingCount;

  UserStats({
    this.artworksDiscovered = 0,
    this.artworksCreated = 0,
    this.nftsOwned = 0,
    this.kub8Balance = 0.0,
    this.achievementsUnlocked = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      artworksDiscovered: json['artworksDiscovered'] ?? json['artworks_discovered'] ?? 0,
      artworksCreated: json['artworksCreated'] ?? json['artworks_created'] ?? 0,
      nftsOwned: json['nftsOwned'] ?? json['nfts_owned'] ?? 0,
      kub8Balance: (json['kub8Balance'] ?? json['kub8_balance'] ?? 0.0).toDouble(),
      achievementsUnlocked: json['achievementsUnlocked'] ?? json['achievements_unlocked'] ?? 0,
      followersCount: json['followersCount'] ?? json['followers_count'] ?? 0,
      followingCount: json['followingCount'] ?? json['following_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artworksDiscovered': artworksDiscovered,
      'artworksCreated': artworksCreated,
      'nftsOwned': nftsOwned,
      'kub8Balance': kub8Balance,
      'achievementsUnlocked': achievementsUnlocked,
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }
}

// Extension on UserProfile for sample data
extension UserProfileSamples on UserProfile {
  static List<UserProfile> getSampleUsers() {
    final now = DateTime.now();
    return [
      UserProfile(
        id: 'sample1',
        walletAddress: '0xSample1',
        username: 'crypto_artist',
        displayName: 'Crypto Artist',
        bio: 'Digital artist exploring blockchain',
        avatar: '${_backendAvatarBase()}/crypto_artist?style=avataaars&format=png',
        isArtist: true,
        stats: UserStats(followersCount: 1234, followingCount: 567),
        createdAt: now,
        updatedAt: now,
      ),
      UserProfile(
        id: 'sample2',
        walletAddress: '0xSample2',
        username: 'nft_collector',
        displayName: 'NFT Collector',
        bio: 'Collecting amazing digital art',
        avatar: '${_backendAvatarBase()}/nft_collector?style=avataaars&format=png',
        stats: UserStats(followersCount: 890, followingCount: 432),
        createdAt: now,
        updatedAt: now,
      ),
      UserProfile(
        id: 'sample3',
        walletAddress: '0xSample3',
        username: 'ar_enthusiast',
        displayName: 'AR Enthusiast',
        bio: 'Love augmented reality art',
        avatar: '${_backendAvatarBase()}/ar_enthusiast?style=avataaars&format=png',
        stats: UserStats(followersCount: 456, followingCount: 789),
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

// Helper to compute backend avatar base URL without importing BackendApiService in model constructors
String _backendAvatarBase() {
  // Try to resolve from environment-like fallback. In runtime, BackendApiService.baseUrl should be preferred.
  try {
    // Importing inside function to avoid circular import at top-level
    final svc = BackendApiService();
    return '${svc.baseUrl.replaceAll(RegExp(r'/$'), '')}/api/avatar';
  } catch (_) {
    return '${AppConfig.baseApiUrl.replaceAll(RegExp(r'/$'), '')}/api/avatar';
  }
}
