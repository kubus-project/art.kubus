import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/content_report_service.dart';
import 'package:art_kubus/widgets/report_content_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContentReportDraft? _result;
bool _closed = false;

Future<void> _open(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  _result = null;
  _closed = false;
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              _result =
                  await showReportContentDialog(context, subject: 'Subject');
              _closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _submit() => find.byKey(const ValueKey<String>('report-submit'));
bool _submitEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit()).onPressed != null;

Future<void> _pick(WidgetTester tester, ReportCategory category) async {
  final tile = find.byKey(ValueKey<String>('report-category-${category.wire}'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('send is disabled until a category is chosen', (tester) async {
    await _open(tester);
    expect(_submitEnabled(tester), isFalse);
    await _pick(tester, ReportCategory.spam);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('an ordinary category sends without a statement', (tester) async {
    await _open(tester);
    await _pick(tester, ReportCategory.harassment);
    expect(
        find.byKey(const ValueKey<String>('report-good-faith')), findsNothing);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(_closed, isTrue);
    expect(_result!.category, ReportCategory.harassment);
    expect(_result!.goodFaithStatement, isFalse);
  });

  testWidgets('copyright needs the good-faith statement and an explanation',
      (tester) async {
    await _open(tester);
    await _pick(tester, ReportCategory.copyright);
    expect(find.byKey(const ValueKey<String>('report-good-faith')),
        findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey<String>('report-details')),
        'This photograph is mine.');
    await tester.pump();
    expect(_submitEnabled(tester), isFalse, reason: 'statement still missing');

    final box = find.byKey(const ValueKey<String>('report-good-faith'));
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(_submitEnabled(tester), isTrue);

    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(_result!.category, ReportCategory.copyright);
    expect(_result!.goodFaithStatement, isTrue);
    expect(_result!.details, 'This photograph is mine.');
  });

  testWidgets('switching away from a notice category drops the statement',
      (tester) async {
    await _open(tester);
    await _pick(tester, ReportCategory.illegalContent);
    final box = find.byKey(const ValueKey<String>('report-good-faith'));
    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pumpAndSettle();
    await _pick(tester, ReportCategory.spam);
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(_result!.category, ReportCategory.spam);
    expect(_result!.goodFaithStatement, isFalse);
  });

  testWidgets('an invalid contact address blocks sending and is explained',
      (tester) async {
    await _open(tester);
    await _pick(tester, ReportCategory.spam);
    final email = find.byKey(const ValueKey<String>('report-contact-email'));
    await tester.ensureVisible(email);
    await tester.enterText(email, 'not-an-address');
    await tester.pump();
    expect(_submitEnabled(tester), isFalse);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(email, 'me@example.test');
    await tester.pump();
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('cancel returns nothing', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_closed, isTrue);
    expect(_result, isNull);
  });

  testWidgets('Slovenian shows every label in Slovenian', (tester) async {
    await _open(tester, locale: const Locale('sl'));
    expect(find.text('Prijavi vsebino'), findsOneWidget);
    expect(find.text('Nezakonita vsebina'), findsOneWidget);
    expect(find.text('Avtorske ali druge pravice'), findsOneWidget);
    expect(find.text('Pošlji prijavo'), findsOneWidget);
    await _pick(tester, ReportCategory.copyright);
    expect(find.textContaining('V dobri veri izjavljam'), findsOneWidget);
  });
}
