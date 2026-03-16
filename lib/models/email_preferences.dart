class EmailPreferences {
  final bool productUpdates;
  final bool newsletter;
  final bool communityDigest;
  final bool securityAlerts;
  final bool artNotifications;
  final bool communityNotifications;
  final bool daoNotifications;
  final bool artistHubNotifications;
  final bool institutionHubNotifications;
  final bool transactional;

  const EmailPreferences({
    required this.productUpdates,
    required this.newsletter,
    required this.communityDigest,
    required this.securityAlerts,
    required this.artNotifications,
    required this.communityNotifications,
    required this.daoNotifications,
    required this.artistHubNotifications,
    required this.institutionHubNotifications,
    required this.transactional,
  });

  factory EmailPreferences.defaults() {
    return const EmailPreferences(
      productUpdates: false,
      newsletter: false,
      communityDigest: false,
      securityAlerts: true,
      artNotifications: true,
      communityNotifications: true,
      daoNotifications: true,
      artistHubNotifications: true,
      institutionHubNotifications: true,
      transactional: true,
    );
  }

  EmailPreferences copyWith({
    bool? productUpdates,
    bool? newsletter,
    bool? communityDigest,
    bool? securityAlerts,
    bool? artNotifications,
    bool? communityNotifications,
    bool? daoNotifications,
    bool? artistHubNotifications,
    bool? institutionHubNotifications,
    bool? transactional,
  }) {
    return EmailPreferences(
      productUpdates: productUpdates ?? this.productUpdates,
      newsletter: newsletter ?? this.newsletter,
      communityDigest: communityDigest ?? this.communityDigest,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      artNotifications: artNotifications ?? this.artNotifications,
      communityNotifications:
          communityNotifications ?? this.communityNotifications,
      daoNotifications: daoNotifications ?? this.daoNotifications,
      artistHubNotifications:
          artistHubNotifications ?? this.artistHubNotifications,
      institutionHubNotifications:
          institutionHubNotifications ?? this.institutionHubNotifications,
      transactional: transactional ?? this.transactional,
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
      productUpdates: readBool('productUpdates', false),
      newsletter: readBool('newsletter', false),
      communityDigest: readBool('communityDigest', false),
      securityAlerts: readBool('securityAlerts', true),
      artNotifications: readBool('artNotifications', true),
      communityNotifications: readBool('communityNotifications', true),
      daoNotifications: readBool('daoNotifications', true),
      artistHubNotifications: readBool('artistHubNotifications', true),
      institutionHubNotifications:
          readBool('institutionHubNotifications', true),
      transactional: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productUpdates': productUpdates,
      'newsletter': newsletter,
      'communityDigest': communityDigest,
      'securityAlerts': securityAlerts,
      'artNotifications': artNotifications,
      'communityNotifications': communityNotifications,
      'daoNotifications': daoNotifications,
      'artistHubNotifications': artistHubNotifications,
      'institutionHubNotifications': institutionHubNotifications,
      'transactional': true,
    };
  }
}
