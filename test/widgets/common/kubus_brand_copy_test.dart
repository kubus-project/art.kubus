import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_family_brand.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/unavailable_entity_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_screen_harness.dart';

/// The brand is lowercase everywhere and `kubus` is always bold italic where
/// the UI can style it. The pilot strings below are plain l10n values, so the
/// styling comes from [KubusFamilyBrandText] at the point they are shown.
void main() {
  final pilotStrings = <String, String Function(AppLocalizations)>{
    'spatialReconstructionFree': (l) => l.spatialReconstructionFree,
    'spatialReconstructionCancelling': (l) => l.spatialReconstructionCancelling,
    'spatialReconstructionWaiting': (l) => l.spatialReconstructionWaiting,
    'spatialReconstructionProcessing': (l) => l.spatialReconstructionProcessing,
    'spatialSourceProviderDisclosure': (l) => l.spatialSourceProviderDisclosure,
    'spatialProgressRemoteBody': (l) => l.spatialProgressRemoteBody,
    'spatialProcessNetworkTitle': (l) => l.spatialProcessNetworkTitle,
    'spatialRemotePrivacyTitle': (l) => l.spatialRemotePrivacyTitle,
    'authSignInTitle': (l) => l.authSignInTitle,
    'spatialProgressLeaveHint': (l) => l.spatialProgressLeaveHint,
    'spatialPilotNodeExplanation': (l) => l.spatialPilotNodeExplanation,
    'kubusNodeOfferGpu': (l) => l.kubusNodeOfferGpu,
    'kubusNodeOfferGpuBody': (l) => l.kubusNodeOfferGpuBody,
    'kubusNodeDownloadAction': (l) => l.kubusNodeDownloadAction,
  };

  List<TextSpan> brandRuns(InlineSpan root) {
    final runs = <TextSpan>[];
    root.visitChildren((span) {
      if (span is TextSpan && span.text?.toLowerCase() == 'kubus') {
        runs.add(span);
      }
      return true;
    });
    return runs;
  }

  test('no ARB value spells the brand with a capital K', () {
    for (final locale in ['en', 'sl']) {
      final text = File('lib/l10n/app_$locale.arb').readAsStringSync();
      expect(RegExp(r'Kubus').allMatches(text).length, 0,
          reason: 'app_$locale.arb must say kubus, never Kubus');
    }
  });

  for (final locale in ['en', 'sl']) {
    group('pilot strings in $locale', () {
      final l10n = lookupAppLocalizations(Locale(locale));
      pilotStrings.forEach((key, read) {
        test('$key renders kubus bold italic, lowercase', () {
          final text = read(l10n);
          expect(text, isNot(contains('Kubus')));
          final span = KubusFamilyBrandText.span(text);
          expect(span.toPlainText(), text);
          if (!KubusFamilyBrandText.containsBrandToken(text)) {
            // Not every key names the brand in every locale.
            expect(text.toLowerCase(), isNot(matches(r'(^|\W)kubus(\W|$)')));
            return;
          }
          final runs = brandRuns(span);
          expect(runs, isNotEmpty);
          for (final run in runs) {
            expect(run.text, 'kubus');
            expect(run.style?.fontStyle, FontStyle.italic);
            expect(run.style?.fontWeight, FontWeight.w800);
          }
        });
      });
    });
  }

  testWidgets('KubusFamilyBrandText paints the brand bold italic',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: KubusFamilyBrandText('Processing on the kubus network.'),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).last);
    final runs = brandRuns(rich.text);
    expect(runs.single.style?.fontStyle, FontStyle.italic);
    expect(runs.single.style?.fontWeight, FontWeight.w800);
    expect(find.text('Processing on the kubus network.'), findsOneWidget);
  });

  testWidgets('plain copy without the brand is left untouched', (tester) async {
    final span = KubusFamilyBrandText.span('Sign in to continue',
        style: const TextStyle(fontSize: 12));
    expect(span.children, isNull);
    expect(span.text, 'Sign in to continue');
  });

  testWidgets(
      'the public-entry header bar renders art.kubus with kubus bold '
      'italic', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KubusScreenHeaderBar(
          title: 'art.kubus',
          brandTitle: true,
          compact: true,
          titleStyle: KubusTextStyles.screenTitle,
        ),
      ),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final runs = brandRuns(rich.text);
    expect(runs, hasLength(1));
    expect(runs.single.style?.fontStyle, FontStyle.italic);
    expect(runs.single.style?.fontWeight, FontWeight.w800);
    expect(rich.text.toPlainText(), 'art.kubus');
  });

  testWidgets('without brandTitle the header bar title stays plain',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KubusScreenHeaderBar(title: 'art.kubus', compact: true),
      ),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(brandRuns(rich.text), isEmpty);
  });

  testWidgets(
      'the unavailable public artwork page titles art.kubus in brand '
      'style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UnavailableEntityScaffold(
        entityLabel: 'Artwork',
        reason: UnavailableEntityReason.notFound,
        onRetry: () {},
        canonicalPublicEntry: true,
      ),
    ));
    await tester.pump();
    final bar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(RichText),
    );
    final runs = brandRuns(tester.widget<RichText>(bar.first).text);
    expect(runs, hasLength(1));
    expect(runs.single.style?.fontStyle, FontStyle.italic);
  });

  test('brand-bearing pilot strings are never handed to a plain Text', () {
    // Each of these l10n values names kubus, so the UI must show it through
    // KubusFamilyBrandText; a plain Text(...) would render kubus upright.
    final plain = RegExp(
      r'\bText\(\s*(?:_?l10n|AppLocalizations\.of\(context\)!?)\.'
      r'(spatialProgressLeaveHint|spatialPilotNodeExplanation|'
      r'kubusNodeOfferGpu|kubusNodeOfferGpuBody|kubusNodeDownloadAction|'
      r'spatialReconstructionFree|spatialReconstructionCancelling|'
      r'spatialReconstructionWaiting|spatialReconstructionProcessing|'
      r'spatialSourceProviderDisclosure|spatialProgressRemoteBody|'
      r'spatialProcessNetworkTitle|spatialRemotePrivacyTitle|'
      r'spatialResultReviewBody|spatialFailedLocalBody|'
      r'spatialProcessOwnNodeSubtitle|availabilityNodeTitle)\b',
    );
    // Positive controls: the pattern must bite a plain Text and spare the
    // brand widget, otherwise this scan is silently vacuous.
    expect(plain.hasMatch('Text(l10n.kubusNodeOfferGpu)'), isTrue);
    expect(
        plain.hasMatch('child: Text(   l10n.availabilityNodeTitle,'), isTrue);
    expect(plain.hasMatch('KubusFamilyBrandText(l10n.kubusNodeOfferGpu)'),
        isFalse);
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n')) continue;
      final source = entity.readAsStringSync();
      if (plain.hasMatch(source)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty);
  });

  testWidgets(
      'the public profile app bar renders art.kubus with kubus bold italic',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.mobilePublic,
      canonicalPublicEntry: true,
    );
    final bar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(RichText),
    );
    final texts = tester.widgetList<RichText>(bar).toList();
    final branded = texts.where((t) => t.text.toPlainText() == 'art.kubus');
    expect(branded, hasLength(1));
    final runs = brandRuns(branded.single.text);
    expect(runs, hasLength(1));
    expect(runs.single.style?.fontStyle, FontStyle.italic);
    expect(runs.single.style?.fontWeight, FontWeight.w800);
  });
}
