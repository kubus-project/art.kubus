import 'package:flutter/material.dart';

class GradientIconCard extends StatelessWidget {
  final Color start;
  final Color? end;
  final IconData icon;
  final double iconSize;
  final double width;
  final double height;
  final double radius;

  const GradientIconCard({
    super.key,
    required this.start,
    this.end,
    required this.icon,
    this.iconSize = 32,
    this.width = 80,
    this.height = 80,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final Color endColor = end ?? start.withOpacity(0.7);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, endColor],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: start.withOpacity(0.28),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
