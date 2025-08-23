import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/themeprovider.dart';
import 'providers/profile_provider.dart';
import 'providers/mockup_data_provider.dart';
import 'config/config.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  bool _analyticsEnabled = true;
  bool _debugMode = AppConfig.enableDebugPrints;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _analyticsEnabled = prefs.getBool('analytics_enabled') ?? AppConfig.enableAnalytics;
      _debugMode = prefs.getBool('debug_mode') ?? AppConfig.enableDebugPrints;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, ProfileProvider>(
      builder: (context, themeProvider, profileProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Section
              _buildSectionHeader('Appearance'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.palette),
                      title: const Text('Theme'),
                      subtitle: Text(_getThemeModeText(themeProvider.themeMode)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeDialog(context, themeProvider),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode),
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme'),
                      value: themeProvider.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Audio & Notifications Section
              _buildSectionHeader('Audio & Notifications'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up),
                      title: const Text('Sound Effects'),
                      subtitle: const Text('Enable app sounds'),
                      value: _soundEnabled,
                      onChanged: (value) {
                        setState(() {
                          _soundEnabled = value;
                        });
                        _saveSetting('sound_enabled', value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications),
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive notifications'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _saveSetting('notifications_enabled', value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Privacy & Security Section
              _buildSectionHeader('Privacy & Security'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.analytics),
                      title: const Text('Analytics'),
                      subtitle: const Text('Help improve the app'),
                      value: _analyticsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _analyticsEnabled = value;
                        });
                        _saveSetting('analytics_enabled', value);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showTermsOfService(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Developer Section (only show in debug mode)
              if (AppConfig.isDevelopment) ...[
                _buildSectionHeader('Developer'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.bug_report),
                        title: const Text('Debug Mode'),
                        subtitle: const Text('Show debug information'),
                        value: _debugMode,
                        onChanged: (value) {
                          setState(() {
                            _debugMode = value;
                          });
                          _saveSetting('debug_mode', value);
                        },
                      ),
                      const Divider(height: 1),
                      Consumer<MockupDataProvider>(
                        builder: (context, mockupProvider, child) {
                          return SwitchListTile(
                            secondary: const Icon(Icons.data_usage),
                            title: const Text('Mockup Data'),
                            subtitle: Text(mockupProvider.isMockDataEnabled 
                                ? 'Using demo data (disable for IPFS production)' 
                                : 'Production mode (IPFS integration)'),
                            value: mockupProvider.isMockDataEnabled,
                            onChanged: (value) async {
                              await mockupProvider.toggleMockData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(value 
                                        ? 'Switched to mockup data mode' 
                                        : 'Switched to production mode (IPFS ready)'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.settings_backup_restore),
                        title: const Text('Reset Settings'),
                        subtitle: const Text('Reset all settings to default'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showResetDialog(context),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.data_usage),
                        title: Text('Mock Data'),
                        subtitle: Text(AppConfig.useMockData ? 'Enabled' : 'Disabled'),
                        trailing: Icon(
                          AppConfig.useMockData ? Icons.check_circle : Icons.cancel,
                          color: AppConfig.useMockData ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Account Section
              _buildSectionHeader('Account'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Profile'),
                      subtitle: Text(profileProvider.profile?.name ?? 'Guest'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed('/profile'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Wallet Settings'),
                      subtitle: const Text('Manage your Web3 wallet'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed('/wallet_settings'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                      onTap: () => _showSignOutDialog(context, profileProvider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // About Section
              _buildSectionHeader('About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About art.kubus'),
                      subtitle: const Text('Version 1.0.0'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSupportDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: const Text('Rate the App'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _rateApp(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'This is where the privacy policy would be displayed. '
            'In a real app, this would contain the full privacy policy text '
            'or navigate to a web view with the policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'This is where the terms of service would be displayed. '
            'In a real app, this would contain the full terms of service text '
            'or navigate to a web view with the terms.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _resetSettings();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to default')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, ProfileProvider profileProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              profileProvider.signOut();
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About art.kubus'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('art.kubus is a revolutionary platform for discovering, '
                'creating, and trading digital art in the Web3 space.'),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• AR Art Viewing'),
            Text('• NFT Marketplace'),
            Text('• Community Platform'),
            Text('• Web3 Integration'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email Support'),
              subtitle: Text('support@artkubus.com'),
            ),
            ListTile(
              leading: Icon(Icons.message),
              title: Text('Discord Community'),
              subtitle: Text('Join our Discord'),
            ),
            ListTile(
              leading: Icon(Icons.description),
              title: Text('Documentation'),
              subtitle: Text('Read our guides'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! This would open the app store rating page.'),
      ),
    );
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _soundEnabled = true;
      _notificationsEnabled = true;
      _analyticsEnabled = AppConfig.enableAnalytics;
      _debugMode = AppConfig.enableDebugPrints;
    });
  }
}