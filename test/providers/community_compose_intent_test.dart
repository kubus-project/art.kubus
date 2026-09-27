import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a remembered compose intent is returned once', () {
    final hub = CommunityHubProvider();
    expect(hub.hasPendingComposeIntent, isFalse);
    hub.rememberComposeIntentForAuth(CommunityComposeIntent.createGroup);
    expect(hub.hasPendingComposeIntent, isTrue);
    expect(hub.takeComposeIntent(), CommunityComposeIntent.createGroup);
    expect(hub.takeComposeIntent(), isNull);
    expect(hub.hasPendingComposeIntent, isFalse);
  });

  test('a stale compose intent is dropped instead of reopening later', () {
    final hub = CommunityHubProvider();
    hub.rememberComposeIntentForAuth(CommunityComposeIntent.post);
    expect(hub.takeComposeIntent(maxAge: Duration.zero), isNull);
    expect(hub.hasPendingComposeIntent, isFalse);
  });
}
