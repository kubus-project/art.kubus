import 'package:flutter/material.dart';
import 'package:art_kubus/pages/animated_map_controller.dart';
import 'package:art_kubus/pages/bundled_offline_map.dart';
import 'package:art_kubus/pages/cancellable_tile_provider.dart';
import 'package:art_kubus/pages/circle.dart';
import 'package:art_kubus/pages/custom_crs/custom_crs.dart';
import 'package:art_kubus/pages/debouncing_tile_update_transformer.dart';
import 'package:art_kubus/pages/epsg3413_crs.dart';
import 'package:art_kubus/pages/epsg4326_crs.dart';
import 'package:art_kubus/pages/fallback_url_page.dart';
import 'package:art_kubus/pages/home.dart';
import 'package:art_kubus/pages/interactive_test_page.dart';
import 'package:art_kubus/pages/latlng_to_screen_point.dart';
import 'package:art_kubus/pages/many_circles.dart';
import 'package:art_kubus/pages/many_markers.dart';
import 'package:art_kubus/pages/map_controller.dart';
import 'package:art_kubus/pages/map_inside_listview.dart';
import 'package:art_kubus/pages/markers.dart';
import 'package:art_kubus/pages/overlay_image.dart';
import 'package:art_kubus/pages/plugin_zoombuttons.dart';
import 'package:art_kubus/pages/polygon_perf_stress.dart';
import 'package:art_kubus/pages/polyline_perf_stress.dart';
import 'package:art_kubus/pages/reset_tile_layer.dart';
import 'package:art_kubus/pages/retina.dart';
import 'package:art_kubus/pages/screen_point_to_latlng.dart';
import 'package:art_kubus/pages/secondary_tap.dart';
import 'package:art_kubus/pages/sliding_map.dart';
import 'package:art_kubus/pages/tile_builder.dart';
import 'package:art_kubus/pages/tile_loading_error_handle.dart';
import 'package:art_kubus/pages/wms_tile_layer.dart';
import 'package:art_kubus/widgets/drawer/menu_item.dart';
import 'package:art_kubus/main.dart';

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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Sofia Sans'), // Set text color to white
                ),
                const Text(
                  '© kubus',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'Sofia Sans'), // Set text color to white
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
