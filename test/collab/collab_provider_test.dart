import 'dart:async';

import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCollabApi implements CollabApi {
  @override
  String? getAuthToken() => 'token';

  List<CollabInvite> inbox = <CollabInvite>[];
  Object? listFailure;
  Completer<void>? acceptCompleter;
  Completer<void>? declineCompleter;

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async {
    final failure = listFailure;
    if (failure != null) throw failure;
    return List<CollabInvite>.from(inbox);
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    final completer = acceptCompleter;
    if (completer == null) {
      inbox = inbox.where((i) => i.id != inviteId).toList(growable: false);
      return Future.value();
    }
    return completer.future.then((_) {
      inbox = inbox.where((i) => i.id != inviteId).toList(growable: false);
    });
  }

  @override
  Future<void> declineInvite(String inviteId) {
    final completer = declineCompleter;
    if (completer == null) {
      inbox = inbox.where((i) => i.id != inviteId).toList(growable: false);
      return Future.value();
    }
    return completer.future.then((_) {
      inbox = inbox.where((i) => i.id != inviteId).toList(growable: false);
    });
  }

  @override
  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  ) {
    throw UnimplementedError();
  }

  Object? collaboratorsFailure;

  @override
  Future<List<CollabMember>> listCollaborators(
      String entityType, String entityId) async {
    final failure = collaboratorsFailure;
    if (failure != null) throw failure;
    throw UnimplementedError();
  }

  @override
  Future<void> updateCollaboratorRole(
    String entityType,
    String entityId,
    String memberUserId,
    String role,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeCollaborator(
      String entityType, String entityId, String memberUserId) {
    throw UnimplementedError();
  }
}

void main() {
  test('CollabProvider keeps the typed invite load failure, then clears it',
      () async {
    SharedPreferences.setMockInitialValues({});
    const unauthorized = BackendApiRequestException(
      statusCode: 401,
      path: '/api/collab/invites',
      body: 'jwt expired',
    );
    final api = _FakeCollabApi()..listFailure = unauthorized;
    final provider = CollabProvider(api: api);
    addTearDown(provider.dispose);

    await provider.initialize(refresh: true);
    // The caught object survives (status intact) for classification.
    expect(provider.invitesError, same(unauthorized));

    api.listFailure = const BackendApiRequestException(
      statusCode: 503,
      path: '/api/collab/invites',
    );
    await provider.refreshInvites();
    expect(
      provider.invitesError,
      isA<BackendApiRequestException>()
          .having((error) => error.statusCode, 'statusCode', 503),
    );

    api.listFailure = null;
    await provider.refreshInvites();
    expect(provider.invitesError, isNull);
    expect(provider.error, isNull);
  });

  test('CollabProvider acceptInvite removes invite before API completes',
      () async {
    SharedPreferences.setMockInitialValues({});

    const invite = CollabInvite(
      id: 'invite_1',
      entityType: 'exhibitions',
      entityId: '11111111-1111-4111-8111-111111111111',
      invitedUserId: 'user_1',
      invitedByUserId: 'user_2',
      role: 'viewer',
      status: 'pending',
    );

    final api = _FakeCollabApi()
      ..inbox = <CollabInvite>[invite]
      ..acceptCompleter = Completer<void>();

    final provider = CollabProvider(api: api);
    addTearDown(provider.dispose);

    await provider.initialize(refresh: true);
    expect(provider.pendingInviteCount, 1);

    final future = provider.acceptInvite(invite.id);
    expect(provider.pendingInviteCount, 0);
    expect(provider.isLoading, true);

    api.acceptCompleter!.complete();
    await future;

    expect(provider.pendingInviteCount, 0);
    expect(provider.isLoading, false);
  });

  test('CollabProvider restores an optimistic invite after a typed failure',
      () async {
    SharedPreferences.setMockInitialValues({});

    const invite = CollabInvite(
      id: 'invite_failed',
      entityType: 'artworks',
      entityId: '33333333-3333-4333-8333-333333333333',
      invitedUserId: 'user_1',
      invitedByUserId: 'user_2',
      role: 'editor',
      status: 'pending',
    );
    const requestError = BackendApiRequestException(
      statusCode: 503,
      path: '/api/collab/invites/invite_failed/accept',
      body: 'temporarily unavailable',
    );
    final api = _FakeCollabApi()
      ..inbox = <CollabInvite>[invite]
      ..acceptCompleter = Completer<void>();
    final provider = CollabProvider(api: api);
    addTearDown(provider.dispose);

    await provider.initialize(refresh: true);
    final future = provider.acceptInvite(invite.id);
    final expectation = expectLater(
      future,
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503),
      ),
    );
    expect(provider.pendingInviteCount, 0);

    api.acceptCompleter!.completeError(requestError);
    await expectation;

    expect(provider.pendingInviteCount, 1);
    expect(provider.invitesInbox.single.id, invite.id);
    expect(provider.error, contains('temporarily unavailable'));
    expect(provider.isLoading, false);
  });

  test('CollabProvider declineInvite removes invite before API completes',
      () async {
    SharedPreferences.setMockInitialValues({});

    const invite = CollabInvite(
      id: 'invite_2',
      entityType: 'events',
      entityId: '22222222-2222-4222-8222-222222222222',
      invitedUserId: 'user_1',
      invitedByUserId: 'user_2',
      role: 'editor',
      status: 'pending',
    );

    final api = _FakeCollabApi()
      ..inbox = <CollabInvite>[invite]
      ..declineCompleter = Completer<void>();

    final provider = CollabProvider(api: api);
    addTearDown(provider.dispose);

    await provider.initialize(refresh: true);
    expect(provider.pendingInviteCount, 1);

    final future = provider.declineInvite(invite.id);
    expect(provider.pendingInviteCount, 0);
    expect(provider.isLoading, true);

    api.declineCompleter!.complete();
    await future;

    expect(provider.pendingInviteCount, 0);
    expect(provider.isLoading, false);
  });

  test('a background collaborator refresh keeps its failure and throws nothing',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeCollabApi()
      ..collaboratorsFailure = const BackendApiRequestException(
        statusCode: 503,
        path: '/api/collab/artwork/a1/members',
      );
    final provider = CollabProvider(api: api);
    addTearDown(provider.dispose);

    // Unlike loadCollaborators, this is safe to fire without awaiting.
    await provider.refreshCollaboratorsInBackground('artwork', 'a1');

    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  group('the invite inbox follows the signed-in account, not a wallet', () {
    const invite = CollabInvite(
      id: 'invite_1',
      entityType: 'exhibitions',
      entityId: '11111111-1111-4111-8111-111111111111',
      invitedUserId: 'e10d1421-019f-481a-8065-637f1fad53ed',
      invitedByUserId: 'user_2',
      role: 'viewer',
      status: 'pending',
    );

    UserProfile profile({String wallet = '', String id = 'profile-1'}) =>
        UserProfile(
          id: id,
          userId: 'e10d1421-019f-481a-8065-637f1fad53ed',
          walletAddress: wallet,
          username: 'artist',
          displayName: 'Artist',
          bio: '',
          avatar: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    Future<CollabProvider> bind(_FakeCollabApi api, ProfileProvider p) async {
      final provider = CollabProvider(api: api);
      addTearDown(provider.dispose);
      provider.bindProfileProvider(p);
      // initialize() runs unawaited from the bind; let it finish.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return provider;
    }

    test('a walletless signed-in artist loads their invites', () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeCollabApi()..inbox = <CollabInvite>[invite];

      final provider =
          await bind(api, ProfileProvider()..setCurrentUser(profile()));

      expect(provider.pendingInviteCount, 1);
    });

    test('a wallet artist still loads their invites', () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeCollabApi()..inbox = <CollabInvite>[invite];

      final provider = await bind(
        api,
        ProfileProvider()
          ..setCurrentUser(
            profile(wallet: 'ArtistWallet111111111111111111111111111111111'),
          ),
      );

      expect(provider.pendingInviteCount, 1);
    });

    test('a guest has no inbox', () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeCollabApi()..inbox = <CollabInvite>[invite];

      final provider = await bind(api, ProfileProvider());

      expect(provider.pendingInviteCount, 0);
    });

    test('a locally invented profile id is not an identity', () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeCollabApi()..inbox = <CollabInvite>[invite];
      final placeholder = UserProfile(
        id: 'profile_e10d1421',
        walletAddress: '',
        username: 'artist',
        displayName: 'Artist',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider =
          await bind(api, ProfileProvider()..setCurrentUser(placeholder));

      expect(provider.pendingInviteCount, 0);
    });
  });
}
