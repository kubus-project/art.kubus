import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../detail/poap_detail_card.dart';
import 'creator_kit.dart';

/// Mutable POAP badge configuration shared by the event and exhibition
/// creators. Persisted through PUT /api/{events|exhibitions}/:id/poap after
/// the main entity save succeeds.
class CreatorPoapConfig {
  bool enabled;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController rewardController;
  String rarity;
  String proofType; // marker_attendance | scan_proof
  Uint8List? iconBytes;
  String? iconFileName;
  String? iconUrl;

  CreatorPoapConfig({
    this.enabled = false,
    String? title,
    String? description,
    int rewardKub8 = 0,
    this.rarity = 'common',
    this.proofType = 'marker_attendance',
    this.iconUrl,
  })  : titleController = TextEditingController(text: title ?? ''),
        descriptionController = TextEditingController(text: description ?? ''),
        rewardController = TextEditingController(
            text: rewardKub8 > 0 ? rewardKub8.toString() : '');

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    rewardController.dispose();
  }

  bool get hasTitle => titleController.text.trim().isNotEmpty;

  int get rewardKub8 {
    final parsed = int.tryParse(rewardController.text.trim());
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  Map<String, dynamic> toPayload({String? uploadedIconUrl}) {
    final icon = (uploadedIconUrl ?? iconUrl ?? '').trim();
    return <String, dynamic>{
      'enabled': enabled,
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      if (icon.isNotEmpty) 'iconUrl': icon,
      'rarity': rarity,
      'rewardKub8': rewardKub8,
      'proofType': proofType,
    };
  }
}

const kPoapRarities = <String>[
  'common',
  'uncommon',
  'rare',
  'epic',
  'legendary',
];

String localizedPoapRarityLabel(AppLocalizations l10n, String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'uncommon':
      return l10n.poapRarityUncommon;
    case 'rare':
      return l10n.poapRarityRare;
    case 'epic':
      return l10n.poapRarityEpic;
    case 'legendary':
      return l10n.poapRarityLegendary;
    case 'common':
    default:
      return l10n.poapRarityCommon;
  }
}

/// Creator section for configuring a POAP badge with a live preview.
/// Pure presentation — the owning screen holds the [CreatorPoapConfig] and
/// rebuilds via [onChanged].
class CreatorPoapSection extends StatelessWidget {
  final CreatorPoapConfig config;
  final VoidCallback onChanged;
  final VoidCallback onPickIcon;
  final bool enabled;
  final Color? accentColor;

  const CreatorPoapSection({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onPickIcon,
    this.enabled = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CreatorSection(
      title: l10n.creatorPoapSectionTitle,
      children: [
        CreatorSwitchTile(
          title: l10n.creatorPoapEnableTitle,
          subtitle: l10n.creatorPoapEnableSubtitle,
          value: config.enabled,
          onChanged: enabled
              ? (v) {
                  config.enabled = v;
                  onChanged();
                }
              : null,
          activeColor: accentColor,
        ),
        if (config.enabled) ...[
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: config.titleController,
            label: l10n.creatorPoapTitleLabel,
            enabled: enabled,
            accentColor: accentColor,
            onChanged: (_) => onChanged(),
            validator: (v) {
              if (config.enabled && (v ?? '').trim().isEmpty) {
                return l10n.creatorPoapTitleRequired;
              }
              return null;
            },
          ),
          const CreatorFieldSpacing(),
          CreatorDescriptionTextField(
            controller: config.descriptionController,
            label: l10n.creatorPoapDescriptionLabel,
            enabled: enabled,
            accentColor: accentColor,
            onChanged: (_) => onChanged(),
          ),
          const CreatorFieldSpacing(),
          _CreatorDropdownField<String>(
            label: l10n.creatorPoapRarityLabel,
            value: config.rarity,
            items: kPoapRarities,
            itemLabelBuilder: (code) => localizedPoapRarityLabel(l10n, code),
            enabled: enabled,
            onChanged: (value) {
              if (value == null) return;
              config.rarity = value;
              onChanged();
            },
          ),
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: config.rewardController,
            label: l10n.creatorPoapRewardLabel,
            keyboardType: TextInputType.number,
            enabled: enabled,
            accentColor: accentColor,
            onChanged: (_) => onChanged(),
          ),
          const CreatorFieldSpacing(),
          _CreatorDropdownField<String>(
            label: l10n.creatorPoapProofTypeLabel,
            value: config.proofType,
            items: const <String>['marker_attendance', 'scan_proof'],
            itemLabelBuilder: (code) => code == 'scan_proof'
                ? l10n.creatorPoapProofScan
                : l10n.creatorPoapProofMarkerAttendance,
            enabled: enabled,
            onChanged: (value) {
              if (value == null) return;
              config.proofType = value;
              onChanged();
            },
          ),
          const CreatorFieldSpacing(),
          Text(
            l10n.creatorPoapIconLabel,
            style: KubusTextStyles.detailLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          CreatorCoverImagePicker(
            imageBytes: config.iconBytes,
            imageUrl: config.iconUrl,
            uploadLabel: l10n.commonUpload,
            changeLabel: l10n.commonChangeCover,
            removeTooltip: l10n.commonRemove,
            onPick: onPickIcon,
            onRemove: () {
              config.iconBytes = null;
              config.iconFileName = null;
              config.iconUrl = null;
              onChanged();
            },
            enabled: enabled,
          ),
          const CreatorFieldSpacing(),
          Text(
            l10n.creatorPoapPreviewLabel,
            style: KubusTextStyles.detailLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          PoapDetailCard(
            title: config.titleController.text.trim().isNotEmpty
                ? config.titleController.text.trim()
                : l10n.creatorPoapSectionTitle,
            description: config.descriptionController.text.trim().isNotEmpty
                ? config.descriptionController.text.trim()
                : l10n.creatorPoapSectionSubtitle,
            iconUrl: config.iconUrl,
            rarityLabel: localizedPoapRarityLabel(l10n, config.rarity),
            rewardLabel:
                config.rewardKub8 > 0 ? '+${config.rewardKub8} KUB8' : null,
            eligibilityLabel: config.proofType == 'scan_proof'
                ? l10n.creatorPoapProofScan
                : l10n.creatorPoapProofMarkerAttendance,
            claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
            claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
          ),
        ],
      ],
    );
  }
}

class _CreatorDropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const _CreatorDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabelBuilder,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm + KubusSpacing.xs),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: scheme.surfaceContainerHighest,
            style: TextStyle(color: scheme.onSurface),
            items: items
                .map((item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabelBuilder(item),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
