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
import 'markers/artmarker.dart'; // Import the ArtMarker widget

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

    WidgetsBinding.instance.addObserver(this);
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
        _mapController.move(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!), 16);
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
            title: 'Marker $i',
            description: 'This is marker $i',
          ),
        );
      }
    } catch (e) {
      // print('Failed to get location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Transform.scale(
            scale: 2, // Adjust this value as needed
            child: Transform.rotate(
              angle: _autoCenter ? ((_direction ?? 0) * (pi / 180) * -1) : 0,
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
            top: 10.0,
            right: 10.0,
            child: FloatingActionButton(
              child: Icon(_autoCenter ? Icons.location_searching : Icons.location_disabled, color: Colors.black,),
              onPressed: () {
                setState(() {
                  _autoCenter = !_autoCenter;
                  _direction = 0;
                });
              },
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