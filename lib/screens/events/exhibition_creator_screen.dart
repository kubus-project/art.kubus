import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../providers/exhibitions_provider.dart';
import '../../utils/design_tokens.dart';
import 'exhibition_detail_screen.dart';
import '../../widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ExhibitionCreatorScreen extends StatefulWidget {
  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;

  const ExhibitionCreatorScreen({super.key, this.embedded = false});

  @override
  State<ExhibitionCreatorScreen> createState() =>
      _ExhibitionCreatorScreenState();
}

class _ExhibitionCreatorScreenState extends State<ExhibitionCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _published = false;
  bool _submitting = false;

  Uint8List? _coverBytes;
  String? _coverFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      final file = picked?.files.single;
      final bytes = file?.bytes;
      final name = (file?.name ?? '').trim();

      if (!mounted) return;

      if (bytes == null || bytes.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)),
        );
        return;
      }

      setState(() {
        _coverBytes = bytes;
        _coverFileName = name.isNotEmpty ? name : 'cover.jpg';
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (!AppConfig.isFeatureEnabled('exhibitions')) {
      final disabledBody = Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: Text(
            l10n.exhibitionCreatorDisabledMessage,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

      if (widget.embedded) return CreatorGlassBody(child: disabledBody);

      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.exhibitionCreatorDisabledAppBarTitle,
            style: KubusTextStyles.detailScreenTitle,
          ),
        ),
        body: disabledBody,
      );
    }

    final formBody = Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
              // --- Basics section ---
              CreatorSection(
                title: l10n.exhibitionCreatorBasicsTitle,
                children: [
                  CreatorTextField(
                    controller: _titleController,
                    label: l10n.exhibitionCreatorTitleLabel,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return l10n.exhibitionCreatorTitleValidation;
                      }
                      return null;
                    },
                  ),
                  const CreatorFieldSpacing(),
                  CreatorTextField(
                    controller: _descriptionController,
                    label: l10n.exhibitionCreatorDescriptionLabel,
                    maxLines: 4,
                  ),
                  const CreatorFieldSpacing(),
                  CreatorTextField(
                    controller: _locationController,
                    label: l10n.exhibitionCreatorLocationLabel,
                  ),
                ],
              ),

              const CreatorSectionSpacing(),

              // --- Schedule section ---
              CreatorSection(
                title: l10n.exhibitionCreatorScheduleTitle,
                children: [
                  CreatorDateField(
                    label: l10n.exhibitionCreatorStartsLabel,
                    value: _startsAt,
                    notSetLabel: l10n.exhibitionCreatorNotSetLabel,
                    onPick: () => _pickDate(isStart: true),
                    onClear: () => setState(() => _startsAt = null),
                  ),
                  const CreatorFieldSpacing(),
                  CreatorDateField(
                    label: l10n.exhibitionCreatorEndsLabel,
                    value: _endsAt,
                    notSetLabel: l10n.exhibitionCreatorNotSetLabel,
                    onPick: () => _pickDate(isStart: false),
                    onClear: () => setState(() => _endsAt = null),
                  ),
                ],
              ),

              const CreatorSectionSpacing(),

              // --- Visibility toggle ---
              CreatorSwitchTile(
                title: l10n.exhibitionCreatorPublishTitle,
                subtitle: _published
                    ? l10n.exhibitionCreatorPublishVisible
                    : l10n.exhibitionCreatorPublishDraft,
                value: _published,
                onChanged:
                    _submitting ? null : (v) => setState(() => _published = v),
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
                    enabled: !_submitting,
                  ),
                ],
              ),

              const CreatorSectionSpacing(),

              // --- Collaboration hint ---
              if (AppConfig.isFeatureEnabled('collabInvites'))
                CreatorInfoBox(
                  text: l10n.exhibitionCreatorCollabHint,
                  icon: Icons.group_add_outlined,
                ),

              if (AppConfig.isFeatureEnabled('collabInvites'))
                const CreatorSectionSpacing(),

              // --- Create button ---
              CreatorFooterActions(
                primaryLabel: l10n.commonCreate,
                onPrimary: _submit,
                primaryLoading: _submitting,
              ),
          ],
        ),
      ),
    );

    if (widget.embedded) return CreatorGlassBody(child: formBody);

    return CreatorScaffold(
      title: l10n.exhibitionCreatorAppBarTitle,
      body: formBody,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _startsAt : _endsAt;
    final initial = current ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (!mounted || picked == null) return;

    setState(() {
      if (isStart) {
        _startsAt = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<ExhibitionsProvider>();

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final locationName = _locationController.text.trim();

    if (_endsAt != null &&
        _startsAt != null &&
        _endsAt!.isBefore(_startsAt!)) {
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(l10n.exhibitionCreatorEndDateAfterStartError)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String? coverUrl;
      if (_coverBytes != null) {
        final safeFileName = (_coverFileName ?? 'cover.jpg').trim();
        coverUrl = await provider.uploadExhibitionCover(
          bytes: _coverBytes!,
          fileName: safeFileName.isEmpty ? 'cover.jpg' : safeFileName,
        );
        if (!mounted) return;
        if (coverUrl == null || coverUrl.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.commonActionFailedToast)),
          );
          return;
        }
      }

      final payload = <String, dynamic>{
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (locationName.isNotEmpty) 'locationName': locationName,
        if (_startsAt != null) 'startsAt': _startsAt!.toIso8601String(),
        if (_endsAt != null) 'endsAt': _endsAt!.toIso8601String(),
        'status': _published ? 'published' : 'draft',
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
      };

      final created = await provider.createExhibition(payload);
      if (!mounted) return;

      if (created == null) {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.exhibitionCreatorCreateFailed)));
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExhibitionDetailScreen(
            exhibitionId: created.id,
            initialExhibition: created,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
            content: Text(l10n.exhibitionCreatorCreateFailedWithError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
