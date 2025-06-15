import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/themeprovider.dart';

class AppSettings extends StatelessWidget {
  const AppSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThemeSettingsSection(),
            NotificationSettingsSection(),
            LanguageSettingsSection(),
            AppInfoSection(),
          ],
        ),
      ),
    );
  }
}

class ThemeSettingsSection extends StatefulWidget {
  const ThemeSettingsSection({super.key});

  @override
  State<ThemeSettingsSection> createState() => _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends State<ThemeSettingsSection> {
  late String _selectedTheme;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _selectedTheme = _themeModeToString(themeProvider.themeMode);
  }
  String _themeModeToString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  ThemeMode _stringToThemeMode(String theme) {
    switch (theme) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System Default':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Theme Settings',
      children: [
        ListTile(
          title: const Text('Select Theme'),
          trailing: DropdownButton<String>(
            value: _selectedTheme,
            items: <String>['Light', 'Dark', 'System Default']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedTheme = newValue!;
              });
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.setTheme(_stringToThemeMode(newValue!));
            },
          ),
        ),
      ],
    );
  }
}

class NotificationSettingsSection extends StatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  State<NotificationSettingsSection> createState() => _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState extends State<NotificationSettingsSection> {
  bool _isNotificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Notification Settings',
      children: [
        ListTile(
          title: const Text('Enable Notifications'),
          trailing: Switch(
            value: _isNotificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _isNotificationsEnabled = value;
              });
            },
          ),
        ),
      ],
    );
  }
}

class LanguageSettingsSection extends StatefulWidget {
  const LanguageSettingsSection({super.key});

  @override
  State<LanguageSettingsSection> createState() => _LanguageSettingsSectionState();
}

class _LanguageSettingsSectionState extends State<LanguageSettingsSection> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Language Settings',
      children: [
        ListTile(
          title: const Text('Select Language'),
          trailing: DropdownButton<String>(
            value: _selectedLanguage,
            items: <String>['English', 'Slovenščina', 'Espanol', 'Francias', 'Deutsch', 'Italiano', 'Português', '中文', '日本語']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedLanguage = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }
}

class AppInfoSection extends StatelessWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'App Information',
      children: [
        const ListTile(
          title: Text('Version'),
          trailing: Text('0.0.1'), // Replace with actual version
        ),
        ListTile(
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            // Navigate to Terms of Service screen
          },
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            // Navigate to Privacy Policy screen
          },
        ),
      ],
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const Section({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}