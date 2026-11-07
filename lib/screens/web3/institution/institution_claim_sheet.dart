import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../models/institution.dart';
import '../../../models/institution_claim.dart';
import '../../../services/backend_api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/common/keyboard_inset_padding.dart';
import '../../../widgets/inline_loading.dart';

/// How the claim sheet ended when it was closed by a decision.
enum InstitutionClaimSheetResult {
  /// The request was sent.
  submitted,

  /// The account already had an open request for this profile.
  alreadyOpen,
}

/// Sends the request. Defaults to the backend; tests substitute their own.
typedef InstitutionClaimSubmit = Future<InstitutionClaimSummary> Function({
  required String institutionId,
  required String message,
  String? claimantTitle,
  String? evidenceUrl,
});

/// Shortest message the form accepts. The backend only caps the length; a
/// sentence of context is what lets an administrator decide.
const int kInstitutionClaimMessageMinLength = 10;

/// Opens the claim request sheet for an imported, unclaimed [institution].
Future<InstitutionClaimSheetResult?> showInstitutionClaimSheet(
  BuildContext context, {
  required Institution institution,
  InstitutionClaimSubmit? submit,
}) {
  return showModalBottomSheet<InstitutionClaimSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => InstitutionClaimSheet(
      institution: institution,
      submit: submit,
    ),
  );
}

class InstitutionClaimSheet extends StatefulWidget {
  const InstitutionClaimSheet({
    super.key,
    required this.institution,
    this.submit,
  });

  final Institution institution;
  final InstitutionClaimSubmit? submit;

  @override
  State<InstitutionClaimSheet> createState() => _InstitutionClaimSheetState();
}

class _InstitutionClaimSheetState extends State<InstitutionClaimSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _evidenceController = TextEditingController();

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  InstitutionClaimSubmit get _submit =>
      widget.submit ?? BackendApiService().submitInstitutionClaim;

  String? _validateEvidence(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok = uri != null &&
        uri.scheme == 'https' &&
        uri.host.contains('.') &&
        text.length <= 2000;
    return ok ? null : l10n.institutionClaimEvidenceInvalid;
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _submit(
        institutionId: widget.institution.id,
        message: _messageController.text,
        claimantTitle: _titleController.text,
        evidenceUrl: _evidenceController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(InstitutionClaimSheetResult.submitted);
    } on BackendApiRequestException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        Navigator.of(context).pop(InstitutionClaimSheetResult.alreadyOpen);
        return;
      }
      setState(() {
        _sending = false;
        // 503 is the backend feature gate: claims are not switched on yet.
        _error = error.statusCode == 503
            ? l10n.institutionClaimUnavailableToast
            : l10n.institutionClaimFailedToast;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = l10n.institutionClaimFailedToast;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = widget.institution.name.trim();

    return KeyboardInsetPadding(
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KubusRadius.xl),
            topRight: Radius.circular(KubusRadius.xl),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.institutionClaimSheetTitle(name),
                        style: KubusTextStyles.detailSectionTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    Text(
                      l10n.institutionClaimSheetIntro,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.md),
                    TextFormField(
                      key: const ValueKey('institution-claim-title'),
                      controller: _titleController,
                      enabled: !_sending,
                      maxLength: 255,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.institutionClaimTitleLabel,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('institution-claim-message'),
                      controller: _messageController,
                      enabled: !_sending,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l10n.institutionClaimMessageLabel,
                        alignLabelWithHint: true,
                        counterText: '',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) <
                              kInstitutionClaimMessageMinLength
                          ? l10n.institutionClaimMessageMinError(
                              kInstitutionClaimMessageMinLength)
                          : null,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('institution-claim-evidence'),
                      controller: _evidenceController,
                      enabled: !_sending,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.institutionClaimEvidenceLabel,
                      ),
                      validator: (value) => _validateEvidence(value, l10n),
                      onFieldSubmitted: (_) => _send(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const ValueKey('institution-claim-error'),
                          style: KubusTextStyles.detailBody.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: KubusSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(l10n.commonCancel),
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        FilledButton(
                          key: const ValueKey('institution-claim-submit'),
                          onPressed: _sending ? null : _send,
                          child: _sending
                              ? const InlineLoading(width: 18, height: 18)
                              : Text(l10n.institutionClaimSubmit),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
