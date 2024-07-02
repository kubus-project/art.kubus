import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:art_kubus/providers/tile_providers.dart';
import 'package:art_kubus/widgets/first_start_dialog.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart';
import 'markers/pulsingmarker.dart';
import 'markers/artmarker.dart';
import 'package:art_kubus/map/compassaccuracy.dart';

class MapHome extends StatefulWidget {
  static const String route = '/';

  const MapHome({super.key});

  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> with WidgetsBindingObserver {
  LocationData? _currentLocation;
  Location location = Location();
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _autoCenter = true;

  // Declare a list of ArtMarker widgets
  List<ArtMarker>? _artMarkers;

  double? _direction;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
void initState() {
  super.initState();
  _getLocation();
  showIntroDialogIfNeeded();
  _timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) => _getLocation());

  // Start listening to compass updates immediately
  _compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
    setState(() {
      _direction = event.heading;
    });
  });

  WidgetsBinding.instance.addObserver(this);
}


  void updateDirection(double newDirection) {
  if ((newDirection - (_direction ?? 0)).abs() > 1) { // Example threshold
    setState(() {
      _direction = newDirection;
    });
  }
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is resumed, start listening to compass updates
      _compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
        setState(() {
          _direction = event.heading;
        });
      });
    } else {
      // App is paused, canceled, or detached, stop listening to compass updates
      _compassSubscription?.cancel();
      _compassSubscription = null;
    }
  }

  void _getLocation() async {
    try {
      var userLocation = await location.getLocation();
      setState(() {
        _currentLocation = userLocation;
      });
      if (_autoCenter) {
        _mapController.move(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!), _mapController.camera.zoom, 
        
        );
      }

      // Generate the ArtMarker widgets when the current location becomes available for the first time
      if (_artMarkers == null && _currentLocation != null) {
        _artMarkers = List.generate(
          10,
          (i) => ArtMarker(
            position: LatLng(
              _currentLocation!.latitude! + Random().nextDouble() * 0.02,
              _currentLocation!.longitude! + Random().nextDouble() * 0.01,
            ),
            title: 'Artwork $i',
            description: 'This is an artwork. Here you will see the info and other cool related stuff about the art that has been published and pinned to this location. $i',
          ),
        );
      }
    } catch (e) {
      // print('Failed to get location: $e');
    }
  }

 void checkCompassAccuracyAndShowPopup(BuildContext context, CompassAccuracyWidget compassWidget) {
  // Use the CompassAccuracyWidget to get the current compass accuracy
  double compassAccuracy = compassKey.currentState!.getCompassAccuracy(); // Adjust this line based on how you access the method

  // Check if the accuracy is below a certain threshold, indicating calibration is needed
  if (compassAccuracy < 2) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Compass Calibration Needed"),
          content: Text("Your compass needs calibration for better accuracy. Please move your device in a figure-eight motion. Current accuracy: $compassAccuracy"),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }
}

  @override
  Widget build(BuildContext context) {
    double rotationRadians = -(_direction ?? 0) * (pi / 180);
    return Scaffold(
      body: Stack(
        children: [
          Transform.scale(
            scale: 2.2, // Adjust this value as needed
            child: Transform.rotate(
              angle: _autoCenter ? rotationRadians : 0,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation != null
                      ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                      : const LatLng(46.056, 14.505),
                  initialZoom: 16,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-90, -180),
                      const LatLng(90, 180),
                    ),
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() {
                        _autoCenter = false;
                      });
                    }
                  },
                ),
                children: [
                  openStreetMapTileLayer,
                   MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(
                          point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                          child: const PulseMarkerWidget(),
                        ),
                    ],
                  ),
                  
                  
                  
                  // Add a separate MarkerLayer for the ArtMarker widgets
                  if (_artMarkers != null)
                    MarkerLayer(
                      markers: _artMarkers!.map(
                        (artMarker) => Marker(
                          point: artMarker.position,
                          child: artMarker,
                        ),
                      ).toList(),
                    ),
              
                ],
              ),
            ),
          ),

           Positioned(
      bottom: MediaQuery.of(context).size.height * 0.18,
      left: MediaQuery.of(context).size.width * 0.05,
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white, 
        elevation: 1,
        onPressed: () {
          _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          );
        },
        heroTag: 'zoomInFAB',
        child: const Icon(Icons.add),
      ),
    ),
    Positioned(
      bottom: MediaQuery.of(context).size.height * 0.1,
      left: MediaQuery.of(context).size.width * 0.05,
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white, 
        elevation: 1,
        onPressed: () {
          _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          );
        },
        heroTag: 'zoomOutFAB',
        child: const Icon(Icons.remove),
      ),
    ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
              elevation: 1,
              backgroundColor: Colors.transparent,
              onPressed: () {
                setState(() {
                  _autoCenter = !_autoCenter;
                  _direction = 0;
                });
              },
              heroTag: 'centerFAB',
              child: Icon(_autoCenter ? Icons.location_searching : Icons.location_disabled, 
                          color: Colors.white,
                          ),
            ),
          ),
        ],
      ),
    );
  }


  void showIntroDialogIfNeeded() {
    const seenIntroBoxKey = 'seenIntroBox(a)';
    if (kIsWeb && Uri.base.host.trim() == 'demo.fleaflet.dev') {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) async {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool(seenIntroBoxKey) ?? false) return;

          if (!mounted) return;

          await showDialog<void>(
            context: context,
            builder: (context) => const FirstStartDialog(),
          );
          await prefs.setBool(seenIntroBoxKey, true);
        },
      );
    }
  }

@override
  void dispose() {
    _timer?.cancel();
    _compassSubscription?.cancel(); // Stop listening to compass updates
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
