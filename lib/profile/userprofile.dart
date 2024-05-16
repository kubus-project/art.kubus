import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/profile/editprofile.dart'; // Import the EditProfile widget

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
        title: const Text('Your Profile', style: TextStyle(color: Colors.white, fontFamily: 'SofiaSans'),), // Set the font to Sofia Sans
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
                  profile!.imageFile,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              )
            else
              Card(
                color: Colors.white, // Set the card color to white
                child: const Icon(
                  Icons.account_circle,
                  size: 120,
                  color: Colors.grey,
                ),
              ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Name', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
                subtitle: Text(profile?.name ?? '', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
              ),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Bio', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
                subtitle: Text(profile?.bio ?? '', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
              ),
            ),
            Card(
              color: Colors.white, // Set the card color to white
              child: ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Links', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
                subtitle: Text(profile?.links ?? '', style: TextStyle(fontFamily: 'SofiaSans')), // Set the font to Sofia Sans
              ),
            ),
          ],
        ),
      ),
    );
  }
}
