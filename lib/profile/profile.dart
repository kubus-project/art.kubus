import 'dart:io';
import 'package:web3dart/web3dart.dart';

class Profile {
  String name;
  String bio;
  String links;
  List<String> achievements;
  File? imageFile;
  EthereumAddress? walletAddress;
  List<String> friends;

  Profile({
    required this.name,
    required this.bio,
    required this.links,
    required this.achievements,
    this.imageFile,
    this.walletAddress,
    this.friends = const [],
  });
}