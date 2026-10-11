import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/collection_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/creator/creator_kit.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public viewer sees collection actions without empty menu',
      (tester) async {
    final harness = _CollectionHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(CreatorSubjectActionsButton), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('public embedded collection hides the empty menu trigger',
      (tester) async {
    final harness = _CollectionHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
      embedded: true,
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('collection owner can open management actions', (tester) async {
    final harness = _CollectionHarness(owner: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app(const CollectionDetailScreen(
      collectionId: 'collection-1',
      embedded: true,
    )));
    await tester.pumpAndSettle();

    final menu = find.byIcon(Icons.more_horiz);
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the cover title band keeps 4.5:1 over dark and bright photos',
      (tester) async {
    for (final light in [true, false]) {
      final roles = light ? KubusColorRoles.light : KubusColorRoles.dark;
      final brightness = light ? Brightness.light : Brightness.dark;
      final theme = ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: roles.surface,
          brightness: brightness,
        ).copyWith(surface: roles.surface, onSurface: roles.foreground),
        extensions: <ThemeExtension<dynamic>>[roles],
      );
      final harness = _CollectionHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.app(
        const CollectionDetailScreen(collectionId: 'collection-1'),
        theme: theme,
      ));
      await tester.pumpAndSettle();

      // The scrim is the last DecoratedBox in the expanded app bar background.
      final scrim = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(FlexibleSpaceBar),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      final gradient =
          (scrim.decoration as BoxDecoration).gradient as LinearGradient;
      // The title's top edge sits 72 px above the cover's bottom in the 128 px
      // scrim: 0.4375 of the way down the gradient.
      final alpha = _alphaAt(gradient, 0.4375);
      final title = theme.colorScheme.onSurface;
      for (final photo in <Color>[
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      ]) {
        final background = _composite(theme.colorScheme.surface, photo, alpha);
        final ratio = _contrast(title, background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${light ? 'light' : 'dark'} title over $photo: $ratio',
        );
      }
    }
  });
}

/// Alpha of [gradient] at [at] (0..1 from its start), from its colour stops.
double _alphaAt(LinearGradient gradient, double at) {
  final stops = gradient.stops ??
      List<double>.generate(
        gradient.colors.length,
        (i) => i / (gradient.colors.length - 1),
      );
  for (var i = 0; i < stops.length - 1; i++) {
    if (at >= stops[i] && at <= stops[i + 1]) {
      final t = (at - stops[i]) / (stops[i + 1] - stops[i]);
      return gradient.colors[i].a +
          (gradient.colors[i + 1].a - gradient.colors[i].a) * t;
    }
  }
  return gradient.colors.last.a;
}

/// Source-over compositing of [photo] under the scrim [surface] at [alpha].
Color _composite(Color surface, Color photo, double alpha) => Color.from(
      alpha: 1,
      red: surface.r * alpha + photo.r * (1 - alpha),
      green: surface.g * alpha + photo.g * (1 - alpha),
      blue: surface.b * alpha + photo.b * (1 - alpha),
    );

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

class _CollectionHarness {
  _CollectionHarness({bool owner = false})
      : collections = CollectionsProvider(api: _FakeBackendApiService()),
        wallet = WalletProvider(deferInit: true),
        savedItems = SavedItemsProvider(),
        takeover = PublicEntityTakeoverProvider(),
        collab = CollabProvider(api: _FakeCollabApi()),
        profile = ProfileProvider() {
    collections.seedPublicPresentation(const <String, dynamic>{
      'id': 'collection-1',
      'title': 'Public collection',
      'itemCount': 0,
    });
    if (owner) wallet.setCurrentWalletAddressForTesting('owner-wallet');
  }

  final CollectionsProvider collections;
  final WalletProvider wallet;
  final SavedItemsProvider savedItems;
  final PublicEntityTakeoverProvider takeover;
  final CollabProvider collab;
  final ProfileProvider profile;

  Widget app(Widget child, {ThemeData? theme}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CollectionsProvider>.value(value: collections),
          ChangeNotifierProvider<WalletProvider>.value(value: wallet),
          ChangeNotifierProvider<SavedItemsProvider>.value(value: savedItems),
          ChangeNotifierProvider<PublicEntityTakeoverProvider>.value(
            value: takeover,
          ),
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
      );

  void dispose() {
    collections.dispose();
    wallet.dispose();
    savedItems.dispose();
    takeover.dispose();
    collab.dispose();
    profile.dispose();
  }
}

class _FakeBackendApiService implements BackendApiService {
  @override
  Future<Map<String, dynamic>> getCollection(String collectionId) async =>
      <String, dynamic>{
        'id': collectionId,
        'name': 'Public collection',
        'wallet_address': 'owner-wallet',
        'is_public': true,
        'artwork_count': 0,
        'artworks': <dynamic>[],
      };

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollabApi implements CollabApi {
  @override
  Future<List<CollabMember>> listCollaborators(
    String entityType,
    String entityId,
  ) async =>
      <CollabMember>[];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
