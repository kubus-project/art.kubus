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
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../providers/main_tab_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../art/collection_detail_screen.dart';
import '../community/post_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../desktop/desktop_shell_scope.dart';

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
  final Map<SavedItemType, int> _visibleLimitByType = {
    for (final type in SavedItemType.values) type: 50,
  };
  bool _prefetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prefetchMissingEntities());
    });
  }

  Future<void> _refresh() async {
    final savedProvider = context.read<SavedItemsProvider>();
    await savedProvider.reloadFromDisk();
    await _prefetchMissingEntities();
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

  int _visibleLimit(SavedItemType type) => _visibleLimitByType[type] ?? 50;

  Future<void> _loadMore(
      SavedItemsProvider savedProvider, SavedItemType type) async {
    await savedProvider.loadMore(type);
    if (!mounted) return;
    setState(() {
      _visibleLimitByType[type] = _visibleLimit(type) + 50;
    });
  }

  Color _accentForType(SavedItemType type) {
    return switch (type) {
      SavedItemType.artwork => AppColorUtils.tealAccent,
      SavedItemType.event => AppColorUtils.blueAccent,
      SavedItemType.collection => AppColorUtils.orangeAccent,
      SavedItemType.exhibition => AppColorUtils.amberAccent,
      SavedItemType.communityPost => AppColorUtils.cyanAccent,
      SavedItemType.artist => AppColorUtils.pinkAccent,
      SavedItemType.institution => AppColorUtils.blueAccent,
      SavedItemType.group => AppColorUtils.greenAccent,
      SavedItemType.marker => AppColorUtils.coralAccent,
    };
  }

  String _localizedTypeLabel(AppLocalizations l10n, SavedItemType type) {
    return switch (type) {
      SavedItemType.artwork => l10n.savedItemsArtworkLabel,
      SavedItemType.event => l10n.savedItemsEventLabel,
      SavedItemType.collection => l10n.savedItemsCollectionLabel,
      SavedItemType.exhibition => l10n.savedItemsExhibitionLabel,
      SavedItemType.communityPost => l10n.savedItemsPostLabel,
      SavedItemType.artist => l10n.savedItemsArtistLabel,
      SavedItemType.institution => l10n.savedItemsInstitutionLabel,
      SavedItemType.group => l10n.savedItemsGroupLabel,
      SavedItemType.marker => l10n.savedItemsMarkerLabel,
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

    final roles = KubusColorRoles.of(context);
    return ColoredBox(
      color: roles.ground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: roles.ground,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: Border(
                  bottom: BorderSide(
                    color: roles.rule,
                    width: KubusSizes.hairline,
                  ),
                ),
                title: Text(
                  l10n.profileMenuSavedItemsTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: roles.foreground,
                      ),
                ),
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
              if (totalCount == 0) ...[
                _SavedLibraryHeader(
                  notion: l10n.savedItemsLibraryNotion,
                  subtitle: null,
                  countLabel: null,
                ),
                const SizedBox(height: KubusSpacing.md),
                // One useful empty state instead of nine empty sections.
                EmptyStateCard(
                  icon: Icons.bookmark_border,
                  title: l10n.savedItemsEmptyLibraryTitle,
                  description: l10n.savedItemsSummarySubtitleEmpty,
                  showAction: true,
                  actionLabel: l10n.homeIntroExploreMapAction,
                  onAction: _openDiscovery,
                ),
              ] else
                _SavedLibraryHeader(
                  notion: l10n.savedItemsLibraryNotion,
                  subtitle: lastSaved != null
                      ? l10n.savedItemsSummarySubtitleLastSaved(
                          _formatTimestamp(l10n, lastSaved),
                        )
                      : null,
                  countLabel: l10n.savedItemsSummaryCount(totalCount),
                ),
              if (totalCount > 0) const SizedBox(height: KubusSpacing.md),
              if (totalCount > 0)
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
              if (totalCount > 0)
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
              if (totalCount > 0)
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
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.exhibition),
                  ),
                  icon: AppColorUtils.exhibitionIcon,
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
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.communityPost),
                  ),
                  icon: Icons.forum_outlined,
                  accent: _accentForType(SavedItemType.communityPost),
                  expanded: _isExpanded(SavedItemType.communityPost),
                  onToggle: () => _toggleSection(SavedItemType.communityPost),
                  count: savedProvider.savedPostsCount,
                  child: _buildPostSection(
                    context: context,
                    l10n: l10n,
                    savedProvider: savedProvider,
                  ),
                ),
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.artist),
                  ),
                  icon: Icons.palette_outlined,
                  accent: _accentForType(SavedItemType.artist),
                  expanded: _isExpanded(SavedItemType.artist),
                  onToggle: () => _toggleSection(SavedItemType.artist),
                  count: savedProvider.savedArtistsCount,
                  child: _buildSnapshotSection(
                    context: context,
                    l10n: l10n,
                    savedProvider: savedProvider,
                    type: SavedItemType.artist,
                    records: savedProvider.savedArtistItems,
                    icon: Icons.palette_outlined,
                  ),
                ),
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.institution),
                  ),
                  icon: Icons.apartment_outlined,
                  accent: _accentForType(SavedItemType.institution),
                  expanded: _isExpanded(SavedItemType.institution),
                  onToggle: () => _toggleSection(SavedItemType.institution),
                  count: savedProvider.savedInstitutionsCount,
                  child: _buildSnapshotSection(
                    context: context,
                    l10n: l10n,
                    savedProvider: savedProvider,
                    type: SavedItemType.institution,
                    records: savedProvider.savedInstitutionItems,
                    icon: Icons.apartment_outlined,
                  ),
                ),
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.group),
                  ),
                  icon: Icons.groups_2_outlined,
                  accent: _accentForType(SavedItemType.group),
                  expanded: _isExpanded(SavedItemType.group),
                  onToggle: () => _toggleSection(SavedItemType.group),
                  count: savedProvider.savedGroupsCount,
                  child: _buildSnapshotSection(
                    context: context,
                    l10n: l10n,
                    savedProvider: savedProvider,
                    type: SavedItemType.group,
                    records: savedProvider.savedGroupItems,
                    icon: Icons.groups_2_outlined,
                  ),
                ),
              if (totalCount > 0)
                _SavedItemsSection(
                  title: l10n.savedItemsSectionTitle(
                    _localizedTypeLabel(l10n, SavedItemType.marker),
                  ),
                  icon: Icons.place_outlined,
                  accent: _accentForType(SavedItemType.marker),
                  expanded: _isExpanded(SavedItemType.marker),
                  onToggle: () => _toggleSection(SavedItemType.marker),
                  count: savedProvider.savedMarkersCount,
                  child: _buildSnapshotSection(
                    context: context,
                    l10n: l10n,
                    savedProvider: savedProvider,
                    type: SavedItemType.marker,
                    records: savedProvider.savedMarkerItems,
                    icon: Icons.place_outlined,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sends the viewer to the map, the most direct way to find something to
  /// save. Desktop uses the shell route; mobile switches the main tab.
  void _openDiscovery() {
    final shell = DesktopShellScope.of(context);
    if (shell != null) {
      shell.navigateToRoute('/explore');
      return;
    }
    try {
      context.read<MainTabProvider>().setIndex(0);
    } catch (_) {}
    Navigator.of(context).popUntil((route) => route.isFirst);
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

    final visibleRecords =
        records.take(_visibleLimit(SavedItemType.artwork)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _ArtworkSavedTile(
            l10n: l10n,
            record: record,
            artwork: artworkProvider.getArtworkById(record.id),
            accent: AppColorUtils.tealAccent,
            onTap: () => openArtwork(
              context,
              record.id,
              source: 'saved_items',
            ),
            onRemove: () => _confirmRemoveSavedItem(
              record: record,
            ),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: SavedItemType.artwork,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
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

    final visibleRecords =
        records.take(_visibleLimit(SavedItemType.event)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _EventSavedTile(
            l10n: l10n,
            record: record,
            event: eventsProvider.events
                .where((event) => event.id == record.id)
                .firstOrNull,
            accent: AppColorUtils.blueAccent,
            onTap: () {
              final event = eventsProvider.events
                  .where((event) => event.id == record.id)
                  .firstOrNull;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(
                    eventId: record.id,
                    initialEvent: event,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: record,
            ),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: SavedItemType.event,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
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

    final visibleRecords =
        records.take(_visibleLimit(SavedItemType.collection)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _CollectionSavedTile(
            l10n: l10n,
            record: record,
            collection: collectionsProvider.getCollectionById(record.id),
            accent: AppColorUtils.orangeAccent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(
                    collectionId: record.id,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: record,
            ),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: SavedItemType.collection,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
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
        icon: AppColorUtils.exhibitionIcon,
        accent: AppColorUtils.amberAccent,
      );
    }

    final visibleRecords =
        records.take(_visibleLimit(SavedItemType.exhibition)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _ExhibitionSavedTile(
            l10n: l10n,
            record: record,
            exhibition: exhibitionsProvider.exhibitions
                .where((exhibition) => exhibition.id == record.id)
                .firstOrNull,
            accent: AppColorUtils.amberAccent,
            onTap: () {
              final exhibition = exhibitionsProvider.exhibitions
                  .where((exhibition) => exhibition.id == record.id)
                  .firstOrNull;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExhibitionDetailScreen(
                    exhibitionId: record.id,
                    initialExhibition: exhibition,
                  ),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: record,
            ),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: SavedItemType.exhibition,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
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

    final visibleRecords =
        records.take(_visibleLimit(SavedItemType.communityPost)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _PostSavedTile(
            l10n: l10n,
            record: record,
            post: null,
            accent: AppColorUtils.cyanAccent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: record.id),
                ),
              );
            },
            onRemove: () => _confirmRemoveSavedItem(
              record: record,
            ),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: SavedItemType.communityPost,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
    );
  }

  Widget _buildSnapshotSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required SavedItemType type,
    required List<SavedItemRecord> records,
    required IconData icon,
  }) {
    final accent = _accentForType(type);
    if (records.isEmpty) {
      return _buildEmptySection(
        context: context,
        l10n: l10n,
        itemTypeLabel: _localizedTypeLabel(l10n, type),
        icon: icon,
        accent: accent,
      );
    }

    final visibleRecords = records.take(_visibleLimit(type)).toList();
    return _buildTileGrid(
      context: context,
      children: [
        for (final record in visibleRecords)
          _SnapshotSavedTile(
            l10n: l10n,
            record: record,
            accent: accent,
            icon: icon,
            typeLabel: _localizedTypeLabel(l10n, type),
            onTap: () => _openSnapshotRecord(record),
            onRemove: () => _confirmRemoveSavedItem(record: record),
          ),
      ],
      footer: _buildLoadMoreButton(
        l10n: l10n,
        savedProvider: savedProvider,
        type: type,
        totalVisible: visibleRecords.length,
        totalKnown: records.length,
      ),
    );
  }

  Widget _buildTileGrid({
    required BuildContext context,
    required List<Widget> children,
    Widget? footer,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 2;
        final spacing = KubusSpacing.md;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final child in children)
                  SizedBox(width: itemWidth, child: child),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: KubusSpacing.md),
              Align(alignment: Alignment.center, child: footer),
            ],
          ],
        );
      },
    );
  }

  Widget? _buildLoadMoreButton({
    required AppLocalizations l10n,
    required SavedItemsProvider savedProvider,
    required SavedItemType type,
    required int totalVisible,
    required int totalKnown,
  }) {
    if (totalVisible >= totalKnown && !savedProvider.hasMore(type)) {
      return null;
    }
    return KubusButton(
      onPressed:
          savedProvider.isSyncing ? null : () => _loadMore(savedProvider, type),
      icon: Icons.expand_more,
      label: l10n.savedItemsLoadMoreButton,
      variant: KubusButtonVariant.secondary,
    );
  }

  void _openSnapshotRecord(SavedItemRecord record) {
    if (record.type == SavedItemType.communityPost) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: record.id)),
      );
    }
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
      await savedProvider.removeItem(record.type, record.id);

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

/// Flat page header for the personal library: structural notion, a
/// machine-register count and the last-saved line. The app bar carries the
/// page title, so it is not repeated here. No card, tint or icon tile.
class _SavedLibraryHeader extends StatelessWidget {
  const _SavedLibraryHeader({
    required this.notion,
    required this.subtitle,
    required this.countLabel,
  });

  final String notion;
  final String? subtitle;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                notion.toUpperCase(),
                style: KubusTextStyles.structuralLabel.copyWith(
                  color: roles.foregroundMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (countLabel != null)
              Text(
                countLabel!,
                style: KubusTextStyles.machineValue.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: KubusSpacing.xs),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(color: roles.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

/// One entity group in the library: a flat disclosure row over a rule, then
/// its items. Empty groups are not rendered by the screen.
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

  /// Kept for call-site compatibility; groups no longer carry a colour.
  final Color accent;
  final bool expanded;
  final VoidCallback onToggle;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: roles.rule, width: KubusSizes.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              label: '$title, $count',
              onTap: onToggle,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onToggle,
                  focusColor: roles.focus.withValues(alpha: 0.16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: roles.foregroundMuted),
                        const SizedBox(width: KubusSpacing.sm + 4),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: roles.foreground,
                            ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: KubusTextStyles.machineValue.copyWith(
                            color: roles.foregroundMuted,
                          ),
                        ),
                        const SizedBox(width: KubusSpacing.xs),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0.0,
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: roles.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xs),
                child: child,
              ),
          ],
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
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < _kSavedTileCompactWidth;
              final thumbnailSize = isCompact
                  ? _kSavedTileCompactThumbnailSize
                  : _kSavedTileRegularThumbnailSize;

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
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: roles.foreground,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: compact ? 3 : 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: roles.foregroundMuted,
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
                  style: textTheme.labelSmall?.copyWith(
                    color: roles.foregroundSubtle,
                  ),
                );
              }

              Widget buildRemoveButton() {
                return IconButton(
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  color: roles.foregroundMuted,
                  onPressed: onRemove,
                  tooltip: l10n.commonRemove,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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
        icon: AppColorUtils.exhibitionIcon,
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
    final imageUrl =
        MediaUrlResolver.resolveDisplayUrl(post?.imageUrl ?? record.imageUrl);
    final title = (record.title ?? '').trim().isNotEmpty
        ? record.title!.trim()
        : post != null && post!.authorName.trim().isNotEmpty
            ? post!.authorName.trim()
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
    final snapshotSubtitle = (record.subtitle ?? '').trim();
    if (snapshotSubtitle.isNotEmpty) return snapshotSubtitle;
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

class _SnapshotSavedTile extends StatelessWidget {
  const _SnapshotSavedTile({
    required this.l10n,
    required this.record,
    required this.accent,
    required this.icon,
    required this.typeLabel,
    required this.onTap,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final SavedItemRecord record;
  final Color accent;
  final IconData icon;
  final String typeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = (record.title ?? '').trim().isNotEmpty
        ? record.title!.trim()
        : l10n.savedItemsPlaceholderTitle;
    final subtitle = (record.subtitle ?? '').trim().isNotEmpty
        ? record.subtitle!.trim()
        : typeLabel;
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(record.imageUrl);

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
        icon: icon,
        avatarLabel: title,
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
    final resolved = imageUrl?.trim();
    final hasImage = resolved != null && resolved.isNotEmpty;
    final image = resolved ?? '';
    final roles = KubusColorRoles.of(context);
    final boxDecoration = BoxDecoration(
      color: roles.ground,
      borderRadius: BorderRadius.circular(KubusRadius.surface),
      border: Border.all(color: roles.rule, width: KubusSizes.hairline),
    );

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        child: Image.network(
          image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(boxDecoration, roles),
        ),
      );
    }

    return _fallback(boxDecoration, roles);
  }

  Widget _fallback(BoxDecoration decoration, KubusColorRoles roles) {
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: avatarLabel != null && avatarLabel!.trim().isNotEmpty
          ? Center(
              child: Text(
                avatarLabel!.trim()[0].toUpperCase(),
                style: KubusTypography.content(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: roles.foregroundMuted,
                ),
              ),
            )
          : Icon(icon, size: 28, color: roles.foregroundMuted),
    );
  }
}

/// Compact truthful line for a group whose items are not available yet.
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
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: roles.foregroundSubtle),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: roles.foreground,
                  ),
                ),
                Text(
                  description,
                  style: textTheme.bodySmall
                      ?.copyWith(color: roles.foregroundMuted),
                ),
              ],
            ),
          ),
        ],
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
