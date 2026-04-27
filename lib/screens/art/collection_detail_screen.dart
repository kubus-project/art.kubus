import 'dart:async';
import 'package:art_kubus/widgets/glass_components.dart';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/collection_record.dart';
import '../../providers/collections_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/creator/creator_kit.dart';
import '../../widgets/common/subject_options_sheet.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../config/config.dart';
import '../../utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final bool embedded;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.embedded = false,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  Future<void> _load({bool force = false}) async {
    final provider = context.read<CollectionsProvider>();
    try {
      await provider.fetchCollection(widget.collectionId, force: force);
    } catch (_) {
      // Provider handles error state.
    }
  }

  void _reload() {
    unawaited(_load(force: true));
  }

  Widget _buildEmbeddedHeader({
    required CollectionRecord collection,
    required String name,
    required String? thumbnailUrl,
    required bool canEdit,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DetailSpacing.lg,
        DetailSpacing.lg,
        DetailSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.commonActions,
                onPressed: () => _showCollectionOptions(collection, canEdit),
                icon: const Icon(Icons.more_horiz),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(DetailRadius.md),
            child: SizedBox(
              height: 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.secondary.withValues(alpha: 0.18),
                    ],
                  ),
                ),
                child: thumbnailUrl == null
                    ? Center(
                        child: Icon(
                          Icons.collections,
                          size: 72,
                          color: scheme.onSurface.withValues(alpha: 0.35),
                        ),
                      )
                    : Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 56,
                            color: scheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(CollectionRecord collection) async {
    await CreatorShellNavigation.openCollectionSettingsWorkspace(
      context,
      collectionId: collection.id,
      collectionIndex: -1,
      collectionName: collection.name,
    );
  }

  Future<void> _showCollectionOptions(
    CollectionRecord collection,
    bool canEdit,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showSubjectOptionsSheet(
      context: context,
      title: collection.name,
      subtitle: l10n.collectionSettingsTitle,
      actions: [
        if (canEdit)
          SubjectOptionsAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: l10n.commonEdit,
            onSelected: () => _openEditor(collection),
          ),
        SubjectOptionsAction(
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onSelected: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.collection(
                collectionId: collection.id,
                title: collection.name,
              ),
              sourceScreen: 'collection_detail',
            );
          },
        ),
        if (canEdit)
          SubjectOptionsAction(
            id: 'delete',
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            isDestructive: true,
            onSelected: () => _deleteCollection(collection),
          ),
      ],
    );
  }

  Future<void> _deleteCollection(CollectionRecord collection) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final collectionsProvider = context.read<CollectionsProvider>();
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text(l10n.collectionSettingsDeleteDialogTitle),
        content: Text(
          l10n.collectionSettingsDeleteDialogContent(collection.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await collectionsProvider.deleteCollection(collection.id);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionSettingsDeletedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Consumer2<CollectionsProvider, WalletProvider>(
        builder: (context, collectionsProvider, walletProvider, _) {
          final collection =
              collectionsProvider.getCollectionById(widget.collectionId);
          final isLoading = collectionsProvider.isLoading(widget.collectionId);
          final error = collectionsProvider.errorFor(widget.collectionId);

          if (collection == null && isLoading) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          }

          if (collection == null && (error ?? '').isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DetailSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 34),
                    const SizedBox(height: DetailSpacing.md),
                    Text(
                      l10n.collectionDetailLoadFailedMessage,
                      textAlign: TextAlign.center,
                      style: KubusTypography.inter(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: DetailSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          final resolved = collection ??
              CollectionRecord(
                id: widget.collectionId,
                walletAddress: '',
                name: l10n.userProfileCollectionFallbackTitle,
                description: '',
                isPublic: true,
                artworkCount: 0,
              );

          final name = resolved.name.isNotEmpty
              ? resolved.name
              : l10n.userProfileCollectionFallbackTitle;
          final description = (resolved.description ?? '').trim();
          final thumbnailUrl = MediaUrlResolver.resolve(resolved.thumbnailUrl);
          final artworks = resolved.artworks;

          final walletAddress = walletProvider.currentWalletAddress;
          final canEdit = walletAddress != null &&
              walletAddress.isNotEmpty &&
              WalletUtils.equals(walletAddress, resolved.walletAddress);

          final slivers = <Widget>[
            if (widget.embedded)
              SliverToBoxAdapter(
                child: _buildEmbeddedHeader(
                  collection: resolved,
                  name: name,
                  thumbnailUrl: thumbnailUrl,
                  canEdit: canEdit,
                ),
              )
            else
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: scheme.surface,
                elevation: 0,
                foregroundColor: scheme.onSurface,
                actions: [
                  CreatorSubjectActionsButton(
                    title: name,
                    subtitle: l10n.collectionSettingsTitle,
                    actions: [
                      if (canEdit)
                        SubjectOptionsAction(
                          id: 'edit',
                          icon: Icons.edit_outlined,
                          label: l10n.commonEdit,
                          onSelected: () => _openEditor(resolved),
                        ),
                      SubjectOptionsAction(
                        id: 'share',
                        icon: Icons.share_outlined,
                        label: l10n.commonShare,
                        onSelected: () {
                          ShareService().showShareSheet(
                            context,
                            target: ShareTarget.collection(
                              collectionId: widget.collectionId,
                              title: name,
                            ),
                            sourceScreen: 'collection_detail',
                          );
                        },
                      ),
                      if (canEdit)
                        SubjectOptionsAction(
                          id: 'delete',
                          icon: Icons.delete_outline,
                          label: l10n.commonDelete,
                          isDestructive: true,
                          onSelected: () => _deleteCollection(resolved),
                        ),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: KubusTypography.inter(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.22),
                          scheme.secondary.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                    child: thumbnailUrl == null
                        ? Center(
                            child: Icon(
                              Icons.collections,
                              size: 72,
                              color: scheme.onSurface.withValues(alpha: 0.35),
                            ),
                          )
                        : Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 56,
                                color: scheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DetailSpacing.lg,
                DetailSpacing.lg,
                DetailSpacing.lg,
                DetailSpacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    if (AppConfig.isFeatureEnabled('collabInvites')) ...[
                      CollaborationPanel(
                        entityType: 'collections',
                        entityId: widget.collectionId,
                      ),
                      const SizedBox(
                          height: DetailSpacing.lg + DetailSpacing.xs),
                    ],
                    if (description.isNotEmpty) ...[
                      Text(
                        l10n.collectionDetailDescription,
                        style: DetailTypography.sectionTitle(context),
                      ),
                      const SizedBox(height: DetailSpacing.sm),
                      Text(description, style: DetailTypography.body(context)),
                      const SizedBox(
                          height: DetailSpacing.lg + DetailSpacing.xs),
                    ],
                    SectionHeader(
                      title: l10n.collectionDetailArtworks,
                      trailing: null,
                    ),
                    const SizedBox(height: DetailSpacing.md),
                    if ((error ?? '').isNotEmpty && collection != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: DetailSpacing.md),
                        child: Text(
                          l10n.collectionDetailLoadFailedMessage,
                          style: KubusTypography.inter(
                              fontSize: 12, color: scheme.error),
                        ),
                      ),
                    if (artworks.isEmpty)
                      Text(l10n.collectionDetailNoArtworksYet,
                          style: DetailTypography.caption(context))
                    else
                      ...artworks.map((art) => _ArtworkRow(artwork: art)),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: DetailSpacing.lg),
                        child: LinearProgressIndicator(color: scheme.primary),
                      ),
                  ],
                ),
              ),
            ),
          ];

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }
}

class _ArtworkRow extends StatelessWidget {
  final CollectionArtworkRecord artwork;

  const _ArtworkRow({required this.artwork});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final id = artwork.id;
    final title =
        artwork.title.isNotEmpty ? artwork.title : l10n.commonUntitled;
    final rawUrl = artwork.imageUrl ??
        (artwork.imageCid != null && artwork.imageCid!.isNotEmpty
            ? 'ipfs://${artwork.imageCid}'
            : null);
    final imageUrl = MediaUrlResolver.resolve(rawUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: DetailSpacing.md),
      child: DetailCard(
        onTap: id.isEmpty
            ? null
            : () {
                openArtwork(context, id, source: 'collection_detail');
              },
        padding: const EdgeInsets.all(DetailSpacing.md),
        borderRadius: DetailRadius.sm,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DetailRadius.xs),
              child: Container(
                width: 56,
                height: 56,
                color: scheme.surfaceContainerHighest,
                child: imageUrl == null
                    ? Icon(Icons.image_outlined,
                        color: scheme.onSurface.withValues(alpha: 0.4))
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: DetailSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DetailTypography.cardTitle(context),
              ),
            ),
            Icon(Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
