import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/common/subject_options_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/artwork.dart';
import '../../models/collection_record.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/collections_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/wallet_utils.dart';
import '../desktop/desktop_shell.dart';

class CollectionSettingsScreen extends StatefulWidget {
  final int collectionIndex;
  final String collectionName;
  final String? collectionId;
  final bool embedded;

  const CollectionSettingsScreen({
    super.key,
    required this.collectionIndex,
    required this.collectionName,
    this.collectionId,
    this.embedded = false,
  });

  @override
  State<CollectionSettingsScreen> createState() =>
      _CollectionSettingsScreenState();
}

class _CollectionSettingsScreenState extends State<CollectionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isPublic = true;
  bool _saving = false;
  bool _loadingArtworks = false;
  bool _updatingCover = false;
  Uint8List? _pickedCoverBytes;
  String? _pickedCoverFileName;
  String? _hydratedCollectionId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final collection = _resolvedCollection(context.read<CollectionsProvider>());
    if (collection == null || collection.id == _hydratedCollectionId) return;

    _hydratedCollectionId = collection.id;
    _nameController.text = collection.name;
    _descriptionController.text = collection.description ?? '';
    _isPublic = collection.isPublic;
    _pickedCoverBytes = null;
    _pickedCoverFileName = null;
  }

  CollectionRecord? _resolvedCollection(CollectionsProvider provider) {
    final targetId = (widget.collectionId ?? '').trim();
    if (targetId.isNotEmpty) {
      final byId = provider.getCollectionById(targetId);
      if (byId != null) return byId;
    }

    final index = widget.collectionIndex;
    if (index >= 0 && index < provider.collections.length) {
      return provider.collections[index];
    }

    final byName = provider.collections
        .where((item) => item.name.trim() == widget.collectionName.trim());
    if (byName.isNotEmpty) {
      return byName.first;
    }

    return targetId.isNotEmpty ? provider.getCollectionById(targetId) : null;
  }

  bool _canEdit(CollectionRecord? collection) {
    if (collection == null) return false;
    final wallet = context.read<WalletProvider>().currentWalletAddress ?? '';
    return wallet.isNotEmpty &&
        WalletUtils.equals(wallet, collection.walletAddress);
  }

  Future<void> _pickCover() async {
    if (_updatingCover) return;
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
      return;
    }

    setState(() {
      _pickedCoverBytes = bytes;
      _pickedCoverFileName = (file?.name ?? '').trim();
    });
  }

  Future<void> _save(CollectionRecord collection) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final provider = context.read<CollectionsProvider>();

    try {
      String? thumbnailUrl;
      if (_pickedCoverBytes != null) {
        setState(() => _updatingCover = true);
        thumbnailUrl = await provider.uploadCollectionThumbnail(
          bytes: _pickedCoverBytes!,
          fileName: (_pickedCoverFileName ?? 'cover.jpg').trim().isEmpty
              ? 'cover.jpg'
              : _pickedCoverFileName!.trim(),
        );
        if (!mounted) return;
        if (thumbnailUrl == null || thumbnailUrl.trim().isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast)),
          );
          return;
        }
      }

      await provider.updateCollection(
        id: collection.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
        thumbnailUrl: thumbnailUrl,
      );
      if (!mounted) return;

      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.collectionSettingsSavedToast(_nameController.text.trim()),
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionSettingsSaveFailedToast)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _updatingCover = false;
        });
      }
    }
  }

  Future<void> _delete(CollectionRecord collection) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final collectionsProvider = context.read<CollectionsProvider>();
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text(l10n.collectionSettingsDeleteDialogTitle),
        content:
            Text(l10n.collectionSettingsDeleteDialogContent(collection.name)),
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

  Future<void> _removeArtwork(
    CollectionRecord collection,
    CollectionArtworkRecord artwork,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final collectionsProvider = context.read<CollectionsProvider>();
      await collectionsProvider.removeArtwork(
        collectionId: collection.id,
        artworkId: artwork.id,
      );
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .collectionDetailRemoveArtworkFailedToast,
          ),
        ),
      );
    }
  }

  Future<void> _showAddArtworksDialog(CollectionRecord collection) async {
    if (_loadingArtworks) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final collectionsProvider = context.read<CollectionsProvider>();
    final walletAddress =
        context.read<WalletProvider>().currentWalletAddress ?? '';
    if (walletAddress.trim().isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionDetailNoArtworksYet)),
      );
      return;
    }

    setState(() => _loadingArtworks = true);
    final artworkProvider = context.read<ArtworkProvider>();
    try {
      await artworkProvider.loadArtworksForWallet(walletAddress, force: true);
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionDetailAddArtworkFailedToast)),
      );
      return;
    } finally {
      if (mounted) setState(() => _loadingArtworks = false);
    }

    if (!mounted) return;

    final owned = _filterOwnedArtworks(artworkProvider.artworks, walletAddress);
    final existingIds = collection.artworks.map((a) => a.id).toSet();
    final available = owned.where((a) => !existingIds.contains(a.id)).toList();

    if (available.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionDetailNoArtworksYet)),
      );
      return;
    }

    final selectedIds = <String>{};
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return KubusAlertDialog(
              title: Text(l10n.collectionDetailAddArtwork),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final art = available[index];
                    final checked = selectedIds.contains(art.id);
                    final imageUrl =
                        MediaUrlResolver.resolveDisplayUrl(art.imageUrl);
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
                      title: Text(art.title),
                      subtitle: Text(
                        art.artist.isNotEmpty ? art.artist : art.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: imageUrl == null
                              ? Icon(Icons.image_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5))
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

    try {
      await collectionsProvider.addArtworks(
        collectionId: collection.id,
        artworkIds: selectedIds.toList(),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
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

    return Consumer<CollectionsProvider>(
      builder: (context, provider, _) {
        if (provider.listLoading && provider.collections.isEmpty) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final collection = _resolvedCollection(provider);
        if (collection == null) {
          return CreatorScaffold(
            title: l10n.collectionSettingsTitle,
            onBack: () => Navigator.of(context).maybePop(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: CreatorInfoBox(
                  text: widget.collectionName.trim().isNotEmpty
                      ? widget.collectionName.trim()
                      : l10n.collectionDetailLoadFailedMessage,
                  icon: Icons.collections_outlined,
                ),
              ),
            ),
          );
        }

        final canEdit = _canEdit(collection);
        final subjectActions = <SubjectOptionsAction>[
          SubjectOptionsAction(
            id: 'open',
            icon: Icons.open_in_new_outlined,
            label: l10n.commonOpen,
            onSelected: () {
              unawaited(
                CreatorShellNavigation.openCollectionDetailWorkspace(
                  context,
                  collectionId: collection.id,
                  collectionName: collection.name,
                ),
              );
            },
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
                sourceScreen: 'collection_settings',
              );
            },
          ),
          if (canEdit)
            SubjectOptionsAction(
              id: 'delete',
              icon: Icons.delete_outline,
              label: l10n.commonDelete,
              isDestructive: true,
              onSelected: () => _delete(collection),
            ),
        ];
        final actionsButton = CreatorSubjectActionsButton(
          title: collection.name,
          subtitle: l10n.collectionSettingsTitle,
          actions: subjectActions,
        );

        final body = _buildMainBody(context, collection, canEdit);
        if (widget.embedded) {
          return DesktopCreatorShell(
            title: l10n.collectionSettingsTitle,
            subtitle: l10n.collectionCreatorShellSavedSubtitle,
            onBack: () {
              final shellScope = DesktopShellScope.of(context);
              if (shellScope?.canPop ?? false) {
                shellScope!.popScreen();
                return;
              }
              Navigator.of(context).maybePop();
            },
            actions: [actionsButton],
            headerBadge: CreatorStatusBadge(
              label: l10n.collectionCreatorStatusSavedSubtitle,
              color: Theme.of(context).colorScheme.primary,
            ),
            mainContent: body,
            sidebar: _buildSidebar(context, collection, canEdit),
          );
        }

        return CreatorScaffold(
          title: l10n.collectionSettingsTitle,
          onBack: () => Navigator.of(context).maybePop(),
          appBarActions: [actionsButton],
          body: body,
        );
      },
    );
  }

  Widget _buildMainBody(
    BuildContext context,
    CollectionRecord collection,
    bool canEdit,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = _pickedCoverBytes == null
        ? MediaUrlResolver.resolveDisplayUrl(collection.thumbnailUrl)
        : null;

    final artworkCount = collection.artworks.length;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: KubusSpacing.xxl),
        children: [
          CreatorSection(
            title: l10n.collectionSettingsBasicInfo,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: canEdit,
                decoration: InputDecoration(
                  labelText: l10n.collectionSettingsName,
                  hintText: l10n.collectionSettingsNameHint,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.collectionCreatorNameRequiredError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: KubusSpacing.md),
              TextFormField(
                controller: _descriptionController,
                enabled: canEdit,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.collectionSettingsDescriptionLabel,
                  hintText: l10n.collectionSettingsDescriptionHint,
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              Text(
                l10n.commonCoverImage,
                style: KubusTextStyles.detailLabel.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.lg),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                  child: _pickedCoverBytes != null
                      ? Image.memory(_pickedCoverBytes!, fit: BoxFit.cover)
                      : (coverUrl == null
                          ? Center(
                              child: Icon(
                                Icons.collections_outlined,
                                size: 52,
                                color: scheme.onSurface.withValues(alpha: 0.38),
                              ),
                            )
                          : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 52,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.38),
                                ),
                              ),
                            )),
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
              CreatorCoverImagePicker(
                imageBytes: _pickedCoverBytes,
                uploadLabel: l10n.commonUpload,
                changeLabel: l10n.commonChangeCover,
                removeTooltip: l10n.commonRemove,
                onPick: canEdit ? _pickCover : () {},
                onRemove: canEdit && _pickedCoverBytes != null
                    ? () {
                        setState(() {
                          _pickedCoverBytes = null;
                          _pickedCoverFileName = null;
                        });
                      }
                    : null,
                enabled: canEdit,
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          CreatorSection(
            title: l10n.collectionSettingsPrivacy,
            children: [
              CreatorSwitchTile(
                title: l10n.collectionSettingsPublic,
                subtitle: l10n.collectionSettingsPublicSubtitle,
                value: _isPublic,
                onChanged: canEdit
                    ? (value) => setState(() => _isPublic = value)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          CreatorSection(
            title: l10n.collectionDetailArtworks,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.collectionCreatorReadySelectionComplete(
                          artworkCount),
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: canEdit
                        ? () => _showAddArtworksDialog(collection)
                        : null,
                    icon: _loadingArtworks
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(l10n.collectionDetailAddArtwork),
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.md),
              if (collection.artworks.isEmpty)
                CreatorInfoBox(
                  text: l10n.collectionDetailNoArtworksYet,
                  icon: Icons.image_not_supported_outlined,
                )
              else
                Column(
                  children: collection.artworks
                      .map(
                        (artwork) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: KubusSpacing.sm),
                          child: _CollectionArtworkTile(
                            artwork: artwork,
                            canEdit: canEdit,
                            onRemove: canEdit
                                ? () => _removeArtwork(collection, artwork)
                                : null,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          CreatorFooterActions(
            primaryLabel: canEdit
                ? l10n.collectionCreatorQuickActionUpdate
                : l10n.commonSave,
            onPrimary: canEdit ? () => _save(collection) : null,
            primaryLoading: _saving,
            secondaryLabel: l10n.commonCancel,
            onSecondary: () => Navigator.of(context).maybePop(),
            accentColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    CollectionRecord collection,
    bool canEdit,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final readinessItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadyBasicsLabel,
        description: l10n.collectionCreatorReadyBasicsDescription,
        complete: _nameController.text.trim().isNotEmpty,
        icon: Icons.badge_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadyCoverLabel,
        description: _pickedCoverBytes != null
            ? l10n.collectionCreatorReadyCoverComplete
            : l10n.collectionCreatorReadyCoverPending,
        complete: _pickedCoverBytes != null ||
            (collection.thumbnailUrl ?? '').trim().isNotEmpty,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadyVisibilityLabel,
        description: _isPublic
            ? l10n.collectionCreatorReadyVisibilityPublic
            : l10n.collectionCreatorReadyVisibilityPrivate,
        complete: true,
        icon: _isPublic ? Icons.public_outlined : Icons.lock_outline,
      ),
    ];
    final collabEnabled = AppConfig.isFeatureEnabled('collabInvites');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopCreatorSidebarSection(
            title: l10n.collectionCreatorReadinessTitle,
            subtitle: l10n.collectionCreatorReadinessSubtitle,
            icon: Icons.checklist_outlined,
            accentColor: scheme.primary,
            child: DesktopCreatorReadinessChecklist(items: readinessItems),
          ),
          const SizedBox(height: KubusSpacing.lg),
          DesktopCreatorSubjectActionsSection(
            title: l10n.collectionSettingsTitle,
            subtitle: l10n.commonActions,
            accentColor: scheme.primary,
            actions: [
              SubjectOptionsAction(
                id: 'open',
                icon: Icons.open_in_new_outlined,
                label: l10n.commonOpen,
                onSelected: () {
                  unawaited(
                    CreatorShellNavigation.openCollectionDetailWorkspace(
                      context,
                      collectionId: collection.id,
                      collectionName: collection.name,
                    ),
                  );
                },
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
                    sourceScreen: 'collection_settings',
                  );
                },
              ),
              if (canEdit)
                SubjectOptionsAction(
                  id: 'delete',
                  icon: Icons.delete_outline,
                  label: l10n.commonDelete,
                  isDestructive: true,
                  onSelected: () => _delete(collection),
                ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          DesktopCreatorSidebarSection(
            title: l10n.collectionCreatorQuickActionsTitle,
            subtitle: l10n.collectionCreatorQuickActionsSubtitle,
            icon: Icons.flash_on_outlined,
            accentColor: scheme.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: canEdit ? () => _save(collection) : null,
                  icon: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(canEdit
                      ? l10n.collectionCreatorQuickActionUpdate
                      : l10n.commonSave),
                ),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          DesktopCreatorSidebarSection(
            title: l10n.collectionCreatorSummaryIdLabel,
            subtitle: l10n.collectionCreatorSummarySelectedArtworksLabel,
            icon: Icons.info_outline,
            accentColor: scheme.tertiary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopCreatorSummaryRow(
                  label: l10n.collectionCreatorSummaryIdLabel,
                  value: collection.id.trim().isEmpty
                      ? l10n.collectionCreatorSummaryNotCreatedYet
                      : collection.id,
                  icon: Icons.tag,
                ),
                const SizedBox(height: KubusSpacing.sm),
                DesktopCreatorSummaryRow(
                  label: l10n.collectionCreatorSummaryVisibilityLabel,
                  value: _isPublic ? l10n.commonPublic : l10n.commonPrivate,
                  icon: _isPublic ? Icons.public_outlined : Icons.lock_outline,
                ),
                const SizedBox(height: KubusSpacing.sm),
                DesktopCreatorSummaryRow(
                  label: l10n.collectionCreatorSummarySelectedArtworksLabel,
                  value: '${collection.artworks.length}',
                  icon: Icons.collections_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          if (collabEnabled)
            DesktopCreatorCollaborationSection(
              title: l10n.collectionSettingsCollaboration,
              subtitle: canEdit
                  ? l10n.collectionCreatorCollaborationReadySubtitle
                  : l10n.collectionCreatorCollaborationLockedSubtitle,
              entityType: 'collection',
              entityId: collection.id,
              enabled: canEdit,
              lockedMessage: l10n.collectionCreatorCollaborationLockedMessage,
            )
          else
            DesktopCreatorSidebarSection(
              title: l10n.collectionSettingsCollaboration,
              subtitle: l10n.collectionCreatorCollaborationLockedSubtitle,
              icon: Icons.group_off_outlined,
              accentColor: scheme.tertiary,
              child: CreatorInfoBox(
                text: l10n.collectionCreatorCollaborationLockedMessage,
                icon: Icons.lock_outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionArtworkTile extends StatelessWidget {
  final CollectionArtworkRecord artwork;
  final bool canEdit;
  final VoidCallback? onRemove;

  const _CollectionArtworkTile({
    required this.artwork,
    required this.canEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = MediaUrlResolver.resolveDisplayUrl(artwork.imageUrl);

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            child: Container(
              width: 56,
              height: 56,
              color: scheme.surfaceContainerHighest,
              child: coverUrl == null
                  ? Icon(
                      Icons.image_outlined,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    )
                  : Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailLabel.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  artwork.artistName?.trim().isNotEmpty == true
                      ? artwork.artistName!.trim()
                      : artwork.artistWallet?.trim().isNotEmpty == true
                          ? artwork.artistWallet!.trim()
                          : artwork.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          if (canEdit && onRemove != null)
            IconButton(
              tooltip: AppLocalizations.of(context)!.commonRemove,
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ],
      ),
    );
  }
}
