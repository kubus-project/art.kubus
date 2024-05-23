import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart'; 
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/connection_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/web3provider.dart';
import 'pages/markers.dart';
import 'pages/circle.dart';
import 'homenewusers.dart';
import 'walletmenu.dart';
import 'map.dart';
import 'ar/ar.dart';

void main() async {
  var logger = Logger();

  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logger.e(e.description);
  }
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
        ChangeNotifierProvider(create: (context) => Web3Provider()),
      ],
      child: MaterialApp(
        routes: {
          '/pages/markers': (context) => const MarkerPage(),
          '/pages/circle':(context) => const CirclePage(),
          '/pages/home' : (context) => const ArtKubus(),
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const HomeNewUsers()
          );
        },
        title: 'art.kubus',
         theme: ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    textTheme: GoogleFonts.sofiaSansTextTheme(
      Theme.of(context).textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    ),
          ),
          home: const MyHomePage(),
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

    final List<Widget> widgetOptions = [
      
      const MapHome(),
      const Augmented('https://rokcernezel.com/wp-content/uploads/2024/04/logo2.jpg.webp'),
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
                icon: const Icon(Icons.camera_alt),
                onPressed: () => _onItemTapped(1),
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

List<CameraDescription> cameras = [];