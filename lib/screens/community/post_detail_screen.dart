import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../community/community_interactions.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/backend_api_service.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost? post;
  final String? postId;
  final VoidCallback? onClose;

  const PostDetailScreen({super.key, this.post, this.postId, this.onClose}) : assert(post != null || postId != null);

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

  String? _currentWalletAddress() {
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
    } else if (widget.postId != null) {
      _fetchPost(widget.postId!);
    }
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

  List<Widget> _buildAuthorRoleBadges(CommunityPost post, {double fontSize = 10}) {
    final widgets = <Widget>[];
    if (post.authorIsArtist) {
      widgets.add(const SizedBox(width: 6));
      widgets.add(ArtistBadge(
        fontSize: fontSize,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        iconOnly: true,
      ));
    }
    if (post.authorIsInstitution) {
      widgets.add(const SizedBox(width: 6));
      widgets.add(InstitutionBadge(
        fontSize: fontSize,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        iconOnly: true,
      ));
    }
    return widgets;
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
      final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_post!.isLiked ? l10n.postDetailPostLikedToast : l10n.postDetailLikeRemovedToast),
          action: SnackBarAction(
            label: l10n.commonUndo,
            textColor: accent,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postDetailUpdateLikeFailedToast),
          action: SnackBarAction(
            label: l10n.commonRetry,
            textColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postDetailCommentAddedToast),
          action: SnackBarAction(
            label: l10n.commonUndo,
            textColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
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
                                          if (_post!.authorIsArtist) ...[
                                            const SizedBox(width: 6),
                                            const ArtistBadge(fontSize: 10, iconOnly: true),
                                          ],
                                          if (_post!.authorIsInstitution) ...[
                                            const SizedBox(width: 6),
                                            const InstitutionBadge(fontSize: 10, iconOnly: true),
                                          ],
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

  Widget _buildPostDetailCard(CommunityPost post) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final textColor = scheme.onSurface;
    final isRepost = (post.postType ?? '').toLowerCase() == 'repost';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorHeader(post),
          const SizedBox(height: 16),
          // Category badge
          if (post.category.isNotEmpty && post.category.toLowerCase() != 'post') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(post.category),
                    size: 14,
                    color: themeProvider.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatCategoryLabel(post.category),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isRepost && post.content.isNotEmpty) ...[
            Text(
              post.content,
              style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: textColor),
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
          ],
          if (isRepost)
            post.originalPost != null
                ? _buildOriginalPostCard(post.originalPost!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMissingOriginalNotice(),
                      if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildPostImage(post.imageUrl!),
                      ],
                    ],
                  )
          else ...[
            Text(
              post.content,
              style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: textColor),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPostImage(post.imageUrl!),
            ],
          ],
          // Metadata section
          if (!isRepost) _buildPostMetadataSection(post, scheme, themeProvider),
        ],
      ),
    );
  }

  Widget _buildPostMetadataSection(CommunityPost post, ColorScheme scheme, ThemeProvider themeProvider) {
    final hasMetadata = post.tags.isNotEmpty ||
        post.mentions.isNotEmpty ||
        post.location != null ||
        post.artwork != null ||
        post.group != null;

    if (!hasMetadata) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: scheme.outline.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        // Tags
        if (post.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '#$tag',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.accentColor,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Mentions
        if (post.mentions.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.mentions.map((mention) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '@$mention',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Location
        if (post.location != null && (post.location!.name?.isNotEmpty == true || post.location!.lat != null)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: scheme.tertiary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    post.location!.name ?? '${post.location!.lat!.toStringAsFixed(4)}, ${post.location!.lng!.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
                if (post.distanceKm != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${post.distanceKm!.toStringAsFixed(1)} km',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Artwork reference
        if (post.artwork != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: post.artwork!.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            post.artwork!.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.view_in_ar,
                              color: themeProvider.accentColor,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.view_in_ar,
                          color: themeProvider.accentColor,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.artwork!.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Linked artwork',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Group reference
        if (post.group != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups_2,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Posted in ${post.group!.name}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ar_drop':
      case 'art_drop':
        return Icons.place_outlined;
      case 'art_review':
        return Icons.rate_review_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'poll':
        return Icons.poll_outlined;
      case 'question':
        return Icons.help_outline;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'review':
        return Icons.rate_review_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _formatCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'ar_drop':
      case 'art_drop':
        return 'AR Drop';
      case 'art_review':
        return 'Art Review';
      case 'event':
        return 'Event';
      case 'poll':
        return 'Poll';
      case 'question':
        return 'Question';
      case 'announcement':
        return 'Announcement';
      case 'review':
        return 'Review';
      default:
        return category.replaceAll('_', ' ').split(' ').map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
    }
  }

  Widget _buildAuthorHeader(CommunityPost post) {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 360;
    final handle = _formatAuthorHandle(post);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarWidget(
          wallet: post.authorWallet ?? post.authorId,
          avatarUrl: post.authorAvatar,
          radius: 26,
          allowFabricatedFallback: true,
          enableProfileNavigation: true,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.authorName,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ..._buildAuthorRoleBadges(post, fontSize: 9),
                ],
              ),
              if (handle.isNotEmpty)
                Text(
                  handle,
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 12 : 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _timeAgo(post.timestamp),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  String _formatAuthorHandle(CommunityPost post) {
    final username = post.authorUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    final raw = (post.authorWallet ?? post.authorId).trim();
    if (raw.isEmpty) return '';
    if (raw.length <= 12) return raw;
    return '${raw.substring(0, 6)}...${raw.substring(raw.length - 4)}';
  }

  Widget _buildOriginalPostCard(CommunityPost originalPost) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final originalHandle = originalPost.authorUsername?.trim();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: originalPost)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: originalPost.authorWallet ?? originalPost.authorId,
                  avatarUrl: originalPost.authorAvatar,
                  radius: 18,
                  allowFabricatedFallback: true,
                  enableProfileNavigation: true,
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
                              originalPost.authorName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._buildAuthorRoleBadges(originalPost, fontSize: 8),
                        ],
                      ),
                      if (originalHandle != null && originalHandle.isNotEmpty)
                        Text(
                          '@$originalHandle',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(originalPost.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              originalPost.content,
              style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: scheme.onSurface),
            ),
            if (originalPost.imageUrl != null && originalPost.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  originalPost.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.image_not_supported, color: themeProvider.accentColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissingOriginalNotice() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Original post is no longer available',
              style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(String imageUrl) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 220,
          color: themeProvider.accentColor.withValues(alpha: 0.1),
          child: Icon(Icons.image_not_supported, color: themeProvider.accentColor),
        ),
      ),
    );
  }

  Widget _buildDetailAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final color = highlight ? accent : scheme.onSurface.withValues(alpha: 0.7);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      _buildPostDetailCard(_post!),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildDetailAction(
                            icon: _post!.isLiked ? Icons.favorite : Icons.favorite_border,
                            label: '${_post!.likeCount}',
                            onTap: _toggleLike,
                            highlight: _post!.isLiked,
                          ),
                          _buildDetailAction(
                            icon: Icons.chat_bubble_outline,
                            label: '${_post!.commentCount}',
                            onTap: () {
                              FocusScope.of(context).requestFocus(_commentFocusNode);
                            },
                          ),
                          _buildDetailAction(
                            icon: Icons.repeat,
                            label: '${_post!.shareCount}',
                            onTap: () => _showRepostModal(),
                          ),
                          _buildDetailAction(
                            icon: Icons.share,
                            label: l10n.commonShare,
                            onTap: () => _showShareModal(),
                          ),
                        ],
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
