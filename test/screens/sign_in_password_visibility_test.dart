import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _buildApp({Size size = const Size(390, 844)}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const Scaffold(body: SignInScreen()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login form shows password visibility toggle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: const Size(390, 844)));
    await tester.pump(const Duration(milliseconds: 700));

    final openEmailForm = find.text('Sign in with email');
    if (openEmailForm.evaluate().isNotEmpty) {
      await tester.tap(openEmailForm.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    } else {
      final showOtherOptions = find.text('Show other options');
      if (showOtherOptions.evaluate().isNotEmpty) {
        await tester.tap(showOtherOptions.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
      final fallbackOpenEmailForm = find.text('Sign in with email');
      if (fallbackOpenEmailForm.evaluate().isNotEmpty) {
        await tester.tap(fallbackOpenEmailForm.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets(
      'desktop sign-in keeps centered auth divider and explicit hover overlay',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: const Size(1366, 900)));
    await tester.pump(const Duration(milliseconds: 700));

    final orLabel = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').trim().toLowerCase() == 'or',
      description: 'localized "or" divider label',
    );
    expect(orLabel, findsWidgets);

    final dividerRow = find.ancestor(
      of: orLabel.first,
      matching: find.byWidgetPredicate(
        (widget) {
          if (widget is! Row) return false;
          final expandedCount = widget.children.whereType<Expanded>().length;
          final hasPadding = widget.children.any((child) => child is Padding);
          return expandedCount == 2 && hasPadding;
        },
        description: 'auth method divider row',
      ),
    );
    expect(dividerRow, findsOneWidget);

    final dividerRowRect = tester.getRect(dividerRow.first);
    final dividerLabelRect = tester.getRect(orLabel.first);
    expect(
      (dividerLabelRect.center.dx - dividerRowRect.center.dx).abs(),
      lessThanOrEqualTo(2.0),
    );

    final desktopSplitRow = find.byWidgetPredicate(
      (widget) {
        if (widget is! Row) return false;
        final hasHeroExpanded =
            widget.children.any((child) => child is Expanded);
        final hasFixedWidthFormRegion = widget.children.any(
          (child) => child is SizedBox && (child.width ?? 0) >= 400,
        );
        return hasHeroExpanded && hasFixedWidthFormRegion;
      },
      description: 'desktop auth split row with fixed form region',
    );
    expect(desktopSplitRow, findsWidgets);

    final ElevatedButton primaryAction =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
    final hoverOverlay = primaryAction.style
        ?.overlayColor
        ?.resolve(<WidgetState>{WidgetState.hovered});
    expect(hoverOverlay, isNotNull);
  });
}
