import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import '../../../services/backend_api_service.dart';
import '../../../providers/collections_provider.dart';
import '../../../utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    final scheme = Theme.of(context).colorScheme;
    final studioAccent = KubusColorRoles.of(context).web3ArtistStudioAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.collectionCreatorTitle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              l10n.collectionSettingsBasicInfo,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.collectionSettingsName,
                hintText: l10n.collectionSettingsNameHint,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return l10n.collectionCreatorNameRequiredError;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.collectionSettingsDescriptionLabel,
                hintText: l10n.collectionSettingsDescriptionHint,
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.commonCoverImage,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
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
                          },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _coverBytes == null ? l10n.commonUpload : l10n.commonChangeCover,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.commonRemove,
                  onPressed: (_isSubmitting || _coverBytes == null)
                      ? null
                      : () => setState(() {
                            _coverBytes = null;
                            _coverFileName = null;
                          }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (_coverBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                  child: Image.memory(
                    _coverBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              value: _isPublic,
              onChanged: _isSubmitting ? null : (v) => setState(() => _isPublic = v),
              title: Text(l10n.collectionSettingsPublic),
              subtitle: Text(l10n.collectionSettingsPublicSubtitle),
              activeThumbColor: studioAccent,
              activeTrackColor: studioAccent.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: studioAccent,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                      )
                    : Text(
                        l10n.commonCreate,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
