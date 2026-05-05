import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _buildApp({
  required ConnectWallet child,
}) {
  return ChangeNotifierProvider<WalletProvider>(
    create: (_) => WalletProvider(deferInit: true),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

dynamic _state(WidgetTester tester) {
  return tester.state(find.byType(ConnectWallet)) as dynamic;
}

Map<String, dynamic> _dataUser(Object? payload) {
  final map = payload as Map<String, dynamic>;
  final data = map['data'] as Map<String, dynamic>;
  return data['user'] as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('debugBuildWalletAuthPayload builds standard user payload',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: const ConnectWallet(embedded: true),
      ),
    );

    final payload = _state(tester).debugBuildWalletAuthPayload(' wallet-1 ');
    expect(_dataUser(payload)['walletAddress'], 'wallet-1');
  });

  testWidgets('debugBuildWalletAuthPayload preserves response data and user',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: const ConnectWallet(embedded: true),
      ),
    );

    final payload = _state(tester).debugBuildWalletAuthPayload(
      'wallet-2',
      response: const <String, dynamic>{
        'token': 'token-value',
        'data': <String, dynamic>{
          'source': 'backend',
          'user': <String, dynamic>{'id': 'u1'},
        },
      },
      user: const <String, dynamic>{'displayName': 'Artist'},
    ) as Map<String, dynamic>;

    expect(payload['token'], 'token-value');
    expect((payload['data'] as Map<String, dynamic>)['source'], 'backend');
    final user = _dataUser(payload);
    expect(user['id'], 'u1');
    expect(user['displayName'], 'Artist');
    expect(user['walletAddress'], 'wallet-2');
  });

  testWidgets('auth-entry close returns a Map payload', (tester) async {
    Object? completedResult;
    await tester.pumpWidget(
      _buildApp(
        child: ConnectWallet(
          embedded: true,
          telemetryAuthFlow: 'sign_in',
          onFlowComplete: (result) {
            completedResult = result;
          },
        ),
      ),
    );

    expect(_state(tester).debugIsAuthEntryFlow, isTrue);
    _state(tester).debugCloseSuccessfulAuthFlow(walletAddress: 'wallet-3');

    expect(completedResult, isA<Map<String, dynamic>>());
    expect(_dataUser(completedResult)['walletAddress'], 'wallet-3');
  });

  testWidgets('authInline is treated as auth-entry flow', (tester) async {
    Object? completedResult;
    await tester.pumpWidget(
      _buildApp(
        child: ConnectWallet(
          embedded: true,
          authInline: true,
          onFlowComplete: (result) {
            completedResult = result;
          },
        ),
      ),
    );

    expect(_state(tester).debugIsAuthEntryFlow, isTrue);
    _state(tester).debugCloseSuccessfulAuthFlow(walletAddress: 'wallet-4');

    expect(completedResult, isA<Map<String, dynamic>>());
    expect(_dataUser(completedResult)['walletAddress'], 'wallet-4');
  });

  testWidgets('auth-entry connected close returns current wallet payload',
      (tester) async {
    Object? completedResult;
    await tester.pumpWidget(
      _buildApp(
        child: ConnectWallet(
          embedded: true,
          authInline: true,
          onFlowComplete: (result) {
            completedResult = result;
          },
        ),
      ),
    );
    Provider.of<WalletProvider>(
      tester.element(find.byType(ConnectWallet)),
      listen: false,
    ).setCurrentWalletAddressForTesting('wallet-connected');

    _state(tester).debugCloseConnectedWalletFlow();

    expect(completedResult, isA<Map<String, dynamic>>());
    expect(_dataUser(completedResult)['walletAddress'], 'wallet-connected');
  });

  testWidgets('non-auth success close preserves response behavior',
      (tester) async {
    Object? completedResult;
    const response = <String, dynamic>{'status': 'connected'};
    await tester.pumpWidget(
      _buildApp(
        child: ConnectWallet(
          embedded: true,
          onFlowComplete: (result) {
            completedResult = result;
          },
        ),
      ),
    );

    expect(_state(tester).debugIsAuthEntryFlow, isFalse);
    _state(tester).debugCloseSuccessfulAuthFlow(
      walletAddress: 'wallet-5',
      response: response,
    );

    expect(completedResult, response);
  });
}
