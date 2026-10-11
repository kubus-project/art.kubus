import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/presence_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/tile_providers.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_map_screen.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/kubus_map_tokens.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/map/controls/kubus_map_primary_controls.dart';
import 'package:art_kubus/widgets/map/kubus_activation_prompt_card.dart';
import 'package:art_kubus/widgets/map/kubus_map_chrome.dart';
import 'package:art_kubus/widgets/search/kubus_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map chrome correction (0.8.2 E): one logo, one flat surface level per
/// cluster, visible attribution, and a grouped control cluster with a logical
/// focus order.
void main() {
  group('map chrome: attribution', () {
    // Worst-case map pixels behind the chrome. The overlay is 90% opaque, so
    // the map shows through at most 10%; black (light theme) and white (dark
    // theme) are the adverse extremes the credit must still read against.
    const lightMapWorst = Color(0xFF000000);
    const darkMapWorst = Color(0xFFFFFFFF);

    for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
      final isDark = brightness == Brightness.dark;
      final roles = isDark ? KubusColorRoles.dark : KubusColorRoles.light;
      final mapWorst = isDark ? darkMapWorst : lightMapWorst;

      testWidgets(
        'credit is visible and meets 4.5:1 with token colours in '
        '${isDark ? 'dark' : 'light'} theme over the adverse map pixel',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                extensions: <ThemeExtension<dynamic>>[roles],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Stack(
                  children: [
                    Container(color: mapWorst),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: KubusMapAttributionControl(
                        semanticsLabel: 'Map attributions',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final credit = tester.widget<Text>(
            find.text(kubusMapAttributionCredit),
          );
          final textColor = credit.style?.color;
          expect(textColor, isNotNull);
          // The text colour is the family foreground token, not a literal.
          expect(textColor, roles.foreground);

          // Chrome surface = surfaceOverlay token composited over the map.
          final chromeBackground = Color.alphaBlend(
            roles.surfaceOverlay,
            mapWorst,
          );
          final ratio = kubusMapChromeContrastRatio(
            textColor!,
            chromeBackground,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'credit contrast $ratio over $chromeBackground',
          );

          // Readable and tappable: the whole row is at least 44px high.
          final tapTarget = tester.getSize(
            find.byType(KubusMapAttributionControl),
          );
          expect(tapTarget.height, greaterThanOrEqualTo(44));
          expect(find.byIcon(Icons.info_outline), findsOneWidget);
        },
      );
    }

    testWidgets('mobile credit target is at least 48px high', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[KubusColorRoles.light],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: KubusMapAttributionControl(
                semanticsLabel: 'Map attributions',
                onPressed: () {},
                // The mobile map passes its 48px touch target.
                minHeight: 48,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tapTarget = tester.getSize(find.byType(KubusMapAttributionControl));
      expect(tapTarget.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
        'credit wraps to two lines in a narrow map gap, never truncates',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[KubusColorRoles.light],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 200,
                child: KubusMapAttributionControl(
                  semanticsLabel: 'Map attributions',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.getSize(find.text(kubusMapAttributionCredit));
      expect(text.width, lessThanOrEqualTo(200));
      // Two lines of credit: taller than a single 12px label line.
      expect(text.height, greaterThan(20));
      final tapTarget = tester.getSize(find.byType(KubusMapAttributionControl));
      expect(tapTarget.width, lessThanOrEqualTo(200));
    });

    test('credit matches the vendored Kubus styles attribution', () {
      for (final style in const <String>[
        'assets/map_styles/kubus_light.json',
        'assets/map_styles/kubus_dark.json',
      ]) {
        final json = File(style).readAsStringSync();
        expect(json, contains(kubusMapAttributionCredit), reason: style);
      }
    });
  });

  group('map chrome: control cluster', () {
    testWidgets(
        'desktop cluster is one flat surface with grouped, labelled controls '
        'in reading order', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = _buildMapController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: KubusMapPrimaryControls(
                controller: controller,
                layout: KubusMapPrimaryControlsLayout.desktopToolbar,
                onCenterOnMe: () {},
                onCreateMarker: () {},
                centerOnMeActive: false,
                createMarkerHighlighted: true,
                showNearbyToggle: true,
                nearbyActive: false,
                onToggleNearby: () {},
                nearbyTooltipWhenInactive: 'Nearby art',
                zoomInTooltip: 'Zoom in',
                zoomOutTooltip: 'Zoom out',
                centerOnMeTooltip: 'Center on me',
                createMarkerTooltip: 'Create marker here',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flat: no blur layer anywhere in the cluster.
      expect(find.byType(BackdropFilter), findsNothing);

      // Every desktop chrome control clears the 48px map chrome target.
      final buttons = find.byType(KubusMapChromeIconButton);
      expect(buttons, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final size = tester.getSize(buttons.at(i));
        expect(size.width, greaterThanOrEqualTo(48), reason: 'button $i');
        expect(size.height, greaterThanOrEqualTo(48), reason: 'button $i');
      }

      // Reading order: left to right, nearby -> zoom out -> zoom in ->
      // create marker -> center on me. Groups are separated by hairlines.
      const labels = <String>[
        'Nearby art',
        'Zoom out',
        'Zoom in',
        'Create marker here',
        'Center on me',
      ];
      double xOf(String label) =>
          tester.getTopLeft(find.bySemanticsLabel(label).first).dx;
      final xs = labels.map(xOf).toList();
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]), reason: '${labels[i]} order');
      }

      // Keyboard focus follows the same order.
      final visited = <String>[];
      for (var i = 0; i < 12 && visited.length < labels.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        final button =
            focused?.findAncestorWidgetOfExactType<KubusMapChromeIconButton>();
        if (button != null &&
            (visited.isEmpty || visited.last != button.tooltip)) {
          visited.add(button.tooltip);
        }
      }
      expect(visited, labels);

      // The selected state carries the selected flag, not a custom fill.
      final create = tester.getSemantics(
        find.bySemanticsLabel('Create marker here').first,
      );
      expect(create.flagsCollection.isSelected, Tristate.isTrue);

      semantics.dispose();
    });

    testWidgets('mobile rail is one flat cluster with 48px targets',
        (tester) async {
      final controller = _buildMapController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: KubusMapPrimaryControls(
                controller: controller,
                layout: KubusMapPrimaryControlsLayout.mobileRightRail,
                onCenterOnMe: () {},
                onCreateMarker: () {},
                centerOnMeActive: false,
                buttonSize: 48,
                zoomInTooltip: 'Zoom in',
                zoomOutTooltip: 'Zoom out',
                centerOnMeTooltip: 'Center on me',
                createMarkerTooltip: 'Create marker here',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      final buttons = find.byType(KubusMapChromeIconButton);
      expect(buttons, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(buttons.at(i)).height, greaterThanOrEqualTo(48));
      }
      // Vertical order: zoom in above zoom out, create marker last.
      double yOf(String label) =>
          tester.getTopLeft(find.bySemanticsLabel(label).first).dy;
      expect(yOf('Zoom in'), lessThan(yOf('Zoom out')));
      expect(yOf('Zoom out'), lessThan(yOf('Center on me')));
      expect(yOf('Center on me'), lessThan(yOf('Create marker here')));
    });
  });

  group('map chrome: focus indicator', () {
    testWidgets(
        'keyboard focus on a chrome control draws a 2px focus-role ring and no '
        'fill; the Material focus highlight is off', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[KubusColorRoles.light],
          ),
          home: Scaffold(
            body: Center(
              child: KubusMapChromeIconButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ink = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(ink.focusColor, Colors.transparent);
      expect(ink.highlightColor, Colors.transparent);
      expect(ink.hoverColor, Colors.transparent);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(KubusMapChromeIconButton),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.width, 2);
      expect(border.top.color, KubusColorRoles.light.focus);
      // Focus is a ring, not a fill: no background colour behind the icon.
      expect(decoration.color, anyOf(isNull, Colors.transparent));
    });
  });

  group('map chrome: single logo', () {
    testWidgets(
        'the desktop map composition has no second brand mark: the shell rail '
        'owns the logo and the map header is the title and search only',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ArtworkProvider()),
            ChangeNotifierProvider(create: (_) => TaskProvider()),
            ChangeNotifierProvider(create: (_) => WalletProvider()),
            ChangeNotifierProvider(create: (_) => MainTabProvider()),
            ChangeNotifierProvider(create: (_) => MapDeepLinkProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ChangeNotifierProvider(create: (_) => ExhibitionsProvider()),
            ChangeNotifierProvider(create: (_) => EventsProvider()),
            ChangeNotifierProvider(
              create: (_) => ActivationPromptProvider(
                hasAuthSession: () => false,
              ),
            ),
            ChangeNotifierProvider(create: (_) => MarkerManagementProvider()),
            ChangeNotifierProvider(create: (_) => PresenceProvider()),
            Provider<TileProviders>(
              create: (context) => TileProviders(context.read<ThemeProvider>()),
              dispose: (_, value) => value.dispose(),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 900)),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const DesktopMapScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(DesktopMapScreen), findsOneWidget);
      // Map header: the title, and no brand mark beside it.
      expect(find.text('Discover'), findsOneWidget);
      expect(find.byType(AppLogo), findsNothing);
      // The visible credit is present once in the composition.
      expect(find.byType(KubusMapAttributionControl), findsOneWidget);
    });
  });

  group('map chrome: activation prompt', () {
    testWidgets('prompt CTA and dismiss targets are at least 48px high',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final provider = ActivationPromptProvider(hasAuthSession: () => false);
      addTearDown(provider.dispose);
      await tester.runAsync(() async {
        for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
          await provider.recordEntityView();
        }
      });
      expect(provider.shouldPrompt, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<ActivationPromptProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[KubusColorRoles.light],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: KubusActivationPromptCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(KubusMapMetrics.mobileControlSize),
      );
      expect(
        tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(KubusMapMetrics.mobileControlSize),
      );
    });
  });

  group('map chrome: search field semantics', () {
    // The desktop header title sits beside the search field. The field must be
    // its own semantics container: its label is the hint alone and its node is
    // the field's own size. A merged neighbour made the engine size the text
    // input to the whole map, so map and marker taps hit the input instead.
    testWidgets(
        'the desktop search field is its own container: label is the hint and '
        'the node is field-sized', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ArtworkProvider()),
            ChangeNotifierProvider(create: (_) => TaskProvider()),
            ChangeNotifierProvider(create: (_) => WalletProvider()),
            ChangeNotifierProvider(create: (_) => MainTabProvider()),
            ChangeNotifierProvider(create: (_) => MapDeepLinkProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ChangeNotifierProvider(create: (_) => ExhibitionsProvider()),
            ChangeNotifierProvider(create: (_) => EventsProvider()),
            ChangeNotifierProvider(
              create: (_) => ActivationPromptProvider(
                hasAuthSession: () => false,
              ),
            ),
            ChangeNotifierProvider(create: (_) => MarkerManagementProvider()),
            ChangeNotifierProvider(create: (_) => PresenceProvider()),
            Provider<TileProviders>(
              create: (context) => TileProviders(context.read<ThemeProvider>()),
              dispose: (_, value) => value.dispose(),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 900)),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const DesktopMapScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));

      final bar = tester.getSize(find.byType(KubusSearchBar).first);
      final node = tester.getSemantics(find.byType(EditableText).first);
      // The field's own node is the immediate semantics parent of the editable.
      // Before the fix that parent was the merged title ("Discover").
      final parent = node.parent;
      expect(parent, isNotNull);
      expect(parent!.label, isNot(contains('Discover')));
      expect(parent.label, contains('Search artworks'));
      expect(parent.rect.height, lessThanOrEqualTo(bar.height + 1));
      expect(parent.rect.width, lessThanOrEqualTo(bar.width + 1));
      handle.dispose();
    });
  });
}

KubusMapController _buildMapController() {
  return KubusMapController(
    ids: const KubusMapControllerIds(
      layers: MapLayersIds(
        markerSourceId: 'kubus_markers',
        markerLayerId: 'kubus_marker_layer',
        markerHitboxLayerId: 'kubus_marker_hitbox_layer',
        markerHitboxImageId: 'kubus_hitbox_square_transparent',
        markerDotLayerId: 'kubus_marker_dot_layer',
        markerPulseLayerId: 'kubus_marker_pulse_layer',
        cubeLayerId: 'kubus_marker_cubes_layer',
        cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
        locationSourceId: 'kubus_user_location',
        locationLayerId: 'kubus_user_location_layer',
      ),
    ),
    debugTracing: false,
    tapConfig: const KubusMapTapConfig(),
    distance: const Distance(),
  );
}
