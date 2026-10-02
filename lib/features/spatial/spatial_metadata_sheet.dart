import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/common/keyboard_inset_padding.dart';
import '../../widgets/kubus_kit.dart';

/// The user-editable part of a capture's metadata.
@immutable
class SpatialMetadataEdit {
  const SpatialMetadataEdit({this.displayName, this.note});

  /// Empty means "clear it", which is different from leaving it alone.
  final String? displayName;
  final String? note;
}

/// Edits the only fields a user owns: what the capture is called, and a note.
///
/// Sample counts, capture time, byte totals and CIDs are deliberately absent.
/// They record what happened; letting them be typed over would turn the
/// library into a place where the numbers mean whatever someone wanted them
/// to mean.
class SpatialMetadataSheet extends StatefulWidget {
  const SpatialMetadataSheet({
    super.key,
    this.initialDisplayName,
    this.initialNote,
    required this.fallbackName,
  });

  final String? initialDisplayName;
  final String? initialNote;

  /// Shown as the field's placeholder: what the capture is called when the
  /// user has not named it.
  final String fallbackName;

  static Future<SpatialMetadataEdit?> show(
    BuildContext context, {
    String? initialDisplayName,
    String? initialNote,
    required String fallbackName,
  }) =>
      showModalBottomSheet<SpatialMetadataEdit>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SpatialMetadataSheet(
          initialDisplayName: initialDisplayName,
          initialNote: initialNote,
          fallbackName: fallbackName,
        ),
      );

  @override
  State<SpatialMetadataSheet> createState() => _SpatialMetadataSheetState();
}

class _SpatialMetadataSheetState extends State<SpatialMetadataSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialDisplayName ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: KeyboardInsetPadding(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.spatialEditMetadataTitle,
                style: KubusTextStyles.sheetTitle,
              ),
              const SizedBox(height: KubusSpacing.md),
              KubusTextField(
                controller: _name,
                label: l10n.spatialEditDisplayNameLabel,
                hintText: widget.fallbackName,
                helperText: l10n.spatialEditDisplayNameHint,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: KubusSpacing.md),
              KubusTextField(
                controller: _note,
                label: l10n.spatialEditNoteLabel,
                maxLines: 3,
              ),
              const SizedBox(height: KubusSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: KubusButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: l10n.commonCancel,
                      variant: KubusButtonVariant.secondary,
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Expanded(
                    child: KubusButton(
                      onPressed: () => Navigator.of(context).pop(
                        SpatialMetadataEdit(
                          displayName: _name.text.trim(),
                          note: _note.text.trim(),
                        ),
                      ),
                      label: l10n.commonSave,
                      variant: KubusButtonVariant.accent,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
