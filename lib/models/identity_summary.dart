class IdentitySummary {
  final String? userId;
  final String? walletAddress;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final bool isArtist;
  final bool isInstitution;
  final bool resolved;

  const IdentitySummary({
    this.userId,
    this.walletAddress,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.isArtist = false,
    this.isInstitution = false,
    this.resolved = false,
  });

  factory IdentitySummary.fromValues({
    String? userId,
    String? walletAddress,
    String? displayName,
    String? username,
    String? avatarUrl,
    bool isArtist = false,
    bool isInstitution = false,
    bool? resolved,
  }) {
    final name = _text(displayName);
    final handle = _normalizeUsername(username);
    final wallet = _text(walletAddress);
    return IdentitySummary(
      userId: _text(userId),
      walletAddress: wallet,
      displayName: _isProvisionalName(name, wallet) ? null : name,
      username: _isProvisionalName(handle, null) ? null : handle,
      avatarUrl: _text(avatarUrl),
      isArtist: isArtist,
      isInstitution: isInstitution,
      resolved: resolved ?? (name != null || handle != null || wallet != null),
    );
  }

  factory IdentitySummary.fromJson(
    Map<String, dynamic> json, {
    String nestedKey = 'author',
  }) {
    final nestedRaw = json[nestedKey];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};
    final rolesRaw = nested['roles'] ?? json['roles'];
    final roles = rolesRaw is Map
        ? Map<String, dynamic>.from(rolesRaw)
        : const <String, dynamic>{};
    final resolvedRaw = nested.containsKey('resolved')
        ? nested['resolved']
        : json.containsKey('resolved')
            ? json['resolved']
            : null;

    String? pick(List<String> keys) {
      for (final source in [nested, json]) {
        for (final key in keys) {
          final value = _text(source[key]);
          if (value != null) return value;
        }
      }
      return null;
    }

    return IdentitySummary.fromValues(
      userId: pick(const ['userId', 'user_id', 'id', 'authorId', 'author_id']),
      walletAddress: pick(const [
        'walletAddress',
        'wallet_address',
        'wallet',
        'authorWallet',
        'author_wallet',
        'publicKey',
        'public_key',
      ]),
      displayName: pick(const [
        'displayName',
        'display_name',
        'authorDisplayName',
        'author_display_name',
        'authorName',
        'author_name',
        'name',
      ]),
      username: pick(const ['username', 'authorUsername', 'author_username']),
      avatarUrl: pick(const [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'authorAvatar',
        'author_avatar',
        'profileImage',
        'profile_image',
      ]),
      isArtist: _bool(roles['artist']) ||
          _bool(nested['isArtist'] ?? nested['is_artist']) ||
          _bool(json['authorIsArtist'] ?? json['author_is_artist']),
      isInstitution: _bool(roles['institution']) ||
          _bool(nested['isInstitution'] ?? nested['is_institution']) ||
          _bool(json['authorIsInstitution'] ?? json['author_is_institution']),
      resolved: resolvedRaw == null ? null : _bool(resolvedRaw),
    );
  }

  String label({required String fallback}) {
    final name = _text(displayName);
    if (name != null) return name;
    final handle = _text(username);
    if (handle != null) return handle;
    final wallet = _text(walletAddress);
    if (wallet != null) return compactWallet(wallet);
    return fallback;
  }

  static String compactWallet(String wallet) {
    final value = wallet.trim();
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();
    if (lower == 'unknown' || lower == 'anonymous' || lower == 'n/a') {
      return null;
    }
    return normalized;
  }

  static String? _normalizeUsername(String? value) {
    final normalized = _text(value);
    if (normalized == null) return null;
    return normalized.startsWith('@') ? normalized.substring(1) : normalized;
  }

  static bool _bool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static bool _isProvisionalName(String? value, String? wallet) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    if (lower == 'user' ||
        lower == 'unknown creator' ||
        lower == 'unknown author') {
      return true;
    }
    if (lower.startsWith('user_')) return true;
    final normalizedWallet = wallet?.toLowerCase();
    if (normalizedWallet == null || normalizedWallet.isEmpty) return false;
    return lower == normalizedWallet || normalizedWallet.startsWith(lower);
  }
}
