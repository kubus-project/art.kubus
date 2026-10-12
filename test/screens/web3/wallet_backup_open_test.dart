import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_backup_protection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouteCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

Widget _app({
  required Widget child,
  List<Widget>? pushed,
  NavigatorObserver? observer,
}) {
  Widget body = Builder(
    builder: (context) => TextButton(
      onPressed: () => openWalletBackupProtection(context),
      child: const Text('open'),
    ),
  );
  if (pushed != null) {
    body = DesktopShellScope(
      pushScreen: pushed.add,
      popScreen: () {},
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (_, {content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: false,
      child: body,
    );
  }
  return MaterialApp(
    navigatorObservers: [if (observer != null) observer],
    home: Scaffold(body: body),
  );
}

void main() {
  testWidgets('inside the desktop shell backup opens in the shell, not a route',
      (tester) async {
    final pushed = <Widget>[];
    final observer = _RouteCounter();
    await tester.pumpWidget(
        _app(child: const SizedBox(), pushed: pushed, observer: observer));
    final routesBefore = observer.pushes;

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(pushed.single, isA<WalletBackupProtectionScreen>());
    expect(observer.pushes, routesBefore);
  });
}
