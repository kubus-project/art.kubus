import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import '../../../services/backend_api_service.dart';
import '../../../providers/collections_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';

class CollectionCreator extends StatefulWidget {
  final void Function(String collectionId)? onCreated;

  const CollectionCreator({
    super.key,
    this.onCreated,
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

  @override
  void initState() {
    super.initState();
    _loadArtworks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadArtworks() async {
    final artworkProvider = context.read<ArtworkProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final walletAddress = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );

    if (walletAddress.isEmpty) return;

    setState(() => _artworksLoading = true);
    try {
      await artworkProvider.loadArtworksForWallet(walletAddress);
    } catch (_) {
      // Non-fatal; artworks list will be empty.
    } finally {
      if (mounted) setState(() => _artworksLoading = false);
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

      widget.onCreated?.call(id);

      if (widget.onCreated == null) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.collectionCreatorCreateFailedWithError(e))),
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

    return CreatorScaffold(
      title: l10n.collectionCreatorTitle,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.md, KubusSpacing.md, KubusSpacing.md, KubusSpacing.lg,
          ),
          children: [
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
      ),
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
                final imageUrl = MediaUrlResolver.resolve(artwork.imageUrl);

                return ListTile(
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
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 20,
                                  color: scheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_outlined,
                                size: 20,
                                color: scheme.onSurface.withValues(alpha: 0.3),
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
                  subtitle: artwork.artist.isNotEmpty
                      ? Text(
                          artwork.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTextStyles.detailCaption.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        )
                      : null,
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
