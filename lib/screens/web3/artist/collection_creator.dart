import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'dart:async';
import 'dart:typed_data';

import '../../../config/config.dart';
import '../../art/collection_detail_screen.dart';
import '../../../services/backend_api_service.dart';
import '../../../providers/collections_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/wallet_utils.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/collaboration_panel.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import '../../desktop/desktop_shell.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';

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
  String? _createdCollectionId;
  String _attemptedWalletAddress = '';
  String _inflightWalletAddress = '';
  String _scheduledWalletAddress = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _scheduleLoadArtworksIfNeeded(String walletAddress) {
    final normalized = walletAddress.trim();
    if (normalized.isEmpty) return;
    if (normalized == _attemptedWalletAddress) return;
    if (normalized == _inflightWalletAddress) return;
    if (normalized == _scheduledWalletAddress) return;

    _scheduledWalletAddress = normalized;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final toLoad = _scheduledWalletAddress;
      _scheduledWalletAddress = '';
      if (toLoad.isEmpty) return;
      unawaited(_loadArtworksForWallet(toLoad));
    });
  }

  Future<void> _loadArtworksForWallet(String walletAddress) async {
    final normalized = walletAddress.trim();
    if (normalized.isEmpty) return;

    final artworkProvider = context.read<ArtworkProvider>();
    _attemptedWalletAddress = normalized;
    _inflightWalletAddress = normalized;

    setState(() => _artworksLoading = true);
    try {
      await artworkProvider.loadArtworksForWallet(normalized);
    } catch (_) {
      // Non-fatal; artworks list will be empty.
    } finally {
      _inflightWalletAddress = '';
      if (mounted) {
        setState(() => _artworksLoading = false);
      }
    }
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
    _scheduleLoadArtworksIfNeeded(walletAddress);

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
            _buildArtworkSelectionSection(l10n, studioAccent),

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
            ? 'Shape the collection, then save it to unlock collaboration.'
            : 'Collection saved. Keep curating or invite collaborators in-context.',
        onBack: shellScope?.popScreen,
        headerBadge: CreatorStatusBadge(
          label: _createdCollectionId == null ? 'Draft' : 'Saved',
          color: _createdCollectionId == null ? studioAccent : Theme.of(context).colorScheme.primary,
        ),
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
        label: 'Basics complete',
        description: 'Name and description are filled in.',
        complete: hasBasics,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Cover image added',
        description: hasCover
            ? 'Collection cover is ready.'
            : 'Optional, but strongly recommended on desktop.',
        complete: hasCover,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Artwork selection ready',
        description: selectedCount > 0
            ? '$selectedCount artwork(s) selected.'
            : 'Choose artworks to anchor the collection.',
        complete: selectedCount > 0,
        icon: Icons.collections_bookmark_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Visibility chosen',
        description: _isPublic
            ? 'Public collection visible to everyone.'
            : 'Private collection is still available to collaborators.',
        complete: true,
        icon: _isPublic ? Icons.public_outlined : Icons.lock_outline,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: 'Status',
          subtitle: created ? 'Saved collection' : 'Draft in progress',
          icon: created ? Icons.bookmark_added_outlined : Icons.edit_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: created ? 'Saved' : 'Draft',
                color: created ? scheme.primary : accent,
              ),
              const SizedBox(height: KubusSpacing.sm),
              DesktopCreatorSummaryRow(
                label: 'Collection ID',
                value: created ? createdId : 'Not created yet',
                valueColor: created ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6),
              ),
              DesktopCreatorSummaryRow(
                label: 'Selected artworks',
                value: '$selectedCount',
                icon: Icons.collections_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: 'Visibility',
                value: _isPublic ? 'Public' : 'Private',
                icon: _isPublic ? Icons.public_outlined : Icons.lock_outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Readiness',
          subtitle: 'A quick sanity check before saving.',
          icon: Icons.fact_check_outlined,
          child: DesktopCreatorReadinessChecklist(items: readyItems),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Quick actions',
          subtitle: 'Keep the workflow in this creator.',
          icon: Icons.flash_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: Icon(created ? Icons.refresh_outlined : Icons.save_outlined),
                label: Text(created ? 'Update collection' : 'Save collection'),
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
                  label: const Text('Open collection'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Collaboration',
          subtitle: created
              ? 'Invite co-curators without leaving the workspace.'
              : 'Save once to unlock collaboration.',
          icon: Icons.group_add_outlined,
          child: created && AppConfig.isFeatureEnabled('collabInvites')
              ? CollaborationPanel(
                  entityType: 'collections',
                  entityId: createdId,
                )
              : Text(
                  'Once saved, collaborators can be invited here so curation stays in context.',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildArtworkSelectionSection(AppLocalizations l10n, Color accent) {
    final artworkProvider = context.watch<ArtworkProvider>();
    final allArtworks = artworkProvider.artworks;
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

        // Artworks list
        if (_artworksLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (filtered.isEmpty)
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
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: scheme.outline.withValues(alpha: 0.12)),
              itemBuilder: (_, index) {
                final artwork = filtered[index];
                final isSelected = _selectedArtworkIds.contains(artwork.id);
                final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
                final thumbCacheSize = (40 * dpr).clamp(64.0, 256.0).round();

                return ListTile(
                  key: ValueKey<String>(artwork.id),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm,
                    vertical: KubusSpacing.xxs,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(KubusRadius.sm),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: KubusCachedImage(
                        imageUrl: artwork.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: thumbCacheSize,
                        cacheHeight: thumbCacheSize,
                        maxDisplayWidth: thumbCacheSize,
                        cacheVersion: KubusCachedImage.versionTokenFromDate(
                          artwork.updatedAt ?? artwork.createdAt,
                        ),
                        iconSize: 20,
                        errorBuilder: (_, __, ___) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: scheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    artwork.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailLabel,
                  ),
                  subtitle: ArtworkCreatorByline(
                    artwork: artwork,
                    includeByPrefix: false,
                    showUsername: false,
                    linkToProfile: false,
                    maxLines: 1,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: Checkbox(
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
                );
              },
            ),
          ),
      ],
    );
  }
}
