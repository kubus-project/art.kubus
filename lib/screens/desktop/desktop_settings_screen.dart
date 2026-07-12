import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/glass_capabilities_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/platform_provider.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/email_preferences_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../models/email_preferences.dart';
import '../../models/achievement_progress.dart';
import '../../models/user_profile.dart';
import '../../services/achievement_service.dart' as achievement_svc;
import '../../services/backend_api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/common/kubus_stat_card.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/shared_section_widgets.dart';
import '../../widgets/detail/shared_settings_widgets.dart';
import '../../widgets/email_verification_status_badge.dart';
import '../../widgets/support/support_ticket_dialog.dart';
import '../../utils/achievement_ui.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import 'desktop_shell_scope.dart';
import '../web3/wallet/wallet_backup_protection_screen.dart';
import '../web3/achievements/achievements_page.dart';
import '../auth/secure_account_screen.dart';
import '../onboarding/onboarding_flow_screen.dart';
import '../../../config/config.dart';
import '../../providers/locale_provider.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/wallet_custody_status_panel.dart';
import '../../utils/design_tokens.dart';
import '../../utils/wallet_backup_status.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/utils/wallet_reconnect_action.dart';

part 'desktop_settings_screen_parts/desktop_settings_screen_p1.dart';
part 'desktop_settings_screen_parts/desktop_settings_screen_p2.dart';
part 'desktop_settings_screen_parts/desktop_settings_screen_p3.dart';
/// Desktop profile and settings screen
/// Clean dashboard layout with account info and settings
class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen>
    with TickerProviderStateMixin {
  /// setState shim for methods extracted into part-file extensions
  /// (State.setState is @protected and not callable from extensions).
  void _applyState(VoidCallback fn) => setState(fn);

  late AnimationController _animationController;
  late TabController _tabController;

  int _selectedSettingsIndex = 0;

  // Profile settings state
  String _profileVisibility = 'Public';

  // Privacy settings state
  bool _dataCollection = true;
  bool _personalizedAds = true;
  bool _locationTracking = true;
  String _dataRetention = '1 Year';

  // Security settings state
  bool _twoFactorAuth = false;
  bool _sessionTimeout = true;
  String _autoLockTime = '5 minutes';
  bool _loginNotifications = true;
  bool _requirePin = false;
  bool _biometricAuth = false;
  bool _biometricsDeclined = false;
  bool _useBiometricsOnUnlock = true;
  bool _privacyMode = false;
  bool _hasPin = false;
  bool _biometricsSupported = false;

  // Account settings state
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _marketingEmails = false;
  String _accountType = 'Standard';
  bool _publicProfile = true;

  // App settings state
  bool _analytics = true;
  bool _crashReporting = true;
  bool _skipOnboardingForReturningUsers = true;

  // Wallet settings state
  String _networkSelection = 'Mainnet';
  bool _autoBackup = true;
  WalletBackupStatusSnapshot _walletBackupStatus =
      const WalletBackupStatusSnapshot.noWallet();

  // Profile interaction settings
  bool _showAchievements = true;
  bool _showFriends = true;
  bool _allowMessages = true;
  bool _secureAccountHasEmail = false;
  bool _secureAccountHasPassword = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: 11, vsync: this);
    _animationController.forward();
    _loadSettings();
  }










  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final scheme = Theme.of(context).colorScheme;
    final sidebarStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.sidebarBackground,
      tintBase: scheme.surface,
    );
    final content = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: animationTheme.fadeCurve,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLarge)
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: LiquidGlassPanel(
                      padding: EdgeInsets.zero,
                      margin: EdgeInsets.zero,
                      borderRadius: BorderRadius.zero,
                      blurSigma: sidebarStyle.blurSigma,
                      fallbackMinOpacity: sidebarStyle.fallbackMinOpacity,
                      showBorder: false,
                      backgroundColor: sidebarStyle.tintColor,
                      child: _buildSettingsSidebar(themeProvider),
                    ),
                  ),
                ),
              Expanded(
                child: _buildMainContent(themeProvider, isLarge),
              ),
            ],
          ),
        );
      },
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: content,
    );

    if (widget.embeddedInShell) {
      return scaffold;
    }

    return AnimatedGradientBackground(child: scaffold);
  }














































}

class _SettingsItem {
  final String title;
  final IconData icon;
  final int index;

  _SettingsItem(this.title, this.icon, this.index);
}
