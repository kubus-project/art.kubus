import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../models/map_marker_subject.dart';
import '../utils/marker_subject_utils.dart';
import '../utils/map_marker_subject_loader.dart';

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

  const MapMarkerDialog({
    super.key,
    required this.subjectData,
    required this.onRefreshSubjects,
    required this.initialPosition,
    this.allowManualPosition = false,
    this.mapCenter,
    this.onUseMapCenter,
    this.initialSubjectType = MarkerSubjectType.artwork,
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
  }) {
    return showDialog<MapMarkerFormResult>(
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
    _subjectData = widget.subjectData;
    _subjectOptionsByType = _buildOptions(_subjectData);
    _arEnabledArtworks =
        _subjectData.artworks.where(artworkSupportsAR).toList();

    _selectedSubjectType = widget.initialSubjectType;
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
        type: buildSubjectOptions(
          type: type,
          artworks: data.artworks,
          institutions: data.institutions,
          events: data.events,
          delegates: data.delegates,
        ),
    };
  }

  bool _subjectSelectionRequired(MarkerSubjectType type) =>
      type != MarkerSubjectType.misc;
  bool _arAssetRequired(MarkerSubjectType type) =>
      type != MarkerSubjectType.artwork && type != MarkerSubjectType.misc;

  Artwork? _resolveDefaultAsset(
    MarkerSubjectType type,
    MarkerSubjectOption? option,
  ) {
    if (type == MarkerSubjectType.artwork) {
      return findArtworkById(_arEnabledArtworks, option?.id);
    }
    if (_arAssetRequired(type) && _arEnabledArtworks.isNotEmpty) {
      return _arEnabledArtworks.first;
    }
    return null;
  }

  Future<void> _scheduleRefresh({bool force = false}) async {
    if (_refreshScheduled && !force) return;
    _refreshScheduled = true;
    setState(() => _refreshing = true);
    try {
      final fresh = await widget.onRefreshSubjects(force: true);
      if (fresh == null || !mounted) return;
      setState(() {
        _subjectData = fresh;
        _subjectOptionsByType = _buildOptions(fresh);
        _arEnabledArtworks = fresh.artworks.where(artworkSupportsAR).toList();
        final updatedOptions = _subjectOptionsByType[_selectedSubjectType] ?? [];
        MarkerSubjectOption? preserved;
        if (_selectedSubject != null) {
          try {
            preserved = updatedOptions
                .firstWhere((option) => option.id == _selectedSubject!.id);
          } catch (_) {}
        }
        _selectedSubject =
            preserved ?? (updatedOptions.isNotEmpty ? updatedOptions.first : null);
        _selectedArAsset =
            _resolveDefaultAsset(_selectedSubjectType, _selectedSubject);
      });
    } catch (_) {
      // ignore refresh failures inside dialog
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _applySubjectType(MarkerSubjectType type) {
    final options = _subjectOptionsByType[type] ?? [];
    final nextSubject = options.isNotEmpty ? options.first : null;
    setState(() {
      _selectedSubjectType = type;
      _selectedMarkerType = type.defaultMarkerType;
      _selectedSubject = nextSubject;
      _categoryController.text = type.defaultCategory;
      if (nextSubject != null) {
        _titleController.text = nextSubject.title;
        _descriptionController.text = nextSubject.subtitle.isNotEmpty
            ? nextSubject.subtitle
            : 'Marker for ${nextSubject.title}';
      } else if (_subjectSelectionRequired(type)) {
        _titleController.clear();
        _descriptionController.clear();
      }
      _selectedArAsset = _resolveDefaultAsset(type, nextSubject);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return AlertDialog(
      backgroundColor: scheme.surface,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Create Art Marker',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          if (_refreshing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: ConstrainedBox(
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
                  'Attach an existing subject and AR asset to this location.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<MarkerSubjectType>(
                  isExpanded: true,
                  value: _selectedSubjectType,
                  decoration: InputDecoration(
                    labelText: 'Subject Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: MarkerSubjectType.values
                      .map(
                        (type) => DropdownMenuItem<MarkerSubjectType>(
                          value: type,
                          child: Text(type.label),
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
                      value: _selectedSubject,
                      decoration: InputDecoration(
                        labelText: '${_selectedSubjectType.label} *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
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
                                          GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                  if (option.subtitle.isNotEmpty)
                                    Text(
                                      option.subtitle,
                                      style: GoogleFonts.outfit(fontSize: 12),
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
                                : 'Marker for ${value.title}';
                            if (_selectedSubjectType == MarkerSubjectType.artwork) {
                              _selectedArAsset =
                                  findArtworkById(_arEnabledArtworks, value.id);
                            }
                          });
                        }
                      },
                    )
                  else
                    _hintBox(
                      scheme,
                      'No ${_selectedSubjectType.label.toLowerCase()}s available. Create one first.',
                    )
                else
                  _hintBox(
                    scheme,
                    'Misc markers do not need a linked subject. Provide a custom title and description below.',
                  ),
                const SizedBox(height: 14),
                if (_arAssetRequired(_selectedSubjectType)) ...[
                  Text(
                    'Linked AR Asset',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_arEnabledArtworks.isEmpty)
                    _hintBox(
                      scheme,
                      'No AR-enabled artworks available. Create one first.',
                    )
                  else
                    DropdownButtonFormField<Artwork>(
                      isExpanded: true,
                      value: _selectedArAsset,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
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
                    labelText: 'Marker Title *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.trim().length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ArtMarkerType>(
                  isExpanded: true,
                  value: _selectedMarkerType,
                  decoration: InputDecoration(
                    labelText: 'Marker Layer',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ArtMarkerType.values
                      .map((type) => DropdownMenuItem<ArtMarkerType>(
                            value: type,
                            child: Text(_describeMarkerType(type)),
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
                  title: Text('Public marker',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Visible to all explorers on the map',
                    style: GoogleFonts.outfit(fontSize: 12),
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
                            labelText: 'Latitude *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed.abs() > 90) {
                              return 'Enter a valid latitude';
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
                            labelText: 'Longitude *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed.abs() > 180) {
                              return 'Enter a valid longitude';
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
                        label: const Text('Use map center'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.outfit()),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_location_alt),
          label: Text('Create Marker', style: GoogleFonts.outfit()),
        ),
      ],
    );
  }

  Widget _hintBox(ColorScheme scheme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 13),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectSelectionRequired(_selectedSubjectType) && _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a subject to continue')),
      );
      return;
    }
    if (_arAssetRequired(_selectedSubjectType) && _selectedArAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an AR-enabled artwork to link')),
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

  String _describeMarkerType(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return 'Artwork';
      case ArtMarkerType.institution:
        return 'Institution';
      case ArtMarkerType.event:
        return 'Event';
      case ArtMarkerType.residency:
        return 'Residency';
      case ArtMarkerType.drop:
        return 'Drop/Reward';
      case ArtMarkerType.experience:
        return 'AR Experience';
      case ArtMarkerType.other:
        return 'Other';
    }
  }
}
