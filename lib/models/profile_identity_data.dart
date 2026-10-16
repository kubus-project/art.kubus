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

  String? get navigationIdentifier {
    final normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isNotEmpty) return normalizedUserId;
    final normalizedWallet = walletSeed.trim();
    if (normalizedWallet.isNotEmpty && normalizedWallet != label.trim()) {
      return normalizedWallet;
    }
    return null;
  }

  /// The best human-facing text to take avatar initials from: the display
  /// name, else the username, else the handle. A wallet (or a shortened
  /// wallet used as a placeholder label) is never an initial, so the avatar
  /// reads as a name rather than an arbitrary character such as "7". Null
  /// when nothing human is known.
  String? get avatarInitialsSource {
    final wallet = walletSeed.trim();
    for (final candidate in [label, username, handle]) {
      var text = (candidate ?? '').trim();
      if (text.startsWith('@')) text = text.substring(1).trim();
      if (text.isEmpty) continue;
      if (text == wallet || WalletUtils.looksLikeWallet(text)) continue;
      if (wallet.isNotEmpty &&
          (text.contains('\u2026') || text.contains('...')) &&
          text.codeUnitAt(0) == wallet.codeUnitAt(0)) {
        continue;
      }
      return text;
    }
    return null;
  }

  bool get canOpenProfile =>
      navigationIdentifier != null || (username ?? '').trim().isNotEmpty;

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
    final explicitUserId = _firstNonEmpty(<dynamic>[
      raw['userId'],
      raw['user_id'],
      raw['accountId'],
      raw['account_id'],
    ]);
    final rawId = _normalizeText(raw['id']);
    final userId = explicitUserId ??
        (rawId != null && !WalletUtils.looksLikeWallet(rawId) ? rawId : null);
    final walletSeed = _firstNonEmpty(<dynamic>[
          raw['walletAddress'],
          raw['wallet_address'],
          raw['wallet'],
          rawId != null && WalletUtils.looksLikeWallet(rawId) ? rawId : null,
          fallbackUserId,
          userId,
        ]) ??
        '';
    final rawLabel = identity.name.trim();
    final label = rawLabel.isEmpty || rawLabel.toLowerCase() == 'unknown artist'
        ? fallbackLabel
        : rawLabel;
    return ProfileIdentityData(
      label: label,
      handle: identity.handle,
      username: identity.username,
      userId: userId,
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
    // Legacy wallet-only payloads still carry a stable linked identifier.
    // Prefer an explicit account ID whenever both identifiers are available.
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
    final explicitUserId = pick(const [
      'userId',
      'user_id',
      'authorId',
      'author_id',
    ]);
    final rawId = pick(const ['id']);
    final userId = explicitUserId ??
        (rawId != null && !WalletUtils.looksLikeWallet(rawId) ? rawId : null);
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
      userId: userId,
      wallet: wallet ??
          (rawId != null && WalletUtils.looksLikeWallet(rawId)
              ? rawId
              : userId),
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
    // `imageUrl` is the rail's single "best image": the avatar or logo, but
    // the cover when there is none. It may stand in for a missing explicit
    // avatar field (older payloads carried no other), never when it is the
    // cover itself, which belongs behind the mark, not in it.
    final imageUrl = _normalizeText(item.imageUrl);
    final cover = _firstNonEmpty(<dynamic>[
      raw['coverImageUrl'],
      raw['cover_image_url'],
      raw['coverImage'],
      raw['cover_image'],
      raw['coverUrl'],
      raw['cover_url'],
    ]);
    final imageAsMark = imageUrl != null && imageUrl != cover ? imageUrl : null;
    // A profile's `imageUrl` falls back to its cover when it has no avatar,
    // and a payload without explicit media fields (the 0.8.0 backend) cannot
    // say which it is. Only a URL that is evidently an avatar upload may then
    // stand in for the avatar; anything else could be the cover.
    final hasExplicitMedia = cover != null || _pickAvatarUrl(raw) != null;
    final profileImageAsMark = imageAsMark != null &&
            (hasExplicitMedia || imageAsMark.contains('/avatars/'))
        ? imageAsMark
        : null;
    if (item.entityType == PromotionEntityType.profile) {
      final subtitle = (item.subtitle ?? '').trim();
      final username = CreatorDisplayFormat.normalizeUsername(
        raw['username']?.toString() ??
            raw['handle']?.toString() ??
            (subtitle.startsWith('@') ? subtitle.substring(1) : null),
      );
      final rawId = item.id.trim();
      final userId = item.profileTargetId ??
          (WalletUtils.looksLikeWallet(rawId) ? null : rawId);
      return ProfileIdentityData.fromValues(
        fallbackLabel: fallbackLabel,
        displayName: item.title,
        username: username,
        userId: userId,
        wallet: item.profileTargetId ?? rawId,
        avatarUrl: _pickAvatarUrl(raw) ?? profileImageAsMark,
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
        avatarUrl: _pickLogoOrAvatarUrl(raw) ?? imageAsMark,
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
