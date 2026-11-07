import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/institution.dart';
import '../../providers/account_verification_provider.dart';
import '../../screens/web3/institution/institution_claim_sheet.dart';
import '../../services/backend_api_service.dart';
import '../../utils/design_tokens.dart';
import '../common/keyboard_inset_padding.dart';
import '../common/kubus_screen_header.dart';
import '../dashboard/kubus_dashboard_chrome.dart';
import '../inline_loading.dart';
import '../kubus_button.dart';
import '../kubus_snackbar.dart';

/// Institution access for an account that is not yet a member of one.
///
/// Two paths, both reviewed by an administrator and both without a wallet:
/// claim an existing listing, or request a NEW institutional presence when
/// none exists. Open requests are listed with their server-side status, so a
/// pending request is never submitted twice by accident.
class InstitutionVerificationPanel extends StatelessWidget {
  const InstitutionVerificationPanel({super.key, this.onRequestSent});

  /// Called after a claim or a presence request was sent.
  final VoidCallback? onRequestSent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AccountVerificationProvider>();

    final KubusStatusTone tone;
    final String? detail;
    final String? statusLabel;
    if (provider.isUnavailable) {
      tone = KubusStatusTone.neutral;
      detail = l10n.verificationUnavailable;
      statusLabel = null;
    } else if (provider.legacyRoleWithoutMembership) {
      tone = KubusStatusTone.warning;
      detail = l10n.verificationInstitutionLegacyNotice;
      statusLabel = null;
    } else if (provider.hasOpenInstitutionRequest) {
      tone = KubusStatusTone.warning;
      detail = null;
      statusLabel = l10n.verificationStatusPending;
    } else {
      tone = KubusStatusTone.neutral;
      detail = null;
      statusLabel = provider.isReady ? l10n.verificationStatusNotApplied : null;
    }

    final canAct = provider.isReady && provider.institutionsAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KubusStatusPanel(
          title: l10n.verificationInstitutionCardTitle,
          description: l10n.verificationInstitutionCardSubtitle,
          statusLabel: statusLabel,
          tone: tone,
          isLoading: provider.isLoading,
          detail: detail,
          action: provider.isUnavailable
              ? KubusButton(
                  onPressed: () => provider.refresh(),
                  label: l10n.verificationCtaRetry,
                  icon: Icons.refresh_rounded,
                  isFullWidth: true,
                  variant: KubusButtonVariant.secondary,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KubusButton(
                      key: const ValueKey('verification-claim-action'),
                      onPressed: canAct
                          ? () async {
                              final sent =
                                  await showInstitutionDirectorySheet(context);
                              if (sent) onRequestSent?.call();
                            }
                          : null,
                      label: l10n.verificationInstitutionClaimTitle,
                      icon: Icons.search_rounded,
                      isFullWidth: true,
                      variant: KubusButtonVariant.primary,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    KubusButton(
                      key: const ValueKey('verification-request-action'),
                      onPressed: canAct
                          ? () async {
                              final sent =
                                  await showInstitutionPresenceRequestSheet(
                                      context);
                              if (sent) onRequestSent?.call();
                            }
                          : null,
                      label: l10n.verificationInstitutionRequestTitle,
                      icon: Icons.add_business_outlined,
                      isFullWidth: true,
                      variant: KubusButtonVariant.secondary,
                    ),
                  ],
                ),
        ),
        if (provider.isReady &&
            (provider.claims.isNotEmpty ||
                provider.presenceRequests.isNotEmpty))
          _RequestsList(provider: provider),
      ],
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({required this.provider});

  final AccountVerificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      for (final request in provider.presenceRequests)
        _RequestRow(
          key: ValueKey('presence-${request.id}'),
          title: request.name,
          kind: l10n.verificationRequestKindPresence,
          status: _statusLabel(l10n, request.status),
          onWithdraw: request.isOpen
              ? () async {
                  try {
                    await provider.withdrawPresenceRequest(request.id);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showKubusSnackBar(
                        SnackBar(content: Text(l10n.verificationSubmitFailed)),
                      );
                    }
                  }
                }
              : null,
        ),
      for (final claim in provider.claims)
        _RequestRow(
          key: ValueKey('claim-${claim.id}'),
          title: claim.institutionName ?? '',
          kind: l10n.verificationRequestKindClaim,
          status: _statusLabel(l10n, claim.status),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.verificationInstitutionRequestsTitle,
              style: KubusTextStyles.detailSectionTitle
                  .copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          ...rows,
        ],
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'submitted':
      return l10n.verificationRequestStatusSubmitted;
    case 'under_review':
      return l10n.verificationRequestStatusUnderReview;
    case 'approved':
      return l10n.verificationRequestStatusApproved;
    case 'rejected':
      return l10n.verificationRequestStatusRejected;
    case 'withdrawn':
      return l10n.verificationRequestStatusWithdrawn;
    case 'revoked':
      return l10n.verificationRequestStatusRevoked;
    default:
      return status;
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    super.key,
    required this.title,
    required this.kind,
    required this.status,
    this.onWithdraw,
  });

  final String title;
  final String kind;
  final String status;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: KubusTextStyles.detailBody
                        .copyWith(color: scheme.onSurface),
                  ),
                Text(
                  '$kind · $status',
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (onWithdraw != null)
            TextButton(
              onPressed: onWithdraw,
              child: Text(l10n.verificationRequestWithdraw),
            ),
        ],
      ),
    );
  }
}

/// Chooses which institution the account acts for. Shown only when the
/// account belongs to more than one; the choice is always one of the
/// server-confirmed memberships.
class InstitutionSelector extends StatelessWidget {
  const InstitutionSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountVerificationProvider>();
    final memberships = provider.memberships;
    if (memberships.length < 2) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final selected = provider.selectedMembership;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('institution-selector'),
        initialValue: selected?.institutionId,
        isExpanded: true,
        decoration:
            InputDecoration(labelText: l10n.verificationInstitutionActingFor),
        items: [
          for (final membership in memberships)
            DropdownMenuItem<String>(
              value: membership.institutionId,
              child: Text(
                '${membership.institutionName} · ${roleLabel(l10n, membership.role)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) provider.selectInstitution(value);
        },
      ),
    );
  }
}

String roleLabel(AppLocalizations l10n, String role) {
  switch (role) {
    case 'owner':
      return l10n.verificationInstitutionRoleOwner;
    case 'admin':
      return l10n.verificationInstitutionRoleAdmin;
    case 'editor':
      return l10n.verificationInstitutionRoleEditor;
    default:
      return l10n.verificationInstitutionRoleViewer;
  }
}

BoxDecoration _sheetDecoration(ColorScheme scheme) => BoxDecoration(
      color: scheme.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(KubusRadius.xl),
        topRight: Radius.circular(KubusRadius.xl),
      ),
    );

// --------------------------------------------------------------------------
// Find an existing listing and claim it
// --------------------------------------------------------------------------

/// Search the public listings by name and claim one. Returns true once a claim
/// was sent.
Future<bool> showInstitutionDirectorySheet(BuildContext context) async {
  final provider = context.read<AccountVerificationProvider>();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<AccountVerificationProvider>.value(
      value: provider,
      child: const _InstitutionDirectorySheet(),
    ),
  );
  return sent == true;
}

class _InstitutionDirectorySheet extends StatefulWidget {
  const _InstitutionDirectorySheet();

  @override
  State<_InstitutionDirectorySheet> createState() =>
      _InstitutionDirectorySheetState();
}

class _InstitutionDirectorySheetState
    extends State<_InstitutionDirectorySheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _searchGeneration = 0;
  bool _searching = false;
  bool _searched = false;
  List<Institution> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String term) async {
    final generation = ++_searchGeneration;
    setState(() => _searching = true);
    List<Institution> parsed = const [];
    try {
      final raw = await BackendApiService().listInstitutions(
        limit: 10,
        search: term,
      );
      parsed = raw.map(Institution.fromJson).toList(growable: false);
    } catch (error) {
      if (kDebugMode) debugPrint('Institution search failed: $error');
    }
    // A slower earlier search must not overwrite a newer one.
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = parsed;
      _searching = false;
      _searched = true;
    });
  }

  Future<void> _claim(Institution institution) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = context.read<AccountVerificationProvider>();
    final result =
        await showInstitutionClaimSheet(context, institution: institution);
    if (result == null) return;
    await provider.refresh();
    if (result == InstitutionClaimSheetResult.submitted) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.verificationClaimSent)),
      );
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return KeyboardInsetPadding(
      child: Container(
        decoration: _sheetDecoration(scheme),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KubusSheetHeader(
                    title: l10n.verificationInstitutionClaimTitle,
                    subtitle: l10n.verificationInstitutionClaimBody,
                    showHandle: false,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  TextField(
                    key: const ValueKey('institution-directory-search'),
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      labelText: l10n.verificationInstitutionSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(KubusSpacing.md),
                      child:
                          Center(child: InlineLoading(width: 24, height: 24)),
                    )
                  else if (_searched && _results.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.verificationInstitutionSearchEmpty,
                          key: const ValueKey('institution-directory-empty'),
                          style: KubusTextStyles.detailBody.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final institution in _results)
                            _DirectoryRow(
                              institution: institution,
                              onClaim: institution.claimState == 'unclaimed'
                                  ? () => _claim(institution)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: KubusSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({required this.institution, this.onClaim});

  final Institution institution;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final location =
        institution.address.trim().isEmpty ? null : institution.address.trim();
    return ListTile(
      key: ValueKey('directory-${institution.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(institution.name),
      subtitle: location == null
          ? null
          : Text(location,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
      trailing: onClaim != null
          ? FilledButton(
              onPressed: onClaim,
              child: Text(l10n.verificationInstitutionClaimAction),
            )
          : Text(
              l10n.verificationInstitutionAlreadyManaged,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
    );
  }
}

// --------------------------------------------------------------------------
// Request a NEW institutional presence
// --------------------------------------------------------------------------

const List<(String, InstitutionKind)> _requestKinds = [
  ('museum', InstitutionKind.museum),
  ('gallery', InstitutionKind.gallery),
  ('arts_centre', InstitutionKind.artsCentre),
  ('exhibition_space', InstitutionKind.exhibitionSpace),
  ('cultural_centre', InstitutionKind.culturalCentre),
  ('other', InstitutionKind.other),
];

String _kindLabel(AppLocalizations l10n, InstitutionKind kind) {
  switch (kind) {
    case InstitutionKind.museum:
      return l10n.institutionDetailKindMuseum;
    case InstitutionKind.gallery:
      return l10n.institutionDetailKindGallery;
    case InstitutionKind.artsCentre:
      return l10n.institutionDetailKindArtsCentre;
    case InstitutionKind.exhibitionSpace:
      return l10n.institutionDetailKindExhibitionSpace;
    case InstitutionKind.culturalCentre:
      return l10n.institutionDetailKindCulturalCentre;
    case InstitutionKind.other:
      return l10n.institutionDetailKindOther;
  }
}

/// Opens the request form for a new institutional presence. Returns true once
/// a request was sent.
Future<bool> showInstitutionPresenceRequestSheet(BuildContext context) async {
  final provider = context.read<AccountVerificationProvider>();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<AccountVerificationProvider>.value(
      value: provider,
      child: const _PresenceRequestSheet(),
    ),
  );
  return sent == true;
}

class _PresenceRequestSheet extends StatefulWidget {
  const _PresenceRequestSheet();

  @override
  State<_PresenceRequestSheet> createState() => _PresenceRequestSheetState();
}

class _PresenceRequestSheetState extends State<_PresenceRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _website = TextEditingController();
  final _location = TextEditingController();
  final _role = TextEditingController();
  final _message = TextEditingController();
  final _evidence = TextEditingController();
  String _kind = 'gallery';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _location.dispose();
    _role.dispose();
    _message.dispose();
    _evidence.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _duplicateCandidates(String? body) {
    if (body == null || body.isEmpty) return const [];
    try {
      final decoded = jsonDecode(body);
      final candidates = decoded is Map ? decoded['candidates'] : null;
      if (candidates is! List) return const [];
      return candidates
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _errorCode(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded['error']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _send({bool confirmNotDuplicate = false}) async {
    if (_sending) return;
    if (!confirmNotDuplicate && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AccountVerificationProvider>();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await provider.submitPresenceRequest(
        name: _name.text,
        kind: _kind,
        message: _message.text,
        website: _website.text,
        location: _location.text,
        requesterTitle: _role.text,
        evidenceUrl: _evidence.text,
        confirmNotDuplicate: confirmNotDuplicate,
      );
      if (!mounted) return;
      if (sent == null) {
        navigator.pop(false);
        return;
      }
      navigator.pop(true);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.verificationPresenceSubmitted)),
      );
    } on BackendApiRequestException catch (error) {
      if (!mounted) return;
      final code = _errorCode(error.body);
      if (error.statusCode == 409 && code == 'possible_duplicate') {
        setState(() => _sending = false);
        final proceed = await _confirmNotDuplicate(
          l10n,
          _duplicateCandidates(error.body),
        );
        if (proceed == true && mounted) {
          await _send(confirmNotDuplicate: true);
        }
        return;
      }
      setState(() {
        _sending = false;
        _error = switch (code) {
          'too_many_open_requests' => l10n.verificationPresenceTooMany,
          'request_already_open' => l10n.verificationPresenceTooMany,
          _ => l10n.verificationSubmitFailed,
        };
      });
    } catch (error) {
      if (kDebugMode) debugPrint('Presence request failed: $error');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = l10n.verificationSubmitFailed;
      });
    }
  }

  Future<bool?> _confirmNotDuplicate(
    AppLocalizations l10n,
    List<Map<String, dynamic>> candidates,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.verificationPresenceDuplicateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.verificationPresenceDuplicateBody),
            const SizedBox(height: KubusSpacing.sm),
            for (final candidate in candidates)
              Text('• ${candidate['name'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('presence-duplicate-continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.verificationPresenceDuplicateContinue),
          ),
        ],
      ),
    );
  }

  String? _validateUrl(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.contains('.') &&
        text.length <= 2000;
    return ok ? null : l10n.institutionClaimEvidenceInvalid;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return KeyboardInsetPadding(
      child: Container(
        decoration: _sheetDecoration(scheme),
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
                    KubusSheetHeader(
                      title: l10n.verificationInstitutionRequestTitle,
                      subtitle: l10n.verificationInstitutionRequestBody,
                      showHandle: false,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-name'),
                      controller: _name,
                      enabled: !_sending,
                      maxLength: 255,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldName,
                        counterText: '',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? l10n.verificationPresenceValidationName
                          : null,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('presence-kind'),
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldKind,
                      ),
                      items: [
                        for (final (code, kind) in _requestKinds)
                          DropdownMenuItem(
                            value: code,
                            child: Text(_kindLabel(l10n, kind)),
                          ),
                      ],
                      onChanged: _sending
                          ? null
                          : (value) => setState(() => _kind = value ?? _kind),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-website'),
                      controller: _website,
                      enabled: !_sending,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldWebsite,
                      ),
                      validator: (value) {
                        final urlError = _validateUrl(value, l10n);
                        if (urlError != null) return urlError;
                        final hasEvidence = _evidence.text.trim().isNotEmpty;
                        if ((value?.trim().isEmpty ?? true) && !hasEvidence) {
                          return l10n.verificationPresenceValidationContact;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-location'),
                      controller: _location,
                      enabled: !_sending,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldLocation,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-role'),
                      controller: _role,
                      enabled: !_sending,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldRole,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-message'),
                      controller: _message,
                      enabled: !_sending,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldMessage,
                        alignLabelWithHint: true,
                        counterText: '',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 20
                          ? l10n.verificationPresenceValidationMessage
                          : null,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    TextFormField(
                      key: const ValueKey('presence-evidence'),
                      controller: _evidence,
                      enabled: !_sending,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: l10n.verificationPresenceFieldEvidence,
                      ),
                      validator: (value) => _validateUrl(value, l10n),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const ValueKey('presence-error'),
                          style: KubusTextStyles.detailBody
                              .copyWith(color: scheme.error),
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
                              : () => Navigator.of(context).pop(false),
                          child: Text(l10n.commonCancel),
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        FilledButton(
                          key: const ValueKey('presence-submit'),
                          onPressed: _sending ? null : () => _send(),
                          child: _sending
                              ? const InlineLoading(width: 18, height: 18)
                              : Text(l10n.verificationPresenceSubmit),
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
