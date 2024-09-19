import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart'; 
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/connection_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/web3provider.dart';
import 'providers/themeprovider.dart';
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
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => Web3Provider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const ArtKubus(),
    ),
  );
}

class ArtKubus extends StatelessWidget {
  const ArtKubus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          routes: {
            '/pages/home': (context) => const ArtKubus(),
          },
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const HomeNewUsers(),
            );
          },
          title: 'art.kubus',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MyHomePage(),
        );
      },
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
                elevation: 1,
                heroTag: 'ARFAB',
                child: const Icon(Icons.view_in_ar_outlined),
              ),
            ),
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 28,
              bottom: 42,
              child: FloatingActionButton(
  onPressed: () => _onItemTapped(0),
  elevation: 1,
  heroTag: 'LogoFAB',
  child: Image.asset(
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/logo.png'
        : 'assets/images/logo_black.png',
  ),
),
            ),
            Positioned(
              right: MediaQuery.of(context).size.width * 0.05,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _onItemTapped(2),
                elevation: 1,
                heroTag: 'MenuFAB',
                child: const Icon(Icons.menu),
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

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.black,
  primaryColorDark: Colors.black,
  primaryColorLight: Colors.black,
  scaffoldBackgroundColor: Colors.black,
  cardColor: Colors.black,
  canvasColor: Colors.black,
  dialogBackgroundColor: Colors.black,
  dividerColor: Colors.white,
  focusColor: Colors.white,
  hoverColor: Colors.white,
  highlightColor: Colors.white,
  splashColor: Colors.white,
  unselectedWidgetColor: Colors.white,
  disabledColor: Colors.grey,
  secondaryHeaderColor: Colors.black,
  indicatorColor: Colors.white,
  hintColor: Colors.white,
  textTheme: GoogleFonts.sofiaSansTextTheme(
    ThemeData.dark().textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      decorationColor: Colors.white,
    ),
  ),
  buttonTheme: const ButtonThemeData(
    buttonColor: Colors.black,
    textTheme: ButtonTextTheme.primary,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.black26,
    foregroundColor: Colors.white,
  ),
  snackBarTheme: const SnackBarThemeData(
    actionBackgroundColor: Colors.white,
    backgroundColor: Colors.white,
    actionTextColor: Colors.black,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.black,
  ),
  dialogTheme: const DialogTheme(
    backgroundColor: Colors.black,
    iconColor: Colors.white,
    titleTextStyle: TextStyle(color: Colors.white),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all(Colors.white),
      backgroundColor: WidgetStateProperty.all(Colors.black),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.black),
      foregroundColor: WidgetStateProperty.all(Colors.white),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Colors.white,
  ),
  iconTheme: const IconThemeData(
    color: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white),
  ),
  primaryIconTheme: const IconThemeData(
    color: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.black,
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.grey,
  ),
  tabBarTheme: const TabBarTheme(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.grey,
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: Colors.black,
    disabledColor: Colors.grey,
    selectedColor: Colors.white,
    secondarySelectedColor: Colors.white,
    padding: EdgeInsets.all(4.0),
    labelStyle: TextStyle(color: Colors.white),
    secondaryLabelStyle: TextStyle(color: Colors.black),
    brightness: Brightness.dark,
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: Colors.white,
    inactiveTrackColor: Colors.grey,
    thumbColor: Colors.white,
    overlayColor: Colors.white24,
    valueIndicatorColor: Colors.white,
  ),
  cardTheme: const CardTheme(
    color: Colors.black,
    shadowColor: Colors.white,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.black,
  ),
  tooltipTheme: const TooltipThemeData(
    decoration: BoxDecoration(
      color: Colors.black,
    ),
    textStyle: TextStyle(color: Colors.white),
  ),
);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.white,
  primaryColorDark: Colors.white,
  primaryColorLight: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  canvasColor: Colors.white,
  dialogBackgroundColor: Colors.white,
  dividerColor: Colors.black,
  focusColor: Colors.black,
  hoverColor: Colors.black,
  highlightColor: Colors.black,
  splashColor: Colors.black,
  unselectedWidgetColor: Colors.black,
  disabledColor: Colors.grey,
  secondaryHeaderColor: Colors.white,
  indicatorColor: Colors.black,
  hintColor: Colors.black,
  textTheme: GoogleFonts.sofiaSansTextTheme(
    ThemeData.light().textTheme.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
      decorationColor: Colors.black,
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
    actionBackgroundColor: Colors.black,
    backgroundColor: Colors.black,
    actionTextColor: Colors.white,
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.white,
  ),
  dialogTheme: const DialogTheme(
    backgroundColor: Colors.white,
    iconColor: Colors.black,
    titleTextStyle: TextStyle(color: Colors.black),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all(Colors.black),
      backgroundColor: WidgetStateProperty.all(Colors.white),
    ),
  ),
   elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.white),
      foregroundColor: WidgetStateProperty.all(Colors.black),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Colors.black,
  ),
  iconTheme: const IconThemeData(
    color: Colors.black,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(color: Colors.black),
  ),
  primaryIconTheme: const IconThemeData(
    color: Colors.black,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Colors.black,
    unselectedItemColor: Colors.grey,
  ),
  tabBarTheme: const TabBarTheme(
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey,
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: Colors.white,
    disabledColor: Colors.grey,
    selectedColor: Colors.black,
    secondarySelectedColor: Colors.black,
    padding: EdgeInsets.all(4.0),
    labelStyle: TextStyle(color: Colors.black),
    secondaryLabelStyle: TextStyle(color: Colors.white),
    brightness: Brightness.light,
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: Colors.black,
    inactiveTrackColor: Colors.grey,
    thumbColor: Colors.black,
    overlayColor: Colors.black26,
    valueIndicatorColor: Colors.black,
  ),
  cardTheme: const CardTheme(
    color: Colors.white,
    shadowColor: Colors.black,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
  ),
  tooltipTheme: const TooltipThemeData(
    decoration: BoxDecoration(
      color: Colors.white,
    ),
    textStyle: TextStyle(color: Colors.black),
  ),
);