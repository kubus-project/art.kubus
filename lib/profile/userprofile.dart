import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/profile/editprofile.dart';
import '../web3/achievements/achievements_page.dart' as web3_achievements;
import '../web3/wallet/wallet_overview.dart';
import '../web3/wallet/nft_gallery.dart';
import '../screens/settings_screen.dart';
import 'friends.dart';
import 'profilesettings.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    // ignore: unused_local_variable
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Profile',
          style: GoogleFonts.sofiaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfile()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileImageSection(),
            const ProfileInfoSection(),
            const SizedBox(height: 16),
            _buildWeb3ProfileSection(context),
            const SizedBox(height: 16),
            const AchievementsSection(),
            const SizedBox(height: 16),
            const FriendsSection(),
            const SizedBox(height: 16),
            _buildSettingsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWeb3ProfileSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Web3 & Digital Assets',
              style: GoogleFonts.sofiaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWeb3ActionCard(
                    icon: Icons.account_balance_wallet,
                    title: 'Wallet',
                    subtitle: '1000 KUB8',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalletOverview()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeb3ActionCard(
                    icon: Icons.collections,
                    title: 'NFTs',
                    subtitle: '5 items',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NFTGallery()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeb3ActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.sofiaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text('Profile Settings', style: GoogleFonts.sofiaSans()),
              subtitle: const Text('Manage your profile preferences'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileSettings()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_applications),
              title: Text('App Settings', style: GoogleFonts.sofiaSans()),
              subtitle: const Text('Theme, notifications, language'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(context).primaryColor,
            child: CircleAvatar(
              radius: 58,
              backgroundImage: profile?.imageFile != null
                  ? FileImage(profile!.imageFile!)
                  : null,
              child: profile?.imageFile == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile?.name ?? 'Anonymous User',
            style: GoogleFonts.sofiaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (profile?.bio != null && profile!.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                profile.bio,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
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
          icon: Icons.location_on,
          title: 'Location',
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
        leading: Icon(icon),
        title: Text(title, style: GoogleFonts.sofiaSans()),
        subtitle: Text(content.isEmpty ? 'Not specified' : content),
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
        title: Text('Achievements', style: GoogleFonts.sofiaSans()),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const web3_achievements.AchievementsPage()),
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
        leading: const Icon(Icons.people),
        title: Text('Friends', style: GoogleFonts.sofiaSans()),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Friends()),
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
        title: Text('Profile Settings', style: GoogleFonts.sofiaSans()),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSettings()),
          );
        },
      ),
    );
  }
}
