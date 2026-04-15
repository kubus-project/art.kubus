class EmailPreferences {
  final bool marketingProductUpdates;
  final bool marketingNewsletter;
  final bool marketingCommunityDigest;
  final bool activityArt;
  final bool activityCommunity;
  final bool activityDao;
  final bool activityArtistHub;
  final bool activityInstitutionHub;
  final bool activityPromotion;
  final bool criticalAccountSecurity;
  final bool criticalWalletSecurity;
  final bool criticalTransactional;

  const EmailPreferences({
    required this.marketingProductUpdates,
    required this.marketingNewsletter,
    required this.marketingCommunityDigest,
    required this.activityArt,
    required this.activityCommunity,
    required this.activityDao,
    required this.activityArtistHub,
    required this.activityInstitutionHub,
    required this.activityPromotion,
    required this.criticalAccountSecurity,
    required this.criticalWalletSecurity,
    required this.criticalTransactional,
  });

  factory EmailPreferences.defaults() {
    return const EmailPreferences(
      marketingProductUpdates: false,
      marketingNewsletter: false,
      marketingCommunityDigest: false,
      activityArt: true,
      activityCommunity: true,
      activityDao: true,
      activityArtistHub: true,
      activityInstitutionHub: true,
      activityPromotion: true,
      criticalAccountSecurity: true,
      criticalWalletSecurity: true,
      criticalTransactional: true,
    );
  }

  EmailPreferences copyWith({
    bool? marketingProductUpdates,
    bool? marketingNewsletter,
    bool? marketingCommunityDigest,
    bool? activityArt,
    bool? activityCommunity,
    bool? activityDao,
    bool? activityArtistHub,
    bool? activityInstitutionHub,
    bool? activityPromotion,
    bool? criticalAccountSecurity,
    bool? criticalWalletSecurity,
    bool? criticalTransactional,
  }) {
    return EmailPreferences(
      marketingProductUpdates:
          marketingProductUpdates ?? this.marketingProductUpdates,
      marketingNewsletter: marketingNewsletter ?? this.marketingNewsletter,
      marketingCommunityDigest:
          marketingCommunityDigest ?? this.marketingCommunityDigest,
      activityArt: activityArt ?? this.activityArt,
      activityCommunity: activityCommunity ?? this.activityCommunity,
      activityDao: activityDao ?? this.activityDao,
      activityArtistHub: activityArtistHub ?? this.activityArtistHub,
      activityInstitutionHub:
          activityInstitutionHub ?? this.activityInstitutionHub,
      activityPromotion: activityPromotion ?? this.activityPromotion,
      criticalAccountSecurity:
          criticalAccountSecurity ?? this.criticalAccountSecurity,
      criticalWalletSecurity:
          criticalWalletSecurity ?? this.criticalWalletSecurity,
      criticalTransactional:
          criticalTransactional ?? this.criticalTransactional,
    );
  }

  factory EmailPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return EmailPreferences.defaults();

    bool readBool(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      return fallback;
    }

    return EmailPreferences(
      marketingProductUpdates: readBool(
        'marketingProductUpdates',
        readBool('productUpdates', false),
      ),
      marketingNewsletter: readBool(
        'marketingNewsletter',
        readBool('newsletter', false),
      ),
      marketingCommunityDigest: readBool(
        'marketingCommunityDigest',
        readBool('communityDigest', false),
      ),
      activityArt: readBool(
        'activityArt',
        readBool('artNotifications', true),
      ),
      activityCommunity: readBool(
        'activityCommunity',
        readBool('communityNotifications', true),
      ),
      activityDao: readBool(
        'activityDao',
        readBool('daoNotifications', true),
      ),
      activityArtistHub: readBool(
        'activityArtistHub',
        readBool('artistHubNotifications', true),
      ),
      activityInstitutionHub: readBool(
        'activityInstitutionHub',
        readBool('institutionHubNotifications', true),
      ),
      activityPromotion: readBool(
        'activityPromotion',
        readBool('promotionAlerts', true),
      ),
      criticalAccountSecurity: true,
      criticalWalletSecurity: true,
      criticalTransactional: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marketingProductUpdates': marketingProductUpdates,
      'marketingNewsletter': marketingNewsletter,
      'marketingCommunityDigest': marketingCommunityDigest,
      'activityArt': activityArt,
      'activityCommunity': activityCommunity,
      'activityDao': activityDao,
      'activityArtistHub': activityArtistHub,
      'activityInstitutionHub': activityInstitutionHub,
      'activityPromotion': activityPromotion,
      'criticalAccountSecurity': true,
      'criticalWalletSecurity': true,
      'criticalTransactional': true,
    };
  }
}
