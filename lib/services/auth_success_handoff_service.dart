import 'package:flutter/material.dart';

import 'auth_redirect_controller.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import '../widgets/auth/post_auth_loading_screen.dart';
import 'post_auth_coordinator.dart';

class AuthSuccessHandoffService {
  const AuthSuccessHandoffService();

  Future<void> handle({
    required NavigatorState navigator,
    required bool Function() isMounted,
    required double screenWidth,
    required Map<String, dynamic> payload,
    required AuthOrigin origin,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    required bool embedded,
    required bool modalReauth,
    required bool requiresWalletBackup,
    Future<void> Function()? onBeforeSavedItemsSync,
    Future<void> Function(Map<String, dynamic> payload)? onInlineCompleted,
  }) async {
    if (!embedded && onInlineCompleted == null) {
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PostAuthLoadingScreen(
            payload: payload,
            origin: origin,
            redirectRoute: redirectRoute,
            redirectArguments: redirectArguments,
            walletAddress: walletAddress,
            userId: userId,
            embedded: embedded,
            modalReauth: modalReauth,
            requiresWalletBackup: requiresWalletBackup,
          ),
          settings: const RouteSettings(name: '/post-auth-loading'),
        ),
      );
      return;
    }

    final currentContext = navigator.context;
    final result = await const PostAuthCoordinator().complete(
      context: currentContext,
      origin: origin,
      payload: payload,
      redirectRoute: redirectRoute,
      redirectArguments: redirectArguments,
      walletAddress: walletAddress,
      userId: userId,
      embedded: embedded,
      modalReauth: modalReauth,
      requiresWalletBackup: requiresWalletBackup,
      onBeforeSavedItemsSync: onBeforeSavedItemsSync,
      onStageChanged: (_) {},
    );

    if (!isMounted() || !result.completed) {
      return;
    }

    if (onInlineCompleted != null) {
      await onInlineCompleted(payload);
      return;
    }

    await _routeToResult(navigator, screenWidth, result);
  }

  Future<void> _routeToResult(
    NavigatorState navigator,
    double screenWidth,
    PostAuthResult result,
  ) async {
    if (result.onboardingStepId != null &&
        result.onboardingStepId!.isNotEmpty) {
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OnboardingFlowScreen(
            forceDesktop: screenWidth >= 1024,
            initialStepId: result.onboardingStepId,
          ),
          settings: const RouteSettings(name: '/onboarding'),
        ),
        (_) => false,
      );
      return;
    }

    final routeName = result.routeName ?? '/main';
    if (result.replaceStack) {
      await navigator.pushNamedAndRemoveUntil(
        routeName,
        (_) => false,
        arguments: result.arguments,
      );
    } else {
      await navigator.pushReplacementNamed(
        routeName,
        arguments: result.arguments,
      );
    }
  }
}