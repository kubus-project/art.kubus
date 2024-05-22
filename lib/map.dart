import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:art_kubus/providers/tile_providers.dart';
// import 'package:art_kubus/widgets/drawer/floating_menu_button.dart';
// import 'package:art_kubus/widgets/drawer/menu_drawer.dart';
import 'package:art_kubus/widgets/first_start_dialog.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'widgets/pulsingmarker.dart';

class MapHome extends StatefulWidget {
  static const String route = '/';

  const MapHome({super.key});

  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  LocationData? _currentLocation;
  Location location = Location();
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _autoCenter = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
    showIntroDialogIfNeeded();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) => _getLocation());
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
    } catch (e) {
      // print('Failed to get location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   //   drawer: const MenuDrawer(MapHome.route),
      body: Stack(
        children: [
          FlutterMap(
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
            ],
          ),
          Positioned(
            top: 10.0,
            right: 10.0,
            child: FloatingActionButton(
              child: Icon(_autoCenter ? Icons.location_searching : Icons.location_disabled, color: Colors.black,),
              onPressed: () {
                setState(() {
                  _autoCenter = !_autoCenter;
                });
              },
            ),
          ),
       //   const FloatingMenuButton()
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
    super.dispose();
  }
}
