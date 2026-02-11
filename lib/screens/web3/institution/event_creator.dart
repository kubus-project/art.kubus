import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/wallet_utils.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class EventCreator extends StatefulWidget {
  final Event? initialEvent;

  const EventCreator({super.key, this.initialEvent});

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
  String _eventType = 'Exhibition';
  String _category = 'Art';
  bool _isPublic = true;
  bool _allowRegistration = true;
  int _currentStep = 0;

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
      _eventType = _eventTypeLabel(initial.type);
      _category = _categoryLabel(initial.category);
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
    return FadeTransition(
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
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Event' : 'Create New Event',
                style: KubusTextStyles.screenTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              Text(
                'Step ${_currentStep + 1} of 4',
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.help_outline,
                color: scheme.onPrimary),
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
              margin: EdgeInsets.only(
                  right: index < 3 ? KubusSpacing.sm : 0),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Basic Information'),
            const SizedBox(height: KubusSpacing.lg),
            _buildInstitutionSelector(),
            const SizedBox(height: KubusSpacing.md),
            _buildTextField(
              controller: _titleController,
              label: 'Event Title',
              hint: 'Enter event title',
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter event title';
                }
                return null;
              },
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your event',
              maxLines: 4,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter event description';
                }
                return null;
              },
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildDropdown(
              label: 'Event Type',
              value: _eventType,
              items: [
                'Exhibition',
                'Workshop',
                'Talk',
                'Performance',
                'Conference'
              ],
              onChanged: (value) => setState(() => _eventType = value!),
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildDropdown(
              label: 'Category',
              value: _category,
              items: [
                'Art',
                'Digital Art',
                'Photography',
                'Sculpture',
                'Mixed Media'
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Date & Time'),
          const SizedBox(height: KubusSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: () => _selectDate(true),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTimeField(
                  label: 'Start Time',
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
                  label: 'End Date',
                  date: _endDate,
                  onTap: () => _selectDate(false),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTimeField(
                  label: 'End Time',
                  time: _endTime,
                  onTap: () => _selectTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildTextField(
            controller: _locationController,
            label: 'Location',
            hint: 'Enter venue or location',
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter location';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Event Details'),
          const SizedBox(height: KubusSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _capacityController,
                  label: 'Capacity',
                  hint: 'Maximum attendees',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter capacity';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: _buildTextField(
                  controller: _priceController,
                  label: 'Price (\$)',
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          _buildSwitchTile(
            title: 'Public Event',
            subtitle: 'Allow public discovery and registration',
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildSwitchTile(
            title: 'Allow Registration',
            subtitle: 'Enable online registration for this event',
            value: _allowRegistration,
            onChanged: (value) => setState(() => _allowRegistration = value),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Review & Confirm'),
          const SizedBox(height: KubusSpacing.lg),
          _buildReviewCard(),
          const SizedBox(height: KubusSpacing.lg),
          Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: accent,
                ),
                const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                Expanded(
                  child: Text(
                    'Your event will be reviewed and published within 24 hours.',
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
            color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isNotEmpty
                ? _titleController.text
                : 'Event Title',
            style: KubusTextStyles.screenTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : 'Event Description',
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildReviewItem('Type', _eventType),
          _buildReviewItem('Category', _category),
          _buildReviewItem(
              'Location',
              _locationController.text.isNotEmpty
                  ? _locationController.text
                  : 'Location'),
          _buildReviewItem('Date', _formatDateRange()),
          _buildReviewItem('Time', _formatTimeRange()),
          _buildReviewItem(
              'Capacity',
              _capacityController.text.isNotEmpty
                  ? _capacityController.text
                  : '0'),
          _buildReviewItem(
              'Price',
              _priceController.text.isNotEmpty
                  ? '\$${_priceController.text}'
                  : 'Free'),
          _buildReviewItem('Public', _isPublic ? 'Yes' : 'No'),
          _buildReviewItem(
              'Registration', _allowRegistration ? 'Enabled' : 'Disabled'),
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
            hintStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.4)),
            filled: true,
            fillColor: scheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                  color: scheme.outline.withValues(alpha: 0.25)),
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
        final scheme = Theme.of(context).colorScheme;
        final institutions = provider.institutions;
        if (institutions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_city,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    size: 18),
                const SizedBox(width: KubusSpacing.sm),
                Expanded(
                  child: Text(
                    'No institutions available. Load or create an institution first.',
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
              'Institution',
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
                border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.25)),
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
            border: Border.all(
                color: scheme.outline.withValues(alpha: 0.25)),
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
                child: Text(item),
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
              border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: scheme.onSurface.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'Select date',
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
              border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: scheme.onSurface.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  time != null ? time.format(context) : 'Select time',
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
            color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KubusTextStyles.detailLabel.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: KubusSpacing.xxs),
                  child: Text(
                    subtitle,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: KubusColorRoles.of(context).web3InstitutionAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3InstitutionAccent;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _currentStep--),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      scheme.onSurface.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: KubusTextStyles.detailButton.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < 3 ? _nextStep : _createEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: scheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
              ),
              child: Text(
                _currentStep < 3 ? 'Next' : 'Create Event',
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
      final l10n = AppLocalizations.of(context)!;
      showKubusDialog(
        context: context,
        builder: (context) => KubusAlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(
            _isEditing
                ? l10n.eventCreatorEventUpdatedTitle
                : l10n.eventCreatorEventCreatedTitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Text(
            _isEditing
                ? l10n.eventCreatorEventUpdatedBody
                : l10n.eventCreatorEventCreatedBody,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_isEditing) {
                  Navigator.pop(context);
                } else {
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
      _eventType = 'Exhibition';
      _category = 'Art';
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

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) return 'Not selected';
    if (_startDate == _endDate) {
      return '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}';
    }
    return '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
  }

  String _formatTimeRange() {
    if (_startTime == null || _endTime == null) return 'Not selected';
    return '${_startTime!.format(context)} - ${_endTime!.format(context)}';
  }

  EventType _parseEventType(String label) {
    switch (label.toLowerCase()) {
      case 'exhibition':
        return EventType.exhibition;
      case 'workshop':
        return EventType.workshop;
      case 'performance':
        return EventType.performance;
      case 'talk':
      case 'conference':
        return EventType.conference;
      default:
        return EventType.exhibition;
    }
  }

  EventCategory _parseEventCategory(String label) {
    switch (label.toLowerCase()) {
      case 'art':
        return EventCategory.art;
      case 'digital art':
      case 'digital':
        return EventCategory.digital;
      case 'photography':
        return EventCategory.photography;
      case 'sculpture':
        return EventCategory.sculpture;
      case 'mixed media':
      case 'mixedmedia':
        return EventCategory.mixedMedia;
      default:
        return EventCategory.art;
    }
  }

  String _eventTypeLabel(EventType type) {
    switch (type) {
      case EventType.exhibition:
        return 'Exhibition';
      case EventType.workshop:
        return 'Workshop';
      case EventType.conference:
        return 'Conference';
      case EventType.performance:
        return 'Performance';
      case EventType.galleryOpening:
        return 'Gallery Opening';
      case EventType.auction:
        return 'Auction';
    }
  }

  String _categoryLabel(EventCategory category) {
    switch (category) {
      case EventCategory.art:
        return 'Art';
      case EventCategory.photography:
        return 'Photography';
      case EventCategory.sculpture:
        return 'Sculpture';
      case EventCategory.digital:
        return 'Digital Art';
      case EventCategory.mixedMedia:
        return 'Mixed Media';
      case EventCategory.installation:
        return 'Installation';
    }
  }

  void _showHelp() {
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Event Creation Help',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Follow the 4-step process to create your event:\n\n'
          '1. Basic Info: Enter title, description, and type\n'
          '2. Date & Time: Set when your event occurs\n'
          '3. Details: Configure capacity, pricing, and settings\n'
          '4. Review: Confirm all details before creating',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }
}
