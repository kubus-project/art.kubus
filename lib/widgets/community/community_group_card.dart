import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_group.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';

enum CommunityGroupCardVariant {
  mobile,
  desktop,
}

class CommunityGroupCard extends StatelessWidget {
  const CommunityGroupCard({
    super.key,
    required this.group,
    required this.accentColor,
    required this.variant,
    required this.onOpenGroupFeed,
    this.onToggleMembership,
    this.isMembershipActionInFlight = false,
    this.timeAgoBuilder,
  });

  final CommunityGroupSummary group;
  final Color accentColor;
  final CommunityGroupCardVariant variant;
  final VoidCallback onOpenGroupFeed;
  final VoidCallback? onToggleMembership;
  final bool isMembershipActionInFlight;
  final String Function(DateTime dateTime)? timeAgoBuilder;

  bool get _isMobile => variant == CommunityGroupCardVariant.mobile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(KubusSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: KubusRadius.circular(18),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: KubusTypography.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.description?.isNotEmpty == true
                            ? group.description!
                            : l10n.communityGroupNoDescription,
                        style: KubusTypography.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_isMobile) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: group.isOwner ||
                            isMembershipActionInFlight ||
                            onToggleMembership == null
                        ? null
                        : onToggleMembership,
                    icon: Icon(
                      group.isMember ? Icons.check : Icons.group_add,
                      size: 16,
                    ),
                    label: Text(_membershipLabel(l10n)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          group.isMember ? scheme.surface : accentColor,
                      foregroundColor: group.isMember
                          ? scheme.onSurface
                          : scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: KubusTypography.textTheme.labelMedium,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    group.isPublic ? Icons.public : Icons.lock,
                    size: 16,
                  ),
                  label: Text(
                    group.isPublic ? l10n.commonPublic : l10n.commonPrivate,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.people_alt, size: 16),
                  label: Text(l10n.commonMembersCount(group.memberCount)),
                ),
              ],
            ),
            if (group.latestPost != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(KubusSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: KubusRadius.circular(KubusRadius.md + 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.communityGroupLatestPostLabel,
                      style: KubusTypography.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.latestPost?.content?.isNotEmpty == true
                          ? group.latestPost!.content!
                          : '-',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    if (group.latestPost?.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeAgo(group.latestPost!.createdAt!),
                        style: KubusTypography.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenGroupFeed,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text(l10n.communityOpenGroupFeedButton),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark ? scheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenGroupFeed,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: Row(
              children: [
                _GroupAvatar(group: group, accentColor: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: KubusTextStyles.sectionTitle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.description!,
                          style: KubusTextStyles.sectionSubtitle.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.desktopCommunityGroupMembersLabel(
                              group.memberCount,
                            ),
                            style: KubusTextStyles.navMetaLabel.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (group.latestPost?.createdAt != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                l10n.desktopCommunityLatestLabel(
                                  _formatTimeAgo(group.latestPost!.createdAt!),
                                ),
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _membershipLabel(AppLocalizations l10n) {
    if (group.isOwner) return l10n.commonOwner;
    if (group.isMember) return l10n.commonJoined;
    return l10n.commonJoin;
  }

  String _formatTimeAgo(DateTime dateTime) {
    if (timeAgoBuilder != null) {
      return timeAgoBuilder!(dateTime);
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    }
    if (difference.inDays >= 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
    if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({
    required this.group,
    required this.accentColor,
  });

  final CommunityGroupSummary group;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: group.coverImage != null && group.coverImage!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              child: Image.network(
                MediaUrlResolver.resolveDisplayUrl(group.coverImage!) ??
                    group.coverImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.groups,
                  color: accentColor,
                  size: 28,
                ),
              ),
            )
          : Icon(
              Icons.groups,
              color: accentColor,
              size: 28,
            ),
    );
  }
}
