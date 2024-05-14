import 'package:flutter/material.dart';

class MenuItemWidget extends StatelessWidget {
  final String caption;
  final String routeName;
  final bool isSelected;
  final Widget? icon;

  const MenuItemWidget({
    required this.caption,
    required this.routeName,
    required String currentRoute,
    this.icon,
    Key? key, // Corrected parameter name
  }) : isSelected = currentRoute == "/pages$routeName", super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        caption,
        style: TextStyle(color: Colors.white),
      ),
      leading: icon,
      selected: isSelected,
      tileColor: Colors.black,
      onTap: () {
        if (isSelected) {
          // Close drawer
          Navigator.pop(context);
          return;
        }
        Navigator.pushReplacementNamed(context, "/pages$routeName");
      },
    );
  }
}
