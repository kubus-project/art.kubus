import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../models/exhibition.dart';
import '../../providers/exhibitions_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/creator_shell_navigation.dart';
import 'exhibition_detail_screen.dart';
import '../desktop/desktop_shell.dart';
import '../../widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ExhibitionCreatorScreen extends StatefulWidget {
  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;
  final Exhibition? initialExhibition;
  final bool forceDraftOnly;
  final VoidCallback? onCreated;

  const ExhibitionCreatorScreen({
    super.key,
    this.embedded = false,
    this.initialExhibition,
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
  bool _seededInitialExhibition = false;

  bool get _isEditing => widget.initialExhibition != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _seedInitialExhibitionIfNeeded() {
    if (_seededInitialExhibition) return;
    final initial = widget.initialExhibition;
    if (initial == null) return;

    _seededInitialExhibition = true;
    _titleController.text = initial.title;
    _descriptionController.text = initial.description ?? '';
    _locationController.text = initial.locationName ?? '';
    _startsAt = initial.startsAt;
    _endsAt = initial.endsAt;
    _published = initial.isPublished;
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
    _seedInitialExhibitionIfNeeded();

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
                text: _isEditing
                    ? l10n.exhibitionCreatorSavedInfoBox
                    : l10n.exhibitionCreatorSavedInfoBox,
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
              primaryLabel: _isEditing
                  ? l10n.exhibitionCreatorQuickActionUpdate
                  : l10n.commonCreate,
              onPrimary: _submitting ? null : _submit,
              primaryLoading: _submitting,
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      final accent = KubusColorRoles.of(context).web3InstitutionAccent;
      return DesktopCreatorShell(
        title: l10n.exhibitionCreatorAppBarTitle,
        subtitle: _createdExhibition == null
            ? l10n.exhibitionCreatorShellDraftSubtitle
            : l10n.exhibitionCreatorShellSavedSubtitle,
        onBack: shellScope?.popScreen,
        headerBadge: CreatorStatusBadge(
          label: _createdExhibition == null
              ? l10n.commonDraft
              : l10n.commonSavedToast,
          color: _createdExhibition == null ? scheme.primary : scheme.tertiary,
        ),
        sidebarAccentColor: accent,
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
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;

    final readyItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: l10n.exhibitionCreatorReadyBasicsLabel,
        description: l10n.exhibitionCreatorReadyBasicsDescription,
        complete: hasBasics,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.exhibitionCreatorReadyDatesLabel,
        description: hasDates
            ? l10n.exhibitionCreatorReadyDatesComplete
            : l10n.exhibitionCreatorReadyDatesPending,
        complete: hasDates,
        icon: Icons.date_range_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.exhibitionCreatorReadyCoverLabel,
        description: hasCover
            ? l10n.exhibitionCreatorReadyCoverComplete
            : l10n.exhibitionCreatorReadyCoverPending,
        complete: hasCover,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.exhibitionCreatorReadyVisibilityLabel,
        description: isPublic
            ? l10n.exhibitionCreatorReadyVisibilityPublic
            : l10n.exhibitionCreatorReadyVisibilityPrivate,
        complete: true,
        icon: isPublic ? Icons.public_outlined : Icons.lock_outline,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: l10n.commonStatus,
          subtitle: created == null
              ? l10n.exhibitionCreatorStatusDraftSubtitle
              : l10n.exhibitionCreatorStatusSavedSubtitle,
          icon: created == null ? Icons.edit_outlined : Icons.museum_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: created == null
                    ? l10n.commonDraft
                    : l10n.commonSavedToast,
                color: created == null ? scheme.primary : scheme.tertiary,
              ),
              const SizedBox(height: KubusSpacing.sm),
              DesktopCreatorSummaryRow(
                label: l10n.exhibitionCreatorSummaryIdLabel,
                value: createdId.isNotEmpty
                    ? createdId
                    : l10n.exhibitionCreatorSummaryNotCreatedYet,
                valueColor: createdId.isNotEmpty
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
              DesktopCreatorSummaryRow(
                label: l10n.exhibitionCreatorSummaryScheduleLabel,
                value: hasDates
                    ? l10n.exhibitionCreatorSummaryScheduleReady
                    : l10n.exhibitionCreatorSummaryScheduleIncomplete,
                icon: Icons.event_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: l10n.exhibitionCreatorSummaryVisibilityLabel,
                value: isPublic ? l10n.commonPublic : l10n.commonPrivate,
                icon: isPublic ? Icons.public_outlined : Icons.lock_outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.exhibitionCreatorReadinessTitle,
          subtitle: l10n.exhibitionCreatorReadinessSubtitle,
          icon: Icons.fact_check_outlined,
          accentColor: accent,
          child: DesktopCreatorReadinessChecklist(
            items: readyItems,
            accentColor: accent,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.exhibitionCreatorQuickActionsTitle,
          subtitle: l10n.exhibitionCreatorQuickActionsSubtitle,
          icon: Icons.flash_on_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: Icon(created == null
                    ? Icons.save_outlined
                    : Icons.refresh_outlined),
                label: Text(created == null
                    ? l10n.exhibitionCreatorQuickActionSave
                    : l10n.exhibitionCreatorQuickActionUpdate),
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
                  label: Text(l10n.exhibitionCreatorQuickActionOpen),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorCollaborationSection(
          title: l10n.exhibitionCreatorCollaborationTitle,
          subtitle: created != null
              ? l10n.exhibitionCreatorCollaborationReadySubtitle
              : l10n.exhibitionCreatorCollaborationLockedSubtitle,
          entityType: 'exhibitions',
          entityId: createdId,
          enabled: collabEnabled,
          lockedMessage: l10n.exhibitionCreatorCollaborationLockedMessage,
          accentColor: accent,
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
    final shellScope = DesktopShellScope.of(context);

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

      final Exhibition? saved = _isEditing
          ? await provider.updateExhibition(widget.initialExhibition!.id, payload)
          : await provider.createExhibition(payload);
      if (!mounted) return;

      if (saved == null) {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.exhibitionCreatorCreateFailed)));
        return;
      }

      if (widget.embedded) {
        setState(() {
          _createdExhibition = saved;
        });
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonSavedToast)),
        );

        if (_isEditing) {
          if (shellScope?.canPop ?? false) {
            shellScope!.popScreen();
          } else {
            Navigator.of(context).maybePop();
          }
          return;
        }

        if (shellScope != null) {
          await CreatorShellNavigation.openExhibitionDetailWorkspace(
            context,
            exhibitionId: saved.id,
            initialExhibition: saved,
            titleOverride: saved.title,
            replace: true,
          );
        }
        return;
      }

      if (widget.onCreated != null) {
        widget.onCreated!.call();
        return;
      }

      if (_isEditing) {
        Navigator.of(context).maybePop();
        return;
      }

      await CreatorShellNavigation.openExhibitionDetailWorkspace(
        context,
        exhibitionId: saved.id,
        initialExhibition: saved,
        titleOverride: saved.title,
        replace: true,
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
