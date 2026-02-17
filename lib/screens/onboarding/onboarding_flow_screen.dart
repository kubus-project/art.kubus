import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/register_screen.dart';
import 'package:art_kubus/screens/auth/verify_email_screen.dart';
import 'package:art_kubus/screens/community/profile_edit_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/web3/artist/artwork_creator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
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
  done,
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

  bool get _isDesktop =>
      widget.forceDesktop || DesktopBreakpoints.isDesktop(context);

  _OnboardingStep get _currentStep => _steps[_currentIndex.clamp(0, _steps.length - 1)];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    _isSignedIn = Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
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
    _syncStepSideEffects();
  }

  List<_OnboardingStep> _buildSteps() {
    final steps = <_OnboardingStep>[
      _OnboardingStep.welcome,
      if (!_isSignedIn) _OnboardingStep.account,
      _OnboardingStep.profile,
      if (_isSignedIn) _OnboardingStep.role,
      _OnboardingStep.permissions,
      _OnboardingStep.artwork,
      _OnboardingStep.follow,
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
      final featured = await api.listArtists(featured: true, limit: 12, offset: 0);
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artists = const <Map<String, dynamic>>[];
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
    final signedInNow = Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
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
    if (_currentStep == _OnboardingStep.follow && _artists.isEmpty && !_isLoadingArtists) {
      unawaited(_loadArtists());
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    if (kIsWeb) return;
    final status = await permission.request();
    if (!mounted) return;
    setState(() {
      if (permission == Permission.location) {
        _locationEnabled = status.isGranted;
      } else if (permission == Permission.notification) {
        _notificationEnabled = status.isGranted;
      } else if (permission == Permission.camera) {
        _cameraEnabled = status.isGranted;
      }
    });
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

  Future<void> _openRegisterFromOnboarding() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted) return;
    _refreshAuthDerivedSteps();
    if (_isSignedIn) {
      await _markCompleted(_OnboardingStep.account);
    } else {
      setState(() {});
    }
  }

  Future<void> _openVerifyEmailFromOnboarding() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
    if (!mounted) return;
    _refreshAuthDerivedSteps();
    setState(() {});
  }

  Future<void> _applyRoleSelection({
    required bool isArtist,
    required bool isInstitution,
  }) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
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
    final artistId = (artist['id'] ?? artist['walletAddress'] ?? '').toString();
    if (artistId.isEmpty || _isBusy) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.onboardingFlowFollowFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markCompleted(prefs: prefs);
    await _persistProgress();
    unawaited(TelemetryService().trackOnboardingComplete(reason: 'step_flow_complete'));

    if (!mounted) return;
    final isSignedIn = Provider.of<ProfileProvider>(context, listen: false).isSignedIn;
    Navigator.of(context).pushReplacementNamed(isSignedIn ? '/main' : '/sign-in');
  }

  Future<void> _onPrimaryAction() async {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
        await _markCompleted(_OnboardingStep.welcome);
        return;
      case _OnboardingStep.account:
        await _openRegisterFromOnboarding();
        return;
      case _OnboardingStep.profile:
        await _saveProfileFromOnboarding();
        return;
      case _OnboardingStep.role:
        await _markCompleted(_OnboardingStep.role);
        return;
      case _OnboardingStep.permissions:
        await _markCompleted(_OnboardingStep.permissions);
        return;
      case _OnboardingStep.artwork:
        await _openArtworkCreator();
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
          final active = index == _currentIndex;
          final done = _completed.contains(step);
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 6),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: done
                    ? scheme.primary
                    : active
                        ? scheme.primary.withValues(alpha: 0.6)
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
          onCreateAccount: _openRegisterFromOnboarding,
          onVerifyEmail: _openVerifyEmailFromOnboarding,
        );
      case _OnboardingStep.profile:
        content = _ProfileStep(
          title: l10n.onboardingFlowProfileTitle,
          body: l10n.onboardingFlowProfileBody,
        );
      case _OnboardingStep.role:
        final user = Provider.of<ProfileProvider>(context, listen: false).currentUser;
        content = _RoleStep(
          title: l10n.onboardingFlowRoleTitle,
          body: l10n.onboardingFlowRoleBody,
          artistSelected: user?.isArtist ?? false,
          institutionSelected: user?.isInstitution ?? false,
          onSave: _applyRoleSelection,
        );
      case _OnboardingStep.permissions:
        content = _PermissionsStep(
          title: l10n.onboardingFlowPermissionsTitle,
          body: l10n.onboardingFlowPermissionsBody,
          locationEnabled: _locationEnabled,
          notificationEnabled: _notificationEnabled,
          cameraEnabled: _cameraEnabled,
          onRequestLocation: () => _requestPermission(Permission.location),
          onRequestNotifications: () => _requestPermission(Permission.notification),
          onRequestCamera: () => _requestPermission(Permission.camera),
        );
      case _OnboardingStep.artwork:
        content = _ArtworkStep(
          title: l10n.onboardingFlowArtworkTitle,
          body: l10n.onboardingFlowArtworkBody,
        );
      case _OnboardingStep.follow:
        content = _FollowStep(
          title: l10n.onboardingFlowFollowTitle,
          body: l10n.onboardingFlowFollowBody,
          artists: _artists,
          followedArtists: _followedArtists,
          isLoading: _isLoadingArtists,
          onToggleFollow: _toggleFollow,
        );
      case _OnboardingStep.done:
        content = _DoneStep(
          title: l10n.onboardingFlowDoneTitle,
          body: l10n.onboardingFlowDoneBody,
        );
    }

    return LiquidGlassPanel(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = Provider.of<ThemeProvider>(context).accentColor;

    final bgStart = scheme.primary.withValues(alpha: 0.50);
    final bgEnd = accent.withValues(alpha: 0.42);
    final bgMid = Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd;

    if (_isInitializing) {
      return AnimatedGradientBackground(
        colors: [bgStart, bgMid, bgEnd, bgStart],
        intensity: 0.20,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AnimatedGradientBackground(
      colors: [bgStart, bgMid, bgEnd, bgStart],
      intensity: 0.20,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidth,
                          minHeight: constraints.maxHeight - (keyboardInset > 0 ? 10 : 0),
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
                                    onPressed: _currentStep == _OnboardingStep.done
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
        return l10n.onboardingFlowOpenProfile;
      case _OnboardingStep.permissions:
        return l10n.onboardingFlowContinueWithoutPermissions;
      case _OnboardingStep.artwork:
        return l10n.onboardingFlowCreateArtwork;
      case _OnboardingStep.follow:
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
    required this.onCreateAccount,
    required this.onVerifyEmail,
  });

  final String title;
  final String body;
  final String verifyHint;
  final Future<void> Function() onCreateAccount;
  final Future<void> Function() onVerifyEmail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        KubusButton(
          onPressed: onCreateAccount,
          label: AppLocalizations.of(context)!.onboardingFlowCreateAccount,
          isFullWidth: true,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onVerifyEmail,
          child: Text(AppLocalizations.of(context)!.onboardingFlowOpenVerification),
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8))),
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
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
  });

  final String title;
  final String body;
  final bool artistSelected;
  final bool institutionSelected;
  final Future<void> Function({
    required bool isArtist,
    required bool isInstitution,
  }) onSave;

  @override
  State<_RoleStep> createState() => _RoleStepState();
}

class _RoleStepState extends State<_RoleStep> {
  late bool _artist;
  late bool _institution;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _artist = widget.artistSelected;
    _institution = widget.institutionSelected;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
        const Spacer(),
      ],
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({
    required this.title,
    required this.body,
    required this.locationEnabled,
    required this.notificationEnabled,
    required this.cameraEnabled,
    required this.onRequestLocation,
    required this.onRequestNotifications,
    required this.onRequestCamera,
  });

  final String title;
  final String body;
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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

class _ArtworkStep extends StatelessWidget {
  const _ArtworkStep({
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
            final id = (artist['id'] ?? artist['walletAddress'] ?? '').toString();
            final name = (artist['displayName'] ?? artist['name'] ?? artist['username'] ?? '').toString();
            final isFollowed = followedArtists.contains(id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(name.isEmpty ? l10n.onboardingFlowUnknownArtist : name),
              subtitle: Text((artist['bio'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: OutlinedButton(
                onPressed: () => onToggleFollow(artist),
                child: Text(isFollowed ? l10n.commonFollowing : l10n.commonFollow),
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
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
      ],
    );
  }
}
