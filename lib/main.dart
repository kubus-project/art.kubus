import 'package:flutter/material.dart';
import 'homenewusers.dart'; // Ensure this imports your HomeNewUsers screen correctly
import 'profilemenu.dart';
import 'map.dart';
import 'package:permission_handler/permission_handler.dart';


void main() => runApp(const ArtKubus());

class ArtKubus extends StatelessWidget {
  const ArtKubus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'art.kubus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

Future<void> requestPermissions() async {
  await Permission.storage.request();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
   createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  // List of widgets to call on tap
  final List<Widget> _widgetOptions = [
    const HomeNewUsers(), // Your HomeNewUsers widget
    const MapScreen(), // Placeholder for the map screen
     const ProfileMenu(), // Placeholder for the profile screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () => _onItemTapped(1),
            ),
            const Spacer(), // This will space out the logo to the center
            IconButton(
              icon: Image.asset('assets/images/logo.png'), // Logo as a button
              onPressed: () => _onItemTapped(0), // You can modify this as needed
            ),
            const Spacer(), // Another spacer
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}