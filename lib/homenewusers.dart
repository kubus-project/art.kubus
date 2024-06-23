import 'package:flutter/material.dart';
import 'map/map.dart'; // Make sure this import is correct

class HomeNewUsers extends StatelessWidget {
  const HomeNewUsers({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(side: BorderSide(width: 1)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MapHome(), // Embedding MapScreen here
            ),
          ],
        ),
      ),
    );
  }
}
