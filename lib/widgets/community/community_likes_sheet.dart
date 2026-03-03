import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../community/community_interactions.dart';
import '../../l10n/app_localizations.dart';
import '../avatar_widget.dart';
import '../empty_state_card.dart';
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
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: theme.colorScheme.onSurface,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CommunityLikeUser>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
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
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            errorMessage,
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              errorMessage,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
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
                        horizontal: 24, vertical: 12),
                    itemCount: likes.length,
                    separatorBuilder: (_, __) => Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final user = likes[index];
                      final subtitleParts = <String>[];
                      if (user.username != null && user.username!.isNotEmpty) {
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
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subtitleParts.isNotEmpty
                            ? Text(
                                subtitleParts.join(' • '),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
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
      );
    },
  );
}
