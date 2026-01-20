class EmailPreferences {
  final bool productUpdates;
  final bool newsletter;
  final bool communityDigest;
  final bool securityAlerts;
  final bool transactional;

  const EmailPreferences({
    required this.productUpdates,
    required this.newsletter,
    required this.communityDigest,
    required this.securityAlerts,
    required this.transactional,
  });

  factory EmailPreferences.defaults() {
    return const EmailPreferences(
      productUpdates: false,
      newsletter: false,
      communityDigest: false,
      securityAlerts: true,
      transactional: true,
    );
  }

  EmailPreferences copyWith({
    bool? productUpdates,
    bool? newsletter,
    bool? communityDigest,
    bool? securityAlerts,
    bool? transactional,
  }) {
    return EmailPreferences(
      productUpdates: productUpdates ?? this.productUpdates,
      newsletter: newsletter ?? this.newsletter,
      communityDigest: communityDigest ?? this.communityDigest,
      securityAlerts: securityAlerts ?? this.securityAlerts,
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
      transactional: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productUpdates': productUpdates,
      'newsletter': newsletter,
      'communityDigest': communityDigest,
      'securityAlerts': securityAlerts,
      'transactional': true,
    };
  }
}

