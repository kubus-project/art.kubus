import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart'; // Import the provider package
import 'pages/markers.dart';
import 'pages/circle.dart';
import 'homenewusers.dart';
import 'profilemenu.dart';
import 'map.dart';
import 'connection_provider.dart'; // Import the ConnectionProvider class

void main() => runApp(const ArtKubus());

class ArtKubus extends StatelessWidget {
  const ArtKubus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      routes: {
        '/pages/markers': (context) => MarkerPage(),
        '/pages/circle':(context) => CirclePage(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => HomeNewUsers()
        );
      },
      title: 'art.kubus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider( // Wrap your main widget with the provider
        create: (context) => ConnectionProvider(), // Provide an instance of ConnectionProvider
        child: const MyHomePage(),
      ),
    );
  }
}

Future<void> requestPermissions() async {
  await Permission.storage.request();
  await Permission.location.request();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);

    final List<Widget> widgetOptions = [
      const HomeNewUsers(),
      const MapHome(),
      const ProfileMenu(), 
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            widgetOptions.elementAt(_selectedIndex)
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  if (!connectionProvider.isConnected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You need to connect to use the map.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    _onItemTapped(1);
                  }
                },
              ),
              IconButton(
                icon: Image.asset('assets/images/logo.png'), 
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => _onItemTapped(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
