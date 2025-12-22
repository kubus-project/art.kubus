import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/artwork.dart';
import '../../../models/portfolio_entry.dart';
import '../../../providers/portfolio_provider.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/media_url_resolver.dart';
import '../../art/collection_detail_screen.dart';
import '../../events/exhibition_detail_screen.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<PortfolioProvider>().setWalletAddress(widget.walletAddress);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final entries = provider.entries.where(_matchesFilters).toList(growable: false);

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildHeader(
                title: l10n.artistGalleryTitle,
                countLabel: l10n.artistGalleryArtworkCount(provider.entries.length),
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _buildEntryCard(context, entry, provider, scheme, l10n);
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
    if (_statusFilter != null && entry.publishState != _statusFilter) return false;
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      countLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isBusy) ...[
            const SizedBox(height: 10),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _DropdownFilter<PortfolioEntryType>(
              label: typeLabel(_typeFilter),
              value: _typeFilter,
              items: <_DropdownItem<PortfolioEntryType>>[
                _DropdownItem(value: null, label: l10n.artistGalleryFilterAll),
                _DropdownItem(value: PortfolioEntryType.artwork, label: l10n.userProfileArtworksTitle),
                _DropdownItem(value: PortfolioEntryType.collection, label: l10n.userProfileCollectionsTitle),
                _DropdownItem(value: PortfolioEntryType.exhibition, label: l10n.artistStudioTabExhibitions),
              ],
              onSelected: (value) => setState(() => _typeFilter = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownFilter<PortfolioPublishState>(
              label: statusLabel(_statusFilter),
              value: _statusFilter,
              items: <_DropdownItem<PortfolioPublishState>>[
                _DropdownItem(value: null, label: l10n.artistGalleryFilterAll),
                _DropdownItem(value: PortfolioPublishState.published, label: l10n.artistGalleryFilterActive),
                _DropdownItem(value: PortfolioPublishState.draft, label: l10n.artistGalleryFilterDraft),
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
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 64,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.artistGalleryEmptyTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.artistGalleryEmptyDescription,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
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
    final coverUrl = () {
      if (entry.type == PortfolioEntryType.artwork) {
        final artwork = provider.artworkById(entry.id);
        if (artwork != null) {
          return ArtworkMediaResolver.resolveCover(artwork: artwork) ??
              MediaUrlResolver.resolve(entry.coverUrl);
        }
      }
      return MediaUrlResolver.resolve(entry.coverUrl);
    }();

    final statusColor = entry.isPublished
        ? scheme.primary
        : scheme.tertiary;

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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEntry(context, entry, provider),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverThumb(url: coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          typeLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (entry.subtitle != null && entry.subtitle!.trim().isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.subtitle!.trim(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
              const SizedBox(width: 6),
              _EntryMenu(entry: entry, onSelected: (action) => _handleAction(context, provider, entry, action)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(BuildContext context, PortfolioEntry entry, PortfolioProvider provider) async {
    switch (entry.type) {
      case PortfolioEntryType.artwork:
        final artwork = provider.artworkById(entry.id);
        if (artwork == null) return;
        await _showArtworkActionsSheet(context, provider, artwork);
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

    // Handle non-artwork edit first so we don't trip the async context lint.
    if (action == 'edit' && entry.type != PortfolioEntryType.artwork) {
      await _openEntry(context, entry, provider);
      return;
    }

    if (entry.type != PortfolioEntryType.artwork) return;

    final artwork = provider.artworkById(entry.id);
    if (artwork == null) return;

    switch (action) {
      case 'edit':
        await _showEditArtworkSheet(context, provider, artwork);
        return;
      case 'publish':
        await provider.publishArtwork(artwork.id);
        messenger.showSnackBar(SnackBar(content: Text(l10n.commonSavedToast)));
        return;
      case 'unpublish':
        await provider.unpublishArtwork(artwork.id);
        messenger.showSnackBar(SnackBar(content: Text(l10n.commonSavedToast)));
        return;
      case 'delete':
        final confirmed = await _confirmDeleteArtwork(context, artwork.title);
        if (confirmed != true) return;
        await provider.deleteArtwork(artwork.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.artistGalleryDeletedToast(artwork.title))),
        );
        return;
    }
  }

  Future<bool?> _confirmDeleteArtwork(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
    );
  }

  Future<void> _showArtworkActionsSheet(
    BuildContext context,
    PortfolioProvider provider,
    Artwork artwork,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final isPublished = artwork.isPublic;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.commonEdit),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showEditArtworkSheet(context, provider, artwork);
                },
              ),
              ListTile(
                leading: Icon(isPublished ? Icons.visibility_off : Icons.visibility),
                title: Text(isPublished ? l10n.exhibitionCreatorPublishDraft : l10n.exhibitionCreatorPublishTitle),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (isPublished) {
                    await provider.unpublishArtwork(artwork.id);
                  } else {
                    await provider.publishArtwork(artwork.id);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.commonDelete),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await _confirmDeleteArtwork(context, artwork.title);
                  if (confirmed == true) {
                    await provider.deleteArtwork(artwork.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditArtworkSheet(
    BuildContext context,
    PortfolioProvider provider,
    Artwork artwork,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController(text: artwork.title);
    final descriptionController = TextEditingController(text: artwork.description);
    final priceController = TextEditingController(text: artwork.price?.toString() ?? '');
    bool isForSale = artwork.isForSale;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final insets = MediaQuery.of(sheetContext).viewInsets.bottom;
        final scheme = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: EdgeInsets.only(bottom: insets),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.commonEdit,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: l10n.commonTitle),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(labelText: l10n.commonDescription),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: l10n.commonPrice),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.commonForSale),
                              value: isForSale,
                              onChanged: (value) => setLocalState(() => isForSale = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: Text(l10n.commonCancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final updates = <String, dynamic>{
                                  'title': titleController.text.trim(),
                                  'description': descriptionController.text.trim(),
                                  'isForSale': isForSale,
                                };
                                final priceRaw = priceController.text.trim();
                                final parsedPrice = double.tryParse(priceRaw);
                                if (priceRaw.isNotEmpty) {
                                  updates['price'] = parsedPrice;
                                }

                                try {
                                  await provider.updateArtwork(artwork.id, updates);
                                  if (!context.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  messenger.showSnackBar(SnackBar(content: Text(l10n.commonSavedToast)));
                                } catch (_) {
                                  if (!context.mounted) return;
                                  messenger.showSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
                                }
                              },
                              child: Text(l10n.commonSave),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}

class _CoverThumb extends StatelessWidget {
  final String? url;

  const _CoverThumb({this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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

class _EntryMenu extends StatelessWidget {
  final PortfolioEntry entry;
  final ValueChanged<String> onSelected;

  const _EntryMenu({required this.entry, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
        ];

        if (entry.type == PortfolioEntryType.artwork) {
          if (entry.isPublished) {
            items.add(PopupMenuItem(value: 'unpublish', child: Text(l10n.exhibitionCreatorPublishDraft)));
          } else {
            items.add(PopupMenuItem(value: 'publish', child: Text(l10n.exhibitionCreatorPublishTitle)));
          }
          items.add(PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)));
        }

        return items;
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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
