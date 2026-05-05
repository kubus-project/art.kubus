import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'onboarding_state_service.dart';

class StructuredOnboardingResumeState {
  const StructuredOnboardingResumeState({
    required this.requiresStructuredOnboarding,
    this.nextStepId,
  });

  final bool requiresStructuredOnboarding;
  final String? nextStepId;
}

class AuthOnboardingService {
  static const int onboardingFlowVersion = 5;

  static const List<String> accountStepIds = <String>[
    'account',
    'verifyEmail',
    'role',
    'profile',
    'walletBackupIntro',
    'walletBackup',
    'daoReview',
    'accountPermissions',
    'done',
  ];

  static const Set<String> _accountStepIdSet = <String>{
    'account',
    'verifyEmail',
    'role',
    'profile',
    'walletBackupIntro',
    'walletBackup',
    'daoReview',
    'accountPermissions',
    'done',
  };

  static bool payloadIndicatesNewAccount(Map<String, dynamic> payload) {
    final data = payload['data'];
    final envelope = data is Map<String, dynamic> ? data : payload;

    return _readBool(payload, 'isNewUser') ||
        _readBool(payload, 'needsOnboarding') ||
        _readBool(envelope, 'isNewUser') ||
        _readBool(envelope, 'needsOnboarding');
  }

  static bool isAccountStepId(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isNotEmpty && _accountStepIdSet.contains(normalized);
  }

  static Future<StructuredOnboardingResumeState>
      resolveStructuredOnboardingResume({
    required SharedPreferences prefs,
    required bool hasPendingAuthOnboarding,
    required bool hasAuthenticatedSession,
    required bool hasHydratedProfile,
    required bool requiresWalletBackup,
    required String? heuristicNextStepId,
    required String? persona,
    String? flowScopeKey,
    Map<String, dynamic>? payload,
  }) async {
    final payloadIsNewAccount =
        payload != null && payloadIndicatesNewAccount(payload);

    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: onboardingFlowVersion,
      flowScopeKey: flowScopeKey,
    );
    final completedSteps = progress.completedSteps
        .where(isAccountStepId)
        .map((step) => step.trim())
        .toSet();
    final deferredSteps = progress.deferredSteps
        .where(isAccountStepId)
        .map((step) => step.trim())
        .toSet();
    if (completedSteps.contains('walletBackup')) {
      completedSteps.add('walletBackupIntro');
    }
    if (deferredSteps.contains('walletBackup') &&
        !completedSteps.contains('walletBackupIntro')) {
      deferredSteps.add('walletBackupIntro');
    }
    final hasSavedProgress =
        completedSteps.isNotEmpty || deferredSteps.isNotEmpty;

    final walletBackupOnboardingEnabled =
        AppConfig.isFeatureEnabled('walletBackupOnboarding');
    String? normalizedHeuristic = isAccountStepId(heuristicNextStepId)
        ? heuristicNextStepId!.trim()
        : null;
    if (!walletBackupOnboardingEnabled &&
        normalizedHeuristic == 'walletBackup') {
      normalizedHeuristic = null;
    } else if (normalizedHeuristic == 'walletBackup' &&
        walletBackupOnboardingEnabled) {
      normalizedHeuristic = 'walletBackupIntro';
    }
    final normalizedPersona = (persona ?? '').trim().toLowerCase();
    final requiresWalletBackupStep = walletBackupOnboardingEnabled &&
        (completedSteps.contains('walletBackup') ||
            deferredSteps.contains('walletBackup') ||
            requiresWalletBackup);
    final allowRoleSpecificOnboarding =
        hasPendingAuthOnboarding || payloadIsNewAccount || hasSavedProgress;
    final explicitTrustedHeuristic = normalizedHeuristic != null &&
        (hasPendingAuthOnboarding || payloadIsNewAccount || hasSavedProgress);
    final shouldResume = hasPendingAuthOnboarding ||
        payloadIsNewAccount ||
        hasSavedProgress ||
        requiresWalletBackupStep ||
        explicitTrustedHeuristic;

    if (!shouldResume) {
      return const StructuredOnboardingResumeState(
        requiresStructuredOnboarding: false,
      );
    }

    final requiresDaoReview = allowRoleSpecificOnboarding &&
        (completedSteps.contains('daoReview') ||
            deferredSteps.contains('daoReview') ||
            normalizedPersona == 'creator' ||
            normalizedPersona == 'institution');
    final requiresVerifyEmail = completedSteps.contains('verifyEmail') ||
        deferredSteps.contains('verifyEmail');

    if (hasSavedProgress) {
      final nextStepId = _nextIncompleteStepId(
        hasAuthenticatedSession: hasAuthenticatedSession,
        requiresVerifyEmail: requiresVerifyEmail,
        requiresWalletBackup: requiresWalletBackupStep,
        requiresDaoReview: requiresDaoReview,
        completedSteps: completedSteps,
      );
      return StructuredOnboardingResumeState(
        requiresStructuredOnboarding: nextStepId != null,
        nextStepId: nextStepId,
      );
    }

    if (explicitTrustedHeuristic) {
      return StructuredOnboardingResumeState(
        requiresStructuredOnboarding: true,
        nextStepId: normalizedHeuristic,
      );
    }

    if (hasAuthenticatedSession && hasHydratedProfile) {
      final nextStepId = requiresWalletBackupStep
          ? 'walletBackupIntro'
          : (requiresDaoReview ? 'daoReview' : 'accountPermissions');
      return StructuredOnboardingResumeState(
        requiresStructuredOnboarding: true,
        nextStepId: nextStepId,
      );
    }

    return StructuredOnboardingResumeState(
      requiresStructuredOnboarding: true,
      nextStepId: hasAuthenticatedSession ? 'role' : 'account',
    );
  }

  static bool _readBool(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static String? _nextIncompleteStepId({
    required bool hasAuthenticatedSession,
    required bool requiresVerifyEmail,
    required bool requiresWalletBackup,
    required bool requiresDaoReview,
    required Set<String> completedSteps,
  }) {
    final orderedSteps = <String>[
      if (!hasAuthenticatedSession) 'account',
      if (requiresVerifyEmail) 'verifyEmail',
      'role',
      'profile',
      if (requiresWalletBackup) 'walletBackupIntro',
      if (requiresWalletBackup) 'walletBackup',
      if (requiresDaoReview) 'daoReview',
      'accountPermissions',
      'done',
    ];

    for (final step in orderedSteps) {
      if (!completedSteps.contains(step)) {
        return step;
      }
    }
    return null;
  }
}
