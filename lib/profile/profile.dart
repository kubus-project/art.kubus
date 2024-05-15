import 'dart:io';
class Profile {
  String name;
  String bio;
  String links;
  File imageFile;

  Profile({
    required this.name,
    required this.bio,
    required this.links,
    required this.imageFile,
  });
}
