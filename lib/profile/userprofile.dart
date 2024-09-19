import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/profile/editprofile.dart'; // Import the EditProfile widget
import 'achievements.dart';
import 'friends.dart';
import 'profilesettings.dart';

class UserProfile extends StatelessWidget {
  const UserProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    // ignore: unused_local_variable
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Profile',
          style: TextStyle(fontFamily: 'SofiaSans'),
        ), // Set the font to Sofia Sans
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfile()), // Navigate to EditProfile widget
              );
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileImageSection(),
            ProfileInfoSection(),
            SizedBox(height: 16),
            AchievementsSection(),
            SizedBox(height: 16),
            FriendsSection(),
            SizedBox(height: 16),
            ProfileSettingsSection(),
          ],
        ),
      ),
    );
  }
}

class ProfileImageSection extends StatelessWidget {
  const ProfileImageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;

    return Center(
      child: profile?.imageFile != null
          ? Card(
              child: Image.file(
                profile!.imageFile!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            )
          : const Card(
              child: Icon(
                Icons.account_circle,
                size: 120,
              ),
            ),
    );
  }
}

class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;

    return Column(
      children: [
        ProfileInfoCard(
          icon: Icons.person,
          title: 'Name',
          content: profile?.name ?? '',
        ),
        ProfileInfoCard(
          icon: Icons.info,
          title: 'Bio',
          content: profile?.bio ?? '',
        ),
        ProfileInfoCard(
          icon: Icons.link,
          title: 'Links',
          content: profile?.links ?? '',
        ),
      ],
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: Icon(icon),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'SofiaSans')),
            Text(content, style: const TextStyle(fontFamily: 'SofiaSans')),
          ],
        ),
      ),
    );
  }
}

class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: const Text('Achievements', style: TextStyle(fontFamily: 'SofiaSans')),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AchievementsPage()), // Navigate to AchievementsPage
          );
        },
      ),
    );
  }
}

class FriendsSection extends StatelessWidget {
  const FriendsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.group),
        title: const Text('Friends', style: TextStyle(fontFamily: 'SofiaSans')),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Friends()), // Navigate to FriendsPage
          );
        },
      ),
    );
  }
}

class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Profile Settings', style: TextStyle(fontFamily: 'SofiaSans')),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to profile settings page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Profile Settings'),
                ),
                body: const ProfileSettings(),
              ),
            ), // Wrap ProfileSettings in Scaffold
          );
        },
      ),
    );
  }
}