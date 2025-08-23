class UserProfile {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String profileImageUrl;
  final int followersCount;
  final int followingCount;
  final int artworksCount;
  final bool isFollowing;
  final bool isVerified;
  final DateTime joinDate;
  final List<String> badges;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    required this.profileImageUrl,
    required this.followersCount,
    required this.followingCount,
    required this.artworksCount,
    required this.isFollowing,
    required this.isVerified,
    required this.joinDate,
    required this.badges,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? profileImageUrl,
    int? followersCount,
    int? followingCount,
    int? artworksCount,
    bool? isFollowing,
    bool? isVerified,
    DateTime? joinDate,
    List<String>? badges,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      artworksCount: artworksCount ?? this.artworksCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isVerified: isVerified ?? this.isVerified,
      joinDate: joinDate ?? this.joinDate,
      badges: badges ?? this.badges,
    );
  }

  // Sample user data for demonstration
  static List<UserProfile> getSampleUsers() {
    return [
      UserProfile(
        id: '1',
        name: 'Maya Digital',
        username: '@maya_3d',
        bio: 'AR artist exploring the intersection of digital and physical worlds. Creating immersive experiences.',
        profileImageUrl: '',
        followersCount: 1250,
        followingCount: 340,
        artworksCount: 45,
        isFollowing: true,
        isVerified: true,
        joinDate: DateTime(2024, 1, 15),
        badges: ['Early Adopter', 'AR Pioneer'],
      ),
      UserProfile(
        id: '2',
        name: 'Alex Creator',
        username: '@alex_nft',
        bio: 'NFT artist and collector. Passionate about blockchain technology and digital ownership.',
        profileImageUrl: '',
        followersCount: 890,
        followingCount: 120,
        artworksCount: 32,
        isFollowing: false,
        isVerified: false,
        joinDate: DateTime(2024, 3, 8),
        badges: ['Collector'],
      ),
      UserProfile(
        id: '3',
        name: 'Sam Artist',
        username: '@sam_ar',
        bio: 'Interactive AR installations and public art. Bringing art to the streets through technology.',
        profileImageUrl: '',
        followersCount: 2100,
        followingCount: 580,
        artworksCount: 78,
        isFollowing: true,
        isVerified: true,
        joinDate: DateTime(2023, 11, 22),
        badges: ['Verified Artist', 'Community Leader'],
      ),
      UserProfile(
        id: '4',
        name: 'Luna Vision',
        username: '@luna_viz',
        bio: 'Digital sculptor and AR experience designer. Creating worlds that exist between reality and imagination.',
        profileImageUrl: '',
        followersCount: 1680,
        followingCount: 290,
        artworksCount: 56,
        isFollowing: false,
        isVerified: true,
        joinDate: DateTime(2024, 2, 3),
        badges: ['Featured Artist'],
      ),
      UserProfile(
        id: '5',
        name: 'Pixel Master',
        username: '@pixel_master',
        bio: 'Generative art and algorithmic creativity. Code meets canvas in the digital realm.',
        profileImageUrl: '',
        followersCount: 750,
        followingCount: 200,
        artworksCount: 94,
        isFollowing: true,
        isVerified: false,
        joinDate: DateTime(2024, 4, 12),
        badges: ['Code Artist'],
      ),
    ];
  }
}
