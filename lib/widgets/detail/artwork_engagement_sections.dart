import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/artwork.dart';
import '../../models/artwork_comment.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/wallet_utils.dart';
import '../avatar_widget.dart';
import '../collaboration_panel.dart';
import '../glass_components.dart';
import '../inline_loading.dart';
import '../kubus_snackbar.dart';
import 'detail_shell_components.dart';

enum ArtworkCommentsLayoutMode {
  fill,
  compact,
}

class ArtworkCommentsPanelController {
  VoidCallback? _openAndScrollToTop;

  void _attach(VoidCallback callback) {
    _openAndScrollToTop = callback;
  }

  void _detach(VoidCallback callback) {
    if (_openAndScrollToTop == callback) {
      _openAndScrollToTop = null;
    }
  }

  void openAndScrollToTop() {
    _openAndScrollToTop?.call();
  }
}

class ArtworkCollaboratorsExpandableCard extends StatefulWidget {
  final Artwork artwork;
  final bool initiallyExpanded;

  const ArtworkCollaboratorsExpandableCard({
    super.key,
    required this.artwork,
    this.initiallyExpanded = false,
  });

  @override
  State<ArtworkCollaboratorsExpandableCard> createState() =>
      _ArtworkCollaboratorsExpandableCardState();
}

class _ArtworkCollaboratorsExpandableCardState
    extends State<ArtworkCollaboratorsExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ArtworkCollaboratorsExpandableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork.id != widget.artwork.id) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final viewerWallet = WalletUtils.canonical(
      profileProvider.currentUser?.walletAddress ??
          walletProvider.currentWalletAddress ??
          '',
    );
    final ownerWallet = WalletUtils.canonical(widget.artwork.walletAddress ?? '');
    final isOwner = viewerWallet.isNotEmpty && ownerWallet == viewerWallet;

    return DetailCard(
      padding: const EdgeInsets.fromLTRB(
        DetailSpacing.lg,
        DetailSpacing.md,
        DetailSpacing.lg,
        DetailSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(DetailRadius.sm),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DetailSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.collectionSettingsCollaboration,
                      style: DetailTypography.sectionTitle(context),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: DetailSpacing.sm),
              child: CollaborationPanel(
                entityType: 'artworks',
                entityId: widget.artwork.id,
                myRole: isOwner ? 'owner' : null,
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class ArtworkCommentsExpandableCard extends StatefulWidget {
  final Artwork artwork;
  final bool isSignedIn;
  final bool initiallyExpanded;
  final ArtworkCommentsLayoutMode layoutMode;
  final BoxConstraints compactListConstraints;
  final ArtworkCommentsPanelController? controller;
  final VoidCallback? onClose;
  final Map<String, dynamic>? signInArguments;

  const ArtworkCommentsExpandableCard({
    super.key,
    required this.artwork,
    required this.isSignedIn,
    this.initiallyExpanded = true,
    this.layoutMode = ArtworkCommentsLayoutMode.compact,
    this.compactListConstraints = const BoxConstraints(
      minHeight: 120,
      maxHeight: 280,
    ),
    this.controller,
    this.onClose,
    this.signInArguments,
  });

  @override
  State<ArtworkCommentsExpandableCard> createState() =>
      _ArtworkCommentsExpandableCardState();
}

class _ArtworkCommentsExpandableCardState
    extends State<ArtworkCommentsExpandableCard> {
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  late final ScrollController _commentsScrollController;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  String? _loadedArtworkId;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    _commentsScrollController = ScrollController();
    widget.controller?._attach(_openAndScrollToTop);
    _ensureCommentsLoaded(force: true);
  }

  @override
  void didUpdateWidget(covariant ArtworkCommentsExpandableCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_openAndScrollToTop);
      widget.controller?._attach(_openAndScrollToTop);
    }

    if (oldWidget.artwork.id != widget.artwork.id) {
      _replyToCommentId = null;
      _replyToAuthorName = null;
      _commentController.clear();
      _expanded = widget.initiallyExpanded;
      _ensureCommentsLoaded(force: true);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(_openAndScrollToTop);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  void _ensureCommentsLoaded({bool force = false}) {
    final artworkId = widget.artwork.id.trim();
    if (artworkId.isEmpty) return;
    if (!force && _loadedArtworkId == artworkId) return;
    _loadedArtworkId = artworkId;
    unawaited(context.read<ArtworkProvider>().loadComments(artworkId, force: force));
  }

  void _openAndScrollToTop() {
    if (!mounted) return;
    if (!_expanded) {
      setState(() {
        _expanded = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_commentsScrollController.hasClients) {
        _commentsScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ArtworkProvider>();
    final comments = provider.getComments(widget.artwork.id);
    final isLoading = provider.isLoading('load_comments_${widget.artwork.id}');
    final loadError = provider.commentLoadError(widget.artwork.id);

    return DetailCard(
      padding: EdgeInsets.zero,
      borderRadius: DetailRadius.lg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DetailSpacing.lg,
              DetailSpacing.lg,
              DetailSpacing.lg,
              DetailSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.commonComments} (${widget.artwork.commentsCount})',
                    style: DetailTypography.sectionTitle(context),
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: _expanded ? l10n.commonCollapse : l10n.commonExpand,
                  onPressed: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
                if (widget.onClose != null)
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.commonClose,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.chevron_right),
                  ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.commonRefresh,
                  onPressed: () => _ensureCommentsLoaded(force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            if (widget.layoutMode == ArtworkCommentsLayoutMode.fill)
              Expanded(
                child: _buildCommentsBody(
                  comments: comments,
                  isLoading: isLoading,
                  loadError: loadError,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DetailSpacing.lg,
                  DetailSpacing.md,
                  DetailSpacing.lg,
                  DetailSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: widget.compactListConstraints,
                      child: _buildCommentsBody(
                        comments: comments,
                        isLoading: isLoading,
                        loadError: loadError,
                      ),
                    ),
                    const SizedBox(height: DetailSpacing.md),
                    _buildCommentComposer(provider),
                  ],
                ),
              ),
            if (widget.layoutMode == ArtworkCommentsLayoutMode.fill) ...[
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DetailSpacing.lg,
                  DetailSpacing.sm,
                  DetailSpacing.lg,
                  DetailSpacing.lg,
                ),
                child: _buildCommentComposer(provider),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsBody({
    required List<ArtworkComment> comments,
    required bool isLoading,
    required String? loadError,
  }) {
    if (isLoading) {
      return const Center(child: InlineLoading());
    }
    if (loadError != null) {
      return _buildCommentsError(
        loadError,
        onRetry: () => _ensureCommentsLoaded(force: true),
      );
    }
    if (comments.isEmpty) {
      return _buildCommentsEmpty();
    }

    return ListView(
      controller: _commentsScrollController,
      primary: false,
      padding: EdgeInsets.zero,
      children: [
        for (final comment in comments) ...[
          ..._buildCommentTreeWidgets(
            comment: comment,
            provider: context.read<ArtworkProvider>(),
            depth: 0,
          ),
        ],
      ],
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
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.postDetailNoCommentsDescription,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
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
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
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
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final widgets = <Widget>[
      _buildCommentTile(
        comment: comment,
        provider: provider,
        depth: depth,
      ),
      const SizedBox(height: DetailSpacing.md),
    ];

    for (final reply in comment.replies) {
      widgets.addAll(
        _buildCommentTreeWidgets(
          comment: reply,
          provider: provider,
          depth: depth + 1,
        ),
      );
    }

    return widgets;
  }

  Widget _buildCommentTile({
    required ArtworkComment comment,
    required ArtworkProvider provider,
    required int depth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profile = context.read<ProfileProvider>().currentUser;
    final walletProvider = context.read<WalletProvider>();

    final currentWallet = WalletUtils.canonical(
      (profile?.walletAddress ?? walletProvider.currentWalletAddress ?? '')
          .toString(),
    );
    final currentId = WalletUtils.canonical((profile?.id ?? '').toString());
    final authorKey = WalletUtils.canonical(comment.userId);
    final canModify = authorKey.isNotEmpty &&
        (authorKey == currentWallet ||
            (currentId.isNotEmpty && authorKey == currentId));

    Future<void> showHistory() async {
      if (!comment.isEdited || comment.originalContent == null) return;
      await showKubusDialog<void>(
        context: context,
        builder: (dialogContext) {
          return KubusAlertDialog(
            title: Text(l10n.commentHistoryTitle),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commentHistoryCurrentLabel,
                    style: KubusTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    comment.content,
                    style: KubusTextStyles.detailBody,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.commentHistoryOriginalLabel,
                    style: KubusTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    comment.originalContent ?? '',
                    style: KubusTextStyles.detailBody,
                  ),
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
      await showKubusDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return KubusAlertDialog(
                title: Text(l10n.commentEditTitle),
                content: TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                  decoration:
                      InputDecoration(hintText: l10n.postDetailWriteCommentHint),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(dialogContext).pop(),
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
                                artworkId: widget.artwork.id,
                                commentId: comment.id,
                                content: next,
                              );
                              if (!mounted) return;
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              messenger.showKubusSnackBar(
                                SnackBar(content: Text(l10n.commentUpdatedToast)),
                              );
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showKubusSnackBar(
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
      final confirmed = await showKubusDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return KubusAlertDialog(
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
        await provider.deleteArtworkComment(
          artworkId: widget.artwork.id,
          commentId: comment.id,
        );
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commentDeletedToast)),
        );
      } catch (_) {
        if (!mounted) return;
        messenger.showKubusSnackBar(
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
        padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(KubusRadius.md),
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
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName,
                          style: KubusTextStyles.actionTileTitle.copyWith(
                            fontSize: KubusHeaderMetrics.sectionSubtitle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Text(
                        comment.timeAgo,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (comment.isEdited) ...[
                        const SizedBox(width: 8),
                        Text(
                          l10n.commonEditedTag,
                          style: KubusTextStyles.compactBadge.copyWith(
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
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(l10n.commonEdit),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.commonDelete),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (comment.isEdited && comment.originalContent != null)
                        ? showHistory
                        : null,
                    child: Text(
                      comment.content,
                      style: KubusTextStyles.detailBody.copyWith(
                        fontSize: KubusHeaderMetrics.sectionSubtitle,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            provider.toggleCommentLike(widget.artwork.id, comment.id),
                        icon: Icon(
                          comment.isLikedByCurrentUser
                              ? Icons.favorite
                              : Icons.favorite_border,
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
                          style: KubusTextStyles.navMetaLabel.copyWith(
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
                          _commentController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _commentController.text.length),
                          );
                          FocusScope.of(context).requestFocus(_commentFocusNode);
                        },
                        child: Text(
                          l10n.commonReply,
                          style: KubusTextStyles.navMetaLabel,
                        ),
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

  Widget _buildCommentComposer(ArtworkProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isSubmitting = provider.isLoading('comment_${widget.artwork.id}');

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
                    style: KubusTextStyles.sectionSubtitle.copyWith(
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
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => _submitComment(provider, widget.isSignedIn),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm + KubusSpacing.xs,
                  vertical: KubusSpacing.sm + KubusSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: InlineLoading(
                        shape: BoxShape.circle,
                        tileSize: 3.5,
                      ),
                    )
                  : Icon(Icons.send, size: 18, color: scheme.onPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitComment(ArtworkProvider provider, bool isSignedIn) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isSignedIn) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.communityCommentAuthRequiredToast,
            style: KubusTypography.inter(),
          ),
          action: SnackBarAction(
            label: l10n.commonSignIn,
            onPressed: () {
              navigator.pushNamed(
                '/sign-in',
                arguments: widget.signInArguments ??
                    {
                      'redirectRoute': '/artwork',
                      'redirectArguments': {'artworkId': widget.artwork.id},
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
        artworkId: widget.artwork.id,
        content: content,
        parentCommentId: parentId,
      );
      if (!mounted) return;
      _commentController.clear();
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
      messenger.showKubusSnackBar(
        SnackBar(
          content:
              Text(l10n.artworkCommentAddedToast, style: KubusTypography.inter()),
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
              final msg = (decoded['error'] ?? decoded['message'] ?? '')
                  .toString()
                  .trim();
              if (msg.isNotEmpty) {
                backendMessage =
                    msg.length > 140 ? '${msg.substring(0, 140)}\u2026' : msg;
              }
            }
          }
        } catch (_) {
          // Ignore body parse failures and fall back to a generic message.
        }
      }

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            authRequired
                ? l10n.communityCommentAuthRequiredToast
                : (backendMessage ??
                    '${l10n.commonSomethingWentWrong} (${e.statusCode})'),
            style: KubusTypography.inter(),
          ),
          action: authRequired
              ? SnackBarAction(
                  label: l10n.commonSignIn,
                  onPressed: () {
                    navigator.pushNamed(
                      '/sign-in',
                      arguments: widget.signInArguments ??
                          {
                            'redirectRoute': '/artwork',
                            'redirectArguments': {'artworkId': widget.artwork.id},
                          },
                    );
                  },
                )
              : null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content:
              Text(l10n.commonSomethingWentWrong, style: KubusTypography.inter()),
        ),
      );
    }
  }
}