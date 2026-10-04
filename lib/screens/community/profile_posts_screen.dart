import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../community/community_interactions.dart';
import '../../providers/community_interactions_provider.dart';
import '../../models/profile_package.dart';
import '../../providers/profile_package_controller.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/themeprovider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/inline_loading.dart';
import '../desktop/desktop_shell_scope.dart';
import 'post_detail_screen.dart';

/// The complete post history of one profile.
///
/// The profile itself shows a bounded preview and sends the rest here. That is
/// the whole point: paging belongs on a screen whose job is the list, not above
/// a profile's closing statistics where it would make the bottom of the page
/// unreachable.
class ProfilePostsScreen extends StatefulWidget {
  const ProfilePostsScreen({
    super.key,
    required this.userId,
    this.username,
    this.displayName,
    this.embedded = false,
    @visibleForTesting this.initialCriticalPackage,
  });

  final String userId;
  final String? username;

  /// Shown in the header where it is known, so the screen says whose posts
  /// these are without a second request.
  final String? displayName;

  /// Hosted by a chrome owner (the desktop shell's [DesktopSubScreen]): the
  /// screen renders only its list, with no app bar, title or back control of
  /// its own, so the host's single header is the only one.
  final bool embedded;

  final ProfileCriticalPackage? initialCriticalPackage;

  @override
  State<ProfilePostsScreen> createState() => _ProfilePostsScreenState();
}

class _ProfilePostsScreenState extends State<ProfilePostsScreen> {
  late final ProfilePackageController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = ProfilePackageController(
      walletAddress: widget.userId,
      username: widget.username,
      initialCriticalPackage: widget.initialCriticalPackage,
    );
    _controller.addListener(_onControllerChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    await _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await _controller.loadPosts(
      savedItemsProvider: context.read<SavedItemsProvider>(),
      interactionsProvider: context.read<CommunityInteractionsProvider>(),
      errorMessage: l10n?.userProfilePostsLoadFailedDescription,
    );
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) return;
    if (_controller.isLastPage || _controller.loadingMore) return;
    // A failed page waits for the footer's Retry instead of re-firing on
    // every scroll tick.
    if (_controller.postsError != null) return;
    _loadMore();
  }

  void _loadMore() {
    final l10n = AppLocalizations.of(context);
    unawaited(
      _controller.loadMorePosts(
        savedItemsProvider: context.read<SavedItemsProvider>(),
        interactionsProvider: context.read<CommunityInteractionsProvider>(),
        errorMessage: l10n?.userProfilePostsLoadMoreFailedDescription,
      ),
    );
  }

  void _openPost(CommunityPost post) {
    final shellScope = DesktopShellScope.of(context);
    if (widget.embedded && shellScope != null) {
      shellScope.pushScreen(PostDetailScreen(post: post));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final accent = context.watch<ThemeProvider>().accentColor;
    final posts = _controller.posts;
    final name = (widget.displayName ?? _controller.user?.name ?? '').trim();

    final body = RefreshIndicator(
      onRefresh: _loadPosts,
      color: accent,
      child: _controller.postsLoading && posts.isEmpty
          ? const Center(child: InlineLoading(width: 40, height: 40))
          : ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.md,
                KubusSpacing.md,
                KubusSpacing.md,
                KubusSpacing.xxl,
              ),
              // Header, the posts, then the paging foot.
              itemCount: posts.isEmpty ? 2 : posts.length + 2,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KubusSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
                    child: KubusHeaderText(
                      // Embedded, the host header already says "Posts".
                      title: widget.embedded && name.isNotEmpty
                          ? name
                          : l10n.userProfilePostsTitle,
                      subtitle: widget.embedded || name.isEmpty ? null : name,
                      kind: KubusHeaderKind.section,
                      titleColor: roles.foreground,
                    ),
                  );
                }
                if (posts.isEmpty) {
                  final error = _controller.postsError;
                  return EmptyStateCard(
                    icon: error == null ? Icons.article : Icons.cloud_off,
                    title: error == null
                        ? l10n.userProfileNoPostsTitle
                        : l10n.userProfilePostsLoadFailedTitle,
                    description: error ??
                        (name.isEmpty
                            ? ''
                            : l10n.userProfileNoPostsDescription(name)),
                    showAction: error != null,
                    actionLabel: error == null ? null : l10n.commonRetry,
                    onAction:
                        error == null ? null : () => unawaited(_loadPosts()),
                  );
                }
                if (index <= posts.length) {
                  return CommunityPostCard(
                    post: posts[index - 1],
                    accentColor: accent,
                    onOpenPostDetail: _openPost,
                  );
                }
                if (_controller.loadingMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: InlineLoading(tileSize: 4),
                      ),
                    ),
                  );
                }
                if (_controller.postsError != null) {
                  return Semantics(
                    container: true,
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: KubusSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.postsError!,
                            textAlign: TextAlign.center,
                            style: KubusTextStyles.sectionSubtitle.copyWith(
                              color: roles.foregroundMuted,
                            ),
                          ),
                          const SizedBox(height: KubusSpacing.xs),
                          TextButton(
                            onPressed: _loadMore,
                            child: Text(l10n.commonRetry),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (_controller.isLastPage) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KubusSpacing.sm,
                    ),
                    child: Center(
                      child: Text(
                        l10n.userProfileNoMorePostsLabel,
                        style: KubusTextStyles.sectionSubtitle.copyWith(
                          color: roles.foregroundMuted,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const KubusGlassAppBarBackdrop(showBottomDivider: true),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.userProfilePostsTitle,
          style: KubusTextStyles.mobileAppBarTitle,
        ),
      ),
      body: body,
    );
  }
}
