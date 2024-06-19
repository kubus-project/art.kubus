import 'package:flutter/material.dart';

class PulseMarkerWidget extends StatelessWidget {
  const PulseMarkerWidget({super.key});

  void createMarker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create a Marker'),
          content: SizedBox(
            width: 200, // Set your desired width
            height: 200, // Set your desired height
            child: Column(
              children: <Widget>[
                const TextField(
                  decoration: InputDecoration(hintText: 'Enter title'),
                ),
                const TextField(
                  decoration: InputDecoration(hintText: 'Enter description'),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    Navigator.pushNamed(context, '/ar');
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                const snackBar = SnackBar(content: Text('Marker created!'));
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => createMarker(context),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 22, // changes position of shadow
            ),
          ],
        ),
        child: const Icon(
          Icons.circle,
          size: 11,
        ),
      ),
    );
  }
}
