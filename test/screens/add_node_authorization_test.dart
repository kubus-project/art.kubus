import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/node/add_node_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Records the account decisions the screen makes without reaching the wire.
class _RecordingNodeProvider extends KubusNodeProvider {
  _RecordingNodeProvider({this.found});

  final Map<String, dynamic>? found;
  final List<String> lookups = <String>[];
  final List<String> authorized = <String>[];
  final List<String> declined = <String>[];

  @override
  Future<Map<String, dynamic>> lookupInstallation(String code) async {
    lookups.add(code);
    final result = found;
    if (result == null) throw StateError('not found');
    return result;
  }

  @override
  Future<void> authorizeInstallation(String installationId) async {
    authorized.add(installationId);
  }

  @override
  Future<void> declineInstallation(String installationId) async {
    declined.add(installationId);
  }

  @override
  Future<void> loadOwnedNodes() async {}
}

Widget _app(KubusNodeProvider node) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<KubusNodeProvider>.value(value: node),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const AddNodeScreen(),
      ),
    );

Map<String, dynamic> _installation() => <String, dynamic>{
      'installationId': 'install-1',
      'kind': 'NODE_SETUP',
      'label': 'Studio',
      'fingerprint': 'a' * 64,
    };

void main() {
  testWidgets('the code is uppercased and lookup waits for a full code',
      (tester) async {
    final node = _RecordingNodeProvider(found: _installation());
    await tester.pumpWidget(_app(node));
    await tester.pumpAndSettle();

    // Nothing can be looked up until a whole code is present.
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.enterText(find.byType(TextField), 'abcd23');
    await tester.pumpAndSettle();
    expect(node.lookups, isEmpty);

    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();
    expect(find.text('ABCD2345'), findsOneWidget);

    await tester.tap(find.text('Find Node'));
    await tester.pumpAndSettle();
    expect(node.lookups, ['ABCD2345']);
  });

  testWidgets('the fingerprint and what is granted are shown before deciding',
      (tester) async {
    final node = _RecordingNodeProvider(found: _installation());
    await tester.pumpWidget(_app(node));
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Node'));
    await tester.pumpAndSettle();

    expect(find.text('Authorize this Node?'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
    expect(find.textContaining('a' * 16), findsOneWidget);
    expect(find.textContaining('archive availability'), findsOneWidget);
    // Nothing is granted by merely looking the Node up.
    expect(node.authorized, isEmpty);

    await tester.tap(find.text('Authorize'));
    await tester.pumpAndSettle();
    expect(node.authorized, ['install-1']);
    expect(find.textContaining('Authorized.'), findsOneWidget);
  });

  testWidgets('declining issues nothing and says so', (tester) async {
    final node = _RecordingNodeProvider(found: _installation());
    await tester.pumpWidget(_app(node));
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Node'));
    await tester.pumpAndSettle();

    // The decline action sits below the default 800x600 test viewport.
    await tester.ensureVisible(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(node.declined, ['install-1']);
    expect(node.authorized, isEmpty);
    expect(find.textContaining('No credential was issued'), findsOneWidget);
  });

  testWidgets('an unknown code is reported, not silently swallowed',
      (tester) async {
    final node = _RecordingNodeProvider();
    await tester.pumpWidget(_app(node));
    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Node'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No Node is waiting for that code'),
        findsOneWidget);
    expect(find.text('Authorize this Node?'), findsNothing);
  });
}
