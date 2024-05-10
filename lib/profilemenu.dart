import 'package:flutter/material.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 450,
          height: 893,
          padding: const EdgeInsets.only(bottom: 0.25),
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: Colors.black),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 450,
                height: 464,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 450,
                        height: 464,
                        decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                      ),
                    ),
                    const Positioned(
                      left: 154,
                      top: 205,
                      child: SizedBox(
                        width: 160,
                        height: 41,
                        child: Text(
                          'Collection',
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
              const SizedBox(height: 30),
              SizedBox(
                width: 450,
                height: 115,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 450,
                        height: 115,
                        decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                      ),
                    ),
                    const Positioned(
                      left: 143,
                      top: 39,
                      child: SizedBox(
                        width: 180,
                        child: Text(
                          'Community',
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
              const SizedBox(height: 30),
              SizedBox(
                width: 450,
                height: 115,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 450,
                        height: 115,
                        decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                      ),
                    ),
                    const Positioned(
                      left: 181,
                      top: 39,
                      child: SizedBox(
                        width: 120,
                        child: Text(
                          'Profile',
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
              const SizedBox(height: 30),
              SizedBox(
                width: 450,
                height: 101.75,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 450,
                        height: 101.75,
                        decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
                      ),
                    ),
                    const Positioned(
                      left: 169,
                      top: 34.51,
                      child: SizedBox(
                        width: 120,
                        height: 33.62,
                        child: Text(
                          'Support',
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