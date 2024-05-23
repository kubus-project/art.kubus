import 'package:flutter/material.dart';
import 'package:art_kubus/pages/markers.dart';
import 'package:art_kubus/widgets/drawer/menu_item.dart';

class MenuDrawer extends StatelessWidget {
  final String currentRoute;

  const MenuDrawer(this.currentRoute, {super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor:  Colors.black,
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'art.kubus',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white,  ), // Set text color to white
                ),
                const Text(
                  '© kubus',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white,  ), // Set text color to white
                ),
              ],
            ),
          ),
          MenuItemWidget(
            caption: 'Home',
            routeName: '/pages/home',
            currentRoute: currentRoute,
            icon: const Icon(Icons.home,
            color: Colors.white,),
          ),
          const Divider(),
          MenuItemWidget(
            caption: 'Marker Layer',
            routeName: MarkerPage.route,
            currentRoute: currentRoute,
          ),
        ],
      ),
    );
  }
}
