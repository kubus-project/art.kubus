import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../../config/config.dart';
import '../../providers/exhibitions_provider.dart';
import 'exhibition_detail_screen.dart';

class ExhibitionCreatorScreen extends StatefulWidget {
  const ExhibitionCreatorScreen({super.key});

  @override
  State<ExhibitionCreatorScreen> createState() => _ExhibitionCreatorScreenState();
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
        messenger.showSnackBar(
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (!AppConfig.isFeatureEnabled('exhibitions')) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exhibitionCreatorDisabledAppBarTitle, style: GoogleFonts.inter())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.exhibitionCreatorDisabledMessage,
              style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.75)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.exhibitionCreatorAppBarTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  l10n.exhibitionCreatorBasicsTitle,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.exhibitionCreatorTitleLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return l10n.exhibitionCreatorTitleValidation;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.exhibitionCreatorDescriptionLabel,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: l10n.exhibitionCreatorLocationLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.exhibitionCreatorScheduleTitle,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _DateRow(
                  label: l10n.exhibitionCreatorStartsLabel,
                  value: _startsAt,
                  onPick: () => _pickDate(isStart: true),
                  onClear: () => setState(() => _startsAt = null),
                ),
                const SizedBox(height: 10),
                _DateRow(
                  label: l10n.exhibitionCreatorEndsLabel,
                  value: _endsAt,
                  onPick: () => _pickDate(isStart: false),
                  onClear: () => setState(() => _endsAt = null),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _published,
                  title: Text(l10n.exhibitionCreatorPublishTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _published ? l10n.exhibitionCreatorPublishVisible : l10n.exhibitionCreatorPublishDraft,
                    style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                  ),
                  onChanged: _submitting ? null : (v) => setState(() => _published = v),
                ),
                const SizedBox(height: 16),

                Text(
                  l10n.commonCoverImage,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickCoverImage,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _coverBytes == null ? l10n.commonUpload : l10n.commonChangeCover,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l10n.commonRemove,
                      onPressed: (_submitting || _coverBytes == null)
                          ? null
                          : () => setState(() {
                                _coverBytes = null;
                                _coverFileName = null;
                              }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                if (_coverBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: scheme.surfaceContainerHighest,
                      child: Image.memory(
                        _coverBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Collaboration hint
                if (AppConfig.isFeatureEnabled('collabInvites'))
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.group_add_outlined, size: 20, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.exhibitionCreatorCollabHint,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(l10n.commonCreate, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      messenger.showSnackBar(
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
          messenger.showSnackBar(
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
        messenger.showSnackBar(SnackBar(content: Text(l10n.exhibitionCreatorCreateFailed)));
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exhibitionCreatorCreateFailedWithError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final text = value == null
      ? l10n.exhibitionCreatorNotSetLabel
        : '${value!.year.toString().padLeft(4, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text('$label: $text', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.commonClear,
          onPressed: value == null ? null : onClear,
          icon: Icon(Icons.close, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
