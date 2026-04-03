import 'package:flutter/material.dart';

import '../models/promotion.dart';
import '../utils/creator_display_format.dart';
import '../utils/user_identity_display.dart';
import '../utils/user_profile_navigation.dart';
import '../utils/wallet_utils.dart';
import 'avatar_widget.dart';

enum ProfileIdentityLayout {
  row,
  stacked,
}

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
    final normalizedUsername = _normalizeUsername(username);
    final normalizedUserId =
        WalletUtils.canonical((userId ?? '').trim().isNotEmpty ? userId : wallet);
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

  factory ProfileIdentityData.fromHomeRailItem(
    HomeRailItem item, {
    required String fallbackLabel,
  }) {
    final raw = item.raw;
    if (item.entityType == PromotionEntityType.profile) {
      final subtitle = (item.subtitle ?? '').trim();
      final username = _normalizeUsername(
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
        username: _normalizeUsername(raw['username']?.toString()),
        userId: profileTargetId,
        wallet: profileTargetId ?? item.id,
        avatarUrl: _pickLogoOrAvatarUrl(raw) ?? _normalizeText(item.imageUrl),
      );
    }

    return ProfileIdentityData.fromValues(
      fallbackLabel: fallbackLabel,
      displayName: item.title,
      username: _normalizeUsername(raw['username']?.toString()),
      userId: item.profileTargetId,
      wallet: item.profileTargetId ?? item.id,
      avatarUrl: _pickAvatarUrl(raw),
    );
  }
}

class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({
    super.key,
    required this.identity,
    this.layout = ProfileIdentityLayout.row,
    this.avatarRadius = 20,
    this.allowFabricatedFallback = true,
    this.enableProfileNavigation = false,
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
    this.titleSuffix,
    this.trailing,
    this.textAlign,
  });

  final ProfileIdentityData identity;
  final ProfileIdentityLayout layout;
  final double avatarRadius;
  final bool allowFabricatedFallback;
  final bool enableProfileNavigation;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Widget? titleSuffix;
  final Widget? trailing;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final effectiveTitleStyle = titleStyle ??
        theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        );
    final effectiveSubtitleStyle = subtitleStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.62),
        );
    final effectiveTextAlign =
        textAlign ?? (layout == ProfileIdentityLayout.stacked
            ? TextAlign.center
            : TextAlign.start);
    final resolvedOnTap = onTap ??
        (enableProfileNavigation && identity.canOpenProfile
            ? () => UserProfileNavigation.open(
                  context,
                  userId: identity.userId!,
                  username: identity.username,
                )
            : null);

    final child = switch (layout) {
      ProfileIdentityLayout.row => Row(
          children: [
            AvatarWidget(
              avatarUrl: identity.avatarUrl,
              wallet: identity.walletSeed,
              radius: avatarRadius,
              allowFabricatedFallback: allowFabricatedFallback,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IdentityTextBlock(
                label: identity.label,
                handle: identity.handle,
                titleStyle: effectiveTitleStyle,
                subtitleStyle: effectiveSubtitleStyle,
                textAlign: effectiveTextAlign,
                titleSuffix: titleSuffix,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ProfileIdentityLayout.stacked => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(
              avatarUrl: identity.avatarUrl,
              wallet: identity.walletSeed,
              radius: avatarRadius,
              allowFabricatedFallback: allowFabricatedFallback,
            ),
            const SizedBox(height: 10),
            _IdentityTextBlock(
              label: identity.label,
              handle: identity.handle,
              titleStyle: effectiveTitleStyle,
              subtitleStyle: effectiveSubtitleStyle,
              textAlign: effectiveTextAlign,
              titleSuffix: titleSuffix,
              centerTitleRow: true,
            ),
            if (trailing != null) ...[
              const SizedBox(height: 10),
              trailing!,
            ],
          ],
        ),
    };

    if (resolvedOnTap == null) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: resolvedOnTap,
      child: child,
    );
  }
}

class _IdentityTextBlock extends StatelessWidget {
  const _IdentityTextBlock({
    required this.label,
    required this.handle,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.textAlign,
    this.titleSuffix,
    this.centerTitleRow = false,
  });

  final String label;
  final String? handle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextAlign textAlign;
  final Widget? titleSuffix;
  final bool centerTitleRow;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: titleStyle,
    );

    final titleRow = titleSuffix == null
        ? title
        : Row(
            mainAxisSize: centerTitleRow ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment:
                centerTitleRow ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Flexible(child: title),
              const SizedBox(width: 6),
              titleSuffix!,
            ],
          );

    return Column(
      crossAxisAlignment: centerTitleRow
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleRow,
        if ((handle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            handle!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: subtitleStyle,
          ),
        ],
      ],
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

String? _normalizeUsername(String? value) {
  var normalized = (value ?? '').trim();
  if (normalized.startsWith('@')) {
    normalized = normalized.substring(1).trim();
  }
  if (normalized.isEmpty || WalletUtils.looksLikeWallet(normalized)) {
    return null;
  }
  return normalized;
}
