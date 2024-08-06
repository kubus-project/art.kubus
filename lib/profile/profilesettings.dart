import 'package:flutter/material.dart';

class ProfileSettings extends StatelessWidget {
  const ProfileSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrivacySettingsSection(),
          SecuritySettingsSection(),
          DeactivationSection(),
        ],
      ),
    );
  }
}

class PrivacySettingsSection extends StatefulWidget {
  const PrivacySettingsSection({super.key});

  @override
  _PrivacySettingsSectionState createState() => _PrivacySettingsSectionState();
}

class _PrivacySettingsSectionState extends State<PrivacySettingsSection> {
  String _selectedVisibility = 'Public';

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Privacy Settings',
      children: [
        ListTile(
          title: const Text('Profile Visibility'),
          trailing: DropdownButton<String>(
            dropdownColor: Colors.black,
            value: _selectedVisibility,
            items: <String>['Public', 'Private', 'Friends Only']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedVisibility = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }
}

class SecuritySettingsSection extends StatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  _SecuritySettingsSectionState createState() => _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<SecuritySettingsSection> {
  bool _isTwoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Security Settings',
      children: [
        ListTile(
          title: const Text('Change Password'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            // Navigate to change password screen
          },
        ),
        ListTile(
          title: const Text('Two-Factor Authentication'),
          trailing: Switch(
            value: _isTwoFactorEnabled,
            onChanged: (bool value) {
              setState(() {
                _isTwoFactorEnabled = value;
              });
            },
          ),
        ),
      ],
    );
  }
}

class DeactivationSection extends StatelessWidget {
  const DeactivationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Account Deactivation',
      children: [
        ListTile(
          title: const Text('Deactivate Account'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            // Navigate to account deactivation screen
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