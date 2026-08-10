import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/web3/web3_capabilities.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_labs_feature.dart';
import '../../../utils/marketplace_value_formatter.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/common/kubus_cached_image.dart';
import '../../../widgets/common/kubus_labs_adornment.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/inline_loading.dart';
import '../desktop_shell.dart';

enum _EditionSort { newest, title, listedFirst, supply }

enum _EditionView { grid, list }

class DesktopMarketplaceScreen extends StatefulWidget {
  const DesktopMarketplaceScreen({super.key});

  @override
  State<DesktopMarketplaceScreen> createState() =>
      _DesktopMarketplaceScreenState();
}

class _DesktopMarketplaceScreenState extends State<DesktopMarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _listedOnly = false;
  bool _arOnly = false;
  bool _ownedOnly = false;
  _EditionSort _sort = _EditionSort.newest;
  _EditionView _view = _EditionView.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Web3Capabilities _capabilities({
    String? ownerAddress,
    bool isListed = false,
    bool listen = true,
  }) {
    final profile = listen
        ? context.watch<ProfileProvider>()
        : context.read<ProfileProvider>();
    final wallet = listen
        ? context.watch<WalletProvider>()
        : context.read<WalletProvider>();
    return Web3CapabilityResolver.resolve(
      Web3CapabilityContext.fromProviders(
        profileProvider: profile,
        walletProvider: wallet,
        entityOwnerAddress: ownerAddress,
        entityIsListed: isListed,
        acquisitionSupported: false,
        mintingSupported: false,
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _listedOnly = false;
      _arOnly = false;
      _ownedOnly = false;
      _sort = _EditionSort.newest;
    });
  }

  List<MarketplaceArtworkEntry> _visibleEntries(
    CollectiblesProvider provider,
    String walletAddress,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    final entries = provider.marketplaceEntries.where((entry) {
      if (_listedOnly && !entry.isListed) return false;
      if (_arOnly && !entry.requiresArInteraction) return false;
      if (_ownedOnly &&
          !entry.collectibles.any(
            (item) => WalletUtils.equals(item.ownerAddress, walletAddress),
          )) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      final searchable = <String>[
        entry.title,
        entry.artistName,
        entry.artwork.category,
        entry.artwork.description,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList(growable: false);

    final sorted = entries.toList();
    switch (_sort) {
      case _EditionSort.newest:
        sorted.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
      case _EditionSort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _EditionSort.listedFirst:
        sorted.sort((a, b) {
          final listed = (b.isListed ? 1 : 0).compareTo(a.isListed ? 1 : 0);
          return listed != 0
              ? listed
              : b.sortTimestamp.compareTo(a.sortTimestamp);
        });
      case _EditionSort.supply:
        sorted.sort((a, b) {
          final aRemaining = (a.totalSupply ?? 0) - (a.mintedCount ?? 0);
          final bRemaining = (b.totalSupply ?? 0) - (b.mintedCount ?? 0);
          return aRemaining.compareTo(bRemaining);
        });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final capabilities = _capabilities();
    final walletAddress =
        context.watch<WalletProvider>().currentWalletAddress ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.xl,
              KubusSpacing.lg,
              KubusSpacing.xl,
              KubusSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: KubusSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.navigationScreenMarketplace,
                            style: KubusTextStyles.screenTitle.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const KubusLabsAdornment.inlinePill(
                            feature: KubusLabsFeature.marketplace,
                            emphasized: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        l10n.marketplaceFeaturedCollectionsSubtitle,
                        style: KubusTextStyles.screenSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                if (capabilities.canCreateEdition)
                  FilledButton.icon(
                    onPressed: () => DesktopShellScope.of(context)
                        ?.navigateToRoute('/artist-studio'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.commonCreate),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final search = TextField(
                  key: const Key('desktop-editions-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        '${l10n.commonSearch} ${l10n.navigationScreenMarketplace}',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: l10n.commonClear,
                          ),
                  ),
                );
                final controls = _buildControls(l10n, capabilities);
                if (compact) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: KubusSpacing.sm),
                      Align(alignment: Alignment.centerLeft, child: controls),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: KubusSpacing.md),
                    controls,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          Expanded(
            child: Consumer<CollectiblesProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: InlineLoading());
                }
                if (provider.error != null) {
                  return Center(
                    child: EmptyStateCard(
                      icon: Icons.error_outline,
                      title: l10n.commonActionFailedToast,
                      description: provider.error!,
                    ),
                  );
                }

                final entries = _visibleEntries(provider, walletAddress);
                if (entries.isEmpty) {
                  return Center(
                    child: EmptyStateCard(
                      icon: Icons.collections_outlined,
                      title: l10n.commonNoResultsFound,
                      description: l10n.marketplaceNoMintedNftsDescription,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.xl,
                      ),
                      child: Text(
                        '${entries.length} ${l10n.navigationScreenMarketplace}',
                        style: KubusTextStyles.sectionSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    Expanded(
                      child: _view == _EditionView.grid
                          ? _buildGrid(entries)
                          : _buildList(entries),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    AppLocalizations l10n,
    Web3Capabilities capabilities,
  ) {
    return Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          key: const Key('desktop-editions-listed-filter'),
          selected: _listedOnly,
          onSelected: (value) => setState(() => _listedOnly = value),
          label: Text(l10n.commonForSale),
        ),
        FilterChip(
          key: const Key('desktop-editions-ar-filter'),
          selected: _arOnly,
          onSelected: (value) => setState(() => _arOnly = value),
          label: Text(l10n.marketplaceArBadgeLabel),
        ),
        if (capabilities.hasWalletIdentity)
          FilterChip(
            key: const Key('desktop-editions-owned-filter'),
            selected: _ownedOnly,
            onSelected: (value) => setState(() => _ownedOnly = value),
            label: Text(l10n.marketplaceOwnedLabel),
          ),
        TextButton(
          key: const Key('desktop-editions-reset'),
          onPressed: _resetFilters,
          child: Text(l10n.commonClear),
        ),
        DropdownButton<_EditionSort>(
          key: const Key('desktop-editions-sort'),
          value: _sort,
          onChanged: (value) {
            if (value != null) setState(() => _sort = value);
          },
          items: [
            DropdownMenuItem(
              value: _EditionSort.newest,
              child: Text(l10n.mapSortNewest),
            ),
            DropdownMenuItem(
              value: _EditionSort.title,
              child: Text(l10n.commonTitle),
            ),
            DropdownMenuItem(
              value: _EditionSort.listedFirst,
              child: Text(l10n.commonForSale),
            ),
            DropdownMenuItem(
              value: _EditionSort.supply,
              child: Text(l10n.marketplaceTotalSupplyLabel),
            ),
          ],
        ),
        SegmentedButton<_EditionView>(
          key: const Key('desktop-editions-view-toggle'),
          segments: [
            ButtonSegment(
              value: _EditionView.grid,
              icon: const Icon(Icons.grid_view),
              tooltip: l10n.commonView,
            ),
            ButtonSegment(
              value: _EditionView.list,
              icon: const Icon(Icons.view_list),
              tooltip: l10n.commonView,
            ),
          ],
          selected: <_EditionView>{_view},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() => _view = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildGrid(List<MarketplaceArtworkEntry> entries) {
    return GridView.builder(
      key: const Key('desktop-editions-grid'),
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.xl,
        0,
        KubusSpacing.xl,
        KubusSpacing.xl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 390,
        crossAxisSpacing: KubusSpacing.md,
        mainAxisSpacing: KubusSpacing.md,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _EditionCard(
        entry: entries[index],
        onOpen: () => _showDetails(entries[index]),
      ),
    );
  }

  Widget _buildList(List<MarketplaceArtworkEntry> entries) {
    return ListView.separated(
      key: const Key('desktop-editions-list'),
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.xl,
        0,
        KubusSpacing.xl,
        KubusSpacing.xl,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: KubusSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EditionListRow(
          entry: entry,
          onOpen: () => _showDetails(entry),
        );
      },
    );
  }

  Collectible? _ownedCollectible(MarketplaceArtworkEntry entry) {
    final wallet = context.read<WalletProvider>().currentWalletAddress ?? '';
    for (final item in entry.collectibles) {
      if (WalletUtils.equals(item.ownerAddress, wallet)) return item;
    }
    return null;
  }

  Future<void> _showDetails(MarketplaceArtworkEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final owned = _ownedCollectible(entry);
    final capabilities = _capabilities(
      ownerAddress: owned?.ownerAddress,
      isListed: owned?.isForSale ?? false,
      listen: false,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(KubusRadius.md),
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: KubusCachedImage(
                            imageUrl: entry.coverUrl,
                            semanticLabel: entry.title,
                          ),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: KubusTextStyles.screenTitle.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: KubusSpacing.xs),
                            ArtworkCreatorByline(artwork: entry.artwork),
                            const SizedBox(height: KubusSpacing.md),
                            _detailLine(
                              l10n.marketplaceTotalSupplyLabel,
                              entry.totalSupply?.toString() ??
                                  l10n.commonNotAvailableShort,
                            ),
                            _detailLine(
                              l10n.marketplaceMintedLabel,
                              entry.mintedCount?.toString() ??
                                  l10n.commonNotAvailableShort,
                            ),
                            _detailLine(
                              l10n.commonStatus,
                              entry.isListed
                                  ? l10n.commonForSale
                                  : l10n.marketplaceValueNotListedLabel,
                            ),
                            if (entry.requiresArInteraction)
                              _detailLine(
                                l10n.marketplaceArBadgeLabel,
                                l10n.commonEnabled,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (entry.artwork.description.trim().isNotEmpty) ...[
                    const SizedBox(height: KubusSpacing.lg),
                    Text(
                      entry.artwork.description,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                  const SizedBox(height: KubusSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.commonClose),
                      ),
                      if (owned != null && capabilities.canListEdition) ...[
                        const SizedBox(width: KubusSpacing.sm),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _listEdition(entry, owned);
                          },
                          child: Text(l10n.marketplaceListNftForSaleTitle),
                        ),
                      ],
                      if (owned != null && capabilities.canUnlistEdition) ...[
                        const SizedBox(width: KubusSpacing.sm),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _unlistEdition(owned);
                          },
                          child: Text(l10n.marketplaceRemoveFromSaleTitle),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          Text(value, style: KubusTextStyles.detailLabel),
        ],
      ),
    );
  }

  Future<void> _listEdition(
    MarketplaceArtworkEntry entry,
    Collectible collectible,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final priceController = TextEditingController();
    final price = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.marketplaceListNftForSaleTitle),
        content: TextField(
          controller: priceController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: l10n.marketplacePriceKub8Label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(priceController.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    priceController.dispose();
    if (price == null || price.isEmpty || !mounted) return;

    final wallet = context.read<WalletProvider>();
    final profile = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profile,
      walletProvider: wallet,
    );
    if (!mounted || !canProceed) return;

    try {
      final collectiblesProvider = context.read<CollectiblesProvider>();
      await collectiblesProvider.listCollectibleForSale(
        collectibleId: collectible.id,
        price: price,
      );
      collectiblesProvider.clearError();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.marketplaceListForSaleSuccessToast)),
      );
    } catch (_) {
      if (!mounted) return;
      context.read<CollectiblesProvider>().clearError();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.marketplaceListForSaleFailedToast)),
      );
    }
  }

  Future<void> _unlistEdition(Collectible collectible) async {
    final l10n = AppLocalizations.of(context)!;
    final wallet = context.read<WalletProvider>();
    final profile = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profile,
      walletProvider: wallet,
    );
    if (!mounted || !canProceed) return;

    try {
      final collectiblesProvider = context.read<CollectiblesProvider>();
      await collectiblesProvider.removeCollectibleFromSale(
        collectibleId: collectible.id,
      );
      collectiblesProvider.clearError();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.marketplaceRemoveFromSaleSuccessToast)),
      );
    } catch (_) {
      if (!mounted) return;
      context.read<CollectiblesProvider>().clearError();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.marketplaceRemoveFromSaleFailedToast)),
      );
    }
  }
}

class _EditionCard extends StatelessWidget {
  const _EditionCard({required this.entry, required this.onOpen});

  final MarketplaceArtworkEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.marketplaceOpenSeriesDetailsSemantic(entry.title),
      child: LiquidGlassCard(
        onTap: onOpen,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KubusRadius.md),
              ),
              child: SizedBox(
                height: 230,
                width: double.infinity,
                child: KubusCachedImage(
                  imageUrl: entry.coverUrl,
                  semanticLabel: entry.title,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    ArtworkCreatorByline(
                      artwork: entry.artwork,
                      linkToProfile: false,
                    ),
                    const Spacer(),
                    _EditionMetadata(entry: entry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditionListRow extends StatelessWidget {
  const _EditionListRow({required this.entry, required this.onOpen});

  final MarketplaceArtworkEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.marketplaceOpenSeriesDetailsSemantic(entry.title),
      child: LiquidGlassCard(
        onTap: onOpen,
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              child: SizedBox(
                width: 104,
                height: 104,
                child: KubusCachedImage(
                  imageUrl: entry.coverUrl,
                  semanticLabel: entry.title,
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: KubusTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  ArtworkCreatorByline(
                    artwork: entry.artwork,
                    linkToProfile: false,
                  ),
                ],
              ),
            ),
            _EditionMetadata(entry: entry),
            const SizedBox(width: KubusSpacing.md),
            Icon(Icons.chevron_right, color: scheme.onSurface),
          ],
        ),
      ),
    );
  }
}

class _EditionMetadata extends StatelessWidget {
  const _EditionMetadata({required this.entry});

  final MarketplaceArtworkEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final value = MarketplaceValueFormatter.formatDisplayValue(
      entry.displayValue,
      fallback: l10n.marketplaceValueNotListedLabel,
    );
    return Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (entry.isListed)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(l10n.commonForSale),
          ),
        if (entry.requiresArInteraction)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(l10n.marketplaceArBadgeLabel),
          ),
        Text(
          value,
          style: KubusTextStyles.detailLabel.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }
}
