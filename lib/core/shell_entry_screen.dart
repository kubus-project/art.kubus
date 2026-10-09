import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main_app.dart';
import '../models/creator_workspace.dart';
import '../providers/main_tab_provider.dart';
import '../screens/desktop/desktop_shell.dart';
import '../utils/creator_workspace_navigation.dart';
import 'shell_routes.dart';

/// Entry wrapper for routes that must land inside the app shell, while still
/// allowing a semantically useful URL (e.g. `/map`).
class ShellEntryScreen extends StatefulWidget {
  const ShellEntryScreen({
    super.key,
    required this.mobileTabIndex,
    required this.desktopInitialIndex,
  }) : workspace = null;

  const ShellEntryScreen.map({super.key})
      : mobileTabIndex = 0,
        desktopInitialIndex = 1,
        workspace = null;

  const ShellEntryScreen.community({super.key})
      : mobileTabIndex = 2,
        desktopInitialIndex = 2,
        workspace = null;

  /// A creator workspace URL (`/artist-studio`, `/institution-hub`). On
  /// desktop the shell opens on the workspace; on a phone the workspace page
  /// opens above Home, so Back leaves the workspace for the shell.
  const ShellEntryScreen.workspace(CreatorWorkspace this.workspace, {super.key})
      : mobileTabIndex = 3,
        desktopInitialIndex = 0;

  final int mobileTabIndex;
  final int desktopInitialIndex;
  final CreatorWorkspace? workspace;

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
      final workspace = widget.workspace;
      if (workspace == null) return;
      // This entry route carries the workspace's name. Rename the shell
      // beneath the workspace to `/main` (without a transition) so that after
      // Back the address bar names the page that is showing, then open the
      // workspace as its own named page.
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        PageRouteBuilder<void>(
          settings: const RouteSettings(name: ShellRoutes.main),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const MainApp(),
        ),
      );
      navigator.push(CreatorWorkspaceNavigation.pageRoute(workspace));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopBreakpoints.isDesktop(context)) {
      return DesktopShell(
        initialIndex: widget.desktopInitialIndex,
        initialRoute: widget.workspace?.desktopShellRoute,
      );
    }
    return const MainApp();
  }
}
