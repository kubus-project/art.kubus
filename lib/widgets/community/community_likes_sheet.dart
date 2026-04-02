import 'package:flutter/material.dart';

import '../../community/community_interactions.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../avatar_widget.dart';
import '../common/kubus_glass_icon_button.dart';
import '../common/kubus_screen_header.dart';
import '../empty_state_card.dart';
import '../glass_components.dart';
import '../inline_loading.dart';

Future<void> showCommunityLikesSheet({
  required BuildContext context,
  required String title,
  required Future<List<CommunityLikeUser>> Function() loader,
  required String Function(DateTime likedAt) formatTimeAgo,
  required String errorMessage,
  required String unnamedUserLabel,
  bool showDetailedError = false,
  bool isScrollControlled = false,
  bool enableProfileNavigation = false,
  bool allowFabricatedFallback = false,
}) {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;
  final future = loader();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: BackdropGlassSheet(
          showBorder: false,
          padding: EdgeInsets.zero,
          backgroundColor: theme.colorScheme.surface,
          child: Column(
            children: [
              KubusSheetHeader(
                title: title,
                trailing: KubusGlassIconButton(
                  icon: Icons.close,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CommunityLikeUser>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          width: KubusSpacing.xl,
                          height: KubusSpacing.xl,
                          child: InlineLoading(
                            expand: true,
                            shape: BoxShape.circle,
                            tileSize: 4.0,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      if (!showDetailedError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(KubusSpacing.lg),
                            child: Text(
                              errorMessage,
                              style: KubusTypography.textTheme.bodyMedium
                                  ?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(KubusSpacing.lg),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                                size: 36,
                              ),
                              const SizedBox(height: KubusSpacing.sm),
                              Text(
                                errorMessage,
                                style: KubusTypography.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: KubusSpacing.sm),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: l10n.postDetailNoLikesTitle,
                          description: l10n.postDetailNoLikesDescription,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.lg,
                        vertical: KubusSpacing.sm,
                      ),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final subtitleParts = <String>[];
                        if (user.username != null &&
                            user.username!.isNotEmpty) {
                          subtitleParts.add('@${user.username}');
                        }
                        if (user.likedAt != null) {
                          subtitleParts.add(formatTimeAgo(user.likedAt!));
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            enableProfileNavigation: enableProfileNavigation,
                            allowFabricatedFallback: allowFabricatedFallback,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : unnamedUserLabel,
                            style: KubusTypography.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: subtitleParts.isNotEmpty
                              ? Text(
                                  subtitleParts.join(' • '),
                                  style: KubusTextStyles.navMetaLabel.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
