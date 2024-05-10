import 'package:flutter/material.dart';
import 'map.dart'; // Make sure this import is correct

class HomeNewUsers extends StatelessWidget {
  const HomeNewUsers({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 455,
          height: 893,
          clipBehavior: Clip.antiAlias,
          decoration: const ShapeDecoration(
            color: Colors.black,
            shape: RoundedRectangleBorder(side: BorderSide(width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded( // Use Expanded to let the map take up all available space
                child: MapScreen(), // Embedding MapScreen here
              ),
              SizedBox(
                width: 455,
                height: 96,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 455,
                        height: 96,
                        decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                      ),
                    ),
                    const Positioned(
                      left: 165,
                      top: 29,
                      child: SizedBox(
                        width: 124,
                        height: 38,
                        child: Text(
                          'Connect',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontFamily: 'Sofia Sans',
                            fontWeight: FontWeight.w400,
                            height: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
