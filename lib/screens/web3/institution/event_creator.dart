import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/exhibitions_provider.dart';
import '../../../providers/institution_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../events/event_detail_screen.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../desktop/desktop_shell.dart';
import '../../../widgets/creator/creator_kit.dart';
import '../../../widgets/creator/creator_poap_section.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class EventCreator extends StatefulWidget {
  final KubusEvent? initialEvent;

  /// When `true` the screen wraps in a frosted glass body because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides a header
  /// and gradient background.
  final bool embedded;

  const EventCreator({super.key, this.initialEvent, this.embedded = false});

  @override
  State<EventCreator> createState() => _EventCreatorState();
}

class _EventCreatorState extends State<EventCreator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _institutionId;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _eventType = 'exhibition';
  String _category = 'art';
  bool _isPublic = true;
  bool _allowRegistration = true;
  int _currentStep = 0;
  bool _submitting = false;
  KubusEvent? _createdEvent;

  // Linked exhibitions state, persisted via the relation endpoint after the
  // event itself is saved.
  final List<Exhibition> _linkedExhibitions = <Exhibition>[];
  final Set<String> _removedExhibitionIds = <String>{};
  final Set<String> _initiallyLinkedExhibitionIds = <String>{};

  late final CreatorPoapConfig _poapConfig = CreatorPoapConfig();
  bool _poapPreviouslyConfigured = false;
  bool _remoteStateRequested = false;

  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    final initial = widget.initialEvent;
    if (initial != null) {
      _titleController.text = initial.title;
      _descriptionController.text = initial.description ?? '';
      _locationController.text = initial.locationName ?? '';
      if (initial.startsAt != null) {
        _startDate = DateTime(initial.startsAt!.year, initial.startsAt!.month,
            initial.startsAt!.day);
        _startTime = TimeOfDay.fromDateTime(initial.startsAt!);
      }
      if (initial.endsAt != null) {
        _endDate = DateTime(
            initial.endsAt!.year, initial.endsAt!.month, initial.endsAt!.day);
        _endTime = TimeOfDay.fromDateTime(initial.endsAt!);
      }
      _isPublic = initial.isPublished;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRemoteCreatorState();
    });
  }

  /// When editing, hydrate linked exhibitions and the POAP config from the
  /// backend. Failures stay local — the editor remains usable.
  Future<void> _loadRemoteCreatorState() async {
    if (_remoteStateRequested) return;
    _remoteStateRequested = true;
    final initial = widget.initialEvent;
    if (initial == null) return;
    final eventsProvider = context.read<EventsProvider>();

    try {
      final linked =
          await eventsProvider.loadEventExhibitions(initial.id, refresh: true);
      if (!mounted) return;
      setState(() {
        _linkedExhibitions
          ..clear()
          ..addAll(linked);
        _initiallyLinkedExhibitionIds
          ..clear()
          ..addAll(linked.map((e) => e.id));
      });
    } catch (e) {
      debugPrint('EventCreator: linked exhibitions load failed: $e');
    }

    try {
      final poap = await eventsProvider.fetchEventPoap(initial.id, force: true);
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
        if ((poap.poap.proofType ?? poap.proofType ?? '') == 'scan_proof') {
          _poapConfig.proofType = 'scan_proof';
        }
      });
    } catch (e) {
      // 404 simply means no POAP is configured yet.
      debugPrint('EventCreator: POAP load failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_institutionId != null && _institutionId!.isNotEmpty) return;
    final provider = context.read<InstitutionProvider>();
    final selected = provider.selectedInstitution?.id;
    if (selected != null && selected.isNotEmpty) {
      _institutionId = selected;
      return;
    }
    if (provider.institutions.isNotEmpty) {
      _institutionId = provider.institutions.first.id;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _poapConfig.dispose();
    super.dispose();
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

  Future<void> _showLinkExhibitionDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final exhibitionsProvider = context.read<ExhibitionsProvider>();

    try {
      await exhibitionsProvider.loadExhibitions(mine: true, refresh: true);
    } catch (_) {
      // Provider reports its own errors.
    }
    if (!mounted) return;

    final selectedIds = _linkedExhibitions.map((e) => e.id).toSet();
    final candidates = exhibitionsProvider.myExhibitions
        .where((e) => !selectedIds.contains(e.id))
        .toList();

    if (candidates.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorNoExhibitionsToLink)),
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
              title: Text(l10n.selectExhibitionsDialogTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final exhibition = candidates[index];
                    final checked = picked.contains(exhibition.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            picked.add(exhibition.id);
                          } else {
                            picked.remove(exhibition.id);
                          }
                        });
                      },
                      title: Text(
                        exhibition.title,
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
        final exhibition = candidates.firstWhere((e) => e.id == id);
        _linkedExhibitions.add(exhibition);
        _removedExhibitionIds.remove(id);
      }
    });
  }

  void _removeLinkedExhibition(Exhibition exhibition) {
    setState(() {
      _linkedExhibitions.removeWhere((e) => e.id == exhibition.id);
      if (_initiallyLinkedExhibitionIds.contains(exhibition.id)) {
        _removedExhibitionIds.add(exhibition.id);
      }
    });
  }

  /// Syncs exhibition links and the POAP badge after the event save
  /// succeeded. Returns true when everything synced; the caller surfaces a
  /// secondary warning otherwise without failing the main save.
  Future<bool> _syncRelationsAndPoap(KubusEvent saved) async {
    final eventsProvider = context.read<EventsProvider>();
    var allSynced = true;

    final toAdd = _linkedExhibitions
        .where((e) => !_initiallyLinkedExhibitionIds.contains(e.id))
        .map((e) => e.id)
        .toList();
    if (toAdd.isNotEmpty) {
      try {
        await eventsProvider.linkEventExhibitions(saved.id, toAdd);
      } catch (e) {
        debugPrint('EventCreator: link exhibitions sync failed: $e');
        allSynced = false;
      }
    }

    for (final exhibitionId in _removedExhibitionIds) {
      try {
        await eventsProvider.unlinkEventExhibition(saved.id, exhibitionId);
      } catch (e) {
        debugPrint('EventCreator: unlink exhibition sync failed: $e');
        allSynced = false;
      }
    }

    if (_poapConfig.enabled || _poapPreviouslyConfigured) {
      try {
        String? uploadedIconUrl;
        if (_poapConfig.iconBytes != null) {
          final result = await BackendApiService().uploadFile(
            fileBytes: _poapConfig.iconBytes!,
            fileName: _poapConfig.iconFileName ?? 'poap_icon.png',
            fileType: 'image',
            metadata: const <String, String>{'folder': 'events/poap'},
          );
          final url = result['uploadedUrl']?.toString();
          if (url != null && url.trim().isNotEmpty) {
            uploadedIconUrl = url.trim();
          }
        }
        await eventsProvider.upsertEventPoap(
          saved.id,
          _poapConfig.toPayload(uploadedIconUrl: uploadedIconUrl),
        );
        _poapPreviouslyConfigured = _poapConfig.enabled;
      } catch (e) {
        debugPrint('EventCreator: POAP sync failed: $e');
        allSynced = false;
      }
    }

    return allSynced;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shellScope = DesktopShellScope.of(context);
    Widget body = FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          color: Colors.transparent,
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(child: _buildStepContent()),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return DesktopCreatorShell(
        title: _isEditing
            ? l10n.eventCreatorShellEditTitle
            : l10n.eventCreatorShellCreateTitle,
        subtitle: _createdEvent == null
            ? l10n.eventCreatorShellDraftSubtitle
            : l10n.eventCreatorShellSavedSubtitle,
        onBack: shellScope?.popScreen,
        headerBadge: CreatorStatusBadge(
          label: _createdEvent == null
              ? l10n.eventCreatorStepBadge(_currentStep + 1)
              : l10n.commonSavedToast,
          color: KubusColorRoles.of(context).web3InstitutionAccent,
        ),
        sidebarAccentColor: KubusColorRoles.of(context).web3InstitutionAccent,
        actions: [
          IconButton(
            tooltip: l10n.eventCreatorHelpTooltip,
            onPressed: _showHelp,
            icon: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
        mainContent: body,
        sidebar: _buildDesktopSidebar(l10n),
      );
    }

    return body;
  }

  Widget _buildDesktopSidebar(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final institutionProvider = context.watch<InstitutionProvider>();
    final selectedInstitution =
        _institutionId == null || _institutionId!.isEmpty
            ? institutionProvider.selectedInstitution
            : institutionProvider.getInstitutionById(_institutionId!);
    final created = _createdEvent;
    final createdId = created?.id ?? '';
    final hasInstitution = selectedInstitution != null;
    final hasBasics = _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;
    final hasDates = _startDate != null && _endDate != null;
    final hasCapacity = _capacityController.text.trim().isNotEmpty;
    final collabEnabled =
        AppConfig.isFeatureEnabled('collabInvites') && createdId.isNotEmpty;
    const contextType = DesktopCreatorContextType.event;

    final readyItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: l10n.eventCreatorReadyInstitutionLabel,
        description: hasInstitution
            ? l10n.eventCreatorReadyInstitutionComplete(
                selectedInstitution.name,
              )
            : l10n.eventCreatorReadyInstitutionPending,
        complete: hasInstitution,
        icon: Icons.apartment_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.eventCreatorReadyBasicsLabel,
        description: l10n.eventCreatorReadyBasicsDescription,
        complete: hasBasics,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.eventCreatorReadyDatesLabel,
        description: hasDates
            ? l10n.eventCreatorReadyDatesComplete
            : l10n.eventCreatorReadyDatesPending,
        complete: hasDates,
        icon: Icons.date_range_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.eventCreatorReadyCapacityLabel,
        description: hasCapacity
            ? l10n.eventCreatorReadyCapacityComplete
            : l10n.eventCreatorReadyCapacityPending,
        complete: hasCapacity,
        icon: Icons.groups_outlined,
      ),
      // Informational only — neither blocks saving the event.
      DesktopCreatorReadinessItem(
        label: l10n.eventCreatorLinkedExhibitionsTitle,
        description: _linkedExhibitions.isNotEmpty
            ? l10n.eventDetailLinkedExhibitionsSummary(
                _linkedExhibitions.length)
            : l10n.eventCreatorLinkedExhibitionsEmpty,
        complete: _linkedExhibitions.isNotEmpty,
        icon: Icons.museum_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: l10n.creatorPoapSectionTitle,
        description: _poapConfig.enabled
            ? l10n.creatorPoapEnableSubtitle
            : l10n.creatorPoapSectionSubtitle,
        complete: _poapConfig.enabled && _poapConfig.hasTitle,
        icon: Icons.confirmation_number_outlined,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: l10n.commonStatus,
          subtitle: created == null
              ? l10n.eventCreatorStatusDraftSubtitle
              : l10n.eventCreatorStatusSavedSubtitle,
          icon: created == null
              ? Icons.edit_outlined
              : Icons.event_available_outlined,
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
                label: l10n.eventCreatorSummaryEventId,
                value: createdId.isNotEmpty
                    ? createdId
                    : l10n.eventCreatorSummaryNotCreatedYet,
                valueColor: createdId.isNotEmpty
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
              DesktopCreatorSummaryRow(
                label: l10n.eventCreatorSummaryEventType,
                value: _eventType,
                icon: Icons.category_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: l10n.eventCreatorSummaryRegistration,
                value: _allowRegistration ? l10n.commonEnabled : l10n.commonOff,
                icon: Icons.how_to_reg_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.eventCreatorReadyInstitutionLabel,
          subtitle: selectedInstitution?.name ??
              l10n.eventCreatorReadyInstitutionPending,
          icon: Icons.apartment_outlined,
          contextType: contextType,
          semantic: DesktopCreatorSectionSemantic.summary,
          child: DesktopCreatorSummaryRow(
            label: l10n.eventCreatorReadyInstitutionLabel,
            value: selectedInstitution?.name ??
                l10n.eventCreatorReadyInstitutionPending,
            icon: Icons.verified_outlined,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.eventCreatorReadinessTitle,
          subtitle: l10n.eventCreatorReadinessSubtitle,
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
          title: l10n.eventCreatorQuickActionsTitle,
          subtitle: l10n.eventCreatorQuickActionsSubtitle,
          icon: Icons.flash_on_outlined,
          contextType: contextType,
          semantic: DesktopCreatorSectionSemantic.actions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _submitting
                    ? null
                    : (_currentStep < 3 ? _nextStep : _createEvent),
                icon: Icon(_currentStep < 3
                    ? Icons.arrow_forward
                    : Icons.save_outlined),
                label: Text(_currentStep < 3
                    ? l10n.eventCreatorQuickActionNextStep
                    : (created == null
                        ? l10n.eventCreatorQuickActionCreateEvent
                        : l10n.eventCreatorQuickActionUpdateEvent)),
              ),
              if (created != null) ...[
                const SizedBox(height: KubusSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    DesktopShellScope.of(context)?.pushScreen(
                      DesktopSubScreen(
                        title: _isEditing
                            ? l10n.eventCreatorShellEditTitle
                            : l10n.eventCreatorShellCreateTitle,
                        child: EventDetailScreen(eventId: createdId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: Text(l10n.eventCreatorQuickActionOpenEvent),
                ),
                const SizedBox(height: KubusSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(
                      CreatorShellNavigation.openExhibitionCreatorWorkspace(
                        context,
                        eventId: createdId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.museum_outlined),
                  label: Text(l10n.eventCreatorCreateExhibitionForEvent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorCollaborationSection(
          title: l10n.collectionSettingsCollaboration,
          subtitle: created != null
              ? l10n.eventCreatorCollaborationReadySubtitle
              : l10n.eventCreatorCollaborationLockedSubtitle,
          entityType: 'events',
          entityId: createdId,
          enabled: collabEnabled,
          lockedMessage: l10n.eventCreatorCollaborationLockedMessage,
          contextType: contextType,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? l10n.eventCreatorShellEditTitle
                    : l10n.eventCreatorShellCreateTitle,
                style: KubusTextStyles.mobileAppBarTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              Text(
                l10n.eventCreatorStepLabel(_currentStep + 1),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.help_outline, color: scheme.onPrimary),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: KubusSpacing.xs,
              margin: EdgeInsets.only(right: index < 3 ? KubusSpacing.sm : 0),
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? KubusColorRoles.of(context).web3InstitutionAccent
                    : scheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(KubusRadius.xs),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildDateTimeStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildReviewStep();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.eventCreatorBasicsTitle),
            const SizedBox(height: KubusSpacing.lg),
            _buildInstitutionSelector(),
            const SizedBox(height: KubusSpacing.md),
            _buildTextField(
              controller: _titleController,
              label: l10n.eventCreatorTitleLabel,
              hint: l10n.eventCreatorTitleHint,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return l10n.eventCreatorTitleRequiredError;
                }
                return null;
              },
            ),
            const SizedBox(height: KubusSpacing.md),
            CreatorDescriptionTextField(
              controller: _descriptionController,
              label: l10n.commonDescription,
              hint: l10n.eventCreatorDescriptionHint,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return l10n.eventCreatorDescriptionRequiredError;
                }
                if ((value ?? '').length >
                    CreatorDescriptionTextField.maxDescriptionLength) {
                  return l10n.eventCreatorSaveFailedToast;
                }
                return null;
              },
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildDropdown(
              label: l10n.eventCreatorEventTypeLabel,
              value: _eventType,
              items: _eventTypeOptions(),
              itemLabelBuilder: (code) => _eventTypeLabel(code, l10n),
              onChanged: (value) => setState(() => _eventType = value!),
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildDropdown(
              label: l10n.eventCreatorCategoryLabel,
              value: _category,
              items: _categoryOptions(),
              itemLabelBuilder: (code) => _categoryLabel(code, l10n),
              onChanged: (value) => setState(() => _category = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(l10n.eventCreatorDateTimeTitle),
          const SizedBox(height: KubusSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: l10n.eventCreatorStartDateLabel,
                  date: _startDate,
                  onTap: () => _selectDate(true),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTimeField(
                  label: l10n.eventCreatorStartTimeLabel,
                  time: _startTime,
                  onTap: () => _selectTime(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: l10n.eventCreatorEndDateLabel,
                  date: _endDate,
                  onTap: () => _selectDate(false),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTimeField(
                  label: l10n.eventCreatorEndTimeLabel,
                  time: _endTime,
                  onTap: () => _selectTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildTextField(
            controller: _locationController,
            label: l10n.eventCreatorLocationLabel,
            hint: l10n.eventCreatorLocationHint,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return l10n.eventCreatorLocationRequiredError;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(l10n.eventCreatorDetailsTitle),
          const SizedBox(height: KubusSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _capacityController,
                  label: l10n.eventCreatorCapacityLabel,
                  hint: l10n.eventCreatorCapacityHint,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return l10n.eventCreatorCapacityRequiredError;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTextField(
                  controller: _priceController,
                  label: l10n.eventCreatorPriceLabel,
                  hint: l10n.eventCreatorPriceHint,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          CreatorSwitchTile(
            title: l10n.eventCreatorPublicEventTitle,
            subtitle: l10n.eventCreatorPublicEventSubtitle,
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            activeColor: KubusColorRoles.of(context).web3InstitutionAccent,
          ),
          const SizedBox(height: KubusSpacing.md),
          CreatorSwitchTile(
            title: l10n.eventCreatorAllowRegistrationTitle,
            subtitle: l10n.eventCreatorAllowRegistrationSubtitle,
            value: _allowRegistration,
            onChanged: (value) => setState(() => _allowRegistration = value),
            activeColor: KubusColorRoles.of(context).web3InstitutionAccent,
          ),
          if (AppConfig.isFeatureEnabled('exhibitions')) ...[
            const SizedBox(height: KubusSpacing.lg),
            _buildLinkedExhibitionsSection(l10n),
          ],
          const SizedBox(height: KubusSpacing.lg),
          CreatorPoapSection(
            config: _poapConfig,
            enabled: !_submitting,
            accentColor: KubusColorRoles.of(context).web3InstitutionAccent,
            onChanged: () => setState(() {}),
            onPickIcon: _pickPoapIcon,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedExhibitionsSection(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return CreatorSection(
      title: l10n.eventCreatorLinkedExhibitionsTitle,
      children: [
        Text(
          l10n.eventCreatorLinkedExhibitionsSubtitle,
          style: KubusTextStyles.detailCaption.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const CreatorFieldSpacing(),
        if (_linkedExhibitions.isEmpty)
          Text(
            l10n.eventCreatorLinkedExhibitionsEmpty,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          ..._linkedExhibitions.map(
            (exhibition) => Padding(
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
                    Icon(Icons.museum_outlined,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.65)),
                    const SizedBox(width: KubusSpacing.sm),
                    Expanded(
                      child: Text(
                        exhibition.title,
                        style:
                            KubusTypography.inter(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonRemove,
                      onPressed: _submitting
                          ? null
                          : () => _removeLinkedExhibition(exhibition),
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
              onPressed: _submitting ? null : _showLinkExhibitionDialog,
              icon: const Icon(Icons.link_outlined, size: 18),
              label: Text(l10n.eventCreatorAddExhibition),
            ),
            OutlinedButton.icon(
              onPressed: _submitting || _createdEvent == null
                  ? null
                  : () => unawaited(
                        CreatorShellNavigation.openExhibitionCreatorWorkspace(
                          context,
                          eventId: _createdEvent!.id,
                        ),
                      ),
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(l10n.eventDetailCreateExhibition),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(l10n.eventCreatorReviewTitle),
          const SizedBox(height: KubusSpacing.lg),
          _buildReviewCard(),
          if (_createdEvent != null) ...[
            const SizedBox(height: KubusSpacing.lg),
            CreatorInfoBox(
              text: l10n.eventCreatorSavedCollaborationHint,
              icon: Icons.check_circle_outline,
            ),
          ],
          const SizedBox(height: KubusSpacing.lg),
          CreatorInfoBox(
            text: l10n.eventCreatorReviewNotice,
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isNotEmpty
                ? _titleController.text
                : l10n.eventCreatorTitleLabel,
            style: KubusTextStyles.screenTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : l10n.eventCreatorDescriptionPlaceholder,
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildReviewItem(l10n.eventCreatorReviewTypeLabel,
              _eventTypeLabel(_eventType, l10n)),
          _buildReviewItem(l10n.eventCreatorReviewCategoryLabel,
              _categoryLabel(_category, l10n)),
          _buildReviewItem(
              l10n.eventCreatorReviewLocationLabel,
              _locationController.text.isNotEmpty
                  ? _locationController.text
                  : l10n.eventCreatorLocationLabel),
          _buildReviewItem(
              l10n.eventCreatorReviewDateLabel, _formatDateRange(l10n)),
          _buildReviewItem(
              l10n.eventCreatorReviewTimeLabel, _formatTimeRange(l10n)),
          _buildReviewItem(
              l10n.eventCreatorReviewCapacityLabel,
              _capacityController.text.isNotEmpty
                  ? _capacityController.text
                  : '0'),
          _buildReviewItem(
              l10n.eventCreatorReviewPriceLabel,
              _priceController.text.isNotEmpty
                  ? '\$${_priceController.text}'
                  : l10n.commonFree),
          _buildReviewItem(l10n.eventCreatorReviewPublicLabel,
              _isPublic ? l10n.commonEnabled : l10n.commonDisabled),
          _buildReviewItem(l10n.eventCreatorReviewRegistrationLabel,
              _allowRegistration ? l10n.commonEnabled : l10n.commonDisabled),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: KubusTextStyles.detailLabel.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: KubusTextStyles.detailLabel.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: KubusTextStyles.detailSectionTitle.copyWith(
        color: scheme.onSurface,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;
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
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: scheme.onSurface.withValues(alpha: 0.4)),
            filled: true,
            fillColor: scheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide:
                  BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide:
                  BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                color: accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionSelector() {
    return Consumer<InstitutionProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final institutions = provider.institutions;
        if (institutions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_city,
                    color: scheme.onSurface.withValues(alpha: 0.7), size: 18),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.eventCreatorNoInstitutionAvailableMessage,
                    style: KubusTextStyles.detailLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final selectedId =
            (_institutionId != null && _institutionId!.isNotEmpty)
                ? _institutionId!
                : institutions.first.id;
        if (_institutionId != selectedId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _institutionId = selectedId);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.eventCreatorInstitutionLabel,
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
                border:
                    Border.all(color: scheme.outline.withValues(alpha: 0.25)),
              ),
              child: DropdownButton<String>(
                value: selectedId,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: scheme.surfaceContainerHighest,
                style: TextStyle(color: scheme.onSurface),
                items: institutions.map((institution) {
                  return DropdownMenuItem<String>(
                    value: institution.id,
                    child:
                        Text(institution.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _institutionId = value);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) itemLabelBuilder,
    required void Function(String?) onChanged,
  }) {
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
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            style: TextStyle(color: scheme.onSurface),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(itemLabelBuilder(item)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: scheme.onSurface.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  date != null
                      ? MaterialLocalizations.of(context).formatShortDate(date)
                      : AppLocalizations.of(context)!
                          .eventCreatorSelectDateLabel,
                  style: TextStyle(
                    color: date != null
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: scheme.onSurface.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  time != null
                      ? time.format(context)
                      : AppLocalizations.of(context)!
                          .eventCreatorSelectTimeLabel,
                  style: TextStyle(
                    color: time != null
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _currentStep--),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                child: Text(
                  l10n.commonBack,
                  style: KubusTextStyles.detailButton.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : (_currentStep < 3 ? _nextStep : _createEvent),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
              ),
              child: Text(
                _currentStep < 3
                    ? l10n.commonNext
                    : (_isEditing ? l10n.commonSave : l10n.commonCreate),
                style: KubusTextStyles.detailButton.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    }
  }

  bool _validateCurrentStep() {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentStep) {
      case 0:
        return _formKey.currentState?.validate() ?? false;
      case 1:
        if (_startDate == null || _endDate == null) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.eventCreatorSelectStartEndDatesToast)),
          );
          return false;
        }
        return true;
      case 2:
        if (_capacityController.text.isEmpty) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.eventCreatorEnterCapacityToast)),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _createEvent() async {
    if (!_validateCurrentStep()) return;

    final l10n = AppLocalizations.of(context)!;

    final institutionProvider = context.read<InstitutionProvider>();
    final eventsProvider = context.read<EventsProvider>();
    final institutions = institutionProvider.institutions;
    final institutionId = (_institutionId != null && _institutionId!.isNotEmpty)
        ? _institutionId!
        : institutionProvider.selectedInstitution?.id ??
            (institutions.isNotEmpty ? institutions.first.id : null);

    if (institutionId == null || institutionId.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorNoInstitutionAvailableToast)),
      );
      return;
    }

    final institution = institutionProvider.getInstitutionById(institutionId);
    if (institution == null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
            content: Text(l10n.eventCreatorSelectedInstitutionNotFoundToast)),
      );
      return;
    }

    final startDate = _startDate;
    final endDate = _endDate;
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorSelectStartEndDatesToast)),
      );
      return;
    }

    final startTime = _startTime ?? const TimeOfDay(hour: 10, minute: 0);
    final endTime = _endTime ?? const TimeOfDay(hour: 12, minute: 0);

    final startAt = DateTime(startDate.year, startDate.month, startDate.day,
        startTime.hour, startTime.minute);
    final endAt = DateTime(
        endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
    if (!endAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorEndTimeAfterStartToast)),
      );
      return;
    }

    if (_submitting) return;
    setState(() => _submitting = true);

    final initial = widget.initialEvent;
    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'startsAt': startAt.toIso8601String(),
      'endsAt': endAt.toIso8601String(),
      'locationName': _locationController.text.trim(),
      'status': _isPublic ? 'published' : 'draft',
      'lat': institution.latitude,
      'lng': institution.longitude,
    };

    try {
      final KubusEvent? saved;
      if (_isEditing) {
        saved = await eventsProvider.updateEvent(initial!.id, payload);
      } else {
        saved = await eventsProvider.createEvent(payload);
      }

      if (saved == null) {
        throw const BackendApiRequestException(
          statusCode: 500,
          path: '/api/events',
          body: 'Event save returned no event.',
        );
      }

      if (!mounted) return;
      final shellScope = DesktopShellScope.of(context);
      setState(() {
        _createdEvent = saved;
      });

      // The event itself is saved; linked exhibitions and POAP sync are
      // secondary. A sync failure shows a warning but never turns the save
      // into a failure.
      final relationsSynced = await _syncRelationsAndPoap(saved);
      if (!mounted) return;
      if (!relationsSynced) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.creatorRelationSyncFailedWarning,
            ),
          ),
          tone: KubusSnackBarTone.warning,
        );
      }

      final l10n = AppLocalizations.of(context)!;
      showKubusDialog(
        context: context,
        builder: (dialogContext) => KubusAlertDialog(
          backgroundColor:
              Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
          title: Text(
            _isEditing
                ? l10n.eventCreatorEventUpdatedTitle
                : l10n.eventCreatorEventCreatedTitle,
            style:
                TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
          ),
          content: Text(
            _isEditing
                ? l10n.eventCreatorEventUpdatedBody
                : l10n.eventCreatorEventCreatedBody,
            style: TextStyle(
                color: Theme.of(dialogContext)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75)),
          ),
          actions: [
            if (!_isEditing)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  unawaited(
                    CreatorShellNavigation.openExhibitionCreatorWorkspace(
                      context,
                      eventId: saved?.id,
                    ),
                  );
                },
                child: Text(l10n.eventCreatorCreateExhibitionForEvent),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (_isEditing) {
                  if (widget.embedded) {
                    shellScope?.popScreen();
                  } else {
                    Navigator.of(context).pop();
                  }
                } else if (!widget.embedded) {
                  _resetForm();
                }
              },
              child: Text(_isEditing
                  ? l10n.commonDone
                  : l10n.eventCreatorCreateAnotherButton),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EventCreator: Failed to save event: $e');
      }
      if (!mounted) return;
      final message = e is BackendApiRequestException
          ? e.userMessage
          : AppLocalizations.of(context)!.eventCreatorSaveFailedToast;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _priceController.clear();
      _capacityController.clear();
      _startDate = null;
      _endDate = null;
      _startTime = null;
      _endTime = null;
      _eventType = 'exhibition';
      _category = 'art';
      _isPublic = true;
      _allowRegistration = true;
    });
  }

  void _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  void _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  String _formatDateRange(AppLocalizations l10n) {
    if (_startDate == null || _endDate == null) {
      return l10n.eventCreatorNotSelectedLabel;
    }
    final localizations = MaterialLocalizations.of(context);
    if (_startDate == _endDate) {
      return localizations.formatShortDate(_startDate!);
    }
    return '${localizations.formatShortDate(_startDate!)} - ${localizations.formatShortDate(_endDate!)}';
  }

  String _formatTimeRange(AppLocalizations l10n) {
    if (_startTime == null || _endTime == null) {
      return l10n.eventCreatorNotSelectedLabel;
    }
    return '${_startTime!.format(context)} - ${_endTime!.format(context)}';
  }





  List<String> _eventTypeOptions() => const <String>[
        'exhibition',
        'workshop',
        'talk',
        'performance',
        'conference',
        'gallery_opening',
        'auction',
      ];

  List<String> _categoryOptions() => const <String>[
        'art',
        'digital_art',
        'photography',
        'sculpture',
        'mixed_media',
        'installation',
      ];

  String _eventTypeLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'workshop':
        return l10n.eventCreatorEventTypeWorkshop;
      case 'talk':
        return l10n.eventCreatorEventTypeTalk;
      case 'performance':
        return l10n.eventCreatorEventTypePerformance;
      case 'conference':
        return l10n.eventCreatorEventTypeConference;
      case 'gallery_opening':
        return l10n.eventCreatorEventTypeGalleryOpening;
      case 'auction':
        return l10n.eventCreatorEventTypeAuction;
      case 'exhibition':
      default:
        return l10n.eventCreatorEventTypeExhibition;
    }
  }

  String _categoryLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'digital_art':
        return l10n.eventCreatorCategoryDigitalArt;
      case 'photography':
        return l10n.eventCreatorCategoryPhotography;
      case 'sculpture':
        return l10n.eventCreatorCategorySculpture;
      case 'mixed_media':
        return l10n.eventCreatorCategoryMixedMedia;
      case 'installation':
        return l10n.eventCreatorCategoryInstallation;
      case 'art':
      default:
        return l10n.eventCreatorCategoryArt;
    }
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text(
          l10n.eventCreatorHelpTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          l10n.eventCreatorHelpBody,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonGotIt),
          ),
        ],
      ),
    );
  }
}
