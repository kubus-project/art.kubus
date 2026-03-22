import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import 'kubus_snackbar.dart';

class MobileShellExitScope extends StatefulWidget {
  const MobileShellExitScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MobileShellExitScope> createState() => _MobileShellExitScopeState();
}

class _MobileShellExitScopeState extends State<MobileShellExitScope> {
  static const Duration _exitWindow = Duration(seconds: 2);

  Timer? _exitTimer;
  bool _allowExit = false;

  @override
  void dispose() {
    _exitTimer?.cancel();
    _exitTimer = null;
    super.dispose();
  }

  void _handleBlockedExit() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    messenger.showKubusSnackBar(
      SnackBar(
        content: Text(l10n.appExitConfirmBackHint),
        duration: _exitWindow,
      ),
    );

    _exitTimer?.cancel();
    setState(() {
      _allowExit = true;
    });
    _exitTimer = Timer(_exitWindow, () {
      if (!mounted) return;
      setState(() {
        _allowExit = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBlockedExit();
      },
      child: widget.child,
    );
  }
}
