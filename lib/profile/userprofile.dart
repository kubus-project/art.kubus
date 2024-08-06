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
    final profile = profileProvider.profile;

    return Scaffold(
      backgroundColor: Colors.black, // Set the background color to black
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Your Profile',
          style: TextStyle(color: Colors.white, fontFamily: 'SofiaSans'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            if (profile?.imageFile != null)
              Card(
                color: Colors.white, // Set the card color to white
                child: Image.file(
                  profile!.imageFile!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Card(
                color: Colors.white, // Set the card color to white
                child: Icon(
                  Icons.account_circle,
                  size: 120,
                  color: Colors.grey,
                ),
              ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                leading: const Icon(Icons.person, color: Colors.black), // Make icon color black
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Name', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                    Text(profile?.name ?? '', style: const TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                leading: const Icon(Icons.info, color: Colors.black), // Make icon color black
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bio', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                    Text(profile?.bio ?? '', style: const TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                leading: const Icon(Icons.link, color: Colors.black), // Make icon color black
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Links', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                    Text(profile?.links ?? '', style: const TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Achievements',
              style: TextStyle(color: Colors.white, fontFamily: 'SofiaSans', fontSize: 18),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.black), // Make icon color black
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Achievements', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AchievementsPage()), // Navigate to AchievementsPage
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Friends',
              style: TextStyle(color: Colors.white, fontFamily: 'SofiaSans', fontSize: 18),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.group, color: Colors.black), // Make icon color black
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Friends', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Friends()), // Navigate to FriendsPage
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Settings',
              style: TextStyle(color: Colors.white, fontFamily: 'SofiaSans', fontSize: 18),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.black), // Make icon color black
                title: const Text('Profile Settings', style: TextStyle(fontFamily: 'SofiaSans', color: Colors.black)), // Make text color black
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
            ),
          ],
        ),
      ),
    );
  }
}