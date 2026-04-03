import 'package:flutter/material.dart';

import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';

Future<Object?> showAuthWalletFlowSheet({
  required BuildContext context,
  required String telemetryAuthFlow,
  int initialStep = 0,
  String? requiredWalletAddress,
}) async {
  final isDesktop = DesktopBreakpoints.isDesktop(context);

  if (isDesktop) {
    return showKubusDialog<Object?>(
      context: context,
      builder: (dialogContext) => ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 780,
        ),
        child: ConnectWallet(
          embedded: true,
          initialStep: initialStep,
          telemetryAuthFlow: telemetryAuthFlow,
          requiredWalletAddress: requiredWalletAddress,
        ),
      ),
    );
  }

  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      final screenHeight = MediaQuery.sizeOf(sheetContext).height;
      final maxHeight = screenHeight * 0.92;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.sm,
          KubusSpacing.none,
          KubusSpacing.sm,
          KubusSpacing.sm,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ConnectWallet(
            embedded: true,
            initialStep: initialStep,
            telemetryAuthFlow: telemetryAuthFlow,
            requiredWalletAddress: requiredWalletAddress,
          ),
        ),
      );
    },
  );
}