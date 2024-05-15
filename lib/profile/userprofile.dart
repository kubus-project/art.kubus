import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/profile_provider.dart';
import 'package:art_kubus/profile/editprofile.dart'; // Import the EditProfile widget

class UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text('UserProfile'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfile()), // Navigate to EditProfile widget
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (profile?.imageFile != null)
              Image.file(
                profile!.imageFile,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 8),
            Text(
              'Name: ${profile?.name ?? ''}',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              'Bio: ${profile?.bio ?? ''}',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              'Links: ${profile?.links ?? ''}',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
