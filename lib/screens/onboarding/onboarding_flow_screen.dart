import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/dao.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/notification_helper.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/push_notification_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/services/wallet_session_sync_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/dao_role_verification.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/auth_entry_controls.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/user_persona_picker_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OnboardingStep {
  welcome,

  // Phase 2a: Guest branch
  guestPermissions,

  // Phase 2b: Account branch
  account,
  verifyEmail,
  role,
  profile,
  walletBackup,
  daoReview,
  accountPermissions,
  done,
}

enum _OnboardingBranch {
  none,
  guest,
  account,
}

class _StepPalette {
  const _StepPalette({
    required this.start,
    required this.end,
    required this.accent,
  });

  final Color start;
  final Color end;
  final Color accent;
}

class _DaoApplicationDraftRecord {
  const _DaoApplicationDraftRecord({
    required this.isArtist,
    required this.isInstitution,
    required this.title,
    required this.contact,
    required this.portfolioUrl,
    required this.medium,
    required this.statement,
  });

  final bool isArtist;
  final bool isInstitution;
  final String title;
  final String contact;
  final String portfolioUrl;
  final String medium;
  final String statement;

  bool get hasContent =>
      title.isNotEmpty ||
      contact.isNotEmpty ||
      portfolioUrl.isNotEmpty ||
      medium.isNotEmpty ||
      statement.isNotEmpty;

  bool get isSubmittable {
    if (isInstitution) {
      return title.isNotEmpty &&
          contact.isNotEmpty &&
          medium.isNotEmpty &&
          statement.isNotEmpty;
    }
    if (isArtist) {
      return portfolioUrl.isNotEmpty &&
          medium.isNotEmpty &&
          statement.isNotEmpty;
    }
    return false;
  }

  bool get isEligibleRole => isArtist || isInstitution;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isArtist': isArtist,
      'isInstitution': isInstitution,
      'title': title,
      'contact': contact,
      'portfolioUrl': portfolioUrl,
      'medium': medium,
      'statement': statement,
    };
  }

  factory _DaoApplicationDraftRecord.fromJson(Map<String, dynamic> json) {
    return _DaoApplicationDraftRecord(
      isArtist: json['isArtist'] == true,
      isInstitution: json['isInstitution'] == true,
      title: (json['title'] ?? '').toString().trim(),
      contact: (json['contact'] ?? '').toString().trim(),
      portfolioUrl: (json['portfolioUrl'] ?? '').toString().trim(),
      medium: (json['medium'] ?? '').toString().trim(),
      statement: (json['statement'] ?? '').toString().trim(),
    );
  }
}

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    this.forceDesktop = false,
    this.initialStepId,
  });

  final bool forceDesktop;
  final String? initialStepId;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen>
    with WidgetsBindingObserver {
  static const int _flowVersion = AuthOnboardingService.onboardingFlowVersion;
  static const String _personaDraftKey = 'onboarding_persona_draft_v3';
  static const String _profileDraftKey = 'onboarding_profile_draft_v3';
  static const String _daoDraftKey = 'onboarding_dao_application_draft_v1';
  static const String _verificationEmailDraftKey =
      'onboarding_verification_email_v3';
  static const String _verificationPendingFlagKey =
      'onboarding_pending_email_verification_v1';
  static const String _verificationSignupMethodKey =
      'onboarding_pending_signup_method_v1';
  static const String _emailSignupMethod = 'email';
  static const Duration _verificationPollInterval = Duration(seconds: 4);
  static const Duration _verificationPollMaxDuration = Duration(seconds: 75);

  List<_OnboardingStep> _steps = const <_OnboardingStep>[];
  final Set<_OnboardingStep> _completed = <_OnboardingStep>{};
  final Set<_OnboardingStep> _deferred = <_OnboardingStep>{};

  _OnboardingBranch _branch = _OnboardingBranch.none;
  bool _isFinishingOnboarding = false;

  int _currentIndex = 0;
  bool _isInitializing = true;
  bool _locationEnabled = false;
  bool _notificationEnabled = false;
  bool _cameraEnabled = false;
  bool _isRequestingPermission = false;
  int _permissionStatusEpoch = 0;
  bool _webLocationGrantedOverride = false;

  bool _isSkippingFlow = false;
  bool _isSignedIn = false;
  bool _pendingEmailVerification = false;
  String? _pendingVerificationEmail;
  String _pendingVerificationSignupMethod = _emailSignupMethod;
  String? _permissionHint;
  UserPersona? _selectedPersona;
  Map<String, String> _localProfileDraft = <String, String>{};
  _DaoApplicationDraftRecord? _daoDraft;
  DAOReview? _daoReview;
  bool _daoReviewLoading = false;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarFileName;
  String? _pendingAvatarMimeType;
  Timer? _verificationPollTimer;
  DateTime? _verificationPollStartedAt;
  bool _verificationPollInFlight = false;
  bool _emailVerifiedConfirmed = false;
  bool _autoAdvancingVerification = false;
  bool _finishSignInPromptShown = false;
  bool _verifiedSigningInMessageShown = false;
  bool _requiresWalletBackupStep = false;
  String? _flowScopeKey;

  bool get _walletBackupOnboardingEnabled =>
      AppConfig.isFeatureEnabled('walletBackupOnboarding');

  _StepPalette _paletteForStep(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return const _StepPalette(
          start: Color(0xFF006064),
          end: KubusColors.accentTealLight,
          accent: Color(0xFF26A69A),
        );
      case _OnboardingStep.guestPermissions:
        return const _StepPalette(
          start: Color(0xFF00695C),
          end: Color(0xFF26A69A),
          accent: Color(0xFF80CBC4),
        );
      case _OnboardingStep.account:
        return const _StepPalette(
          start: Color(0xFF1565C0),
          end: Color(0xFF42A5F5),
          accent: KubusColors.accentBlue,
        );
      case _OnboardingStep.verifyEmail:
        return const _StepPalette(
          start: Color(0xFF2E7D32),
          end: KubusColors.successDark,
          accent: Color(0xFFA5D6A7),
        );
      case _OnboardingStep.role:
        return const _StepPalette(
          start: Color(0xFFE65100),
          end: KubusColors.accentOrangeDark,
          accent: Color(0xFFFFB74D),
        );
      case _OnboardingStep.profile:
        return const _StepPalette(
          start: Color(0xFF00796B),
          end: Color(0xFF4DB6AC),
          accent: KubusColors.accentTealDark,
        );
      case _OnboardingStep.walletBackup:
        return const _StepPalette(
          start: Color(0xFF0D47A1),
          end: Color(0xFF1E88E5),
          accent: Color(0xFF90CAF9),
        );
      case _OnboardingStep.daoReview:
        return const _StepPalette(
          start: Color(0xFF6A1B9A),
          end: Color(0xFF8E24AA),
          accent: Color(0xFFCE93D8),
        );
      case _OnboardingStep.accountPermissions:
        return const _StepPalette(
          start: Color(0xFF00695C),
          end: Color(0xFF26A69A),
          accent: Color(0xFF80CBC4),
        );
      case _OnboardingStep.done:
        return const _StepPalette(
          start: Color(0xFFF57F17),
          end: KubusColors.achievementGoldDark,
          accent: Color(0xFFFFE082),
        );
    }
  }

  bool get _isDesktop =>
      widget.forceDesktop || DesktopBreakpoints.isDesktop(context);

  _OnboardingStep get _currentStep {
    if (_steps.isEmpty) return _OnboardingStep.welcome;
    final safeIndex = _currentIndex.clamp(0, _steps.length - 1);
    return _steps[safeIndex];
  }

  bool get _isWelcomePhase => _branch == _OnboardingBranch.none;

  UserPersona? get _effectivePersona {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    return _selectedPersona ?? profileProvider.userPersona;
  }

  bool get _requiresDaoReviewStep {
    final persona = _effectivePersona;
    return persona == UserPersona.creator || persona == UserPersona.institution;
  }

  DaoRoleType? get _requiredDaoRoleType {
    switch (_effectivePersona) {
      case UserPersona.creator:
        return DaoRoleType.artist;
      case UserPersona.institution:
        return DaoRoleType.institution;
      case UserPersona.lover:
      case null:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (_isInitializing || _steps.isEmpty) return;
    if (_isPermissionRelatedStep(_currentStep)) {
      unawaited(_loadPermissionStatuses());
    }
    if (_currentStep == _OnboardingStep.verifyEmail) {
      _logVerificationRefresh('resume trigger');
      _startVerificationPollingIfNeeded(restartWindow: true);
      unawaited(_pollVerificationStatus(trigger: 'resume'));
    }
  }

  void _logVerificationRefresh(String message) {
    if (!kDebugMode) return;
    debugPrint('OnboardingFlowScreen.$message');
  }

  Future<void> _bootstrap() async {
    try {
      _isSignedIn =
          Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
      final isWidgetTestBinding = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgetsFlutterBinding');

      final prefs = await SharedPreferences.getInstance();
      _hydrateLocalDrafts(prefs);
      await _syncWalletBackupRequirement();

      // Infer branch from initialStepId so that tests and deep-links can jump
      // directly into account or guest steps without going through the welcome
      // wizard.
      final initialStepId = widget.initialStepId?.trim();
      if (initialStepId != null && initialStepId.isNotEmpty) {
        final accountStepIds = AuthOnboardingService.accountStepIds.toSet();
        const guestStepIds = {'guestPermissions'};
        if (accountStepIds.contains(initialStepId)) {
          _branch = _OnboardingBranch.account;
        } else if (guestStepIds.contains(initialStepId)) {
          _branch = _OnboardingBranch.guest;
        }
      }

      _steps = _buildSteps();
      final flowScopeKey =
          _flowScopeKey ?? await _resolveFlowScopeKey(prefs: prefs);
      _flowScopeKey = flowScopeKey;
      final progress = await OnboardingStateService.loadFlowProgress(
        prefs: prefs,
        onboardingVersion: _flowVersion,
        flowScopeKey: flowScopeKey,
      );

      if (!mounted) return;

      final completed = isWidgetTestBinding
          ? <_OnboardingStep>{}
          : progress.completedSteps
              .map(_stepFromId)
              .whereType<_OnboardingStep>()
              .toSet();
      final deferred = isWidgetTestBinding
          ? <_OnboardingStep>{}
          : progress.deferredSteps
              .map(_stepFromId)
              .whereType<_OnboardingStep>()
              .toSet();
      final hasSavedProgress = completed.isNotEmpty || deferred.isNotEmpty;
      var seededInitialProgress = false;
      if (!hasSavedProgress &&
          initialStepId != null &&
          initialStepId.isNotEmpty) {
        final targetIndex =
            _steps.indexWhere((step) => _stepId(step) == initialStepId);
        if (targetIndex > 0) {
          for (final step in _steps.take(targetIndex)) {
            if (completed.add(step)) {
              seededInitialProgress = true;
            }
          }
        }
      }

      setState(() {
        _completed
          ..clear()
          ..addAll(completed);
        _deferred
          ..clear()
          ..addAll(deferred);
        _isInitializing = false;
        _currentIndex = _nextIncompleteIndex();
      });
      if (seededInitialProgress) {
        await _persistProgress();
      }

      await _loadPermissionStatuses();
      _syncStepSideEffects();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
            'OnboardingFlowScreen._bootstrap failed: $error\n$stackTrace');
      }
      if (!mounted) return;
      final fallbackSteps = _buildSteps();
      setState(() {
        _steps = fallbackSteps.isEmpty
            ? const <_OnboardingStep>[_OnboardingStep.welcome]
            : fallbackSteps;
        _isInitializing = false;
        _currentIndex = _nextIncompleteIndex();
      });
      _syncStepSideEffects();
    }
  }

  void _setPendingEmailVerification(
    String email, {
    String signupMethod = _emailSignupMethod,
  }) {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) return;
    _pendingVerificationEmail = normalizedEmail;
    _pendingEmailVerification = true;
    _pendingVerificationSignupMethod = signupMethod;
    _emailVerifiedConfirmed = false;
    _finishSignInPromptShown = false;
    _verifiedSigningInMessageShown = false;
  }

  void _clearPendingEmailVerificationState() {
    _pendingVerificationEmail = null;
    _pendingEmailVerification = false;
    _pendingVerificationSignupMethod = _emailSignupMethod;
    _emailVerifiedConfirmed = false;
    _finishSignInPromptShown = false;
    _verifiedSigningInMessageShown = false;
  }

  void _hydrateLocalDrafts(SharedPreferences prefs) {
    final rawPersona = (prefs.getString(_personaDraftKey) ?? '').trim();
    _selectedPersona = UserPersonaX.tryParse(rawPersona);

    final rawProfile = (prefs.getString(_profileDraftKey) ?? '').trim();
    if (rawProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfile);
        if (decoded is Map<String, dynamic>) {
          _localProfileDraft = decoded.map(
            (key, value) => MapEntry(key, (value ?? '').toString()),
          );
        }
      } catch (_) {
        _localProfileDraft = <String, String>{};
      }
    } else {
      _localProfileDraft = <String, String>{};
    }

    final rawDao = (prefs.getString(_daoDraftKey) ?? '').trim();
    _daoDraft = null;
    if (rawDao.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDao);
        if (decoded is Map<String, dynamic>) {
          final parsed = _DaoApplicationDraftRecord.fromJson(decoded);
          if (parsed.isEligibleRole && parsed.hasContent) {
            _daoDraft = parsed;
          }
        }
      } catch (_) {
        _daoDraft = null;
      }
    } else {
      _daoDraft = null;
    }

    final pendingEmail =
        (prefs.getString(_verificationEmailDraftKey) ?? '').trim();
    final pendingFlag = prefs.getBool(_verificationPendingFlagKey) ?? false;
    final pendingMethod =
        (prefs.getString(_verificationSignupMethodKey) ?? _emailSignupMethod)
            .trim();
    _pendingVerificationSignupMethod =
        pendingMethod.isEmpty ? _emailSignupMethod : pendingMethod;

    if (pendingEmail.isNotEmpty) {
      // Legacy migration: old builds persisted only email; treat it as pending.
      _setPendingEmailVerification(
        pendingEmail,
        signupMethod: _pendingVerificationSignupMethod,
      );
    } else {
      _pendingEmailVerification = pendingFlag;
      if (!_pendingEmailVerification) {
        _pendingVerificationEmail = null;
      }
    }

    if ((_pendingVerificationEmail ?? '').trim().isEmpty) {
      _pendingEmailVerification = false;
    }

    _daoDraft = _normalizeDaoDraftForPersona(_selectedPersona);
  }

  _DaoApplicationDraftRecord? _normalizeDaoDraftForPersona(
      UserPersona? persona) {
    if (persona == null || persona == UserPersona.lover) {
      return null;
    }

    final existing = _daoDraft;
    final profileName = (_localProfileDraft['displayName'] ?? '').trim();
    final profileWebsite = (_localProfileDraft['website'] ?? '').trim();
    final isInstitution = persona == UserPersona.institution;

    return _DaoApplicationDraftRecord(
      isArtist: !isInstitution,
      isInstitution: isInstitution,
      title: isInstitution ? (existing?.title ?? profileName) : '',
      contact: isInstitution ? (existing?.contact ?? profileWebsite) : '',
      portfolioUrl:
          isInstitution ? '' : (existing?.portfolioUrl ?? profileWebsite),
      medium: existing?.medium ?? '',
      statement: existing?.statement ?? '',
    );
  }

  Future<void> _persistLocalDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final personaValue = _selectedPersona?.storageValue ?? '';
    if (personaValue.isEmpty) {
      await prefs.remove(_personaDraftKey);
    } else {
      await prefs.setString(_personaDraftKey, personaValue);
    }
    if (_localProfileDraft.isEmpty) {
      await prefs.remove(_profileDraftKey);
    } else {
      await prefs.setString(_profileDraftKey, jsonEncode(_localProfileDraft));
    }
    final daoDraft = _daoDraft;
    if (daoDraft == null || !daoDraft.isEligibleRole || !daoDraft.hasContent) {
      await prefs.remove(_daoDraftKey);
    } else {
      await prefs.setString(_daoDraftKey, jsonEncode(daoDraft.toJson()));
    }

    final pendingEmail = (_pendingVerificationEmail ?? '').trim();
    if (pendingEmail.isEmpty) {
      await prefs.remove(_verificationEmailDraftKey);
    } else {
      await prefs.setString(_verificationEmailDraftKey, pendingEmail);
    }
    await prefs.setBool(_verificationPendingFlagKey, _pendingEmailVerification);
    if (_pendingVerificationSignupMethod.trim().isEmpty) {
      await prefs.remove(_verificationSignupMethodKey);
    } else {
      await prefs.setString(
        _verificationSignupMethodKey,
        _pendingVerificationSignupMethod,
      );
    }
  }

  String _currentSessionEmailLower() {
    return (BackendApiService().getCurrentAuthEmail() ?? '')
        .trim()
        .toLowerCase();
  }

  String _currentSessionWalletAddress() {
    return (BackendApiService().getCurrentAuthWalletAddress() ?? '').trim();
  }

  Future<String?> _resolveWalletForBackupCheck({
    SharedPreferences? prefs,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final fromProfile =
        (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    final fromWallet = (walletProvider.currentWalletAddress ?? '').trim();
    if (fromWallet.isNotEmpty) return fromWallet;
    final fromSession = _currentSessionWalletAddress();
    if (fromSession.isNotEmpty) return fromSession;
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final fallback = (resolvedPrefs.getString(PreferenceKeys.walletAddress) ??
            resolvedPrefs.getString('wallet_address') ??
            resolvedPrefs.getString('walletAddress') ??
            resolvedPrefs.getString('wallet') ??
            '')
        .trim();
    return fallback.isEmpty ? null : fallback;
  }

  Future<String?> _resolveFlowScopeKey({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final walletAddress =
        await _resolveWalletForBackupCheck(prefs: resolvedPrefs);
    final userId = (resolvedPrefs.getString('user_id') ?? '').trim();
    return OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: walletAddress,
      userId: userId,
    );
  }

  Future<void> _syncWalletBackupRequirement() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = await _resolveWalletForBackupCheck(prefs: prefs);
    _flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: walletAddress,
      userId: (prefs.getString('user_id') ?? '').trim(),
    );
    if (!_walletBackupOnboardingEnabled) {
      _requiresWalletBackupStep = false;
      return;
    }
    _requiresWalletBackupStep = await walletProvider.isMnemonicBackupRequired(
      walletAddress: walletAddress,
    );
  }

  bool _sessionMatchesPendingVerificationEmail() {
    if (!_pendingEmailVerification) return true;
    final pending = (_pendingVerificationEmail ?? '').trim().toLowerCase();
    if (pending.isEmpty) return false;
    final sessionEmail = _currentSessionEmailLower();
    if (sessionEmail.isEmpty) return false;
    return sessionEmail == pending;
  }

  Future<void> _refreshProfileForCurrentSessionWallet() async {
    final wallet = _currentSessionWalletAddress();
    if (wallet.isEmpty) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.loadProfile(wallet);
    await _syncWalletBackupRequirement();
    _refreshAuthDerivedSteps();
  }

  Future<void> _syncWalletSessionIntoProviders({
    String? preferredWalletAddress,
    Object? userId,
  }) async {
    final sessionWallet = (preferredWalletAddress ?? '').trim().isNotEmpty
        ? (preferredWalletAddress ?? '').trim()
        : _currentSessionWalletAddress();
    if (sessionWallet.isEmpty) return;

    await const WalletSessionSyncService().bindAuthenticatedWallet(
      context: context,
      walletAddress: sessionWallet,
      userId: userId,
      warmUp: false,
      loadProfile: true,
    );
    await _syncWalletBackupRequirement();
  }

  void _showVerificationSnack(
    String message, {
    KubusSnackBarTone tone = KubusSnackBarTone.neutral,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showKubusSnackBar(
      SnackBar(content: Text(message)),
      tone: tone,
    );
  }

  List<_OnboardingStep> _buildSteps() {
    switch (_branch) {
      case _OnboardingBranch.none:
        return const <_OnboardingStep>[
          _OnboardingStep.welcome,
        ];
      case _OnboardingBranch.guest:
        return const <_OnboardingStep>[
          _OnboardingStep.guestPermissions,
          _OnboardingStep.done,
        ];
      case _OnboardingBranch.account:
        return <_OnboardingStep>[
          _OnboardingStep.account,
          if (_verificationRequired) _OnboardingStep.verifyEmail,
          _OnboardingStep.role,
          _OnboardingStep.profile,
          if (_walletBackupOnboardingEnabled && _requiresWalletBackupStep)
            _OnboardingStep.walletBackup,
          if (_requiresDaoReviewStep) _OnboardingStep.daoReview,
          _OnboardingStep.accountPermissions,
          _OnboardingStep.done,
        ];
    }
  }

  bool get _verificationRequired =>
      _pendingEmailVerification &&
      (_pendingVerificationEmail ?? '').trim().isNotEmpty;

  bool _isPermissionRelatedStep(_OnboardingStep step) {
    return step == _OnboardingStep.guestPermissions ||
        step == _OnboardingStep.accountPermissions;
  }

  bool _isStatusBlocked(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  Permission _locationPermissionForRequest() {
    return kIsWeb ? Permission.location : Permission.locationWhenInUse;
  }

  Future<PermissionStatus> _safePermissionStatus(Permission permission) async {
    try {
      return await permission.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Future<List<PermissionStatus>> _locationStatuses() async {
    if (kIsWeb) {
      return <PermissionStatus>[
        await _safePermissionStatus(Permission.location),
      ];
    }
    return <PermissionStatus>[
      await _safePermissionStatus(Permission.locationWhenInUse),
      await _safePermissionStatus(Permission.location),
    ];
  }

  Future<bool> _isLocationPermissionGranted() async {
    if (kIsWeb) {
      if (_webLocationGrantedOverride) return true;
      try {
        final permission = await Geolocator.checkPermission();
        final granted = permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
        if (granted) _webLocationGrantedOverride = true;
        if (granted) return true;
      } catch (_) {}

      // Fallback: keep UI accurate if Geolocator.checkPermission() is stale on
      // some browsers by consulting permission_handler as a secondary signal.
      final status = await _safePermissionStatus(Permission.location);
      if (status.isGranted) {
        _webLocationGrantedOverride = true;
        return true;
      }
      return false;
    }
    final statuses = await _locationStatuses();
    return statuses.any((status) => status.isGranted);
  }

  Future<bool> _isLocationPermissionBlocked() async {
    if (kIsWeb) {
      try {
        final permission = await Geolocator.checkPermission();
        // On web, a user "deny" is effectively sticky until changed in browser
        // site settings; treat both denied and deniedForever as blocked.
        return permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever;
      } catch (_) {
        final status = await _safePermissionStatus(Permission.location);
        return _isStatusBlocked(status);
      }
    }
    final statuses = await _locationStatuses();
    if (statuses.any((status) => status.isGranted)) return false;
    return statuses.any(_isStatusBlocked);
  }

  Future<bool> _isNotificationPermissionGranted() async {
    if (kIsWeb) {
      try {
        return await isWebNotificationPermissionGranted();
      } catch (_) {
        return false;
      }
    }

    final handlerGranted =
        (await _safePermissionStatus(Permission.notification)).isGranted;
    if (handlerGranted) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_permission_granted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isPermissionBlocked(Permission permission) async {
    if (permission == Permission.location) {
      return _isLocationPermissionBlocked();
    }
    if (permission == Permission.notification) {
      if (await _isNotificationPermissionGranted()) return false;
      if (kIsWeb) {
        // On web, browser won't re-prompt after a deny; treat that as blocked
        // and guide the user to site settings.
        return webNotificationPermissionStateNow() == 'denied';
      }
      return _isStatusBlocked(
        await _safePermissionStatus(Permission.notification),
      );
    }
    if (permission == Permission.camera) {
      if (kIsWeb) return false;
      return _isStatusBlocked(await _safePermissionStatus(Permission.camera));
    }
    return false;
  }

  bool _isPermissionGrantedFor(Permission permission) {
    if (permission == Permission.location) {
      return _locationEnabled;
    }
    if (permission == Permission.notification) {
      return _notificationEnabled;
    }
    if (permission == Permission.camera) {
      return _cameraEnabled;
    }
    return false;
  }

  Future<void> _loadPermissionStatuses() async {
    final requestEpoch = ++_permissionStatusEpoch;
    var locationEnabled = false;
    var notificationEnabled = false;
    var cameraEnabled = false;
    try {
      locationEnabled = await _isLocationPermissionGranted();
    } catch (_) {}

    if (kIsWeb) {
      notificationEnabled = await _isNotificationPermissionGranted();
      cameraEnabled = true;
    } else {
      try {
        notificationEnabled = await _isNotificationPermissionGranted();
      } catch (_) {
        notificationEnabled = false;
      }
      try {
        final camera = await Permission.camera.status;
        cameraEnabled = camera.isGranted;
      } catch (_) {
        cameraEnabled = false;
      }
    }

    if (!mounted || requestEpoch != _permissionStatusEpoch) return;
    setState(() {
      _locationEnabled = locationEnabled;
      _notificationEnabled = notificationEnabled;
      _cameraEnabled = cameraEnabled;
    });
  }

  _OnboardingStep? _stepFromId(String raw) {
    for (final step in _steps) {
      if (_stepId(step) == raw) {
        return step;
      }
    }
    return null;
  }

  String _stepId(_OnboardingStep step) => step.name;

  Future<void> _persistProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final flowScopeKey =
        _flowScopeKey ?? await _resolveFlowScopeKey(prefs: prefs);
    _flowScopeKey = flowScopeKey;
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: _flowVersion,
      completedSteps: _completed.map(_stepId).toSet(),
      deferredSteps: _deferred.map(_stepId).toSet(),
      flowScopeKey: flowScopeKey,
    );
  }

  int _nextIncompleteIndex() {
    final index = _steps.indexWhere((step) => !_completed.contains(step));
    return index == -1 ? _steps.length - 1 : index;
  }

  Future<void> _goBackStep() async {
    if (!mounted || _currentIndex <= 0) return;
    setState(() {
      _currentIndex = (_currentIndex - 1).clamp(0, _steps.length - 1);
    });
    _syncStepSideEffects();
  }

  void _startVerificationPollingIfNeeded({bool restartWindow = false}) {
    if (_steps.isEmpty) return;
    final pendingEmail = (_pendingVerificationEmail ?? '').trim();
    final shouldPoll =
        _currentStep == _OnboardingStep.verifyEmail && pendingEmail.isNotEmpty;
    if (!shouldPoll) {
      _verificationPollTimer?.cancel();
      _verificationPollTimer = null;
      _verificationPollStartedAt = null;
      return;
    }
    if (restartWindow || _verificationPollStartedAt == null) {
      _verificationPollStartedAt = DateTime.now();
    }
    if (_verificationPollTimer != null) return;

    _verificationPollTimer = Timer.periodic(
      _verificationPollInterval,
      (_) {
        final startedAt = _verificationPollStartedAt;
        if (startedAt != null &&
            DateTime.now().difference(startedAt) >
                _verificationPollMaxDuration) {
          _logVerificationRefresh('poll timeout reached; stopping timer');
          _verificationPollTimer?.cancel();
          _verificationPollTimer = null;
          return;
        }
        unawaited(_pollVerificationStatus(trigger: 'poll'));
      },
    );
    unawaited(_pollVerificationStatus(trigger: 'step_enter'));
  }

  Future<void> _pollVerificationStatus({required String trigger}) async {
    if (_verificationPollInFlight || !mounted) return;
    final email = (_pendingVerificationEmail ?? '').trim();
    if (email.isEmpty) return;

    _logVerificationRefresh('refresh start trigger=$trigger');
    setState(() {
      _verificationPollInFlight = true;
    });
    try {
      final status =
          await BackendApiService().getEmailVerificationStatus(email: email);
      final verified = status['verified'] == true;
      _logVerificationRefresh(
        'refresh result trigger=$trigger verified=$verified',
      );

      if (!mounted) return;
      if (_emailVerifiedConfirmed != verified) {
        setState(() {
          _emailVerifiedConfirmed = verified;
        });
      }

      if (!verified) {
        _finishSignInPromptShown = false;
        _verifiedSigningInMessageShown = false;
        return;
      }

      if (_autoAdvancingVerification) return;

      if (!_sessionMatchesPendingVerificationEmail()) {
        _verificationPollTimer?.cancel();
        _verificationPollTimer = null;
        _verificationPollStartedAt = null;
        if (!_finishSignInPromptShown) {
          _finishSignInPromptShown = true;
          _showVerificationSnack(
            'Verified - please enter password to finish signing in',
            tone: KubusSnackBarTone.warning,
          );
        }
        return;
      }

      if (!_verifiedSigningInMessageShown) {
        _verifiedSigningInMessageShown = true;
        _showVerificationSnack(
          'Verified - signing you in...',
          tone: KubusSnackBarTone.neutral,
        );
      }

      if (!mounted) return;
      setState(() {
        _autoAdvancingVerification = true;
      });
      try {
        await _confirmVerificationAndContinue();
      } finally {
        if (mounted) {
          setState(() {
            _autoAdvancingVerification = false;
          });
        } else {
          _autoAdvancingVerification = false;
        }
      }
    } catch (e) {
      _logVerificationRefresh('refresh failed trigger=$trigger error=$e');
      // Quietly retry on next tick/resume/manual action.
    } finally {
      if (mounted) {
        setState(() {
          _verificationPollInFlight = false;
        });
      } else {
        _verificationPollInFlight = false;
      }
    }
  }

  Future<void> _syncLocalProfileDraftToBackendIfPossible() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;

    final displayName = (_localProfileDraft['displayName'] ?? '').trim();
    final username = (_localProfileDraft['username'] ?? '').trim();
    final bio = (_localProfileDraft['bio'] ?? '').trim();
    final avatar = (_localProfileDraft['avatar'] ?? '').trim();

    final twitter = (_localProfileDraft['twitter'] ?? '').trim();
    final instagram = (_localProfileDraft['instagram'] ?? '').trim();
    final website = (_localProfileDraft['website'] ?? '').trim();
    final social = <String, String>{
      if (twitter.isNotEmpty) 'twitter': twitter,
      if (instagram.isNotEmpty) 'instagram': instagram,
      if (website.isNotEmpty) 'website': website,
    };

    final fieldOfWorkRaw = (_localProfileDraft['fieldOfWork'] ?? '').trim();
    final fieldOfWork = fieldOfWorkRaw
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
    final yearsActive =
        int.tryParse((_localProfileDraft['yearsActive'] ?? '').trim());
    final persona = _selectedPersona;

    await profileProvider.saveProfile(
      walletAddress: wallet,
      displayName: displayName.isEmpty ? null : displayName,
      username: username.isEmpty ? null : username,
      bio: bio.isEmpty ? null : bio,
      avatar: avatar.isEmpty ? null : avatar,
      social: social.isEmpty ? null : social,
      fieldOfWork: fieldOfWork.isEmpty ? null : fieldOfWork,
      yearsActive: yearsActive,
    );

    if (persona != null) {
      await profileProvider.setUserPersona(persona);
    }

    await _flushPendingAvatarUploadIfPossible();
  }

  Future<void> _syncDaoReviewStateIfNeeded({bool forceRefresh = false}) async {
    if (!_requiresDaoReviewStep || _currentStep != _OnboardingStep.daoReview) {
      return;
    }
    if (_daoReviewLoading) return;

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;

    final daoProvider = Provider.of<DAOProvider>(context, listen: false);
    setState(() {
      _daoReviewLoading = true;
    });
    try {
      final review = await daoProvider.loadReviewForWallet(
        wallet,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _daoReview = review;
      });
    } finally {
      if (mounted) {
        setState(() {
          _daoReviewLoading = false;
        });
      } else {
        _daoReviewLoading = false;
      }
    }
  }

  Future<void> _submitDaoReview() async {
    final persona = _effectivePersona;
    final draft = _daoDraft;
    if (persona == null || draft == null || !draft.isSubmittable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          const SnackBar(
            content: Text('Complete the review form before continuing.'),
          ),
          tone: KubusSnackBarTone.warning,
        );
      }
      return;
    }

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;

    final verification = DaoRoleVerification(
      walletAddress: wallet,
      review: _daoReview,
    );
    final requiredRole = _requiredDaoRoleType;
    if (requiredRole != null &&
        (verification.isApprovedFor(requiredRole) ||
            verification.isPendingFor(requiredRole))) {
      await _markCompleted(_OnboardingStep.daoReview);
      return;
    }

    final daoProvider = Provider.of<DAOProvider>(context, listen: false);
    DAOReview? submittedReview;
    if (persona == UserPersona.institution) {
      submittedReview = await daoProvider.submitInstitutionReview(
        walletAddress: wallet,
        organization: draft.title,
        contact: draft.contact,
        focus: draft.medium,
        mission: draft.statement,
        metadata: <String, dynamic>{'source': 'onboarding'},
      );
    } else if (persona == UserPersona.creator) {
      submittedReview = await daoProvider.submitReview(
        walletAddress: wallet,
        portfolioUrl: draft.portfolioUrl,
        medium: draft.medium,
        statement: draft.statement,
        title: (_localProfileDraft['displayName'] ?? '').trim(),
        metadata: <String, dynamic>{'source': 'onboarding'},
        role: 'artist',
      );
    }

    if (submittedReview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          const SnackBar(
            content: Text('Unable to submit the DAO review right now.'),
          ),
          tone: KubusSnackBarTone.error,
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _daoReview = submittedReview;
    });
    await _persistLocalDrafts();
    await _markCompleted(_OnboardingStep.daoReview);
  }

  void _refreshAuthDerivedSteps() {
    final signedInNow =
        Provider.of<ProfileProvider>(context, listen: false).isSignedIn;

    _isSignedIn = signedInNow;
    _steps = _buildSteps();
    if (!_requiresDaoReviewStep) {
      _daoReview = null;
      _daoDraft = null;
    }
    _completed.removeWhere((step) => !_steps.contains(step));
    _deferred.removeWhere((step) => !_steps.contains(step));
    if (_currentIndex >= _steps.length) {
      _currentIndex = _steps.isEmpty ? 0 : (_steps.length - 1);
    }
  }

  Future<void> _markCompleted(_OnboardingStep step) async {
    _completed.add(step);
    _deferred.remove(step);
    await _persistProgress();
    if (mounted) {
      setState(() {
        _refreshAuthDerivedSteps();
        _currentIndex = _nextIncompleteIndex();
      });
      _syncStepSideEffects();
    }
  }

  Future<void> _deferCurrentStep() async {
    final step = _currentStep;
    if (step == _OnboardingStep.guestPermissions ||
        step == _OnboardingStep.accountPermissions) {
      await _markCompleted(step);
      return;
    }
    if (step == _OnboardingStep.verifyEmail) {
      await _markCompleted(_OnboardingStep.verifyEmail);
      return;
    }

    _deferred.add(step);
    await _persistProgress();

    final next = _steps.indexWhere(
      (s) => !_completed.contains(s) && !_deferred.contains(s) && s != step,
    );
    if (!mounted) return;
    setState(() {
      _refreshAuthDerivedSteps();
      _currentIndex = next == -1 ? _steps.length - 1 : next;
    });
    _syncStepSideEffects();
  }

  void _syncStepSideEffects() {
    _startVerificationPollingIfNeeded();
    if (_currentStep == _OnboardingStep.daoReview) {
      unawaited(_syncDaoReviewStateIfNeeded());
    }
  }

  Future<void> _selectGuestBranch() async {
    setState(() {
      _branch = _OnboardingBranch.guest;
      _steps = _buildSteps();
      _currentIndex = 0;
    });
    await _persistProgress();
  }

  Future<void> _selectAccountBranch() async {
    await _syncWalletBackupRequirement();
    setState(() {
      _branch = _OnboardingBranch.account;
      _steps = _buildSteps();
      _currentIndex = 0;
    });
    await _persistProgress();
  }

  Future<void> _requestPermission(Permission permission) async {
    if (_isRequestingPermission) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      if (permission == Permission.notification) {
        if (kIsWeb) {
          // Must be requested directly from a user gesture on web.
          try {
            if (webNotificationPermissionStateNow() == 'denied') {
              _showPermissionSettingsDialog(permission);
            } else {
              await requestWebNotificationPermission();
            }
          } catch (_) {}
        } else {
          try {
            await Permission.notification.request();
          } catch (_) {}
          try {
            await PushNotificationService().requestPermission();
          } catch (_) {}
        }
      } else if (kIsWeb && permission == Permission.camera) {
        // Camera permission is not requested from the web onboarding flow.
      } else if (kIsWeb && permission == Permission.location) {
        try {
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          );
          _webLocationGrantedOverride = true;
        } catch (_) {}
      } else {
        final requestedPermission = permission == Permission.location
            ? _locationPermissionForRequest()
            : permission;
        try {
          await requestedPermission.request();
        } catch (_) {}
      }

      await _loadPermissionStatuses();
      if (!mounted) return;

      final granted = _isPermissionGrantedFor(permission);
      if (granted) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(
              l10n.permissionsPermissionGrantedToast(
                _permissionLabel(l10n, permission),
              ),
            ),
          ),
          tone: KubusSnackBarTone.success,
        );
      }

      final blocked = granted ? false : await _isPermissionBlocked(permission);
      if (!mounted) return;

      setState(() {
        _permissionHint = blocked
            ? l10n.permissionsOpenSettingsDialogContent(
                _permissionLabel(l10n, permission),
              )
            : null;
      });

      if (blocked) {
        _showPermissionSettingsDialog(permission);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      } else {
        _isRequestingPermission = false;
      }
    }
  }

  String _permissionLabel(AppLocalizations l10n, Permission permission) {
    if (permission == Permission.location) {
      return l10n.onboardingFlowPermissionLocation;
    }
    if (permission == Permission.notification) {
      return l10n.onboardingFlowPermissionNotifications;
    }
    if (permission == Permission.camera) {
      return l10n.onboardingFlowPermissionCamera;
    }
    return 'permission';
  }

  void _showPermissionSettingsDialog(Permission permission) {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.permissionsPermissionRequiredTitle,
          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        content: Text(
          l10n.permissionsOpenSettingsDialogContent(
            _permissionLabel(l10n, permission),
          ),
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          if (!kIsWeb)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(openAppSettings());
              },
              child: Text(l10n.permissionsOpenSettings),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.commonOk),
            ),
        ],
      ),
    );
  }

  Future<void> _saveInlineProfile({
    required String displayName,
    required String username,
    required String bio,
    required String? avatar,
    required String website,
    required String fieldOfWork,
    required String yearsActive,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress;
    _localProfileDraft = <String, String>{
      'displayName': displayName.trim(),
      'username': username.trim(),
      'bio': bio.trim(),
      'avatar': (avatar ?? '').trim(),
      'website': website.trim(),
      'fieldOfWork': fieldOfWork.trim(),
      'yearsActive': yearsActive.trim(),
    };
    _daoDraft = _normalizeDaoDraftForPersona(_effectivePersona);
    await _persistLocalDrafts();

    if (wallet != null && wallet.trim().isNotEmpty) {
      final specialties = fieldOfWork
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      await profileProvider.saveProfile(
        walletAddress: wallet,
        displayName: displayName.trim().isEmpty ? null : displayName.trim(),
        username: username.trim().isEmpty ? null : username.trim(),
        bio: bio.trim().isEmpty ? null : bio.trim(),
        avatar: (avatar ?? '').trim().isEmpty ? null : avatar?.trim(),
        social: website.trim().isEmpty
            ? null
            : <String, String>{'website': website.trim()},
        fieldOfWork: specialties.isEmpty ? null : specialties,
        yearsActive: int.tryParse(yearsActive.trim()),
      );
      await _flushPendingAvatarUploadIfPossible();
    }

    if (!mounted) return;
    await _markCompleted(_OnboardingStep.profile);
  }

  Future<void> _handleEmbeddedRegistrationSuccess() async {
    await _syncWalletBackupRequirement();
    _refreshAuthDerivedSteps();
    await _syncLocalProfileDraftToBackendIfPossible();
    await _flushPendingAvatarUploadIfPossible();
    if (!mounted) return;
    if (_steps.contains(_OnboardingStep.account)) {
      await _markCompleted(_OnboardingStep.account);
    } else {
      setState(() {});
    }
  }

  Future<void> _handleEmbeddedVerificationRequired(String email) async {
    _setPendingEmailVerification(email);
    await _persistLocalDrafts();
    _refreshAuthDerivedSteps();
    if (!mounted) return;
    if (_steps.contains(_OnboardingStep.account)) {
      await _markCompleted(_OnboardingStep.account);
      await _jumpToVerifyStep();
    } else {
      setState(() {});
    }
  }

  Future<void> _handleEmbeddedEmailRegistrationAttempted(String email) async {
    if (!mounted) return;
    setState(() {
      _setPendingEmailVerification(email);
    });
    await _persistLocalDrafts();
    _syncStepSideEffects();
  }

  Future<void> _handleEmbeddedSignInNeedsVerification(String email) async {
    await _setPendingVerificationAndRoute(
      email,
      completeAccountStep: false,
    );
  }

  Future<void> _setPendingVerificationAndRoute(
    String email, {
    required bool completeAccountStep,
  }) async {
    _setPendingEmailVerification(email);
    await _persistLocalDrafts();
    _refreshAuthDerivedSteps();
    await _jumpToVerifyStep();
    if (completeAccountStep && _steps.contains(_OnboardingStep.account)) {
      await _markCompleted(_OnboardingStep.account);
    }
  }

  Future<void> _handleEmbeddedSignInSuccess(
      Map<String, dynamic> payload) async {
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    final signedInEmail = (user['email'] ?? '').toString().trim().toLowerCase();
    final signedInWallet =
        (user['walletAddress'] ?? user['wallet_address'] ?? '')
            .toString()
            .trim();
    final pendingEmail = (_pendingVerificationEmail ?? '').trim().toLowerCase();
    var shouldPersistDrafts = false;
    if (pendingEmail.isNotEmpty && signedInEmail == pendingEmail) {
      _clearPendingEmailVerificationState();
      shouldPersistDrafts = true;
    } else if (pendingEmail.isNotEmpty) {
      _finishSignInPromptShown = false;
      _showVerificationSnack(
        'Sign-in used a different account. Use $pendingEmail to finish verification.',
        tone: KubusSnackBarTone.warning,
      );
      _refreshAuthDerivedSteps();
      await _persistLocalDrafts();
      if (mounted) {
        await _jumpToVerifyStep();
      }
      return;
    }

    await _syncWalletSessionIntoProviders(
      preferredWalletAddress: signedInWallet.isEmpty ? null : signedInWallet,
      userId: user['id'],
    );
    await _syncWalletBackupRequirement();
    _refreshAuthDerivedSteps();
    try {
      await _refreshProfileForCurrentSessionWallet();
    } catch (_) {
      // Keep onboarding resilient; verification flow will retry profile sync.
    }
    if (shouldPersistDrafts) {
      await _persistLocalDrafts();
    }
    await _syncLocalProfileDraftToBackendIfPossible();
    await _flushPendingAvatarUploadIfPossible();
    if (!mounted) return;
    await _markCompleted(_OnboardingStep.account);
  }

  Future<void> _stageAvatarForLaterUpload({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _pendingAvatarBytes = bytes;
    _pendingAvatarFileName = fileName;
    _pendingAvatarMimeType = mimeType;
  }

  Future<void> _flushPendingAvatarUploadIfPossible() async {
    final bytes = _pendingAvatarBytes;
    final fileName = (_pendingAvatarFileName ?? '').trim();
    if (bytes == null || fileName.isEmpty) return;

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;

    try {
      final uploadedUrl = await profileProvider.uploadAvatarBytes(
        fileBytes: bytes,
        fileName: fileName,
        walletAddress: wallet,
        mimeType: _pendingAvatarMimeType,
      );
      if (uploadedUrl.trim().isEmpty) return;

      await profileProvider.saveProfile(
        walletAddress: wallet,
        avatar: uploadedUrl.trim(),
      );

      _localProfileDraft = <String, String>{
        ..._localProfileDraft,
        'avatar': uploadedUrl.trim(),
      };
      await _persistLocalDrafts();

      _pendingAvatarBytes = null;
      _pendingAvatarFileName = null;
      _pendingAvatarMimeType = null;
    } catch (_) {
      // Keep staged avatar for retry after auth/session settles.
    }
  }

  Future<void> _confirmVerificationAndContinue() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    _refreshAuthDerivedSteps();

    if (_verificationRequired) {
      var verified = _emailVerifiedConfirmed;
      final emailToCheck = (_pendingVerificationEmail ?? '').trim();
      if (emailToCheck.isNotEmpty) {
        try {
          final status = await BackendApiService()
              .getEmailVerificationStatus(email: emailToCheck);
          verified = status['verified'] == true;
          if (mounted && _emailVerifiedConfirmed != verified) {
            setState(() {
              _emailVerifiedConfirmed = verified;
            });
          } else {
            _emailVerifiedConfirmed = verified;
          }
        } catch (_) {
          // Keep local confirmation state when backend is temporarily unavailable.
        }
      }

      if (!verified) {
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authVerifyEmailSignInHint)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }

      if (!_sessionMatchesPendingVerificationEmail()) {
        _finishSignInPromptShown = true;
        messenger.showKubusSnackBar(
          const SnackBar(
            content:
                Text('Verified - please enter password to finish signing in'),
          ),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }

      if (!_verifiedSigningInMessageShown) {
        _verifiedSigningInMessageShown = true;
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('Verified - signing you in...')),
          tone: KubusSnackBarTone.neutral,
        );
      }

      await BackendApiService().refreshAuthTokenFromStorage();
      await _syncWalletSessionIntoProviders();
      await _syncWalletBackupRequirement();
      try {
        await _refreshProfileForCurrentSessionWallet();
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
              'OnboardingFlowScreen._confirmVerificationAndContinue profile refresh failed: $error');
        }
        messenger.showKubusSnackBar(
          const SnackBar(
            content: Text(
              'Signed in, but profile refresh is still syncing. Please continue.',
            ),
          ),
          tone: KubusSnackBarTone.warning,
        );
      }

      if (!_sessionMatchesPendingVerificationEmail()) {
        messenger.showKubusSnackBar(
          const SnackBar(
            content: Text(
              'Sign-in session mismatch. Please sign in with your verified email.',
            ),
          ),
          tone: KubusSnackBarTone.error,
        );
        return;
      }

      _clearPendingEmailVerificationState();
      await _persistLocalDrafts();
      messenger.showKubusSnackBar(
        const SnackBar(
            content: Text('Verified account signed in successfully.')),
        tone: KubusSnackBarTone.success,
      );
    }

    if (!mounted) return;

    if (_steps.contains(_OnboardingStep.verifyEmail)) {
      await _markCompleted(_OnboardingStep.verifyEmail);
    }

    await _syncLocalProfileDraftToBackendIfPossible();

    if (mounted) {
      setState(() {
        _currentIndex = _nextIncompleteIndex();
      });
    }
  }

  Future<void> _jumpToVerifyStep() async {
    await _jumpToStepIfPresent(_OnboardingStep.verifyEmail);
  }

  Future<void> _handleManualVerificationRefresh() async {
    _startVerificationPollingIfNeeded(restartWindow: true);
    await _pollVerificationStatus(trigger: 'manual');
  }

  Future<void> _jumpToStepIfPresent(_OnboardingStep step) async {
    final target = _steps.indexOf(step);
    if (target < 0 || !mounted) return;
    setState(() {
      _currentIndex = target;
    });
    _syncStepSideEffects();
  }

  Future<void> _applyPersonaSelection(UserPersona persona) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    _selectedPersona = persona;
    _daoDraft = _normalizeDaoDraftForPersona(persona);
    _daoReview = null;
    await _persistLocalDrafts();
    if ((profileProvider.currentUser?.walletAddress ?? '').trim().isNotEmpty) {
      await profileProvider.setUserPersona(persona, persistToBackend: true);
    }
    if (!mounted) return;
    await _markCompleted(_OnboardingStep.role);
  }

  Future<void> _handleWalletBackupStep() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_walletBackupOnboardingEnabled || !_requiresWalletBackupStep) {
      await _markCompleted(_OnboardingStep.walletBackup);
      return;
    }
    final walletAddress = await _resolveWalletForBackupCheck();
    if (!mounted) return;

    if ((walletAddress ?? '').isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.onboardingFlowWalletBackupNoWallet)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    final completed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => const MnemonicRevealScreen(),
      ),
    );
    if (!mounted) return;
    await _syncWalletBackupRequirement();
    if (!_requiresWalletBackupStep || completed == true) {
      await _markCompleted(_OnboardingStep.walletBackup);
      return;
    }
    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.onboardingFlowWalletBackupContinueHint)),
      tone: KubusSnackBarTone.neutral,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishingOnboarding) return;
    setState(() => _isFinishingOnboarding = true);

    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final api = BackendApiService();
      _clearPendingEmailVerificationState();
      await _persistLocalDrafts();
      await api.refreshAuthTokenFromStorage();
      await _syncWalletSessionIntoProviders();
      _refreshAuthDerivedSteps();

      if (!_isSignedIn) {
        final authToken = (api.getAuthToken() ?? '').trim();
        if (authToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final storedWallet = (_currentSessionWalletAddress().isNotEmpty
                  ? _currentSessionWalletAddress()
                  : (prefs.getString('wallet_address') ??
                      prefs.getString('walletAddress') ??
                      ''))
              .trim();
          if (storedWallet.isNotEmpty) {
            try {
              await profileProvider
                  .loadProfile(storedWallet)
                  .timeout(const Duration(seconds: 6));
            } catch (_) {
              // Keep onboarding completion resilient even when profile hydration
              // is temporarily unavailable.
            }
            _refreshAuthDerivedSteps();
          }
        }
      }

      if (_isSignedIn) {
        await _syncLocalProfileDraftToBackendIfPossible();
        await _flushPendingAvatarUploadIfPossible();
      }

      await _persistLocalDrafts();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_permissions', true);
      await OnboardingStateService.markCompleted(
        prefs: prefs,
        authOnboardingScopeKey: _flowScopeKey,
      );
      await _persistProgress();
      unawaited(TelemetryService()
          .trackOnboardingComplete(reason: 'step_flow_complete'));

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main');
    } finally {
      if (mounted) {
        setState(() => _isFinishingOnboarding = false);
      }
    }
  }

  Future<void> _skipForNow() async {
    if (_isSkippingFlow) return;
    _refreshAuthDerivedSteps();
    setState(() => _isSkippingFlow = true);

    try {
      _clearPendingEmailVerificationState();
      await _persistLocalDrafts();
      final prefs = await SharedPreferences.getInstance();
      await OnboardingStateService.markCompleted(
        prefs: prefs,
        authOnboardingScopeKey: _flowScopeKey,
      );
      await _persistProgress();
      unawaited(
        TelemetryService().trackOnboardingComplete(reason: 'skip_for_now'),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main');
    } finally {
      if (mounted) {
        setState(() => _isSkippingFlow = false);
      }
    }
  }

  Future<void> _onPrimaryAction() async {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
        return;
      case _OnboardingStep.guestPermissions:
        await _markCompleted(_OnboardingStep.guestPermissions);
        return;
      case _OnboardingStep.account:
        if (_isSignedIn) {
          await _markCompleted(_OnboardingStep.account);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.verifyEmail:
        await _confirmVerificationAndContinue();
        return;
      case _OnboardingStep.role:
        if (_completed.contains(_OnboardingStep.role)) {
          await _markCompleted(_OnboardingStep.role);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.profile:
        if (_completed.contains(_OnboardingStep.profile)) {
          await _markCompleted(_OnboardingStep.profile);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.walletBackup:
        await _handleWalletBackupStep();
        return;
      case _OnboardingStep.daoReview:
        if (_completed.contains(_OnboardingStep.daoReview)) {
          await _markCompleted(_OnboardingStep.daoReview);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.accountPermissions:
        await _markCompleted(_OnboardingStep.accountPermissions);
        return;
      case _OnboardingStep.done:
        await _finishOnboarding();
        return;
    }
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    ColorScheme scheme, {
    bool compact = false,
  }) {
    final stepNumber = _currentIndex + 1;
    final viewportSize = MediaQuery.sizeOf(context);
    final headerCompact = compact && viewportSize.height < 680;
    final skipLabel = l10n.commonSkip;
    final iconBoxSize = headerCompact ? 42.0 : 48.0;
    final iconGlyphSize = headerCompact ? 20.0 : 24.0;
    return Padding(
      padding: EdgeInsets.only(
        top: headerCompact ? KubusSpacing.xs : KubusSpacing.sm,
        bottom: headerCompact ? KubusSpacing.xs : KubusSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _paletteForStep(_currentStep).start,
                  _paletteForStep(_currentStep).end,
                ],
              ),
            ),
            child: Icon(
              _stepIcon(_currentStep),
              color: Colors.white,
              size: iconGlyphSize,
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.onboardingFlowTitle,
                      maxLines: 1,
                      softWrap: false,
                      style: (headerCompact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    l10n.commonStepOfTotal(stepNumber, _steps.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const AuthEntryControls(compact: true),
                    TextButton(
                      onPressed: _isSkippingFlow ? null : _skipForNow,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        backgroundColor: scheme.surface.withValues(alpha: 0.72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.sm,
                          vertical: 6,
                        ),
                        minimumSize: const Size(50, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        skipLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final step = _steps[index];
          final stepPalette = _paletteForStep(step);
          final active = index == _currentIndex;
          final done = _completed.contains(step);
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                  right: index == _steps.length - 1 ? 0 : KubusSpacing.xs),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: done
                    ? stepPalette.accent
                    : active
                        ? stepPalette.accent
                        : scheme.outline.withValues(alpha: 0.14),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCard(AppLocalizations l10n, ColorScheme scheme) {
    final step = _currentStep;
    final palette = _paletteForStep(step);

    Widget content;
    switch (step) {
      case _OnboardingStep.welcome:
        content = const SizedBox.shrink();
        break;
      case _OnboardingStep.guestPermissions:
        content = _PermissionsStep(
          title: l10n.onboardingFlowPermissionsTitle,
          body: l10n.onboardingFlowPermissionsBody,
          hint: _permissionHint,
          locationEnabled: _locationEnabled,
          cameraEnabled: _cameraEnabled,
          notificationEnabled: _notificationEnabled,
          onRequestLocation: () => _requestPermission(Permission.location),
          onRequestCamera: () => _requestPermission(Permission.camera),
          onRequestNotification: () =>
              _requestPermission(Permission.notification),
        );
        break;
      case _OnboardingStep.account:
        final currentProfile =
            Provider.of<ProfileProvider>(context, listen: false).currentUser;
        content = _AccountStep(
          title: l10n.onboardingFlowAccountTitle,
          body: l10n.onboardingFlowAccountBody,
          verifyHint: l10n.onboardingFlowAccountVerifyHint,
          profileDisplayName: (_localProfileDraft['displayName'] ??
                  currentProfile?.displayName ??
                  '')
              .trim(),
          onAuthCompleted: _handleEmbeddedRegistrationSuccess,
          onEmailRegistrationAttempted:
              _handleEmbeddedEmailRegistrationAttempted,
          onVerificationRequired: _handleEmbeddedVerificationRequired,
          onSignInSuccess: _handleEmbeddedSignInSuccess,
          onSignInNeedsVerification: _handleEmbeddedSignInNeedsVerification,
        );
        break;
      case _OnboardingStep.verifyEmail:
        content = _VerifyEmailStep(
          title: l10n.onboardingFlowVerifyLastTitle,
          body: l10n.onboardingFlowVerifyLastBody,
          email: _pendingVerificationEmail,
          isVerified: _emailVerifiedConfirmed,
          isSignedIn: _isSignedIn,
          requiresFinishSignIn: _verificationRequired &&
              _emailVerifiedConfirmed &&
              !_sessionMatchesPendingVerificationEmail(),
          isRefreshingVerification:
              _verificationPollInFlight || _autoAdvancingVerification,
          onRefreshVerification: _handleManualVerificationRefresh,
          onAuthSuccess: _handleEmbeddedSignInSuccess,
          onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
        );
        break;
      case _OnboardingStep.role:
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        final personaSelection =
            _selectedPersona ?? profileProvider.userPersona;
        content = _RoleStep(
          title: l10n.onboardingFlowRoleTitle,
          body: l10n.onboardingFlowRoleBody,
          selectedPersona: personaSelection,
          onSelectPersona: _applyPersonaSelection,
        );
        break;
      case _OnboardingStep.profile:
        final user =
            Provider.of<ProfileProvider>(context, listen: false).currentUser;
        content = _InlineProfileStep(
          title: l10n.onboardingFlowProfileTitle,
          body: l10n.onboardingFlowProfileBody,
          persona: _effectivePersona,
          initialDisplayName:
              (user?.displayName ?? _localProfileDraft['displayName'] ?? ''),
          initialUsername:
              (user?.username ?? _localProfileDraft['username'] ?? ''),
          initialBio: (user?.bio ?? _localProfileDraft['bio'] ?? ''),
          initialAvatarUrl:
              (user?.avatar ?? _localProfileDraft['avatar'] ?? ''),
          initialWebsite: _localProfileDraft['website'] ?? '',
          initialFieldOfWork: _localProfileDraft['fieldOfWork'] ?? '',
          initialYearsActive: _localProfileDraft['yearsActive'] ?? '',
          onSave: _saveInlineProfile,
          onAvatarStaged: _stageAvatarForLaterUpload,
        );
        break;
      case _OnboardingStep.walletBackup:
        content = _WalletBackupStep(
          title: l10n.onboardingFlowWalletBackupTitle,
          body: l10n.onboardingFlowWalletBackupBody,
          privacyWarning: l10n.onboardingFlowWalletBackupPrivacyWarning,
          lossWarning: l10n.onboardingFlowWalletBackupLossWarning,
          actionLabel: l10n.onboardingFlowWalletBackupAction,
          completed: _completed.contains(_OnboardingStep.walletBackup) ||
              !_requiresWalletBackupStep,
          onRevealMnemonic: _handleWalletBackupStep,
        );
        break;
      case _OnboardingStep.daoReview:
        content = _DaoReviewStep(
          title: 'DAO review',
          body: _effectivePersona == UserPersona.institution
              ? 'Submit your institution details for DAO review before the account setup is completed.'
              : 'Submit your practice for DAO review before the account setup is completed.',
          persona: _effectivePersona,
          draft: _daoDraft,
          review: _daoReview,
          isLoadingReview: _daoReviewLoading,
          onSaveDraft: (draft) async {
            _daoDraft = draft;
            await _persistLocalDrafts();
            if (mounted) {
              setState(() {});
            }
          },
          onSubmit: _submitDaoReview,
        );
        break;
      case _OnboardingStep.accountPermissions:
        content = _PermissionsStep(
          title: l10n.onboardingFlowPermissionsTitle,
          body: l10n.onboardingFlowPermissionsBody,
          hint: _permissionHint,
          locationEnabled: _locationEnabled,
          cameraEnabled: _cameraEnabled,
          notificationEnabled: _notificationEnabled,
          onRequestLocation: () => _requestPermission(Permission.location),
          onRequestCamera: () => _requestPermission(Permission.camera),
          onRequestNotification: () =>
              _requestPermission(Permission.notification),
        );
        break;
      case _OnboardingStep.done:
        content = _DoneStep(
          title: l10n.onboardingFlowDoneTitle,
          body: l10n.onboardingFlowDoneBody,
        );
        break;
    }

    if (_isDesktop) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          color: scheme.surface.withValues(alpha: 0.12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [palette.start, palette.accent, palette.end],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [palette.start, palette.accent, palette.end],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  IconData _stepIcon(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return Icons.explore_outlined;
      case _OnboardingStep.guestPermissions:
        return Icons.shield_outlined;
      case _OnboardingStep.account:
        return Icons.person_add_alt_1_outlined;
      case _OnboardingStep.verifyEmail:
        return Icons.mark_email_read_outlined;
      case _OnboardingStep.role:
        return Icons.tune_outlined;
      case _OnboardingStep.profile:
        return Icons.badge_outlined;
      case _OnboardingStep.walletBackup:
        return Icons.vpn_key_outlined;
      case _OnboardingStep.daoReview:
        return Icons.fact_check_outlined;
      case _OnboardingStep.accountPermissions:
        return Icons.shield_outlined;
      case _OnboardingStep.done:
        return Icons.rocket_launch_outlined;
    }
  }

  Widget _buildBottomActions(AppLocalizations l10n, {required bool compact}) {
    if (_currentStep == _OnboardingStep.account) {
      if (_currentIndex == 0) {
        return const SizedBox.shrink();
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final backForeground = isDark
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.95);
      return Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: _goBackStep,
          style: TextButton.styleFrom(
            foregroundColor: backForeground,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.lg,
              vertical: KubusSpacing.sm,
            ),
            minimumSize: const Size(48, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(l10n.commonBack),
        ),
      );
    }

    if (_currentStep == _OnboardingStep.role ||
        _currentStep == _OnboardingStep.profile ||
        _currentStep == _OnboardingStep.walletBackup ||
        _currentStep == _OnboardingStep.daoReview) {
      if (_currentIndex == 0) {
        return const SizedBox.shrink();
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final backForeground = isDark
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.95);
      return Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: _goBackStep,
          style: TextButton.styleFrom(
            foregroundColor: backForeground,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.lg,
              vertical: KubusSpacing.sm,
            ),
            minimumSize: const Size(48, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(l10n.commonBack),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Back button text: white to be readable against gradient background
    final backForeground = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KubusButton(
          onPressed: _onPrimaryAction,
          label: _primaryLabelForStep(l10n),
          isFullWidth: true,
        ),
        if (_currentIndex > 0)
          Padding(
            padding: EdgeInsets.only(top: compact ? 6 : 8),
            child: TextButton(
              onPressed: _goBackStep,
              style: TextButton.styleFrom(
                foregroundColor: backForeground,
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.lg,
                  vertical: KubusSpacing.sm,
                ),
                minimumSize: const Size(48, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.commonBack),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopStepRail(AppLocalizations l10n, ColorScheme scheme) {
    final labels = _steps.map((step) {
      switch (step) {
        case _OnboardingStep.welcome:
          return l10n.onboardingExploreTitle;
        case _OnboardingStep.guestPermissions:
          return l10n.onboardingFlowPermissionsTitle;
        case _OnboardingStep.account:
          return l10n.onboardingFlowAccountTitle;
        case _OnboardingStep.verifyEmail:
          return l10n.onboardingFlowVerifyLastTitle;
        case _OnboardingStep.role:
          return l10n.onboardingFlowRoleTitle;
        case _OnboardingStep.profile:
          return l10n.onboardingFlowProfileTitle;
        case _OnboardingStep.walletBackup:
          return l10n.onboardingFlowWalletBackupTitle;
        case _OnboardingStep.daoReview:
          return 'DAO review';
        case _OnboardingStep.accountPermissions:
          return l10n.onboardingFlowPermissionsTitle;
        case _OnboardingStep.done:
          return l10n.onboardingFlowDoneTitle;
      }
    }).toList(growable: false);

    return Container(
      key: const Key('onboarding_desktop_step_rail'),
      width: 260,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.xs,
              KubusSpacing.xs,
              KubusSpacing.xs,
              KubusSpacing.sm,
            ),
            child: Text(
              l10n.onboardingFlowTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: labels.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KubusSpacing.xs),
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isActive = index == _currentIndex;
                final isDone = _completed.contains(step);
                final palette = _paletteForStep(step);
                final icon = isDone ? Icons.check_circle : _stepIcon(step);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm,
                    vertical: KubusSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? palette.accent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: isActive
                          ? palette.accent.withValues(alpha: 0.32)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            colors: isDone
                                ? <Color>[scheme.primary, scheme.primary]
                                : <Color>[palette.start, palette.end],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(
                        child: Text(
                          labels[index],
                          maxLines: 3,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(AppLocalizations l10n, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spotlight = _paletteForStep(_OnboardingStep.welcome);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLogo(width: 46, height: 46),
                      const Spacer(),
                      const AuthEntryControls(compact: false),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.onboardingWelcomeTitle,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      const AuthEntryControls(compact: true),
                    ],
                  ),
            SizedBox(height: _isDesktop ? KubusSpacing.xl : KubusSpacing.md),
            Expanded(
              child: _isDesktop
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1120,
                          maxHeight: 640,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _WelcomeHeroColumn(
                                title: l10n.onboardingWelcomeTitle,
                                subtitle: l10n.onboardingWelcomeDescription,
                                details: [
                                  l10n.onboardingFlowWelcomeInfoAccount,
                                  l10n.onboardingFlowWelcomeInfoCreate,
                                  l10n.onboardingFlowWelcomeInfoFollow,
                                  l10n.onboardingFlowWelcomeInfoTime,
                                ],
                                start: spotlight.start,
                                end: spotlight.end,
                              ),
                            ),
                            const SizedBox(width: KubusSpacing.xl),
                            SizedBox(
                              width: 440,
                              child: _WelcomeDecisionPanel(
                                isDark: isDark,
                                scheme: scheme,
                                discoverTitle: l10n.commonDiscoverArt,
                                discoverBody:
                                    l10n.onboardingWelcomeDiscoverBody,
                                createTitle: l10n.commonCreateAccount,
                                createBody: l10n.onboardingFlowAccountBody,
                                onSelectGuest: _selectGuestBranch,
                                onSelectAccount: _selectAccountBranch,
                                onSignIn: () {
                                  Navigator.of(context)
                                      .pushReplacementNamed('/sign-in');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.onboardingWelcomeDescription,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.74,
                                    ),
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        Expanded(
                          child: _WelcomeDecisionPanel(
                            isDark: isDark,
                            scheme: scheme,
                            compact: true,
                            discoverTitle: l10n.commonDiscoverArt,
                            discoverBody: l10n.onboardingWelcomeDiscoverBody,
                            createTitle: l10n.commonCreateAccount,
                            createBody: l10n.onboardingFlowAccountBody,
                            onSelectGuest: _selectGuestBranch,
                            onSelectAccount: _selectAccountBranch,
                            onSignIn: () {
                              Navigator.of(context)
                                  .pushReplacementNamed('/sign-in');
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContent(AppLocalizations l10n, ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopStepRail(l10n, scheme),
        const SizedBox(width: KubusSpacing.md),
        Expanded(child: _buildStepCard(l10n, scheme)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accent = themeProvider.accentColor;
    final stepPalette = _paletteForStep(_currentStep);
    final onboardingTheme = theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final bgStart = stepPalette.start.withValues(alpha: 0.76);
    final bgEnd = stepPalette.end.withValues(alpha: 0.68);
    final bgMid = Color.lerp(bgStart, bgEnd, 0.45) ?? bgEnd;
    final bgAccent =
        Color.lerp(stepPalette.accent, accent, 0.3)?.withValues(alpha: 0.58) ??
            accent.withValues(alpha: 0.58);
    final isWidgetTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');

    if (_isInitializing) {
      return AnimatedGradientBackground(
        animate: !isWidgetTestBinding,
        colors: [bgStart, bgMid, bgEnd, bgStart],
        intensity: 0.3,
        child: Theme(
          data: onboardingTheme,
          child: const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return AnimatedGradientBackground(
      animate: !isWidgetTestBinding,
      colors: [bgStart, bgMid, bgAccent, bgEnd, bgStart],
      intensity: 0.3,
      child: Theme(
        data: onboardingTheme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight =
                    !_isDesktop && constraints.maxHeight < 760;
                final compactLayout = compactHeight;
                final hideProgress = !_isDesktop && constraints.maxHeight < 700;

                if (_isWelcomePhase) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isDesktop
                          ? KubusSpacing.lg
                          : (compactLayout ? KubusSpacing.sm : KubusSpacing.md),
                      vertical: compactLayout ? 8 : 10,
                    ),
                    child: _buildWelcomeScreen(l10n, scheme),
                  );
                }

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isDesktop
                        ? KubusSpacing.lg
                        : (compactLayout ? KubusSpacing.sm : KubusSpacing.md),
                    vertical: compactLayout ? 8 : 10,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _isDesktop ? 1280 : double.infinity,
                      ),
                      child: Column(
                        children: [
                          _buildHeader(
                            l10n,
                            scheme,
                            compact: compactLayout,
                          ),
                          SizedBox(
                            height: compactLayout
                                ? KubusSpacing.xs
                                : KubusSpacing.sm,
                          ),
                          if (!hideProgress) ...[
                            _buildProgress(scheme),
                            SizedBox(
                              height: compactLayout ? KubusSpacing.xs : 12,
                            ),
                          ],
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: _isDesktop
                                      ? _buildDesktopContent(l10n, scheme)
                                      : _buildStepCard(l10n, scheme),
                                ),
                                SizedBox(
                                  height: compactLayout
                                      ? KubusSpacing.sm
                                      : KubusSpacing.md,
                                ),
                                _buildBottomActions(
                                  l10n,
                                  compact: compactLayout,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _primaryLabelForStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
      case _OnboardingStep.guestPermissions:
      case _OnboardingStep.account:
      case _OnboardingStep.role:
      case _OnboardingStep.profile:
      case _OnboardingStep.daoReview:
      case _OnboardingStep.accountPermissions:
        return l10n.commonContinue;
      case _OnboardingStep.walletBackup:
        return l10n.onboardingFlowWalletBackupAction;
      case _OnboardingStep.verifyEmail:
        return l10n.onboardingFlowVerifyContinue;
      case _OnboardingStep.done:
        return l10n.commonGetStarted;
    }
  }
}

class _AccountStep extends StatefulWidget {
  const _AccountStep({
    required this.title,
    required this.body,
    required this.verifyHint,
    required this.profileDisplayName,
    required this.onAuthCompleted,
    required this.onEmailRegistrationAttempted,
    required this.onVerificationRequired,
    required this.onSignInSuccess,
    required this.onSignInNeedsVerification,
  });

  final String title;
  final String body;
  final String verifyHint;
  final String profileDisplayName;
  final Future<void> Function() onAuthCompleted;
  final Future<void> Function(String email) onEmailRegistrationAttempted;
  final Future<void> Function(String email) onVerificationRequired;
  final Future<void> Function(Map<String, dynamic>) onSignInSuccess;
  final Future<void> Function(String email) onSignInNeedsVerification;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  bool _showSignIn = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthTitleRow(
              title: widget.title,
              subtitle: widget.body,
              compact: compact,
              foregroundColor: Colors.white,
              subtitleColor: Colors.white.withValues(alpha: 0.85),
            ),
            if (!compact) ...[
              const SizedBox(height: KubusSpacing.xs),
              Text(
                widget.verifyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
              ),
            ],
            const SizedBox(height: KubusSpacing.sm),
            _OnboardingAuthModeSwitch(
              showSignIn: _showSignIn,
              compact: compact,
              onShowCreateAccount: () {
                setState(() => _showSignIn = false);
              },
              onShowSignIn: () {
                setState(() => _showSignIn = true);
              },
            ),
            SizedBox(height: compact ? KubusSpacing.xs : 10),
            Expanded(
              child: _showSignIn
                  ? SignInScreen(
                      embedded: true,
                      onAuthSuccess: widget.onSignInSuccess,
                      onVerificationRequired: (email) => unawaited(
                        widget.onSignInNeedsVerification(email),
                      ),
                      onSwitchToRegister: () {
                        setState(() => _showSignIn = false);
                      },
                    )
                  : AuthMethodsPanel(
                      embedded: true,
                      onAuthSuccess: widget.onAuthCompleted,
                      requireUsernameForEmailRegistration: true,
                      preferredEmailGreetingName:
                          widget.profileDisplayName.trim().isEmpty
                              ? null
                              : widget.profileDisplayName.trim(),
                      prepareProvisionalProfileBeforeRegister: false,
                      onEmailRegistrationAttempted: (email) =>
                          unawaited(widget.onEmailRegistrationAttempted(email)),
                      onVerificationRequired: widget.onVerificationRequired,
                      onSwitchToSignIn: () {
                        setState(() => _showSignIn = true);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingAuthModeSwitch extends StatelessWidget {
  const _OnboardingAuthModeSwitch({
    required this.showSignIn,
    required this.compact,
    required this.onShowCreateAccount,
    required this.onShowSignIn,
  });

  final bool showSignIn;
  final bool compact;
  final VoidCallback onShowCreateAccount;
  final VoidCallback onShowSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _OnboardingAuthModeButton(
                label: l10n.commonCreateAccount,
                selected: !showSignIn,
                compact: compact,
                onTap: onShowCreateAccount,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _OnboardingAuthModeButton(
                label: l10n.commonSignIn,
                selected: showSignIn,
                compact: compact,
                onTap: onShowSignIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingAuthModeButton extends StatelessWidget {
  const _OnboardingAuthModeButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm,
            vertical: compact ? 10 : 12,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        Colors.white.withValues(alpha: selected ? 0.96 : 0.78),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeroColumn extends StatelessWidget {
  const _WelcomeHeroColumn({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.start,
    required this.end,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GradientIconCard(
          start: start,
          end: end,
          icon: Icons.explore_outlined,
          iconSize: 42,
          width: 88,
          height: 88,
          radius: 24,
        ),
        const SizedBox(height: KubusSpacing.xl),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                height: 1.02,
              ),
        ),
        const SizedBox(height: KubusSpacing.md),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.76),
                height: 1.55,
              ),
        ),
        const SizedBox(height: KubusSpacing.xl),
        Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: details
              .map(
                (detail) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      detail,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.84),
                          ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _WelcomeDecisionPanel extends StatelessWidget {
  const _WelcomeDecisionPanel({
    required this.isDark,
    required this.scheme,
    this.compact = false,
    required this.discoverTitle,
    required this.discoverBody,
    required this.createTitle,
    required this.createBody,
    required this.onSelectGuest,
    required this.onSelectAccount,
    required this.onSignIn,
  });

  final bool isDark;
  final ColorScheme scheme;
  final bool compact;
  final String discoverTitle;
  final String discoverBody;
  final String createTitle;
  final String createBody;
  final Future<void> Function() onSelectGuest;
  final Future<void> Function() onSelectAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.84),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? KubusSpacing.lg : KubusSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              _WelcomeChoiceCard(
                compact: compact,
                icon: Icons.travel_explore_rounded,
                title: discoverTitle,
                body: discoverBody,
                action: KubusButton(
                  onPressed: () => unawaited(onSelectGuest()),
                  label: discoverTitle,
                  isFullWidth: true,
                ),
              )
            else
              Expanded(
                child: _WelcomeChoiceCard(
                  compact: compact,
                  fillHeight: true,
                  icon: Icons.travel_explore_rounded,
                  title: discoverTitle,
                  body: discoverBody,
                  action: KubusButton(
                    onPressed: () => unawaited(onSelectGuest()),
                    label: discoverTitle,
                    isFullWidth: true,
                  ),
                ),
              ),
            const SizedBox(height: KubusSpacing.md),
            if (compact)
              _WelcomeChoiceCard(
                compact: compact,
                icon: Icons.person_add_alt_1_rounded,
                title: createTitle,
                body: createBody,
                action: KubusOutlineButton(
                  onPressed: () => unawaited(onSelectAccount()),
                  label: createTitle,
                  isFullWidth: true,
                ),
              )
            else
              Expanded(
                child: _WelcomeChoiceCard(
                  compact: compact,
                  fillHeight: true,
                  icon: Icons.person_add_alt_1_rounded,
                  title: createTitle,
                  body: createBody,
                  action: KubusOutlineButton(
                    onPressed: () => unawaited(onSelectAccount()),
                    label: createTitle,
                    isFullWidth: true,
                  ),
                ),
              ),
            const SizedBox(height: KubusSpacing.lg),
            Center(
              child: TextButton(
                onPressed: onSignIn,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                ),
                child: Text(AppLocalizations.of(context)!.commonSignIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeChoiceCard extends StatelessWidget {
  const _WelcomeChoiceCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    this.fillHeight = false,
  });

  final bool compact;
  final IconData icon;
  final String title;
  final String body;
  final Widget action;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? KubusSpacing.md : KubusSpacing.lg),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.onSurface, size: compact ? 22 : 26),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              title,
              style: (compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              body,
              maxLines: compact ? 2 : null,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
            ),
            if (fillHeight) const Spacer(),
            const SizedBox(height: KubusSpacing.md),
            action,
          ],
        ),
      ),
    );
  }
}

class _VerifyEmailStep extends StatelessWidget {
  const _VerifyEmailStep({
    required this.title,
    required this.body,
    required this.email,
    required this.isVerified,
    required this.isSignedIn,
    required this.requiresFinishSignIn,
    required this.isRefreshingVerification,
    required this.onRefreshVerification,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String? email;
  final bool isVerified;
  final bool isSignedIn;
  final bool requiresFinishSignIn;
  final bool isRefreshingVerification;
  final Future<void> Function() onRefreshVerification;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    final normalizedEmail = (email ?? '').trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 260 &&
            !isSignedIn &&
            !requiresFinishSignIn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                AppLocalizations.of(context)!.commonSignIn,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const Spacer(),
            ],
          );
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _InlineVerificationPanel(
              title: title,
              body: body,
              email: normalizedEmail,
              isVerified: isVerified,
              isSignedIn: isSignedIn,
              requiresFinishSignIn: requiresFinishSignIn,
              isRefreshingVerification: isRefreshingVerification,
              onRefreshVerification: onRefreshVerification,
              onAuthSuccess: onAuthSuccess,
              onVerificationRequired: onVerificationRequired,
            ),
          ),
        );
      },
    );
  }
}

class _InlineVerificationPanel extends StatefulWidget {
  const _InlineVerificationPanel({
    required this.title,
    required this.body,
    required this.email,
    required this.isVerified,
    required this.isSignedIn,
    required this.requiresFinishSignIn,
    required this.isRefreshingVerification,
    required this.onRefreshVerification,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String email;
  final bool isVerified;
  final bool isSignedIn;
  final bool requiresFinishSignIn;
  final bool isRefreshingVerification;
  final Future<void> Function() onRefreshVerification;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  State<_InlineVerificationPanel> createState() =>
      _InlineVerificationPanelState();
}

class _InlineVerificationPanelState extends State<_InlineVerificationPanel> {
  bool _sending = false;
  String? _inlineMessage;

  Future<void> _resend() async {
    final email = widget.email;
    if (email.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _inlineMessage = null;
    });
    try {
      await BackendApiService().resendEmailVerification(email: email);
      if (!mounted) return;
      setState(() {
        _inlineMessage =
            AppLocalizations.of(context)!.authVerifyEmailResendToast;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineMessage =
            AppLocalizations.of(context)!.authVerifyEmailResendFailedInline;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.visible),
        const SizedBox(height: KubusSpacing.sm),
        Text(widget.body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 12),
        if (widget.email.isNotEmpty)
          Text(
            '${AppLocalizations.of(context)!.commonEmail}: ${widget.email}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isVerified
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isVerified
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isVerified
                    ? Icons.check_circle_outline
                    : Icons.mark_email_unread_outlined,
                size: 18,
                color: widget.isVerified
                    ? const Color(0xFF81C784)
                    : Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isVerified
                      ? AppLocalizations.of(context)!
                          .authVerifyEmailStatusVerified
                      : AppLocalizations.of(context)!
                          .authVerifyEmailStatusPending,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.isVerified
                            ? const Color(0xFF81C784)
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.isVerified) ...[
          const SizedBox(height: 12),
          KubusButton(
            onPressed: _sending || widget.email.isEmpty ? null : _resend,
            isLoading: _sending,
            label: AppLocalizations.of(context)!.authVerifyEmailResendButton,
            isFullWidth: true,
          ),
          const SizedBox(height: KubusSpacing.sm),
          KubusButton(
            onPressed: widget.isRefreshingVerification || widget.email.isEmpty
                ? null
                : () => unawaited(widget.onRefreshVerification()),
            isLoading: widget.isRefreshingVerification,
            label: AppLocalizations.of(context)!.onboardingFlowVerifyContinue,
            isFullWidth: true,
          ),
        ] else ...[
          const SizedBox(height: KubusSpacing.sm),
          Text(
            'Email confirmed. Continue to finish onboarding.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.76),
                ),
          ),
        ],
        if (widget.requiresFinishSignIn && widget.email.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          Text(
            'Sign in to finish',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            'Use your verified email and password to finish onboarding.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.78),
                ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          _FinishVerificationSignInPanel(
            email: widget.email,
            onAuthSuccess: widget.onAuthSuccess,
            onVerificationRequired: widget.onVerificationRequired,
          ),
        ],
        if ((_inlineMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _inlineMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
        ],
        const SizedBox(height: KubusSpacing.xs),
      ],
    );
  }
}

class _FinishVerificationSignInPanel extends StatefulWidget {
  const _FinishVerificationSignInPanel({
    required this.email,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String email;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  State<_FinishVerificationSignInPanel> createState() =>
      _FinishVerificationSignInPanelState();
}

class _FinishVerificationSignInPanelState
    extends State<_FinishVerificationSignInPanel> {
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() {
        _inlineError = l10n.authEnterValidEmailPassword;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    try {
      final result = await BackendApiService().loginWithEmail(
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Signed in. Finishing onboarding...')),
        tone: KubusSnackBarTone.success,
      );
      await widget.onAuthSuccess(result);
    } on BackendApiRequestException catch (error) {
      if (!mounted) return;
      var requiresVerification = false;
      if (error.statusCode == 403) {
        try {
          final decoded = jsonDecode((error.body ?? '').trim());
          if (decoded is Map<String, dynamic>) {
            requiresVerification = decoded['requiresEmailVerification'] == true;
          }
        } catch (_) {
          requiresVerification = false;
        }
      }
      if (requiresVerification) {
        await widget.onVerificationRequired(widget.email);
        if (!mounted) return;
        setState(() {
          _inlineError = l10n.authEmailNotVerifiedToast;
        });
        return;
      }
      setState(() {
        _inlineError = l10n.authEmailSignInFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = l10n.authEmailSignInFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.commonPassword,
              border: const OutlineInputBorder(),
            ),
          ),
          if ((_inlineError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              _inlineError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          KubusButton(
            onPressed: _submitting ? null : _submit,
            isLoading: _submitting,
            label: l10n.commonSignIn,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _InlineProfileStep extends StatefulWidget {
  const _InlineProfileStep({
    required this.title,
    required this.body,
    required this.persona,
    required this.initialDisplayName,
    required this.initialUsername,
    required this.initialBio,
    required this.initialAvatarUrl,
    required this.initialWebsite,
    required this.initialFieldOfWork,
    required this.initialYearsActive,
    required this.onSave,
    required this.onAvatarStaged,
  });

  final String title;
  final String body;
  final UserPersona? persona;
  final String initialDisplayName;
  final String initialUsername;
  final String initialBio;
  final String initialAvatarUrl;
  final String initialWebsite;
  final String initialFieldOfWork;
  final String initialYearsActive;
  final Future<void> Function({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) onAvatarStaged;
  final Future<void> Function({
    required String displayName,
    required String username,
    required String bio,
    required String? avatar,
    required String website,
    required String fieldOfWork,
    required String yearsActive,
  }) onSave;

  @override
  State<_InlineProfileStep> createState() => _InlineProfileStepState();
}

class _InlineProfileStepState extends State<_InlineProfileStep> {
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _website;
  late final TextEditingController _fieldOfWork;
  late final TextEditingController _yearsActive;
  final _displayNameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  Uint8List? _localAvatarBytes;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.initialDisplayName);
    _username = TextEditingController(text: widget.initialUsername);
    _bio = TextEditingController(text: widget.initialBio);
    _website = TextEditingController(text: widget.initialWebsite);
    _fieldOfWork = TextEditingController(text: widget.initialFieldOfWork);
    _yearsActive = TextEditingController(text: widget.initialYearsActive);
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    _website.dispose();
    _fieldOfWork.dispose();
    _yearsActive.dispose();
    _displayNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _localAvatarBytes = bytes);

      final fileName = image.name.trim().isNotEmpty
          ? image.name.trim()
          : 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await widget.onAvatarStaged(
        bytes: bytes,
        fileName: fileName,
        mimeType: image.mimeType,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        const SnackBar(content: Text('Unable to select avatar right now.')),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        displayName: _displayName.text,
        username: _username.text,
        bio: _bio.text,
        avatar: _avatarUrl,
        website: _website.text,
        fieldOfWork: _fieldOfWork.text,
        yearsActive: _yearsActive.text,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _resolvedAvatarUrl() {
    final resolved = MediaUrlResolver.resolveDisplayUrl(_avatarUrl) ??
        MediaUrlResolver.resolve(_avatarUrl);
    return (resolved ?? '').trim();
  }

  Widget _buildAvatarPreview(ColorScheme scheme) {
    if (_localAvatarBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          _localAvatarBytes!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    }

    final avatarUrl = _resolvedAvatarUrl();
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          avatarUrl,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person_outline,
            size: 36,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    return Icon(
      Icons.person_outline,
      size: 36,
      color: scheme.onSurface.withValues(alpha: 0.75),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isInstitution = widget.persona == UserPersona.institution;
    final isCreator = widget.persona == UserPersona.creator;
    final introBody = isInstitution
        ? 'Add the organization details people should see first. The DAO review step comes right after this.'
        : isCreator
            ? 'Set up your public creator profile now so your review submission has the right context.'
            : widget.body;
    final displayNameLabel = isInstitution
        ? 'Organization name'
        : l10n.desktopSettingsDisplayNameLabel;
    final bioLabel =
        isInstitution ? 'About your institution' : l10n.desktopSettingsBioLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.visible),
        const SizedBox(height: KubusSpacing.sm),
        Text(introBody,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: scheme.surface.withValues(alpha: 0.45),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Center(child: _buildAvatarPreview(scheme)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed:
                            (_saving || _uploadingAvatar) ? null : _pickAvatar,
                        icon: _uploadingAvatar
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                        label: Text(_uploadingAvatar
                            ? 'Selecting...'
                            : l10n.commonUpload),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: _displayName,
                  focusNode: _displayNameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _usernameFocusNode.requestFocus(),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: displayNameLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _username,
                  focusNode: _usernameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _bioFocusNode.requestFocus(),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: l10n.desktopSettingsUsernameLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bio,
                  focusNode: _bioFocusNode,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: bioLabel,
                  ),
                ),
                if (isInstitution) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.profileEditSocialWebsiteLabel,
                      hintText: l10n.profileEditSocialWebsiteHint,
                    ),
                  ),
                ],
                if (isCreator) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fieldOfWork,
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.profileEditArtistSpecialtiesLabel,
                      helperText: l10n.profileEditArtistSpecialtiesHelper,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _yearsActive,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.profileEditArtistYearsActiveLabel,
                      hintText: l10n.profileEditArtistYearsActiveHint,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                KubusButton(
                  onPressed: (_saving || _uploadingAvatar) ? null : _save,
                  isLoading: _saving,
                  label: l10n.commonSave,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DaoReviewStep extends StatefulWidget {
  const _DaoReviewStep({
    required this.title,
    required this.body,
    required this.persona,
    required this.draft,
    required this.review,
    required this.isLoadingReview,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final String title;
  final String body;
  final UserPersona? persona;
  final _DaoApplicationDraftRecord? draft;
  final DAOReview? review;
  final bool isLoadingReview;
  final Future<void> Function(_DaoApplicationDraftRecord draft) onSaveDraft;
  final Future<void> Function() onSubmit;

  @override
  State<_DaoReviewStep> createState() => _DaoReviewStepState();
}

class _DaoReviewStepState extends State<_DaoReviewStep> {
  late final TextEditingController _title;
  late final TextEditingController _contact;
  late final TextEditingController _portfolioUrl;
  late final TextEditingController _medium;
  late final TextEditingController _statement;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _title = TextEditingController(text: draft?.title ?? '');
    _contact = TextEditingController(text: draft?.contact ?? '');
    _portfolioUrl = TextEditingController(text: draft?.portfolioUrl ?? '');
    _medium = TextEditingController(text: draft?.medium ?? '');
    _statement = TextEditingController(text: draft?.statement ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _contact.dispose();
    _portfolioUrl.dispose();
    _medium.dispose();
    _statement.dispose();
    super.dispose();
  }

  _DaoApplicationDraftRecord _currentDraft() {
    final isInstitution = widget.persona == UserPersona.institution;
    return _DaoApplicationDraftRecord(
      isArtist: !isInstitution,
      isInstitution: isInstitution,
      title: _title.text.trim(),
      contact: _contact.text.trim(),
      portfolioUrl: _portfolioUrl.text.trim(),
      medium: _medium.text.trim(),
      statement: _statement.text.trim(),
    );
  }

  Future<void> _saveDraft() async {
    await widget.onSaveDraft(_currentDraft());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInstitution = widget.persona == UserPersona.institution;
    final role = isInstitution ? DaoRoleType.institution : DaoRoleType.artist;
    final verification = DaoRoleVerification(
      walletAddress: '',
      review: widget.review,
    );
    final isSatisfied =
        verification.isApprovedFor(role) || verification.isPendingFor(role);
    final status = widget.review?.status.toLowerCase() ?? '';
    final statusLabel = status.isEmpty ? null : 'Current status: $status';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          widget.body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
        ),
        const SizedBox(height: 12),
        if (widget.isLoadingReview) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
        ] else if (statusLabel != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KubusSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              statusLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInstitution) ...[
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                    ),
                    onChanged: (_) => unawaited(_saveDraft()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contact,
                    decoration: const InputDecoration(
                      labelText: 'Contact URL or email',
                    ),
                    onChanged: (_) => unawaited(_saveDraft()),
                  ),
                ] else ...[
                  TextField(
                    controller: _portfolioUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Portfolio URL',
                    ),
                    onChanged: (_) => unawaited(_saveDraft()),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _medium,
                  decoration: InputDecoration(
                    labelText:
                        isInstitution ? 'Institution focus' : 'Primary medium',
                  ),
                  onChanged: (_) => unawaited(_saveDraft()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _statement,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: isInstitution ? 'Mission' : 'Artist statement',
                  ),
                  onChanged: (_) => unawaited(_saveDraft()),
                ),
                if ((widget.review?.reviewerNotes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Reviewer notes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.review!.reviewerNotes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        KubusButton(
          onPressed: widget.isLoadingReview ? null : widget.onSubmit,
          label: isSatisfied ? 'Continue' : 'Submit for DAO review',
          isFullWidth: true,
        ),
      ],
    );
  }
}

class _RoleStep extends StatefulWidget {
  const _RoleStep({
    required this.title,
    required this.body,
    required this.selectedPersona,
    required this.onSelectPersona,
  });

  final String title;
  final String body;
  final UserPersona? selectedPersona;
  final Future<void> Function(UserPersona persona) onSelectPersona;

  @override
  State<_RoleStep> createState() => _RoleStepState();
}

class _RoleStepState extends State<_RoleStep> {
  UserPersona? _selectedPersona;

  @override
  void initState() {
    super.initState();
    _selectedPersona = widget.selectedPersona;
  }

  Future<void> _selectPersona(UserPersona persona) async {
    setState(() {
      _selectedPersona = persona;
    });
    await widget.onSelectPersona(persona);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minContentHeight =
            constraints.maxHeight > 64 ? constraints.maxHeight - 64 : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minContentHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                          maxLines: 3,
                          overflow: TextOverflow.visible),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(
                        widget.body,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(height: 12),
                      UserPersonaPickerContent(
                        selectedPersona: _selectedPersona,
                        onSelect: _selectPersona,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({
    required this.title,
    required this.body,
    required this.hint,
    required this.locationEnabled,
    required this.cameraEnabled,
    required this.notificationEnabled,
    required this.onRequestLocation,
    required this.onRequestCamera,
    required this.onRequestNotification,
  });

  final String title;
  final String body;
  final String? hint;
  final bool locationEnabled;
  final bool cameraEnabled;
  final bool notificationEnabled;
  final Future<void> Function() onRequestLocation;
  final Future<void> Function() onRequestCamera;
  final Future<void> Function() onRequestNotification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.visible),
        const SizedBox(height: KubusSpacing.sm),
        Text(body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 12),
        _PermissionTile(
          label: l10n.onboardingFlowPermissionLocation,
          enabled: locationEnabled,
          onTap: onRequestLocation,
        ),
        if (!kIsWeb)
          _PermissionTile(
            label: l10n.onboardingFlowPermissionCamera,
            enabled: cameraEnabled,
            onTap: onRequestCamera,
          ),
        _PermissionTile(
          label: l10n.onboardingFlowPermissionNotifications,
          enabled: notificationEnabled,
          onTap: onRequestNotification,
        ),
        if ((hint ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hint!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        const Spacer(),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white)),
      trailing: enabled
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF81C784)),
                const SizedBox(width: KubusSpacing.xs),
                Text(
                  l10n.permissionsGrantedLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF81C784),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
              ),
              child: Text(l10n.commonEnable),
            ),
    );
  }
}

class _WalletBackupStep extends StatelessWidget {
  const _WalletBackupStep({
    required this.title,
    required this.body,
    required this.privacyWarning,
    required this.lossWarning,
    required this.actionLabel,
    required this.completed,
    required this.onRevealMnemonic,
  });

  final String title;
  final String body;
  final String privacyWarning;
  final String lossWarning;
  final String actionLabel;
  final bool completed;
  final Future<void> Function() onRevealMnemonic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 380;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthTitleRow(
              title: title,
              subtitle: body,
              compact: compact,
              foregroundColor: Colors.white,
              subtitleColor: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KubusSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.privacy_tip_outlined,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(
                        child: Text(
                          privacyWarning,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(
                        child: Text(
                          lossWarning,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF81C784)),
                    const SizedBox(width: KubusSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.onboardingFlowWalletBackupCompleted,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF81C784),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            KubusButton(
              onPressed: () => unawaited(onRevealMnemonic()),
              label: actionLabel,
              icon: Icons.visibility_outlined,
              isFullWidth: true,
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isWide ? 28 : null,
                      color: Colors.white,
                    ),
                maxLines: 3,
                overflow: TextOverflow.visible),
            const SizedBox(height: KubusSpacing.sm),
            Text(body,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
            const Spacer(),
          ],
        );
      },
    );
  }
}
