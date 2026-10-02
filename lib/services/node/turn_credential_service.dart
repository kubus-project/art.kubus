import '../backend_api_service.dart';
import 'turn_configuration.dart';

/// Service boundary for short-lived relay credentials.
///
/// It intentionally exposes only an ICE configuration, never a raw backend
/// response, bearer token, or TURN wire fields to providers and widgets.
abstract interface class TurnCredentialSource {
  Future<IceConfiguration> fetchTurnIceConfiguration();
}

class BackendTurnCredentialSource implements TurnCredentialSource {
  BackendTurnCredentialSource([BackendApiService? backend])
      : _backend = backend ?? BackendApiService();

  final BackendApiService _backend;

  @override
  Future<IceConfiguration> fetchTurnIceConfiguration() =>
      _backend.fetchTurnIceConfiguration();
}

class TurnCredentialService {
  TurnCredentialService({TurnCredentialSource? source})
      : _source = source ?? BackendTurnCredentialSource();

  final TurnCredentialSource _source;

  Future<IceConfiguration> loadIceConfiguration() =>
      _source.fetchTurnIceConfiguration();
}
