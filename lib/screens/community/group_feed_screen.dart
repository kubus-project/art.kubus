import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';
import '../../models/community_group.dart';
import '../../providers/community_hub_provider.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/inline_loading.dart';
import 'post_detail_screen.dart';

class GroupFeedScreen extends StatefulWidget {
  const GroupFeedScreen({super.key, required this.group});

  final CommunityGroupSummary group;

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  late CommunityGroupSummary _group;
  bool _membershipInFlight = false;

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

  Widget _buildGroupPostCard(CommunityPost post) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = post.imageUrl ??
        (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: AvatarWidget(
              wallet: post.authorWallet ?? post.authorId,
              avatarUrl: post.authorAvatar,
              radius: 20,
              allowFabricatedFallback: true,
            ),
            title: Text(
              post.authorName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _getTimeAgo(post.timestamp),
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.secondary.withValues(alpha: 0.3),
                          scheme.secondary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: InlineLoading(expand: false, shape: BoxShape.circle),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: scheme.onSurface.withValues(alpha: 0.1),
                  child: Icon(Icons.broken_image_outlined,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(l10n.commonComments),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text: l10n.communityGroupFeedShareText(
                            post.authorName,
                            _group.name,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(l10n.commonShare),
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
