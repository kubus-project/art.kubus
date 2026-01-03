import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/artwork.dart';
import '../../models/collection_record.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../config/config.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
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

  Future<void> _openEditor(CollectionRecord collection) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CollectionEditSheet(
        collectionId: collection.id,
        initialCollection: collection,
      ),
    );
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
                      style: GoogleFonts.inter(
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor: scheme.surface,
                elevation: 0,
                foregroundColor: scheme.onSurface,
                actions: [
                  IconButton(
                    tooltip: l10n.commonShare,
                    onPressed: () {
                      ShareService().showShareSheet(
                        context,
                        target: ShareTarget.collection(
                            collectionId: widget.collectionId, title: name),
                        sourceScreen: 'collection_detail',
                      );
                    },
                    icon: const Icon(Icons.share_outlined),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: l10n.commonEdit,
                      onPressed: () => _openEditor(resolved),
                      icon: const Icon(Icons.edit),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: GoogleFonts.inter(
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
                padding: const EdgeInsets.fromLTRB(DetailSpacing.lg,
                    DetailSpacing.lg, DetailSpacing.lg, DetailSpacing.xl),
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
                        Text(description,
                            style: DetailTypography.body(context)),
                        const SizedBox(
                            height: DetailSpacing.lg + DetailSpacing.xs),
                      ],
                      SectionHeader(
                        title: l10n.collectionDetailArtworks,
                        trailing: canEdit
                            ? TextButton.icon(
                                onPressed: () => _openEditor(resolved),
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text(l10n.collectionDetailManage,
                                    style: DetailTypography.button(context)),
                              )
                            : null,
                      ),
                      const SizedBox(height: DetailSpacing.md),
                      if ((error ?? '').isNotEmpty && collection != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: DetailSpacing.md),
                          child: Text(
                            l10n.collectionDetailLoadFailedMessage,
                            style: GoogleFonts.inter(
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
            ],
          );
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

class _CollectionEditSheet extends StatefulWidget {
  final String collectionId;
  final CollectionRecord initialCollection;

  const _CollectionEditSheet({
    required this.collectionId,
    required this.initialCollection,
  });

  @override
  State<_CollectionEditSheet> createState() => _CollectionEditSheetState();
}

class _CollectionEditSheetState extends State<_CollectionEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isPublic = true;
  bool _saving = false;
  bool _loadingArtworks = false;
  bool _updatingCover = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialCollection.name);
    _descriptionController =
        TextEditingController(text: widget.initialCollection.description ?? '');
    _isPublic = widget.initialCollection.isPublic;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _changeCover(CollectionRecord collection) async {
    if (_updatingCover) return;

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollectionsProvider>();

    setState(() => _updatingCover = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      final fileName = (file?.name ?? '').trim();

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)),
        );
        return;
      }

      final url = await provider.uploadCollectionThumbnail(
        bytes: bytes,
        fileName: fileName.isEmpty ? 'cover.jpg' : fileName,
      );
      if (!mounted) return;

      if (url == null || url.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)),
        );
        return;
      }

      await provider.updateCollection(
        id: collection.id,
        thumbnailUrl: url,
      );
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.commonActionFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingCover = false);
    }
  }

  Future<void> _save(CollectionRecord collection) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<CollectionsProvider>();

    try {
      await provider.updateCollection(
        id: collection.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              l10n.collectionSettingsSavedToast(_nameController.text.trim())),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionSettingsSaveFailedToast)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _removeArtwork(
    CollectionRecord collection,
    CollectionArtworkRecord artwork,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollectionsProvider>();

    try {
      await provider.removeArtwork(
        collectionId: collection.id,
        artworkId: artwork.id,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionDetailRemoveArtworkFailedToast)),
      );
    }
  }

  Future<void> _showAddArtworksDialog(CollectionRecord collection) async {
    if (_loadingArtworks) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final walletProvider = context.read<WalletProvider>();
    final walletAddress = walletProvider.currentWalletAddress ?? '';
    if (walletAddress.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionDetailNoArtworksYet)),
      );
      return;
    }

    final artworkProvider = context.read<ArtworkProvider>();
    setState(() => _loadingArtworks = true);
    try {
      await artworkProvider.loadArtworksForWallet(walletAddress, force: true);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.collectionDetailAddArtworkFailedToast)),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _loadingArtworks = false);
      }
    }

    if (!mounted) return;

    final owned = _filterOwnedArtworks(artworkProvider.artworks, walletAddress);
    final existingIds = collection.artworks.map((a) => a.id).toSet();
    final available = owned.where((a) => !existingIds.contains(a.id)).toList();

    if (available.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionDetailNoArtworksYet)),
      );
      return;
    }

    final selectedIds = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                l10n.collectionDetailAddArtwork,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final art = available[index];
                    final checked = selectedIds.contains(art.id);
                    final imageUrl =
                        ArtworkMediaResolver.resolveCover(artwork: art);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            selectedIds.add(art.id);
                          } else {
                            selectedIds.remove(art.id);
                          }
                        });
                      },
                      title: Text(
                        art.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        art.artist.isNotEmpty ? art.artist : art.id,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: imageUrl == null
                              ? Icon(
                                  Icons.image_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonAdd),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedIds.isEmpty) return;

    if (!mounted) return;

    final provider = context.read<CollectionsProvider>();
    try {
      await provider.addArtworks(
        collectionId: collection.id,
        artworkIds: selectedIds.toList(),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionDetailAddArtworkFailedToast)),
      );
    }
  }

  List<Artwork> _filterOwnedArtworks(List<Artwork> artworks, String wallet) {
    final normalizedWallet = WalletUtils.canonical(wallet);
    if (normalizedWallet.isEmpty) return const <Artwork>[];

    return artworks.where((artwork) {
      final meta = artwork.metadata ?? const <String, dynamic>{};
      final candidates = <String?>[
        meta['walletAddress']?.toString(),
        meta['wallet_address']?.toString(),
        meta['wallet']?.toString(),
        meta['ownerWallet']?.toString(),
        meta['creatorWallet']?.toString(),
        meta['createdBy']?.toString(),
        meta['created_by']?.toString(),
        artwork.discoveryUserId,
      ];

      for (final candidate in candidates) {
        if (candidate == null) continue;
        if (WalletUtils.equals(candidate, normalizedWallet)) {
          return true;
        }
      }
      final resolved = WalletUtils.resolveFromMap(meta);
      return WalletUtils.equals(resolved, normalizedWallet);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<CollectionsProvider>();
    final collection = provider.getCollectionById(widget.collectionId) ??
        widget.initialCollection;

    final coverUrl = MediaUrlResolver.resolve(collection.thumbnailUrl);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DetailSpacing.xl,
          right: DetailSpacing.xl,
          top: DetailSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + DetailSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.collectionSettingsTitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: DetailSpacing.md),
            Text(
              l10n.commonCoverImage,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: DetailSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(DetailSpacing.md),
              child: Container(
                height: 140,
                width: double.infinity,
                color: scheme.surfaceContainerHighest,
                child: coverUrl == null
                    ? Icon(
                        Icons.image_outlined,
                        size: 44,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      )
                    : Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 44,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: DetailSpacing.md),
            OutlinedButton.icon(
              onPressed: (_saving || _updatingCover)
                  ? null
                  : () => _changeCover(collection),
              icon: _updatingCover
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.primary),
                    )
                  : const Icon(Icons.image_outlined, size: 18),
              label: Text(l10n.commonChangeCover,
                  style: GoogleFonts.inter(fontSize: 13)),
            ),
            const SizedBox(height: DetailSpacing.md),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.collectionSettingsName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DetailSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: l10n.collectionSettingsNameHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DetailSpacing.md),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.collectionCreatorNameRequiredError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DetailSpacing.md),
                  Text(
                    l10n.collectionSettingsDescriptionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DetailSpacing.sm),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.collectionSettingsDescriptionHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DetailSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: DetailSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.collectionSettingsPublic,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      l10n.collectionSettingsPublicSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DetailSpacing.md),
            Row(
              children: [
                Text(
                  l10n.collectionDetailArtworks,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadingArtworks
                      ? null
                      : () => _showAddArtworksDialog(collection),
                  icon: _loadingArtworks
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: Text(l10n.collectionDetailAddArtwork,
                      style: GoogleFonts.inter(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: DetailSpacing.sm),
            if (collection.artworks.isEmpty)
              Text(
                l10n.collectionDetailNoArtworksYet,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.separated(
                  itemCount: collection.artworks.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final art = collection.artworks[index];
                    final imageUrl = MediaUrlResolver.resolve(
                      art.imageUrl ??
                          (art.imageCid != null && art.imageCid!.isNotEmpty
                              ? 'ipfs://${art.imageCid}'
                              : null),
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(DetailSpacing.sm),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: scheme.surfaceContainerHighest,
                          child: imageUrl == null
                              ? Icon(
                                  Icons.image_outlined,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        art.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        (art.artistName ?? art.artistWallet ?? art.id)
                            .toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: scheme.onSurface.withValues(alpha: 0.65)),
                        onPressed: () => _removeArtwork(collection, art),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: DetailSpacing.lg),
            Row(
              children: [
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).maybePop(),
                  child: Text(l10n.commonCancel),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : () => _save(collection),
                  child: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
