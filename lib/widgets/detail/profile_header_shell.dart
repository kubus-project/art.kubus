import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/wallet_utils.dart';
import 'detail_shell_components.dart';

/// A shared profile header component for profile screens (own + other users)
/// Supports cover image/gradient, avatar, name, badges, and stats.
class ProfileHeaderShell extends StatelessWidget {
  /// User's display name
  final String displayName;

  /// Username with @ prefix
  final String? username;

  /// Cover image URL
  final String? coverUrl;

  /// Avatar image URL
  final String? avatarUrl;

  /// Accent color for gradient fallback
  final Color? accentColor;

  /// Whether this user is an artist
  final bool isArtist;

  /// Whether this user is an institution
  final bool isInstitution;

  /// Whether the user is verified
  final bool isVerified;

  /// Activity status widget (online/offline indicator)
  final Widget? activityStatus;

  /// Stats counters (followers, following, posts)
  final ProfileStats? stats;

  /// Badges to display next to name
  final List<Widget> badges;

  /// Action buttons (follow, message, edit, etc.)
  final List<Widget> actions;

  /// Hero tag for avatar animation
  final String? avatarHeroTag;

  /// Callback when cover is tapped
  final VoidCallback? onCoverTap;

  /// Callback when avatar is tapped
  final VoidCallback? onAvatarTap;

  /// Height of the cover section
  final double coverHeight;

  /// Avatar size
  final double avatarSize;

  /// Whether to use compact layout (for mobile)
  final bool compact;

  const ProfileHeaderShell({
    super.key,
    required this.displayName,
    this.username,
    this.coverUrl,
    this.avatarUrl,
    this.accentColor,
    this.isArtist = false,
    this.isInstitution = false,
    this.isVerified = false,
    this.activityStatus,
    this.stats,
    this.badges = const [],
    this.actions = const [],
    this.avatarHeroTag,
    this.onCoverTap,
    this.onAvatarTap,
    this.coverHeight = 160,
    this.avatarSize = 100,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image with avatar overlap
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover image/gradient
            GestureDetector(
              onTap: onCoverTap,
              child: Container(
                height: coverHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      effectiveAccent.withValues(alpha: 0.35),
                      effectiveAccent.withValues(alpha: 0.15),
                      scheme.surface,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: coverUrl != null && coverUrl!.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          // Gradient overlay for better avatar visibility
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    scheme.scrim.withValues(alpha: 0.4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            // Avatar positioned at bottom of cover
            Positioned(
              left: DetailSpacing.lg,
              bottom: -(avatarSize / 2),
              child: GestureDetector(
                onTap: onAvatarTap,
                child: _buildAvatar(context, effectiveAccent),
              ),
            ),
          ],
        ),
        // Content below cover (with padding for avatar)
        Padding(
          padding: EdgeInsets.only(
            top: (avatarSize / 2) + DetailSpacing.md,
            left: DetailSpacing.lg,
            right: DetailSpacing.lg,
          ),
          child: compact
              ? _buildCompactContent(context)
              : _buildFullContent(context),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, Color accentColor) {
    final scheme = Theme.of(context).colorScheme;

    final avatarWidget = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.surface,
          width: DetailSpacing.xs,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.15),
            blurRadius: DetailSpacing.md,
            offset: Offset(0, DetailSpacing.xs),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(context, accentColor),
              )
            : _buildInitials(context, accentColor),
      ),
    );

    if (avatarHeroTag != null) {
      return Hero(tag: avatarHeroTag!, child: avatarWidget);
    }
    return avatarWidget;
  }

  Widget _buildInitials(BuildContext context, Color accentColor) {
    final initials = _getInitials(displayName);
    return Container(
      color: accentColor.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initials,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: accentColor,
              ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  Widget _buildFullContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rawUsername = (username ?? '').trim();
    final normalized = rawUsername.startsWith('@')
      ? rawUsername.substring(1).trim()
      : rawUsername;
    final safeHandle = (normalized.isNotEmpty && !WalletUtils.looksLikeWallet(normalized))
      ? '@$normalized'
      : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name row with badges
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: DetailSpacing.sm),
              Icon(
                Icons.verified,
                size: KubusSizes.sidebarActionIcon + KubusSpacing.xxs,
                color: scheme.primary,
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(width: DetailSpacing.sm),
              ...badges.map((badge) => Padding(
                    padding: const EdgeInsets.only(
                      right: KubusSpacing.xs + KubusSpacing.xxs,
                    ),
                    child: badge,
                  )),
            ],
          ],
        ),
        // Username
        if (safeHandle != null) ...[
          const SizedBox(height: DetailSpacing.xs),
          Text(
            safeHandle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
        // Activity status
        if (activityStatus != null) ...[
          const SizedBox(height: 8),
          activityStatus!,
        ],
        // Stats row
        if (stats != null) ...[
          const SizedBox(height: DetailSpacing.lg),
          _buildStatsRow(context),
        ],
        // Actions row
        if (actions.isNotEmpty) ...[
          const SizedBox(height: DetailSpacing.lg),
          Wrap(
            spacing: DetailSpacing.sm,
            runSpacing: DetailSpacing.sm,
            children: actions,
          ),
        ],
      ],
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rawUsername = (username ?? '').trim();
    final normalized = rawUsername.startsWith('@')
      ? rawUsername.substring(1).trim()
      : rawUsername;
    final safeHandle = (normalized.isNotEmpty && !WalletUtils.looksLikeWallet(normalized))
      ? '@$normalized'
      : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name with badges inline
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                        Icon(
                          Icons.verified,
                          size: KubusSizes.trailingChevron + KubusSpacing.xxs,
                          color: scheme.primary,
                        ),
                      ],
                      ...badges.map((badge) => Padding(
                            padding: const EdgeInsets.only(
                              left: KubusSpacing.xs + KubusSpacing.xxs,
                            ),
                            child: badge,
                          )),
                    ],
                  ),
                  if (safeHandle != null) ...[
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      safeHandle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            // Compact actions
            if (actions.isNotEmpty)
              Row(children: actions),
          ],
        ),
        if (activityStatus != null) ...[
          const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
          activityStatus!,
        ],
        if (stats != null) ...[
          const SizedBox(height: DetailSpacing.md),
          _buildStatsRow(context),
        ],
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _buildStatItem(
          context,
          stats!.postsCount.toString(),
          l10n.userProfilePostsStatLabel,
          stats!.onPostsTap,
        ),
        const SizedBox(width: DetailSpacing.xl),
        _buildStatItem(
          context,
          stats!.followersCount.toString(),
          l10n.userProfileFollowersStatLabel,
          stats!.onFollowersTap,
        ),
        const SizedBox(width: DetailSpacing.xl),
        _buildStatItem(
          context,
          stats!.followingCount.toString(),
          l10n.userProfileFollowingStatLabel,
          stats!.onFollowingTap,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    VoidCallback? onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

/// Stats data for profile header
class ProfileStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStats({
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.onPostsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });
}
