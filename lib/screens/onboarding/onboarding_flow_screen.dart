import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/register_screen.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/community/profile_edit_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/events/exhibition_creator_screen.dart';
import 'package:art_kubus/screens/web3/artist/artwork_creator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
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
  const OnboardingFlowScreen({super.key, this.forceDesktop = false});

  final bool forceDesktop;

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
          start: KubusColors.primary,
          end: KubusColors.accentTealDark,
          accent: KubusColors.primary,
        );
      case _OnboardingStep.account:
        return const _StepPalette(
          start: KubusColors.accentBlue,
          end: KubusColors.primaryVariantDark,
          accent: KubusColors.primaryVariantDark,
        );
      case _OnboardingStep.profile:
        return const _StepPalette(
          start: KubusColors.accentTealDark,
          end: KubusColors.success,
          accent: KubusColors.successDark,
        );
      case _OnboardingStep.role:
        return const _StepPalette(
          start: KubusColors.achievementGoldDark,
          end: KubusColors.accentOrangeDark,
          accent: KubusColors.accentOrangeDark,
        );
      case _OnboardingStep.permissions:
        return const _StepPalette(
          start: KubusColors.warningDark,
          end: KubusColors.accentOrangeDark,
          accent: KubusColors.warningDark,
        );
      case _OnboardingStep.artwork:
        return const _StepPalette(
          start: KubusColors.errorDark,
          end: KubusColors.accentOrangeDark,
          accent: KubusColors.errorDark,
        );
      case _OnboardingStep.follow:
        return const _StepPalette(
          start: KubusColors.accentTealLight,
          end: KubusColors.accentBlue,
          accent: KubusColors.accentBlue,
        );
      case _OnboardingStep.verifyEmail:
        return const _StepPalette(
          start: KubusColors.success,
          end: KubusColors.successDark,
          accent: KubusColors.successDark,
        );
      case _OnboardingStep.done:
        return const _StepPalette(
          start: KubusColors.achievementGoldLight,
          end: KubusColors.primary,
          accent: KubusColors.primaryVariantDark,
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
      if (!_isSignedIn || (_pendingVerificationEmail ?? '').trim().isNotEmpty)
        _OnboardingStep.verifyEmail,
      _OnboardingStep.done,
    ];
    return steps;
  }

  Future<void> _loadPermissionStatuses() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _locationEnabled = true;
        _notificationEnabled = true;
        _cameraEnabled = true;
      });
      return;
    }

    try {
      final location = await Permission.location.status;
      final notifications = await Permission.notification.status;
      final camera = await Permission.camera.status;
      if (!mounted) return;
      setState(() {
        _locationEnabled = location.isGranted;
        _notificationEnabled = notifications.isGranted;
        _cameraEnabled = camera.isGranted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationEnabled = false;
        _notificationEnabled = false;
        _cameraEnabled = false;
      });
    }
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
        final id = (artist['id'] ?? artist['walletAddress'] ?? '').toString();
        if (id.isEmpty) continue;
        merged[id] = artist;
      }
      if (!mounted) return;
      setState(() {
        _artists = merged.values.take(6).toList(growable: false);
        if (_artists.isEmpty) {
          _artists = _fallbackArtists();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artists = _fallbackArtists();
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
    if (signedInNow == _isSignedIn && _steps.isNotEmpty) {
      return;
    }

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
      (s) => !_completed.contains(s) && s != step,
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
    if (kIsWeb) return;
    final status = await permission.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _loadPermissionStatuses();
    if (!mounted) return;
    setState(() {
      if (permission == Permission.location) {
        _locationEnabled = status.isGranted;
        _permissionHint =
            status.isGranted ? null : 'Location permission still disabled';
      } else if (permission == Permission.notification) {
        _notificationEnabled = status.isGranted;
        _permissionHint =
            status.isGranted ? null : 'Notifications permission still disabled';
      } else if (permission == Permission.camera) {
        _cameraEnabled = status.isGranted;
        _permissionHint =
            status.isGranted ? null : 'Camera permission still disabled';
      }
    });
  }

  List<Map<String, dynamic>> _fallbackArtists() {
    return const <Map<String, dynamic>>[
      {
        'id': 'curator_kubus_1',
        'displayName': 'Kubus Curated Artist',
        'bio': 'Featured by the Kubus community.',
      },
      {
        'id': 'curator_kubus_2',
        'displayName': 'AR Studio Collective',
        'bio': 'Immersive artworks and city interventions.',
      },
      {
        'id': 'curator_kubus_3',
        'displayName': 'Digital Monument Lab',
        'bio': 'Public-space AR and on-chain editions.',
      },
    ];
  }

  Future<void> _saveProfileFromOnboarding() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => const ProfileEditScreen(isOnboarding: true),
      ),
    );

    if (!mounted) return;
    await _markCompleted(_OnboardingStep.profile);
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
    _pendingVerificationEmail = null;
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
    _pendingVerificationEmail = email.trim();
    _refreshAuthDerivedSteps();
    if (!mounted) return;
    await _markCompleted(_OnboardingStep.account);
  }

  Future<void> _handleEmbeddedSignInSuccess(
      Map<String, dynamic> payload) async {
    _pendingVerificationEmail = null;
    _refreshAuthDerivedSteps();
    await _refreshDaoReview();
    if (!mounted) return;
    setState(() {
      _currentIndex = _nextIncompleteIndex();
    });
  }

  Future<void> _jumpToVerifyStep() async {
    final target = _steps.indexOf(_OnboardingStep.verifyEmail);
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

  Future<void> _openArtworkCreator() async {
    final navigator = Navigator.of(context);
    final draftId = 'onboarding_${DateTime.now().microsecondsSinceEpoch}';
    await navigator.push(
      MaterialPageRoute(builder: (_) => ArtworkCreator(draftId: draftId)),
    );

    if (!mounted) return;
    await _markCompleted(_OnboardingStep.artwork);
  }

  Future<void> _toggleFollow(Map<String, dynamic> artist) async {
    final artistId = (artist['walletAddress'] ?? artist['id'] ?? '').toString();
    if (artistId.isEmpty || _isBusy) return;
    if (!_isSignedIn) {
      await _jumpToVerifyStep();
      return;
    }

    setState(() => _isBusy = true);
    try {
      final api = BackendApiService();
      if (_followedArtists.contains(artistId)) {
        await api.unfollowUser(artistId);
        _followedArtists.remove(artistId);
      } else {
        await api.followUser(artistId);
        _followedArtists.add(artistId);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_followedArtists.contains(artistId)) {
          _followedArtists.remove(artistId);
        } else {
          _followedArtists.add(artistId);
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
    final isSignedIn =
        Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
    if (!isSignedIn) {
      final verifyIndex = _steps.indexOf(_OnboardingStep.verifyEmail);
      if (!mounted) return;
      setState(() {
        if (verifyIndex >= 0) {
          _currentIndex = verifyIndex;
        }
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markCompleted(prefs: prefs);
    await _persistProgress();
    unawaited(TelemetryService()
        .trackOnboardingComplete(reason: 'step_flow_complete'));

    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(isSignedIn ? '/main' : '/sign-in');
  }

  Future<void> _onPrimaryAction() async {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
        await _markCompleted(_OnboardingStep.welcome);
        return;
      case _OnboardingStep.account:
        return;
      case _OnboardingStep.verifyEmail:
        if (!_isSignedIn) {
          await _jumpToVerifyStep();
          return;
        }
        if (_steps.contains(_OnboardingStep.verifyEmail)) {
          await _markCompleted(_OnboardingStep.verifyEmail);
        }
        return;
      case _OnboardingStep.profile:
        await _markCompleted(_OnboardingStep.profile);
        return;
      case _OnboardingStep.role:
        await _markCompleted(_OnboardingStep.role);
        return;
      case _OnboardingStep.permissions:
        await _markCompleted(_OnboardingStep.permissions);
        return;
      case _OnboardingStep.artwork:
        await _markCompleted(_OnboardingStep.artwork);
        return;
      case _OnboardingStep.follow:
        await _markCompleted(_OnboardingStep.follow);
        return;
      case _OnboardingStep.done:
        await _finishOnboarding();
        return;
    }
  }

  Widget _buildHeader(AppLocalizations l10n, ColorScheme scheme) {
    final stepNumber = _currentIndex + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          const AppLogo(width: 34, height: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.onboardingFlowTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
          ),
          Text(
            l10n.commonStepOfTotal(stepNumber, _steps.length),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
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
              margin:
                  EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: done
                    ? stepPalette.accent
                    : active
                        ? stepPalette.accent.withValues(alpha: 0.7)
                        : scheme.outline.withValues(alpha: 0.25),
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
          );
        }
      case _OnboardingStep.role:
        if (_isSignedIn) {
          final user =
              Provider.of<ProfileProvider>(context, listen: false).currentUser;
          content = _RoleStep(
            title: l10n.onboardingFlowRoleTitle,
            body: l10n.onboardingFlowRoleBody,
            artistSelected: user?.isArtist ?? false,
            institutionSelected: user?.isInstitution ?? false,
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
        );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.start.withValues(alpha: 0.28),
            palette.end.withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.42),
          width: 1.3,
        ),
      ),
      child: LiquidGlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [palette.start, palette.end],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = Provider.of<ThemeProvider>(context).accentColor;
    final stepPalette = _paletteForStep(_currentStep);

    final bgStart = stepPalette.start.withValues(alpha: 0.78);
    final bgEnd = stepPalette.end.withValues(alpha: 0.68);
    final bgMid = Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd;
    final bgAccent =
        Color.lerp(stepPalette.accent, accent, 0.45)?.withValues(alpha: 0.56) ??
            accent.withValues(alpha: 0.56);

    if (_isInitializing) {
      return AnimatedGradientBackground(
        colors: [bgStart, bgMid, bgEnd, bgStart],
        intensity: 0.34,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AnimatedGradientBackground(
      colors: [bgStart, bgMid, bgAccent, bgEnd, bgStart],
      intensity: 0.34,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: (_) {
            final focusScope = FocusScope.of(context);
            if (!focusScope.hasPrimaryFocus &&
                focusScope.focusedChild != null) {
              focusScope.unfocus();
            }
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                final horizontalPadding = _isDesktop ? 48.0 : 16.0;
                final maxWidth = _isDesktop ? 860.0 : 560.0;

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 10 : 0),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidth,
                          minHeight: constraints.maxHeight -
                              (keyboardInset > 0 ? 10 : 0),
                        ),
                        child: Column(
                          children: [
                            _buildHeader(l10n, scheme),
                            const SizedBox(height: 8),
                            _buildProgress(scheme),
                            const SizedBox(height: 14),
                            Expanded(child: _buildStepCard(l10n, scheme)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed:
                                        _currentStep == _OnboardingStep.done
                                            ? null
                                            : _deferCurrentStep,
                                    child: Text(l10n.commonSkip),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: KubusButton(
                                    onPressed: _onPrimaryAction,
                                    label: _primaryLabelForStep(l10n),
                                    isFullWidth: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
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
        return l10n.onboardingFlowContinueWithoutPermissions;
      case _OnboardingStep.artwork:
        return l10n.commonContinue;
      case _OnboardingStep.follow:
        return l10n.commonContinue;
      case _OnboardingStep.verifyEmail:
        return l10n.commonContinue;
      case _OnboardingStep.role:
        return l10n.commonContinue;
      case _OnboardingStep.done:
        return l10n.commonGetStarted;
      case _OnboardingStep.welcome:
        return l10n.commonContinue;
    }
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
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Expanded(
          child: RegisterScreen(
            embedded: true,
            onAuthCompleted: onAuthCompleted,
            onVerificationRequired: (email) => onVerificationRequired(email),
            onSwitchToSignIn: onVerifyEmail,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onVerifyEmail,
          child: Text(
              AppLocalizations.of(context)!.onboardingFlowOpenVerification),
        ),
        const SizedBox(height: 2),
        Text(
          verifyHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
        const Spacer(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 16),
        _WelcomeInfoRow(
          icon: Icons.person_add_alt_1_outlined,
          text: AppLocalizations.of(context)!.onboardingFlowWelcomeInfoAccount,
        ),
        _WelcomeInfoRow(
          icon: Icons.palette_outlined,
          text: AppLocalizations.of(context)!.onboardingFlowWelcomeInfoCreate,
        ),
        _WelcomeInfoRow(
          icon: Icons.group_outlined,
          text: AppLocalizations.of(context)!.onboardingFlowWelcomeInfoFollow,
        ),
        _WelcomeInfoRow(
          icon: Icons.timer_outlined,
          text: AppLocalizations.of(context)!.onboardingFlowWelcomeInfoTime,
        ),
        const Spacer(),
      ],
    );
  }
}

class _WelcomeInfoRow extends StatelessWidget {
  const _WelcomeInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.85),
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
  });

  final String title;
  final String body;
  final String? email;
  final bool isSignedIn;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;

  @override
  Widget build(BuildContext context) {
    final normalizedEmail = (email ?? '').trim();
    return _InlineVerificationPanel(
      title: title,
      body: body,
      email: normalizedEmail,
      isSignedIn: isSignedIn,
      onAuthSuccess: onAuthSuccess,
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
  });

  final String title;
  final String body;
  final String email;
  final bool isSignedIn;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;

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
        const SizedBox(height: 8),
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
            ),
          ),
        ],
        if ((_inlineMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
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

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

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
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
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
        const SizedBox(height: 8),
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
    required this.onSave,
    required this.onApplyDao,
    required this.daoReview,
    required this.daoMessage,
  });

  final String title;
  final String body;
  final bool artistSelected;
  final bool institutionSelected;
  final Map<String, dynamic>? daoReview;
  final String? daoMessage;
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
        const SizedBox(height: 8),
        Text(widget.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        TextField(
          controller: _mediumController,
          decoration: const InputDecoration(labelText: 'Primary medium'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _statementController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'DAO statement'),
        ),
        const SizedBox(height: 8),
        KubusButton(
          onPressed: _submittingDao ? null : _applyDao,
          isLoading: _submittingDao,
          label: 'Apply for DAO review',
          isFullWidth: true,
        ),
        if ((widget.daoMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
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
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
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
  });

  final String title;
  final String body;
  final Future<void> Function(Map<String, dynamic>) onAuthSuccess;

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
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Expanded(
          child: SignInScreen(
            embedded: true,
            onAuthSuccess: onAuthSuccess,
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
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (artists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.onboardingFlowNoSuggestions,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
            ),
          )
        else
          ...artists.map((artist) {
            final id =
                (artist['id'] ?? artist['walletAddress'] ?? '').toString();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
      ],
    );
  }
}
