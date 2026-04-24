import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../models/exhibition.dart';
import '../../providers/exhibitions_provider.dart';
import '../../utils/design_tokens.dart';
import 'exhibition_detail_screen.dart';
import '../desktop/desktop_shell.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ExhibitionCreatorScreen extends StatefulWidget {
  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;
  final bool forceDraftOnly;
  final VoidCallback? onCreated;

  const ExhibitionCreatorScreen({
    super.key,
    this.embedded = false,
    this.forceDraftOnly = false,
    this.onCreated,
  });

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
  Exhibition? _createdExhibition;

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
    final shellScope = DesktopShellScope.of(context);

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
            if (_createdExhibition != null) ...[
              CreatorInfoBox(
                text:
                    'Exhibition saved. Collaboration is available from the sidebar, and you can keep refining the details below.',
                icon: Icons.check_circle_outline,
                accentColor: scheme.primary,
              ),
              const CreatorSectionSpacing(),
            ],
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
              subtitle: widget.forceDraftOnly
                  ? l10n.exhibitionCreatorPublishDraft
                  : (_published
                      ? l10n.exhibitionCreatorPublishVisible
                      : l10n.exhibitionCreatorPublishDraft),
              value: widget.forceDraftOnly ? false : _published,
              onChanged: widget.forceDraftOnly
                  ? null
                  : (_submitting
                      ? null
                      : (v) => setState(() => _published = v)),
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

    if (widget.embedded) {
      return DesktopCreatorShell(
        title: l10n.exhibitionCreatorAppBarTitle,
        subtitle: _createdExhibition == null
            ? 'Curate the exhibition, then save it to unlock collaboration.'
            : 'Exhibition saved. Keep refining or open the detail view from the sidebar.',
        onBack: shellScope?.popScreen,
        headerBadge: CreatorStatusBadge(
          label: _createdExhibition == null ? 'Draft' : 'Saved',
          color: _createdExhibition == null ? scheme.primary : scheme.tertiary,
        ),
        mainContent: formBody,
        sidebar: _buildDesktopSidebar(l10n, scheme),
      );
    }

    return CreatorScaffold(
      title: l10n.exhibitionCreatorAppBarTitle,
      body: formBody,
    );
  }

  Widget _buildDesktopSidebar(AppLocalizations l10n, ColorScheme scheme) {
    final created = _createdExhibition;
    final createdId = created?.id ?? '';
    final hasCover = _coverBytes != null;
    final hasBasics = _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;
    final hasDates = _startsAt != null && _endsAt != null;
    final isPublic = widget.forceDraftOnly ? false : _published;
    final collabEnabled = AppConfig.isFeatureEnabled('collabInvites') &&
        createdId.isNotEmpty;

    final readyItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: 'Basics complete',
        description: 'Title, description, and location are filled in.',
        complete: hasBasics,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Date range set',
        description: hasDates
            ? 'The exhibition has a start and end date.'
            : 'Set both dates before saving.',
        complete: hasDates,
        icon: Icons.date_range_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Cover image added',
        description: hasCover
            ? 'Cover image is ready.'
            : 'Optional, but it improves the showcase.',
        complete: hasCover,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Visibility chosen',
        description: isPublic
            ? 'Public exhibition will be discoverable.'
            : 'Private exhibitions stay restricted.',
        complete: true,
        icon: isPublic ? Icons.public_outlined : Icons.lock_outline,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: 'Status',
          subtitle: created == null ? 'Draft in progress' : 'Saved exhibition',
          icon: created == null ? Icons.edit_outlined : Icons.museum_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: created == null ? 'Draft' : 'Saved',
                color: created == null ? scheme.primary : scheme.tertiary,
              ),
              const SizedBox(height: KubusSpacing.sm),
              DesktopCreatorSummaryRow(
                label: 'Exhibition ID',
                value: createdId.isNotEmpty ? createdId : 'Not created yet',
                valueColor: createdId.isNotEmpty
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
              DesktopCreatorSummaryRow(
                label: 'Schedule',
                value: hasDates ? 'Ready' : 'Incomplete',
                icon: Icons.event_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: 'Visibility',
                value: isPublic ? 'Public' : 'Private',
                icon: isPublic ? Icons.public_outlined : Icons.lock_outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Readiness',
          subtitle: 'A quick sanity check before saving.',
          icon: Icons.fact_check_outlined,
          child: DesktopCreatorReadinessChecklist(items: readyItems),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Quick actions',
          subtitle: 'Stay inside the creator while you work.',
          icon: Icons.flash_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: Icon(created == null
                    ? Icons.save_outlined
                    : Icons.refresh_outlined),
                label: Text(created == null
                    ? 'Save exhibition'
                    : 'Update exhibition'),
              ),
              if (created != null) ...[
                const SizedBox(height: KubusSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: l10n.exhibitionCreatorAppBarTitle,
                        child: ExhibitionDetailScreen(
                          exhibitionId: createdId,
                          initialExhibition: created,
                          embedded: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open exhibition'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Collaboration',
          subtitle: created != null
              ? 'Invite co-curators without leaving the workspace.'
              : 'Save once to unlock collaboration.',
          icon: Icons.group_add_outlined,
          child: collabEnabled
              ? CollaborationPanel(
                  entityType: 'exhibitions',
                  entityId: createdId,
                )
              : Text(
                  'Once saved, collaborators can be invited here so curation stays in context.',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
        ),
      ],
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

    if (_endsAt != null && _startsAt != null && _endsAt!.isBefore(_startsAt!)) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionCreatorEndDateAfterStartError)),
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
        'status': widget.forceDraftOnly
            ? 'draft'
            : (_published ? 'published' : 'draft'),
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
      };

      final created = await provider.createExhibition(payload);
      if (!mounted) return;

      if (created == null) {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.exhibitionCreatorCreateFailed)));
        return;
      }

      if (widget.embedded) {
        setState(() {
          _createdExhibition = created;
        });
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('Exhibition saved successfully.')),
        );
        return;
      }

      if (widget.onCreated != null) {
        widget.onCreated!.call();
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
        SnackBar(content: Text(l10n.exhibitionCreatorCreateFailedWithError)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
