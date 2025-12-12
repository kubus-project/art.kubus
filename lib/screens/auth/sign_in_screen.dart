import 'package:flutter/material.dart';
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
import 'register_screen.dart';
import '../desktop/auth/desktop_auth_shell.dart';
import '../desktop/desktop_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    String? walletAddress = user['walletAddress'] ?? user['wallet_address'];
    final usernameFromUser = (user['username'] ?? user['displayName'] ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(), desiredUsername: usernameFromUser);
    } catch (e) {
      debugPrint('SignInScreen: wallet provisioning failed: $e');
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
      debugPrint('SignInScreen: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in, but profile will refresh shortly.')),
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp()));
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
          debugPrint('SignInScreen: connectWalletWithAddress failed: $e');
        }
      }
      try {
        if (!web3Provider.isConnected || web3Provider.walletAddress != address) {
          await web3Provider.connectExistingWallet(address);
        }
      } catch (e) {
        debugPrint('SignInScreen: connectExistingWallet failed: $e');
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
        debugPrint('SignInScreen: web3 import failed: $e');
      }
      try {
        await BackendApiService().issueTokenForWallet(address);
      } catch (e) {
        debugPrint('SignInScreen: issueTokenForWallet failed: $e');
      }
    } catch (e) {
      debugPrint('SignInScreen: wallet creation failed: $e');
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
      debugPrint('SignInScreen: createProfileFromWallet failed: $e');
    }
    if (effectiveUsername != null && effectiveUsername.isNotEmpty) {
      try {
        await BackendApiService().updateProfile(address, {
          'username': effectiveUsername,
          'displayName': effectiveUsername,
        });
      } catch (err) {
        debugPrint('SignInScreen: updateProfile username patch failed: $err');
      }
    }
  }

  Future<void> _submitEmail() async {
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sign-in is disabled.')));
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email and an 8+ character password.')));
      return;
    }
    setState(() => _isEmailSubmitting = true);
    try {
      final api = BackendApiService();
      final result = await api.loginWithEmail(email: email, password: password);
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email auth failed: $e')));
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!AppConfig.enableGoogleAuth) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in is disabled.')));
      return;
    }

    // Honor any server-provided rate-limit cooldown persisted from prior attempts.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final untilMs = prefs.getInt('rate_limit_auth_google_until');
      if (untilMs != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
        if (DateTime.now().isBefore(until)) {
          final remaining = until.difference(DateTime.now());
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in is temporarily rate limited. Retry in ~$friendly.')),
          );
          return;
        }
      }
    } catch (_) {}

    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        if (!mounted) return;
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      final api = BackendApiService();
      final result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        email: googleResult.email,
        username: googleResult.displayName,
      );
      // Clear any stored cooldown on success.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rate_limit_auth_google_until');
      } catch (_) {}
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  void _showConnectWalletModal() {
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet connection is disabled right now.')));
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connect a wallet', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                const SizedBox(height: 12),
                Text('You will be asked to approve a signature in your wallet app. No gas fee is needed to log in.', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 24),
                const SizedBox(height: 16),
                _walletOptionButton(ctx, 'WalletConnect', Icons.qr_code_2_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 3)));
                }),
                const SizedBox(height: 16),
                _walletOptionButton(ctx, 'Other wallets', Icons.apps_outlined, () {
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
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final form = _buildAuthForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      isDesktop: isDesktop,
    );

    if (isDesktop) {
      return DesktopAuthShell(
        title: 'Sign in to art.kubus',
        subtitle: 'and start exploring, creating, and connecting with other artists.',
        highlights: const [
          'Wallet, email, or Google sign-in',
          'No gas needed to authenticate',
          'Ownership stays with you',
        ],
        icon: GradientIconCard(
          start: const Color(0xFF0EA5E9),
          end: const Color(0xFF10B981),
          icon: Icons.login_rounded,
          iconSize: 52,
          width: 100,
          height: 100,
          radius: 20,
        ),
        gradientStart: const Color(0xFF0EA5E9),
        gradientEnd: const Color(0xFF10B981),
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp())),
            child: Text(
              'Skip for now',
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
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp())),
                        child: Text('Skip for now', style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.7))),
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

  Widget _buildAuthForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
    required bool isDesktop,
  }) {
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
                  start: const Color(0xFF0EA5E9),
                  end: const Color(0xFF10B981),
                  icon: Icons.login_rounded,
                  iconSize: 52,
                  width: 100,
                  height: 100,
                  radius: 20,
                ),
                const SizedBox(height: 12),
                Text('Sign in to art.kubus', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'and start exploring, creating, and connecting with other artists.',
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
            label: Text('Connect wallet', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onPrimary)),
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
              Text('Or log in with your email or username', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
              const SizedBox(height: 12),
              if (enableEmail) _buildEmailForm(colorScheme),
              if (enableGoogle) ...[
                const SizedBox(height: 12),
                GoogleSignInButton(
                  onPressed: _signInWithGoogle,
                  isLoading: _isGoogleSubmitting,
                  colorScheme: colorScheme,
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text('Need an account? Register', style: GoogleFonts.inter(color: colorScheme.primary, fontWeight: FontWeight.w700)),
              ),
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
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
          ),
          onPressed: _isEmailSubmitting ? null : _submitEmail,
          icon: _isEmailSubmitting
              ? const SizedBox(width: 20, height: 20, child: InlineLoading(width: 20, height: 20, tileSize: 5))
              : Icon(Icons.login_rounded, color: colorScheme.onPrimary, size: 22),
          label: Text(
            _isEmailSubmitting ? 'Working...' : 'Sign in with email',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
