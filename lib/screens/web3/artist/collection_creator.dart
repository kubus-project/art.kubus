import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'dart:async';
import 'dart:typed_data';

import '../../../config/config.dart';
import '../../../models/artwork.dart';
import '../../art/collection_detail_screen.dart';
import '../../../services/backend_api_service.dart';
import '../../../providers/collections_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../widgets/disk_cached_artwork_image.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/wallet_utils.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import '../../desktop/desktop_shell.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class CollectionCreator extends StatefulWidget {
  final void Function(String collectionId)? onCreated;

  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;

  const CollectionCreator({
    super.key,
    this.onCreated,
    this.embedded = false,
  });

  @override
  State<CollectionCreator> createState() => _CollectionCreatorState();
}

class _CollectionCreatorState extends State<CollectionCreator> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;
  bool _isSubmitting = false;

  Uint8List? _coverBytes;
  String? _coverFileName;

  // --- Artwork selection state ---
  final Set<String> _selectedArtworkIds = <String>{};
  String _artworkSearchQuery = '';
  bool _artworksLoading = false;
  bool _artworkLibraryLoadRequested = false;
  String _lastPrefetchedArtworkSignature = '';
  String? _createdCollectionId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadArtworksForWallet(String walletAddress) async {
    final normalized = walletAddress.trim();
    if (normalized.isEmpty) return;

    final artworkProvider = context.read<ArtworkProvider>();
    setState(() {
      _artworkLibraryLoadRequested = true;
      _artworksLoading = true;
    });
    try {
      await artworkProvider.loadArtworksForWallet(normalized);
      if (!mounted) return;
      final loaded = artworkProvider.artworksForWallet(normalized);
      _prefetchArtworkImages(loaded);
    } catch (_) {
      // Non-fatal; artworks list will be empty.
    } finally {
      if (mounted) {
        setState(() => _artworksLoading = false);
      }
    }
  }

  void _prefetchArtworkImages(List<Artwork> artworks) {
    if (artworks.isEmpty) return;
    final signature = artworks
        .take(8)
      .map((artwork) => (artwork.imageUrl ?? '').trim())
        .where((url) => url.isNotEmpty)
        .join('|');
    if (signature.isEmpty || signature == _lastPrefetchedArtworkSignature) {
      return;
    }
    _lastPrefetchedArtworkSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final artwork in artworks.take(8)) {
        final url = (artwork.imageUrl ?? '').trim();
        if (url.isEmpty) continue;
        unawaited(prefetchDiskCachedArtworkImage(url));
      }
    });
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final failedToast = l10n.commonActionFailedToast;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(failedToast)),
      );
      return;
    }
    setState(() {
      _coverBytes = bytes;
      _coverFileName = (file?.name ?? '').trim();
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final collectionsProvider = context.read<CollectionsProvider>();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? thumbnailUrl;
      if (_coverBytes != null) {
        final safeName = (_coverFileName ?? 'cover.jpg').trim();
        thumbnailUrl = await collectionsProvider.uploadCollectionThumbnail(
          bytes: _coverBytes!,
          fileName: safeName.isEmpty ? 'cover.jpg' : safeName,
        );
        if (!mounted) return;
        if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast)),
          );
          return;
        }
      }

      final api = BackendApiService();
      final created = await api.createCollection(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
        thumbnailUrl: thumbnailUrl,
      );

      final id = (created['id'] ?? created['collectionId'] ?? created['collection_id'])?.toString();
      if (!mounted) return;

      if (id == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.collectionCreatorCreateFailed)),
        );
        return;
      }

      // Add selected artworks to the newly created collection.
      if (_selectedArtworkIds.isNotEmpty) {
        try {
          await collectionsProvider.addArtworks(
            collectionId: id,
            artworkIds: _selectedArtworkIds.toList(),
          );
        } catch (_) {
          // Non-fatal: collection was created, artworks may fail to attach.
        }
      }

      if (!mounted) return;

      if (widget.embedded) {
        setState(() => _createdCollectionId = id);
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('Collection saved successfully.')),
        );
        return;
      }

      widget.onCreated?.call(id);

      if (widget.onCreated == null) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionCreatorCreateFailedWithError)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final studioAccent = KubusColorRoles.of(context).web3ArtistStudioAccent;
    final shellScope = DesktopShellScope.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final web3Provider = context.watch<Web3Provider>();
    final walletAddress = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
    final artworkProvider = context.watch<ArtworkProvider>();
    final allArtworks = artworkProvider.artworks;
    if (allArtworks.isNotEmpty) {
      _prefetchArtworkImages(allArtworks);
    }

    final formBody = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.md, KubusSpacing.md, KubusSpacing.md, KubusSpacing.lg,
        ),
        children: [
            if (_createdCollectionId != null) ...[
              CreatorInfoBox(
                text:
                    'Collection saved. Collaboration is available from the sidebar, and you can keep refining the selection below.',
                icon: Icons.check_circle_outline,
                accentColor: studioAccent,
              ),
              const CreatorSectionSpacing(),
            ],
            // --- Basics section ---
            CreatorSection(
              title: l10n.collectionSettingsBasicInfo,
              children: [
                CreatorTextField(
                  controller: _nameController,
                  label: l10n.collectionSettingsName,
                  hint: l10n.collectionSettingsNameHint,
                  textInputAction: TextInputAction.next,
                  accentColor: studioAccent,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return l10n.collectionCreatorNameRequiredError;
                    return null;
                  },
                ),
                const CreatorFieldSpacing(),
                CreatorTextField(
                  controller: _descriptionController,
                  label: l10n.collectionSettingsDescriptionLabel,
                  hint: l10n.collectionSettingsDescriptionHint,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  accentColor: studioAccent,
                ),
              ],
            ),

            const CreatorSectionSpacing(),

            // --- Cover Image section ---
            CreatorSection(
              title: l10n.commonCoverImage,
              children: [
                CreatorCoverImagePicker(
                  imageBytes: _coverBytes,
                  uploadLabel: l10n.commonUpload,
                  changeLabel: l10n.commonChangeCover,
                  removeTooltip: l10n.commonRemove,
                  onPick: _pickCoverImage,
                  onRemove: () => setState(() {
                    _coverBytes = null;
                    _coverFileName = null;
                  }),
                  enabled: !_isSubmitting,
                ),
              ],
            ),

            const CreatorSectionSpacing(),

            // --- Add existing artworks section ---
            _buildArtworkSelectionSection(
              l10n,
              studioAccent,
              walletAddress,
              allArtworks,
            ),

            const CreatorSectionSpacing(),

            // --- Visibility toggle ---
            CreatorSwitchTile(
              title: l10n.collectionSettingsPublic,
              subtitle: l10n.collectionSettingsPublicSubtitle,
              value: _isPublic,
              onChanged: _isSubmitting ? null : (v) => setState(() => _isPublic = v),
              activeColor: studioAccent,
            ),

            const CreatorSectionSpacing(),

            // --- Create button ---
            CreatorFooterActions(
              primaryLabel: l10n.commonCreate,
              onPrimary: _submit,
              primaryLoading: _isSubmitting,
              accentColor: studioAccent,
            ),
        ],
      ),
    );

    if (widget.embedded) {
      return DesktopCreatorShell(
        title: l10n.collectionCreatorTitle,
        subtitle: _createdCollectionId == null
            ? l10n.collectionCreatorShellDraftSubtitle
            : l10n.collectionCreatorShellSavedSubtitle,
        onBack: shellScope?.popScreen,
        headerBadge: CreatorStatusBadge(
          label: _createdCollectionId == null
              ? l10n.commonDraft
              : l10n.commonSavedToast,
          color: _createdCollectionId == null ? studioAccent : Theme.of(context).colorScheme.primary,
        ),
        sidebarAccentColor: studioAccent,
        mainContent: formBody,
        sidebar: _buildDesktopSidebar(
          l10n,
          studioAccent,
          walletAddress,
        ),
      );
    }

    return CreatorScaffold(
      title: l10n.collectionCreatorTitle,
      body: formBody,
    );
  }

  Widget _buildDesktopSidebar(
    AppLocalizations l10n,
    Color accent,
    String walletAddress,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final createdId = _createdCollectionId ?? '';
    final created = createdId.isNotEmpty;
    final selectedCount = _selectedArtworkIds.length;
    final hasCover = _coverBytes != null;
    final hasBasics = _nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;

    final readyItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadyBasicsLabel,
        description: l10n.collectionCreatorReadyBasicsDescription,
        complete: hasBasics,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadyCoverLabel,
        description: hasCover
            ? l10n.collectionCreatorReadyCoverComplete
            : l10n.collectionCreatorReadyCoverPending,
        complete: hasCover,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.collectionCreatorReadySelectionLabel,
        description: selectedCount > 0
            ? l10n.collectionCreatorReadySelectionComplete(selectedCount)
            : l10n.collectionCreatorReadySelectionPending,
        complete: selectedCount > 0,
        icon: Icons.collections_bookmark_outlined,
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: l10n.commonStatus,
          subtitle: created
              ? l10n.collectionCreatorStatusSavedSubtitle
              : l10n.collectionCreatorStatusDraftSubtitle,
          icon: created ? Icons.bookmark_added_outlined : Icons.edit_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: created ? l10n.commonSavedToast : l10n.commonDraft,
                color: created ? scheme.primary : accent,
              ),
              const SizedBox(height: KubusSpacing.sm),
              DesktopCreatorSummaryRow(
                label: l10n.collectionCreatorSummaryIdLabel,
                value: created
                    ? createdId
                    : l10n.collectionCreatorSummaryNotCreatedYet,
                valueColor: created ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6),
              ),
              DesktopCreatorSummaryRow(
                label: l10n.collectionCreatorSummarySelectedArtworksLabel,
                value: '$selectedCount',
                icon: Icons.collections_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: l10n.collectionCreatorSummaryVisibilityLabel,
                value: _isPublic ? l10n.commonPublic : l10n.commonPrivate,
                icon: _isPublic ? Icons.public_outlined : Icons.lock_outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.collectionCreatorReadinessTitle,
          subtitle: l10n.collectionCreatorReadinessSubtitle,
          icon: Icons.fact_check_outlined,
          accentColor: accent,
          child: DesktopCreatorReadinessChecklist(
            items: readyItems,
            accentColor: accent,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.collectionCreatorQuickActionsTitle,
          subtitle: l10n.collectionCreatorQuickActionsSubtitle,
          icon: Icons.flash_on_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: Icon(created ? Icons.refresh_outlined : Icons.save_outlined),
                label: Text(created
                    ? l10n.collectionCreatorQuickActionUpdate
                    : l10n.collectionCreatorQuickActionSave),
              ),
              if (created) ...[
                const SizedBox(height: KubusSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    if (createdId.isEmpty) return;
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: l10n.collectionCreatorTitle,
                        child: CollectionDetailScreen(
                          collectionId: createdId,
                          embedded: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: Text(l10n.collectionCreatorQuickActionOpen),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorCollaborationSection(
          title: l10n.collectionSettingsCollaboration,
          subtitle: created
              ? l10n.collectionCreatorCollaborationReadySubtitle
              : l10n.collectionCreatorCollaborationLockedSubtitle,
          entityType: 'collections',
          entityId: createdId,
          enabled: created && AppConfig.isFeatureEnabled('collabInvites'),
          lockedMessage: l10n.collectionCreatorCollaborationLockedMessage,
          accentColor: accent,
        ),
      ],
    );
  }

  Widget _buildArtworkSelectionSection(
    AppLocalizations l10n,
    Color accent,
    String walletAddress,
    List<Artwork> allArtworks,
  ) {
    final scheme = Theme.of(context).colorScheme;

    // Filter artworks by search query.
    final query = _artworkSearchQuery.toLowerCase().trim();
    final filtered = query.isEmpty
        ? allArtworks
        : allArtworks
            .where((a) =>
                a.title.toLowerCase().contains(query) ||
                a.description.toLowerCase().contains(query))
            .toList();

    return CreatorSection(
      title: l10n.collectionCreatorAddArtworksTitle,
      children: [
        // Search field
        CreatorTextField(
          label: l10n.collectionCreatorSearchArtworksLabel,
          hint: l10n.collectionCreatorSearchArtworksHint,
          accentColor: accent,
          onChanged: (v) => setState(() => _artworkSearchQuery = v),
        ),

        const CreatorFieldSpacing(),

        if (walletAddress.isEmpty) ...[
          CreatorInfoBox(
            text:
                'Connect a wallet to load and curate your artwork library inside this collection creator.',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: accent,
          ),
          const CreatorFieldSpacing(),
        ] else if (allArtworks.isEmpty) ...[
          CreatorInfoBox(
            text: _artworkLibraryLoadRequested
                ? 'Your artwork library is still loading. If the backend is slow, you can keep editing the collection basics and come back here.'
                : 'Load your artwork library to select pieces for this collection. This keeps the first open lighter and avoids unnecessary API calls.',
            icon: Icons.collections_bookmark_outlined,
            accentColor: accent,
          ),
          const CreatorFieldSpacing(),
          OutlinedButton.icon(
            onPressed: _artworksLoading
                ? null
                : () => unawaited(_loadArtworksForWallet(walletAddress)),
            icon: Icon(_artworksLoading
                ? Icons.hourglass_bottom_outlined
                : Icons.download_outlined),
            label: Text(
              _artworksLoading ? 'Loading library…' : 'Load artwork library',
            ),
          ),
        ],

        // Selected artworks chips
        if (_selectedArtworkIds.isNotEmpty) ...[
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs,
            children: _selectedArtworkIds.map((id) {
              final artwork = allArtworks
                  .where((a) => a.id == id)
                  .cast<dynamic>()
                  .firstOrNull;
              final title = artwork?.title ?? id;
              return Chip(
                label: Text(
                  title is String ? title : id,
                  style: KubusTextStyles.detailLabel,
                ),
                deleteIcon:
                    Icon(Icons.close, size: 16, color: scheme.onSurface),
                onDeleted: () => setState(() => _selectedArtworkIds.remove(id)),
                backgroundColor: accent.withValues(alpha: 0.12),
                side: BorderSide(color: accent.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
              );
            }).toList(),
          ),
          const CreatorFieldSpacing(),
        ],

        if (_artworksLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (allArtworks.isNotEmpty && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KubusSpacing.md),
            child: Center(
              child: Text(
                l10n.collectionCreatorNoArtworksAvailable,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else if (allArtworks.isNotEmpty)
          ...[
            const CreatorFieldSpacing(),
            _buildArtworkGallery(filtered, accent),
          ],
      ],
    );
  }

  Widget _buildArtworkGallery(List<Artwork> artworks, Color accent) {
    final scheme = Theme.of(context).colorScheme;

    if (artworks.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 760 ? 2 : 1);

        if (!isWide) {
          return Column(
            children: artworks
                .map((artwork) => Padding(
                      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                      child: _buildArtworkSelectionCard(
                        artwork: artwork,
                        accent: accent,
                        scheme: scheme,
                        compact: true,
                      ),
                    ))
                .toList(growable: false),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: artworks.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 260,
            crossAxisSpacing: KubusSpacing.md,
            mainAxisSpacing: KubusSpacing.md,
          ),
          itemBuilder: (context, index) {
            return _buildArtworkSelectionCard(
              artwork: artworks[index],
              accent: accent,
              scheme: scheme,
              compact: false,
            );
          },
        );
      },
    );
  }

  Widget _buildArtworkSelectionCard({
    required Artwork artwork,
    required Color accent,
    required ColorScheme scheme,
    required bool compact,
  }) {
    final isSelected = _selectedArtworkIds.contains(artwork.id);
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final thumbCacheSize = compact
        ? (72 * dpr).clamp(96.0, 320.0).round()
        : (180 * dpr).clamp(180.0, 640.0).round();

    return LiquidGlassCard(
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      backgroundColor: isSelected
          ? accent.withValues(alpha: 0.10)
          : scheme.surface.withValues(alpha: 0.72),
      showBorder: true,
      onTap: _isSubmitting
          ? null
          : () {
              setState(() {
                if (isSelected) {
                  _selectedArtworkIds.remove(artwork.id);
                } else {
                  _selectedArtworkIds.add(artwork.id);
                }
              });
            },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedArtworkIds.remove(artwork.id);
                    } else {
                      _selectedArtworkIds.add(artwork.id);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: compact
                ? Row(
                    children: [
                      _buildArtworkThumb(artwork, thumbCacheSize, accent, scheme),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    artwork.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KubusTextStyles.detailCardTitle,
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  activeColor: accent,
                                  onChanged: _isSubmitting
                                      ? null
                                      : (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedArtworkIds.add(artwork.id);
                                            } else {
                                              _selectedArtworkIds.remove(artwork.id);
                                            }
                                          });
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: KubusSpacing.xs),
                            ArtworkCreatorByline(
                              artwork: artwork,
                              includeByPrefix: false,
                              showUsername: false,
                              linkToProfile: false,
                              maxLines: 2,
                              style: KubusTextStyles.detailCaption.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: KubusCachedImage(
                                imageUrl: artwork.imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: thumbCacheSize,
                                cacheHeight: thumbCacheSize,
                                maxDisplayWidth: thumbCacheSize,
                                cacheVersion:
                                    KubusCachedImage.versionTokenFromDate(
                                  artwork.updatedAt ?? artwork.createdAt,
                                ),
                                iconSize: 28,
                                errorBuilder: (_, __, ___) => Container(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 28,
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.82),
                                borderRadius:
                                    BorderRadius.circular(KubusRadius.xl),
                                border: Border.all(
                                  color: isSelected
                                      ? accent
                                      : scheme.outline.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KubusSpacing.sm,
                                  vertical: KubusSpacing.xs,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      size: 16,
                                      color: isSelected ? accent : scheme.onSurface,
                                    ),
                                    const SizedBox(width: KubusSpacing.xs),
                                    Text(
                                      isSelected ? 'Selected' : 'Add',
                                      style: KubusTextStyles.detailLabel.copyWith(
                                        color: isSelected ? accent : scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              artwork.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KubusTextStyles.detailCardTitle,
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            activeColor: accent,
                            onChanged: _isSubmitting
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedArtworkIds.add(artwork.id);
                                      } else {
                                        _selectedArtworkIds.remove(artwork.id);
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xxs),
                      ArtworkCreatorByline(
                        artwork: artwork,
                        includeByPrefix: false,
                        showUsername: false,
                        linkToProfile: false,
                        maxLines: 2,
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkThumb(
    Artwork artwork,
    int cacheWidth,
    Color accent,
    ColorScheme scheme,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: SizedBox(
        width: 74,
        height: 74,
        child: KubusCachedImage(
          imageUrl: artwork.imageUrl,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          cacheHeight: cacheWidth,
          maxDisplayWidth: cacheWidth,
          cacheVersion: KubusCachedImage.versionTokenFromDate(
            artwork.updatedAt ?? artwork.createdAt,
          ),
          iconSize: 24,
          errorBuilder: (_, __, ___) => Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_outlined,
              size: 24,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
