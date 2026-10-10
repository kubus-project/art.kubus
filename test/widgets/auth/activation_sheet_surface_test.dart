import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/widgets/auth/contextual_activation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The activation gate sits over the community screen. Its surface must be
/// opaque: a translucent fill let the composer text and action icons show
/// through the copy and the buttons (seen in light and dark).
void main() {
  Future<void> openGate(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: ThemeData(
          brightness: brightness,
          splashFactory: NoSplash.splashFactory,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showContextualActivationSheet(
                  context,
                  actionType: PendingActionType.like,
                  targetType: PendingActionTargetType.post,
                  fallbackActionLabel: 'like',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
        'the activation gate surface is opaque (${brightness.name} theme)',
        (tester) async {
      await openGate(tester, brightness: brightness);
      expect(find.text('Like this post'), findsOneWidget);

      final surface = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(SingleChildScrollView),
              matching: find.byWidgetPredicate(
                (w) => w is Material && w.shape != null,
              ),
            )
            .first,
      );
      expect(surface.color, isNotNull);
      expect(surface.color!.a, 1.0);
    });
  }

  testWidgets('the Slovenian like button names the action, as the heart does',
      (tester) async {
    final sl = AppLocalizationsSl();
    // The heart reads "Všečkaj"; the confirmation button must use the same verb.
    expect(sl.activationConfirmLikeCta, 'Všečkaj');
  });
}
