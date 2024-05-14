import 'package:flutter/material.dart';

class FloatingMenuButton extends StatelessWidget {
  const FloatingMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 16,
      top: 16,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
              const SizedBox(width: 8),
              Image.asset('assets/images/logo.png', height: 32, width: 32),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
