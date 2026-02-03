import 'dart:async';

import 'package:art_kubus/widgets/glass_components.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../models/map_marker_subject.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/tile_providers.dart';
import '../../services/storage_config.dart';
import '../../utils/map_marker_subject_loader.dart';
import '../../utils/marker_subject_utils.dart';
import '../../utils/maplibre_style_utils.dart';
import '../../widgets/art_map_view.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class MarkerEditorView extends StatefulWidget {
  const MarkerEditorView({
    super.key,
    required this.marker,
    required this.isNew,
    this.showHeader = false,
    this.onClose,
    this.onSaved,
    this.onDeleted,
  });

  final ArtMarker? marker;
  final bool isNew;
  final bool showHeader;
  final VoidCallback? onClose;
  final ValueChanged<ArtMarker>? onSaved;
  final VoidCallback? onDeleted;

  @override
  State<MarkerEditorView> createState() => _MarkerEditorViewState();
}

class _MarkerEditorViewState extends State<MarkerEditorView> {
  static const LatLng _defaultCenter = LatLng(46.056946, 14.505751);
  static const String _editorSourceId = 'kubus_marker_editor_position';
  static const String _editorLayerId = 'kubus_marker_editor_position_layer';

  final _formKey = GlobalKey<FormState>();
  ml.MapLibreMapController? _mapController;
  bool _styleReady = false;
  bool _styleInitializationInProgress = false;
  late LatLng _position;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _activationRadiusController;

  ArtMarkerType _markerType = ArtMarkerType.artwork;
  bool _isPublic = true;
  bool _isActive = true;
  bool _requiresProximity = true;
  bool _saving = false;

  MarkerSubjectData? _subjectData;
  Map<MarkerSubjectType, List<MarkerSubjectOption>> _subjectOptionsByType =
      const <MarkerSubjectType, List<MarkerSubjectOption>>{};
  List<Artwork> _arEnabledArtworks = const <Artwork>[];
  MarkerSubjectType _subjectType = MarkerSubjectType.artwork;
  MarkerSubjectOption? _subject;
  Artwork? _linkedArtwork;
  String? _linkedArtworkId;
  bool _linkedArtworkCleared = false;
  bool _refreshingSubjects = false;

  @override
  void initState() {
    super.initState();

    final marker = widget.marker;
    final position = marker?.hasValidPosition == true ? marker!.position : _defaultCenter;
    _position = position;

    _nameController = TextEditingController(text: marker?.name ?? '');
    _descriptionController = TextEditingController(text: marker?.description ?? '');
    _categoryController = TextEditingController(text: marker?.category ?? '');
    _latController = TextEditingController(text: position.latitude.toStringAsFixed(6));
    _lngController = TextEditingController(text: position.longitude.toStringAsFixed(6));
    _activationRadiusController =
        TextEditingController(text: (marker?.activationRadius ?? 50).toStringAsFixed(0));

    _markerType = marker?.type ?? ArtMarkerType.artwork;
    _isPublic = marker?.isPublic ?? true;
    _isActive = marker?.isActive ?? true;
    _requiresProximity = marker?.requiresProximity ?? true;

    _bootstrapSubjects(marker);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSubjects(force: true));
    });
  }

  @override
  void dispose() {
    _mapController = null;
    _styleReady = false;
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _activationRadiusController.dispose();
    super.dispose();
  }

  bool _validateLatLng(double lat, double lng) => lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  void _updatePositionFromFields() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return;
    if (!_validateLatLng(lat, lng)) return;
    setState(() => _position = LatLng(lat, lng));
    unawaited(_syncEditorPositionOnMap());
    unawaited(_moveCameraTo(_position));
  }

  String _hexRgb(Color color) {
    return MapLibreStyleUtils.hexRgb(color);
  }

  Future<void> _handleMapStyleLoaded({
    required ColorScheme scheme,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    if (_styleInitializationInProgress) return;
    _styleInitializationInProgress = true;
    _styleReady = false;

    try {
      final Set<String> existingLayerIds = <String>{};
      try {
        final raw = await controller.getLayerIds();
        for (final id in raw) {
          if (id is String) existingLayerIds.add(id);
        }
      } catch (_) {}

      Future<void> safeRemoveLayer(String id) async {
        if (!existingLayerIds.contains(id)) return;
        try {
          await controller.removeLayer(id);
        } catch (_) {}
        existingLayerIds.remove(id);
      }

      await safeRemoveLayer(_editorLayerId);
      try {
        await controller.removeSource(_editorSourceId);
      } catch (_) {}

      await controller.addGeoJsonSource(
        _editorSourceId,
        _editorPositionCollection(_position),
        promoteId: 'id',
      );

      await controller.addCircleLayer(
        _editorSourceId,
        _editorLayerId,
        ml.CircleLayerProperties(
          circleRadius: 7,
          circleColor: _hexRgb(scheme.primary),
          circleOpacity: 1.0,
          circleStrokeWidth: 2,
          circleStrokeColor: _hexRgb(scheme.surface),
        ),
      );

      if (!mounted) return;
      _styleReady = true;
    } finally {
      _styleInitializationInProgress = false;
    }
  }

  Map<String, dynamic> _editorPositionCollection(LatLng position) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'id': 'editor',
          'properties': const <String, dynamic>{'id': 'editor'},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[position.longitude, position.latitude],
          },
        },
      ],
    };
  }

  Future<void> _syncEditorPositionOnMap() async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;

    await controller.setGeoJsonSource(
      _editorSourceId,
      _editorPositionCollection(_position),
    );
  }

  Future<void> _moveCameraTo(LatLng target) async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;

    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(target.latitude, target.longitude),
          zoom: 15,
        ),
      ),
      duration: const Duration(milliseconds: 240),
    );
  }

  MarkerSubjectType _parseSubjectType(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final type in MarkerSubjectType.values) {
      if (type.name == normalized) return type;
    }
    if (normalized.contains('exhibition')) return MarkerSubjectType.exhibition;
    if (normalized.contains('institution')) return MarkerSubjectType.institution;
    if (normalized.contains('event')) return MarkerSubjectType.event;
    if (normalized.contains('group') || normalized.contains('dao') || normalized.contains('residency')) {
      return MarkerSubjectType.group;
    }
    if (normalized.contains('art')) return MarkerSubjectType.artwork;
    return MarkerSubjectType.misc;
  }

  bool _subjectSelectionRequired(MarkerSubjectType type) => type != MarkerSubjectType.misc;

  bool _showOptionalArAsset(MarkerSubjectType type) =>
      type != MarkerSubjectType.artwork && type != MarkerSubjectType.misc;

  Map<MarkerSubjectType, List<MarkerSubjectOption>> _buildOptions(MarkerSubjectData data) {
    return {
      for (final type in MarkerSubjectType.values)
        type: buildSubjectOptions(
          type: type,
          artworks: data.artworks,
          exhibitions: data.exhibitions,
          institutions: data.institutions,
          events: data.events,
          delegates: data.delegates,
        ),
    };
  }

  void _bootstrapSubjects(ArtMarker? marker) {
    try {
      final loader = MarkerSubjectLoader(context);
      final snapshot = loader.snapshot();
      _subjectData = snapshot;
      _subjectOptionsByType = _buildOptions(snapshot);
      _arEnabledArtworks = snapshot.artworks.where(artworkSupportsAR).toList(growable: false);

      final requestedType = _parseSubjectType(marker?.subjectType);
      final resolvedType = requestedType == MarkerSubjectType.misc && (marker?.artworkId ?? '').trim().isNotEmpty
          ? MarkerSubjectType.artwork
          : requestedType;
      _subjectType = widget.isNew ? MarkerSubjectType.artwork : resolvedType;

      final options = _subjectOptionsByType[_subjectType] ?? const <MarkerSubjectOption>[];
      final subjectIdCandidate = (marker?.subjectId ?? '').trim().isNotEmpty
          ? marker!.subjectId!.trim()
          : ((marker?.artworkId ?? '').trim().isNotEmpty && _subjectType == MarkerSubjectType.artwork)
              ? marker!.artworkId!.trim()
              : null;

      _subject = subjectIdCandidate == null
          ? (options.isNotEmpty ? options.first : null)
          : options.where((o) => o.id == subjectIdCandidate).cast<MarkerSubjectOption?>().firstOrNull ??
              (options.isNotEmpty ? options.first : null);

      if (widget.isNew) {
        _markerType = _subjectType.defaultMarkerType;
        if (_categoryController.text.trim().isEmpty) {
          _categoryController.text = _subjectType.defaultCategory;
        }
      }

      if (widget.isNew && _subject != null) {
        if (_nameController.text.trim().isEmpty) _nameController.text = _subject!.title;
        if (_descriptionController.text.trim().isEmpty && _subject!.subtitle.trim().isNotEmpty) {
          _descriptionController.text = _subject!.subtitle;
        }
      }

      if (_subjectType == MarkerSubjectType.artwork) {
        final selectedArtworkId = _subject?.id ?? marker?.artworkId;
        _linkedArtworkId = (selectedArtworkId ?? '').trim().isEmpty ? null : selectedArtworkId!.trim();
        _linkedArtwork = findArtworkById(snapshot.artworks, _linkedArtworkId);
      } else {
        _linkedArtworkId = (marker?.artworkId ?? '').trim().isEmpty ? null : marker!.artworkId!.trim();
        _linkedArtwork = findArtworkById(_arEnabledArtworks, _linkedArtworkId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarkerEditorView: bootstrapSubjects failed: $e');
      }
    }
  }

  Future<void> _refreshSubjects({bool force = false}) async {
    if (_refreshingSubjects && !force) return;
    setState(() => _refreshingSubjects = true);
    try {
      final loader = MarkerSubjectLoader(context);
      final fresh = await loader.refresh(force: force);
      if (!mounted) return;
      final next = fresh ?? loader.snapshot();
      _subjectData = next;
      _subjectOptionsByType = _buildOptions(next);
      _arEnabledArtworks = next.artworks.where(artworkSupportsAR).toList(growable: false);

      final options = _subjectOptionsByType[_subjectType] ?? const <MarkerSubjectOption>[];
      if (_subject != null && !options.any((o) => o.id == _subject!.id)) {
        _subject = options.isNotEmpty ? options.first : null;
      }

      if (_subjectType == MarkerSubjectType.artwork) {
        final selectedArtworkId = _subject?.id ?? _linkedArtworkId;
        _linkedArtworkId = (selectedArtworkId ?? '').trim().isNotEmpty ? selectedArtworkId!.trim() : null;
        _linkedArtwork = findArtworkById(next.artworks, _linkedArtworkId);
      } else if (!_linkedArtworkCleared) {
        final keepId = _linkedArtwork?.id ?? _linkedArtworkId;
        _linkedArtworkId = (keepId ?? '').trim().isNotEmpty ? keepId!.trim() : null;
        _linkedArtwork = findArtworkById(_arEnabledArtworks, _linkedArtworkId);
      } else {
        _linkedArtwork = null;
        _linkedArtworkId = null;
      }

      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarkerEditorView: refreshSubjects failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingSubjects = false);
      }
    }
  }

  void _applySubjectType(MarkerSubjectType type) {
    setState(() {
      _subjectType = type;
      _markerType = type.defaultMarkerType;
      _categoryController.text = type.defaultCategory;

      final options = _subjectOptionsByType[type] ?? const <MarkerSubjectOption>[];
      _subject = options.isNotEmpty ? options.first : null;

      if (type == MarkerSubjectType.artwork) {
        _linkedArtworkCleared = false;
        _linkedArtworkId = _subject?.id;
        _linkedArtwork = findArtworkById(_subjectData?.artworks ?? const <Artwork>[], _linkedArtworkId);
      } else {
        _linkedArtworkCleared = false;
        _linkedArtwork = null;
        _linkedArtworkId = null;
      }

      if (_subject != null) {
        if (_nameController.text.trim().isEmpty) _nameController.text = _subject!.title;
        if (_descriptionController.text.trim().isEmpty && _subject!.subtitle.trim().isNotEmpty) {
          _descriptionController.text = _subject!.subtitle;
        }
      }
    });
  }

  void _applySubjectSelection(MarkerSubjectOption option) {
    setState(() {
      _subject = option;
      if (_nameController.text.trim().isEmpty || widget.isNew) _nameController.text = option.title;
      if ((_descriptionController.text.trim().isEmpty || widget.isNew) && option.subtitle.trim().isNotEmpty) {
        _descriptionController.text = option.subtitle;
      }

      if (_subjectType == MarkerSubjectType.artwork) {
        _linkedArtworkCleared = false;
        _linkedArtworkId = option.id;
        _linkedArtwork = findArtworkById(_subjectData?.artworks ?? const <Artwork>[], option.id);
      }
    });
  }

  Future<MarkerSubjectOption?> _pickOption({
    required AppLocalizations l10n,
    required String title,
    required String hintText,
    required List<MarkerSubjectOption> options,
    MarkerSubjectOption? selected,
  }) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    try {
      return await showKubusDialog<MarkerSubjectOption>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              final query = controller.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? options
                  : options
                      .where((o) =>
                          o.title.toLowerCase().contains(query) || o.subtitle.toLowerCase().contains(query))
                      .toList(growable: false);

              return KubusAlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: hintText,
                          isDense: true,
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.manageMarkersSearchNoResults,
                                  style: GoogleFonts.inter(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final option = filtered[index];
                                  final isSelected = selected?.id == option.id;
                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    title: Text(option.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: option.subtitle.trim().isEmpty
                                        ? null
                                        : Text(option.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    onTap: () => Navigator.of(dialogContext).pop(option),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.manageMarkersCancelButton),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
      focusNode.dispose();
    }
  }

  String _subjectTypeLabel(AppLocalizations l10n, MarkerSubjectType type) {
    switch (type) {
      case MarkerSubjectType.artwork:
        return l10n.mapMarkerSubjectTypeArtwork;
      case MarkerSubjectType.exhibition:
        return l10n.mapMarkerSubjectTypeExhibition;
      case MarkerSubjectType.institution:
        return l10n.mapMarkerSubjectTypeInstitution;
      case MarkerSubjectType.event:
        return l10n.mapMarkerSubjectTypeEvent;
      case MarkerSubjectType.group:
        return l10n.mapMarkerSubjectTypeGroup;
      case MarkerSubjectType.misc:
        return l10n.mapMarkerSubjectTypeMisc;
    }
  }

  String _describeMarkerType(AppLocalizations l10n, ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return l10n.mapMarkerLayerArtwork;
      case ArtMarkerType.institution:
        return l10n.mapMarkerLayerInstitution;
      case ArtMarkerType.event:
        return l10n.mapMarkerLayerEvent;
      case ArtMarkerType.residency:
        return l10n.mapMarkerLayerResidency;
      case ArtMarkerType.drop:
        return l10n.mapMarkerLayerDropReward;
      case ArtMarkerType.experience:
        return l10n.mapMarkerLayerArExperience;
      case ArtMarkerType.other:
        return l10n.mapMarkerLayerOther;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<MarkerManagementProvider>();
    final exhibitionsProvider = AppConfig.isFeatureEnabled('exhibitions') ? context.read<ExhibitionsProvider>() : null;

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null || !_validateLatLng(lat, lng)) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.mapMarkerDialogValidLatitudeError)));
      return;
    }

    if (_subjectSelectionRequired(_subjectType) && _subject == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.mapMarkerDialogSelectSubjectToast)));
      return;
    }

    final activationRadius = double.tryParse(_activationRadiusController.text.trim()) ?? 50;
    final category = _categoryController.text.trim();
    final markerType = _markerType.name;

    final artworkId = _subjectType == MarkerSubjectType.artwork ? _subject?.id : (_linkedArtwork?.id ?? _linkedArtworkId);
    final metadata = <String, dynamic>{
      'subjectType': _subjectType.name,
      'subjectLabel': _subjectType.label,
      if (_subject != null) ...{
        'subjectId': _subject!.id,
        'subjectTitle': _subject!.title,
        'subjectSubtitle': _subject!.subtitle,
      },
      if ((_linkedArtwork?.id ?? _linkedArtworkId)?.trim().isNotEmpty == true) ...{
        'linkedArtworkId': _linkedArtwork?.id ?? _linkedArtworkId,
        if (_linkedArtwork != null) 'linkedArtworkTitle': _linkedArtwork!.title,
      },
      'visibility': _isPublic ? 'public' : 'private',
      if (widget.isNew) 'createdFrom': 'manage_markers',
    };

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': category.isEmpty ? _subjectType.defaultCategory : category,
      // Backend DB constraint expects marker_type in {geolocation,image,qr,nfc}.
      // The app-level semantic type (artwork/event/etc.) is stored in markerType.
      'type': 'geolocation',
      'markerType': markerType,
      'latitude': lat,
      'longitude': lng,
      'artworkId': (artworkId ?? '').trim().isEmpty ? null : artworkId,
      'metadata': metadata,
      'activationRadius': activationRadius,
      'requiresProximity': _requiresProximity,
      'isPublic': _isPublic,
      'isActive': _isActive,
    };

    if (_linkedArtworkCleared) {
      payload['modelCID'] = null;
      payload['modelURL'] = null;
    } else if (_linkedArtwork != null) {
      final modelCid = (_linkedArtwork!.model3DCID ?? '').trim();
      final modelUrl = (_linkedArtwork!.model3DURL ?? '').trim();
      if (modelCid.isNotEmpty) {
        final cid = modelCid.toLowerCase();
        final isCidV0 = cid.startsWith('qm') && modelCid.length >= 46;
        final isCidV1 = cid.startsWith('b') && modelCid.length >= 20;
        if (isCidV0 || isCidV1) payload['modelCID'] = modelCid;
      }
      if (modelUrl.isNotEmpty) {
        payload['modelURL'] = StorageConfig.resolveUrl(modelUrl) ?? modelUrl;
      }
    }

    final hasCid = (payload['modelCID'] ?? '').toString().trim().isNotEmpty;
    final hasUrl = (payload['modelURL'] ?? '').toString().trim().isNotEmpty;
    if (hasCid && hasUrl) {
      payload['storageProvider'] = 'hybrid';
    } else if (hasCid) {
      payload['storageProvider'] = 'ipfs';
    } else if (hasUrl) {
      payload['storageProvider'] = 'http';
    }

    setState(() => _saving = true);
    try {
      ArtMarker? saved;
      if (widget.isNew) {
        saved = await provider.createMarker(payload);
      } else {
        final id = widget.marker?.id;
        if (id == null || id.isEmpty) return;
        saved = await provider.updateMarker(id, payload);
      }

      if (!mounted) return;
      if (saved == null) {
        messenger.showKubusSnackBar(SnackBar(content: Text(l10n.manageMarkersSaveFailed)));
        return;
      }

      if (exhibitionsProvider != null) {
        final prevMarker = widget.marker;
        final prevExhibitionId = prevMarker?.isExhibitionSubject == true
            ? (prevMarker?.subjectId ?? prevMarker?.resolvedExhibitionSummary?.id)
            : prevMarker?.resolvedExhibitionSummary?.id;
        final nextExhibitionId = _subjectType == MarkerSubjectType.exhibition ? _subject?.id : null;

        if ((prevExhibitionId ?? '').trim().isNotEmpty && prevExhibitionId != nextExhibitionId) {
          try {
            await exhibitionsProvider.unlinkExhibitionMarker(prevExhibitionId!, saved.id);
          } catch (_) {
            // Non-fatal (endpoint might not exist or user might not have permissions).
          }
        }

        if ((nextExhibitionId ?? '').trim().isNotEmpty) {
          try {
            await exhibitionsProvider.linkExhibitionMarkers(nextExhibitionId!, [saved.id]);
          } catch (_) {
            // Non-fatal.
          }

          final nextLinkedArtworkId = (_linkedArtwork?.id ?? _linkedArtworkId ?? '').trim();
          if (nextLinkedArtworkId.isNotEmpty) {
            try {
              await exhibitionsProvider.linkExhibitionArtworks(nextExhibitionId!, [nextLinkedArtworkId]);
            } catch (_) {
              // Non-fatal.
            }
          }
        }
      }

      messenger.showKubusSnackBar(
        SnackBar(content: Text(widget.isNew ? l10n.manageMarkersCreatedToast : l10n.manageMarkersUpdatedToast)),
      );
      widget.onSaved?.call(saved);
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.manageMarkersSaveFailed)));
      if (kDebugMode) {
        debugPrint('MarkerEditorView: save failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final marker = widget.marker;
    if (marker == null || marker.id.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirm = await showKubusDialog<bool>(
      context: context,
      builder: (_) => KubusAlertDialog(
        title: Text(l10n.manageMarkersDeleteConfirmTitle),
        content: Text(l10n.manageMarkersDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: Text(l10n.manageMarkersCancelButton),
          ),
          FilledButton(
            onPressed: () => navigator.pop(true),
            child: Text(l10n.manageMarkersDeleteButton),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final markerProvider = context.read<MarkerManagementProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final ok = await markerProvider.deleteMarker(marker.id);
      if (!mounted) return;
      if (!ok) {
        messenger.showKubusSnackBar(SnackBar(content: Text(l10n.manageMarkersDeleteFailed)));
        return;
      }
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.manageMarkersDeletedToast)));
      widget.onDeleted?.call();
      widget.onClose?.call();
      if (!widget.showHeader) {
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tileProviders = context.read<TileProviders>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final markerPosition = (lat != null && lng != null && _validateLatLng(lat, lng)) ? LatLng(lat, lng) : _position;

    final header = widget.showHeader
        ? Row(
            children: [
              Expanded(
                child: Text(
                  widget.isNew ? l10n.manageMarkersNewButton : l10n.manageMarkersEditTitle,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: l10n.manageMarkersCloseTooltip,
                  onPressed: _saving ? null : widget.onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          )
        : const SizedBox.shrink();

    final subjectTypeLabel = _subjectTypeLabel(l10n, _subjectType);
    final subjectOptions = _subjectOptionsByType[_subjectType] ?? const <MarkerSubjectOption>[];

    return AbsorbPointer(
      absorbing: _saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              header,
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ArtMapView(
                  initialCenter: markerPosition,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 24,
                  isDarkMode: isDarkMode,
                  styleAsset: tileProviders.mapStyleAsset(isDarkMode: isDarkMode),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _styleReady = false;
                  },
                  onStyleLoaded: () {
                    unawaited(
                      _handleMapStyleLoaded(
                        scheme: scheme,
                      ).then((_) => _syncEditorPositionOnMap()),
                    );
                  },
                  onMapClick: (_, point) {
                    setState(() {
                      _position = point;
                      _latController.text = point.latitude.toStringAsFixed(6);
                      _lngController.text = point.longitude.toStringAsFixed(6);
                    });
                    unawaited(_syncEditorPositionOnMap());
                  },
                  rotateGesturesEnabled: false,
                  compassEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.mapMarkerDialogAttachHint,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.mapMarkerDialogRefreshSubjectsTooltip,
                        onPressed: _refreshingSubjects ? null : () => unawaited(_refreshSubjects(force: true)),
                        icon: _refreshingSubjects
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MarkerSubjectType>(
                    isExpanded: true,
                    initialValue: _subjectType,
                    decoration: InputDecoration(labelText: l10n.mapMarkerDialogSubjectTypeLabel),
                    items: MarkerSubjectType.values
                        .map(
                          (type) => DropdownMenuItem<MarkerSubjectType>(
                            value: type,
                            child: Text(_subjectTypeLabel(l10n, type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      _applySubjectType(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_subjectSelectionRequired(_subjectType))
                    if (subjectOptions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l10n.mapMarkerDialogNoSubjectsAvailable(subjectTypeLabel),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      )
                    else
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving
                            ? null
                            : () async {
                                final picked = await _pickOption(
                                  l10n: l10n,
                                  title: l10n.manageMarkersPickSubjectTitle(subjectTypeLabel),
                                  hintText: l10n.manageMarkersSearchSubjectsHint,
                                  options: subjectOptions,
                                  selected: _subject,
                                );
                                if (!mounted || picked == null) return;
                                _applySubjectSelection(picked);
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.mapMarkerDialogSubjectRequiredLabel(subjectTypeLabel),
                            border: const OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (_subject?.title ?? l10n.mapMarkerDialogSelectSubjectToast).trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: scheme.onSurface.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        l10n.mapMarkerDialogMiscHint,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  if (_showOptionalArAsset(_subjectType)) ...[
                    const SizedBox(height: 12),
                    if (_arEnabledArtworks.isEmpty)
                      Text(
                        l10n.mapMarkerDialogNoArEnabledArtworksHint,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      )
                    else
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving
                            ? null
                            : () async {
                                final options = _arEnabledArtworks
                                    .map(
                                      (a) => MarkerSubjectOption(
                                        type: MarkerSubjectType.artwork,
                                        id: a.id,
                                        title: a.title,
                                        subtitle: a.description,
                                      ),
                                    )
                                    .toList(growable: false);
                                final selected = (_linkedArtworkId ?? '').trim().isEmpty
                                    ? null
                                    : options
                                        .where((o) => o.id == _linkedArtworkId)
                                        .cast<MarkerSubjectOption?>()
                                        .firstOrNull;

                                final picked = await _pickOption(
                                  l10n: l10n,
                                  title: l10n.manageMarkersPickArAssetTitle,
                                  hintText: l10n.manageMarkersSearchArAssetsHint,
                                  options: options,
                                  selected: selected,
                                );
                                if (!mounted || picked == null) return;
                                setState(() {
                                  _linkedArtworkCleared = false;
                                  _linkedArtworkId = picked.id;
                                  _linkedArtwork = findArtworkById(_arEnabledArtworks, picked.id);
                                });
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.mapMarkerDialogLinkedArAssetTitle,
                            border: const OutlineInputBorder(),
                            suffixIcon: (_linkedArtworkId ?? '').trim().isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l10n.manageMarkersClearSelectionTooltip,
                                    onPressed: () => setState(() {
                                      _linkedArtworkCleared = true;
                                      _linkedArtwork = null;
                                      _linkedArtworkId = null;
                                    }),
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (_linkedArtwork?.title ?? l10n.manageMarkersPickArAssetPlaceholder).trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: scheme.onSurface.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(labelText: l10n.mapMarkerDialogCategoryLabel),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ArtMarkerType>(
                    isExpanded: true,
                    initialValue: _markerType,
                    decoration: InputDecoration(labelText: l10n.mapMarkerDialogMarkerLayerLabel),
                    items: ArtMarkerType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_describeMarkerType(l10n, type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _markerType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.mapMarkerDialogMarkerTitleLabel),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return l10n.mapMarkerDialogEnterTitleError;
                      if (v.length < 3) return l10n.mapMarkerDialogTitleMinLengthError(3);
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: l10n.mapMarkerDialogDescriptionLabel),
                    minLines: 2,
                    maxLines: 4,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return l10n.mapMarkerDialogEnterDescriptionError;
                      if (v.length < 10) return l10n.mapMarkerDialogDescriptionMinLengthError(10);
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: InputDecoration(labelText: l10n.mapMarkerDialogLatitudeLabel),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => _updatePositionFromFields(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: InputDecoration(labelText: l10n.mapMarkerDialogLongitudeLabel),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => _updatePositionFromFields(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _activationRadiusController,
                    decoration: InputDecoration(labelText: l10n.manageMarkersActivationRadiusLabel),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.manageMarkersPublishedToggleTitle),
                  ),
                  SwitchListTile.adaptive(
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.mapMarkerDialogPublicMarkerTitle),
                    subtitle: Text(l10n.mapMarkerDialogPublicMarkerSubtitle),
                  ),
                  SwitchListTile.adaptive(
                    value: _requiresProximity,
                    onChanged: (value) => setState(() => _requiresProximity = value),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.manageMarkersRequiresProximityTitle),
                    subtitle: Text(l10n.manageMarkersRequiresProximitySubtitle),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                                )
                              : Text(widget.isNew ? l10n.manageMarkersCreateButton : l10n.manageMarkersSaveButton),
                        ),
                      ),
                      if (!widget.isNew) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _saving ? null : _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                          ),
                          child: Text(l10n.manageMarkersDeleteButton),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
