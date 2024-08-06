import 'package:flutter/material.dart';

class Friends extends StatelessWidget {
  final List<String> friends = [
    'Alice',
    'Bob',
    'Charlie',
    'David',
    'Eve'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
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