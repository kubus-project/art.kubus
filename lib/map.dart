import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:location/location.dart';

class MapHome extends StatefulWidget {
  const MapHome({Key? key}) : super(key: key);

  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  late InAppWebViewController controller;
  late Location location;
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  late LocationData _locationData;

  @override
  void initState() {
    super.initState();
    location = new Location();
    initLocation();
  }

  Future<void> initLocation() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map'),
      backgroundColor: Colors.black,),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/html/map.html')),
        onWebViewCreated: (InAppWebViewController webViewController) {
          controller = webViewController;
        },
        onLoadStart: (controller, url) {
          // Handle load start
        },
        onLoadStop: (controller, url) {
          // Handle load stop
        },
        onLoadError: (controller, url, code, message) {
          // Handle load error
        },
        onProgressChanged: (controller, progress) {
          // Update loading bar.
        },
        androidOnPermissionRequest: (controller, origin, resources) async {
          return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
        },
      ),
    );
  }
}
