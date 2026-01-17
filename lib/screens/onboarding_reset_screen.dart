import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_loading.dart';
import '../config/config.dart';
import '../services/onboarding_state_service.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// Developer tool to reset app onboarding state
/// This screen can be accessed from the settings or profile menu during development
class OnboardingResetScreen extends StatefulWidget {
  const OnboardingResetScreen({super.key});

  @override
  State<OnboardingResetScreen> createState() => _OnboardingResetScreenState();
}

class _OnboardingResetScreenState extends State<OnboardingResetScreen> {
  Map<String, dynamic> _currentState = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  Future<void> _loadCurrentState() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final state = <String, dynamic>{};

    final onboardingState = await OnboardingStateService.load(prefs: prefs);
    
    // Load all onboarding-related preferences
    state['is_first_launch'] = onboardingState.isFirstLaunch;
    state['has_seen_welcome'] = onboardingState.hasSeenWelcome;
    state['has_completed_onboarding'] = onboardingState.hasCompletedOnboarding;
    state['has_wallet'] = prefs.getBool('has_wallet') ?? false;
    state['skipOnboardingForReturningUsers'] = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;

    // Legacy keys (debug visibility)
    state['legacy.first_time'] = prefs.getBool('first_time');
    state['legacy.completed_onboarding'] = prefs.getBool('completed_onboarding');
    state['legacy.has_seen_onboarding'] = prefs.getBool('has_seen_onboarding');
    state['legacy.has_seen_permissions'] = prefs.getBool('has_seen_permissions');
    
    if (!mounted) return;
    setState(() {
      _currentState = state;
      _isLoading = false;
    });
  }

  Future<void> _resetOnboardingState() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.onboardingResetDialogTitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.onboardingResetDialogBody,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.commonReset),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    
    // Reset all onboarding flags
    await prefs.remove('has_wallet');
    await OnboardingStateService.reset(prefs: prefs);
    
    // Reset all Web3 feature onboarding
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.endsWith('_onboarding_completed')) {
        await prefs.remove(key);
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(l10n.onboardingResetSnackBarMessage),
        duration: const Duration(seconds: 3),
      ),
    );

    // Reload current state
    await _loadCurrentState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingResetToolTitle),
        backgroundColor: scheme.primary,
      ),
        body: _isLoading
          ? const AppLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                l10n.onboardingResetDeveloperToolTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.onboardingResetDeveloperToolDescription,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.onboardingResetCurrentStateTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ..._currentState.entries.map((entry) => _buildStateItem(
                        entry.key,
                        entry.value.toString(),
                        _getStateColor(entry.value, scheme),
                      )),
                  const SizedBox(height: 24),
                  Text(
                    l10n.onboardingResetConfigSettingsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildStateItem(
                    'enforceWalletOnboarding',
                    AppConfig.enforceWalletOnboarding.toString(),
                    AppConfig.enforceWalletOnboarding ? scheme.tertiary : scheme.outline,
                  ),
                  _buildStateItem(
                    'showWelcomeScreen',
                    AppConfig.showWelcomeScreen.toString(),
                    AppConfig.showWelcomeScreen ? scheme.primary : scheme.outline,
                  ),
                  _buildStateItem(
                    'skipOnboardingForReturningUsers',
                    AppConfig.skipOnboardingForReturningUsers.toString(),
                    AppConfig.skipOnboardingForReturningUsers ? scheme.tertiary : scheme.primary,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetOnboardingState,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.onboardingResetButtonLabel),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: scheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: scheme.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                l10n.onboardingResetHowToTestTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.onboardingResetHowToTestSteps,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStateItem(String key, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            _getIconForState(value),
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          key,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForState(String value) {
    if (value == 'true') return Icons.check_circle;
    if (value == 'false') return Icons.cancel;
    return Icons.info;
  }

  Color _getStateColor(dynamic value, ColorScheme scheme) {
    if (value == true) return scheme.primary;
    if (value == false) return scheme.outline;
    return scheme.secondary;
  }
}
