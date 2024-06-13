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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Augmented'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: loadingCamera
    ? const Center(child: CircularProgressIndicator())
    : Stack(
        children: [
          SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: ArWidget(controller)),
          Positioned(
            top: yPosition,
            left: xPosition,
            child: GestureDetector(
              onPanUpdate: (tapInfo) {
                setState(() {
                  xPosition += tapInfo.delta.dx;
                  yPosition += tapInfo.delta.dy;
                });
              },
              child: Container(
                  height: onchange,
                  color: Colors.transparent,
                  child: Image.network(
                      widget.image ??
                          'https://freepngimg.com/thumb/3d/32378-7-3d-photos-thumb.png',
                      height: onchange,
                      width: onchange)),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15, // 15% from the bottom
            child: Container(
              width: MediaQuery.of(context).size.width, // Full width of the screen
              child: Slider(
                value: onchange,
                min: 10,
                max: 300,
                thumbColor: Colors.white,
                activeColor: Colors.white,
                
                onChanged: (value) {
                  setState(() {
                    onchange = value;
                  });
                },
              ),
            ),
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
