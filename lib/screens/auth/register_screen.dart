import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../main_app.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/web3provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../widgets/google_sign_in_button.dart';
import '../web3/wallet/connectwallet_screen.dart';
import 'sign_in_screen.dart';
import '../desktop/auth/desktop_auth_shell.dart';
import '../desktop/desktop_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    String? walletAddress = user['walletAddress'] ?? user['wallet_address'];
    final usernameFromUser = (user['username'] ?? _usernameController.text ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(), desiredUsername: usernameFromUser);
    } catch (e) {
      debugPrint('RegisterScreen: wallet provisioning failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setBool('completed_onboarding', true);
    await prefs.setBool('first_time', false);
    if (walletAddress != null && walletAddress.toString().isNotEmpty) {
      await prefs.setString('wallet_address', walletAddress.toString());
      await prefs.setString('wallet', walletAddress.toString());
      await prefs.setString('walletAddress', walletAddress.toString());
      await prefs.setBool('has_wallet', true);
    }
    if (userId != null && userId.toString().isNotEmpty) {
      await prefs.setString('user_id', userId.toString());
    }
    if (!mounted) return;
    try {
      if (walletAddress != null && walletAddress.toString().isNotEmpty) {
        await Provider.of<ProfileProvider>(context, listen: false)
            .loadProfile(walletAddress.toString())
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('RegisterScreen: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authAccountCreatedProfileLoading)),
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp()));
  }

  Future<void> _registerWithEmail() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authEmailRegistrationDisabled)));
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();
    if (email.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authEnterValidEmailPassword)));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final api = BackendApiService();
      final result = await api.registerWithEmail(
        email: email,
        password: password,
        username: username.isNotEmpty ? username : null,
      );
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authRegistrationFailed)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet, {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final sanitizedExisting = existingWallet?.trim();
    String? address = walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    if (address == null || address.isEmpty) {
      if (sanitizedExisting != null && sanitizedExisting.isNotEmpty) {
        address = sanitizedExisting;
      }
    }

    if (address != null && address.isNotEmpty) {
      if ((walletProvider.currentWalletAddress ?? '').isEmpty) {
        try {
          await walletProvider.connectWalletWithAddress(address);
        } catch (e) {
          debugPrint('RegisterScreen: connectWalletWithAddress failed: $e');
        }
      }
      try {
        if (!web3Provider.isConnected || web3Provider.walletAddress != address) {
          await web3Provider.connectExistingWallet(address);
        }
      } catch (e) {
        debugPrint('RegisterScreen: connectExistingWallet failed: $e');
      }
      return address;
    }

    try {
      final result = await walletProvider.createWallet();
      final mnemonic = result['mnemonic']!;
      address = result['address']!;
      createdFreshWallet = true;
      try {
        await web3Provider.importWallet(mnemonic);
      } catch (e) {
        debugPrint('RegisterScreen: web3 import failed: $e');
      }
      try {
        await BackendApiService().issueTokenForWallet(address);
      } catch (e) {
        debugPrint('RegisterScreen: issueTokenForWallet failed: $e');
      }
    } catch (e) {
      debugPrint('RegisterScreen: wallet creation failed: $e');
    }

    if (address != null && address.isNotEmpty && createdFreshWallet) {
      await _upsertProfileWithUsername(address, desiredUsername);
    }

    return address;
  }

  Future<void> _upsertProfileWithUsername(String address, String? desiredUsername) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final effectiveUsername = (desiredUsername ?? '').isNotEmpty ? desiredUsername : null;
    try {
      await profileProvider.createProfileFromWallet(walletAddress: address, username: effectiveUsername);
    } catch (e) {
      debugPrint('RegisterScreen: createProfileFromWallet failed: $e');
    }
    if (effectiveUsername != null && effectiveUsername.isNotEmpty) {
      try {
        await BackendApiService().updateProfile(address, {
          'username': effectiveUsername,
          'displayName': effectiveUsername,
        });
      } catch (err) {
        debugPrint('RegisterScreen: updateProfile username patch failed: $err');
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableGoogleAuth) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authGoogleSignInDisabled)));
      return;
    }
    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      final api = BackendApiService();
      final result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        email: googleResult.email,
        username: googleResult.displayName,
      );
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authGoogleSignInFailed)));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  void _showConnectWalletModal() {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;
    if (isDesktop) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 0)));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(sheetL10n.authConnectWalletModalTitle, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                const SizedBox(height: 6),
                Text(sheetL10n.authConnectWalletModalDescriptionRegister, style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 16),
                const SizedBox(height: 8),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionWalletConnect, Icons.qr_code_2_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 3)));
                }),
                const SizedBox(height: 8),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionOtherWallets, Icons.apps_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 0)));
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _walletOptionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon, color: colorScheme.primary, size: 22),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final form = _buildRegisterForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      isDesktop: isDesktop,
    );

    if (isDesktop) {
      return DesktopAuthShell(
        title: l10n.authRegisterTitle,
        subtitle: l10n.authRegisterSubtitle,
        highlights: [
          l10n.authHighlightOnboardingOptions,
          l10n.authHighlightKeysLocal,
          l10n.authHighlightOptionalWeb3,
        ],
        icon: GradientIconCard(
          start: const Color(0xFFF59E0B),
          end: const Color(0xFFEF4444),
          icon: Icons.person_add_alt_rounded,
          iconSize: 48,
          width: 96,
          height: 96,
          radius: 18,
        ),
        gradientStart: const Color(0xFFF59E0B),
        gradientEnd: const Color(0xFFEF4444),
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignInScreen())),
            child: Text(
              l10n.authHaveAccountSignIn,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppLogo(width: 48, height: 48),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignInScreen())),
                        child: Text(l10n.authHaveAccountSignIn, style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  form,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
    required bool isDesktop,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                GradientIconCard(
                  start: const Color(0xFFF59E0B),
                  end: const Color(0xFFEF4444),
                  icon: Icons.person_add_alt_rounded,
                  iconSize: 48,
                  width: 96,
                  height: 96,
                  radius: 18,
                ),
                const SizedBox(height: 12),
                Text(l10n.authRegisterTitle, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  l10n.authSignInSubtitle,
                  style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.85)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (!isDesktop) const SizedBox(height: 20),
        if (enableWallet)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _showConnectWalletModal,
            icon: Icon(Icons.account_balance_wallet_outlined, size: 24, color: colorScheme.onPrimary),
            label: Text(l10n.authConnectWalletButton, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onPrimary)),
          ),
        if (enableWallet) const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(l10n.authOrUseEmail, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
              const SizedBox(height: 12),
              if (enableEmail) _buildEmailForm(colorScheme),
              if (enableGoogle) ...[
                const SizedBox(height: 12),
                GoogleSignInButton(
                  onPressed: _registerWithGoogle,
                  isLoading: _isGoogleSubmitting,
                  colorScheme: colorScheme,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonEmail,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonPassword,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonUsernameOptional,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: _isSubmitting ? null : _registerWithEmail,
          icon: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: InlineLoading(width: 20, height: 20, tileSize: 5))
              : Icon(Icons.person_add_alt, color: colorScheme.onPrimary, size: 22),
          label: Text(
            _isSubmitting ? AppLocalizations.of(context)!.commonWorking : AppLocalizations.of(context)!.authContinueWithEmail,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
