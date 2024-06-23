
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ar_core/augmented_reality/augmented_preview.dart';

class Augmented extends StatefulWidget {
  final String image;
  const Augmented(this.image, {super.key});
  @override
  State <Augmented> createState() => _AugmentedState();
}

class _AugmentedState extends State<Augmented> {
  var controller;
  List<CameraDescription> cameras = [];
  bool loadingCamera = false;

  void loadCamera() async {
    setState(() {
      loadingCamera = true;
    });
    try {
      cameras = await availableCameras();
      controller = CameraController(cameras[0], ResolutionPreset.ultraHigh);
      await controller.initialize();
      setState(() {
        loadingCamera = false;
      });
    } catch (e) {
      setState(() {
        loadingCamera = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadCamera();
  }

  double xPosition = 130;
  double yPosition = 150;
  double onchange = 150;

// Modified scanMarker method to accept BuildContext and show SnackBar
void scanMarker(BuildContext context) {
  // Removed incorrect line: child: scanMarker(context);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Scanning marker...")),
  );
}

// Modified addMarker method to accept BuildContext and show SnackBar
void addMarker(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Adding marker...")),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loadingCamera
    ? const Center(child: CircularProgressIndicator())
    : Stack(
        children: [
          SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: ArWidget(controller)),
                  Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
  onPressed: () => scanMarker(context),
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  elevation: 1,
  child: const Icon(Icons.search),
)
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
  onPressed: () => addMarker(context),
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  elevation: 1,
  child: const Icon(Icons.add),
)
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose(); // Dispose the CameraController when the widget is removed from the tree
    super.dispose();
  }
}
