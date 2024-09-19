import 'package:flutter/material.dart';

class Friends extends StatelessWidget {
  final List<String> friends;

  Friends({super.key}) : friends = ['PixelDreamer', 'DesignNinja', 'ScriptWizard', 'DataDancer', 'CloudCrafter', 'BinaryBard', 'CyberSculptor'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(friends[index]),
          );
        },
      ),
    );
  }
}