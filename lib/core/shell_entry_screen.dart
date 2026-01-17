import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main_app.dart';
import '../providers/main_tab_provider.dart';
import '../screens/desktop/desktop_shell.dart';

/// Entry wrapper for routes that must land inside the app shell, while still
/// allowing a semantically useful URL (e.g. `/map`).
class ShellEntryScreen extends StatefulWidget {
  const ShellEntryScreen({
    super.key,
    required this.mobileTabIndex,
    required this.desktopInitialIndex,
  });

  const ShellEntryScreen.map({super.key})
      : mobileTabIndex = 0,
        desktopInitialIndex = 1;

  final int mobileTabIndex;
  final int desktopInitialIndex;

  @override
  State<ShellEntryScreen> createState() => _ShellEntryScreenState();
}

class _ShellEntryScreenState extends State<ShellEntryScreen> {
  bool _didSeedTab = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedTab) return;
    _didSeedTab = true;

    if (DesktopBreakpoints.isDesktop(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MainTabProvider>().setIndex(widget.mobileTabIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopBreakpoints.isDesktop(context)) {
      return DesktopShell(initialIndex: widget.desktopInitialIndex);
    }
    return const MainApp();
  }
}
