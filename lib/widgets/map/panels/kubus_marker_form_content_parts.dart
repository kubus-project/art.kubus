import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/map_marker_subject.dart';
import '../../../utils/design_tokens.dart';
import '../../creator/creator_kit.dart';

class KubusMarkerFormHeader extends StatelessWidget {
  const KubusMarkerFormHeader({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onClose,
  });

  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Icon(Icons.add_location_alt, color: scheme.primary),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: Text(
            l10n.mapMarkerDialogTitle,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          tooltip: l10n.mapMarkerDialogRefreshSubjectsTooltip,
          onPressed: isRefreshing ? null : onRefresh,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class KubusMarkerFormBody extends StatelessWidget {
  const KubusMarkerFormBody({
    super.key,
    required this.formKey,
    required this.allowedTypes,
    required this.allowedMarkerTypes,
    required this.selectedSubjectType,
    required this.subjectOptionsByType,
    required this.selectedSubject,
    required this.arEnabledArtworks,
    required this.selectedArAsset,
    required this.selectedMarkerType,
    required this.isPublic,
    required this.isCommunity,
    required this.allowManualPosition,
    required this.mapCenter,
    required this.onUseMapCenter,
    required this.titleController,
    required this.descriptionController,
    required this.categoryController,
    required this.latController,
    required this.lngController,
    required this.subjectSelectionRequired,
    required this.showOptionalArAsset,
    required this.isStreetArtSelection,
    required this.onSubjectTypeChanged,
    required this.onSubjectChanged,
    required this.onArAssetChanged,
    required this.onMarkerTypeChanged,
    required this.onPublicChanged,
    required this.onCommunityChanged,
    required this.onPickCover,
    required this.onRemoveCover,
    required this.coverImageBytes,
  });

  final GlobalKey<FormState> formKey;
  final Set<MarkerSubjectType> allowedTypes;
  final Set<ArtMarkerType> allowedMarkerTypes;
  final MarkerSubjectType selectedSubjectType;
  final Map<MarkerSubjectType, List<MarkerSubjectOption>> subjectOptionsByType;
  final MarkerSubjectOption? selectedSubject;
  final List<Artwork> arEnabledArtworks;
  final Artwork? selectedArAsset;
  final ArtMarkerType selectedMarkerType;
  final bool isPublic;
  final bool isCommunity;
  final bool allowManualPosition;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController categoryController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final bool subjectSelectionRequired;
  final bool showOptionalArAsset;
  final bool isStreetArtSelection;
  final ValueChanged<MarkerSubjectType> onSubjectTypeChanged;
  final ValueChanged<MarkerSubjectOption> onSubjectChanged;
  final ValueChanged<Artwork?> onArAssetChanged;
  final ValueChanged<ArtMarkerType> onMarkerTypeChanged;
  final ValueChanged<bool> onPublicChanged;
  final ValueChanged<bool> onCommunityChanged;
  final VoidCallback onPickCover;
  final VoidCallback onRemoveCover;
  final Uint8List? coverImageBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Form(
        key: formKey,
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
            const SizedBox(height: KubusSpacing.md),
            KubusMarkerSubjectSection(
              selectedSubjectType: selectedSubjectType,
              allowedTypes: allowedTypes,
              subjectOptionsByType: subjectOptionsByType,
              selectedSubject: selectedSubject,
              subjectSelectionRequired: subjectSelectionRequired,
              onSubjectTypeChanged: onSubjectTypeChanged,
              onSubjectChanged: onSubjectChanged,
            ),
            const SizedBox(height: KubusSpacing.md),
            if (showOptionalArAsset) ...[
              KubusMarkerFormSectionTitle(
                title: l10n.mapMarkerDialogLinkedArAssetTitle,
              ),
              const SizedBox(height: KubusSpacing.sm),
              KubusLinkedArAssetSection(
                arEnabledArtworks: arEnabledArtworks,
                selectedArAsset: selectedArAsset,
                onArAssetChanged: onArAssetChanged,
              ),
              const SizedBox(height: KubusSpacing.md),
            ],
            KubusMarkerFormTextField(
              controller: titleController,
              labelText: l10n.mapMarkerDialogMarkerTitleLabel,
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
            const SizedBox(height: KubusSpacing.md),
            CreatorDescriptionTextField(
              controller: descriptionController,
              label: l10n.mapMarkerDialogDescriptionLabel,
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
            const SizedBox(height: KubusSpacing.md),
            if (isStreetArtSelection) ...[
              KubusMarkerFormSectionTitle(
                title: l10n.mapMarkerDialogCoverImageTitle,
              ),
              const SizedBox(height: KubusSpacing.sm),
              KubusCoverImageSection(
                imageBytes: coverImageBytes,
                uploadLabel: l10n.mapMarkerDialogUploadCover,
                changeLabel: l10n.mapMarkerDialogChangeCover,
                removeTooltip: l10n.mapMarkerDialogRemoveCoverTooltip,
                onPick: onPickCover,
                onRemove: onRemoveCover,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                l10n.mapMarkerDialogStreetArtCoverRequiredHint,
                style: KubusTypography.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
            ],
            KubusMarkerFormTextField(
              controller: categoryController,
              labelText: l10n.mapMarkerDialogCategoryLabel,
            ),
            const SizedBox(height: KubusSpacing.md),
            KubusMarkerMarkerTypeSection(
              selectedMarkerType: selectedMarkerType,
              allowedMarkerTypes: allowedMarkerTypes,
              onMarkerTypeChanged: onMarkerTypeChanged,
            ),
            const SizedBox(height: KubusSpacing.md),
            KubusMarkerFormSwitchTile(
              title: l10n.mapMarkerDialogPublicMarkerTitle,
              subtitle: l10n.mapMarkerDialogPublicMarkerSubtitle,
              value: isPublic,
              onChanged: onPublicChanged,
            ),
            const SizedBox(height: KubusSpacing.sm),
            KubusMarkerFormSwitchTile(
              title: l10n.mapMarkerCommunityLabel,
              value: isCommunity,
              onChanged: onCommunityChanged,
            ),
            if (allowManualPosition) ...[
              const SizedBox(height: KubusSpacing.md),
              KubusMarkerPositionRow(
                latController: latController,
                lngController: lngController,
                mapCenter: mapCenter,
                onUseMapCenter: onUseMapCenter,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Creator-kit aligned styling for the form's dropdowns so they read as the
/// same system as [CreatorTextField] / [CreatorDropdown].
InputDecoration _creatorDropdownDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: KubusSpacing.sm + KubusSpacing.xs,
      vertical: KubusSpacing.sm + KubusSpacing.xs,
    ),
    border: border(scheme.outline.withValues(alpha: 0.25)),
    enabledBorder: border(scheme.outline.withValues(alpha: 0.25)),
    focusedBorder: border(scheme.primary, width: 1.5),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, width: 1.5),
    disabledBorder: border(scheme.outline.withValues(alpha: 0.15)),
  );
}

class _CreatorFieldLabel extends StatelessWidget {
  const _CreatorFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.xs),
      child: Text(
        label,
        style: KubusTextStyles.detailLabel.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

class KubusMarkerSubjectSection extends StatelessWidget {
  const KubusMarkerSubjectSection({
    super.key,
    required this.selectedSubjectType,
    required this.allowedTypes,
    required this.subjectOptionsByType,
    required this.selectedSubject,
    required this.subjectSelectionRequired,
    required this.onSubjectTypeChanged,
    required this.onSubjectChanged,
  });

  final MarkerSubjectType selectedSubjectType;
  final Set<MarkerSubjectType> allowedTypes;
  final Map<MarkerSubjectType, List<MarkerSubjectOption>> subjectOptionsByType;
  final MarkerSubjectOption? selectedSubject;
  final bool subjectSelectionRequired;
  final ValueChanged<MarkerSubjectType> onSubjectTypeChanged;
  final ValueChanged<MarkerSubjectOption> onSubjectChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreatorFieldLabel(label: l10n.mapMarkerDialogSubjectTypeLabel),
        DropdownButtonFormField<MarkerSubjectType>(
          isExpanded: true,
          initialValue: selectedSubjectType,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          decoration: _creatorDropdownDecoration(context),
          items: MarkerSubjectType.values
              .where(allowedTypes.contains)
              .map(
                (type) => DropdownMenuItem<MarkerSubjectType>(
                  value: type,
                  child: Text(_subjectTypeLabel(l10n, type)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onSubjectTypeChanged(value);
            }
          },
        ),
        const SizedBox(height: KubusSpacing.md),
        if (subjectSelectionRequired)
          if ((subjectOptionsByType[selectedSubjectType] ?? []).isNotEmpty) ...[
            _CreatorFieldLabel(
              label: l10n.mapMarkerDialogSubjectRequiredLabel(
                _subjectTypeLabel(l10n, selectedSubjectType),
              ),
            ),
            DropdownButtonFormField<MarkerSubjectOption>(
              isExpanded: true,
              initialValue: selectedSubject,
              borderRadius: BorderRadius.circular(KubusRadius.md),
              decoration: _creatorDropdownDecoration(context),
              // Closed field stays single-line; the menu keeps the richer
              // two-line title + subtitle entries.
              selectedItemBuilder: (context) =>
                  (subjectOptionsByType[selectedSubjectType] ?? [])
                      .map(
                        (option) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              items: (subjectOptionsByType[selectedSubjectType] ?? [])
                  .map(
                    (option) => DropdownMenuItem<MarkerSubjectOption>(
                      value: option,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KubusTypography.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (option.subtitle.isNotEmpty)
                            Text(
                              option.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KubusTypography.textTheme.bodySmall
                                  ?.copyWith(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onSubjectChanged(value);
                }
              },
            ),
          ] else
            KubusMarkerFormHintBox(
              text: l10n.mapMarkerDialogNoSubjectsAvailable(
                _subjectTypeLabel(l10n, selectedSubjectType),
              ),
            )
        else
          KubusMarkerFormHintBox(
            text: selectedSubjectType == MarkerSubjectType.streetArt
                ? l10n.mapMarkerDialogStreetArtHint
                : l10n.mapMarkerDialogMiscHint,
          ),
      ],
    );
  }
}

class KubusLinkedArAssetSection extends StatelessWidget {
  const KubusLinkedArAssetSection({
    super.key,
    required this.arEnabledArtworks,
    required this.selectedArAsset,
    required this.onArAssetChanged,
  });

  final List<Artwork> arEnabledArtworks;
  final Artwork? selectedArAsset;
  final ValueChanged<Artwork?> onArAssetChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (arEnabledArtworks.isEmpty) {
      return KubusMarkerFormHintBox(
        text: l10n.mapMarkerDialogNoArEnabledArtworksHint,
      );
    }

    return DropdownButtonFormField<Artwork>(
      isExpanded: true,
      initialValue: selectedArAsset,
      borderRadius: BorderRadius.circular(KubusRadius.md),
      decoration: _creatorDropdownDecoration(context),
      items: arEnabledArtworks
          .map(
            (artwork) => DropdownMenuItem<Artwork>(
              value: artwork,
              child: Text(
                artwork.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onArAssetChanged,
    );
  }
}

class KubusCoverImageSection extends StatelessWidget {
  const KubusCoverImageSection({
    super.key,
    required this.imageBytes,
    required this.uploadLabel,
    required this.changeLabel,
    required this.removeTooltip,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final String uploadLabel;
  final String changeLabel;
  final String removeTooltip;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CreatorCoverImagePicker(
      imageBytes: imageBytes,
      uploadLabel: uploadLabel,
      changeLabel: changeLabel,
      removeTooltip: removeTooltip,
      onPick: onPick,
      onRemove: onRemove,
    );
  }
}

class KubusMarkerMarkerTypeSection extends StatelessWidget {
  const KubusMarkerMarkerTypeSection({
    super.key,
    required this.selectedMarkerType,
    required this.allowedMarkerTypes,
    required this.onMarkerTypeChanged,
  });

  final ArtMarkerType selectedMarkerType;
  final Set<ArtMarkerType> allowedMarkerTypes;
  final ValueChanged<ArtMarkerType> onMarkerTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreatorFieldLabel(label: l10n.mapMarkerDialogMarkerLayerLabel),
        DropdownButtonFormField<ArtMarkerType>(
          isExpanded: true,
          initialValue: selectedMarkerType,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          decoration: _creatorDropdownDecoration(context),
          items: ArtMarkerType.values
              .where(allowedMarkerTypes.contains)
              .map(
                (type) => DropdownMenuItem<ArtMarkerType>(
                  value: type,
                  child: Text(_describeMarkerType(l10n, type)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onMarkerTypeChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class KubusMarkerFormSwitchTile extends StatelessWidget {
  const KubusMarkerFormSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreatorSwitchTile(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );
  }
}

class KubusMarkerPositionRow extends StatelessWidget {
  const KubusMarkerPositionRow({
    super.key,
    required this.latController,
    required this.lngController,
    required this.mapCenter,
    required this.onUseMapCenter,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final LatLng? mapCenter;
  final VoidCallback? onUseMapCenter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KubusMarkerFormFieldRow(
          first: KubusMarkerFormTextField(
            controller: latController,
            labelText: l10n.mapMarkerDialogLatitudeLabel,
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
          second: KubusMarkerFormTextField(
            controller: lngController,
            labelText: l10n.mapMarkerDialogLongitudeLabel,
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
        const SizedBox(height: KubusSpacing.sm),
        if (mapCenter != null && onUseMapCenter != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onUseMapCenter,
              icon: const Icon(Icons.my_location),
              label: Text(l10n.mapMarkerDialogUseMapCenterButton),
            ),
          ),
      ],
    );
  }
}

class KubusMarkerFormFieldRow extends StatelessWidget {
  const KubusMarkerFormFieldRow({
    super.key,
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
        Expanded(child: second),
      ],
    );
  }
}

/// Thin adapter so the map marker form uses the same field styling as the
/// creator kit ([CreatorTextField]) without changing controllers/validators.
class KubusMarkerFormTextField extends StatelessWidget {
  const KubusMarkerFormTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return CreatorTextField(
      controller: controller,
      label: labelText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

class KubusMarkerFormHintBox extends StatelessWidget {
  const KubusMarkerFormHintBox({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return CreatorInfoBox(text: text);
  }
}

class KubusMarkerFormActionsRow extends StatelessWidget {
  const KubusMarkerFormActionsRow({
    super.key,
    required this.onCancel,
    required this.onSubmit,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CreatorFooterActions(
      primaryLabel: l10n.mapMarkerDialogCreateButton,
      onPrimary: onSubmit,
      secondaryLabel: l10n.commonCancel,
      onSecondary: onCancel,
    );
  }
}

class KubusMarkerFormSectionTitle extends StatelessWidget {
  const KubusMarkerFormSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: KubusTypography.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

String _subjectTypeLabel(AppLocalizations l10n, MarkerSubjectType type) {
  switch (type) {
    case MarkerSubjectType.artwork:
      return l10n.mapMarkerSubjectTypeArtwork;
    case MarkerSubjectType.streetArt:
      return l10n.mapMarkerSubjectTypeStreetArt;
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
    case ArtMarkerType.streetArt:
      return l10n.mapMarkerLayerStreetArt;
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
