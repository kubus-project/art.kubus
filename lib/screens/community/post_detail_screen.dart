import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/wallet_utils.dart';
import '../../community/community_interactions.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/backend_api_service.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../providers/app_refresh_provider.dart';
import '../../providers/community_comments_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/community/community_author_role_badges.dart';
import '../../widgets/community/community_post_options_sheet.dart';

enum PostDetailInitialAction { edit, delete, report, options }

class PostDetailScreen extends StatefulWidget {
  final CommunityPost? post;
  final String? postId;
  final VoidCallback? onClose;
  final Future<List<CommunityLikeUser>> Function(String postId)? postLikesLoader;
  final Future<List<Map<String, dynamic>>> Function(String postId)? postRepostsLoader;
  final String? currentWalletAddressOverride;
  final PostDetailInitialAction? initialAction;

  const PostDetailScreen({
    super.key,
    this.post,
    this.postId,
    this.onClose,
    this.postLikesLoader,
    this.postRepostsLoader,
    this.currentWalletAddressOverride,
    this.initialAction,
  }) : assert(post != null || postId != null);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();

  /// Helper to open a post detail by id (useful for deep links)
  static Future<void> openById(BuildContext context, String postId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  CommunityPost? _post;
  bool _loading = true;
  String? _error;
  final TextEditingController _commentController = TextEditingController();
  String? _replyToCommentId;
  String? _replyToAuthorName;
  final FocusNode _commentFocusNode = FocusNode();
  bool _didRunInitialAction = false;

  String? _currentWalletAddress() {
    final override = widget.currentWalletAddressOverride;
    if (override != null) return override;
    try {
      return Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _post = widget.post;
      _loading = false;
      _maybeRunInitialAction();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final post = _post;
        if (!mounted || post == null) return;
        context.read<CommunityCommentsProvider>().loadComments(post.id, force: true);
      });
    } else if (widget.postId != null) {
      _fetchPost(widget.postId!);
    }
  }

  void _maybeRunInitialAction() {
    if (!mounted) return;
    if (_didRunInitialAction) return;
    final action = widget.initialAction;
    final post = _post;
    if (action == null || post == null) return;

    _didRunInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (action) {
        case PostDetailInitialAction.edit:
          _showEditPostSheet();
          break;
        case PostDetailInitialAction.delete:
          _confirmDeletePost();
          break;
        case PostDetailInitialAction.report:
          _showReportPostDialog();
          break;
        case PostDetailInitialAction.options:
          _showPostOptionsMenu();
          break;
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPost(String id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await BackendApiService().getCommunityPostById(id);
      try {
        await CommunityService.loadSavedInteractions(
          [post],
          walletAddress: _currentWalletAddress(),
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
      });
      if (mounted) {
        // Load comments via provider so edited/original fields and nesting are
        // consistent and mutations can update UI without manual refresh.
        unawaited(context.read<CommunityCommentsProvider>().loadComments(post.id, force: true));
      }
      _maybeRunInitialAction();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PostDetailScreen: error fetching post: $e');
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.postDetailLoadPostFailedMessage;
        _loading = false;
      });
    }
  }

  String _timeAgo(DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 7) return l10n.commonTimeAgoWeeks((diff.inDays / 7).floor());
    if (diff.inDays > 0) return l10n.commonTimeAgoDays(diff.inDays);
    if (diff.inHours > 0) return l10n.commonTimeAgoHours(diff.inHours);
    if (diff.inMinutes > 0) return l10n.commonTimeAgoMinutes(diff.inMinutes);
    return l10n.commonTimeAgoJustNow;
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      await CommunityService.togglePostLike(
        _post!,
        currentUserWallet: _currentWalletAddress(),
      );
      if (!mounted) return;
      setState(() {});

      // Show undo option
      if (!mounted) return;
      _maybeRunInitialAction();
      final roles = KubusColorRoles.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_post!.isLiked ? l10n.postDetailPostLikedToast : l10n.postDetailLikeRemovedToast),
          action: SnackBarAction(
            label: l10n.commonUndo,
            textColor: roles.likeAction,
            onPressed: () async {
              try {
                await CommunityService.togglePostLike(
                  _post!,
                  currentUserWallet: _currentWalletAddress(),
                );
                if (!mounted) return;
                setState(() {});
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('PostDetailScreen: undo like failed: $e');
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.postDetailUndoLikeFailedToast)));
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PostDetailScreen: toggle like failed: $e');
      }
      // On failure ensure rollback and show retry option
      try {
        if (mounted) setState(() {});
      } catch (_) {}
      if (!mounted) return;
      final retryRoles = KubusColorRoles.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postDetailUpdateLikeFailedToast),
          action: SnackBarAction(
            label: l10n.commonRetry,
            textColor: retryRoles.likeAction,
            onPressed: () async {
              try {
                await CommunityService.togglePostLike(
                  _post!,
                  currentUserWallet: _currentWalletAddress(),
                );
                if (!mounted) return;
                setState(() {});
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('PostDetailScreen: retry like failed: $e');
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.postDetailRetryLikeFailedToast)));
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    if (_post == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    // capture and clear reply target
    final parentId = _replyToCommentId;
    _replyToCommentId = null;
    _replyToAuthorName = null;
    if (_commentFocusNode.hasFocus) _commentFocusNode.unfocus();

    try {
      await context.read<CommunityCommentsProvider>().addComment(
            postId: _post!.id,
            content: text,
            parentCommentId: parentId,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.postDetailCommentAddedToast)),
      );
      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PostDetailScreen: add comment failed: $e');
      }
      if (!mounted) return;
      // Backend can reject unauthenticated requests.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.postDetailAddCommentFailedToast)),
      );
    }
  }

  void _showCommentLikes(String commentId) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final future = BackendApiService().getCommentLikes(commentId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.commonLikes, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    IconButton(icon: const Icon(Icons.close), color: theme.colorScheme.onSurface, onPressed: () => Navigator.of(sheetContext).pop()),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CommunityLikeUser>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.postDetailLoadLikesFailedMessage, style: GoogleFonts.inter(color: theme.colorScheme.onSurface)),
                        ),
                      );
                    }
                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: l10n.postDetailNoLikesTitle,
                          description: l10n.postDetailNoLikesDescription,
                        ),
                      ),
                    );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final subtitleParts = <String>[];
                        if (user.username != null && user.username!.isNotEmpty) subtitleParts.add('@${user.username}');
                        if (user.walletAddress != null && user.walletAddress!.isNotEmpty) subtitleParts.add(user.walletAddress!);
                        if (user.likedAt != null) subtitleParts.add(user.likedAt!.toIso8601String());
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(wallet: user.walletAddress ?? user.userId, avatarUrl: user.avatarUrl, radius: 20, enableProfileNavigation: true),
                          title: Text(user.displayName.isNotEmpty ? user.displayName : l10n.commonUnnamed, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          subtitle: subtitleParts.isNotEmpty ? Text(subtitleParts.join(' • '), style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))) : null,
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

  void _showPostLikes() {
    final post = _post;
    if (!mounted || post == null) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final loader = widget.postLikesLoader;
    final future = loader != null
        ? loader(post.id)
        : BackendApiService().getPostLikes(post.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                      l10n.communityPostLikesTitle,
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
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.postDetailLoadLikesFailedMessage,
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }
                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: EmptyStateCard(
                            icon: Icons.favorite_border,
                            title: l10n.postDetailNoLikesTitle,
                            description: l10n.postDetailNoLikesDescription,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        if (user.walletAddress != null &&
                            user.walletAddress!.isNotEmpty) {
                          subtitleParts.add(user.walletAddress!);
                        }
                        if (user.likedAt != null) {
                          subtitleParts.add(user.likedAt!.toIso8601String());
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            enableProfileNavigation: true,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : l10n.commonUnnamed,
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

  void _showPostReposts() {
    final post = _post;
    if (!mounted || post == null) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final loader = widget.postRepostsLoader;
    final future = loader != null
        ? loader(post.id)
        : BackendApiService().getPostReposts(postId: post.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                    l10n.communityRepostedByTitle,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        l10n.communityRepostsLoadFailedMessage,
                        style: GoogleFonts.inter(),
                      ),
                    );
                  }
                  final reposts = snapshot.data ?? [];
                  if (reposts.isEmpty) {
                    return Center(
                      child: EmptyStateCard(
                        icon: Icons.repeat,
                        title: l10n.communityNoRepostsTitle,
                        description: l10n.communityNoRepostsDescription,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: reposts.length,
                    itemBuilder: (ctx, idx) {
                      final repost = reposts[idx];
                      final user = repost['user'] as Map<String, dynamic>?;
                      final username = user?['username'] ??
                          user?['walletAddress'] ??
                          l10n.commonUnknown;
                      final displayName = user?['displayName'] ?? username;
                      final avatar = user?['avatar'];
                      final comment = repost['repostComment'] as String?;
                      final createdAt =
                          DateTime.tryParse(repost['createdAt'] ?? '');

                      return ListTile(
                        leading: AvatarWidget(
                          wallet: WalletUtils.resolveFromMap(
                            user,
                            fallback: username,
                          ),
                          avatarUrl: avatar,
                          radius: 20,
                          enableProfileNavigation: true,
                        ),
                        title: Text(
                          displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$username',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                comment,
                                style: GoogleFonts.inter(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(
                                _timeAgo(createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
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
  }

  bool _isCurrentUserPost(CommunityPost post) {
    final current = _currentWalletAddress();
    if (current == null || current.trim().isEmpty) return false;
    return WalletUtils.equals(post.authorWallet ?? post.authorId, current);
  }

  void _showPostOptionsMenu() {
    final post = _post;
    if (!mounted || post == null) return;
    final isOwner = _isCurrentUserPost(post);

    unawaited(
      showCommunityPostOptionsSheet(
        context: context,
        post: post,
        isOwner: isOwner,
        onReport: _showReportPostDialog,
        onEdit: _showEditPostSheet,
        onDelete: _confirmDeletePost,
      ),
    );
  }

  void _showReportPostDialog() {
    final post = _post;
    if (!mounted || post == null) return;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.postDetailReportPostDialogTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.postDetailReportPostDialogQuestion,
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            _buildPostReportOption(dialogContext, post, l10n.userProfileReportReasonSpam),
            _buildPostReportOption(dialogContext, post, l10n.userProfileReportReasonInappropriate),
            _buildPostReportOption(dialogContext, post, l10n.userProfileReportReasonHarassment),
            _buildPostReportOption(dialogContext, post, l10n.userProfileReportReasonOther),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildPostReportOption(
    BuildContext dialogContext,
    CommunityPost post,
    String reason,
  ) {
    return ListTile(
      title: Text(reason, style: GoogleFonts.inter()),
      onTap: () async {
        Navigator.pop(dialogContext);
        try {
          await CommunityService.reportPost(post, reason);
        } catch (_) {}
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userProfileReportSubmittedToast),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showEditPostSheet() {
    final post = _post;
    if (!mounted || post == null) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final controller = TextEditingController(text: post.content);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
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
                          l10n.postDetailEditPostTitle,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: saving ? null : () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        style: GoogleFonts.inter(),
                        decoration: InputDecoration(
                          hintText: l10n.communityComposerTextHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                saving ? null : () => Navigator.pop(sheetContext),
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(sheetContext);
                                    AppRefreshProvider? appRefresh;
                                    try {
                                      appRefresh = Provider.of<AppRefreshProvider>(
                                        context,
                                        listen: false,
                                      );
                                    } catch (_) {}

                                    final content =
                                        controller.text.trim();
                                    final existingMediaUrls = post.mediaUrls.isNotEmpty
                                        ? post.mediaUrls
                                        : (post.imageUrl != null &&
                                                post.imageUrl!.trim().isNotEmpty)
                                            ? [post.imageUrl!.trim()]
                                            : <String>[];
                                    if (content.isEmpty && existingMediaUrls.isEmpty) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.communityComposerAddContentToast,
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setModalState(() => saving = true);
                                    try {
                                      await BackendApiService().updateCommunityPost(
                                        postId: post.id,
                                        content: content,
                                        mediaUrls: existingMediaUrls,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _post = post.copyWith(content: content);
                                      });
                                      appRefresh?.triggerCommunity();
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(l10n.postDetailPostUpdatedToast),
                                        ),
                                      );
                                    } catch (e) {
                                      if (kDebugMode) {
                                        debugPrint(
                                            'PostDetailScreen: update post failed: $e');
                                      }
                                      if (!mounted) return;
                                      setModalState(() => saving = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.postDetailUpdatePostFailedToast,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.commonSave),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _confirmDeletePost() async {
    final post = _post;
    if (!mounted || post == null) return;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    bool deleting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            l10n.postDetailDeletePostTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            l10n.postDetailDeletePostBody,
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: deleting
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final dialogNavigator = Navigator.of(dialogContext);
                      final navigator = Navigator.of(context);
                      AppRefreshProvider? appRefresh;
                      try {
                        appRefresh = Provider.of<AppRefreshProvider>(
                          context,
                          listen: false,
                        );
                      } catch (_) {}
                      final onClose = widget.onClose;
                      try {
                        await BackendApiService().deleteCommunityPost(post.id);
                        if (!mounted) return;
                        appRefresh?.triggerCommunity();
                        dialogNavigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.postDetailPostDeletedToast),
                          ),
                        );
                        if (onClose != null) {
                          onClose();
                        } else {
                          navigator.maybePop();
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          debugPrint(
                              'PostDetailScreen: delete post failed: $e');
                        }
                        if (!mounted) return;
                        setDialogState(() => deleting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text(l10n.postDetailDeletePostFailedToast),
                          ),
                        );
                      }
                    },
              child: deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonDelete),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareModal() {
    if (_post == null || !mounted) return;
    ShareService().showShareSheet(
      context,
      target: ShareTarget.post(postId: _post!.id, title: _post!.content),
      sourceScreen: 'post_detail',
      onCreatePostRequested: () async {
        if (!mounted) return;
        _showRepostModal();
      },
    );
  }

  void _showRepostModal() {
    if (_post == null || !mounted) return;
    final theme = Theme.of(context);
    final repostContentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.postDetailRepostTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(AppLocalizations.of(context)!.commonCancel, style: GoogleFonts.inter()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final content = repostContentController.text.trim();
                        Navigator.pop(sheetContext);
                        
                        try {
                          await BackendApiService().createRepost(
                            originalPostId: _post!.id,
                            content: content.isNotEmpty ? content : null,
                          );

                              if (!mounted) return;
                              // Refresh post to potentially show updated share count
                              if (widget.postId != null) {
                                await _fetchPost(widget.postId!);
                                if (!mounted) return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    content.isEmpty
                                        ? AppLocalizations.of(context)!.postDetailRepostSuccessToast
                                        : AppLocalizations.of(context)!.postDetailRepostWithCommentSuccessToast,
                                  ),
                                ),
                              );
                        } catch (e) {
                              if (kDebugMode) {
                                debugPrint('PostDetailScreen: repost failed: $e');
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLocalizations.of(context)!.postDetailRepostFailedToast)),
                                );
                              }
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.postDetailRepostButton, style: GoogleFonts.inter()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: repostContentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.postDetailRepostThoughtsHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.postDetailRepostingLabel,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AvatarWidget(wallet: _post!.authorId, avatarUrl: _post!.authorAvatar, radius: 16, enableProfileNavigation: false),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Text(
                                              _post!.authorName,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          CommunityAuthorRoleBadges(
                                            post: _post!,
                                            fontSize: 9.5,
                                            iconOnly: false,
                                          ),
                                        ],
                                      ),
                                      Text(_timeAgo(_post!.timestamp), style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_post!.content, style: GoogleFonts.inter(fontSize: 14), maxLines: 5, overflow: TextOverflow.ellipsis),
                            if (_post!.imageUrl != null && _post!.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_post!.imageUrl!, fit: BoxFit.cover, height: 120, width: double.infinity),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _toggleBookmark() async {
    final post = _post;
    if (!mounted || post == null) return;
    try {
      await CommunityService.toggleBookmark(post);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Bookmark is local-first; failure is non-fatal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.commonPost, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter()))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommunityPostCard(
                        post: _post!,
                        accentColor: themeProvider.accentColor,
                        onOpenPostDetail: (target) {
                          // In detail, avoid pushing the same post.
                          if (_post != null && target.id == _post!.id) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: target),
                            ),
                          );
                        },
                        // Avoid circular imports by relying on AvatarWidget's navigation.
                        onOpenAuthorProfile: () {},
                        onToggleLike: _toggleLike,
                        onOpenComments: () {
                          FocusScope.of(context).requestFocus(_commentFocusNode);
                        },
                        onRepost: _showRepostModal,
                        onShare: _showShareModal,
                        onToggleBookmark: _toggleBookmark,
                        onMoreOptions: _showPostOptionsMenu,
                        onShowLikes: _showPostLikes,
                        onShowReposts: _showPostReposts,
                        onOpenArtwork: (artwork) {
                          Navigator.pushNamed(
                            context,
                            '/artwork',
                            arguments: {'artworkId': artwork.id},
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Consumer<CommunityCommentsProvider>(
                        builder: (context, commentsProvider, _) {
                          final post = _post;
                          final count = post == null ? 0 : commentsProvider.totalCountForPost(post.id);
                          return Row(
                            children: [
                              Text(
                                l10n.commonComments,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                l10n.commonCommentsCount(count),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Consumer<CommunityCommentsProvider>(
                        builder: (context, commentsProvider, _) {
                          final post = _post;
                          if (post == null) return const SizedBox.shrink();

                          final scheme = Theme.of(context).colorScheme;
                          final currentWallet = WalletUtils.canonical(_currentWalletAddress() ?? '');
                          final loading = commentsProvider.isLoading(post.id);
                          final error = commentsProvider.errorForPost(post.id);
                          final comments = commentsProvider.commentsForPost(post.id);

                          bool canModify(Comment c) {
                            if (currentWallet.isEmpty) return false;
                            final authorKey = WalletUtils.canonical((c.authorWallet ?? c.authorId).toString());
                            return authorKey.isNotEmpty && authorKey == currentWallet;
                          }

                          Future<void> showHistory(Comment c) async {
                            if (!c.isEdited || c.originalContent == null) return;
                            await showDialog<void>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: Text(l10n.commentHistoryTitle),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(l10n.commentHistoryCurrentLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        SelectableText(c.content, style: GoogleFonts.inter()),
                                        const SizedBox(height: 16),
                                        Text(l10n.commentHistoryOriginalLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        SelectableText(c.originalContent ?? '', style: GoogleFonts.inter()),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                      child: Text(l10n.commonClose),
                                    ),
                                  ],
                                );
                              },
                            );
                          }

                          Future<void> promptEdit(Comment c) async {
                            final messenger = ScaffoldMessenger.of(context);
                            final controller = TextEditingController(text: c.content);
                            bool saving = false;
                            await showDialog<void>(
                              context: context,
                              barrierDismissible: !saving,
                              builder: (dialogContext) {
                                return StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    return AlertDialog(
                                      title: Text(l10n.commentEditTitle),
                                      content: TextField(
                                        controller: controller,
                                        maxLines: null,
                                        autofocus: true,
                                        decoration: InputDecoration(hintText: l10n.postDetailWriteCommentHint),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                                          child: Text(l10n.commonCancel),
                                        ),
                                        FilledButton(
                                          onPressed: saving
                                              ? null
                                              : () async {
                                                  final next = controller.text.trim();
                                                  if (next.isEmpty) return;
                                                  setDialogState(() => saving = true);
                                                  try {
                                                    await commentsProvider.editComment(
                                                      postId: post.id,
                                                      commentId: c.id,
                                                      content: next,
                                                    );
                                                    if (!mounted) return;
                                                    if (!dialogContext.mounted) return;
                                                    Navigator.of(dialogContext).pop();
                                                    messenger.showSnackBar(SnackBar(content: Text(l10n.commentUpdatedToast)));
                                                  } catch (_) {
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(l10n.commentEditFailedToast),
                                                        backgroundColor: scheme.errorContainer,
                                                      ),
                                                    );
                                                  } finally {
                                                    if (dialogContext.mounted) {
                                                      setDialogState(() => saving = false);
                                                    }
                                                  }
                                                },
                                          child: Text(l10n.commonSave),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                            controller.dispose();
                          }

                          Future<void> promptDelete(Comment c) async {
                            final messenger = ScaffoldMessenger.of(context);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: Text(l10n.commentDeleteConfirmTitle),
                                  content: Text(l10n.commentDeleteConfirmMessage),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: Text(l10n.commonCancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: scheme.error,
                                        foregroundColor: scheme.onError,
                                      ),
                                      child: Text(l10n.commonDelete),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirmed != true) return;
                            try {
                              await commentsProvider.deleteComment(postId: post.id, commentId: c.id);
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text(l10n.commentDeletedToast)));
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.commentDeleteFailedToast),
                                  backgroundColor: scheme.errorContainer,
                                ),
                              );
                            }
                          }

                          Widget buildComment(Comment c, {required int depth}) {
                            final isReply = depth > 0;
                            final avatar = (c.authorAvatar != null && c.authorAvatar!.isNotEmpty)
                                ? NetworkImage(c.authorAvatar!)
                                : null;

                            final timeLine = Row(
                              children: [
                                Text(
                                  _timeAgo(c.timestamp),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                                if (c.isEdited) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.commonEditedTag,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: scheme.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ],
                            );

                            final canEditDelete = canModify(c);

                            return Padding(
                              padding: EdgeInsets.only(left: depth * 56.0, bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: isReply ? 12 : 16,
                                    backgroundImage: avatar,
                                    child: avatar == null
                                        ? Text(
                                            c.authorName.isNotEmpty ? c.authorName[0] : '?',
                                            style: GoogleFonts.inter(fontSize: isReply ? 12 : 14),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.authorName,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: isReply ? 13 : 14,
                                                ),
                                              ),
                                            ),
                                            if (canEditDelete)
                                              PopupMenuButton<String>(
                                                tooltip: l10n.commonMore,
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    await promptEdit(c);
                                                  } else if (value == 'delete') {
                                                    await promptDelete(c);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                                                  PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        timeLine,
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: (c.isEdited && c.originalContent != null) ? () => showHistory(c) : null,
                                          child: Text(
                                            c.content,
                                            style: GoogleFonts.inter(fontSize: isReply ? 14 : 14),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: Icon(
                                                c.isLiked ? Icons.favorite : Icons.favorite_border,
                                                size: isReply ? 14 : 18,
                                                color: c.isLiked ? scheme.error : Theme.of(context).iconTheme.color,
                                              ),
                                              onPressed: () async {
                                                final messenger = ScaffoldMessenger.of(context);
                                                final prevLiked = c.isLiked;
                                                final prevCount = c.likeCount;
                                                setState(() {
                                                  c.isLiked = !c.isLiked;
                                                  c.likeCount = (c.likeCount + (c.isLiked ? 1 : -1)).clamp(0, 1 << 30);
                                                });
                                                try {
                                                  await CommunityService.toggleCommentLike(c, post.id);
                                                } catch (e) {
                                                  if (kDebugMode) {
                                                    debugPrint('PostDetailScreen: toggle comment like failed: $e');
                                                  }
                                                  if (!mounted) return;
                                                  setState(() {
                                                    c.isLiked = prevLiked;
                                                    c.likeCount = prevCount;
                                                  });
                                                  messenger.showSnackBar(
                                                    SnackBar(content: Text(l10n.postDetailUpdateCommentLikeFailedToast)),
                                                  );
                                                }
                                              },
                                            ),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _showCommentLikes(c.id),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                child: Text(
                                                  '${c.likeCount}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: scheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _replyToCommentId = c.id;
                                                  _replyToAuthorName = c.authorName;
                                                });
                                                _commentController.text = '@${c.authorName} ';
                                                _commentController.selection = TextSelection.fromPosition(
                                                  TextPosition(offset: _commentController.text.length),
                                                );
                                                FocusScope.of(context).requestFocus(_commentFocusNode);
                                              },
                                              child: Text(l10n.commonReply, style: GoogleFonts.inter(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          List<Widget> buildCommentTree(Comment c, {required int depth}) {
                            final widgets = <Widget>[buildComment(c, depth: depth)];
                            for (final r in c.replies) {
                              widgets.addAll(buildCommentTree(r, depth: depth + 1));
                            }
                            return widgets;
                          }

                          if (loading && comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (error != null && comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: EmptyStateCard(
                                icon: Icons.error_outline,
                                title: l10n.postDetailNoCommentsTitle,
                                description: error,
                              ),
                            );
                          }

                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: EmptyStateCard(
                                icon: Icons.comment_bank_outlined,
                                title: l10n.postDetailNoCommentsTitle,
                                description: l10n.postDetailNoCommentsDescription,
                              ),
                            );
                          }

                          return Column(
                            children: [
                              for (final c in comments) ...[
                                ...buildCommentTree(c, depth: 0),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_replyToAuthorName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.postDetailReplyingToLabel(_replyToAuthorName!),
                                  style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() { _replyToAuthorName = null; _replyToCommentId = null; _commentController.clear(); }); }),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              decoration: InputDecoration(
                                hintText: l10n.postDetailWriteCommentHint,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: _submitComment, child: Text(l10n.commonSend)),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
