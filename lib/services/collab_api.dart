import '../models/collab_invite.dart';
import '../models/collab_member.dart';
import 'backend_api_service.dart';

abstract class CollabApi {
  String? getAuthToken();

  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  );

  Future<List<CollabMember>> listCollaborators(String entityType, String entityId);

  Future<List<CollabInvite>> listMyCollabInvites();

  Future<void> acceptInvite(String inviteId);

  Future<void> declineInvite(String inviteId);

  Future<void> updateCollaboratorRole(
    String entityType,
    String entityId,
    String memberUserId,
    String role,
  );

  Future<void> removeCollaborator(String entityType, String entityId, String memberUserId);
}

class BackendCollabApi implements CollabApi {
  final BackendApiService _backend;

  BackendCollabApi({BackendApiService? backend}) : _backend = backend ?? BackendApiService();

  @override
  String? getAuthToken() => _backend.getAuthToken();

  @override
  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  ) {
    return _backend.inviteCollaborator(entityType, entityId, invitedIdentifier, role);
  }

  @override
  Future<List<CollabMember>> listCollaborators(String entityType, String entityId) {
    return _backend.listCollaborators(entityType, entityId);
  }

  @override
  Future<List<CollabInvite>> listMyCollabInvites() {
    return _backend.listMyCollabInvites();
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    return _backend.acceptInvite(inviteId);
  }

  @override
  Future<void> declineInvite(String inviteId) {
    return _backend.declineInvite(inviteId);
  }

  @override
  Future<void> updateCollaboratorRole(
    String entityType,
    String entityId,
    String memberUserId,
    String role,
  ) {
    return _backend.updateCollaboratorRole(entityType, entityId, memberUserId, role);
  }

  @override
  Future<void> removeCollaborator(String entityType, String entityId, String memberUserId) {
    return _backend.removeCollaborator(entityType, entityId, memberUserId);
  }
}
