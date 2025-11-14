import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';

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
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final state = <String, dynamic>{};
    
    // Load all onboarding-related preferences
    state['first_time'] = prefs.getBool('first_time') ?? true;
    state['has_seen_welcome'] = prefs.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    state['is_first_launch'] = prefs.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    state['has_wallet'] = prefs.getBool('has_wallet') ?? false;
    state['completed_onboarding'] = prefs.getBool('completed_onboarding') ?? false;
    state['skipOnboardingForReturningUsers'] = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
    
    setState(() {
      _currentState = state;
      _isLoading = false;
    });
  }

  Future<void> _resetOnboardingState() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Reset Onboarding',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will reset all onboarding flags. The app will show onboarding screens on next launch.\n\nContinue?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    
    // Reset all onboarding flags
    await prefs.setBool('first_time', true);
    await prefs.setBool(PreferenceKeys.hasSeenWelcome, false);
    await prefs.setBool(PreferenceKeys.isFirstLaunch, true);
    await prefs.remove('has_wallet');
    await prefs.remove('completed_onboarding');
    
    // Reset all Web3 feature onboarding
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.endsWith('_onboarding_completed')) {
        await prefs.remove(key);
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Onboarding state reset! Restart the app to see onboarding.'),
        duration: Duration(seconds: 3),
      ),
    );

    // Reload current state
    await _loadCurrentState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Reset Tool'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Developer Tool',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This tool shows the current onboarding state and allows you to reset it for testing.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Current Onboarding State',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ..._currentState.entries.map((entry) => _buildStateItem(
                        entry.key,
                        entry.value.toString(),
                        _getStateColor(entry.value),
                      )),
                  const SizedBox(height: 24),
                  Text(
                    'Config Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildStateItem(
                    'enforceWalletOnboarding',
                    AppConfig.enforceWalletOnboarding.toString(),
                    AppConfig.enforceWalletOnboarding ? Colors.green : Colors.orange,
                  ),
                  _buildStateItem(
                    'showWelcomeScreen',
                    AppConfig.showWelcomeScreen.toString(),
                    AppConfig.showWelcomeScreen ? Colors.green : Colors.grey,
                  ),
                  _buildStateItem(
                    'skipOnboardingForReturningUsers',
                    AppConfig.skipOnboardingForReturningUsers.toString(),
                    AppConfig.skipOnboardingForReturningUsers ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetOnboardingState,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Onboarding State'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'How to Test',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Tap "Reset Onboarding State"\n'
                            '2. Restart the app (close and reopen)\n'
                            '3. Onboarding should show on launch',
                            style: TextStyle(fontSize: 14),
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

  Color _getStateColor(dynamic value) {
    if (value == true) return Colors.green;
    if (value == false) return Colors.grey;
    return Colors.blue;
  }
}
