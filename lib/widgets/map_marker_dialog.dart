import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../models/map_marker_subject.dart';
import '../utils/marker_subject_utils.dart';
import '../utils/map_marker_subject_loader.dart';
import 'glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class MapMarkerFormResult {
  final String title;
  final String description;
  final String category;
  final ArtMarkerType markerType;
  final MarkerSubjectType subjectType;
  final MarkerSubjectOption? subject;
  final Artwork? linkedArtwork;
  final bool isPublic;
  final LatLng? positionOverride;

  const MapMarkerFormResult({
    required this.title,
    required this.description,
    required this.category,
    required this.markerType,
    required this.subjectType,
    required this.isPublic,
    this.subject,
    this.linkedArtwork,
    this.positionOverride,
  });
}

class MapMarkerDialog extends StatefulWidget {
  final MarkerSubjectData subjectData;
  final Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects;
  final LatLng initialPosition;
  final bool allowManualPosition;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;
  final MarkerSubjectType initialSubjectType;
  final Set<MarkerSubjectType>? allowedSubjectTypes;
  final Set<String> blockedArtworkIds;
  final bool useSheet;

  const MapMarkerDialog({
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
    this.useSheet = false,
  });

  static Future<MapMarkerFormResult?> show({
    required BuildContext context,
    required MarkerSubjectData subjectData,
    required Future<MarkerSubjectData?> Function({bool force}) onRefreshSubjects,
    required LatLng initialPosition,
    bool allowManualPosition = false,
    LatLng? mapCenter,
    VoidCallback? onUseMapCenter,
    MarkerSubjectType initialSubjectType = MarkerSubjectType.artwork,
    Set<MarkerSubjectType>? allowedSubjectTypes,
    Set<String> blockedArtworkIds = const {},
    bool useSheet = false,
  }) {
    if (useSheet) {
      return showModalBottomSheet<MapMarkerFormResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
              child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: KubusSizes.dialogWidthMd + KubusSizes.sidebarActionIconBox,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Material(
                color: Colors.transparent,
                child: MapMarkerDialog(
                  subjectData: subjectData,
                  onRefreshSubjects: onRefreshSubjects,
                  initialPosition: initialPosition,
                  allowManualPosition: allowManualPosition,
                  mapCenter: mapCenter,
                  onUseMapCenter: onUseMapCenter,
                  initialSubjectType: initialSubjectType,
                  allowedSubjectTypes: allowedSubjectTypes,
                  blockedArtworkIds: blockedArtworkIds,
                  useSheet: true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return showKubusDialog<MapMarkerFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MapMarkerDialog(
        subjectData: subjectData,
        onRefreshSubjects: onRefreshSubjects,
        initialPosition: initialPosition,
        allowManualPosition: allowManualPosition,
        mapCenter: mapCenter,
        onUseMapCenter: onUseMapCenter,
        initialSubjectType: initialSubjectType,
        allowedSubjectTypes: allowedSubjectTypes,
        blockedArtworkIds: blockedArtworkIds,
      ),
    );
  }

  @override
  State<MapMarkerDialog> createState() => _MapMarkerDialogState();
}

class _MapMarkerDialogState extends State<MapMarkerDialog> {
  late MarkerSubjectData _subjectData;
  late Map<MarkerSubjectType, List<MarkerSubjectOption>> _subjectOptionsByType;
  late List<Artwork> _arEnabledArtworks;

  late final Set<MarkerSubjectType> _allowedTypes;

  late MarkerSubjectType _selectedSubjectType;
  MarkerSubjectOption? _selectedSubject;
  Artwork? _selectedArAsset;
  late ArtMarkerType _selectedMarkerType;
  bool _isPublic = true;

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
    _allowedTypes = widget.allowedSubjectTypes ?? Set<MarkerSubjectType>.from(MarkerSubjectType.values);
    _subjectData = widget.subjectData;
    _subjectOptionsByType = _buildOptions(_subjectData);
    _arEnabledArtworks = _subjectData.artworks
      .where(artworkSupportsAR)
      .where((art) => !widget.blockedArtworkIds.contains(art.id))
      .toList();

    _selectedSubjectType = _resolveInitialSubjectType(widget.initialSubjectType);
    _selectedSubject = _subjectOptionsByType[_selectedSubjectType]?.isNotEmpty == true
        ? _subjectOptionsByType[_selectedSubjectType]!.first
        : null;
    _selectedArAsset = _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
    _selectedMarkerType = _selectedSubjectType.defaultMarkerType;
    _categoryController.text = _selectedSubjectType.defaultCategory;
    _titleController.text = _selectedSubject?.title ?? '';
    _descriptionController.text = _selectedSubject?.subtitle ?? '';
    _latController =
        TextEditingController(text: widget.initialPosition.latitude.toStringAsFixed(6));
    _lngController =
        TextEditingController(text: widget.initialPosition.longitude.toStringAsFixed(6));

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
      type != MarkerSubjectType.misc;
  bool _showOptionalArAsset(MarkerSubjectType type) =>
      type != MarkerSubjectType.artwork && type != MarkerSubjectType.misc;

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
    // For artwork markers, link the selected artwork even if it's not AR-enabled.
    if (type == MarkerSubjectType.artwork) {
      return findArtworkById(_subjectData.artworks, option?.id);
    }
    // For other subjects, an AR-linked artwork is optional.
    return null;
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

        final currentOptions = _subjectOptionsByType[_selectedSubjectType] ?? [];
        if (_selectedSubject != null &&
            !currentOptions.any((option) => option.id == _selectedSubject!.id)) {
          _selectedSubject = currentOptions.isNotEmpty ? currentOptions.first : null;
        }

        if (_selectedSubjectType == MarkerSubjectType.artwork) {
          _selectedArAsset = _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
        } else {
          if (_selectedArAsset != null &&
              !_arEnabledArtworks.any((art) => art.id == _selectedArAsset!.id)) {
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
      _categoryController.text = type.defaultCategory;

      final options = _subjectOptionsByType[_selectedSubjectType] ?? [];
      _selectedSubject = options.isNotEmpty ? options.first : null;
      _selectedArAsset = _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = media.size.height * (widget.useSheet ? 0.9 : 0.75);
    final viewInsets = media.viewInsets.bottom;

    final formContent = _buildFormContent(scheme, maxHeight, viewInsets);

    if (widget.useSheet) {
      return Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KubusRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_location_alt, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    l10n.mapMarkerDialogTitle,
                    style: KubusTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: _refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: l10n.mapMarkerDialogRefreshSubjectsTooltip,
                    onPressed: _refreshing ? null : () => _scheduleRefresh(force: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              formContent,
              const SizedBox(height: 12),
              _buildActionsRow(scheme),
            ],
          ),
        ),
      );
    }

    return KubusAlertDialog(
      backgroundColor: scheme.surface,
      contentPadding: const EdgeInsets.fromLTRB(
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.md + KubusSpacing.xs,
        KubusSpacing.sm + KubusSpacing.xs,
      ),
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: scheme.primary),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
          Text(
            l10n.mapMarkerDialogTitle,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
              tooltip: l10n.mapMarkerDialogRefreshSubjectsTooltip,
            onPressed: _refreshing ? null : () => _scheduleRefresh(force: true),
          ),
        ],
      ),
      content: formContent,
      actions: _buildDialogActions(scheme),
    );
  }

  Widget _buildFormContent(ColorScheme scheme, double maxHeight, double viewInsets) {
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mapMarkerDialogAttachHint,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<MarkerSubjectType>(
                isExpanded: true,
                initialValue: _selectedSubjectType,
                decoration: InputDecoration(
                  labelText: l10n.mapMarkerDialogSubjectTypeLabel,
                  border: OutlineInputBorder(
                    borderRadius: KubusRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: MarkerSubjectType.values
                    .where(_allowedTypes.contains)
                    .map(
                      (type) => DropdownMenuItem<MarkerSubjectType>(
                        value: type,
                        child: Text(_subjectTypeLabel(l10n, type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _applySubjectType(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_subjectSelectionRequired(_selectedSubjectType))
                if ((_subjectOptionsByType[_selectedSubjectType] ?? []).isNotEmpty)
                  DropdownButtonFormField<MarkerSubjectOption>(
                    isExpanded: true,
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                      labelText: l10n.mapMarkerDialogSubjectRequiredLabel(
                        _subjectTypeLabel(l10n, _selectedSubjectType),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: KubusRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: (_subjectOptionsByType[_selectedSubjectType] ?? [])
                        .map(
                          (option) => DropdownMenuItem<MarkerSubjectOption>(
                            value: option,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(option.title,
                                    style:
                                        KubusTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                if (option.subtitle.isNotEmpty)
                                  Text(
                                    option.subtitle,
                                    style: KubusTypography.textTheme.bodySmall?.copyWith(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSubject = value;
                          _titleController.text = value.title;
                          _descriptionController.text = value.subtitle.isNotEmpty
                              ? value.subtitle
                              : l10n.mapMarkerDialogMarkerForTitle(value.title);
                          if (_selectedSubjectType == MarkerSubjectType.artwork) {
                            _selectedArAsset =
                                findArtworkById(_subjectData.artworks, value.id);
                          }
                        });
                      }
                    },
                  )
                else
                  _hintBox(
                    scheme,
                    l10n.mapMarkerDialogNoSubjectsAvailable(
                      _subjectTypeLabel(l10n, _selectedSubjectType),
                    ),
                  )
              else
                _hintBox(
                  scheme,
                  l10n.mapMarkerDialogMiscHint,
                ),
              const SizedBox(height: 14),
              if (_showOptionalArAsset(_selectedSubjectType)) ...[
                Text(
                  l10n.mapMarkerDialogLinkedArAssetTitle,
                  style: KubusTypography.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                if (_arEnabledArtworks.isEmpty)
                  _hintBox(
                    scheme,
                    l10n.mapMarkerDialogNoArEnabledArtworksHint,
                  )
                else
                  DropdownButtonFormField<Artwork>(
                    isExpanded: true,
                    initialValue: _selectedArAsset,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: KubusRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _arEnabledArtworks
                        .map(
                          (artwork) => DropdownMenuItem<Artwork>(
                            value: artwork,
                            child: Text(artwork.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedArAsset = value);
                    },
                  ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.mapMarkerDialogMarkerTitleLabel,
                  border: OutlineInputBorder(
                    borderRadius: KubusRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.mapMarkerDialogEnterTitleError;
                  }
                  if (value.trim().length < 3) {
                    return l10n.mapMarkerDialogTitleMinLengthError(3);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.mapMarkerDialogDescriptionLabel,
                  border: OutlineInputBorder(
                    borderRadius: KubusRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.mapMarkerDialogEnterDescriptionError;
                  }
                  if (value.trim().length < 10) {
                    return l10n.mapMarkerDialogDescriptionMinLengthError(10);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: l10n.mapMarkerDialogCategoryLabel,
                  border: OutlineInputBorder(
                    borderRadius: KubusRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ArtMarkerType>(
                isExpanded: true,
                initialValue: _selectedMarkerType,
                decoration: InputDecoration(
                  labelText: l10n.mapMarkerDialogMarkerLayerLabel,
                  border: OutlineInputBorder(
                    borderRadius: KubusRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ArtMarkerType.values
                    .map((type) => DropdownMenuItem<ArtMarkerType>(
                          value: type,
                          child: Text(_describeMarkerType(l10n, type)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMarkerType = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mapMarkerDialogPublicMarkerTitle,
                    style: KubusTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  l10n.mapMarkerDialogPublicMarkerSubtitle,
                  style: KubusTypography.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
              if (widget.allowManualPosition) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: InputDecoration(
                          labelText: l10n.mapMarkerDialogLatitudeLabel,
                          border: OutlineInputBorder(
                            borderRadius: KubusRadius.circular(8),
                          ),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed.abs() > 90) {
                            return l10n.mapMarkerDialogValidLatitudeError;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: InputDecoration(
                          labelText: l10n.mapMarkerDialogLongitudeLabel,
                          border: OutlineInputBorder(
                            borderRadius: KubusRadius.circular(8),
                          ),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed.abs() > 180) {
                            return l10n.mapMarkerDialogValidLongitudeError;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.mapCenter != null && widget.onUseMapCenter != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        widget.onUseMapCenter!();
                        final center = widget.mapCenter!;
                        setState(() {
                          _latController.text = center.latitude.toStringAsFixed(6);
                          _lngController.text = center.longitude.toStringAsFixed(6);
                        });
                      },
                      icon: const Icon(Icons.my_location),
                      label: Text(l10n.mapMarkerDialogUseMapCenterButton),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Row _buildActionsRow(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.commonCancel, style: KubusTypography.textTheme.labelLarge),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_location_alt),
          label: Text(l10n.mapMarkerDialogCreateButton, style: KubusTypography.textTheme.labelLarge?.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  List<Widget> _buildDialogActions(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel, style: KubusTypography.textTheme.labelLarge),
      ),
      ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.mapMarkerDialogCreateButton, style: KubusTypography.textTheme.labelLarge?.copyWith(color: Colors.white)),
      ),
    ];
  }

  Widget _hintBox(ColorScheme scheme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: KubusRadius.circular(8),
      ),
      child: Text(
        text,
        style: KubusTypography.textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_subjectSelectionRequired(_selectedSubjectType) && _selectedSubject == null) {
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

    Navigator.of(context).pop(
      MapMarkerFormResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        markerType: _selectedMarkerType,
        subjectType: _selectedSubjectType,
        subject: _selectedSubject,
        linkedArtwork: _selectedArAsset,
        isPublic: _isPublic,
        positionOverride: manualPosition,
      ),
    );
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
}
