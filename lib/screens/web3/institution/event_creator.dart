import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../events/event_detail_screen.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/wallet_utils.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../desktop/desktop_shell.dart';
import '../../../widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class EventCreator extends StatefulWidget {
  final Event? initialEvent;

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
  Event? _createdEvent;

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
      _institutionId = initial.institutionId;
      _titleController.text = initial.title;
      _descriptionController.text = initial.description;
      _locationController.text = initial.location;
      _priceController.text = initial.price?.toString() ?? '';
      _capacityController.text = initial.capacity?.toString() ?? '';
      _startDate = DateTime(initial.startDate.year, initial.startDate.month,
          initial.startDate.day);
      _endDate = DateTime(
          initial.endDate.year, initial.endDate.month, initial.endDate.day);
      _startTime = TimeOfDay.fromDateTime(initial.startDate);
      _endTime = TimeOfDay.fromDateTime(initial.endDate);
      _eventType = _eventTypeCode(initial.type);
      _category = _categoryCode(initial.category);
      _isPublic = initial.isPublic;
      _allowRegistration = initial.allowRegistration;
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
    super.dispose();
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
    final selectedInstitution = _institutionId == null || _institutionId!.isEmpty
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
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;

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
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: l10n.commonStatus,
          subtitle: created == null
              ? l10n.eventCreatorStatusDraftSubtitle
              : l10n.eventCreatorStatusSavedSubtitle,
          icon: created == null ? Icons.edit_outlined : Icons.event_available_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: created == null
                    ? l10n.commonDraft
                    : l10n.commonSavedToast,
                color: KubusColorRoles.of(context).web3InstitutionAccent,
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
                value: _allowRegistration
                    ? l10n.commonEnabled
                    : l10n.commonOff,
                icon: Icons.how_to_reg_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.eventCreatorReadinessTitle,
          subtitle: l10n.eventCreatorReadinessSubtitle,
          icon: Icons.fact_check_outlined,
          accentColor: accent,
          child: DesktopCreatorReadinessChecklist(
            items: readyItems,
            accentColor: accent,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: l10n.eventCreatorQuickActionsTitle,
          subtitle: l10n.eventCreatorQuickActionsSubtitle,
          icon: Icons.flash_on_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _submitting
                    ? null
                    : (_currentStep < 3 ? _nextStep : _createEvent),
                icon: Icon(_currentStep < 3 ? Icons.arrow_forward : Icons.save_outlined),
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
          accentColor: accent,
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
            _buildTextField(
              controller: _descriptionController,
              label: l10n.commonDescription,
              hint: l10n.eventCreatorDescriptionHint,
              maxLines: 4,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return l10n.eventCreatorDescriptionRequiredError;
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
        ],
      ),
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
            _buildReviewItem(l10n.eventCreatorReviewTypeLabel, _eventTypeLabel(_eventType, l10n)),
            _buildReviewItem(l10n.eventCreatorReviewCategoryLabel, _categoryLabel(_category, l10n)),
          _buildReviewItem(
              l10n.eventCreatorReviewLocationLabel,
              _locationController.text.isNotEmpty
                  ? _locationController.text
                : l10n.eventCreatorLocationLabel),
            _buildReviewItem(l10n.eventCreatorReviewDateLabel, _formatDateRange(l10n)),
            _buildReviewItem(l10n.eventCreatorReviewTimeLabel, _formatTimeRange(l10n)),
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
            _buildReviewItem(
              l10n.eventCreatorReviewPublicLabel,
              _isPublic ? l10n.commonEnabled : l10n.commonDisabled),
          _buildReviewItem(
              l10n.eventCreatorReviewRegistrationLabel,
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
                      : AppLocalizations.of(context)!.eventCreatorSelectDateLabel,
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
                      : AppLocalizations.of(context)!.eventCreatorSelectTimeLabel,
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

    final provider = context.read<InstitutionProvider>();
    final institutions = provider.institutions;
    final institutionId = (_institutionId != null && _institutionId!.isNotEmpty)
        ? _institutionId!
        : provider.selectedInstitution?.id ??
            (institutions.isNotEmpty ? institutions.first.id : null);

    if (institutionId == null || institutionId.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorNoInstitutionAvailableToast)),
      );
      return;
    }

    final institution = provider.getInstitutionById(institutionId);
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

    final priceText = _priceController.text.trim();
    final capacityText = _capacityController.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);

    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final createdBy = WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );

    final initial = widget.initialEvent;
    final event = Event(
      id: initial?.id ?? 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _parseEventType(_eventType),
      category: _parseEventCategory(_category),
      institutionId: institutionId,
      institution: institution,
      startDate: startAt,
      endDate: endAt,
      location: _locationController.text.trim(),
      latitude: institution.latitude,
      longitude: institution.longitude,
      price: price,
      capacity: capacity,
      currentAttendees: initial?.currentAttendees ?? 0,
      isPublic: _isPublic,
      allowRegistration: _allowRegistration,
      imageUrls: initial?.imageUrls ?? const [],
      featuredArtworkIds: initial?.featuredArtworkIds ?? const [],
      artistIds: initial?.artistIds ?? const [],
      createdAt: initial?.createdAt ?? DateTime.now(),
      createdBy: (initial?.createdBy.isNotEmpty == true)
          ? initial!.createdBy
          : (createdBy.isNotEmpty ? createdBy : 'local_user'),
    );

    try {
      if (_isEditing) {
        await provider.updateEvent(event);
      } else {
        await provider.createEvent(event);
      }

      if (!mounted) return;
      final shellScope = DesktopShellScope.of(context);
      setState(() {
        _createdEvent = event;
      });
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
            style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
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
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.eventCreatorSaveFailedToast)),
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
    if (_startDate == null || _endDate == null) return l10n.eventCreatorNotSelectedLabel;
    final localizations = MaterialLocalizations.of(context);
    if (_startDate == _endDate) {
      return localizations.formatShortDate(_startDate!);
    }
    return '${localizations.formatShortDate(_startDate!)} - ${localizations.formatShortDate(_endDate!)}';
  }

  String _formatTimeRange(AppLocalizations l10n) {
    if (_startTime == null || _endTime == null) return l10n.eventCreatorNotSelectedLabel;
    return '${_startTime!.format(context)} - ${_endTime!.format(context)}';
  }

  EventType _parseEventType(String code) {
    switch (code.toLowerCase()) {
      case 'workshop':
        return EventType.workshop;
      case 'conference':
      case 'talk':
        return EventType.conference;
      case 'performance':
        return EventType.performance;
      case 'gallery_opening':
        return EventType.galleryOpening;
      case 'auction':
        return EventType.auction;
      case 'exhibition':
      default:
        return EventType.exhibition;
    }
  }

  EventCategory _parseEventCategory(String code) {
    switch (code.toLowerCase()) {
      case 'art':
        return EventCategory.art;
      case 'digital_art':
      case 'digital':
        return EventCategory.digital;
      case 'photography':
        return EventCategory.photography;
      case 'sculpture':
        return EventCategory.sculpture;
      case 'mixed_media':
      case 'mixedmedia':
        return EventCategory.mixedMedia;
      case 'installation':
        return EventCategory.installation;
      default:
        return EventCategory.art;
    }
  }

  String _eventTypeCode(EventType type) {
    switch (type) {
      case EventType.exhibition:
        return 'exhibition';
      case EventType.workshop:
        return 'workshop';
      case EventType.conference:
        return 'conference';
      case EventType.performance:
        return 'performance';
      case EventType.galleryOpening:
        return 'gallery_opening';
      case EventType.auction:
        return 'auction';
    }
  }

  String _categoryCode(EventCategory category) {
    switch (category) {
      case EventCategory.art:
        return 'art';
      case EventCategory.photography:
        return 'photography';
      case EventCategory.sculpture:
        return 'sculpture';
      case EventCategory.digital:
        return 'digital_art';
      case EventCategory.mixedMedia:
        return 'mixed_media';
      case EventCategory.installation:
        return 'installation';
    }
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
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
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
