import 'package:flutter/material.dart';
import 'package:art_kubus/widgets/drawer/menu_drawer.dart';

class PulseMarkerWidget extends StatelessWidget {
  const PulseMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MenuDrawer(''))),
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
    size: 9,
  ),
));

  }
}
