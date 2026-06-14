import 'package:flutter/material.dart';

import '../models/profile_identity_data.dart';
import '../utils/profile_package_prefetcher.dart';
import '../utils/user_profile_navigation.dart';
import 'avatar_widget.dart';

export '../models/profile_identity_data.dart';

enum ProfileIdentityLayout {
  row,
  stacked,
}

class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({
    super.key,
    required this.identity,
    this.layout = ProfileIdentityLayout.row,
    this.avatarRadius = 20,
    this.allowFabricatedFallback = true,
    this.fetchMissingAvatar = true,
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
  final bool fetchMissingAvatar;
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
    final effectiveTextAlign = textAlign ??
        (layout == ProfileIdentityLayout.stacked
            ? TextAlign.center
            : TextAlign.start);
    void prefetchHighIntent() {
      if (!identity.canOpenProfile) return;
      ProfilePackagePrefetcher.prefetchHighIntent(
        identity.userId!,
        username: identity.username,
      );
    }

    final usesBuiltInNavigation =
        onTap == null && enableProfileNavigation && identity.canOpenProfile;
    final resolvedOnTap = onTap ??
        (usesBuiltInNavigation
            ? () {
                prefetchHighIntent();
                UserProfileNavigation.open(
                  context,
                  userId: identity.userId!,
                  username: identity.username,
                );
              }
            : null);
    if (enableProfileNavigation && identity.canOpenProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ProfilePackagePrefetcher.prefetchVisible(
          identity.userId!,
          username: identity.username,
        );
      });
    }

    final child = switch (layout) {
      ProfileIdentityLayout.row => Row(
          children: [
            AvatarWidget(
              avatarUrl: identity.avatarUrl,
              wallet: identity.walletSeed,
              radius: avatarRadius,
              allowFabricatedFallback: allowFabricatedFallback,
              fetchMissingAvatar: fetchMissingAvatar,
              enableProfileNavigation: enableProfileNavigation,
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
              fetchMissingAvatar: fetchMissingAvatar,
              enableProfileNavigation: enableProfileNavigation,
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: usesBuiltInNavigation ? (_) => prefetchHighIntent() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (usesBuiltInNavigation) {
            prefetchHighIntent();
          }
          resolvedOnTap();
        },
        child: child,
      ),
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
            mainAxisAlignment: centerTitleRow
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Flexible(child: title),
              const SizedBox(width: 6),
              titleSuffix!,
            ],
          );

    return Column(
      crossAxisAlignment:
          centerTitleRow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
