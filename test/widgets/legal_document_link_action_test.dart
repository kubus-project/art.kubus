import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/legal_document_link_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  _FakeUrlLauncherPlatform({this.result = true});

  final bool result;
  final List<String> launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return result;
  }
}

Widget _host(Locale locale, LegalDocument document) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LegalDocumentLinkAction(document: document)),
    );

void main() {
  late UrlLauncherPlatform original;

  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  test('canonical legal URLs are the published site pages', () {
    expect(LegalLinks.of(LegalDocument.termsOfUse).toString(),
        'https://art.kubus.site/terms-of-use.html');
    expect(LegalLinks.of(LegalDocument.privacyPolicy).toString(),
        'https://art.kubus.site/privacy-policy.html');
  });

  for (final (locale, terms, privacy) in const [
    (Locale('en'), 'Read full terms', 'Read full privacy policy'),
    (
      Locale('sl'),
      'Preberi celotne pogoje',
      'Preberi celoten pravilnik o zasebnosti'
    ),
  ]) {
    testWidgets('${locale.languageCode}: opens the terms page', (tester) async {
      final launcher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(_host(locale, LegalDocument.termsOfUse));
      await tester.tap(find.text(terms));
      await tester.pumpAndSettle();
      expect(launcher.launchedUrls,
          <String>['https://art.kubus.site/terms-of-use.html']);
    });

    testWidgets('${locale.languageCode}: opens the privacy page',
        (tester) async {
      final launcher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(_host(locale, LegalDocument.privacyPolicy));
      await tester.tap(find.text(privacy));
      await tester.pumpAndSettle();
      expect(launcher.launchedUrls,
          <String>['https://art.kubus.site/privacy-policy.html']);
    });
  }

  group('takedown section link', () {
    test('points at the notice-and-takedown anchor of the Terms page', () {
      expect(LegalLinks.of(LegalDocument.takedownNotice, 'en').toString(),
          'https://art.kubus.site/terms-of-use.html#notice-and-takedown');
      expect(LegalLinks.of(LegalDocument.takedownNotice, 'sl').toString(),
          'https://art.kubus.site/terms-of-use.html#obvestilo-in-odstranitev');
    });

    for (final (locale, label, anchor) in const [
      (Locale('en'), 'How notice and takedown works', '#notice-and-takedown'),
      (
        Locale('sl'),
        'Kako deluje obvestilo in odstranitev',
        '#obvestilo-in-odstranitev'
      ),
    ]) {
      testWidgets('${locale.languageCode}: opens the takedown section',
          (tester) async {
        final launcher = _FakeUrlLauncherPlatform();
        UrlLauncherPlatform.instance = launcher;
        await tester.pumpWidget(_host(locale, LegalDocument.takedownNotice));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(launcher.launchedUrls,
            <String>['https://art.kubus.site/terms-of-use.html$anchor']);
      });
    }
  });

  testWidgets('a refused launch tells the user and names the URL',
      (tester) async {
    UrlLauncherPlatform.instance = _FakeUrlLauncherPlatform(result: false);
    await tester
        .pumpWidget(_host(const Locale('en'), LegalDocument.privacyPolicy));
    await tester.tap(find.text('Read full privacy policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.text('Could not open https://art.kubus.site/privacy-policy.html'),
        findsOneWidget);
  });
}
