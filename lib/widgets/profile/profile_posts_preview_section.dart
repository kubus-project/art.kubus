import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../community/community_interactions.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../community/community_post_card.dart';
import '../empty_state_card.dart';
import '../inline_loading.dart';
import '../kubus_button.dart';

/// A **bounded** preview of a profile's most recent posts.
///
/// The profile composition deliberately ends on the large kubus statistics, so
/// posts cannot be an unbounded feed sitting immediately above them: a visitor
/// who scrolls would never predictably reach the bottom of the page. The
/// profile shows the two or three most recent posts and hands the complete
/// history to a dedicated screen, which is where paging belongs.
class ProfilePostsPreviewSection extends StatelessWidget {
  const ProfilePostsPreviewSection({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.accentColor,
    required this.onOpenPost,
    required this.onViewAll,
    this.error,
    this.onRetry,
    this.emptyTitle,
    this.emptyDescription,
    this.padding = EdgeInsets.zero,
    this.totalCount,
  });

  final List<CommunityPost> posts;
  final bool isLoading;
  final String? error;
  final Future<void> Function()? onRetry;
  final Color accentColor;
  final void Function(CommunityPost post) onOpenPost;
  final VoidCallback onViewAll;
  final String? emptyTitle;
  final String? emptyDescription;
  final EdgeInsetsGeometry padding;

  /// The profile's real post count where it is known, so "View all posts"
  /// appears even when the first page happens to be shorter than the preview.
  final int? totalCount;

  /// How many posts the preview shows. Two on a phone, three once there is a
  /// column wide enough to read three without the section swallowing the page.
  static int previewCountFor(double width) => width >= 600 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final limit = previewCountFor(constraints.maxWidth);
          final preview = posts.take(limit).toList(growable: false);
          final known = totalCount ?? posts.length;
          final hasMore = known > preview.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.userProfilePostsTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: roles.foreground,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: KubusSpacing.lg),
                  child: Center(child: InlineLoading(width: 40, height: 40)),
                )
              else if (error != null)
                EmptyStateCard(
                  icon: Icons.cloud_off,
                  title: l10n.userProfilePostsLoadFailedTitle,
                  description: error!,
                  showAction: onRetry != null,
                  actionLabel: onRetry == null ? null : l10n.commonRetry,
                  onAction: onRetry == null ? null : () => onRetry!(),
                )
              else if (preview.isEmpty)
                EmptyStateCard(
                  icon: Icons.article,
                  title: emptyTitle ?? l10n.userProfileNoPostsTitle,
                  description: emptyDescription ?? '',
                )
              else
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(height: KubusSpacing.sm),
                  CommunityPostCard(
                    post: preview[i],
                    accentColor: accentColor,
                    onOpenPostDetail: onOpenPost,
                  ),
                ],
              if (hasMore) ...[
                const SizedBox(height: KubusSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KubusButton(
                    onPressed: onViewAll,
                    label: l10n.userProfileViewAllPostsLabel,
                    icon: Icons.arrow_forward,
                    variant: KubusButtonVariant.secondary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
