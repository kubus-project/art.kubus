import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web3dart/web3dart.dart'; // Import the web3dart package

class Profile {
  String name;
  String bio;
  String links;
  File? imageFile;
  EthereumAddress? walletAddress; // Add a field for the wallet address

  Profile({
    required this.name,
    required this.bio,
    required this.links,
    this.imageFile,
    this.walletAddress, // Add a parameter for the wallet address
  });
}

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State <EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  File? _imageFile;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _linksController = TextEditingController();
  EthereumAddress? _walletAddress; // Add a field for the wallet address

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _getImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image selected.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

Future<void> _saveProfile() async {
  // Create a new Profile object with the entered data
  Profile profile = Profile(
    name: _nameController.text,
    bio: _bioController.text,
    links: _linksController.text,
    imageFile: _imageFile,
    walletAddress: _walletAddress, // Add the wallet address to the Profile object
  );

  // TODO: Use the profile object, for example, send it to your server
  // sendProfileToServer(profile);

  // For demonstration purposes, show a snackbar with a saved message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Profile saved'),
      duration: Duration(seconds: 2),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Dismiss keyboard when tapping outside of editable fields
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Edit'
          ),
        ),
        body: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.file(
                              _imageFile!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.account_circle,
                            size: 120,
                            color: Colors.grey,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _getImage,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white,  ),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.grey,  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _bioController,
                style: const TextStyle(color: Colors.white,  ),
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: Colors.grey,  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _linksController,
                style: const TextStyle(color: Colors.white,  ),
                decoration: const InputDecoration(
                  labelText: 'Links',
                  labelStyle: TextStyle(color: Colors.grey,  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text(
                  'Save',
                  style: TextStyle( ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
