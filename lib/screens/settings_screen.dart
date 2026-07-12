import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/inline_loading.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/glass_capabilities_provider.dart';
import '../utils/app_color_utils.dart';
import '../providers/notification_provider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/platform_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/security_gate_provider.dart';
import '../providers/email_preferences_provider.dart';
import '../providers/saved_items_provider.dart';
import '../models/email_preferences.dart';
import '../models/user_profile.dart';
import '../models/wallet.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import '../services/settings_service.dart';
import '../widgets/platform_aware_widgets.dart';
import '../widgets/common/keyboard_inset_padding.dart';
import '../widgets/glass_components.dart';
import '../widgets/wallet_custody_status_panel.dart';
import '../widgets/email_verification_status_badge.dart';
import '../widgets/common/kubus_screen_header.dart';
import '../widgets/detail/shared_section_widgets.dart';
import '../widgets/detail/shared_settings_widgets.dart';
import 'onboarding/onboarding_flow_screen.dart';
import 'web3/wallet/wallet_home.dart' as web3_wallet;
import 'web3/wallet/connectwallet_screen.dart';
import 'community/profile_edit_screen.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/support/support_ticket_dialog.dart';
import 'web3/wallet/wallet_backup_protection_screen.dart';
import '../utils/app_animations.dart';
import '../../config/config.dart';
import '../utils/map_performance_debug.dart';
import '../providers/locale_provider.dart';
import '../utils/wallet_backup_status.dart';
import '../utils/wallet_action_guard.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/utils/wallet_reconnect_action.dart';

part 'settings_screen_parts/settings_screen_p1.dart';
part 'settings_screen_parts/settings_screen_p2.dart';
part 'settings_screen_parts/settings_screen_p3.dart';
part 'settings_screen_parts/settings_screen_p4.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  /// setState shim for methods extracted into part-file extensions
  /// (State.setState is @protected and not callable from extensions).
  void _applyState(VoidCallback fn) => setState(fn);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _didAnimateEntrance = false;


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
    final isWidgetTestBinding = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    final animationTheme = AppAnimationTheme.defaults;
    _animationController = AnimationController(
      duration: animationTheme.long,
      vsync: this,
    );
    _configureAnimations(animationTheme);
    if (isWidgetTestBinding) {
      _didAnimateEntrance = true;
      _animationController.value = 1.0;
    }
    _loadAllSettings();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }
    _configureAnimations(animationTheme);
    if (!_didAnimateEntrance) {
      _didAnimateEntrance = true;
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(l10n),
                    SliverPadding(
                      padding: const EdgeInsets.all(KubusSpacing.lg),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUserSection(l10n),
                          const SizedBox(height: 32),
                          _buildThemeSection(l10n),
                          const SizedBox(height: 24),
                          _buildLanguageSection(l10n),
                          const SizedBox(height: 24),
                          _buildPlatformCapabilitiesSection(l10n),
                          const SizedBox(height: 24),
                          _buildProfileSection(l10n),
                          const SizedBox(height: 24),
                          _buildWalletSection(l10n),
                          const SizedBox(height: 24),
                          _buildSecuritySection(l10n),
                          const SizedBox(height: 24),
                          _buildPrivacySection(l10n),
                          const SizedBox(height: 24),
                          _buildAboutSection(l10n),
                          const SizedBox(height: 24),
                          _buildDangerZone(l10n),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }



































































}

class _ProfileVisibilityOption {
  final String value;
  final String label;
  final String description;

  const _ProfileVisibilityOption({
    required this.value,
    required this.label,
    required this.description,
  });
}
