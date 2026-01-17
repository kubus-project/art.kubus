import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../providers/artwork_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
 

class ArtworkEditScreen extends StatefulWidget {
  final String artworkId;
  final bool showAppBar;

  const ArtworkEditScreen({
    super.key,
    required this.artworkId,
    this.showAppBar = true,
  });

  @override
  State<ArtworkEditScreen> createState() => _ArtworkEditScreenState();
}

class _ArtworkEditScreenState extends State<ArtworkEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _priceController;
  late final TextEditingController _arScaleController;

  bool _loading = true;
  String? _error;
  bool _seeded = false;

  Uint8List? _nextCoverBytes;
  String? _nextCoverName;
  Uint8List? _nextModelBytes;
  String? _nextModelName;

  bool _isSaving = false;
  bool _arEnabled = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _categoryController = TextEditingController();
    _tagsController = TextEditingController();
    _locationNameController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _priceController = TextEditingController();
    _arScaleController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _locationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _priceController.dispose();
    _arScaleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<ArtworkProvider>();
    final l10n = AppLocalizations.of(context);
    final id = widget.artworkId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = l10n?.artworkNotFound;
      });
      return;
    }

    try {
      await provider.fetchArtworkIfNeeded(id);
    } catch (_) {
      // Surface a friendly error; provider already logs in debug.
      _error = l10n?.artDetailLoadFailedMessage;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _seedFromArtworkIfReady();
      }
    }
  }

  void _seedFromArtworkIfReady() {
    if (_seeded) return;
    final artwork = context.read<ArtworkProvider>().getArtworkById(widget.artworkId);
    if (artwork == null) return;

    _titleController.text = artwork.title;
    _descriptionController.text = artwork.description;
    _categoryController.text = artwork.category;
    _tagsController.text = artwork.tags.join(', ');
    _locationNameController.text = (artwork.metadata?['locationName'] ??
            artwork.metadata?['location_name'] ??
            '')
        .toString();
    _latitudeController.text = artwork.position.latitude.toString();
    _longitudeController.text = artwork.position.longitude.toString();
    _priceController.text = artwork.price?.toString() ?? '';
    _arScaleController.text = artwork.arScale?.toString() ?? '';

    _arEnabled = artwork.arEnabled;
    _seeded = true;
    setState(() {});
  }

  Future<void> _pickCover() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = (result != null && result.files.isNotEmpty) ? result.files.first : null;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      setState(() {
        _nextCoverBytes = Uint8List.fromList(bytes);
        _nextCoverName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  Future<void> _pickModel() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf', 'usdz', 'zip'],
        withData: true,
      );
      final file = (result != null && result.files.isNotEmpty) ? result.files.first : null;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      setState(() {
        _nextModelBytes = Uint8List.fromList(bytes);
        _nextModelName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ArtworkProvider>();
    final artwork = provider.getArtworkById(widget.artworkId);
    if (artwork == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonSomethingWentWrong)));
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    setState(() => _isSaving = true);

    final updates = <String, dynamic>{};
    if (title != artwork.title) updates['title'] = title;
    if (description != artwork.description) updates['description'] = description;

    final category = _categoryController.text.trim();
    if (category.isNotEmpty && category != artwork.category) {
      updates['category'] = category;
    }

    final tagsRaw = _tagsController.text.trim();
    if (tagsRaw.isNotEmpty) {
      final tags = tagsRaw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(growable: false);
      if (!listEquals(tags, artwork.tags)) {
        updates['tags'] = tags;
      }
    } else if (artwork.tags.isNotEmpty) {
      updates['tags'] = <String>[];
    }

    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat != null && lng != null) {
      if (lat != artwork.position.latitude) updates['latitude'] = lat;
      if (lng != artwork.position.longitude) updates['longitude'] = lng;
    }

    final locationName = _locationNameController.text.trim();
    if (locationName.isNotEmpty) {
      updates['locationName'] = locationName;
    }

    final nextPriceRaw = _priceController.text.trim();
    final nextPrice = nextPriceRaw.isEmpty ? null : double.tryParse(nextPriceRaw);
    if (nextPriceRaw.isNotEmpty && nextPrice == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      setState(() => _isSaving = false);
      return;
    }
    if (nextPrice != artwork.price) {
      updates['price'] = nextPrice;
    }

    final nextArScaleRaw = _arScaleController.text.trim();
    final nextArScale = nextArScaleRaw.isEmpty ? null : double.tryParse(nextArScaleRaw);
    if (nextArScaleRaw.isNotEmpty && nextArScale == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      setState(() => _isSaving = false);
      return;
    }
    if (nextArScale != artwork.arScale) {
      updates['arScale'] = nextArScale;
    }

    if (_arEnabled != artwork.arEnabled) {
      updates['isAREnabled'] = _arEnabled;
    }

    try {
      if (_nextCoverBytes != null) {
        final upload = await BackendApiService().uploadFile(
          fileBytes: _nextCoverBytes!,
          fileName: _nextCoverName ?? 'artwork_cover.jpg',
          fileType: 'image',
          metadata: const {'uploadFolder': 'artworks/covers', 'source': 'artwork_edit'},
        );
        final coverUrl = (upload['uploadedUrl'] as String?) ?? (upload['data']?['url'] as String?);
        final coverCid = (upload['cid'] as String?) ?? (upload['data']?['cid'] as String?);
        if (coverUrl != null && coverUrl.isNotEmpty) {
          updates['imageUrl'] = coverUrl;
        }
        if (coverCid != null && coverCid.isNotEmpty) {
          updates['imageCid'] = coverCid;
        }
      }

      if (_arEnabled && _nextModelBytes != null) {
        final upload = await BackendApiService().uploadFile(
          fileBytes: _nextModelBytes!,
          fileName: _nextModelName ?? 'ar_model.glb',
          fileType: 'model',
          metadata: const {'uploadFolder': 'ar/models', 'source': 'artwork_edit'},
        );
        final modelUrl = (upload['uploadedUrl'] as String?) ?? (upload['data']?['url'] as String?);
        final modelCid = (upload['cid'] as String?) ?? (upload['data']?['cid'] as String?);
        if (modelUrl != null && modelUrl.isNotEmpty) {
          updates['model3DURL'] = modelUrl;
        }
        if (modelCid != null && modelCid.isNotEmpty) {
          updates['model3DCID'] = modelCid;
        }
      }

      final updated = await provider.updateArtwork(widget.artworkId, updates);
      if (!mounted) return;

      if (updated == null) {
        messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
        setState(() => _isSaving = false);
        return;
      }

      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonSavedToast)));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final provider = context.watch<ArtworkProvider>();
    final artwork = provider.getArtworkById(widget.artworkId);
    _seedFromArtworkIfReady();

    final art = artwork;
    final coverUrl = art == null ? null : ArtworkMediaResolver.resolveCover(artwork: art);

    final Widget? body = art == null
        ? null
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
        DetailCard(
          padding: const EdgeInsets.all(DetailSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.commonCoverImage,
                      style: DetailTypography.sectionTitle(context),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : _pickCover,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: l10n.commonEdit,
                  ),
                ],
              ),
              const SizedBox(height: DetailSpacing.md),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DetailRadius.md),
                  child: _nextCoverBytes != null
                      ? Image.memory(_nextCoverBytes!, fit: BoxFit.cover)
                      : (coverUrl != null && coverUrl.isNotEmpty)
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(Icons.image_not_supported, color: scheme.outline),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.image_outlined, color: scheme.outline),
                            ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DetailSpacing.lg),
        TextField(
          controller: _titleController,
          enabled: !_isSaving,
          decoration: InputDecoration(labelText: l10n.commonTitle),
        ),
        const SizedBox(height: DetailSpacing.md),
        TextField(
          controller: _descriptionController,
          enabled: !_isSaving,
          maxLines: 5,
          decoration: InputDecoration(labelText: l10n.commonDescription),
        ),
        const SizedBox(height: DetailSpacing.md),
        TextField(
          controller: _categoryController,
          enabled: !_isSaving,
          decoration: InputDecoration(labelText: l10n.mapMarkerDialogCategoryLabel),
        ),
        const SizedBox(height: DetailSpacing.md),
        TextField(
          controller: _tagsController,
          enabled: !_isSaving,
          decoration: InputDecoration(hintText: l10n.communitySearchSheetHintTags),
        ),
        const SizedBox(height: DetailSpacing.lg),
        DetailCard(
          padding: const EdgeInsets.all(DetailSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.commonPrice, style: DetailTypography.sectionTitle(context)),
              const SizedBox(height: DetailSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.commonPrice),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DetailSpacing.lg),
        DetailCard(
          padding: const EdgeInsets.all(DetailSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.exhibitionCreatorLocationLabel, style: DetailTypography.sectionTitle(context)),
              const SizedBox(height: DetailSpacing.md),
              TextField(
                controller: _locationNameController,
                enabled: !_isSaving,
                decoration: InputDecoration(labelText: l10n.exhibitionCreatorLocationLabel),
              ),
              const SizedBox(height: DetailSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latitudeController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.mapMarkerDialogLatitudeLabel),
                    ),
                  ),
                  const SizedBox(width: DetailSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _longitudeController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.mapMarkerDialogLongitudeLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DetailSpacing.lg),
        if (AppConfig.enableARViewer) ...[
          DetailCard(
            padding: const EdgeInsets.all(DetailSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l10n.mapArReadyChipLabel, style: DetailTypography.sectionTitle(context)),
                    ),
                    Switch(
                      value: _arEnabled,
                      onChanged: _isSaving ? null : (v) => setState(() => _arEnabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: DetailSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _arScaleController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.arDetailScaleLabel),
                      ),
                    ),
                    const SizedBox(width: DetailSpacing.md),
                    IconButton(
                      onPressed: _isSaving || !_arEnabled ? null : _pickModel,
                      icon: const Icon(Icons.upload_file),
                      tooltip: l10n.commonEdit,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DetailSpacing.lg),
        ],
        if (AppConfig.isFeatureEnabled('collabInvites')) ...[
          CollaborationPanel(entityType: 'artworks', entityId: art.id),
          const SizedBox(height: DetailSpacing.lg),
        ],
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving ? const SizedBox(width: 18, height: 18, child: InlineLoading(tileSize: 6)) : const Icon(Icons.save),
          label: Text(l10n.commonSave),
        ),
            ],
          );

    Widget content;
    if (_loading) {
      content = const Center(child: InlineLoading());
    } else if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(DetailSpacing.xl),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    } else if (artwork == null) {
      content = Center(child: Text(l10n.artworkNotFound));
    } else {
      content = body!;
    }

    if (!widget.showAppBar) {
      return Container(color: scheme.surface, child: content);
    }

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(l10n.commonEdit),
          actions: [
            IconButton(
              onPressed: _isSaving || _loading ? null : _save,
              icon: const Icon(Icons.check),
              tooltip: l10n.commonSave,
            ),
          ],
        ),
        body: content,
      ),
    );
  }
}
