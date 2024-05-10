import 'package:flutter/material.dart';

class HomeLoggedIn extends StatelessWidget {
  const HomeLoggedIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 430,
          height: 932,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: Colors.black),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 563,
                child: Container(
                  width: 430,
                  height: 268,
                  decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 430,
                  height: 563,
                  decoration: const BoxDecoration(color: Color(0xFF5B71E8)),
                ),
              ),
              const Positioned(
                left: 13,
                top: 573,
                child: SizedBox(
                  width: 174,
                  height: 30,
                  child: Text(
                    'Feed',
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
    );
  }
}