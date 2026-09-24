import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/common/kubus_reading_surface.dart';
import 'package:art_kubus/widgets/detail/expandable_detail_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public artwork description stays inside a 320 px detail column',
      (tester) async {
    const viewportWidth = 320.0;
    const description =
        'A public installation tracing the changing relationship between the '
        'Ljubljanica river, its neighborhoods and the shared memory of the city.';

    await tester.binding.setSurfaceSize(const Size(viewportWidth, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Description'),
                  KubusReadingSurface(
                    child: const ExpandableDetailText(text: description),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.getRect(find.byType(KubusReadingSurface));
    final descriptionText = tester.getRect(find.text(description));

    expect(surface.left, greaterThanOrEqualTo(0));
    expect(surface.right, lessThanOrEqualTo(viewportWidth));
    expect(descriptionText.right, lessThanOrEqualTo(surface.right));
    expect(tester.takeException(), isNull);
  });
}
