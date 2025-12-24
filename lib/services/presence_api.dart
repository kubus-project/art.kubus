import '../services/backend_api_service.dart';

abstract class PresenceApi {
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets);

  Future<void> ensureAuthLoaded({String? walletAddress});

  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  });
}

class BackendPresenceApi implements PresenceApi {
  final BackendApiService _backend;

  BackendPresenceApi({BackendApiService? backend}) : _backend = backend ?? BackendApiService();

  @override
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) {
    return _backend.getPresenceBatch(wallets);
  }

  @override
  Future<void> ensureAuthLoaded({String? walletAddress}) {
    return _backend.ensureAuthLoaded(walletAddress: walletAddress);
  }

  @override
  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  }) {
    return _backend.recordPresenceVisit(type: type, id: id, walletAddress: walletAddress);
  }
}

