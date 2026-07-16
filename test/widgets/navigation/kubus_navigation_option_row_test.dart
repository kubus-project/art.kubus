import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/navigation/kubus_navigation_option_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('in-app and external rows share the same compact layout contract',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KubusNavigationOptionRow(
                key: const ValueKey('in-app'),
                icon: Icons.directions_walk_outlined,
                label: 'In-app walking navigation',
                statusLabel: 'Beta',
                onTap: () {},
              ),
              KubusNavigationOptionRow(
                key: const ValueKey('external'),
                icon: Icons.map_outlined,
                label: 'Google Maps',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final inApp = tester.getSize(find.byKey(const ValueKey('in-app')));
    final external = tester.getSize(find.byKey(const ValueKey('external')));
    expect(inApp.height, KubusSizes.navigationOptionRowHeight);
    expect(external.height, inApp.height);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('sl')]) {
    for (final width in <double>[360, 390, 768, 1280]) {
      testWidgets(
        'compact navigation row handles ${locale.languageCode} at ${width.toInt()}px',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (context) => Scaffold(
                  body: KubusNavigationOptionRow(
                    icon: Icons.directions_walk_outlined,
                    label:
                        AppLocalizations.of(context)!.artDetailNavigationInApp,
                    statusLabel:
                        AppLocalizations.of(context)!.walkingNavigationBeta,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(KubusNavigationOptionRow), findsOneWidget);
        },
      );
    }
  }
}
