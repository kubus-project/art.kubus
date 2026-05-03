import 'package:flutter/material.dart';

import 'auth_redirect_controller.dart';
import '../widgets/auth/post_auth_loading_screen.dart';

class AuthSuccessHandoffService {
  const AuthSuccessHandoffService();

  /// For non-embedded auth flows, push the post-auth loading screen.
  /// For embedded flows, the widget (SignInScreen/AuthMethodsPanel) handles
  /// showing a visible loading surface by tracking local state.
  ///
  /// This ensures auth UI never remains visible while post-auth work runs.
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
    Future<void> Function(Map<String, dynamic> payload)? onAuthSuccess,
  }) async {
    // For non-embedded flows, always push a visible loading screen.
    // The loading screen will run the coordinator and handle routing.
    if (!embedded) {
      if (!isMounted()) return;
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
            onBeforeSavedItemsSync: onBeforeSavedItemsSync,
            onAuthSuccess: onAuthSuccess,
          ),
          settings: const RouteSettings(name: '/post-auth-loading'),
        ),
      );
      return;
    }

    // For embedded flows, the widget will handle showing inline loading.
    // This method does nothing; the widget is responsible for rendering
    // the loading surface based on local state.
  }
}