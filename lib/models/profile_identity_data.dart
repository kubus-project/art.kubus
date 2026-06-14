import '../utils/creator_display_format.dart';
import '../utils/user_identity_display.dart';
import '../utils/wallet_utils.dart';
import 'promotion.dart';

class ProfileIdentityData {
  final String label;
  final String? handle;
  final String? username;
  final String? userId;
  final String walletSeed;
  final String? avatarUrl;

  const ProfileIdentityData({
    required this.label,
    required this.walletSeed,
    this.handle,
    this.username,
    this.userId,
    this.avatarUrl,
  });

  bool get canOpenProfile => (userId ?? '').trim().isNotEmpty;

  ProfileIdentityData copyWith({
    String? label,
    String? handle,
    String? username,
    String? userId,
    String? walletSeed,
    String? avatarUrl,
  }) {
    return ProfileIdentityData(
      label: label ?? this.label,
      handle: handle ?? this.handle,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      walletSeed: walletSeed ?? this.walletSeed,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory ProfileIdentityData.fromProfileMap(
    Map<String, dynamic> raw, {
    required String fallbackLabel,
    String? fallbackUserId,
  }) {
    final identity = UserIdentityDisplayUtils.fromProfileMap(raw);
    final userId = WalletUtils.resolveFromMap(raw, fallback: fallbackUserId);
    final walletSeed = WalletUtils.coalesce(
      walletAddress: raw['walletAddress']?.toString(),
      wallet: raw['wallet']?.toString() ?? raw['wallet_address']?.toString(),
      userId: userId,
      fallback: fallbackUserId,
    );
    final rawLabel = identity.name.trim();
    final label = rawLabel.isEmpty || rawLabel.toLowerCase() == 'unknown artist'
        ? fallbackLabel
        : rawLabel;
    return ProfileIdentityData(
      label: label,
      handle: identity.handle,
      username: identity.username,
      userId: userId.trim().isEmpty ? null : userId.trim(),
      walletSeed: walletSeed.trim().isEmpty ? label : walletSeed.trim(),
      avatarUrl: _pickAvatarUrl(raw),
    );
  }

  factory ProfileIdentityData.fromValues({
    required String fallbackLabel,
    String? displayName,
    String? username,
    String? userId,
    String? wallet,
    String? avatarUrl,
  }) {
    final formatted = CreatorDisplayFormat.format(
      fallbackLabel: fallbackLabel,
      displayName: displayName,
      username: username,
      wallet: wallet,
    );
    final normalizedUsername = CreatorDisplayFormat.normalizeUsername(username);
    final normalizedUserId = WalletUtils.canonical(
        (userId ?? '').trim().isNotEmpty ? userId : wallet);
    final walletSeed = WalletUtils.canonical(
      (wallet ?? '').trim().isNotEmpty ? wallet : normalizedUserId,
    );
    return ProfileIdentityData(
      label: formatted.primary,
      handle: formatted.secondary,
      username: normalizedUsername,
      userId: normalizedUserId.isEmpty ? null : normalizedUserId,
      walletSeed: walletSeed.isEmpty ? formatted.primary : walletSeed,
      avatarUrl: _normalizeText(avatarUrl),
    );
  }

  factory ProfileIdentityData.fromIdentityPayload(
    Map<String, dynamic> json, {
    String nestedKey = 'author',
    required String fallbackLabel,
  }) {
    final nestedRaw = json[nestedKey];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};

    String? pick(List<String> keys) {
      for (final source in [nested, json]) {
        for (final key in keys) {
          final value = CreatorDisplayFormat.normalizePayloadText(source[key]);
          if (value != null) return value;
        }
      }
      return null;
    }

    final authorStringWallet =
        nestedRaw is String && nestedRaw.trim().isNotEmpty
            ? nestedRaw.trim()
            : null;
    final userId =
        pick(const ['userId', 'user_id', 'id', 'authorId', 'author_id']);
    final wallet = pick(const [
          'walletAddress',
          'wallet_address',
          'wallet',
          'authorWallet',
          'author_wallet',
          'publicKey',
          'public_key',
        ]) ??
        authorStringWallet;
    return ProfileIdentityData.fromValues(
      fallbackLabel: fallbackLabel,
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
      userId: userId ?? wallet,
      wallet: wallet ?? userId,
      avatarUrl: pick(const [
        'avatarUrl',
        'avatar_url',
        'avatar',
        'authorAvatar',
        'author_avatar',
        'profileImage',
        'profile_image',
      ]),
    );
  }

  factory ProfileIdentityData.fromCompactAuthor(
    Map<String, dynamic> author, {
    required String fallbackLabel,
  }) {
    return ProfileIdentityData.fromIdentityPayload(
      {'author': author},
      fallbackLabel: fallbackLabel,
    );
  }

  factory ProfileIdentityData.fromHomeRailItem(
    HomeRailItem item, {
    required String fallbackLabel,
  }) {
    final raw = item.raw;
    if (item.entityType == PromotionEntityType.profile) {
      final subtitle = (item.subtitle ?? '').trim();
      final username = CreatorDisplayFormat.normalizeUsername(
        raw['username']?.toString() ??
            raw['handle']?.toString() ??
            (subtitle.startsWith('@') ? subtitle.substring(1) : null),
      );
      final userId = item.profileTargetId ?? item.id.trim();
      return ProfileIdentityData.fromValues(
        fallbackLabel: fallbackLabel,
        displayName: item.title,
        username: username,
        userId: userId,
        wallet: userId,
        avatarUrl: _pickAvatarUrl(raw),
      );
    }

    if (item.entityType == PromotionEntityType.institution) {
      final profileTargetId = item.profileTargetId;
      return ProfileIdentityData.fromValues(
        fallbackLabel: fallbackLabel,
        displayName: item.title,
        username: CreatorDisplayFormat.normalizeUsername(raw['username']),
        userId: profileTargetId,
        wallet: profileTargetId ?? item.id,
        avatarUrl: _pickLogoOrAvatarUrl(raw) ?? _normalizeText(item.imageUrl),
      );
    }

    return ProfileIdentityData.fromValues(
      fallbackLabel: fallbackLabel,
      displayName: item.title,
      username: CreatorDisplayFormat.normalizeUsername(raw['username']),
      userId: item.profileTargetId,
      wallet: item.profileTargetId ?? item.id,
      avatarUrl: _pickAvatarUrl(raw),
    );
  }
}

String? _pickAvatarUrl(Map<String, dynamic> raw) {
  return _firstNonEmpty(<dynamic>[
    raw['avatar'],
    raw['avatarUrl'],
    raw['avatar_url'],
    raw['profileImage'],
    raw['profileImageUrl'],
    raw['profile_image_url'],
  ]);
}

String? _pickLogoOrAvatarUrl(Map<String, dynamic> raw) {
  return _firstNonEmpty(<dynamic>[
    raw['logoUrl'],
    raw['logo_url'],
    raw['avatar'],
    raw['avatarUrl'],
    raw['avatar_url'],
    raw['profileImage'],
    raw['profileImageUrl'],
    raw['profile_image_url'],
  ]);
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final normalized = _normalizeText(value?.toString());
    if (normalized != null) return normalized;
  }
  return null;
}

String? _normalizeText(String? value) {
  final normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}
