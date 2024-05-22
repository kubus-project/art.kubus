import 'package:flutter/material.dart';
import 'package:art_kubus/widgets/drawer/menu_drawer.dart';

class PulseMarkerWidget extends StatelessWidget {
  const PulseMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MenuDrawer(''))),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
