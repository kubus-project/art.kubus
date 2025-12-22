import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/wallet_utils.dart';
import '../../community/community_interactions.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/backend_api_service.dart';
import '../../providers/app_refresh_provider.dart';
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
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    // capture and clear reply target
    final parentId = _replyToCommentId;
    _replyToCommentId = null;
    _replyToAuthorName = null;
    if (_commentFocusNode.hasFocus) _commentFocusNode.unfocus();

    String authorName = l10n.commonYou;
    String? authorAvatar;
    try {
      final profileResp = await BackendApiService().getMyProfile();
      if (profileResp['success'] == true && profileResp['data'] is Map<String, dynamic>) {
        final p = profileResp['data'] as Map<String, dynamic>;
        authorName = (p['displayName'] ?? p['display_name'] ?? p['username'] ?? authorName).toString();
        authorAvatar = p['avatar'] as String? ?? p['profileImage'] as String? ?? p['profile_image'] as String?;
      }
    } catch (_) {}

    try {
      final newComment = await CommunityService.addComment(
        _post!,
        text,
        authorName,
        parentCommentId: parentId,
        authorAvatar: authorAvatar,
      );

      // Service already updated the post/comments optimistically, refresh UI
      if (!mounted) return;
      setState(() {});

      // Show undo snackbar which attempts to delete the comment from backend and locally
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postDetailCommentAddedToast),
          action: SnackBarAction(
            label: l10n.commonUndo,
            textColor: scheme.secondary,
            onPressed: () async {
              try {
                // Attempt server delete
                await BackendApiService().deleteComment(newComment.id);
              } catch (_) {}
              // Remove locally
              CommunityService.deleteComment(_post!, newComment.id);
              if (mounted) setState(() {});
            },
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PostDetailScreen: add comment failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.postDetailAddCommentFailedToast)));
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                    Text(l10n.postDetailSharePostTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: l10n.postDetailSearchProfilesHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.primaryContainer,
                  ),
                  onChanged: (query) async {
                    if (query.trim().isEmpty) {
                      setModalState(() { searchResults.clear(); });
                      return;
                    }
                    setModalState(() => isSearching = true);
                    try {
                      final resp = await BackendApiService().search(query: query, type: 'profiles', limit: 20);
                      final list = <Map<String, dynamic>>[];
                      if (resp['success'] == true && resp['results'] is Map) {
                        final profiles = (resp['results']['profiles'] as List?) ?? [];
                        for (final p in profiles) { try { list.add(p as Map<String, dynamic>); } catch (_) {} }
                      }
                      setModalState(() { searchResults = list; isSearching = false; });
                    } catch (e) {
                      setModalState(() => isSearching = false);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.link, color: theme.colorScheme.primary),
                      title: Text(l10n.postDetailCopyLink, style: GoogleFonts.inter()),
                      onTap: () async {
                        final sheetNavigator = Navigator.of(sheetContext);
                        final messenger = ScaffoldMessenger.of(context);
                        final postId = _post!.id;

                        await Clipboard.setData(
                          ClipboardData(text: 'https://app.kubus.site/post/$postId'),
                        );

                        if (!mounted) return;
                        sheetNavigator.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.postDetailLinkCopiedToast)),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.share, color: theme.colorScheme.primary),
                      title: Text(l10n.postDetailShareViaEllipsis, style: GoogleFonts.inter()),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final shareText = '${_post!.content}\\n\\n- ${_post!.authorName} on app.kubus\\n\\nhttps://app.kubus.site/post/${_post!.id}';
                        await SharePlus.instance.share(ShareParams(text: shareText));
                      },
                    ),
                  ],
                ),
              ),
              if (searchController.text.isNotEmpty) ...[
                const Divider(),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : searchResults.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: EmptyStateCard(
                                  icon: Icons.search_off,
                                  title: l10n.postDetailNoProfilesFoundTitle,
                                  description: l10n.postDetailNoProfilesFoundDescription,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: searchResults.length,
                              itemBuilder: (ctx, idx) {
                                final profile = searchResults[idx];
                                final walletAddr = profile['wallet_address'] ?? profile['walletAddress'] ?? profile['wallet'] ?? profile['walletAddr'];
                                final username = profile['username'] ?? walletAddr ?? l10n.commonUnknown;
                                final display = profile['displayName'] ?? profile['display_name'] ?? username;
                                final avatar = profile['avatar'] ?? profile['avatar_url'];
                                return ListTile(
                                  leading: AvatarWidget(wallet: username, avatarUrl: avatar, radius: 20),
                                  title: Text(display ?? l10n.commonUnnamed, style: GoogleFonts.inter()),
                                  subtitle: Text('@$username', style: GoogleFonts.inter(fontSize: 12)),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);
                                    final messenger = ScaffoldMessenger.of(context);

                                    try {
                                      await BackendApiService().sharePostViaDM(
                                        postId: _post!.id,
                                        recipientWallet: (walletAddr ?? username).toString(),
                                        message: l10n.postDetailShareDmDefaultMessage,
                                      );

                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(l10n.postDetailShareSuccessToast(username.toString()))),
                                      );
                                    } catch (e) {
                                      if (kDebugMode) {
                                        debugPrint('PostDetailScreen: share via DM failed: $e');
                                      }
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(l10n.postDetailShareFailedToast)),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ],
          ),
        ),
      ),
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
                                          Text(_post!.authorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                              CommunityAuthorRoleBadges(
                                                post: _post!,
                                                fontSize: 10,
                                                iconOnly: true,
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
                      Text(l10n.commonComments, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_post!.comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: EmptyStateCard(
                            icon: Icons.comment_bank_outlined,
                            title: l10n.postDetailNoCommentsTitle,
                            description: l10n.postDetailNoCommentsDescription,
                          ),
                        )
                      else
                        Column(
                          children: _post!.comments.map((c) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundImage: c.authorAvatar != null && c.authorAvatar!.isNotEmpty ? NetworkImage(c.authorAvatar!) : null,
                                    child: c.authorAvatar == null || c.authorAvatar!.isEmpty ? Text(c.authorName.isNotEmpty ? c.authorName[0] : '?') : null,
                                  ),
                                  title: Text(c.authorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.content, style: GoogleFonts.inter()),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              c.isLiked ? Icons.favorite : Icons.favorite_border,
                                              size: 18,
                                              color: c.isLiked ? Theme.of(context).colorScheme.error : Theme.of(context).iconTheme.color,
                                            ),
                                            onPressed: () async {
                                              final messenger = ScaffoldMessenger.of(context);
                                              // optimistic toggle
                                              final prevLiked = c.isLiked;
                                              final prevCount = c.likeCount;
                                              setState(() {
                                                c.isLiked = !c.isLiked;
                                                c.likeCount = (c.likeCount + (c.isLiked ? 1 : -1)).clamp(0, 1 << 30);
                                              });
                                              try {
                                                await CommunityService.toggleCommentLike(c, _post!.id);
                                              } catch (e) {
                                                if (kDebugMode) {
                                                  debugPrint('PostDetailScreen: toggle comment like failed: $e');
                                                }
                                                // rollback
                                                if (!mounted) return;
                                                setState(() {
                                                  c.isLiked = prevLiked;
                                                  c.likeCount = prevCount;
                                                });
                                                messenger.showSnackBar(SnackBar(content: Text(l10n.postDetailUpdateCommentLikeFailedToast)));
                                              }
                                            },
                                          ),
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _showCommentLikes(c.id),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                              child: Text('${c.likeCount}', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _replyToCommentId = c.id;
                                                _replyToAuthorName = c.authorName;
                                              });
                                              // prefill mention and focus
                                              _commentController.text = '@${c.authorName} ';
                                              _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                                              FocusScope.of(context).requestFocus(_commentFocusNode);
                                            },
                                            child: Text(l10n.commonReply, style: GoogleFonts.inter(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Replies
                                if (c.replies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 56.0),
                                    child: Column(
                                      children: c.replies.map((r) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(radius: 12, backgroundImage: r.authorAvatar != null && r.authorAvatar!.isNotEmpty ? NetworkImage(r.authorAvatar!) : null, child: r.authorAvatar == null || r.authorAvatar!.isEmpty ? Text(r.authorName.isNotEmpty ? r.authorName[0] : '?', style: GoogleFonts.inter(fontSize: 12)) : null),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(r.authorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                                    const SizedBox(height: 2),
                                                    Text(r.content, style: GoogleFonts.inter(fontSize: 14)),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          icon: Icon(
                                                            r.isLiked ? Icons.favorite : Icons.favorite_border,
                                                            size: 14,
                                                            color: r.isLiked ? Theme.of(context).colorScheme.error : Theme.of(context).iconTheme.color,
                                                          ),
                                                          onPressed: () async {
                                                            final messenger = ScaffoldMessenger.of(context);
                                                            final prevLiked = r.isLiked;
                                                            final prevCount = r.likeCount;
                                                            setState(() {
                                                              r.isLiked = !r.isLiked;
                                                              r.likeCount = (r.likeCount + (r.isLiked ? 1 : -1)).clamp(0, 1 << 30);
                                                            });
                                                            try {
                                                              await CommunityService.toggleCommentLike(r, _post!.id);
                                                            } catch (e) {
                                                              if (kDebugMode) {
                                                                debugPrint('PostDetailScreen: toggle reply like failed: $e');
                                                              }
                                                              if (!mounted) return;
                                                              setState(() {
                                                                r.isLiked = prevLiked;
                                                                r.likeCount = prevCount;
                                                              });
                                                              messenger.showSnackBar(SnackBar(content: Text(l10n.postDetailUpdateCommentLikeFailedToast)));
                                                            }
                                                          },
                                                        ),
                                                        GestureDetector(
                                                          behavior: HitTestBehavior.opaque,
                                                          onTap: () => _showCommentLikes(r.id),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                            child: Text('${r.likeCount}', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _replyToCommentId = r.id;
                                                              _replyToAuthorName = r.authorName;
                                                            });
                                                            _commentController.text = '@${r.authorName} ';
                                                            _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
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
                                      }).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),
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
