import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/kubus_failure.dart';
import 'package:art_kubus/widgets/states/kubus_product_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

BackendApiRequestException _status(int code, [String? body]) =>
    BackendApiRequestException(statusCode: code, path: '/api/x', body: body);

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('classifyKubusFailure', () {
    test('maps HTTP statuses to distinct kinds', () {
      expect(
          classifyKubusFailure(_status(401)), KubusFailureKind.authentication);
      expect(classifyKubusFailure(_status(403)), KubusFailureKind.permission);
      expect(classifyKubusFailure(_status(404)), KubusFailureKind.notFound);
      expect(classifyKubusFailure(_status(410)), KubusFailureKind.notFound);
      expect(classifyKubusFailure(_status(422)), KubusFailureKind.validation);
      expect(classifyKubusFailure(_status(429)), KubusFailureKind.rateLimit);
      expect(classifyKubusFailure(_status(503)), KubusFailureKind.server);
      expect(classifyKubusFailure(_status(504)), KubusFailureKind.server);
      expect(classifyKubusFailure(_status(501)), KubusFailureKind.unsupported);
    });

    test('separates offline from a failed request', () {
      expect(
        classifyKubusFailure(
            _status(0, 'SocketException: Failed host lookup: api.kubus.site')),
        KubusFailureKind.offline,
      );
      expect(classifyKubusFailure(_status(0, 'Connection reset by peer')),
          KubusFailureKind.network);
      expect(classifyKubusFailure(http.ClientException('XMLHttpRequest error')),
          KubusFailureKind.network);
      expect(classifyKubusFailure(TimeoutException('slow')),
          KubusFailureKind.network);
    });

    test('wallet, unsupported and unknown stay truthful', () {
      expect(classifyKubusFailure(Exception('No wallet connected')),
          KubusFailureKind.wallet);
      expect(classifyKubusFailure(UnsupportedError('AR')),
          KubusFailureKind.unsupported);
      expect(classifyKubusFailure(Exception('boom')), KubusFailureKind.unknown);
      expect(classifyKubusFailure(null), KubusFailureKind.unknown);
    });
  });

  group('KubusStateView recovery', () {
    testWidgets('network offers retry, never raw exception text',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(_app(KubusStateView.fromError(
        _status(0, 'SocketException: Connection reset'),
        onRetry: () => retried = true,
      )));
      expect(find.text("Couldn't reach art.kubus"), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('authentication offers sign in, not retry', (tester) async {
      await tester.pumpWidget(_app(KubusStateView(
        kind: KubusFailureKind.authentication,
        onSignIn: () {},
        onRetry: () {},
      )));
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('permission explains; not found returns; wallet reconnects',
        (tester) async {
      await tester.pumpWidget(_app(KubusStateView(
        kind: KubusFailureKind.permission,
        onRetry: () {},
      )));
      expect(find.text("You don't have access"), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await tester.pumpWidget(_app(KubusStateView(
        kind: KubusFailureKind.notFound,
        onBack: () {},
      )));
      expect(find.text('Back'), findsOneWidget);

      await tester.pumpWidget(_app(KubusStateView(
        kind: KubusFailureKind.wallet,
        onReconnect: () {},
      )));
      expect(find.text('Wallet not ready'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('every kind has distinct EN and SL copy', (tester) async {
      for (final locale in const [Locale('en'), Locale('sl')]) {
        await tester.pumpWidget(_app(const SizedBox(), locale: locale));
        final l10n =
            AppLocalizations.of(tester.element(find.byType(SizedBox)))!;
        final titles = KubusFailureKind.values
            .map((k) => KubusFailureCopy.of(l10n, k).title)
            .toSet();
        expect(titles.length, KubusFailureKind.values.length,
            reason: 'titles must be distinct for $locale');
      }
    });

    testWidgets('page/section/pagination loading are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const Column(
        children: [
          SizedBox(height: 120, child: KubusPageLoading()),
          KubusSectionLoading(rows: 2),
          KubusPaginationLoading(),
        ],
      )));
      expect(find.bySemanticsLabel('Loading'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Loading more'), findsOneWidget);
      expect(tester.getSize(find.byType(KubusPaginationLoading)).height, 48);
      handle.dispose();
    });
  });
}
