import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../models/event.dart';
import '../../models/exhibition.dart';
import '../../providers/events_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/creator_shell_navigation.dart';
import '../desktop/desktop_shell.dart';
import '../../widgets/creator/creator_kit.dart';
import '../../widgets/creator/creator_poap_section.dart';
import 'exhibition_detail_screen.dart' show localizedEventRelationTypeLabel;
import 'package:art_kubus/widgets/glass_components.dart'
    show showKubusDialog, KubusAlertDialog;
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class ExhibitionCreatorScreen extends StatefulWidget {
  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;
  final Exhibition? initialExhibition;
  final String? eventId;
  final bool forceDraftOnly;
  final VoidCallback? onCreated;

  const ExhibitionCreatorScreen({
    super.key,
    this.embedded = false,
    this.initialExhibition,
    this.eventId,
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
  String? _eventId;

  Uint8List? _coverBytes;
  String? _coverFileName;
  bool _seededInitialExhibition = false;

  // Program / linked events state. Selections are persisted through the
  // relation endpoints after the exhibition itself is saved.
  final List<KubusEvent> _linkedEvents = <KubusEvent>[];
  final Map<String, String> _relationTypeByEventId = <String, String>{};
  final Set<String> _removedEventIds = <String>{};
  final Set<String> _initiallyLinkedEventIds = <String>{};

  late final CreatorPoapConfig _poapConfig = CreatorPoapConfig();
  bool _poapPreviouslyConfigured = false;
  bool _remoteStateRequested = false;

  static const List<String> _relationTypeOptions = <String>[
    'program',
    'opening',
    'artist_talk',
    'guided_tour',
    'workshop',
    'performance',
    'lecture',
    'screening',
    'other',
  ];

  bool get _isEditing => widget.initialExhibition != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRemoteCreatorState();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _poapConfig.dispose();
    super.dispose();
  }

  /// When editing, hydrate the program list and POAP config from the backend.
  /// Failures stay local — the editor remains usable for the core fields.
  Future<void> _loadRemoteCreatorState() async {
    if (_remoteStateRequested) return;
    _remoteStateRequested = true;
    final initial = widget.initialExhibition;
    if (initial == null) return;
    final provider = context.read<ExhibitionsProvider>();

    try {
      final events =
          await provider.listExhibitionEvents(initial.id, refresh: true);
      if (!mounted) return;
      setState(() {
        _linkedEvents
          ..clear()
          ..addAll(events);
        _initiallyLinkedEventIds
          ..clear()
          ..addAll(events.map((e) => e.id));
        for (final event in events) {
          _relationTypeByEventId[event.id] = event.relationType ?? 'program';
        }
      });
    } catch (e) {
      debugPrint('ExhibitionCreator: program load failed: $e');
    }

    try {
      final poap = await provider.fetchExhibitionPoap(initial.id, force: true);
      if (!mounted || poap == null) return;
      setState(() {
        _poapPreviouslyConfigured = true;
        _poapConfig
          ..enabled = true
          ..rarity = poap.poap.rarity.trim().isNotEmpty
              ? poap.poap.rarity.trim().toLowerCase()
              : 'common'
          ..iconUrl = poap.poap.iconUrl;
        if (!kPoapRarities.contains(_poapConfig.rarity)) {
          _poapConfig.rarity = 'common';
        }
        _poapConfig.titleController.text = poap.poap.title;
        _poapConfig.descriptionController.text = poap.poap.description ?? '';
        _poapConfig.rewardController.text =
            poap.poap.rewardKub8 > 0 ? poap.poap.rewardKub8.toString() : '';
        if ((poap.proofType ?? '') == 'scan_proof') {
          _poapConfig.proofType = 'scan_proof';
        }
      });
    } catch (e) {
      // 404 simply means no POAP is configured yet.
      debugPrint('ExhibitionCreator: POAP load failed: $e');
    }
  }

  void _seedInitialExhibitionIfNeeded() {
    if (_seededInitialExhibition) return;
    final initial = widget.initialExhibition;
    if (initial == null) return;

    _seededInitialExhibition = true;
    _titleController.text = initial.title;
    _descriptionController.text = initial.description ?? '';
    _locationController.text = initial.locationName ?? '';
    _eventId = initial.eventId;
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

  Future<void> _pickPoapIcon() async {
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
      if (bytes == null || bytes.isEmpty) return;

      setState(() {
        _poapConfig.iconBytes = bytes;
        _poapConfig.iconFileName = name.isNotEmpty ? name : 'poap_icon.png';
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  Future<void> _showAttachEventDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final eventsProvider = context.read<EventsProvider>();

    if (!eventsProvider.initialized) {
      try {
        await eventsProvider.initialize();
      } catch (_) {
        // Provider reports its own errors.
      }
    }
    if (!mounted) return;

    bool canManageEvent(KubusEvent event) {
      final role = (event.myRole ?? '').trim().toLowerCase();
      return role == 'owner' ||
          role == 'admin' ||
          role == 'publisher' ||
          role == 'editor' ||
          role == 'curator';
    }

    final selectedIds = _linkedEvents.map((e) => e.id).toSet();
    final candidates = eventsProvider.events
        .where((e) => canManageEvent(e) && !selectedIds.contains(e.id))
        .toList();

    if (candidates.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.exhibitionCreatorNoEventsToLink)),
      );
      return;
    }

    final picked = <String>{};
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return KubusAlertDialog(
              title: Text(l10n.selectEventsDialogTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final event = candidates[index];
                    final checked = picked.contains(event.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            picked.add(event.id);
                          } else {
                            picked.remove(event.id);
                          }
                        });
                      },
                      title: Text(
                        event.title,
                        style:
                            KubusTypography.inter(fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child:
                      Text(l10n.commonCancel, style: KubusTypography.inter()),
                ),
                FilledButton(
                  onPressed: picked.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonLink,
                      style:
                          KubusTypography.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || picked.isEmpty || !mounted) return;

    setState(() {
      for (final id in picked) {
        final event = candidates.firstWhere((e) => e.id == id);
        _linkedEvents.add(event);
        _relationTypeByEventId[id] = 'program';
        _removedEventIds.remove(id);
      }
    });
  }

  void _removeLinkedEvent(KubusEvent event) {
    setState(() {
      _linkedEvents.removeWhere((e) => e.id == event.id);
      _relationTypeByEventId.remove(event.id);
      if (_initiallyLinkedEventIds.contains(event.id)) {
        _removedEventIds.add(event.id);
      }
    });
  }

  /// Syncs program links and the POAP badge after the exhibition save
  /// succeeded. Returns true when everything synced; the caller surfaces a
  /// secondary warning otherwise without failing the main save.
  Future<bool> _syncRelationsAndPoap(Exhibition saved) async {
    final provider = context.read<ExhibitionsProvider>();
    var allSynced = true;

    // Group additions by relation type so one request covers each group.
    final toAdd = _linkedEvents
        .where((e) => !_initiallyLinkedEventIds.contains(e.id))
        .toList();
    final byRelation = <String, List<String>>{};
    for (final event in toAdd) {
      final relation = _relationTypeByEventId[event.id] ?? 'program';
      byRelation.putIfAbsent(relation, () => <String>[]).add(event.id);
    }
    for (final entry in byRelation.entries) {
      try {
        await provider.linkExhibitionEvents(
          saved.id,
          entry.value,
          relationType: entry.key,
        );
      } catch (e) {
        debugPrint('ExhibitionCreator: link events sync failed: $e');
        allSynced = false;
      }
    }

    for (final eventId in _removedEventIds) {
      try {
        await provider.unlinkExhibitionEvent(saved.id, eventId);
      } catch (e) {
        debugPrint('ExhibitionCreator: unlink event sync failed: $e');
        allSynced = false;
      }
    }

    if (_poapConfig.enabled || _poapPreviouslyConfigured) {
      try {
        String? uploadedIconUrl;
        if (_poapConfig.iconBytes != null) {
          uploadedIconUrl = await provider.uploadExhibitionCover(
            bytes: _poapConfig.iconBytes!,
            fileName: _poapConfig.iconFileName ?? 'poap_icon.png',
          );
        }
        await provider.upsertExhibitionPoap(
          saved.id,
          _poapConfig.toPayload(uploadedIconUrl: uploadedIconUrl),
        );
        _poapPreviouslyConfigured = _poapConfig.enabled;
      } catch (e) {
        debugPrint('ExhibitionCreator: POAP sync failed: $e');
        allSynced = false;
      }
    }

    return allSynced;
  }

  Widget _buildProgramSection(AppLocalizations l10n, ColorScheme scheme) {
    return CreatorSection(
      title: l10n.exhibitionCreatorProgramTitle,
      children: [
        Text(
          l10n.exhibitionCreatorProgramSubtitle,
          style: KubusTextStyles.detailCaption.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const CreatorFieldSpacing(),
        if (_linkedEvents.isEmpty)
          Text(
            l10n.exhibitionCreatorProgramEmpty,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          ..._linkedEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: KubusTypography.inter(
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: KubusSpacing.xs),
                          DropdownButton<String>(
                            value: _relationTypeOptions.contains(
                                    _relationTypeByEventId[event.id])
                                ? _relationTypeByEventId[event.id]
                                : 'program',
                            isDense: true,
                            underline: const SizedBox(),
                            dropdownColor: scheme.surfaceContainerHighest,
                            style: KubusTextStyles.detailCaption
                                .copyWith(color: scheme.onSurface),
                            items: _relationTypeOptions
                                .map((code) => DropdownMenuItem<String>(
                                      value: code,
                                      child: Text(
                                        localizedEventRelationTypeLabel(
                                            l10n, code),
                                      ),
                                    ))
                                .toList(),
                            onChanged: _submitting ||
                                    _initiallyLinkedEventIds
                                        .contains(event.id)
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _relationTypeByEventId[event.id] = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonRemove,
                      onPressed:
                          _submitting ? null : () => _removeLinkedEvent(event),
                      icon: const Icon(Icons.link_off_outlined, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const CreatorFieldSpacing(),
        Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: _submitting ? null : _showAttachEventDialog,
              icon: const Icon(Icons.link_outlined, size: 18),
              label: Text(l10n.exhibitionCreatorAttachEvent),
            ),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => unawaited(
                        CreatorShellNavigation.openEventCreatorWorkspace(
                            context),
                      ),
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(l10n.exhibitionCreatorCreateEventForExhibition),
            ),
          ],
        ),
      ],
    );
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
                CreatorDescriptionTextField(
                  controller: _descriptionController,
                  label: l10n.exhibitionCreatorDescriptionLabel,
                  validator: (value) {
                    if ((value ?? '').length >
                        CreatorDescriptionTextField.maxDescriptionLength) {
                      return l10n.exhibitionCreatorCreateFailedWithError;
                    }
                    return null;
                  },
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

            // --- Program / linked events section ---
            if (AppConfig.isFeatureEnabled('events')) ...[
              _buildProgramSection(l10n, scheme),
              const CreatorSectionSpacing(),
            ],

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

            // --- POAP badge section ---
            CreatorPoapSection(
              config: _poapConfig,
              enabled: !_submitting,
              onChanged: () => setState(() {}),
              onPickIcon: _pickPoapIcon,
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
          contextType: DesktopCreatorContextType.exhibition,
          semantic: DesktopCreatorSectionSemantic.status,
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
    final collabEnabled =
        AppConfig.isFeatureEnabled('collabInvites') && createdId.isNotEmpty;
    const contextType = DesktopCreatorContextType.exhibition;

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
          contextType: contextType,
          semantic: DesktopCreatorSectionSemantic.status,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label:
                    created == null ? l10n.commonDraft : l10n.commonSavedToast,
                contextType: contextType,
                semantic: DesktopCreatorSectionSemantic.status,
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
          contextType: contextType,
          semantic: DesktopCreatorSectionSemantic.readiness,
          child: DesktopCreatorReadinessChecklist(
            items: readyItems,
            contextType: contextType,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.exhibitionCreatorQuickActionsTitle,
          subtitle: l10n.exhibitionCreatorQuickActionsSubtitle,
          icon: Icons.flash_on_outlined,
          contextType: contextType,
          semantic: DesktopCreatorSectionSemantic.actions,
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
                    unawaited(
                      CreatorShellNavigation.openExhibitionDetailWorkspace(
                        context,
                        exhibitionId: createdId,
                        initialExhibition: created,
                        titleOverride: created.title,
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
          contextType: contextType,
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
    final eventId = (_eventId ?? widget.eventId ?? '').trim();

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
        if (eventId.isNotEmpty) 'eventId': eventId,
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
      };

      final Exhibition? saved = _isEditing
          ? await provider.updateExhibition(
              widget.initialExhibition!.id, payload)
          : await provider.createExhibition(payload);
      if (!mounted) return;

      if (saved == null) {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.exhibitionCreatorCreateFailed)));
        return;
      }

      // The exhibition itself is saved; program links and POAP sync are
      // secondary. A sync failure shows a warning but never turns the save
      // into a failure.
      final relationsSynced = await _syncRelationsAndPoap(saved);
      if (!mounted) return;
      if (!relationsSynced) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.creatorRelationSyncFailedWarning)),
          tone: KubusSnackBarTone.warning,
        );
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
