import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/events/exhibition_creator_screen.dart';
import 'package:art_kubus/screens/web3/artist/artwork_creator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/notification_helper.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/push_notification_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/user_persona_picker_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum _OnboardingStep {
  welcome,
  mapDiscovery,
  community,
  arScan,
  daoGovernance,
  account,
  profile,
  role,
  permissions,
  artwork,
  follow,
  verifyEmail,
  done,
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
  static const int _flowVersion = 4;
  static const String _personaDraftKey = 'onboarding_persona_draft_v3';
  static const String _profileDraftKey = 'onboarding_profile_draft_v3';
  static const String _verificationEmailDraftKey =
      'onboarding_verification_email_v3';
  static const String _verificationPasswordSecureKey =
      'onboarding_verification_password_v3';
  static const AndroidOptions _secureStorageAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const IOSOptions _secureStorageIOSOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const Duration _verificationPollInterval = Duration(seconds: 4);
  static const Duration _verificationPollMaxDuration = Duration(seconds: 75);

  List<_OnboardingStep> _steps = const <_OnboardingStep>[];
  final Set<_OnboardingStep> _completed = <_OnboardingStep>{};
  final Set<_OnboardingStep> _deferred = <_OnboardingStep>{};

  int _currentIndex = 0;
  bool _isInitializing = true;
  bool _isBusy = false;
  bool _locationEnabled = false;
  bool _notificationEnabled = false;
  bool _cameraEnabled = false;

  List<Map<String, dynamic>> _artists = <Map<String, dynamic>>[];
  final Set<String> _followedArtists = <String>{};
  bool _isLoadingArtists = false;
  bool _isSkippingFlow = false;
  bool _isSignedIn = false;
  String? _pendingVerificationEmail;
  String? _pendingVerificationPassword;
  String? _permissionHint;
  Permission? _permissionHintPermission;
  UserPersona? _selectedPersona;
  Map<String, String> _localProfileDraft = <String, String>{};
  late final String _inlineArtworkDraftId;
  Map<String, dynamic>? _daoReview;
  String? _daoMessage;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarFileName;
  String? _pendingAvatarMimeType;
  Timer? _verificationPollTimer;
  DateTime? _verificationPollStartedAt;
  bool _verificationPollInFlight = false;
  bool _emailVerifiedConfirmed = false;
  bool _autoAdvancingVerification = false;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  _StepPalette _paletteForStep(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return const _StepPalette(
          start: Color(0xFF006064),
          end: KubusColors.accentTealLight,
          accent: Color(0xFF26A69A),
        );
      case _OnboardingStep.mapDiscovery:
        return const _StepPalette(
          start: Color(0xFF0D47A1),
          end: Color(0xFF1976D2),
          accent: Color(0xFF64B5F6),
        );
      case _OnboardingStep.community:
        return const _StepPalette(
          start: Color(0xFF2E7D32),
          end: Color(0xFF43A047),
          accent: Color(0xFFA5D6A7),
        );
      case _OnboardingStep.arScan:
        return const _StepPalette(
          start: Color(0xFFEF6C00),
          end: Color(0xFFF57C00),
          accent: Color(0xFFFFCC80),
        );
      case _OnboardingStep.daoGovernance:
        return const _StepPalette(
          start: Color(0xFF37474F),
          end: Color(0xFF546E7A),
          accent: Color(0xFFB0BEC5),
        );
      case _OnboardingStep.account:
        return const _StepPalette(
          start: Color(0xFF1565C0),
          end: Color(0xFF42A5F5),
          accent: KubusColors.accentBlue,
        );
      case _OnboardingStep.profile:
        return const _StepPalette(
          start: Color(0xFF00796B),
          end: Color(0xFF4DB6AC),
          accent: KubusColors.accentTealDark,
        );
      case _OnboardingStep.role:
        return const _StepPalette(
          start: Color(0xFFE65100),
          end: KubusColors.accentOrangeDark,
          accent: Color(0xFFFFB74D),
        );
      case _OnboardingStep.permissions:
        return const _StepPalette(
          start: Color(0xFF00695C),
          end: Color(0xFF26A69A),
          accent: Color(0xFF80CBC4),
        );
      case _OnboardingStep.artwork:
        return const _StepPalette(
          start: Color(0xFFC62828),
          end: KubusColors.errorDark,
          accent: Color(0xFFFF8A80),
        );
      case _OnboardingStep.follow:
        return const _StepPalette(
          start: KubusColors.primary,
          end: Color(0xFF4DD0E1),
          accent: Color(0xFF80DEEA),
        );
      case _OnboardingStep.verifyEmail:
        return const _StepPalette(
          start: Color(0xFF2E7D32),
          end: KubusColors.successDark,
          accent: Color(0xFFA5D6A7),
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

  _OnboardingStep get _currentStep =>
      _steps[_currentIndex.clamp(0, _steps.length - 1)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inlineArtworkDraftId =
        'onboarding_inline_${DateTime.now().microsecondsSinceEpoch}';
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
    if (_currentStep != _OnboardingStep.verifyEmail) return;
    _logVerificationRefresh('resume trigger');
    _startVerificationPollingIfNeeded(restartWindow: true);
    unawaited(_pollVerificationStatus(trigger: 'resume'));
  }

  void _logVerificationRefresh(String message) {
    if (!kDebugMode) return;
    debugPrint('OnboardingFlowScreen.$message');
  }

  String _extractBackendErrorMessage({
    required Object error,
    required String fallback,
  }) {
    if (error is BackendApiRequestException) {
      final rawBody = (error.body ?? '').trim();
      if (rawBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawBody);
          if (decoded is Map<String, dynamic>) {
            final backendError = (decoded['error'] ?? '').toString().trim();
            if (backendError.isNotEmpty) return backendError;
            final backendMessage = (decoded['message'] ?? '').toString().trim();
            if (backendMessage.isNotEmpty) return backendMessage;
          }
        } catch (_) {
          // Ignore parse errors and fall through to fallback.
        }
      }
    }
    return fallback;
  }

  Future<void> _bootstrap() async {
    _isSignedIn =
        Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
    final isWidgetTestBinding = WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

    final prefs = await SharedPreferences.getInstance();
    _hydrateLocalDrafts(prefs);
    await _restorePendingVerificationSecret();
    _steps = _buildSteps();
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: _flowVersion,
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
    final initialStepId = widget.initialStepId?.trim();
    var seededInitialProgress = false;
    if (!hasSavedProgress && initialStepId != null && initialStepId.isNotEmpty) {
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
    await _refreshDaoReview();
    _syncStepSideEffects();
  }

  Future<void> _restorePendingVerificationSecret() async {
    if (kIsWeb) return;
    try {
      final restored = (await _secureStorage.read(
            key: _verificationPasswordSecureKey,
            aOptions: _secureStorageAndroidOptions,
            iOptions: _secureStorageIOSOptions,
          ) ??
              '')
          .trim();
      final pendingEmail = (_pendingVerificationEmail ?? '').trim();
      if (pendingEmail.isEmpty) {
        await _secureStorage.delete(
          key: _verificationPasswordSecureKey,
          aOptions: _secureStorageAndroidOptions,
          iOptions: _secureStorageIOSOptions,
        );
        _pendingVerificationPassword = null;
        return;
      }
      _pendingVerificationPassword = restored.isEmpty ? null : restored;
    } catch (_) {
      _pendingVerificationPassword = null;
    }
  }

  Future<void> _persistPendingVerificationSecret() async {
    if (kIsWeb) return;
    final pendingPassword = (_pendingVerificationPassword ?? '').trim();
    try {
      if (pendingPassword.isEmpty) {
        await _secureStorage.delete(
          key: _verificationPasswordSecureKey,
          aOptions: _secureStorageAndroidOptions,
          iOptions: _secureStorageIOSOptions,
        );
        return;
      }
      await _secureStorage.write(
        key: _verificationPasswordSecureKey,
        value: pendingPassword,
        aOptions: _secureStorageAndroidOptions,
        iOptions: _secureStorageIOSOptions,
      );
    } catch (_) {}
  }

  Future<void> _clearPendingVerificationSecret({
    bool clearEmail = false,
  }) async {
    _pendingVerificationPassword = null;
    if (clearEmail) {
      _pendingVerificationEmail = null;
    }
    if (kIsWeb) return;
    try {
      await _secureStorage.delete(
        key: _verificationPasswordSecureKey,
        aOptions: _secureStorageAndroidOptions,
        iOptions: _secureStorageIOSOptions,
      );
    } catch (_) {}
  }

  void _hydrateLocalDrafts(SharedPreferences prefs) {
    final rawPersona = (prefs.getString(_personaDraftKey) ?? '').trim();
    _selectedPersona = UserPersonaX.tryParse(rawPersona);

    final rawProfile = (prefs.getString(_profileDraftKey) ?? '').trim();
    if (rawProfile.isEmpty) return;
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

    final pendingEmail =
        (prefs.getString(_verificationEmailDraftKey) ?? '').trim();
    if (pendingEmail.isNotEmpty) {
      _pendingVerificationEmail = pendingEmail;
    }
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

    final pendingEmail = (_pendingVerificationEmail ?? '').trim();
    if (pendingEmail.isEmpty) {
      await prefs.remove(_verificationEmailDraftKey);
    } else {
      await prefs.setString(_verificationEmailDraftKey, pendingEmail);
    }
  }

  Future<void> _refreshDaoReview() async {
    final wallet = Provider.of<ProfileProvider>(context, listen: false)
            .currentUser
            ?.walletAddress
            .trim() ??
        '';
    if (wallet.isEmpty) return;
    final review = await BackendApiService().getDAOReview(idOrWallet: wallet);
    if (!mounted) return;
    setState(() {
      _daoReview = review;
    });
  }

  bool _isDaoApprovedForRole({
    required bool isArtist,
    required bool isInstitution,
  }) {
    final review = _daoReview;
    if (review == null) return false;
    final status = (review['status'] ?? '').toString().toLowerCase();
    final approvedFlag = review['isApproved'] == true || status == 'approved';
    if (!approvedFlag) return false;
    final reviewArtist = review['isArtistApplication'] == true;
    final reviewInstitution = review['isInstitutionApplication'] == true;
    if (isInstitution) return reviewInstitution;
    if (isArtist) return reviewArtist;
    return false;
  }

  List<_OnboardingStep> _buildSteps() {
    final shouldShowArStep = AppConfig.isFeatureEnabled('ar');
    final shouldShowDaoStep = AppConfig.isFeatureEnabled('web3') &&
        (AppConfig.isFeatureEnabled('daoOnchainTreasury') ||
            AppConfig.isFeatureEnabled('daoReviewDecisions'));

    return <_OnboardingStep>[
      _OnboardingStep.welcome,
      _OnboardingStep.mapDiscovery,
      _OnboardingStep.community,
      if (shouldShowArStep) _OnboardingStep.arScan,
      if (shouldShowDaoStep) _OnboardingStep.daoGovernance,
      _OnboardingStep.role,
      _OnboardingStep.profile,
      _OnboardingStep.account,
      if (_verificationRequired) _OnboardingStep.verifyEmail,
      _OnboardingStep.permissions,
      _OnboardingStep.done,
    ];
  }

  bool get _verificationRequired =>
      (_pendingVerificationEmail ?? '').trim().isNotEmpty;

  Future<void> _loadPermissionStatuses() async {
    var locationEnabled = false;
    var notificationEnabled = false;
    var cameraEnabled = false;
    try {
      final location = await Permission.location.status;
      locationEnabled = location.isGranted;
    } catch (_) {}

    if (kIsWeb) {
      try {
        notificationEnabled = await isWebNotificationPermissionGranted();
      } catch (_) {
        notificationEnabled = false;
      }
      cameraEnabled = true;
    } else {
      try {
        final notifications = await Permission.notification.status;
        notificationEnabled = notifications.isGranted;
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

    if (!mounted) return;
    setState(() {
      _locationEnabled = locationEnabled;
      _notificationEnabled = notificationEnabled;
      _cameraEnabled = cameraEnabled;
    });
  }

  Future<void> _loadArtists() async {
    if (_isLoadingArtists) return;
    setState(() => _isLoadingArtists = true);
    try {
      final api = BackendApiService();
      final featured =
          await api.listArtists(featured: true, limit: 12, offset: 0);
      final all = await api.listArtists(limit: 12, offset: 0);
      final merged = <String, Map<String, dynamic>>{};
      for (final artist in [...featured, ...all]) {
        final wallet = (artist['walletAddress'] ?? '').toString().trim();
        if (wallet.isEmpty) continue;
        merged[wallet] = <String, dynamic>{...artist, 'walletAddress': wallet};
      }
      if (!mounted) return;
      setState(() {
        _artists = merged.values.take(6).toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artists = <Map<String, dynamic>>[];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingArtists = false);
      }
    }
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
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: _flowVersion,
      completedSteps: _completed.map(_stepId).toSet(),
      deferredSteps: _deferred.map(_stepId).toSet(),
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
    final shouldPoll = _currentStep == _OnboardingStep.verifyEmail &&
        pendingEmail.isNotEmpty &&
        !_isSignedIn;
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
            DateTime.now().difference(startedAt) > _verificationPollMaxDuration) {
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

      if (!verified || _autoAdvancingVerification) return;

      final password = (_pendingVerificationPassword ?? '').trim();
      if (!_isSignedIn && password.isNotEmpty) {
        try {
          final loginResult = await BackendApiService().loginWithEmail(
            email: email,
            password: password,
          );
          await _handleEmbeddedSignInSuccess(loginResult);
        } catch (_) {
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _autoAdvancingVerification = true;
      });
      try {
        await _clearPendingVerificationSecret(clearEmail: true);
        await _persistLocalDrafts();
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
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
    final isArtist = persona == UserPersona.creator
        ? true
        : (persona == UserPersona.lover ? false : null);
    final isInstitution = persona == UserPersona.institution
        ? true
        : (persona == UserPersona.lover ? false : null);

    await profileProvider.saveProfile(
      walletAddress: wallet,
      displayName: displayName.isEmpty ? null : displayName,
      username: username.isEmpty ? null : username,
      bio: bio.isEmpty ? null : bio,
      avatar: avatar.isEmpty ? null : avatar,
      social: social.isEmpty ? null : social,
      fieldOfWork: fieldOfWork.isEmpty ? null : fieldOfWork,
      yearsActive: yearsActive,
      isArtist: isArtist,
      isInstitution: isInstitution,
    );

    if (persona != null) {
      await profileProvider.setUserPersona(persona);
    }

    await _flushPendingAvatarUploadIfPossible();
  }

  void _refreshAuthDerivedSteps() {
    final signedInNow =
        Provider.of<ProfileProvider>(context, listen: false).isSignedIn;

    _isSignedIn = signedInNow;
    _steps = _buildSteps();
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
    if (step == _OnboardingStep.permissions) {
      await _markCompleted(_OnboardingStep.permissions);
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
    if (_currentStep == _OnboardingStep.follow &&
        _isSignedIn &&
        _artists.isEmpty &&
        !_isLoadingArtists) {
      unawaited(_loadArtists());
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final l10n = AppLocalizations.of(context)!;
    PermissionStatus status = PermissionStatus.denied;

    if (kIsWeb && permission == Permission.notification) {
      await PushNotificationService().requestPermission();
    } else if (kIsWeb && permission == Permission.camera) {
      status = PermissionStatus.granted;
    } else {
      try {
        status = await permission.request();
      } catch (_) {
        status = PermissionStatus.denied;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }
    }

    await _loadPermissionStatuses();
    if (!mounted) return;

    final bool granted;
    if (permission == Permission.location) {
      granted = _locationEnabled;
    } else if (permission == Permission.notification) {
      granted = _notificationEnabled;
    } else if (permission == Permission.camera) {
      granted = _cameraEnabled;
    } else {
      granted = status.isGranted;
    }

    setState(() {
      _permissionHint = granted
          ? null
          : l10n.permissionsOpenSettingsDialogContent(
              _permissionLabel(l10n, permission),
            );
      _permissionHintPermission = granted ? null : permission;
    });
  }

  String? _hintForPermission(Permission permission) {
    if (_permissionHintPermission == permission) {
      return _permissionHint;
    }
    return null;
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

  Future<void> _saveInlineProfile({
    required String displayName,
    required String username,
    required String bio,
    required String? avatar,
    required String twitter,
    required String instagram,
    required String website,
    required List<String> fieldOfWork,
    required int? yearsActive,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress;
    _localProfileDraft = <String, String>{
      'displayName': displayName.trim(),
      'username': username.trim(),
      'bio': bio.trim(),
      'avatar': (avatar ?? '').trim(),
      'twitter': twitter.trim(),
      'instagram': instagram.trim(),
      'website': website.trim(),
      'fieldOfWork': fieldOfWork.join(', '),
      'yearsActive': yearsActive?.toString() ?? '',
    };
    await _persistLocalDrafts();

    if (wallet != null && wallet.trim().isNotEmpty) {
      await profileProvider.saveProfile(
        walletAddress: wallet,
        displayName: displayName.trim().isEmpty ? null : displayName.trim(),
        username: username.trim().isEmpty ? null : username.trim(),
        bio: bio.trim().isEmpty ? null : bio.trim(),
        avatar: (avatar ?? '').trim().isEmpty ? null : avatar?.trim(),
        social: <String, String>{
          'twitter': twitter.trim(),
          'instagram': instagram.trim(),
          'website': website.trim(),
        },
        fieldOfWork: fieldOfWork,
        yearsActive: yearsActive,
      );
      await _flushPendingAvatarUploadIfPossible();
    }

    if (!mounted) return;
    await _markCompleted(_OnboardingStep.profile);
  }

  Future<void> _handleEmbeddedRegistrationSuccess() async {
    _refreshAuthDerivedSteps();
    await _refreshDaoReview();
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
    _pendingVerificationEmail = email.trim();
    _emailVerifiedConfirmed = false;
    _refreshAuthDerivedSteps();
    await _refreshDaoReview();
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
      _pendingVerificationEmail = email.trim();
      _emailVerifiedConfirmed = false;
    });
    await _persistLocalDrafts();
    _syncStepSideEffects();
  }

  Future<void> _handleEmbeddedEmailCredentialsCaptured(
      String email, String password) async {
    _pendingVerificationEmail = email.trim();
    _pendingVerificationPassword = password;
    _emailVerifiedConfirmed = false;
    await _persistPendingVerificationSecret();
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
    final normalizedEmail = email.trim();
    final previousPendingEmail = (_pendingVerificationEmail ?? '').trim();
    if (previousPendingEmail.isNotEmpty &&
        previousPendingEmail.toLowerCase() != normalizedEmail.toLowerCase()) {
      await _clearPendingVerificationSecret();
    }
    _pendingVerificationEmail = normalizedEmail;
    _emailVerifiedConfirmed = false;
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
    final pendingEmail = (_pendingVerificationEmail ?? '').trim().toLowerCase();
    var shouldPersistDrafts = false;
    if (pendingEmail.isNotEmpty &&
        (signedInEmail.isEmpty || signedInEmail == pendingEmail)) {
      await _clearPendingVerificationSecret(clearEmail: true);
      shouldPersistDrafts = true;
    } else if (pendingEmail.isEmpty) {
      _pendingVerificationEmail = null;
    }
    await _clearPendingVerificationSecret();
    _refreshAuthDerivedSteps();
    if (shouldPersistDrafts) {
      await _persistLocalDrafts();
    }
    await _refreshDaoReview();
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

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
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
    _refreshAuthDerivedSteps();

    final pendingEmail = (_pendingVerificationEmail ?? '').trim();
    final pendingPassword = (_pendingVerificationPassword ?? '').trim();

    if (_verificationRequired && !_isSignedIn && pendingEmail.isNotEmpty && pendingPassword.isNotEmpty) {
      try {
        final loginResult = await BackendApiService().loginWithEmail(
          email: pendingEmail,
          password: pendingPassword,
        );
        await _handleEmbeddedSignInSuccess(loginResult);
      } catch (_) {
        // Still waiting on verification; continue with fallback checks below.
      }
    }

    if (_verificationRequired && _isSignedIn) {
      final refreshed = await BackendApiService().refreshAuthTokenFromStorage();
      _refreshAuthDerivedSteps();
      if (refreshed) {
        await _clearPendingVerificationSecret(clearEmail: true);
        _emailVerifiedConfirmed = true;
        await _persistLocalDrafts();
      }
    }

    if (_verificationRequired) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.authVerifyEmailSignInHint,
          ),
        ),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

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

  Future<void> _applyRoleSelection({
    required bool isArtist,
    required bool isInstitution,
  }) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _selectedPersona = isInstitution
        ? UserPersona.institution
        : (isArtist ? UserPersona.creator : UserPersona.lover);
    await _persistLocalDrafts();
    profileProvider.setRoleFlags(
      isArtist: isArtist,
      isInstitution: isInstitution,
    );
    final wallet = profileProvider.currentUser?.walletAddress;
    if (wallet != null && wallet.isNotEmpty) {
      await profileProvider.setUserPersona(_selectedPersona ?? UserPersona.lover);
      await profileProvider.saveProfile(
        walletAddress: wallet,
        isArtist: isArtist,
        isInstitution: isInstitution,
      );
    }
    if (!mounted) return;
    await _markCompleted(_OnboardingStep.role);
  }

  Future<void> _applyPersonaSelection(UserPersona persona) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _selectedPersona = persona;
    await _persistLocalDrafts();
    final isArtist = persona == UserPersona.creator;
    final isInstitution = persona == UserPersona.institution;
    profileProvider.setRoleFlags(
      isArtist: isArtist,
      isInstitution: isInstitution,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> _submitDaoApplication({
    required bool isArtist,
    required bool isInstitution,
    required String portfolioUrl,
    required String medium,
    required String statement,
  }) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    if (!isArtist && !isInstitution) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.daoProposalFillRequiredFieldsToast)),
        tone: KubusSnackBarTone.warning,
      );
      return false;
    }

    _refreshAuthDerivedSteps();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (!_isSignedIn || wallet.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.artistStudioApplicationWalletRequiredToast)),
        tone: KubusSnackBarTone.warning,
      );
      await _jumpToStepIfPresent(_OnboardingStep.account);
      return false;
    }

    try {
      final review = await BackendApiService().submitDAOReview(
        walletAddress: wallet,
        portfolioUrl: portfolioUrl.trim(),
        medium: medium.trim(),
        statement: statement.trim(),
        title: isInstitution
            ? 'Institution onboarding application'
            : 'Artist onboarding application',
        metadata: <String, dynamic>{
          'role': isInstitution ? 'institution' : 'artist',
          'isArtistApplication': isArtist,
          'isInstitutionApplication': isInstitution,
          'source': 'onboarding_flow',
        },
      );

      if (review == null) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.daoProposalSubmitFailedToast)),
          tone: KubusSnackBarTone.error,
        );
        return false;
      }
      if (!mounted) return false;

      setState(() {
        _daoReview = review;
        _daoMessage = l10n.artistStudioReviewPendingInfo;
      });

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.artistStudioApplicationSubmittedToast)),
        tone: KubusSnackBarTone.success,
      );

      await _applyRoleSelection(
        isArtist: isArtist,
        isInstitution: isInstitution,
      );
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OnboardingFlowScreen._submitDaoApplication failed: $error');
      }
      if (!mounted) return false;
      final message = _extractBackendErrorMessage(
        error: error,
        fallback: l10n.daoProposalSubmitFailedToast,
      );
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(message)),
        tone: KubusSnackBarTone.error,
      );
      return false;
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> artist) async {
    final artistWallet = (artist['walletAddress'] ?? '').toString().trim();
    if (artistWallet.isEmpty || _isBusy) return;
    if (!_isSignedIn) {
      await _jumpToVerifyStep();
      return;
    }

    final wasFollowed = _followedArtists.contains(artistWallet);
    setState(() {
      _isBusy = true;
      if (wasFollowed) {
        _followedArtists.remove(artistWallet);
      } else {
        _followedArtists.add(artistWallet);
      }
    });
    try {
      final api = BackendApiService();
      if (wasFollowed) {
        await api.unfollowUser(artistWallet);
      } else {
        await api.followUser(artistWallet);
      }
      if (_followedArtists.isNotEmpty &&
          _steps.contains(_OnboardingStep.follow) &&
          !_completed.contains(_OnboardingStep.follow)) {
        await _markCompleted(_OnboardingStep.follow);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFollowed) {
          _followedArtists.add(artistWallet);
        } else {
          _followedArtists.remove(artistWallet);
        }
      });
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.onboardingFlowFollowFailed)),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _finishOnboarding() async {
    await _clearPendingVerificationSecret(clearEmail: true);
    await _persistLocalDrafts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);
    await OnboardingStateService.markCompleted(prefs: prefs);
    await _persistProgress();
    unawaited(TelemetryService()
        .trackOnboardingComplete(reason: 'step_flow_complete'));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/main');
  }

  Future<void> _skipForNow() async {
    if (_isSkippingFlow) return;
    _refreshAuthDerivedSteps();
    setState(() => _isSkippingFlow = true);

    try {
      await _clearPendingVerificationSecret(clearEmail: true);
      await _persistLocalDrafts();
      final prefs = await SharedPreferences.getInstance();
      await OnboardingStateService.markCompleted(prefs: prefs);
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
        await _markCompleted(_OnboardingStep.welcome);
        return;
      case _OnboardingStep.mapDiscovery:
        await _markCompleted(_OnboardingStep.mapDiscovery);
        return;
      case _OnboardingStep.community:
        await _markCompleted(_OnboardingStep.community);
        return;
      case _OnboardingStep.arScan:
        await _markCompleted(_OnboardingStep.arScan);
        return;
      case _OnboardingStep.daoGovernance:
        await _markCompleted(_OnboardingStep.daoGovernance);
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
      case _OnboardingStep.profile:
        if (_completed.contains(_OnboardingStep.profile)) {
          await _markCompleted(_OnboardingStep.profile);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.role:
        if (_completed.contains(_OnboardingStep.role)) {
          await _markCompleted(_OnboardingStep.role);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.permissions:
        await _markCompleted(_OnboardingStep.permissions);
        return;
      case _OnboardingStep.artwork:
        if (_completed.contains(_OnboardingStep.artwork)) {
          await _markCompleted(_OnboardingStep.artwork);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.follow:
        if (_followedArtists.isNotEmpty) {
          await _markCompleted(_OnboardingStep.follow);
        } else {
          await _deferCurrentStep();
        }
        return;
      case _OnboardingStep.done:
        await _finishOnboarding();
        return;
    }
  }

  String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.settingsThemeModeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeModeDark;
      case ThemeMode.system:
        return l10n.settingsThemeModeSystem;
    }
  }

  String _headerSkipLabel(AppLocalizations l10n) {
    return l10n.commonSkipForNow;
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    ColorScheme scheme, {
    required LocaleProvider localeProvider,
    required ThemeProvider themeProvider,
    bool compact = false,
  }) {
    final stepNumber = _currentIndex + 1;
    final headerCompact = compact && MediaQuery.sizeOf(context).height < 680;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isDesktop
            ? KubusSpacing.xxl
            : (headerCompact ? KubusSpacing.md : KubusSpacing.xl),
        headerCompact ? KubusSpacing.sm : KubusSpacing.lg,
        _isDesktop
            ? KubusSpacing.xxl
            : (headerCompact ? KubusSpacing.md : KubusSpacing.xl),
        headerCompact ? KubusSpacing.sm : KubusSpacing.md,
      ),
      child: AuthTitleRow(
        title: l10n.onboardingFlowTitle,
        icon: _stepIcon(_currentStep),
        compact: headerCompact,
        trailing: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isDesktop)
                Text(
                  l10n.commonStepOfTotal(stepNumber, _steps.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
              if (_isDesktop) const SizedBox(width: KubusSpacing.xs),
              PopupMenuButton<String>(
                onSelected: (value) {
                  unawaited(localeProvider.setLanguageCode(value));
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'sl',
                    child: Text(l10n.languageSlovenian),
                  ),
                  PopupMenuItem<String>(
                    value: 'en',
                    child: Text(l10n.languageEnglish),
                  ),
                ],
                child: const _HeaderActionPill(
                  icon: Icons.language,
                ),
              ),
              const SizedBox(width: KubusSpacing.xs),
              PopupMenuButton<ThemeMode>(
                onSelected: (mode) {
                  unawaited(themeProvider.setThemeMode(mode));
                },
                itemBuilder: (context) => [
                  PopupMenuItem<ThemeMode>(
                    value: ThemeMode.light,
                    child: Text(_themeModeLabel(l10n, ThemeMode.light)),
                  ),
                  PopupMenuItem<ThemeMode>(
                    value: ThemeMode.dark,
                    child: Text(_themeModeLabel(l10n, ThemeMode.dark)),
                  ),
                  PopupMenuItem<ThemeMode>(
                    value: ThemeMode.system,
                    child: Text(_themeModeLabel(l10n, ThemeMode.system)),
                  ),
                ],
                child: const _HeaderActionPill(
                  icon: Icons.brightness_6_outlined,
                ),
              ),
              const SizedBox(width: KubusSpacing.xs),
              TextButton(
                onPressed: _isSkippingFlow ? null : _skipForNow,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface.withValues(alpha: 0.84),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm,
                    vertical: KubusSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_headerSkipLabel(l10n)),
              ),
            ],
          ),
        ),
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
              margin:
                  EdgeInsets.only(right: index == _steps.length - 1 ? 0 : KubusSpacing.xs),
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: done
                    ? stepPalette.accent
                    : active
                        ? stepPalette.accent
                        : scheme.outline.withValues(alpha: 0.18),
                border: (active || done)
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.5,
                      )
                    : null,
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
        content = _WelcomeStep(
          title: l10n.onboardingFlowWelcomeTitle,
          body: l10n.onboardingFlowWelcomeBody,
        );
      case _OnboardingStep.mapDiscovery:
        content = _InfoStep(
          title: l10n.onboardingExploreTitle,
          body: l10n.onboardingExploreDescription,
          icon: Icons.map_outlined,
          start: palette.start,
          end: palette.end,
          permissionTitle: l10n.permissionsLocationTitle,
          permissionBody: l10n.permissionsLocationSubtitle,
          permissionEnabled: _locationEnabled,
          onRequestPermission: () => _requestPermission(Permission.location),
          hint: _hintForPermission(Permission.location),
        );
      case _OnboardingStep.community:
        content = _InfoStep(
          title: l10n.onboardingCommunityTitle,
          body: l10n.onboardingCommunityDescription,
          icon: Icons.groups_outlined,
          start: palette.start,
          end: palette.end,
          permissionTitle: l10n.permissionsNotificationsTitle,
          permissionBody: l10n.permissionsNotificationsSubtitle,
          permissionEnabled: _notificationEnabled,
          onRequestPermission: () =>
              _requestPermission(Permission.notification),
          hint: _hintForPermission(Permission.notification),
        );
      case _OnboardingStep.arScan:
        content = _InfoStep(
          title: l10n.permissionsCameraSubtitle,
          body: l10n.permissionsCameraDescription,
          icon: Icons.view_in_ar_outlined,
          start: palette.start,
          end: palette.end,
          permissionTitle: kIsWeb ? null : l10n.permissionsCameraTitle,
          permissionBody: kIsWeb ? null : l10n.permissionsCameraSubtitle,
          permissionEnabled: _cameraEnabled,
          onRequestPermission:
              kIsWeb ? null : () => _requestPermission(Permission.camera),
          hint: kIsWeb ? null : _hintForPermission(Permission.camera),
        );
      case _OnboardingStep.daoGovernance:
        content = _InfoStep(
          title: l10n.daoTreasuryTitle,
          body: l10n.daoTreasurySubtitle,
          icon: Icons.how_to_vote_outlined,
          start: palette.start,
          end: palette.end,
        );
      case _OnboardingStep.account:
        content = _AccountStep(
          title: l10n.onboardingFlowAccountTitle,
          body: l10n.onboardingFlowAccountBody,
          verifyHint: l10n.onboardingFlowAccountVerifyHint,
          onVerifyEmail: _jumpToVerifyStep,
          onAuthCompleted: _handleEmbeddedRegistrationSuccess,
          onEmailRegistrationAttempted: _handleEmbeddedEmailRegistrationAttempted,
          onEmailCredentialsCaptured: _handleEmbeddedEmailCredentialsCaptured,
          onVerificationRequired: _handleEmbeddedVerificationRequired,
        );
      case _OnboardingStep.profile:
        final user = Provider.of<ProfileProvider>(context, listen: false).currentUser;
        final yearsActive = user?.artistInfo?.yearsActive ?? 0;
        content = _InlineProfileStep(
          title: l10n.onboardingFlowProfileTitle,
          body: l10n.onboardingFlowProfileBody,
          persona: _selectedPersona,
          initialDisplayName:
              (user?.displayName ?? _localProfileDraft['displayName'] ?? ''),
          initialUsername:
              (user?.username ?? _localProfileDraft['username'] ?? ''),
          initialBio: (user?.bio ?? _localProfileDraft['bio'] ?? ''),
          initialAvatarUrl:
              (user?.avatar ?? _localProfileDraft['avatar'] ?? ''),
          initialTwitter:
              (user?.social['twitter'] ?? _localProfileDraft['twitter'] ?? ''),
          initialInstagram: (user?.social['instagram'] ??
              _localProfileDraft['instagram'] ??
              ''),
          initialWebsite:
              (user?.social['website'] ?? _localProfileDraft['website'] ?? ''),
          initialFieldOfWork: (user?.artistInfo?.specialty.join(', ') ??
              _localProfileDraft['fieldOfWork'] ??
              ''),
          initialYearsActive: yearsActive > 0
              ? yearsActive.toString()
              : (_localProfileDraft['yearsActive'] ?? ''),
          onSave: _saveInlineProfile,
          onAvatarStaged: _stageAvatarForLaterUpload,
        );
      case _OnboardingStep.role:
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
        final user = profileProvider.currentUser;
        content = _RoleStep(
          title: l10n.onboardingFlowRoleTitle,
          body: l10n.onboardingFlowRoleBody,
          artistSelected: user?.isArtist ?? (_selectedPersona == UserPersona.creator),
          institutionSelected:
              user?.isInstitution ?? (_selectedPersona == UserPersona.institution),
          selectedPersona: _selectedPersona ?? profileProvider.userPersona,
          onSelectPersona: _applyPersonaSelection,
          onSave: _applyRoleSelection,
          onApplyDao: _submitDaoApplication,
          daoMessage: _daoMessage,
          daoReview: _daoReview,
        );
      case _OnboardingStep.permissions:
        content = _PermissionsStep(
          title: 'Before we start...',
          body: l10n.onboardingFlowPermissionsBody,
          hint: _permissionHint,
          locationEnabled: _locationEnabled,
          notificationEnabled: _notificationEnabled,
          cameraEnabled: _cameraEnabled,
          onRequestLocation: () => _requestPermission(Permission.location),
          onRequestNotifications: () =>
              _requestPermission(Permission.notification),
          onRequestCamera: () => _requestPermission(Permission.camera),
        );
      case _OnboardingStep.artwork:
        if (_isSignedIn) {
          final user =
              Provider.of<ProfileProvider>(context, listen: false).currentUser;
          final wantsInstitution = user?.isInstitution == true;
          final wantsArtist = user?.isArtist == true || !wantsInstitution;
          final daoApproved = _isDaoApprovedForRole(
            isArtist: wantsArtist,
            isInstitution: wantsInstitution,
          );
          content = _ArtworkInlineStep(
            title: l10n.onboardingFlowArtworkTitle,
            body: l10n.onboardingFlowArtworkBody,
            draftId: _inlineArtworkDraftId,
            onCreated: () => unawaited(_markCompleted(_OnboardingStep.artwork)),
            institutionMode: wantsInstitution,
            forceDraftOnly: !daoApproved,
          );
        } else {
          content = _AuthRequiredStep(
            title: l10n.onboardingFlowArtworkTitle,
            body: l10n.onboardingFlowArtworkBody,
            onAuthSuccess: _handleEmbeddedSignInSuccess,
            onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
          );
        }
      case _OnboardingStep.follow:
        if (_isSignedIn) {
          content = _FollowStep(
            title: l10n.onboardingFlowFollowTitle,
            body: l10n.onboardingFlowFollowBody,
            artists: _artists,
            followedArtists: _followedArtists,
            isLoading: _isLoadingArtists,
            onToggleFollow: _toggleFollow,
          );
        } else {
          content = _AuthRequiredStep(
            title: l10n.onboardingFlowFollowTitle,
            body: l10n.onboardingFlowFollowBody,
            onAuthSuccess: _handleEmbeddedSignInSuccess,
            onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
          );
        }
      case _OnboardingStep.done:
        content = _DoneStep(
          title: l10n.onboardingFlowDoneTitle,
          body: l10n.onboardingFlowDoneBody,
        );
      case _OnboardingStep.verifyEmail:
        content = _VerifyEmailStep(
          title: l10n.onboardingFlowVerifyLastTitle,
          body: l10n.onboardingFlowVerifyLastBody,
          email: _pendingVerificationEmail,
          isVerified: _emailVerifiedConfirmed,
          isSignedIn: _isSignedIn,
          isRefreshingVerification:
              _verificationPollInFlight || _autoAdvancingVerification,
          onRefreshVerification: _handleManualVerificationRefresh,
          onAuthSuccess: _handleEmbeddedSignInSuccess,
          onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
        );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        color: scheme.surface.withValues(alpha: 0.16),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
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

  IconData _stepIcon(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return Icons.waving_hand_outlined;
      case _OnboardingStep.mapDiscovery:
        return Icons.map_outlined;
      case _OnboardingStep.community:
        return Icons.groups_outlined;
      case _OnboardingStep.arScan:
        return Icons.view_in_ar_outlined;
      case _OnboardingStep.daoGovernance:
        return Icons.how_to_vote_outlined;
      case _OnboardingStep.account:
        return Icons.person_add_alt_1_outlined;
      case _OnboardingStep.profile:
        return Icons.badge_outlined;
      case _OnboardingStep.role:
        return Icons.tune_outlined;
      case _OnboardingStep.permissions:
        return Icons.shield_outlined;
      case _OnboardingStep.artwork:
        return Icons.palette_outlined;
      case _OnboardingStep.follow:
        return Icons.group_add_outlined;
      case _OnboardingStep.verifyEmail:
        return Icons.mark_email_read_outlined;
      case _OnboardingStep.done:
        return Icons.rocket_launch_outlined;
    }
  }

  Widget _buildBottomActions(AppLocalizations l10n, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skipBackground = isDark
      ? scheme.surface.withValues(alpha: 0.86)
      : scheme.surface.withValues(alpha: 0.94);
    final skipForeground = isDark ? scheme.onSurface : scheme.onSurfaceVariant;
    final ctaBackground = isDark
      ? scheme.primary.withValues(alpha: 0.96)
      : scheme.primary.withValues(alpha: 0.98);
    final ctaForeground = scheme.onPrimary;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _currentIndex > 0 ? _goBackStep : null,
            style: TextButton.styleFrom(
              foregroundColor: skipForeground,
              backgroundColor: skipBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(
                vertical: compact ? 10 : 12,
              ),
            ),
            child: Text(l10n.commonBack),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: KubusButton(
            onPressed: _onPrimaryAction,
            label: _primaryLabelForStep(l10n),
            isFullWidth: true,
            backgroundColor: ctaBackground,
            foregroundColor: ctaForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStepRail(AppLocalizations l10n, ColorScheme scheme) {
    final labels = _steps.map((step) {
      switch (step) {
        case _OnboardingStep.mapDiscovery:
          return l10n.onboardingExploreTitle;
        case _OnboardingStep.community:
          return l10n.onboardingCommunityTitle;
        case _OnboardingStep.arScan:
          return l10n.permissionsCameraSubtitle;
        case _OnboardingStep.daoGovernance:
          return l10n.daoTreasuryTitle;
        case _OnboardingStep.role:
          return l10n.onboardingFlowRoleTitle;
        case _OnboardingStep.profile:
          return l10n.onboardingFlowProfileTitle;
        case _OnboardingStep.account:
          return l10n.onboardingFlowAccountTitle;
        case _OnboardingStep.verifyEmail:
          return l10n.onboardingFlowVerifyLastTitle;
        case _OnboardingStep.permissions:
          return l10n.onboardingFlowPermissionsTitle;
        case _OnboardingStep.welcome:
          return l10n.onboardingFlowWelcomeTitle;
        case _OnboardingStep.artwork:
          return l10n.onboardingFlowArtworkTitle;
        case _OnboardingStep.follow:
          return l10n.onboardingFlowFollowTitle;
        case _OnboardingStep.done:
          return l10n.onboardingFlowDoneTitle;
      }
    }).toList(growable: false);

    return Container(
      key: const Key('onboarding_desktop_step_rail'),
      width: 260,
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
              separatorBuilder: (_, __) => const SizedBox(height: KubusSpacing.xs),
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
                        ? palette.accent.withValues(alpha: 0.26)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: isActive
                          ? palette.accent.withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.14),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final accent = themeProvider.accentColor;
    final stepPalette = _paletteForStep(_currentStep);

    final bgStart = stepPalette.start.withValues(alpha: 0.92);
    final bgEnd = stepPalette.end.withValues(alpha: 0.85);
    final bgMid = Color.lerp(bgStart, bgEnd, 0.45) ?? bgEnd;
    final bgAccent =
        Color.lerp(stepPalette.accent, accent, 0.3)?.withValues(alpha: 0.78) ??
            accent.withValues(alpha: 0.78);
    final isWidgetTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');

    if (_isInitializing) {
      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      return AnimatedGradientBackground(
        animate: !isWidgetTestBinding,
        colors: [bgStart, bgMid, bgEnd, bgStart],
        intensity: 0.48,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return AnimatedGradientBackground(
      animate: !isWidgetTestBinding,
      colors: [bgStart, bgMid, bgAccent, bgEnd, bgStart],
      intensity: 0.48,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardOpen = keyboardInset > 0;
              final compactHeight = !_isDesktop && constraints.maxHeight < 760;
              final compactLayout = keyboardOpen || compactHeight;
              final hideProgress =
                  !_isDesktop && constraints.maxHeight < 700 && keyboardOpen;

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: Padding(
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
                              localeProvider: localeProvider,
                              themeProvider: themeProvider,
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
                              child: _isDesktop
                                  ? _buildDesktopContent(l10n, scheme)
                                  : _buildStepCard(l10n, scheme),
                            ),
                            SizedBox(
                              height: compactLayout
                                  ? KubusSpacing.sm
                                  : KubusSpacing.md,
                            ),
                            _buildBottomActions(l10n, compact: compactLayout),
                          ],
                        ),
                      ),
                    ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _primaryLabelForStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case _OnboardingStep.mapDiscovery:
      case _OnboardingStep.community:
      case _OnboardingStep.arScan:
      case _OnboardingStep.daoGovernance:
      case _OnboardingStep.account:
      case _OnboardingStep.profile:
      case _OnboardingStep.permissions:
      case _OnboardingStep.artwork:
      case _OnboardingStep.follow:
      case _OnboardingStep.role:
      case _OnboardingStep.welcome:
        return l10n.commonContinue;
      case _OnboardingStep.verifyEmail:
        return l10n.onboardingFlowVerifyContinue;
      case _OnboardingStep.done:
        return l10n.commonGetStarted;
    }
  }
}

class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.20);
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.34);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.title,
    required this.body,
    required this.verifyHint,
    required this.onVerifyEmail,
    required this.onAuthCompleted,
    required this.onEmailRegistrationAttempted,
    required this.onEmailCredentialsCaptured,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String verifyHint;
  final Future<void> Function() onVerifyEmail;
  final Future<void> Function() onAuthCompleted;
  final Future<void> Function(String email) onEmailRegistrationAttempted;
  final Future<void> Function(String email, String password)
      onEmailCredentialsCaptured;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 22 : null,
                  ),
            ),
            SizedBox(height: compact ? KubusSpacing.xs : KubusSpacing.sm),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
            if (!compact) ...[
              const SizedBox(height: KubusSpacing.xs),
              Text(
                verifyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
              ),
            ],
            SizedBox(height: compact ? KubusSpacing.xs : 10),
            Expanded(
              child: AuthMethodsPanel(
                embedded: true,
                onAuthSuccess: onAuthCompleted,
                prepareProvisionalProfileBeforeRegister: false,
                onEmailRegistrationAttempted: (email) =>
                    unawaited(onEmailRegistrationAttempted(email)),
                onEmailCredentialsCaptured: (email, password) async {
                  await onEmailCredentialsCaptured(email, password);
                },
                onVerificationRequired: onVerificationRequired,
                onSwitchToSignIn: onVerifyEmail,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 400;
        final tight = constraints.maxHeight < 220;
        final isWide = constraints.maxWidth > 500;
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              alignment: Alignment.topLeft,
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact) ...[
                      Center(
                        child: GradientIconCard(
                          start: const Color(0xFF006064),
                          end: const Color(0xFF26A69A),
                          icon: Icons.waving_hand_outlined,
                          iconSize: isWide ? 36 : 28,
                          width: isWide ? 72 : 56,
                          height: isWide ? 72 : 56,
                          radius: isWide ? 18 : 14,
                        ),
                      ),
                      SizedBox(height: isWide ? KubusSpacing.md : 10),
                    ],
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 22 : (isWide ? 28 : null),
                              ),
                    ),
                    SizedBox(height: compact ? KubusSpacing.xs : 6),
                    Text(
                      body,
                      maxLines: tight ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.8),
                          ),
                    ),
                    if (!tight) ...[
                      SizedBox(height: compact ? KubusSpacing.sm : 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF26A69A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                        ),
                        child: Text(
                          l10n.onboardingFlowWelcomeInfoTime,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF80CBC4),
                                  ),
                        ),
                      ),
                      SizedBox(height: compact ? KubusSpacing.sm : 12),
                      _WelcomeInfoRow(
                        icon: Icons.person_add_alt_1_outlined,
                        text: l10n.onboardingFlowWelcomeInfoAccount,
                      ),
                      _WelcomeInfoRow(
                        icon: Icons.palette_outlined,
                        text: l10n.onboardingFlowWelcomeInfoCreate,
                      ),
                      if (!compact) ...[
                        _WelcomeInfoRow(
                          icon: Icons.group_add_outlined,
                          text: l10n.onboardingFlowWelcomeInfoFollow,
                        ),
                        _WelcomeInfoRow(
                          icon: Icons.shield_outlined,
                          text: l10n.onboardingFlowPermissionsTitle,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeInfoRow extends StatelessWidget {
  const _WelcomeInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xFF26A69A).withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF80CBC4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.title,
    required this.body,
    required this.icon,
    required this.start,
    required this.end,
    this.permissionTitle,
    this.permissionBody,
    this.permissionEnabled = false,
    this.permissionUnsupportedMessage,
    this.onRequestPermission,
    this.hint,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color start;
  final Color end;
  final String? permissionTitle;
  final String? permissionBody;
  final bool permissionEnabled;
  final String? permissionUnsupportedMessage;
  final Future<void> Function()? onRequestPermission;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasPermissionPrompt =
        (permissionTitle ?? '').trim().isNotEmpty &&
            (permissionBody ?? '').trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 430;
        final tight = constraints.maxHeight < 350;
        final isWide = constraints.maxWidth > 520;

        final iconCardSize = tight ? 68.0 : (compact ? 82.0 : 96.0);
        final iconSize = tight ? 30.0 : (compact ? 36.0 : 42.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!tight) ...[
              Center(
                child: GradientIconCard(
                  start: start,
                  end: end,
                  icon: icon,
                  iconSize: iconSize,
                  width: iconCardSize,
                  height: iconCardSize,
                  radius: KubusRadius.lg,
                ),
              ),
              SizedBox(height: compact ? KubusSpacing.sm : KubusSpacing.md),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 22 : (isWide ? 28 : null),
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compact ? KubusSpacing.xs : KubusSpacing.sm),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.84),
                    height: 1.35,
                    fontSize: compact ? 14 : null,
                  ),
              maxLines: tight ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasPermissionPrompt) ...[
              SizedBox(height: compact ? KubusSpacing.sm : KubusSpacing.md),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? KubusSpacing.sm : KubusSpacing.md,
                  vertical: compact ? KubusSpacing.sm : KubusSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permissionTitle!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      onRequestPermission == null
                          ? (permissionUnsupportedMessage ?? permissionBody!)
                          : permissionBody!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.76),
                            height: 1.25,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    if (permissionEnabled)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: KubusSpacing.xs),
                          Text(
                            l10n.permissionsGrantedLabel,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      )
                    else if (onRequestPermission != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onRequestPermission,
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurface,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.sm,
                              vertical: KubusSpacing.xs,
                            ),
                          ),
                          child: Text(l10n.commonEnable),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if ((hint ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.xs),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
              ),
            ],
            const Spacer(),
          ],
        );
      },
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
  final bool isRefreshingVerification;
  final Future<void> Function() onRefreshVerification;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    final normalizedEmail = (email ?? '').trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 260 && !isSignedIn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: KubusSpacing.sm),
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: KubusSpacing.sm),
              Text(
                AppLocalizations.of(context)!.commonSignIn,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
            ],
          );
        }
        return _InlineVerificationPanel(
          title: title,
          body: body,
          email: normalizedEmail,
          isVerified: isVerified,
          isSignedIn: isSignedIn,
          isRefreshingVerification: isRefreshingVerification,
          onRefreshVerification: onRefreshVerification,
          onAuthSuccess: onAuthSuccess,
          onVerificationRequired: onVerificationRequired,
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
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(widget.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        if (widget.email.isNotEmpty)
          Text(
            '${AppLocalizations.of(context)!.commonEmail}: ${widget.email}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isVerified
                ? Colors.green.withValues(alpha: 0.16)
                : scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isVerified
                  ? Colors.green.withValues(alpha: 0.5)
                  : scheme.outline.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isVerified
                    ? Icons.check_circle_outline
                    : Icons.mark_email_unread_outlined,
                size: 18,
                color: widget.isVerified ? Colors.green : scheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isVerified
                      ? AppLocalizations.of(context)!.authVerifyEmailStatusVerified
                      : AppLocalizations.of(context)!.authVerifyEmailStatusPending,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.isVerified
                            ? Colors.green
                            : scheme.onSurface.withValues(alpha: 0.85),
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KubusButton(
          onPressed: _sending || widget.email.isEmpty ? null : _resend,
          isLoading: _sending,
          label: AppLocalizations.of(context)!.authVerifyEmailResendButton,
          isFullWidth: true,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        const SizedBox(height: KubusSpacing.sm),
        KubusButton(
          onPressed: widget.isRefreshingVerification || widget.email.isEmpty
              ? null
              : () => unawaited(widget.onRefreshVerification()),
          isLoading: widget.isRefreshingVerification,
          label: AppLocalizations.of(context)!.onboardingFlowVerifyContinue,
          isFullWidth: true,
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
        ),
        if ((_inlineMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _inlineMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
        ],
        const Spacer(),
      ],
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
    required this.initialTwitter,
    required this.initialInstagram,
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
  final String initialTwitter;
  final String initialInstagram;
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
    required String twitter,
    required String instagram,
    required String website,
    required List<String> fieldOfWork,
    required int? yearsActive,
  }) onSave;

  @override
  State<_InlineProfileStep> createState() => _InlineProfileStepState();
}

class _InlineProfileStepState extends State<_InlineProfileStep> {
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _twitter;
  late final TextEditingController _instagram;
  late final TextEditingController _website;
  late final TextEditingController _fieldOfWork;
  late final TextEditingController _yearsActive;
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
    _twitter = TextEditingController(text: widget.initialTwitter);
    _instagram = TextEditingController(text: widget.initialInstagram);
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
    _twitter.dispose();
    _instagram.dispose();
    _website.dispose();
    _fieldOfWork.dispose();
    _yearsActive.dispose();
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

  int? _parseYearsActive() {
    final raw = _yearsActive.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return -1;
    return parsed;
  }

  Future<void> _save() async {
    if (_saving) return;
    final yearsActive = _parseYearsActive();
    if (yearsActive == -1) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        const SnackBar(content: Text('Years active must be a valid number.')),
        tone: KubusSnackBarTone.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        displayName: _displayName.text,
        username: _username.text,
        bio: _bio.text,
        avatar: _avatarUrl,
        twitter: _twitter.text,
        instagram: _instagram.text,
        website: _website.text,
        fieldOfWork: _fieldOfWork.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        yearsActive: yearsActive,
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
    final persona = widget.persona;
    final creatorSelected = persona == UserPersona.creator;
    final institutionSelected = persona == UserPersona.institution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(widget.body, style: Theme.of(context).textTheme.bodyLarge),
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
                        onPressed: (_saving || _uploadingAvatar) ? null : _pickAvatar,
                        icon: _uploadingAvatar
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                        label: Text(_uploadingAvatar ? 'Selecting...' : l10n.commonUpload),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: _displayName,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: l10n.desktopSettingsDisplayNameLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _username,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: l10n.desktopSettingsUsernameLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bio,
                  minLines: 2,
                  maxLines: 4,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    labelText: l10n.desktopSettingsBioLabel,
                  ),
                ),
                if (creatorSelected) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _twitter,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(labelText: 'Twitter'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instagram,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: const InputDecoration(labelText: 'Instagram'),
                  ),
                ],
                if (creatorSelected || institutionSelected) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _website,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.desktopSettingsWebsiteLabel,
                    ),
                  ),
                ],
                if (creatorSelected) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fieldOfWork,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.profileFieldOfWorkLabel,
                      hintText: 'Painting, AR, Photography',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _yearsActive,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: l10n.profileYearsActiveLabel,
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

class _RoleStep extends StatefulWidget {
  const _RoleStep({
    required this.title,
    required this.body,
    required this.artistSelected,
    required this.institutionSelected,
    required this.selectedPersona,
    required this.onSelectPersona,
    required this.onSave,
    required this.onApplyDao,
    required this.daoReview,
    required this.daoMessage,
  });

  final String title;
  final String body;
  final bool artistSelected;
  final bool institutionSelected;
  final UserPersona? selectedPersona;
  final Map<String, dynamic>? daoReview;
  final String? daoMessage;
  final Future<void> Function(UserPersona persona) onSelectPersona;
  final Future<void> Function({
    required bool isArtist,
    required bool isInstitution,
  }) onSave;
  final Future<bool> Function({
    required bool isArtist,
    required bool isInstitution,
    required String portfolioUrl,
    required String medium,
    required String statement,
  }) onApplyDao;

  @override
  State<_RoleStep> createState() => _RoleStepState();
}

class _RoleStepState extends State<_RoleStep> {
  late bool _artist;
  late bool _institution;
  UserPersona? _selectedPersona;
  bool _saving = false;
  final TextEditingController _portfolioController = TextEditingController();
  final TextEditingController _mediumController = TextEditingController();
  final TextEditingController _statementController = TextEditingController();
  bool _submittingDao = false;

  @override
  void initState() {
    super.initState();
    _artist = widget.artistSelected;
    _institution = widget.institutionSelected;
    _selectedPersona = widget.selectedPersona;
    if (_selectedPersona == UserPersona.creator) {
      _artist = true;
      _institution = false;
    } else if (_selectedPersona == UserPersona.institution) {
      _artist = false;
      _institution = true;
    } else if (_selectedPersona == UserPersona.lover) {
      _artist = false;
      _institution = false;
    }
  }

  @override
  void dispose() {
    _portfolioController.dispose();
    _mediumController.dispose();
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        isArtist: _artist,
        isInstitution: _institution,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _applyDao() async {
    if (_submittingDao) return;
    final l10n = AppLocalizations.of(context)!;
    final portfolio = _portfolioController.text.trim();
    final medium = _mediumController.text.trim();
    final statement = _statementController.text.trim();
    if (portfolio.isEmpty || medium.isEmpty || statement.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.daoProposalFillRequiredFieldsToast)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    setState(() => _submittingDao = true);
    try {
      await widget.onApplyDao(
        isArtist: _artist,
        isInstitution: _institution,
        portfolioUrl: portfolio,
        medium: medium,
        statement: statement,
      );
    } finally {
      if (mounted) {
        setState(() => _submittingDao = false);
      }
    }
  }

  Future<void> _selectPersona(UserPersona persona) async {
    setState(() {
      _selectedPersona = persona;
      _artist = persona == UserPersona.creator;
      _institution = persona == UserPersona.institution;
    });
    await widget.onSelectPersona(persona);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(widget.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        UserPersonaPickerContent(
          selectedPersona: _selectedPersona,
          onSelect: _selectPersona,
        ),
        if (_artist || _institution) ...[
          const SizedBox(height: KubusSpacing.md),
          Text(
            'DAO review (optional for now)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          TextField(
            controller: _portfolioController,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: 'Portfolio URL'),
          ),
          const SizedBox(height: KubusSpacing.sm),
          TextField(
            controller: _mediumController,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: 'Primary medium'),
          ),
          const SizedBox(height: KubusSpacing.sm),
          TextField(
            controller: _statementController,
            minLines: 2,
            maxLines: 4,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: 'DAO statement'),
          ),
          const SizedBox(height: KubusSpacing.sm),
          KubusButton(
            onPressed: _submittingDao ? null : _applyDao,
            isLoading: _submittingDao,
            label: 'Apply for DAO review',
            isFullWidth: true,
          ),
          if ((widget.daoMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              widget.daoMessage!.trim(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        const Spacer(),
        KubusButton(
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          label: l10n.commonSave,
          isFullWidth: true,
        ),
      ],
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({
    required this.title,
    required this.body,
    required this.hint,
    required this.locationEnabled,
    required this.notificationEnabled,
    required this.cameraEnabled,
    required this.onRequestLocation,
    required this.onRequestNotifications,
    required this.onRequestCamera,
  });

  final String title;
  final String body;
  final String? hint;
  final bool locationEnabled;
  final bool notificationEnabled;
  final bool cameraEnabled;
  final Future<void> Function() onRequestLocation;
  final Future<void> Function() onRequestNotifications;
  final Future<void> Function() onRequestCamera;

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
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        _PermissionTile(
          label: l10n.onboardingFlowPermissionLocation,
          enabled: locationEnabled,
          onTap: onRequestLocation,
        ),
        _PermissionTile(
          label: l10n.onboardingFlowPermissionNotifications,
          enabled: notificationEnabled,
          onTap: onRequestNotifications,
        ),
        _PermissionTile(
          label: l10n.onboardingFlowPermissionCamera,
          enabled: cameraEnabled,
          onTap: onRequestCamera,
        ),
        if ((hint ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall,
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
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: enabled
          ? Icon(Icons.check_circle, color: scheme.primary)
          : TextButton(
              onPressed: onTap,
              child: Text(AppLocalizations.of(context)!.commonEnable),
            ),
    );
  }
}

class _ArtworkInlineStep extends StatelessWidget {
  const _ArtworkInlineStep({
    required this.title,
    required this.body,
    required this.draftId,
    required this.onCreated,
    required this.institutionMode,
    required this.forceDraftOnly,
  });

  final String title;
  final String body;
  final String draftId;
  final VoidCallback onCreated;
  final bool institutionMode;
  final bool forceDraftOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          forceDraftOnly
              ? '$body\n\nDraft-only mode is enabled until DAO approval.'
              : body,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: institutionMode
              ? ExhibitionCreatorScreen(
                  embedded: true,
                  forceDraftOnly: forceDraftOnly,
                  onCreated: onCreated,
                )
              : ArtworkCreator(
                  draftId: draftId,
                  embedded: true,
                  showAppBar: false,
                  onCreated: onCreated,
                  forceDraftOnly: forceDraftOnly,
                ),
        ),
      ],
    );
  }
}

class _AuthRequiredStep extends StatelessWidget {
  const _AuthRequiredStep({
    required this.title,
    required this.body,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < 260) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    AppLocalizations.of(context)!.commonSignIn,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return SignInScreen(
                embedded: true,
                onAuthSuccess: onAuthSuccess,
                onVerificationRequired: onVerificationRequired,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FollowStep extends StatelessWidget {
  const _FollowStep({
    required this.title,
    required this.body,
    required this.artists,
    required this.followedArtists,
    required this.isLoading,
    required this.onToggleFollow,
  });

  final String title;
  final String body;
  final List<Map<String, dynamic>> artists;
  final Set<String> followedArtists;
  final bool isLoading;
  final Future<void> Function(Map<String, dynamic> artist) onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: KubusSpacing.sm),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (artists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
            child: Text(
              l10n.onboardingFlowNoSuggestions,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
            ),
          )
        else
          ...artists.map((artist) {
            final id = (artist['walletAddress'] ?? '').toString().trim();
            final name = (artist['displayName'] ??
                    artist['name'] ??
                    artist['username'] ??
                    '')
                .toString();
            final isFollowed = followedArtists.contains(id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text(name.isEmpty ? l10n.onboardingFlowUnknownArtist : name),
              subtitle: Text((artist['bio'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: OutlinedButton(
                onPressed: () => onToggleFollow(artist),
                child:
                    Text(isFollowed ? l10n.commonFollowing : l10n.commonFollow),
              ),
            );
          }),
        const Spacer(),
      ],
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
        final compact = constraints.maxHeight < 320;
        final isWide = constraints.maxWidth > 500;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact) ...[
              Center(
                child: GradientIconCard(
                  start: const Color(0xFFF57F17),
                  end: const Color(0xFFFFD54F),
                  icon: Icons.rocket_launch_outlined,
                  iconSize: isWide ? 36 : 28,
                  width: isWide ? 72 : 56,
                  height: isWide ? 72 : 56,
                  radius: isWide ? 18 : 14,
                ),
              ),
              SizedBox(height: isWide ? KubusSpacing.md : 10),
            ],
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isWide ? 28 : null,
                    )),
            const SizedBox(height: KubusSpacing.sm),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
          ],
        );
      },
    );
  }
}
