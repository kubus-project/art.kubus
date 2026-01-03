import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';
import '../../models/community_group.dart';
import '../../models/community_subject.dart';
import '../../providers/community_subject_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/app_animations.dart';
import '../../utils/community_subject_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/community/community_post_card.dart';
import '../../widgets/community/community_post_options_sheet.dart';
import '../../widgets/community/community_subject_picker.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/inline_loading.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class GroupFeedScreen extends StatefulWidget {
  const GroupFeedScreen({super.key, required this.group});

  final CommunityGroupSummary group;

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  late CommunityGroupSummary _group;
  bool _membershipInFlight = false;
  final TextEditingController _composerController = TextEditingController();
  bool _posting = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.loadGroupPosts(_group.id, refresh: true);
      if (!hub.groupsInitialized) {
        hub.loadGroups();
      }
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          Consumer<CommunityHubProvider>(
            builder: (context, hub, _) {
              final latest = _resolveGroup(hub);
              final isOwner = latest.isOwner;
              final isMember = latest.isMember;
              final label = isOwner
                  ? l10n.commonOwner
                  : isMember
                      ? l10n.commonJoined
                      : l10n.commonJoin;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ElevatedButton(
                  onPressed: isOwner
                      ? null
                      : (_membershipInFlight
                          ? null
                          : () => _toggleMembership(hub, latest)),
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CommunityHubProvider>(
        builder: (context, hub, _) {
          final summary = _resolveGroup(hub);
          final posts = hub.groupPosts(summary.id);
          final loading = hub.groupPostsLoading(summary.id);
          final error = hub.groupPostsError(summary.id);

          if (posts.isEmpty && loading) {
            return const AppLoading();
          }

          return RefreshIndicator(
            onRefresh: () => hub.loadGroupPosts(summary.id, refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                _buildGroupHeader(summary),
                const SizedBox(height: 16),
                _buildComposer(summary, hub),
                const SizedBox(height: 16),
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error,
                            style: GoogleFonts.inter(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => hub.loadGroupPosts(summary.id,
                              refresh: posts.isEmpty),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                if (posts.isEmpty && !loading && error == null)
                  EmptyStateCard(
                    icon: Icons.forum_outlined,
                    title: l10n.communityGroupFeedEmptyTitle,
                    description: l10n.communityGroupFeedEmptyDescription,
                  ),
                ...posts.map(_buildGroupPostCard),
                if (loading && posts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: InlineLoading(
                        expand: false,
                        shape: BoxShape.circle,
                        tileSize: 4,
                        progress: null,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  CommunityGroupSummary _resolveGroup(CommunityHubProvider hub) {
    final match = hub.groups.firstWhere(
      (g) => g.id == _group.id,
      orElse: () => _group,
    );
    _group = match;
    return match;
  }

  Widget _buildComposer(CommunityGroupSummary summary, CommunityHubProvider hub) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profileProvider = context.watch<ProfileProvider>();
    final isSignedIn = profileProvider.isSignedIn;
    final isMember = summary.isMember || summary.isOwner;
    final draft = hub.draft;

    if (!isSignedIn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.login, color: scheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign in to post.',
                style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.8)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/sign-in'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    if (!isMember) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Join this group to post.',
                style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.8)),
              ),
            ),
            TextButton(
              onPressed: _membershipInFlight ? null : () => _toggleMembership(hub, summary),
              child: Text(l10n.commonJoin),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _composerController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.communityComposerTextHint,
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_selectedImageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.memory(
                    _selectedImageBytes!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.8),
                      ),
                      onPressed: _posting
                          ? null
                          : () => setState(() {
                                _selectedImage = null;
                                _selectedImageBytes = null;
                              }),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildComposerSubjectSelector(draft, hub),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: l10n.commonImage,
                onPressed: _posting ? null : _pickComposerImage,
                icon: const Icon(Icons.image_outlined),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _posting ? null : () => _submitGroupPost(summary, hub),
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonPost),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickComposerImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _submitGroupPost(CommunityGroupSummary summary, CommunityHubProvider hub) async {
    if (_posting) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final content = _composerController.text.trim();
    if (content.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityComposerAddContentToast)));
      return;
    }

    setState(() => _posting = true);
    try {
      String? imageUrl;
      if (_selectedImageBytes != null && _selectedImage != null) {
        final upload = await BackendApiService().uploadFile(
          fileBytes: _selectedImageBytes!,
          fileName: _selectedImage!.name,
          fileType: 'community_post_media',
          metadata: {'scope': 'group_post', 'groupId': summary.id},
        );
        final raw = upload['uploadedUrl']?.toString();
        imageUrl = MediaUrlResolver.resolve(raw) ?? raw;
      }

      final draft = hub.draft;
      await hub.submitGroupPost(
        summary.id,
        content: content,
        imageUrl: imageUrl,
        artworkId: draft.artwork?.id,
        subjectType: draft.subjectType,
        subjectId: draft.subjectId,
      );

      if (!mounted) return;
      setState(() {
        _posting = false;
        _composerController.clear();
        _selectedImage = null;
        _selectedImageBytes = null;
      });
      hub.setDraftSubject();
      hub.setDraftArtwork(null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.communityComposerPostCreatedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.communityComposerCreatePostFailedToast),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleMembership(
      CommunityHubProvider hub, CommunityGroupSummary group) async {
    if (_membershipInFlight) return;
    setState(() => _membershipInFlight = true);
    try {
      if (group.isMember) {
        await hub.leaveGroup(group.id);
      } else {
        await hub.joinGroup(group.id);
      }
      setState(() {
        _group = _resolveGroup(hub);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroupFeedScreen: failed to update membership: $e');
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityGroupMembershipUpdateFailedToast)),
      );
    } finally {
      if (mounted) {
        setState(() => _membershipInFlight = false);
      }
    }
  }

  Widget _buildGroupHeader(CommunityGroupSummary summary) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.name,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.description?.isNotEmpty == true
                ? summary.description!
                : l10n.communityGroupNoDescription,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                avatar: const Icon(Icons.people_alt, size: 16),
                label: Text(l10n.commonMembersCount(summary.memberCount)),
              ),
              Chip(
                avatar: Icon(
                  summary.isPublic ? Icons.public : Icons.lock,
                  size: 16,
                ),
                label: Text(summary.isPublic ? l10n.commonPublic : l10n.commonPrivate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerSubjectSelector(CommunityPostDraft draft, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final subjectProvider = context.read<CommunitySubjectProvider>();
    final animationTheme = context.animationTheme;

    CommunitySubjectPreview? preview;
    final type = (draft.subjectType ?? '').trim();
    final id = (draft.subjectId ?? '').trim();
    if (type.isNotEmpty && id.isNotEmpty) {
      preview = subjectProvider.previewFor(
        CommunitySubjectRef(type: type, id: id),
      );
    }
    if (preview == null && draft.artwork != null) {
      preview = CommunitySubjectPreview(
        ref: CommunitySubjectRef(type: 'artwork', id: draft.artwork!.id),
        title: draft.artwork!.title,
        imageUrl: MediaUrlResolver.resolve(draft.artwork!.imageUrl) ?? draft.artwork!.imageUrl,
      );
    }

    final previewValue = preview;
    final bool hasSubject = previewValue != null;
    final String label;
    final String title;
    final IconData subjectIcon;
    final String? imageUrl;
    if (previewValue == null) {
      label = l10n.communitySubjectSelectPrompt;
      title = l10n.communitySubjectSelectTitle;
      subjectIcon = Icons.link;
      imageUrl = null;
    } else {
      label = l10n.communitySubjectLinkedLabel(
        _subjectTypeLabel(l10n, previewValue.ref.normalizedType),
      );
      title = previewValue.title;
      subjectIcon = _subjectTypeIcon(previewValue.ref.normalizedType);
      imageUrl = previewValue.imageUrl;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final selection =
            await CommunitySubjectPicker.pick(context, initialType: draft.subjectType);
        if (selection == null) return;
        if (selection.cleared) {
          hub.setDraftSubject();
          hub.setDraftArtwork(null);
          return;
        }
        final selected = selection.preview;
        if (selected == null) return;
        subjectProvider.upsertPreview(selected);
        hub.setDraftSubject(type: selected.ref.normalizedType, id: selected.ref.id);
        if (selected.ref.normalizedType == 'artwork') {
          hub.setDraftArtwork(
            CommunityArtworkReference(
              id: selected.ref.id,
              title: selected.title,
              imageUrl: selected.imageUrl,
            ),
          );
        } else {
          hub.setDraftArtwork(null);
        }
      },
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasSubject
              ? scheme.primaryContainer.withValues(alpha: 0.25)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasSubject
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            if (previewValue != null && imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    subjectIcon,
                    color: scheme.onSurface,
                  ),
                ),
              )
            else
              Icon(
                subjectIcon,
                color: scheme.onSurface,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
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
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  String _subjectTypeLabel(AppLocalizations l10n, String type) {
    switch (type.toLowerCase()) {
      case 'artwork':
        return l10n.commonArtwork;
      case 'exhibition':
        return l10n.commonExhibition;
      case 'collection':
        return l10n.commonCollection;
      case 'institution':
        return l10n.commonInstitution;
      default:
        return l10n.commonDetails;
    }
  }

  IconData _subjectTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'artwork':
        return Icons.view_in_ar;
      case 'exhibition':
        return Icons.event_outlined;
      case 'collection':
        return Icons.collections_bookmark_outlined;
      case 'institution':
        return Icons.apartment_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildGroupPostCard(CommunityPost post) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return CommunityPostCard(
      post: post,
      accentColor: themeProvider.accentColor,
      onOpenPostDetail: _openPostDetail,
      onOpenAuthorProfile: () => _viewUserProfile(post.authorId),
      onToggleLike: () => _toggleLike(post),
      onOpenComments: () => _openPostDetail(post),
      onRepost: () {
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        final currentWallet = walletProvider.currentWalletAddress;
        if (post.postType == 'repost' && post.authorWallet == currentWallet) {
          _showRepostOptions(post);
        } else {
          _showRepostModal(post);
        }
      },
      onShare: () => _sharePost(post),
      onToggleBookmark: () => _toggleBookmark(post),
      onMoreOptions: () => _showPostOptionsForPost(post),
      onShowLikes: () => _showPostLikes(post.id),
      onShowReposts: () => _viewRepostsList(post),
      onOpenSubject: (preview) => CommunitySubjectNavigation.open(
        context,
        subject: preview.ref,
        titleOverride: preview.title,
      ),
    );
  }

  void _openPostDetail(CommunityPost post, {PostDetailInitialAction? initialAction}) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final groupId = post.groupId ?? _group.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          initialAction: initialAction,
          onClose: () {
            hub.removeGroupPost(groupId, post.id);
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  String? _currentWalletAddress() {
    try {
      return Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;
    } catch (_) {
      return null;
    }
  }

  void _showPostOptionsForPost(CommunityPost post) {
    if (!mounted) return;
    final currentWallet = _currentWalletAddress();
    final authorWallet = post.authorWallet ?? post.authorId;
    final isOwner =
        currentWallet != null && WalletUtils.equals(authorWallet, currentWallet);

    showCommunityPostOptionsSheet(
      context: context,
      post: post,
      isOwner: isOwner,
      onReport: () => _openPostDetail(post, initialAction: PostDetailInitialAction.report),
      onEdit: () => _openPostDetail(post, initialAction: PostDetailInitialAction.edit),
      onDelete: () => _openPostDetail(post, initialAction: PostDetailInitialAction.delete),
    );
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final wasLiked = post.isLiked;
    final l10n = AppLocalizations.of(context)!;
    final walletAddress =
        Provider.of<WalletProvider>(context, listen: false).currentWalletAddress;

    try {
      await CommunityService.togglePostLike(
        post,
        currentUserWallet: walletAddress,
      );

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !wasLiked ? l10n.postDetailPostLikedToast : l10n.postDetailLikeRemovedToast,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroupFeedScreen: togglePostLike failed: $e');
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.communityToggleLikeFailedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(CommunityPost post) async {
    final l10n = AppLocalizations.of(context)!;
    final savedItemsProvider =
        Provider.of<SavedItemsProvider>(context, listen: false);
    try {
      await CommunityService.toggleBookmark(post);
      await savedItemsProvider.setPostSaved(post.id, post.isBookmarked);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.isBookmarked
                ? l10n.communityBookmarkAddedToast
                : l10n.communityBookmarkRemovedToast,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroupFeedScreen: bookmark toggle failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.communityBookmarkUpdateFailedToast),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _sharePost(CommunityPost post) {
    ShareService().showShareSheet(
      context,
      target: ShareTarget.post(postId: post.id, title: post.content),
      sourceScreen: 'group_feed',
    );
  }

  void _showPostLikes(String postId) {
    final l10n = AppLocalizations.of(context)!;
    _showLikesDialog(
      title: l10n.communityPostLikesTitle,
      loader: () => BackendApiService().getPostLikes(postId),
    );
  }

  void _showLikesDialog({
    required String title,
    required Future<List<CommunityLikeUser>> Function() loader,
  }) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final future = loader();

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
                      return Center(
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
                                'Failed to load likes',
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
                                  color:
                                      theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return const Center(
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: 'No likes yet',
                          description: 'Be the first to like this post',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final username = (user.username ?? user.walletAddress ?? '').trim();
                        return ListTile(
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            allowFabricatedFallback: true,
                          ),
                          title: Text(
                            user.displayName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          subtitle: username.isNotEmpty
                              ? Text(
                                  '@$username',
                                  style: GoogleFonts.inter(fontSize: 12),
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

  void _viewRepostsList(CommunityPost post) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                future: BackendApiService().getPostReposts(postId: post.id),
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
                          wallet: username,
                          avatarUrl: avatar,
                          radius: 20,
                        ),
                        title: Text(
                          displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username',
                                style: GoogleFonts.inter(fontSize: 12)),
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
                                _getTimeAgo(createdAt),
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
      ),
    );
  }

  void _showRepostModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final repostContentController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.postDetailRepostTitle,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(l10n.commonCancel,
                              style: GoogleFonts.inter()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final content = repostContentController.text.trim();
                            Navigator.pop(sheetContext);
                            final messenger = ScaffoldMessenger.of(context);

                            try {
                              await BackendApiService().createRepost(
                                originalPostId: post.id,
                                content: content.isNotEmpty ? content : null,
                              );
                              BackendApiService().trackAnalyticsEvent(
                                eventType: 'repost_created',
                                postId: post.id,
                                metadata: {'has_comment': content.isNotEmpty},
                              );

                              if (!mounted) return;
                              setState(() {
                                post.shareCount =
                                    (post.shareCount + 1).clamp(0, 1 << 30);
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    content.isEmpty
                                        ? l10n.postDetailRepostSuccessToast
                                        : l10n.postDetailRepostWithCommentSuccessToast,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint('GroupFeedScreen: repost failed: $e');
                              }
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content:
                                      Text(l10n.postDetailRepostFailedToast),
                                ),
                              );
                            }
                          },
                          child: Text(
                            l10n.postDetailRepostButton,
                            style: GoogleFonts.inter(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: repostContentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.postDetailRepostThoughtsHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CommunityPostCard(
                  post: post,
                  accentColor: themeProvider.accentColor,
                  onOpenPostDetail: _openPostDetail,
                  onOpenAuthorProfile: () => _viewUserProfile(post.authorId),
                  onToggleLike: () => _toggleLike(post),
                  onOpenComments: () => _openPostDetail(post),
                  onRepost: () {},
                  onShare: () {},
                  onToggleBookmark: () => _toggleBookmark(post),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepostOptions(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(
                l10n.communityUnrepostAction,
                style: GoogleFonts.inter(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _unrepostPost(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unrepostPost(CommunityPost post) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityUnrepostTitle, style: GoogleFonts.inter()),
        content: Text(
          l10n.communityUnrepostConfirmBody,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel, style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.communityUnrepostAction,
              style: GoogleFonts.inter(),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BackendApiService().deleteRepost(post.id);
      BackendApiService().trackAnalyticsEvent(
        eventType: 'repost_deleted',
        postId: post.originalPostId ?? post.id,
        metadata: {'repost_id': post.id},
      );

      if (!mounted) return;
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      final groupId = post.groupId ?? _group.id;
      hub.removeGroupPost(groupId, post.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.communityRepostRemovedToast)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroupFeedScreen: unrepost failed: $e');
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.communityUnrepostFailedToast)),
      );
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) {
      return l10n.commonTimeAgoJustNow;
    } else if (difference.inMinutes < 60) {
      return l10n.commonTimeAgoMinutes(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.commonTimeAgoHours(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.commonTimeAgoDays(difference.inDays);
    } else {
      final weeks = (difference.inDays / 7).floor();
      return l10n.commonTimeAgoWeeks(weeks);
    }
  }
}
