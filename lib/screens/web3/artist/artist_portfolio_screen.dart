import 'dart:async';
import 'package:flutter/material.dart';
import '../../../widgets/inline_loading.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/widgets/glass_components.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/artwork.dart';
import '../../../models/promotion.dart';
import '../../../models/portfolio_entry.dart';
import '../../../providers/portfolio_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../screens/desktop/desktop_shell.dart';
import '../../../services/share/share_deep_link_parser.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/artwork_navigation.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/artwork_edit_navigation.dart';
import '../../../utils/share_deep_link_navigation.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/kubus_entity_semantics.dart';
import '../../../widgets/common/kubus_entity_card.dart';
import '../../../widgets/kubus_button.dart';
import '../../../widgets/kubus_card.dart';
import '../../art/collection_detail_screen.dart';
import '../../events/exhibition_detail_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../../widgets/common/subject_options_sheet.dart';
import '../../../widgets/promotion/promotion_builder_sheet.dart';

bool _artworkCanBePromoted(Artwork artwork) =>
    artwork.isPublic && artwork.isActive;

class ArtistPortfolioScreen extends StatefulWidget {
  final String walletAddress;
  final VoidCallback? onCreateRequested;

  /// Opens a studio card. Defaults to the artwork detail, the marker detail,
  /// or the collection or exhibition detail. Tests inject a spy here.
  final Future<void> Function(BuildContext context, PortfolioEntry entry)?
      onOpenEntry;

  const ArtistPortfolioScreen({
    super.key,
    required this.walletAddress,
    this.onCreateRequested,
    this.onOpenEntry,
  });

  @override
  State<ArtistPortfolioScreen> createState() => _ArtistPortfolioScreenState();
}

class _ArtistPortfolioScreenState extends State<ArtistPortfolioScreen> {
  final Set<String> _deleteDialogOpenArtworkIds = <String>{};
  final Set<String> _deleteInFlightArtworkIds = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWallet();
  }

  @override
  void didUpdateWidget(covariant ArtistPortfolioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletAddress.trim() == widget.walletAddress.trim()) return;
    _syncWallet();
  }

  /// Hands the wallet to the provider after the current build. The provider
  /// notifies synchronously when the wallet changes, and a notification during
  /// build would mark the studio dirty while it is being built.
  void _syncWallet() {
    final wallet = widget.walletAddress;
    Future.microtask(() {
      if (!mounted) return;
      context.read<PortfolioProvider>().setWalletAddress(wallet);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final section = provider.section;
        final status = provider.statusFor(section);
        final entries = provider
            .entriesFor(section)
            .where((entry) => _matchesFilters(provider, section, entry))
            .toList(growable: false);

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              _buildHeader(
                title: l10n.artistGalleryTitle,
                isBusy: provider.isLoading,
                error: provider.error,
              ),
              _buildSectionChips(l10n, provider),
              _buildFilterRow(l10n, provider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refresh(force: true),
                  child: _buildSectionBody(
                    context,
                    l10n,
                    provider,
                    section,
                    status,
                    entries,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The status filter applies to every section. The type filter belongs to
  /// the collections section only, so an artwork section is never emptied by a
  /// type chosen elsewhere.
  bool _matchesFilters(
    PortfolioProvider provider,
    PortfolioStudioSection section,
    PortfolioEntry entry,
  ) {
    final statusFilter = provider.statusFilter;
    if (statusFilter != null && entry.publishState != statusFilter) {
      return false;
    }
    final typeFilter = provider.typeFilter;
    if (section == PortfolioStudioSection.collectionsAndExhibitions &&
        typeFilter != null &&
        entry.type != typeFilter) {
      return false;
    }
    return true;
  }

  Widget _buildHeader({
    required String title,
    required bool isBusy,
    required String? error,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: KubusTextStyles.mobileAppBarTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: widget.onCreateRequested,
                icon: Icon(Icons.add, color: scheme.onSurface),
                tooltip: l10n.artistGalleryCreateArtworkButton,
              ),
            ],
          ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              error,
              style:
                  KubusTextStyles.sectionSubtitle.copyWith(color: scheme.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isBusy) ...[
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            InlineLoading(height: 3, borderRadius: BorderRadius.circular(2)),
          ],
        ],
      ),
    );
  }

  /// The three studio sections. Each chip carries the section's own total so
  /// the count shown is the backend's count for that scope.
  Widget _buildSectionChips(AppLocalizations l10n, PortfolioProvider provider) {
    final entries = <({PortfolioStudioSection section, String label})>[
      (
        section: PortfolioStudioSection.authoredArtworks,
        label: l10n.artistPortfolioSectionAuthored,
      ),
      (
        section: PortfolioStudioSection.publicArt,
        label: l10n.artistPortfolioSectionPublicArt,
      ),
      (
        section: PortfolioStudioSection.collectionsAndExhibitions,
        label: l10n.artistPortfolioSectionCollections,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.none,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: Wrap(
        spacing: KubusSpacing.sm,
        runSpacing: KubusSpacing.xs,
        children: [
          for (final item in entries)
            _buildSectionChip(l10n, provider, item.section, item.label),
        ],
      ),
    );
  }

  Widget _buildSectionChip(
    AppLocalizations l10n,
    PortfolioProvider provider,
    PortfolioStudioSection section,
    String label,
  ) {
    final total = provider.statusFor(section).total;
    final text = total == null
        ? label
        : l10n.artistPortfolioSectionLabelWithCount(label, total);
    return ChoiceChip(
      label: Text(text),
      selected: provider.section == section,
      onSelected: (_) => provider.setSection(section),
    );
  }

  Widget _buildFilterRow(AppLocalizations l10n, PortfolioProvider provider) {
    final section = provider.section;
    final statusFilter = provider.statusFilter;
    final typeFilter = provider.typeFilter;

    String typeLabel(PortfolioEntryType? type) {
      if (type == null) return l10n.artistGalleryFilterAll;
      switch (type) {
        case PortfolioEntryType.collection:
          return l10n.userProfileCollectionsTitle;
        case PortfolioEntryType.exhibition:
          return l10n.artistStudioTabExhibitions;
        case PortfolioEntryType.artwork:
        case PortfolioEntryType.publicArtMarker:
          return l10n.artistGalleryFilterAll;
      }
    }

    String statusLabel(PortfolioPublishState? status) {
      if (status == null) return l10n.artistGalleryFilterAll;
      switch (status) {
        case PortfolioPublishState.draft:
          return l10n.artistGalleryFilterDraft;
        case PortfolioPublishState.published:
          return l10n.artistGalleryFilterActive;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.none,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _DropdownFilter<PortfolioPublishState>(
              label: statusLabel(statusFilter),
              value: statusFilter,
              items: <_DropdownItem<PortfolioPublishState>>[
                _DropdownItem(value: null, label: l10n.artistGalleryFilterAll),
                _DropdownItem(
                    value: PortfolioPublishState.published,
                    label: l10n.artistGalleryFilterActive),
                _DropdownItem(
                    value: PortfolioPublishState.draft,
                    label: l10n.artistGalleryFilterDraft),
              ],
              onSelected: provider.setStatusFilter,
            ),
          ),
          if (section == PortfolioStudioSection.collectionsAndExhibitions) ...[
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: _DropdownFilter<PortfolioEntryType>(
                label: typeLabel(typeFilter),
                value: typeFilter,
                items: <_DropdownItem<PortfolioEntryType>>[
                  _DropdownItem(
                      value: null, label: l10n.artistGalleryFilterAll),
                  _DropdownItem(
                      value: PortfolioEntryType.collection,
                      label: l10n.userProfileCollectionsTitle),
                  _DropdownItem(
                      value: PortfolioEntryType.exhibition,
                      label: l10n.artistStudioTabExhibitions),
                ],
                onSelected: provider.setTypeFilter,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One section's body. Each section owns its own notices, loading, empty and
  /// error states; an unsupported scope is an explicit notice, never a list.
  Widget _buildSectionBody(
    BuildContext context,
    AppLocalizations l10n,
    PortfolioProvider provider,
    PortfolioStudioSection section,
    PortfolioSectionStatus status,
    List<PortfolioEntry> entries,
  ) {
    final unsupported = status.loaded &&
        !status.honoured &&
        section != PortfolioStudioSection.collectionsAndExhibitions;
    final initialLoading = status.isLoading && !status.loaded;
    // An empty state is only true once the section has actually loaded; before
    // the first page arrives (including the frame after a wallet switch) the
    // section shows nothing rather than a misleading "no artworks yet".
    final showEmpty = entries.isEmpty &&
        status.loaded &&
        !initialLoading &&
        !unsupported &&
        status.error == null;

    final notices = <Widget>[
      if (unsupported)
        _buildNotice(
          context,
          message: section == PortfolioStudioSection.authoredArtworks
              ? l10n.artistPortfolioAuthoredUnsupported
              : l10n.artistPortfolioPublicArtUnsupported,
        ),
      if (status.error != null)
        _buildNotice(
          context,
          message: l10n.artistPortfolioSectionLoadFailed,
          action: KubusButton(
            onPressed: () => unawaited(provider.refresh(force: true)),
            label: l10n.commonRetry,
            icon: Icons.refresh,
            variant: KubusButtonVariant.secondary,
          ),
        ),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (notices.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: notices,
            ),
          ),
        if (entries.isNotEmpty)
          _buildGallery(context, entries, provider, section, l10n),
        if (entries.isNotEmpty && status.hasMore)
          SliverToBoxAdapter(
            child: _buildLoadMore(l10n, provider, section, status),
          ),
        if (showEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(l10n, section),
          ),
      ],
    );
  }

  Widget _buildNotice(
    BuildContext context, {
    required String message,
    Widget? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.none,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: KubusCard(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: KubusSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore(
    AppLocalizations l10n,
    PortfolioProvider provider,
    PortfolioStudioSection section,
    PortfolioSectionStatus status,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.none,
        KubusSpacing.md,
        KubusSpacing.lg,
      ),
      child: Center(
        child: KubusButton(
          onPressed: status.isLoadingMore
              ? null
              : () => unawaited(provider.loadMore(section)),
          label: l10n.artistPortfolioLoadMore,
          icon: Icons.expand_more,
          isLoading: status.isLoadingMore,
          variant: KubusButtonVariant.secondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      AppLocalizations l10n, PortfolioStudioSection section) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, description, showCreate) = switch (section) {
      PortfolioStudioSection.authoredArtworks => (
          Icons.collections_bookmark_outlined,
          l10n.artistGalleryEmptyTitle,
          l10n.artistGalleryEmptyDescription,
          true,
        ),
      PortfolioStudioSection.publicArt => (
          Icons.place_outlined,
          l10n.artistPortfolioPublicArtEmptyTitle,
          l10n.artistPortfolioPublicArtEmptyDescription,
          false,
        ),
      PortfolioStudioSection.collectionsAndExhibitions => (
          Icons.collections_outlined,
          l10n.artistPortfolioCollectionsEmptyTitle,
          l10n.artistPortfolioCollectionsEmptyDescription,
          false,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.xl,
        KubusSpacing.md,
        KubusSpacing.lg,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (showCreate) ...[
              const SizedBox(height: KubusSpacing.lg),
              ElevatedButton.icon(
                onPressed: widget.onCreateRequested,
                icon: const Icon(Icons.add),
                label: Text(l10n.artistGalleryCreateArtworkButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The workspace's dominant surface: an image-led adaptive grid.
  ///
  /// The column count comes from the available width against a target card
  /// width, so a wide window gets more columns at a consistent rhythm instead
  /// of one narrow list stranded in the middle of it, and cards never stretch
  /// to fill the screen. Below [_galleryGridMinWidth] it stays a one-column
  /// list of banner cards, so a phone gets an image-led list rather than a
  /// grid of postage stamps.
  Widget _buildGallery(
    BuildContext context,
    List<PortfolioEntry> entries,
    PortfolioProvider provider,
    PortfolioStudioSection section,
    AppLocalizations l10n,
  ) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const padding = KubusSpacing.md;
        const gap = KubusSpacing.md;
        final available = constraints.crossAxisExtent - (padding * 2);
        final columns = available < _galleryGridMinWidth
            ? 1
            : (available / _galleryTargetCardWidth).floor().clamp(1, 5);
        final cardWidth = (available - (gap * (columns - 1))) / columns;

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            padding,
            KubusSpacing.sm,
            padding,
            KubusSpacing.sm,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              // One column is a wide banner card; several are portrait-ish
              // previews. The media stays the subject either way.
              mainAxisExtent: columns == 1
                  ? _galleryListCardHeight
                  : cardWidth * _galleryCardAspect,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => _buildEntryCard(
              context,
              entries[index],
              provider,
              section,
              l10n,
            ),
          ),
        );
      },
    );
  }

  /// Below this the gallery is a one-column list of banner cards.
  static const double _galleryGridMinWidth = 560;

  /// Target card width the column count is derived from.
  static const double _galleryTargetCardWidth = 300;

  /// Height of a single-column banner card.
  static const double _galleryListCardHeight = 148;

  /// Grid card height as a ratio of its width.
  static const double _galleryCardAspect = 1.12;

  String _artistLine(AppLocalizations l10n, String? artistName) {
    final name = artistName?.trim();
    if (name == null || name.isEmpty) return l10n.commonUnknownArtist;
    return l10n.artistPortfolioArtistLine(name);
  }

  /// One studio card: the shared [KubusEntityCard] with the publication state
  /// (always visible, because it is information) and, only where the owner
  /// manages the record, one rectangular actions control over the media's
  /// top-right corner. Documented public art carries no management control.
  Widget _buildEntryCard(
    BuildContext context,
    PortfolioEntry entry,
    PortfolioProvider provider,
    PortfolioStudioSection section,
    AppLocalizations l10n,
  ) {
    final roles = KubusColorRoles.of(context);
    final artwork = entry.type == PortfolioEntryType.artwork
        ? provider.artworkById(entry.id)
        : null;
    final coverUrl = artwork != null
        ? (ArtworkMediaResolver.resolveCover(artwork: artwork) ??
            MediaUrlResolver.resolve(entry.coverUrl))
        : MediaUrlResolver.resolve(entry.coverUrl);

    final kind = switch (entry.type) {
      PortfolioEntryType.artwork ||
      PortfolioEntryType.publicArtMarker =>
        KubusEntityKind.artwork,
      PortfolioEntryType.collection => KubusEntityKind.collection,
      PortfolioEntryType.exhibition => KubusEntityKind.exhibition,
    };
    final (primaryLine, secondaryLine) = switch (entry.type) {
      PortfolioEntryType.artwork || PortfolioEntryType.publicArtMarker => (
          _artistLine(l10n, entry.artistName),
          section == PortfolioStudioSection.publicArt
              ? l10n.artistPortfolioAddedByYou
              : _nonEmpty(entry.subtitle),
        ),
      PortfolioEntryType.collection => (
          l10n.userProfileCollectionsTitle,
          _nonEmpty(entry.subtitle),
        ),
      PortfolioEntryType.exhibition => (
          l10n.artistStudioTabExhibitions,
          _nonEmpty(entry.subtitle),
        ),
    };

    final title = entry.title.isEmpty ? l10n.commonArtwork : entry.title;
    final actions = <Widget>[];
    if (entry.type == PortfolioEntryType.artwork) {
      // Only a record the owner's full data confirms gets management actions.
      if (section == PortfolioStudioSection.authoredArtworks &&
          artwork != null) {
        actions.add(_actionsButton(l10n, title, () {
          unawaited(_showEntryOptionsSheet(context, provider, entry));
        }));
      }
    } else if (entry.type == PortfolioEntryType.collection ||
        entry.type == PortfolioEntryType.exhibition) {
      actions.add(_actionsButton(l10n, title, () {
        unawaited(_showEntryOptionsSheet(context, provider, entry));
      }));
    }

    return KubusEntityCard(
      variant: KubusEntityCardVariant.media,
      kind: kind,
      imageUrl: coverUrl,
      title: title,
      subtitle: primaryLine,
      meta: secondaryLine,
      onTap: () => _activate(context, entry, provider),
      status: entry.publishState == null
          ? null
          : _PublicationStateChip(
              label: entry.isPublished
                  ? l10n.artistGalleryFilterActive
                  : l10n.artistGalleryFilterDraft,
              tone: entry.isPublished
                  ? roles.positiveAction
                  : roles.warningAction,
            ),
      actions: actions,
      alwaysShowActions: true,
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Widget _actionsButton(
    AppLocalizations l10n,
    String title,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: l10n.artistPortfolioCardActionsLabel(title),
      child: KubusButton(
        onPressed: onPressed,
        label: l10n.commonActions,
        icon: Icons.more_horiz,
        variant: KubusButtonVariant.secondary,
      ),
    );
  }

  void _activate(
    BuildContext context,
    PortfolioEntry entry,
    PortfolioProvider provider,
  ) {
    final seam = widget.onOpenEntry;
    if (seam != null) {
      unawaited(seam(context, entry));
      return;
    }
    unawaited(_openEntry(context, entry, provider));
  }

  Future<void> _openEntry(BuildContext context, PortfolioEntry entry,
      PortfolioProvider provider) async {
    switch (entry.type) {
      case PortfolioEntryType.artwork:
        await openArtwork(context, entry.id);
        return;
      case PortfolioEntryType.publicArtMarker:
        await ShareDeepLinkNavigation.open(
          context,
          ShareDeepLinkTarget(type: ShareEntityType.marker, id: entry.id),
          ensureShell: true,
        );
        return;
      case PortfolioEntryType.collection:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailScreen(collectionId: entry.id),
          ),
        );
        return;
      case PortfolioEntryType.exhibition:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExhibitionDetailScreen(exhibitionId: entry.id),
          ),
        );
        return;
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    PortfolioProvider provider,
    PortfolioEntry entry,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // Handle non-artwork open action first so we don't trip the async context lint.
    if (action == 'open' && entry.type != PortfolioEntryType.artwork) {
      await _openEntry(context, entry, provider);
      return;
    }

    if (entry.type != PortfolioEntryType.artwork) return;

    final artwork = provider.artworkById(entry.id);
    if (artwork == null) return;

    switch (action) {
      case 'edit':
        await openArtworkEditor(context, artwork.id,
            source: 'artist_portfolio');
        return;
      case 'publish':
        await _runPublishActionWithGuard(
          context: context,
          provider: provider,
          artworkId: artwork.id,
          publish: true,
        );
        return;
      case 'unpublish':
        await _runPublishActionWithGuard(
          context: context,
          provider: provider,
          artworkId: artwork.id,
          publish: false,
        );
        return;
      case 'delete':
        if (_deleteDialogOpenArtworkIds.contains(artwork.id) ||
            _deleteInFlightArtworkIds.contains(artwork.id)) {
          return;
        }
        final confirmed =
            await _confirmDeleteArtwork(context, artwork.id, artwork.title);
        if (confirmed != true) return;
        if (!mounted) return;
        if (_deleteInFlightArtworkIds.contains(artwork.id)) return;
        _deleteInFlightArtworkIds.add(artwork.id);
        try {
          await provider.deleteArtwork(artwork.id);
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(
                content: Text(l10n.artistGalleryDeletedToast(artwork.title))),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast)),
          );
        } finally {
          _deleteInFlightArtworkIds.remove(artwork.id);
        }
        return;
      case 'promote':
        if (!_artworkCanBePromoted(artwork)) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.artistGalleryPromoteUnavailableToast)),
          );
          return;
        }
        await showPromotionBuilderSheet(
          context: context,
          entityType: PromotionEntityType.artwork,
          entityId: artwork.id,
          entityLabel: artwork.title,
        );
        return;
    }
  }

  Future<void> _showEntryOptionsSheet(
    BuildContext context,
    PortfolioProvider provider,
    PortfolioEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final artwork = entry.type == PortfolioEntryType.artwork
        ? provider.artworkById(entry.id)
        : null;

    final actions = <SubjectOptionsAction>[];
    if (entry.type == PortfolioEntryType.artwork) {
      if (artwork == null) return;
      final isPublished = artwork.isPublic;
      actions.addAll([
        SubjectOptionsAction(
          id: 'edit',
          icon: Icons.edit_outlined,
          label: l10n.commonEdit,
          onSelected: () => _handleAction(context, provider, entry, 'edit'),
        ),
        SubjectOptionsAction(
          id: isPublished ? 'unpublish' : 'publish',
          icon: isPublished
              ? Icons.visibility_off_outlined
              : Icons.publish_outlined,
          label: isPublished ? l10n.commonUnpublish : l10n.commonPublish,
          onSelected: () => _handleAction(
            context,
            provider,
            entry,
            isPublished ? 'unpublish' : 'publish',
          ),
        ),
        if (_artworkCanBePromoted(artwork))
          SubjectOptionsAction(
            id: 'promote',
            icon: Icons.campaign_outlined,
            label: l10n.eventDetailPromoteLabel,
            onSelected: () =>
                _handleAction(context, provider, entry, 'promote'),
          ),
        SubjectOptionsAction(
          id: 'delete',
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          isDestructive: true,
          onSelected: () => _handleAction(context, provider, entry, 'delete'),
        ),
      ]);
    } else {
      actions.add(
        SubjectOptionsAction(
          id: 'open',
          icon: Icons.visibility_outlined,
          label: l10n.commonViewDetails,
          onSelected: () => _handleAction(context, provider, entry, 'open'),
        ),
      );
    }

    // Desktop gets a centered management dialog; the phone keeps the bottom
    // sheet unchanged.
    final presentation = DesktopBreakpoints.isDesktop(context)
        ? SubjectOptionsPresentation.centeredDialog
        : SubjectOptionsPresentation.adaptive;

    await showSubjectOptionsSheet(
      context: context,
      title: entry.title,
      subtitle: entry.type == PortfolioEntryType.artwork
          ? l10n.userProfileArtworksTitle
          : (entry.type == PortfolioEntryType.collection
              ? l10n.userProfileCollectionsTitle
              : l10n.artistStudioTabExhibitions),
      actions: actions,
      presentation: presentation,
    );
  }

  Future<bool?> _confirmDeleteArtwork(
    BuildContext context,
    String artworkId,
    String title,
  ) {
    final l10n = AppLocalizations.of(context)!;
    _deleteDialogOpenArtworkIds.add(artworkId);
    return showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return KubusAlertDialog(
          size: KubusDialogSize.compact,
          title: Text(l10n.artistGalleryDeleteArtworkTitle),
          content: Text(l10n.artistGalleryDeleteConfirmBody(title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _deleteDialogOpenArtworkIds.remove(artworkId);
    });
  }

  Future<void> _runPublishActionWithGuard({
    required BuildContext context,
    required PortfolioProvider provider,
    required String artworkId,
    required bool publish,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final savedToastMessage = AppLocalizations.of(context)!.commonSavedToast;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    if (!mounted || !canProceed) {
      return;
    }

    if (publish) {
      await provider.publishArtwork(artworkId);
    } else {
      await provider.unpublishArtwork(artworkId);
    }

    if (!mounted) return;
    messenger.showKubusSnackBar(
      SnackBar(content: Text(savedToastMessage)),
    );
  }
}

/// The publication state over a gallery card's media.
///
/// State is information, so it is always visible; a small tinted pill rather
/// than a block of colour, so it never competes with the artwork.
class _PublicationStateChip extends StatelessWidget {
  const _PublicationStateChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(KubusRadius.xs),
      ),
      child: Text(
        label.toUpperCase(),
        style: KubusTextStyles.compactBadge.copyWith(color: Colors.white),
      ),
    );
  }
}

class _DropdownItem<T> {
  final T? value;
  final String label;

  const _DropdownItem({required this.value, required this.label});
}

class _DropdownFilter<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?> onSelected;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md - KubusSpacing.xxs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          isExpanded: true,
          value: value,
          hint: Text(label, overflow: TextOverflow.ellipsis),
          items: items
              .map(
                (e) => DropdownMenuItem<T?>(
                  value: e.value,
                  child: Text(e.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: onSelected,
        ),
      ),
    );
  }
}
