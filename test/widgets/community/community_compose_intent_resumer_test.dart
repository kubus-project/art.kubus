import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/widgets/community/community_compose_intent_resumer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _app(
  CommunityHubProvider hub, {
  required bool isSignedIn,
  required List<CommunityComposeIntent> resumed,
}) {
  return ChangeNotifierProvider<CommunityHubProvider>.value(
    value: hub,
    child: MaterialApp(
      home: CommunityComposeIntentResumer(
        isSignedIn: isSignedIn,
        onResume: resumed.add,
        child: const Text('community'),
      ),
    ),
  );
}

void main() {
  for (final intent in CommunityComposeIntent.values) {
    testWidgets('reopens ${intent.name} once the guest is signed in',
        (tester) async {
      final hub = CommunityHubProvider();
      final resumed = <CommunityComposeIntent>[];
      hub.rememberComposeIntentForAuth(intent);

      // Still a guest (sign-in in progress): nothing opens.
      await tester.pumpWidget(_app(hub, isSignedIn: false, resumed: resumed));
      await tester.pump();
      expect(resumed, isEmpty);
      expect(hub.hasPendingComposeIntent, isTrue);

      // Authentication completed: the requested surface opens exactly once.
      await tester.pumpWidget(_app(hub, isSignedIn: true, resumed: resumed));
      await tester.pump();
      expect(resumed, [intent]);

      await tester.pumpWidget(_app(hub, isSignedIn: true, resumed: resumed));
      await tester.pump();
      expect(resumed, [intent]);
      expect(hub.hasPendingComposeIntent, isFalse);
    });
  }

  testWidgets('a signed-in viewer with no remembered intent opens nothing',
      (tester) async {
    final hub = CommunityHubProvider();
    final resumed = <CommunityComposeIntent>[];
    await tester.pumpWidget(_app(hub, isSignedIn: true, resumed: resumed));
    await tester.pump();
    expect(resumed, isEmpty);
  });

  testWidgets(
      'waits for the sign-in route to close before consuming the intent',
      (tester) async {
    final hub = CommunityHubProvider();
    final navigator = GlobalKey<NavigatorState>();
    final signedIn = ValueNotifier(false);
    final resumed = <CommunityComposeIntent>[];
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: hub,
      child: MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<bool>(
          valueListenable: signedIn,
          builder: (_, value, __) => CommunityComposeIntentResumer(
            isSignedIn: value,
            onResume: resumed.add,
            child: const Text('community'),
          ),
        ),
      ),
    ));
    hub.rememberComposeIntentForAuth(CommunityComposeIntent.post);
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('sign-in')),
    ));
    await tester.pumpAndSettle();
    signedIn.value = true;
    await tester.pump();
    expect(resumed, isEmpty);
    expect(hub.hasPendingComposeIntent, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(resumed, [CommunityComposeIntent.post]);
    expect(hub.hasPendingComposeIntent, isFalse);
    signedIn.dispose();
  });
}
