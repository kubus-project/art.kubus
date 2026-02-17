import 'dart:async';

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
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/user_persona_picker_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OnboardingStep {
  welcome,
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

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  static const int _flowVersion = 2;

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
  String? _permissionHint;
  late final String _inlineArtworkDraftId;
  Map<String, dynamic>? _daoReview;
  String? _daoMessage;

  _StepPalette _paletteForStep(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return const _StepPalette(
          start: Color(0xFF006064),
          end: KubusColors.accentTealLight,
          accent: Color(0xFF26A69A),
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
          start: Color(0xFF6A1B9A),
          end: Color(0xFFAB47BC),
          accent: Color(0xFFCE93D8),
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
    _inlineArtworkDraftId =
        'onboarding_inline_${DateTime.now().microsecondsSinceEpoch}';
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    _isSignedIn =
        Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
    _steps = _buildSteps();

    final prefs = await SharedPreferences.getInstance();
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: _flowVersion,
    );

    if (!mounted) return;

    final completed = progress.completedSteps
        .map(_stepFromId)
        .whereType<_OnboardingStep>()
        .toSet();
    final deferred = progress.deferredSteps
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
    final steps = <_OnboardingStep>[
      _OnboardingStep.welcome,
      if (!_isSignedIn) _OnboardingStep.account,
      if (_isSignedIn) _OnboardingStep.profile,
      _OnboardingStep.role,
      _OnboardingStep.permissions,
      _OnboardingStep.artwork,
      _OnboardingStep.follow,
      if (_verificationRequired) _OnboardingStep.verifyEmail,
      _OnboardingStep.done,
    ];
    return steps;
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
    });
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
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress;
    if (wallet == null || wallet.trim().isEmpty) return;

    await profileProvider.saveProfile(
      walletAddress: wallet,
      displayName: displayName.trim().isEmpty ? null : displayName.trim(),
      username: username.trim().isEmpty ? null : username.trim(),
      bio: bio.trim().isEmpty ? null : bio.trim(),
    );

    if (!mounted) return;
    await _markCompleted(_OnboardingStep.profile);
  }

  Future<void> _handleEmbeddedRegistrationSuccess() async {
    // Keep pending verification email (if set) so the final verification step
    // remains visible even when auto-login succeeds after registration.
    _refreshAuthDerivedSteps();
    await _refreshDaoReview();
    if (!mounted) return;
    if (_steps.contains(_OnboardingStep.account)) {
      await _markCompleted(_OnboardingStep.account);
    } else {
      setState(() {});
    }
  }

  Future<void> _handleEmbeddedVerificationRequired(String email) async {
    await _setPendingVerificationAndRoute(
      email,
      completeAccountStep: true,
    );
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
    _pendingVerificationEmail = email.trim();
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
    if (pendingEmail.isNotEmpty &&
        (signedInEmail.isEmpty || signedInEmail == pendingEmail)) {
      _pendingVerificationEmail = null;
    } else if (pendingEmail.isEmpty) {
      _pendingVerificationEmail = null;
    }
    _refreshAuthDerivedSteps();
    await _refreshDaoReview();
    if (!mounted) return;
    await _markCompleted(_OnboardingStep.account);
  }

  Future<void> _confirmVerificationAndContinue() async {
    _refreshAuthDerivedSteps();
    if (!_isSignedIn) {
      await _jumpToVerifyStep();
      return;
    }
    if (_verificationRequired) {
      final refreshed = await BackendApiService().refreshAuthTokenFromStorage();
      _refreshAuthDerivedSteps();
      if (!_isSignedIn) return;
      if (refreshed) {
        _pendingVerificationEmail = null;
        _refreshAuthDerivedSteps();
      }
      if (_verificationRequired) return;
    }
    if (_steps.contains(_OnboardingStep.verifyEmail)) {
      await _markCompleted(_OnboardingStep.verifyEmail);
    } else if (mounted) {
      setState(() {
        _currentIndex = _nextIncompleteIndex();
      });
    }
  }

  Future<void> _jumpToVerifyStep() async {
    await _jumpToStepIfPresent(_OnboardingStep.verifyEmail);
  }

  Future<void> _jumpToStepIfPresent(_OnboardingStep step) async {
    final target = _steps.indexOf(step);
    if (target < 0 || !mounted) return;
    setState(() {
      _currentIndex = target;
    });
  }

  Future<void> _applyRoleSelection({
    required bool isArtist,
    required bool isInstitution,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.setRoleFlags(
      isArtist: isArtist,
      isInstitution: isInstitution,
    );
    final wallet = profileProvider.currentUser?.walletAddress;
    if (wallet != null && wallet.isNotEmpty) {
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
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.setUserPersona(persona);
    final isArtist = persona == UserPersona.creator;
    final isInstitution = persona == UserPersona.institution;
    await _applyRoleSelection(
      isArtist: isArtist,
      isInstitution: isInstitution,
    );
  }

  Future<void> _submitDaoApplication({
    required bool isArtist,
    required bool isInstitution,
    required String portfolioUrl,
    required String medium,
    required String statement,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final wallet = profileProvider.currentUser?.walletAddress ?? '';
    if (wallet.trim().isEmpty) return;

    await _applyRoleSelection(isArtist: isArtist, isInstitution: isInstitution);

    final review = await BackendApiService().submitDAOReview(
      walletAddress: wallet,
      portfolioUrl: portfolioUrl,
      medium: medium,
      statement: statement,
      title: isInstitution
          ? 'Institution onboarding application'
          : 'Artist onboarding application',
      metadata: <String, dynamic>{
        'isArtistApplication': isArtist,
        'isInstitutionApplication': isInstitution,
        'source': 'onboarding_flow',
      },
    );

    if (!mounted) return;
    setState(() {
      _daoReview = review ?? _daoReview;
      _daoMessage = review == null
          ? 'Could not submit DAO application right now. You can continue in draft mode.'
          : 'Application submitted. You can keep creating in draft mode until approval.';
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.onboardingFlowFollowFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _finishOnboarding() async {
    _refreshAuthDerivedSteps();
    if (_isSignedIn && _verificationRequired) {
      await _jumpToVerifyStep();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
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
      case _OnboardingStep.account:
        if (_isSignedIn) {
          await _markCompleted(_OnboardingStep.account);
        }
        return;
      case _OnboardingStep.verifyEmail:
        await _confirmVerificationAndContinue();
        return;
      case _OnboardingStep.profile:
        if (_completed.contains(_OnboardingStep.profile)) {
          await _markCompleted(_OnboardingStep.profile);
        }
        return;
      case _OnboardingStep.role:
        if (_completed.contains(_OnboardingStep.role)) {
          await _markCompleted(_OnboardingStep.role);
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
  }) {
    final stepNumber = _currentIndex + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KubusSpacing.md, 10, KubusSpacing.md, KubusSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _isDesktop ? 84 : 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTitleRow(
              title: l10n.onboardingFlowTitle,
              icon: _stepIcon(_currentStep),
              compact: !_isDesktop,
              trailing: Text(
                l10n.commonStepOfTotal(stepNumber, _steps.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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
                  child: _HeaderActionPill(
                    icon: Icons.language,
                    label: localeProvider.languageCode.toUpperCase(),
                  ),
                ),
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
                  child: _HeaderActionPill(
                    icon: Icons.brightness_6_outlined,
                    label: _themeModeLabel(l10n, themeProvider.themeMode),
                  ),
                ),
                TextButton(
                  onPressed: _isSkippingFlow ? null : _skipForNow,
                  child: Text(_headerSkipLabel(l10n)),
                ),
              ],
            ),
          ],
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
      case _OnboardingStep.account:
        content = _AccountStep(
          title: l10n.onboardingFlowAccountTitle,
          body: l10n.onboardingFlowAccountBody,
          verifyHint: l10n.onboardingFlowAccountVerifyHint,
          onVerifyEmail: _jumpToVerifyStep,
          onAuthCompleted: _handleEmbeddedRegistrationSuccess,
          onVerificationRequired: _handleEmbeddedVerificationRequired,
        );
      case _OnboardingStep.profile:
        if (_isSignedIn) {
          final user =
              Provider.of<ProfileProvider>(context, listen: false).currentUser;
          content = _InlineProfileStep(
            title: l10n.onboardingFlowProfileTitle,
            body: l10n.onboardingFlowProfileBody,
            initialDisplayName: user?.displayName ?? '',
            initialUsername: user?.username ?? '',
            initialBio: user?.bio ?? '',
            onSave: _saveInlineProfile,
          );
        } else {
          content = _AuthRequiredStep(
            title: l10n.onboardingFlowProfileTitle,
            body: l10n.onboardingFlowProfileBody,
            onAuthSuccess: _handleEmbeddedSignInSuccess,
            onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
          );
        }
      case _OnboardingStep.role:
        if (_isSignedIn) {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          final user = profileProvider.currentUser;
          content = _RoleStep(
            title: l10n.onboardingFlowRoleTitle,
            body: l10n.onboardingFlowRoleBody,
            artistSelected: user?.isArtist ?? false,
            institutionSelected: user?.isInstitution ?? false,
            selectedPersona: profileProvider.userPersona,
            onSelectPersona: _applyPersonaSelection,
            onSave: _applyRoleSelection,
            onApplyDao: _submitDaoApplication,
            daoMessage: _daoMessage,
            daoReview: _daoReview,
          );
        } else {
          content = _AuthRequiredStep(
            title: l10n.onboardingFlowRoleTitle,
            body: l10n.onboardingFlowRoleBody,
            onAuthSuccess: _handleEmbeddedSignInSuccess,
            onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
          );
        }
      case _OnboardingStep.permissions:
        content = _PermissionsStep(
          title: l10n.onboardingFlowPermissionsTitle,
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
          isSignedIn: _isSignedIn,
          onAuthSuccess: _handleEmbeddedSignInSuccess,
          onVerificationRequired: _handleEmbeddedSignInNeedsVerification,
        );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.start.withValues(alpha: 0.55),
            palette.end.withValues(alpha: 0.40),
          ],
        ),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: LiquidGlassPanel(
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        fallbackMinOpacity: 0.30,
        backgroundColor: palette.start.withValues(alpha: 0.12),
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
      ),
    );
  }

  IconData _stepIcon(_OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return Icons.waving_hand_outlined;
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

  String _stepLabel(AppLocalizations l10n, _OnboardingStep step) {
    switch (step) {
      case _OnboardingStep.welcome:
        return l10n.onboardingFlowWelcomeTitle;
      case _OnboardingStep.account:
        return l10n.onboardingFlowAccountTitle;
      case _OnboardingStep.profile:
        return l10n.onboardingFlowProfileTitle;
      case _OnboardingStep.role:
        return l10n.onboardingFlowRoleTitle;
      case _OnboardingStep.permissions:
        return l10n.onboardingFlowPermissionsTitle;
      case _OnboardingStep.artwork:
        return l10n.onboardingFlowArtworkTitle;
      case _OnboardingStep.follow:
        return l10n.onboardingFlowFollowTitle;
      case _OnboardingStep.verifyEmail:
        return l10n.onboardingFlowVerifyLastTitle;
      case _OnboardingStep.done:
        return l10n.onboardingFlowDoneTitle;
    }
  }

  Widget _buildDesktopStepRail(AppLocalizations l10n, ColorScheme scheme) {
    final activePalette = _paletteForStep(_currentStep);
    return LiquidGlassPanel(
      key: const Key('onboarding_desktop_step_rail'),
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(20),
      fallbackMinOpacity: 0.28,
      backgroundColor: activePalette.start.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GradientIconCard(
                start: activePalette.start,
                end: activePalette.end,
                icon: Icons.auto_awesome,
                iconSize: 18,
                width: 36,
                height: 36,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.onboardingFlowTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_steps.length, (index) {
            final step = _steps[index];
            final active = _currentIndex == index;
            final done = _completed.contains(step);
            final palette = _paletteForStep(step);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                color: active
                    ? palette.accent.withValues(alpha: 0.28)
                    : done
                        ? palette.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                border: Border.all(
                  color: active
                      ? palette.accent.withValues(alpha: 0.65)
                      : done
                          ? palette.accent.withValues(alpha: 0.35)
                          : scheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                      gradient: (active || done)
                          ? LinearGradient(
                              colors: [palette.start, palette.end],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: (active || done)
                          ? null
                          : scheme.outline.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : _stepIcon(step),
                      size: 15,
                      color: (active || done)
                          ? Colors.white
                          : scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _stepLabel(l10n, step),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: active
                                ? scheme.onSurface
                                : scheme.onSurface
                                    .withValues(alpha: done ? 0.75 : 0.55),
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(),
          if (_currentStep == _OnboardingStep.welcome) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: activePalette.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: activePalette.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: KubusSpacing.sm, vertical: KubusSpacing.xs),
                    decoration: BoxDecoration(
                      color: activePalette.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                    ),
                    child: Text(
                      l10n.onboardingFlowWelcomeInfoTime,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: activePalette.accent,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RailInfoItem(
                    icon: Icons.person_add_alt_1_outlined,
                    text: l10n.onboardingFlowWelcomeInfoAccount,
                    color: activePalette.accent,
                  ),
                  _RailInfoItem(
                    icon: Icons.palette_outlined,
                    text: l10n.onboardingFlowWelcomeInfoCreate,
                    color: activePalette.accent,
                  ),
                  _RailInfoItem(
                    icon: Icons.group_add_outlined,
                    text: l10n.onboardingFlowWelcomeInfoFollow,
                    color: activePalette.accent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n, {required bool compact}) {
    final palette = _paletteForStep(_currentStep);
    return LiquidGlassPanel(
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.fromLTRB(10, compact ? 8 : 10, 10, compact ? 8 : 10),
      fallbackMinOpacity: 0.28,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _currentStep == _OnboardingStep.done
                  ? null
                  : _deferCurrentStep,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.9),
              ),
              child: Text(l10n.commonSkip),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KubusButton(
              onPressed: _onPrimaryAction,
              label: _primaryLabelForStep(l10n),
              isFullWidth: true,
              backgroundColor: palette.accent,
              foregroundColor: _contrastForeground(palette.accent),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns white or dark foreground based on luminance of [bg].
  static Color _contrastForeground(Color bg) {
    return bg.computeLuminance() > 0.45
        ? const Color(0xFF0A0A0A)
        : Colors.white;
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
      return AnimatedGradientBackground(
        animate: !isWidgetTestBinding,
        colors: [bgStart, bgMid, bgEnd, bgStart],
        intensity: 0.48,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
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

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isDesktop ? KubusSpacing.lg : KubusSpacing.md,
                    vertical: 10,
                  ),
                  child: _isDesktop
                      ? Row(
                          children: [
                            SizedBox(
                              width: 320,
                              child: _buildDesktopStepRail(l10n, scheme),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildHeader(
                                    l10n,
                                    scheme,
                                    localeProvider: localeProvider,
                                    themeProvider: themeProvider,
                                  ),
                                  const SizedBox(height: KubusSpacing.sm),
                                  _buildProgress(scheme),
                                  const SizedBox(height: 10),
                                  Expanded(child: _buildStepCard(l10n, scheme)),
                                  const SizedBox(height: 10),
                                  _buildBottomActions(l10n,
                                      compact: keyboardOpen),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHeader(
                              l10n,
                              scheme,
                              localeProvider: localeProvider,
                              themeProvider: themeProvider,
                            ),
                            SizedBox(height: keyboardOpen ? KubusSpacing.xs : KubusSpacing.sm),
                            _buildProgress(scheme),
                            SizedBox(height: keyboardOpen ? KubusSpacing.sm : 12),
                            Expanded(child: _buildStepCard(l10n, scheme)),
                            const SizedBox(height: KubusSpacing.sm),
                            _buildBottomActions(l10n, compact: keyboardOpen),
                          ],
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
      case _OnboardingStep.account:
        return l10n.onboardingFlowCreateAccount;
      case _OnboardingStep.profile:
        return l10n.commonContinue;
      case _OnboardingStep.permissions:
        return l10n.commonContinue;
      case _OnboardingStep.artwork:
        return l10n.commonContinue;
      case _OnboardingStep.follow:
        return l10n.commonContinue;
      case _OnboardingStep.verifyEmail:
        return l10n.onboardingFlowVerifyContinue;
      case _OnboardingStep.role:
        return l10n.commonContinue;
      case _OnboardingStep.done:
        return l10n.commonGetStarted;
      case _OnboardingStep.welcome:
        return l10n.commonContinue;
    }
  }
}

class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: KubusSpacing.xxs),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _RailInfoItem extends StatelessWidget {
  const _RailInfoItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String verifyHint;
  final Future<void> Function() onVerifyEmail;
  final Future<void> Function() onAuthCompleted;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: KubusSpacing.xs),
        Text(
          verifyHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AuthMethodsPanel(
            embedded: true,
            onAuthSuccess: onAuthCompleted,
            onVerificationRequired: onVerificationRequired,
            onSwitchToSignIn: onVerifyEmail,
          ),
        ),
      ],
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

class _VerifyEmailStep extends StatelessWidget {
  const _VerifyEmailStep({
    required this.title,
    required this.body,
    required this.email,
    required this.isSignedIn,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String? email;
  final bool isSignedIn;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;
  final Future<void> Function(String email) onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    final normalizedEmail = (email ?? '').trim();
    return _InlineVerificationPanel(
      title: title,
      body: body,
      email: normalizedEmail,
      isSignedIn: isSignedIn,
      onAuthSuccess: onAuthSuccess,
      onVerificationRequired: onVerificationRequired,
    );
  }
}

class _InlineVerificationPanel extends StatefulWidget {
  const _InlineVerificationPanel({
    required this.title,
    required this.body,
    required this.email,
    required this.isSignedIn,
    required this.onAuthSuccess,
    required this.onVerificationRequired,
  });

  final String title;
  final String body;
  final String email;
  final bool isSignedIn;
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
        OutlinedButton.icon(
          onPressed: _sending || widget.email.isEmpty ? null : _resend,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_read_outlined),
          label:
              Text(AppLocalizations.of(context)!.authVerifyEmailResendButton),
        ),
        if (!widget.isSignedIn) ...[
          const SizedBox(height: 12),
          Expanded(
            child: SignInScreen(
              embedded: true,
              initialEmail: widget.email,
              onAuthSuccess: widget.onAuthSuccess,
              onVerificationRequired: widget.onVerificationRequired,
            ),
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
        const Spacer(),
      ],
    );
  }
}

class _InlineProfileStep extends StatefulWidget {
  const _InlineProfileStep({
    required this.title,
    required this.body,
    required this.initialDisplayName,
    required this.initialUsername,
    required this.initialBio,
    required this.onSave,
  });

  final String title;
  final String body;
  final String initialDisplayName;
  final String initialUsername;
  final String initialBio;
  final Future<void> Function({
    required String displayName,
    required String username,
    required String bio,
  }) onSave;

  @override
  State<_InlineProfileStep> createState() => _InlineProfileStepState();
}

class _InlineProfileStepState extends State<_InlineProfileStep> {
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.initialDisplayName);
    _username = TextEditingController(text: widget.initialUsername);
    _bio = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        displayName: _displayName.text,
        username: _username.text,
        bio: _bio.text,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        TextField(
          controller: _displayName,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!
                  .desktopSettingsDisplayNameLabel),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _username,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.commonUsernameOptional),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bio,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.desktopSettingsBioLabel),
        ),
        const SizedBox(height: 10),
        KubusButton(
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          label: AppLocalizations.of(context)!.commonSave,
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
  final Future<void> Function({
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
    final portfolio = _portfolioController.text.trim();
    final medium = _mediumController.text.trim();
    final statement = _statementController.text.trim();
    if (portfolio.isEmpty || medium.isEmpty || statement.isEmpty) return;

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
        const SizedBox(height: 10),
        SwitchListTile(
          title: Text(l10n.settingsRoleArtistTitle),
          subtitle: Text(l10n.settingsRoleArtistSubtitle),
          value: _artist,
          onChanged: (value) => setState(() => _artist = value),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: Text(l10n.settingsRoleInstitutionTitle),
          subtitle: Text(l10n.settingsRoleInstitutionSubtitle),
          value: _institution,
          onChanged: (value) => setState(() => _institution = value),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        KubusButton(
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          label: l10n.commonSave,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _portfolioController,
          decoration: const InputDecoration(labelText: 'Portfolio URL'),
        ),
        const SizedBox(height: KubusSpacing.sm),
        TextField(
          controller: _mediumController,
          decoration: const InputDecoration(labelText: 'Primary medium'),
        ),
        const SizedBox(height: KubusSpacing.sm),
        TextField(
          controller: _statementController,
          minLines: 2,
          maxLines: 4,
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
          Text(widget.daoMessage!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (widget.daoReview != null) ...[
          const SizedBox(height: 6),
          Text(
            'DAO status: ${(widget.daoReview!['status'] ?? 'pending').toString()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
          child: SignInScreen(
            embedded: true,
            onAuthSuccess: onAuthSuccess,
            onVerificationRequired: onVerificationRequired,
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
