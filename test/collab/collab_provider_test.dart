import 'dart:async';

import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCollabApi implements CollabApi {
  @override
  String? getAuthToken() => 'token';

  List<CollabInvite> inbox = <CollabInvite>[];
  Completer<void>? acceptCompleter;
  Completer<void>? declineCompleter;

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async {
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

  @override
  Future<List<CollabMember>> listCollaborators(String entityType, String entityId) {
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
  Future<void> removeCollaborator(String entityType, String entityId, String memberUserId) {
    throw UnimplementedError();
  }
}

void main() {
  test('CollabProvider acceptInvite removes invite before API completes', () async {
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

  test('CollabProvider declineInvite removes invite before API completes', () async {
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
}
