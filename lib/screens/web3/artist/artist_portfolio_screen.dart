import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/widgets/glass_components.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/artwork.dart';
import '../../../models/promotion.dart';
import '../../../models/portfolio_entry.dart';
import '../../../providers/portfolio_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/artwork_edit_navigation.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/design_tokens.dart';
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

  const ArtistPortfolioScreen({
    super.key,
    required this.walletAddress,
    this.onCreateRequested,
  });

  @override
  State<ArtistPortfolioScreen> createState() => _ArtistPortfolioScreenState();
}

class _ArtistPortfolioScreenState extends State<ArtistPortfolioScreen> {
  PortfolioEntryType? _typeFilter;
  PortfolioPublishState? _statusFilter;
  final Set<String> _deleteDialogOpenArtworkIds = <String>{};
  final Set<String> _deleteInFlightArtworkIds = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<PortfolioProvider>().setWalletAddress(widget.walletAddress);
  }

  @override
  void didUpdateWidget(covariant ArtistPortfolioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletAddress.trim() == widget.walletAddress.trim()) return;
    context.read<PortfolioProvider>().setWalletAddress(widget.walletAddress);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final entries =
            provider.entries.where(_matchesFilters).toList(growable: false);

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              _buildHeader(
                title: l10n.artistGalleryTitle,
                countLabel:
                    l10n.artistGalleryArtworkCount(provider.entries.length),
                isBusy: provider.isLoading,
                error: provider.error,
              ),
              _buildFilterRow(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refresh(force: true),
                  child: entries.isEmpty
                      ? _buildEmptyState(l10n)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            KubusSpacing.md,
                            KubusSpacing.sm,
                            KubusSpacing.md,
                            KubusSpacing.lg,
                          ),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _buildEntryCard(
                                context, entry, provider, scheme, l10n);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesFilters(PortfolioEntry entry) {
    if (_typeFilter != null && entry.type != _typeFilter) return false;
    if (_statusFilter != null && entry.publishState != _statusFilter) {
      return false;
    }
    return true;
  }

  Widget _buildHeader({
    required String title,
    required String countLabel,
    required bool isBusy,
    required String? error,
  }) {
    final scheme = Theme.of(context).colorScheme;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KubusTextStyles.mobileAppBarTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      countLabel,
                      style: KubusTextStyles.screenSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onCreateRequested,
                icon: Icon(Icons.add, color: scheme.onSurface),
                tooltip: title,
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
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final l10n = AppLocalizations.of(context)!;

    String typeLabel(PortfolioEntryType? type) {
      if (type == null) return l10n.artistGalleryFilterAll;
      switch (type) {
        case PortfolioEntryType.artwork:
          return l10n.userProfileArtworksTitle;
        case PortfolioEntryType.collection:
          return l10n.userProfileCollectionsTitle;
        case PortfolioEntryType.exhibition:
          return l10n.artistStudioTabExhibitions;
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
            child: _DropdownFilter<PortfolioEntryType>(
              label: typeLabel(_typeFilter),
              value: _typeFilter,
              items: <_DropdownItem<PortfolioEntryType>>[
                _DropdownItem(value: null, label: l10n.artistGalleryFilterAll),
                _DropdownItem(
                    value: PortfolioEntryType.artwork,
                    label: l10n.userProfileArtworksTitle),
                _DropdownItem(
                    value: PortfolioEntryType.collection,
                    label: l10n.userProfileCollectionsTitle),
                _DropdownItem(
                    value: PortfolioEntryType.exhibition,
                    label: l10n.artistStudioTabExhibitions),
              ],
              onSelected: (value) => setState(() => _typeFilter = value),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: _DropdownFilter<PortfolioPublishState>(
              label: statusLabel(_statusFilter),
              value: _statusFilter,
              items: <_DropdownItem<PortfolioPublishState>>[
                _DropdownItem(value: null, label: l10n.artistGalleryFilterAll),
                _DropdownItem(
                    value: PortfolioPublishState.published,
                    label: l10n.artistGalleryFilterActive),
                _DropdownItem(
                    value: PortfolioPublishState.draft,
                    label: l10n.artistGalleryFilterDraft),
              ],
              onSelected: (value) => setState(() => _statusFilter = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.xl,
        KubusSpacing.md,
        KubusSpacing.lg,
      ),
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 64,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: KubusSpacing.md),
              Text(
                l10n.artistGalleryEmptyTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.artistGalleryEmptyDescription,
                textAlign: TextAlign.center,
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              ElevatedButton.icon(
                onPressed: widget.onCreateRequested,
                icon: const Icon(Icons.add),
                label: Text(l10n.artistGalleryCreateArtworkButton),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    PortfolioEntry entry,
    PortfolioProvider provider,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final artwork = entry.type == PortfolioEntryType.artwork
        ? provider.artworkById(entry.id)
        : null;
    final coverUrl = () {
      if (entry.type == PortfolioEntryType.artwork) {
        if (artwork != null) {
          return ArtworkMediaResolver.resolveCover(artwork: artwork) ??
              MediaUrlResolver.resolve(entry.coverUrl);
        }
      }
      return MediaUrlResolver.resolve(entry.coverUrl);
    }();

    final statusColor = entry.isPublished ? scheme.primary : scheme.tertiary;

    String typeLabel() {
      switch (entry.type) {
        case PortfolioEntryType.artwork:
          return l10n.userProfileArtworksTitle;
        case PortfolioEntryType.collection:
          return l10n.userProfileCollectionsTitle;
        case PortfolioEntryType.exhibition:
          return l10n.artistStudioTabExhibitions;
      }
    }

    String statusLabel() {
      return entry.isPublished
          ? l10n.artistGalleryFilterActive
          : l10n.artistGalleryFilterDraft;
    }

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        onTap: () => _openEntry(context, entry, provider),
        child: Container(
          padding: const EdgeInsets.all(KubusSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            border:
                Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverThumb(url: coverUrl),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: KubusTextStyles.sectionTitle.copyWith(
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm,
                            vertical: KubusSpacing.xxs + KubusSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(KubusRadius.xl),
                          ),
                          child: Text(
                            statusLabel(),
                            style: KubusTextStyles.compactBadge.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                    Row(
                      children: [
                        Text(
                          typeLabel(),
                          style: KubusTextStyles.sectionSubtitle.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (entry.subtitle != null &&
                            entry.subtitle!.trim().isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: KubusTextStyles.navMetaLabel.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.subtitle!.trim(),
                              style: KubusTextStyles.navMetaLabel.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.65),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
              IconButton(
                tooltip: l10n.commonMore,
                onPressed: () =>
                    _showEntryOptionsSheet(context, provider, entry),
                icon: Icon(
                  Icons.more_horiz,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(BuildContext context, PortfolioEntry entry,
      PortfolioProvider provider) async {
    switch (entry.type) {
      case PortfolioEntryType.artwork:
        await _showEntryOptionsSheet(context, provider, entry);
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

    await showSubjectOptionsSheet(
      context: context,
      title: entry.title,
      subtitle: entry.type == PortfolioEntryType.artwork
          ? l10n.userProfileArtworksTitle
          : (entry.type == PortfolioEntryType.collection
              ? l10n.userProfileCollectionsTitle
              : l10n.artistStudioTabExhibitions),
      actions: actions,
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

class _CoverThumb extends StatelessWidget {
  final String? url;

  const _CoverThumb({this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: Container(
        width: 56,
        height: 56,
        color: scheme.surfaceContainerHighest,
        child: (url != null && url!.isNotEmpty)
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            : Icon(
                Icons.image_outlined,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
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
