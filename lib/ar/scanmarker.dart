import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

// Assuming 'controller' is a CameraController and is initialized elsewhere in your code
late CameraController controller;

Future<void> scanMarker(BuildContext context) async {
  // Placeholder for permission check (not implemented here)
  // Ensure you have the necessary permissions before proceeding

  try {
    // Ensure the camera is initialized
    if (!controller.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera is not initialized")),
      );
      return;
    }
    // Path for the image
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Capture the image
    await controller.takePicture();

    // Create a File object to send
    File imageFile = File(filePath);

    // Send the image to the backend
    var uri = Uri.parse('YOUR_BACKEND_API_ENDPOINT'); // Ensure this is your actual backend API endpoint
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image successfully sent to the backend")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send image to the backend")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error scanning marker: $e")),
    );
  }
}