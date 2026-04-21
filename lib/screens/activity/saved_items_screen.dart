import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../community/community_interactions.dart';
import '../../l10n/app_localizations.dart';
import '../../models/artwork.dart';
import '../../models/collection_record.dart';
import '../../models/event.dart';
import '../../models/exhibition.dart';
import '../../models/saved_item.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../art/collection_detail_screen.dart';
import '../community/post_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';

const double _kSavedSummaryCompactWidth = 480;
const double _kSavedSectionCompactWidth = 440;
const double _kSavedTileCompactWidth = 460;
const double _kSavedTileCompactThumbnailSize = 56;
const double _kSavedTileRegularThumbnailSize = 68;

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  final Set<SavedItemType> _expandedTypes =
      Set<SavedItemType>.from(SavedItemType.values);
  Future<List<CommunityPost>>? _postsFuture;
  bool _prefetching = false;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prefetchMissingEntities());
    });
  }

  Future<List<CommunityPost>> _loadPosts() {
    return BackendApiService().getCommunityPosts(limit: 100);
  }

  Future<void> _refresh() async {
    final savedProvider = context.read<SavedItemsProvider>();
    final postsFuture = _loadPosts();

    if (mounted) {
      setState(() {
        _postsFuture = postsFuture;
      });
    } else {
      _postsFuture = postsFuture;
    }

    await savedProvider.reloadFromDisk();
    await _prefetchMissingEntities();

    try {
      await postsFuture;
    } catch (_) {
      // The section will render placeholders if posts cannot be loaded.
    }
  }

  Future<void> _prefetchMissingEntities() async {
    if (_prefetching) return;
    _prefetching = true;

    try {
      final savedProvider = context.read<SavedItemsProvider>();
      final artworkProvider = context.read<ArtworkProvider>();
      final eventsProvider = context.read<EventsProvider>();
      final collectionsProvider = context.read<CollectionsProvider>();
      final exhibitionsProvider = context.read<ExhibitionsProvider>();

      final tasks = <Future<void>>[];

      for (final record in savedProvider.savedArtworkItems) {
        if (artworkProvider.getArtworkById(record.id) != null) continue;
        tasks.add(
          artworkProvider.fetchArtworkIfNeeded(record.id).then(
                (_) {},
                onError: (_) {},
              ),
        );
      }

      for (final record in savedProvider.savedEventItems) {
        if (eventsProvider.events.any((event) => event.id == record.id)) {
          continue;
        }
        tasks.add(
          eventsProvider.fetchEvent(record.id).then(
                (_) {},
                onError: (_) {},
              ),
        );
      }

      for (final record in savedProvider.savedCollectionItems) {
        if (collectionsProvider.getCollectionById(record.id) != null) continue;
        tasks.add(
          collectionsProvider.fetchCollection(record.id).then(
                (_) {},
                onError: (_) {},
              ),
        );
      }

      for (final record in savedProvider.savedExhibitionItems) {
        if (exhibitionsProvider.exhibitions
            .any((exhibition) => exhibition.id == record.id)) {
          continue;
        }
        tasks.add(
          exhibitionsProvider.fetchExhibition(record.id).then(
                (_) {},
                onError: (_) {},
              ),
        );
      }

      await Future.wait(tasks);
    } finally {
      _prefetching = false;
    }
  }

  void _toggleSection(SavedItemType type) {
    setState(() {
      if (_expandedTypes.contains(type)) {
        _expandedTypes.remove(type);
      } else {
        _expandedTypes.add(type);
      }
    });
  }

  bool _isExpanded(SavedItemType type) => _expandedTypes.contains(type);

  Color _accentForType(SavedItemType type) {
    return switch (type) {
      SavedItemType.artwork => AppColorUtils.tealAccent,
      SavedItemType.event => AppColorUtils.blueAccent,
      SavedItemType.collection => AppColorUtils.orangeAccent,
      SavedItemType.exhibition => AppColorUtils.amberAccent,
      SavedItemType.post => AppColorUtils.cyanAccent,
    };
  }

  String _localizedTypeLabel(AppLocalizations l10n, SavedItemType type) {
    return switch (type) {
      SavedItemType.artwork => l10n.savedItemsArtworkLabel,
      SavedItemType.event => l10n.savedItemsEventLabel,
      SavedItemType.collection => l10n.savedItemsCollectionLabel,
      SavedItemType.exhibition => l10n.savedItemsExhibitionLabel,
      SavedItemType.post => l10n.savedItemsPostLabel,
    };
  }

  String _formatTimestamp(AppLocalizations l10n, DateTime timestamp) {
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savedProvider = context.watch<SavedItemsProvider>();
    final artworkProvider = context.watch<ArtworkProvider>();
    final eventsProvider = context.watch<EventsProvider>();
    final collectionsProvider = context.watch<CollectionsProvider>();
    final exhibitionsProvider = context.watch<ExhibitionsProvider>();

    final totalCount = savedProvider.totalSavedCount;
    final lastSaved = savedProvider.mostRecentSave;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  l10n.profileMenuSavedItemsTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700),
                ),
                flexibleSpace:
                    const KubusGlassAppBarBackdrop(showBottomDivider: true),
                actions: [
                  if (totalCount > 0)
                    IconButton(
                      tooltip: l10n.savedItemsClearAllTooltip,
                      onPressed: _showClearAllDialog,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.md,
              KubusSpacing.md,
              KubusSpacing.md,
              KubusSpacing.xl,
            ),
            children: [
              _SummaryCard(
                title: l10n.profileMenuSavedItemsTitle,
                subtitle: totalCount == 0
                    ? l10n.savedItemsSummarySubtitleEmpty
                    : lastSaved != null
                        ? l10n.savedItemsSummarySubtitleLastSaved(
                            _formatTimestamp(l10n, lastSaved),
                          )
                        : l10n.savedItemsSummarySubtitleEmpty,
                countLabel: l10n.savedItemsSummaryCount(totalCount),
                accent: AppColorUtils.tealAccent,
                icon: Icons.bookmarks_outlined,
              ),
              const SizedBox(height: KubusSpacing.md),
              _SavedItemsSection(
                title: l10n.savedItemsSectionTitle(
                  _localizedTypeLabel(l10n, SavedItemType.artwork),
                ),
                icon: Icons.photo_library_outlined,
                accent: _accentForType(SavedItemType.artwork),
                expanded: _isExpanded(SavedItemType.artwork),
                onToggle: () => _toggleSection(SavedItemType.artwork),
                count: savedProvider.savedArtworksCount,
                child: _buildArtworkSection(
                  context: context,
                  l10n: l10n,
                  savedProvider: savedProvider,
                  artworkProvider: artworkProvider,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              _SavedItemsSection(
                title: l10n.savedItemsSectionTitle(
                  _localizedTypeLabel(l10n, SavedItemType.event),
                ),
                icon: Icons.event_outlined,
                accent: _accentForType(SavedItemType.event),
                expanded: _isExpanded(SavedItemType.event),
                onToggle: () => _toggleSection(SavedItemType.event),
                count: savedProvider.savedEventsCount,
                child: _buildEventSection(
                  context: context,
                  l10n: l10n,
                  savedProvider: savedProvider,
                  eventsProvider: eventsProvider,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              _SavedItemsSection(
                title: l10n.savedItemsSectionTitle(
                  _localizedTypeLabel(l10n, SavedItemType.collection),
                ),
                icon: Icons.folder_outlined,
                accent: _accentForType(SavedItemType.collection),
                expanded: _isExpanded(SavedItemType.collection),
                onToggle: () => _toggleSection(SavedItemType.collection),
                count: savedProvider.savedCollectionsCount,
                child: _buildCollectionSection(
                  context: context,
                  l10n: l10n,
                  savedProvider: savedProvider,
                  collectionsProvider: collectionsProvider,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              _SavedItemsSection(
                title: l10n.savedItemsSectionTitle(
                  _localizedTypeLabel(l10n, SavedItemType.exhibition),
                ),
                icon: Icons.panorama_outlined,
                accent: _accentForType(SavedItemType.exhibition),
                expanded: _isExpanded(SavedItemType.exhibition),
                onToggle: () => _toggleSection(SavedItemType.exhibition),
                count: savedProvider.savedExhibitionsCount,
                child: _buildExhibitionSection(
                  context: context,
                  l10n: l10n,
                  savedProvider: savedProvider,
                  exhibitionsProvider: exhibitionsProvider,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              _SavedItemsSection(
                title: l10n.savedItemsSectionTitle(
                  _localizedTypeLabel(l10n, SavedItemType.post),
                ),
                icon: Icons.forum_outlined,
                accent: _accentForType(SavedItemType.post),
                expanded: _isExpanded(SavedItemType.post),
                onToggle: () => _toggleSection(SavedItemType.post),
                count: savedProvider.savedPostsCount,
                child: _buildPostSection(
                  context: context,
                  l10n: l10n,
                  savedProvider: savedProvider,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required ArtworkProvider artworkProvider,
  }) {
    final records = savedProvider.savedArtworkItems;
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: l10n.savedItemsArtworkLabel,
        icon: Icons.photo_library_outlined,
        accent: AppColorUtils.tealAccent,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          _ArtworkSavedTile(
            l10n: l10n,
            record: records[i],
            artwork: artworkProvider.getArtworkById(records[i].id),
            accent: AppColorUtils.tealAccent,
            onTap: () => openArtwork(
              context,
              records[i].id,
              source: 'saved_items',
            ),
            onRemove: () => _confirmRemoveSavedItem(
              record: records[i],
            ),
          ),
          if (i != records.length - 1) const SizedBox(height: KubusSpacing.md),
        ],
      ],
    );
  }

  Widget _buildEventSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required EventsProvider eventsProvider,
  }) {
    final records = savedProvider.savedEventItems;
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: l10n.savedItemsEventLabel,
        icon: Icons.event_outlined,
        accent: AppColorUtils.blueAccent,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          _EventSavedTile(
            l10n: l10n,
            record: records[i],
            event: eventsProvider.events
                .where((event) => event.id == records[i].id)
                .firstOrNull,
            accent: AppColorUtils.blueAccent,
            onTap: () {
              final event = eventsProvider.events
                  .where((event) => event.id == records[i].id)
                  .firstOrNull;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    eventId: records[i].id,
                    initialEvent: event,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: records[i],
            ),
          ),
          if (i != records.length - 1) const SizedBox(height: KubusSpacing.md),
        ],
      ],
    );
  }

  Widget _buildCollectionSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required CollectionsProvider collectionsProvider,
  }) {
    final records = savedProvider.savedCollectionItems;
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: l10n.savedItemsCollectionLabel,
        icon: Icons.folder_outlined,
        accent: AppColorUtils.orangeAccent,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          _CollectionSavedTile(
            l10n: l10n,
            record: records[i],
            collection: collectionsProvider.getCollectionById(records[i].id),
            accent: AppColorUtils.orangeAccent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(
                    collectionId: records[i].id,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: records[i],
            ),
          ),
          if (i != records.length - 1) const SizedBox(height: KubusSpacing.md),
        ],
      ],
    );
  }

  Widget _buildExhibitionSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required ExhibitionsProvider exhibitionsProvider,
  }) {
    final records = savedProvider.savedExhibitionItems;
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: l10n.savedItemsExhibitionLabel,
        icon: Icons.panorama_outlined,
        accent: AppColorUtils.amberAccent,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          _ExhibitionSavedTile(
            l10n: l10n,
            record: records[i],
            exhibition: exhibitionsProvider.exhibitions
                .where((exhibition) => exhibition.id == records[i].id)
                .firstOrNull,
            accent: AppColorUtils.amberAccent,
            onTap: () {
              final exhibition = exhibitionsProvider.exhibitions
                  .where((exhibition) => exhibition.id == records[i].id)
                  .firstOrNull;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExhibitionDetailScreen(
                    exhibitionId: records[i].id,
                    initialExhibition: exhibition,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: records[i],
            ),
          ),
          if (i != records.length - 1) const SizedBox(height: KubusSpacing.md),
        ],
      ],
    );
  }

  Widget _buildPostSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
  }) {
    final records = savedProvider.savedPostItems;
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: l10n.savedItemsPostLabel,
        icon: Icons.forum_outlined,
        accent: AppColorUtils.cyanAccent,
      );
    }

    final future = _postsFuture ?? _loadPosts();

    return FutureBuilder<List<CommunityPost>>(
      future: future,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <CommunityPost>[];
        final byId = <String, CommunityPost>{
          for (final post in posts) post.id: post,
        };

        return Column(
          children: [
            for (var i = 0; i < records.length; i++) ...[
              _PostSavedTile(
                l10n: l10n,
                record: records[i],
                post: byId[records[i].id],
                accent: AppColorUtils.cyanAccent,
                onTap: () {
                  final post = byId[records[i].id];
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => post != null
                          ? PostDetailScreen(post: post)
                          : PostDetailScreen(postId: records[i].id),
                    ),
                  );
                },
                onRemove: () => _confirmRemoveSavedItem(
                  record: records[i],
                ),
              ),
              if (i != records.length - 1)
                const SizedBox(height: KubusSpacing.md),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptySection({
    required BuildContext context,
    required AppLocalizations l10n,
    required String itemTypeLabel,
    required IconData icon,
    required Color accent,
  }) {
    return _GlassEmptyState(
      icon: icon,
      accent: accent,
      title: l10n.savedItemsEmptySectionTitle(itemTypeLabel),
      description: l10n.savedItemsEmptySectionDescription(itemTypeLabel),
    );
  }

  Future<void> _confirmRemoveSavedItem({
    required SavedItemRecord record,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final savedProvider = context.read<SavedItemsProvider>();

    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(
          l10n.savedItemsRemoveDialogTitle,
          style: KubusTypography.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.savedItemsRemoveDialogMessage,
          style: KubusTypography.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _removeRecord(savedProvider, record);
            },
            child: Text(
              l10n.savedItemsRemoveDialogAction,
              style: KubusTypography.inter(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeRecord(
    SavedItemsProvider savedProvider,
    SavedItemRecord record,
  ) async {
    try {
      if (record.type == SavedItemType.artwork) {
        await savedProvider.removeArtwork(record.id);
      } else if (record.type == SavedItemType.event) {
        await savedProvider.removeEvent(record.id);
      } else if (record.type == SavedItemType.collection) {
        await savedProvider.removeCollection(record.id);
      } else if (record.type == SavedItemType.exhibition) {
        await savedProvider.removeExhibition(record.id);
      } else {
        await savedProvider.removePost(record.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.savedItemsRemovedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonActionFailedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showClearAllDialog() {
    unawaited(showSavedItemsClearAllDialog(context));
  }
}

Future<void> showSavedItemsClearAllDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final savedProvider = context.read<SavedItemsProvider>();

  await showKubusDialog<void>(
    context: context,
    builder: (dialogContext) => KubusAlertDialog(
      title: Text(
        l10n.savedItemsClearAllDialogTitle,
        style: KubusTypography.inter(fontWeight: FontWeight.w700),
      ),
      content: Text(
        l10n.savedItemsClearAllDialogMessage,
        style: KubusTypography.inter(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await savedProvider.clearAll();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.savedItemsClearedToast),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Text(
            l10n.savedItemsClearAllDialogAction,
            style: KubusTypography.inter(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String countLabel;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: accent,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
        ),
      ),
      child: LiquidGlassPanel(
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        blurSigma: style.blurSigma,
        backgroundColor: style.tintColor,
        showBorder: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < _kSavedSummaryCompactWidth;

            Widget buildCountPill({required bool compact}) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? KubusSpacing.sm : KubusSpacing.md,
                  vertical: compact ? KubusSpacing.xs : KubusSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                ),
                child: Text(
                  countLabel,
                  style: KubusTypography.inter(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              );
            }

            final content = isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.lg),
                            ),
                            child: Icon(icon, color: accent, size: 26),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: KubusTypography.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: KubusSpacing.xs),
                                Text(
                                  subtitle,
                                  maxLines: 3,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: KubusTypography.inter(
                                    fontSize: 13,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.68),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      buildCountPill(compact: true),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(KubusRadius.lg),
                        ),
                        child: Icon(
                          icon,
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: KubusTypography.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xs),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: KubusTypography.inter(
                                fontSize: 13,
                                color: scheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      buildCountPill(compact: false),
                    ],
                  );

            return Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: content,
            );
          },
        ),
      ),
    );
  }
}

class _SavedItemsSection extends StatelessWidget {
  const _SavedItemsSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.expanded,
    required this.onToggle,
    required this.count,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final bool expanded;
  final VoidCallback onToggle;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: accent,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: LiquidGlassPanel(
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        blurSigma: style.blurSigma,
        backgroundColor: style.tintColor,
        showBorder: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < _kSavedSectionCompactWidth;

            Widget buildCountPill({required bool compact}) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm,
                  vertical: KubusSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  '$count',
                  style: KubusTypography.inter(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              );
            }

            final header = InkWell(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? KubusSpacing.xs : KubusSpacing.sm,
                  vertical: KubusSpacing.xs,
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(KubusRadius.md),
                                ),
                                child: Icon(icon, color: accent, size: 20),
                              ),
                              const SizedBox(width: KubusSpacing.md),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: KubusTypography.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KubusSpacing.sm),
                          Row(
                            children: [
                              buildCountPill(compact: true),
                              const Spacer(),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.68),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.md),
                            ),
                            child: Icon(icon, color: accent, size: 20),
                          ),
                          const SizedBox(width: KubusSpacing.md),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: KubusTypography.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.md),
                          buildCountPill(compact: false),
                          const SizedBox(width: KubusSpacing.sm),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: scheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
              ),
            );

            return Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: expanded
                        ? Padding(
                            padding:
                                const EdgeInsets.only(top: KubusSpacing.md),
                            child: child,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SavedItemTile extends StatelessWidget {
  const _SavedItemTile({
    required this.l10n,
    required this.title,
    required this.subtitle,
    required this.leadingBuilder,
    required this.accent,
    required this.onTap,
    required this.onRemove,
    this.savedAt,
  });

  final AppLocalizations l10n;
  final String title;
  final String subtitle;
  final Widget Function(double size) leadingBuilder;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String? savedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: accent,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: LiquidGlassPanel(
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        blurSigma: style.blurSigma,
        backgroundColor: style.tintColor,
        showBorder: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact =
                    constraints.maxWidth < _kSavedTileCompactWidth;
                final thumbnailSize = isCompact
                    ? _kSavedTileCompactThumbnailSize
                    : _kSavedTileRegularThumbnailSize;
                final removeButtonSize = isCompact ? 36.0 : 40.0;

                Widget buildTextBlock({required bool compact}) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: compact ? 3 : 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: compact ? 12 : 13,
                          color: scheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  );
                }

                Widget buildSavedAtLabel() {
                  if (savedAt == null) return const SizedBox.shrink();
                  return Text(
                    l10n.savedItemsSavedAtLabel(savedAt!),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.52),
                    ),
                  );
                }

                Widget buildRemoveButton() {
                  return KubusGlassIconButton(
                    icon: Icons.bookmark_remove_outlined,
                    onPressed: onRemove,
                    tooltip: l10n.commonRemove,
                    active: true,
                    accentColor: accent,
                    iconColor: accent,
                    activeIconColor: accent,
                    activeTint: accent,
                    size: removeButtonSize,
                  );
                }

                final content = isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leadingBuilder(thumbnailSize),
                              const SizedBox(width: KubusSpacing.sm),
                              Expanded(child: buildTextBlock(compact: true)),
                            ],
                          ),
                          const SizedBox(height: KubusSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: buildSavedAtLabel()),
                              const SizedBox(width: KubusSpacing.sm),
                              buildRemoveButton(),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leadingBuilder(thumbnailSize),
                          const SizedBox(width: KubusSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildTextBlock(compact: false),
                                if (savedAt != null) ...[
                                  const SizedBox(height: KubusSpacing.sm),
                                  buildSavedAtLabel(),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          buildRemoveButton(),
                        ],
                      );

                return Padding(
                  padding: EdgeInsets.all(
                    isCompact
                        ? KubusSpacing.sm + KubusSpacing.xs
                        : KubusSpacing.md,
                  ),
                  child: content,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkSavedTile extends StatelessWidget {
  const _ArtworkSavedTile({
    required this.l10n,
    required this.record,
    required this.artwork,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final Artwork? artwork;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final resolvedArtwork = artwork;
    final savedAt = record.savedAt;
    final coverUrl =
        ArtworkMediaResolver.resolveCover(artwork: resolvedArtwork);
    final artworkTitle = (resolvedArtwork?.title ?? '').trim();
    final title = artworkTitle.isNotEmpty
        ? artworkTitle
        : l10n.savedItemsPlaceholderTitle;
    final artworkArtist = (resolvedArtwork?.artist ?? '').trim();
    final subtitle = artworkArtist.isNotEmpty
        ? artworkArtist
        : l10n.savedItemsPlaceholderDescription;

    return _SavedItemTile(
      l10n: l10n,
      title: title,
      subtitle: subtitle,
      savedAt: _formatSavedAt(context, savedAt),
      accent: accent,
      onTap: onTap,
      onRemove: onRemove,
      leadingBuilder: (size) => _MediaThumbnail(
        accent: accent,
        imageUrl: coverUrl,
        icon: Icons.photo_library_outlined,
        size: size,
      ),
    );
  }

  String _formatSavedAt(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }
}

class _EventSavedTile extends StatelessWidget {
  const _EventSavedTile({
    required this.l10n,
    required this.record,
    required this.event,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final KubusEvent? event;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final resolvedEvent = event;
    final coverUrl =
        MediaUrlResolver.resolveDisplayUrl(resolvedEvent?.coverUrl);
    final eventTitle = (resolvedEvent?.title ?? '').trim();
    final title =
        eventTitle.isNotEmpty ? eventTitle : l10n.savedItemsPlaceholderTitle;
    final subtitle = _subtitle(context, resolvedEvent);

    return _SavedItemTile(
      l10n: l10n,
      title: title,
      subtitle: subtitle,
      savedAt: _formatSavedAt(context, record.savedAt),
      accent: accent,
      onTap: onTap,
      onRemove: onRemove,
      leadingBuilder: (size) => _MediaThumbnail(
        accent: accent,
        imageUrl: coverUrl,
        icon: Icons.event_outlined,
        size: size,
      ),
    );
  }

  String _subtitle(BuildContext context, KubusEvent? event) {
    if (event == null) {
      return l10n.savedItemsPlaceholderDescription;
    }

    final pieces = <String>[];
    if ((event.locationName ?? '').trim().isNotEmpty) {
      pieces.add(event.locationName!.trim());
    }
    if (event.startsAt != null) {
      pieces.add(
        DateFormat.yMMMd(AppLocalizations.of(context)!.localeName)
            .format(event.startsAt!.toLocal()),
      );
    }
    if (event.endsAt != null) {
      pieces.add(
        DateFormat.yMMMd(AppLocalizations.of(context)!.localeName)
            .format(event.endsAt!.toLocal()),
      );
    }

    if (pieces.isEmpty) {
      return l10n.savedItemsEventLabel;
    }
    return pieces.join(' • ');
  }

  String _formatSavedAt(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }
}

class _CollectionSavedTile extends StatelessWidget {
  const _CollectionSavedTile({
    required this.l10n,
    required this.record,
    required this.collection,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final CollectionRecord? collection;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        MediaUrlResolver.resolveDisplayUrl(collection?.thumbnailUrl);
    final collectionRecord = collection;
    final collectionName = (collectionRecord?.name ?? '').trim();
    final title = collectionName.isNotEmpty
        ? collectionName
        : l10n.savedItemsPlaceholderTitle;
    final subtitle = collectionRecord == null
        ? l10n.savedItemsPlaceholderDescription
        : l10n.userProfileArtworksCountLabel(collectionRecord.artworkCount);

    return _SavedItemTile(
      l10n: l10n,
      title: title,
      subtitle: subtitle,
      savedAt: _formatSavedAt(context, record.savedAt),
      accent: accent,
      onTap: onTap,
      onRemove: onRemove,
      leadingBuilder: (size) => _MediaThumbnail(
        accent: accent,
        imageUrl: coverUrl,
        icon: Icons.folder_outlined,
        size: size,
      ),
    );
  }

  String _formatSavedAt(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }
}

class _ExhibitionSavedTile extends StatelessWidget {
  const _ExhibitionSavedTile({
    required this.l10n,
    required this.record,
    required this.exhibition,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final Exhibition? exhibition;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final coverUrl = MediaUrlResolver.resolveDisplayUrl(exhibition?.coverUrl);
    final exhibitionTitle = (exhibition?.title ?? '').trim();
    final title = exhibitionTitle.isNotEmpty
        ? exhibitionTitle
        : l10n.savedItemsPlaceholderTitle;
    final subtitle = _subtitle(context, exhibition);

    return _SavedItemTile(
      l10n: l10n,
      title: title,
      subtitle: subtitle,
      savedAt: _formatSavedAt(context, record.savedAt),
      accent: accent,
      onTap: onTap,
      onRemove: onRemove,
      leadingBuilder: (size) => _MediaThumbnail(
        accent: accent,
        imageUrl: coverUrl,
        icon: Icons.panorama_outlined,
        size: size,
      ),
    );
  }

  String _subtitle(BuildContext context, Exhibition? exhibition) {
    if (exhibition == null) {
      return l10n.savedItemsPlaceholderDescription;
    }

    final pieces = <String>[];
    if ((exhibition.locationName ?? '').trim().isNotEmpty) {
      pieces.add(exhibition.locationName!.trim());
    }

    final locale = AppLocalizations.of(context)!.localeName;
    if (exhibition.startsAt != null) {
      pieces
          .add(DateFormat.yMMMd(locale).format(exhibition.startsAt!.toLocal()));
    }
    if (exhibition.endsAt != null) {
      pieces.add(DateFormat.yMMMd(locale).format(exhibition.endsAt!.toLocal()));
    }

    if (pieces.isEmpty) {
      return l10n.commonExhibition;
    }
    return pieces.join(' • ');
  }

  String _formatSavedAt(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }
}

class _PostSavedTile extends StatelessWidget {
  const _PostSavedTile({
    required this.l10n,
    required this.record,
    required this.post,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final CommunityPost? post;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(post?.imageUrl);
    final title = post != null
        ? ((post!.authorName).trim().isNotEmpty
            ? post!.authorName.trim()
            : l10n.savedItemsPlaceholderTitle)
        : l10n.savedItemsPlaceholderTitle;
    final subtitle = _subtitle(post);

    return _SavedItemTile(
      l10n: l10n,
      title: title,
      subtitle: subtitle,
      savedAt: _formatSavedAt(context, record.savedAt),
      accent: accent,
      onTap: onTap,
      onRemove: onRemove,
      leadingBuilder: (size) => _MediaThumbnail(
        accent: accent,
        imageUrl: imageUrl,
        icon: Icons.forum_outlined,
        avatarLabel: post?.authorName,
        size: size,
      ),
    );
  }

  String _subtitle(CommunityPost? post) {
    if (post == null) {
      return l10n.savedItemsPlaceholderDescription;
    }
    final content = post.content.trim();
    if (content.isEmpty) return l10n.commonPost;
    if (content.length <= 96) return content;
    return '${content.substring(0, 93).trimRight()}…';
  }

  String _formatSavedAt(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final format = DateFormat.yMMMd(l10n.localeName).add_jm();
    return format.format(timestamp.toLocal());
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.accent,
    required this.imageUrl,
    required this.icon,
    this.size = _kSavedTileRegularThumbnailSize,
    this.avatarLabel,
  });

  final Color accent;
  final String? imageUrl;
  final IconData icon;
  final double size;
  final String? avatarLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolved = imageUrl?.trim();
    final hasImage = resolved != null && resolved.isNotEmpty;
    final image = resolved ?? '';
    final boxDecoration = BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      border: Border.all(color: accent.withValues(alpha: 0.18)),
    );

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: Image.network(
          image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(boxDecoration, scheme),
        ),
      );
    }

    return _fallback(boxDecoration, scheme);
  }

  Widget _fallback(BoxDecoration decoration, ColorScheme scheme) {
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: avatarLabel != null && avatarLabel!.trim().isNotEmpty
          ? Center(
              child: Text(
                avatarLabel!.trim()[0].toUpperCase(),
                style: KubusTypography.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            )
          : Icon(icon, size: 28, color: accent),
    );
  }
}

class _GlassEmptyState extends StatelessWidget {
  const _GlassEmptyState({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: accent,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: LiquidGlassPanel(
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        blurSigma: style.blurSigma,
        backgroundColor: style.tintColor,
        showBorder: false,
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            children: [
              Icon(icon, size: 40, color: accent),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: KubusTypography.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                description,
                textAlign: TextAlign.center,
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
