import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/map_marker_subject.dart';
import '../../../config/config.dart';
import '../../../utils/marker_subject_utils.dart';
import '../../../utils/map_marker_subject_loader.dart';
import '../../map_marker_dialog.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'kubus_marker_form_content_parts.dart';

/// Reusable stateful form body for creating a map marker.
///
/// Used by both [MapMarkerDialog] (mobile dialog/sheet) and
/// [KubusCreateMarkerPanel] (desktop sidebar).
class KubusMarkerFormContent extends StatefulWidget {
  final MarkerSubjectData subjectData;
  final Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects;
  final LatLng initialPosition;
  final bool allowManualPosition;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;
  final MarkerSubjectType initialSubjectType;
  final Set<MarkerSubjectType>? allowedSubjectTypes;
  final Set<String> blockedArtworkIds;
  final ValueChanged<MapMarkerFormResult> onSubmit;
  final VoidCallback onCancel;

  /// When true, the header row (title, refresh, close) is rendered by this
  /// widget. Set to false when the parent already provides its own header.
  final bool showHeader;

  const KubusMarkerFormContent({
    super.key,
    required this.subjectData,
    required this.onRefreshSubjects,
    required this.initialPosition,
    this.allowManualPosition = false,
    this.mapCenter,
    this.onUseMapCenter,
    this.initialSubjectType = MarkerSubjectType.artwork,
    this.allowedSubjectTypes,
    this.blockedArtworkIds = const {},
    required this.onSubmit,
    required this.onCancel,
    this.showHeader = true,
  });

  @override
  State<KubusMarkerFormContent> createState() => _KubusMarkerFormContentState();
}

class _KubusMarkerFormContentState extends State<KubusMarkerFormContent> {
  late MarkerSubjectData _subjectData;
  late Map<MarkerSubjectType, List<MarkerSubjectOption>> _subjectOptionsByType;
  late List<Artwork> _arEnabledArtworks;

  late final Set<MarkerSubjectType> _allowedTypes;
  late final Set<ArtMarkerType> _allowedMarkerTypes;

  late MarkerSubjectType _selectedSubjectType;
  MarkerSubjectOption? _selectedSubject;
  Artwork? _selectedArAsset;
  late ArtMarkerType _selectedMarkerType;
  bool _isPublic = true;
  bool _isCommunity = false;
  Uint8List? _coverImageBytes;
  String? _coverImageFileName;
  String? _coverImageFileType;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  final _formKey = GlobalKey<FormState>();

  bool _refreshScheduled = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    final defaultTypes = Set<MarkerSubjectType>.from(MarkerSubjectType.values);
    _allowedMarkerTypes = Set<ArtMarkerType>.from(ArtMarkerType.values);
    if (!AppConfig.isFeatureEnabled('streetArtMarkers')) {
      defaultTypes.remove(MarkerSubjectType.streetArt);
      _allowedMarkerTypes.remove(ArtMarkerType.streetArt);
    }
    _allowedTypes = widget.allowedSubjectTypes ?? defaultTypes;
    _subjectData = widget.subjectData;
    _subjectOptionsByType = _buildOptions(_subjectData);
    _arEnabledArtworks = _subjectData.artworks
        .where(artworkSupportsAR)
        .where((art) => !widget.blockedArtworkIds.contains(art.id))
        .toList();

    _selectedSubjectType =
        _resolveInitialSubjectType(widget.initialSubjectType);
    _selectedSubject =
        _subjectOptionsByType[_selectedSubjectType]?.isNotEmpty == true
            ? _subjectOptionsByType[_selectedSubjectType]!.first
            : null;
    _selectedArAsset =
        _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
    _selectedMarkerType = _selectedSubjectType.defaultMarkerType;
    _isCommunity = _isStreetArtSelection();
    _categoryController.text = _selectedSubjectType.defaultCategory;
    _titleController.text = _selectedSubject?.title ?? '';
    _descriptionController.text = _selectedSubject?.subtitle ?? '';
    _latController = TextEditingController(
        text: widget.initialPosition.latitude.toStringAsFixed(6));
    _lngController = TextEditingController(
        text: widget.initialPosition.longitude.toStringAsFixed(6));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleRefresh(force: true);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Map<MarkerSubjectType, List<MarkerSubjectOption>> _buildOptions(
    MarkerSubjectData data,
  ) {
    return {
      for (final type in MarkerSubjectType.values)
        if (_allowedTypes.contains(type))
          type: buildSubjectOptions(
            type: type,
            artworks: type == MarkerSubjectType.artwork
                ? data.artworks
                    .where((art) => !widget.blockedArtworkIds.contains(art.id))
                    .toList()
                : data.artworks,
            exhibitions: data.exhibitions,
            institutions: data.institutions,
            events: data.events,
            delegates: data.delegates,
          ),
    };
  }

  bool _subjectSelectionRequired(MarkerSubjectType type) =>
      type != MarkerSubjectType.misc && type != MarkerSubjectType.streetArt;
  bool _showOptionalArAsset(MarkerSubjectType type) =>
      type != MarkerSubjectType.artwork &&
      type != MarkerSubjectType.misc &&
      type != MarkerSubjectType.streetArt;

  MarkerSubjectType _resolveInitialSubjectType(MarkerSubjectType requested) {
    if (_allowedTypes.contains(requested)) {
      return requested;
    }
    for (final type in MarkerSubjectType.values) {
      if (_allowedTypes.contains(type)) return type;
    }
    return MarkerSubjectType.artwork;
  }

  Artwork? _resolveDefaultAsset(
    MarkerSubjectType type,
    MarkerSubjectOption? option,
  ) {
    if (type == MarkerSubjectType.artwork) {
      return findArtworkById(_subjectData.artworks, option?.id);
    }
    return null;
  }

  bool _isStreetArtSelection({
    MarkerSubjectType? subjectType,
    ArtMarkerType? markerType,
  }) {
    final resolvedSubject = subjectType ?? _selectedSubjectType;
    final resolvedMarker = markerType ?? _selectedMarkerType;
    return resolvedSubject == MarkerSubjectType.streetArt ||
        resolvedMarker == ArtMarkerType.streetArt;
  }

  Future<void> _scheduleRefresh({bool force = false}) async {
    if (_refreshScheduled && !force) return;
    _refreshScheduled = true;
    setState(() => _refreshing = true);
    try {
      final fresh = await widget.onRefreshSubjects(force: true);
      if (!mounted) return;
      if (fresh != null) {
        _subjectData = fresh;
        _subjectOptionsByType = _buildOptions(_subjectData);
        _arEnabledArtworks = _subjectData.artworks
            .where(artworkSupportsAR)
            .where((art) => !widget.blockedArtworkIds.contains(art.id))
            .toList();

        final currentOptions =
            _subjectOptionsByType[_selectedSubjectType] ?? [];
        if (_selectedSubject != null &&
            !currentOptions
                .any((option) => option.id == _selectedSubject!.id)) {
          _selectedSubject =
              currentOptions.isNotEmpty ? currentOptions.first : null;
        }

        if (_selectedSubjectType == MarkerSubjectType.artwork) {
          _selectedArAsset =
              _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
        } else {
          if (_selectedArAsset != null &&
              !_arEnabledArtworks
                  .any((art) => art.id == _selectedArAsset!.id)) {
            _selectedArAsset = null;
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _refreshScheduled = false;
        });
      }
    }
  }

  void _applySubjectType(MarkerSubjectType type) {
    setState(() {
      _selectedSubjectType = type;
      _selectedMarkerType = type.defaultMarkerType;
      if (_isStreetArtSelection(
        subjectType: type,
        markerType: _selectedMarkerType,
      )) {
        _isCommunity = true;
      }
      _categoryController.text = type.defaultCategory;

      final options = _subjectOptionsByType[_selectedSubjectType] ?? [];
      _selectedSubject = options.isNotEmpty ? options.first : null;
      _selectedArAsset =
          _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
    });
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;

    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
      return;
    }

    final fallbackFileName = 'street-art-cover.png';
    final fileName = (file?.name ?? '').trim().isNotEmpty
        ? file!.name.trim()
        : fallbackFileName;

    setState(() {
      _coverImageBytes = bytes;
      _coverImageFileName = fileName;
      _coverImageFileType = _resolveImageMimeType(fileName);
    });
  }

  void _removeCoverImage() {
    setState(() {
      _coverImageBytes = null;
      _coverImageFileName = null;
      _coverImageFileType = null;
    });
  }

  String _resolveImageMimeType(String fileName) {
    final lower = fileName.trim().toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          KubusMarkerFormHeader(
            isRefreshing: _refreshing,
            onRefresh: () => _scheduleRefresh(force: true),
            onClose: widget.onCancel,
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        Expanded(
          child: KubusMarkerFormBody(
            formKey: _formKey,
            allowedTypes: _allowedTypes,
            allowedMarkerTypes: _allowedMarkerTypes,
            selectedSubjectType: _selectedSubjectType,
            subjectOptionsByType: _subjectOptionsByType,
            selectedSubject: _selectedSubject,
            arEnabledArtworks: _arEnabledArtworks,
            selectedArAsset: _selectedArAsset,
            selectedMarkerType: _selectedMarkerType,
            isPublic: _isPublic,
            isCommunity: _isCommunity,
            allowManualPosition: widget.allowManualPosition,
            mapCenter: widget.mapCenter,
            onUseMapCenter: widget.mapCenter != null &&
                    widget.onUseMapCenter != null
                ? () {
                    widget.onUseMapCenter!();
                    final center = widget.mapCenter!;
                    setState(() {
                      _latController.text =
                          center.latitude.toStringAsFixed(6);
                      _lngController.text =
                          center.longitude.toStringAsFixed(6);
                    });
                  }
                : null,
            titleController: _titleController,
            descriptionController: _descriptionController,
            categoryController: _categoryController,
            latController: _latController,
            lngController: _lngController,
            subjectSelectionRequired: _subjectSelectionRequired(
              _selectedSubjectType,
            ),
            showOptionalArAsset: _showOptionalArAsset(_selectedSubjectType),
            isStreetArtSelection: _isStreetArtSelection(),
            onSubjectTypeChanged: _applySubjectType,
            onSubjectChanged: (value) {
              setState(() {
                _selectedSubject = value;
                _titleController.text = value.title;
                _descriptionController.text = value.subtitle.isNotEmpty
                    ? value.subtitle
                    : AppLocalizations.of(context)!
                        .mapMarkerDialogMarkerForTitle(value.title);
                if (_selectedSubjectType == MarkerSubjectType.artwork) {
                  _selectedArAsset =
                      findArtworkById(_subjectData.artworks, value.id);
                }
              });
            },
            onArAssetChanged: (value) =>
                setState(() => _selectedArAsset = value),
            onMarkerTypeChanged: (value) =>
                setState(() => _selectedMarkerType = value),
            onPublicChanged: (value) => setState(() => _isPublic = value),
            onCommunityChanged: (value) =>
                setState(() => _isCommunity = value),
            onPickCover: _pickCoverImage,
            onRemoveCover: _removeCoverImage,
            coverImageBytes: _coverImageBytes,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        KubusMarkerFormActionsRow(
          onCancel: widget.onCancel,
          onSubmit: _submit,
        ),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_isStreetArtSelection() && _coverImageBytes == null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.mapMarkerDialogStreetArtCoverRequiredError),
        ),
      );
      return;
    }
    if (_subjectSelectionRequired(_selectedSubjectType) &&
        _selectedSubject == null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.mapMarkerDialogSelectSubjectToast)),
      );
      return;
    }

    LatLng? manualPosition;
    if (widget.allowManualPosition) {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat != null && lng != null) {
        manualPosition = LatLng(lat, lng);
      }
    }

    widget.onSubmit(
      MapMarkerFormResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        markerType: _selectedMarkerType,
        subjectType: _selectedSubjectType,
        subject: _selectedSubject,
        linkedArtwork: _selectedArAsset,
        isPublic: _isPublic,
        isCommunity: _isCommunity,
        positionOverride: manualPosition,
        coverImageBytes: _coverImageBytes,
        coverImageFileName: _coverImageFileName,
        coverImageFileType: _coverImageFileType,
      ),
    );
  }

}
