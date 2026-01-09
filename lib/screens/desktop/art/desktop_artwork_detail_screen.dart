import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../../models/artwork.dart';
import '../../../models/artwork_comment.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/detail/detail_shell_components.dart';

class DesktopArtworkDetailScreen extends StatefulWidget {
  final String artworkId;
  final bool showAppBar;

  const DesktopArtworkDetailScreen({
    super.key,
    required this.artworkId,
    this.showAppBar = false,
  });

  @override
  State<DesktopArtworkDetailScreen> createState() =>
      _DesktopArtworkDetailScreenState();
}

class _DesktopArtworkDetailScreenState
    extends State<DesktopArtworkDetailScreen> {
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  late final ScrollController _commentsScrollController;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  bool _artworkLoading = true;
  String? _artworkError;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    _commentsScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadArtworkDetails();
      if (!mounted) return;
      context.read<ArtworkProvider>().incrementViewCount(widget.artworkId);
      context.read<ArtworkProvider>().loadComments(widget.artworkId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArtworkDetails() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<ArtworkProvider>();
    final existing = provider.getArtworkById(widget.artworkId);

    if (existing != null) {
      if (mounted) {
        setState(() {
          _artworkLoading = false;
          _artworkError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _artworkLoading = true;
        _artworkError = null;
      });
    }

    try {
      await provider.fetchArtworkIfNeeded(widget.artworkId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkError = l10n.artDetailLoadFailedMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _artworkLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer2<ArtworkProvider, ProfileProvider>(
      builder: (context, artworkProvider, profileProvider, child) {
        final artwork = artworkProvider.getArtworkById(widget.artworkId);
        final isSignedIn = profileProvider.isSignedIn;

        if (_artworkLoading) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title: Text(l10n.artDetailLoadingTitle,
                        style: GoogleFonts.inter()))
                : null,
            body: const Center(child: InlineLoading()),
          );
        }

        if (_artworkError != null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title:
                        Text(l10n.artDetailTitle, style: GoogleFonts.inter()))
                : null,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _artworkError!,
                    style: GoogleFonts.inter(color: scheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadArtworkDetails,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          );
        }

        if (artwork == null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: widget.showAppBar
                ? AppBar(
                    title:
                        Text(l10n.artworkNotFound, style: GoogleFonts.inter()))
                : null,
            body: Center(
                child: Text(l10n.artworkNotFound, style: GoogleFonts.inter())),
          );
        }

        final coverUrl = ArtworkMediaResolver.resolveCover(
          artwork: artwork,
          metadata: artwork.metadata,
        );

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: widget.showAppBar
              ? AppBar(
                  title: Text(artwork.title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.all(DetailSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showTwoColumns = constraints.maxWidth >= 900;
                final sideWidth =
                    (constraints.maxWidth >= 1200) ? 460.0 : 400.0;

                if (!showTwoColumns) {
                  final commentsHeight =
                      (constraints.maxHeight * 0.55).clamp(360.0, 560.0);
                  return Column(
                    children: [
                      Expanded(
                        child: _buildLeftPane(
                          artwork: artwork,
                          coverUrl: coverUrl,
                          artworkProvider: artworkProvider,
                          isSignedIn: isSignedIn,
                        ),
                      ),
                      const SizedBox(height: DetailSpacing.lg),
                      SizedBox(
                        height: commentsHeight,
                        child: _buildCommentsPanel(
                            artwork, artworkProvider, isSignedIn),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildLeftPane(
                        artwork: artwork,
                        coverUrl: coverUrl,
                        artworkProvider: artworkProvider,
                        isSignedIn: isSignedIn,
                      ),
                    ),
                    const SizedBox(width: DetailSpacing.xl),
                    SizedBox(
                      width: sideWidth,
                      child: _buildRightPane(
                        artwork: artwork,
                        artworkProvider: artworkProvider,
                        isSignedIn: isSignedIn,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPane({
    required Artwork artwork,
    required String? coverUrl,
    required ArtworkProvider artworkProvider,
    required bool isSignedIn,
  }) {
    return ListView(
      children: [
        _buildMedia(coverUrl),
        const SizedBox(height: DetailSpacing.lg),
        _buildHeader(artwork),
        const SizedBox(height: DetailSpacing.md),
        _buildActionsRow(artwork, artworkProvider, isSignedIn),
        const SizedBox(height: DetailSpacing.lg),
        _buildDescription(artwork),
      ],
    );
  }

  Widget _buildRightPane({
    required Artwork artwork,
    required ArtworkProvider artworkProvider,
    required bool isSignedIn,
  }) {
    return _buildCommentsPanel(artwork, artworkProvider, isSignedIn);
  }

  Widget _buildMedia(String? coverUrl) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: coverUrl == null
            ? Container(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.image_not_supported,
                    color: scheme.onSurfaceVariant),
              )
            : Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.surfaceContainerHighest,
                  child:
                      Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Artwork artwork) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          artwork.title,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: DetailSpacing.sm),
        ArtworkCreatorByline(
          artwork: artwork,
          style: DetailTypography.caption(context),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildDescription(Artwork artwork) {
    final text = (artwork.description).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: DetailTypography.body(context));
  }

  Widget _buildActionsRow(
      Artwork artwork, ArtworkProvider artworkProvider, bool isSignedIn) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final canInteract = isSignedIn;

    Future<void> requireSignInToast() async {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast,
              style: GoogleFonts.inter()),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _actionButton(
          icon: artwork.isLikedByCurrentUser
              ? Icons.favorite
              : Icons.favorite_border,
          label: '${artwork.likesCount}',
          onPressed: canInteract
              ? () => artworkProvider.toggleLike(artwork.id)
              : requireSignInToast,
          foreground:
              artwork.isLikedByCurrentUser ? scheme.error : scheme.onSurface,
          background: scheme.surfaceContainerHighest,
          tooltip: l10n.commonLikes,
        ),
        _actionButton(
          icon: artwork.isFavoriteByCurrentUser
              ? Icons.bookmark
              : Icons.bookmark_border,
          label: l10n.commonSave,
          onPressed: canInteract
              ? () => artworkProvider.toggleFavorite(artwork.id)
              : requireSignInToast,
          foreground: scheme.onSurface,
          background: scheme.surfaceContainerHighest,
          tooltip: l10n.commonSave,
        ),
        _actionButton(
          icon: Icons.comment_outlined,
          label: '${artwork.commentsCount}',
          onPressed: () {
            if (_commentsScrollController.hasClients) {
              _commentsScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          },
          foreground: scheme.onSurface,
          background: scheme.surfaceContainerHighest,
          tooltip: l10n.commonComments,
        ),
        _actionButton(
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onPressed: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.artwork(
                  artworkId: artwork.id, title: artwork.title),
              sourceScreen: 'desktop_art_detail',
            );
          },
          foreground: scheme.onSurface,
          background: scheme.surfaceContainerHighest,
          tooltip: l10n.commonShare,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color foreground,
    required Color background,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DetailRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: DetailSpacing.md, vertical: DetailSpacing.sm + 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DetailRadius.md),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: DetailSpacing.sm),
              Text(label, style: DetailTypography.button(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsPanel(
      Artwork artwork, ArtworkProvider provider, bool isSignedIn) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final comments = provider.getComments(artwork.id);
    final isLoading = provider.isLoading('load_comments_${artwork.id}');
    final loadError = provider.commentLoadError(artwork.id);

    return DetailCard(
      padding: EdgeInsets.zero,
      borderRadius: DetailRadius.lg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DetailSpacing.lg, 14, DetailSpacing.lg, DetailSpacing.md),
            child: Row(
              children: [
                Text(
                  '${l10n.commonComments} (${artwork.commentsCount})',
                  style: DetailTypography.sectionTitle(context),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.commonRefresh,
                  onPressed: () =>
                      provider.loadComments(artwork.id, force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Divider(
              height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
          Expanded(
            child: isLoading
                ? const Center(child: InlineLoading())
                : (loadError != null)
                    ? _buildCommentsError(loadError,
                        onRetry: () =>
                            provider.loadComments(artwork.id, force: true))
                    : (comments.isEmpty)
                        ? _buildCommentsEmpty()
                        : ListView(
                            controller: _commentsScrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: DetailSpacing.lg,
                                vertical: DetailSpacing.md),
                            children: [
                              for (final c in comments) ...[
                                ..._buildCommentTreeWidgets(
                                  artwork: artwork,
                                  comment: c,
                                  provider: provider,
                                  depth: 0,
                                ),
                              ],
                            ],
                          ),
          ),
          Divider(
              height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _buildCommentComposer(artwork, provider, isSignedIn),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsEmpty() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.postDetailNoCommentsTitle,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.postDetailNoCommentsDescription,
            style: GoogleFonts.inter(
                color: scheme.onSurface.withValues(alpha: 0.65)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsError(String message, {required VoidCallback onRetry}) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                  color: scheme.onSurface.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCommentTreeWidgets({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final widgets = <Widget>[
      _buildCommentTile(
        artwork: artwork,
        comment: comment,
        provider: provider,
        depth: depth,
      ),
      const SizedBox(height: DetailSpacing.md),
    ];

    for (final r in comment.replies) {
      widgets.addAll(
        _buildCommentTreeWidgets(
          artwork: artwork,
          comment: r,
          provider: provider,
          depth: depth + 1,
        ),
      );
    }

    return widgets;
  }

  Widget _buildCommentTile({
    required Artwork artwork,
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profile = context.read<ProfileProvider>().currentUser;
    final walletProvider = context.read<WalletProvider>();

    final currentWallet = WalletUtils.canonical(
      (profile?.walletAddress ?? walletProvider.currentWalletAddress ?? '').toString(),
    );
    final currentId = WalletUtils.canonical((profile?.id ?? '').toString());
    final authorKey = WalletUtils.canonical(comment.userId);
    final canModify = authorKey.isNotEmpty &&
        (authorKey == currentWallet || (currentId.isNotEmpty && authorKey == currentId));

    Future<void> showHistory() async {
      if (!comment.isEdited || comment.originalContent == null) return;
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
                  SelectableText(comment.content, style: GoogleFonts.inter()),
                  const SizedBox(height: 16),
                  Text(l10n.commentHistoryOriginalLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(comment.originalContent ?? '', style: GoogleFonts.inter()),
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

    Future<void> promptEdit() async {
      final messenger = ScaffoldMessenger.of(context);
      final controller = TextEditingController(text: comment.content);
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
                              await provider.editArtworkComment(
                                artworkId: artwork.id,
                                commentId: comment.id,
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

    Future<void> promptDelete() async {
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
        await provider.deleteArtworkComment(artworkId: artwork.id, commentId: comment.id);
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

    final isReply = depth > 0;

    return Padding(
      padding: EdgeInsets.only(left: depth * 48.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(
              avatarUrl: comment.userAvatarUrl,
              wallet: comment.userId,
              radius: isReply ? 14 : 18,
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
                          comment.userName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (comment.isEdited) ...[
                        const SizedBox(width: 8),
                        Text(
                          l10n.commonEditedTag,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      if (canModify)
                        PopupMenuButton<String>(
                          tooltip: l10n.commonMore,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await promptEdit();
                            } else if (value == 'delete') {
                              await promptDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                            PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (comment.isEdited && comment.originalContent != null) ? showHistory : null,
                    child: Text(
                      comment.content,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => provider.toggleCommentLike(artwork.id, comment.id),
                        icon: Icon(
                          comment.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: comment.isLikedByCurrentUser
                              ? scheme.error
                              : scheme.onSurface.withValues(alpha: 0.8),
                        ),
                        tooltip: l10n.commonLikes,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (comment.likesCount > 0)
                        Text(
                          comment.likesCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _replyToCommentId = comment.id;
                            _replyToAuthorName = comment.userName;
                          });
                          _commentController.text = '@${comment.userName} ';
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
      ),
    );
  }

  Widget _buildCommentComposer(
      Artwork artwork, ArtworkProvider provider, bool isSignedIn) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final isSubmitting = provider.isLoading('comment_${artwork.id}');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToAuthorName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.postDetailReplyingToLabel(_replyToAuthorName!),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: () {
                    setState(() {
                      _replyToAuthorName = null;
                      _replyToCommentId = null;
                    });
                    _commentController.clear();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.artworkCommentAddHint,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => _submitComment(artwork, provider, isSignedIn),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: InlineLoading(shape: BoxShape.circle, tileSize: 3.5),
                    )
                  : Icon(Icons.send, size: 18, color: scheme.onPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitComment(
      Artwork artwork, ArtworkProvider provider, bool isSignedIn) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isSignedIn) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.communityCommentAuthRequiredToast,
              style: GoogleFonts.inter()),
          action: SnackBarAction(
            label: l10n.commonSignIn,
            onPressed: () {
              navigator.pushNamed(
                '/sign-in',
                arguments: {
                  'redirectRoute': '/artwork',
                  'redirectArguments': {'artworkId': artwork.id},
                },
              );
            },
          ),
        ),
      );
      return;
    }

    final parentId = _replyToCommentId;
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });

    try {
      await provider.addComment(
        artworkId: artwork.id,
        content: content,
        parentCommentId: parentId,
      );
      if (!mounted) return;
      _commentController.clear();
      // With oldest-first ordering, new comments appear at the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_commentsScrollController.hasClients) {
          _commentsScrollController.animateTo(
            _commentsScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(l10n.artworkCommentAddedToast, style: GoogleFonts.inter()),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      } on BackendApiRequestException catch (e) {
        if (!mounted) return;
        final authRequired = e.statusCode == 401 || e.statusCode == 403;
        String? backendMessage;
        if (!authRequired) {
          try {
            final raw = (e.body ?? '').trim();
            if (raw.isNotEmpty) {
              final decoded = jsonDecode(raw);
              if (decoded is Map<String, dynamic>) {
                final msg = (decoded['error'] ?? decoded['message'] ?? '').toString().trim();
                if (msg.isNotEmpty) {
                  backendMessage = msg.length > 140 ? '${msg.substring(0, 140)}…' : msg;
                }
              }
            }
          } catch (_) {
            // Ignore body parse failures and fall back to a generic message.
          }
        }
        backendMessage = backendMessage?.replaceAll('â€¦', '…');
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              authRequired
                  ? l10n.communityCommentAuthRequiredToast
                  : (backendMessage ?? '${l10n.commonSomethingWentWrong} (${e.statusCode})'),
              style: GoogleFonts.inter(),
            ),
            action: authRequired
                ? SnackBarAction(
                  label: l10n.commonSignIn,
                  onPressed: () {
                    navigator.pushNamed(
                      '/sign-in',
                      arguments: {
                        'redirectRoute': '/artwork',
                        'redirectArguments': {'artworkId': artwork.id},
                      },
                    );
                  },
                )
              : null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(l10n.commonSomethingWentWrong,
                style: GoogleFonts.inter())),
      );
    }
  }
}
