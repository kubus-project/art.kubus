import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart'; // Import the provider package
import 'pages/markers.dart';
import 'pages/circle.dart';
import 'homenewusers.dart';
import 'walletmenu.dart';
import 'map.dart';
import 'providers/connection_provider.dart';
import 'providers/profile_provider.dart';
import  'providers/web3provider.dart'; // Import the ConnectionProvider class

void main() {
  runApp(const ArtKubus());
}

class ArtKubus extends StatelessWidget {
  const ArtKubus({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => Web3Provider()),// Add other providers here
      ],
      child: MaterialApp(
        routes: {
          '/pages/markers': (context) => const MarkerPage(),
          '/pages/circle':(context) => const CirclePage(),
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const HomeNewUsers()
          );
        },
        title: 'art.kubus',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MyHomePage(),  // Now MyHomePage has access to ConnectionProvider
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
                icon: const Icon(Icons.wallet),
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
