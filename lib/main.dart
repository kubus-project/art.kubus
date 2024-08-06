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
import 'menu.dart';
import 'map/map.dart';
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
    primaryColorDark: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    cardColor: Colors.white,
    canvasColor: Colors.white,
    textTheme: GoogleFonts.sofiaSansTextTheme(
      Theme.of(context).textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        decorationColor: Colors.white,
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Colors.white,
      textTheme: ButtonTextTheme.primary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
  ),
    snackBarTheme: const SnackBarThemeData(
      actionBackgroundColor: Colors.white,
      backgroundColor: Colors.white,
      actionTextColor: Colors.black,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Colors.transparent,
      iconColor: Colors.white,
      titleTextStyle: TextStyle(color: Colors.white)
      ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(foregroundColor:WidgetStatePropertyAll(Colors.white))
      
    )
          ),
          home: const MyHomePage(),
      ),
    );
  }
}


Future<void> requestPermissions() async {
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
      const Augmented(),
      const Menu(), 
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            widgetOptions.elementAt(_selectedIndex),
            // Floating action buttons
            Positioned(
              left: MediaQuery.of(context).size.width * 0.05,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _onItemTapped(1),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 1,
                heroTag: 'ARFAB',
                child: const Icon(Icons.view_in_ar_outlined),
              ),
            ),
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 28,
              bottom: 42
              ,
              child: FloatingActionButton(
                onPressed: () => _onItemTapped(0),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 1,
                heroTag:'LogoFAB',
                child: Image.asset('assets/images/logo.png')
              ),
            ),
            Positioned(
              right: MediaQuery.of(context).size.width * 0.05,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _onItemTapped(2),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 1,
                heroTag: 'MenuFAB',
                child: const Icon(Icons.menu,),
              ),
            ),
          ],
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