import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kubus_node_models.dart';
import '../services/kubus_node_service.dart';
import '../services/backend_api_service.dart';
import '../services/node/turn_credential_service.dart';
import '../services/node/kubus_node_transport.dart';
import '../services/node/node_identity_proof.dart';

class KubusNodeProvider extends ChangeNotifier {
  KubusNodeProvider({
    KubusNodeService? service,
    TurnCredentialService? turnCredentialService,
  })  : service = service ?? KubusNodeService(),
        _turnCredentialService =
            turnCredentialService ?? TurnCredentialService();
  final KubusNodeService service;
  final TurnCredentialService _turnCredentialService;
  KubusNodeConnectionState _state = KubusNodeConnectionState.unpaired;
  KubusNodeSnapshot? _snapshot;
  List<KubusNodeJob> _jobs = const [];
  List<KubusComputeCandidate> _computeCandidates = const [];
  KubusRemoteComputeJob? _remoteJob;
  Map<String, dynamic> _computeSettings = const {};
  String? _error;
  Object? _connectionFailure;
  bool _initialized = false;
  KubusNodeConnectionState get state => _state;
  KubusNodeSnapshot? get snapshot => _snapshot;
  List<KubusNodeJob> get jobs => _jobs;
  List<KubusComputeCandidate> get computeCandidates => _computeCandidates;
  KubusRemoteComputeJob? get remoteJob => _remoteJob;
  Map<String, dynamic> get computeSettings => _computeSettings;
  bool get computeSettingsAvailable =>
      _computeSettings.isNotEmpty &&
      _snapshot?.capabilityAvailable('compute.remoteJobs') == true;
  String? get error => _error;
  bool get isPaired => service.isPaired;
  KubusNodeConnectionDetail get connectionDetail {
    if (_state == KubusNodeConnectionState.connecting) {
      return KubusNodeConnectionDetail.attaching;
    }
    if (_connectionFailure is KubusNodeIdentityException ||
        _connectionFailure is NodeIdentityException) {
      return KubusNodeConnectionDetail.identityMismatch;
    }
    if (_state == KubusNodeConnectionState.paired) {
      final authorization = _snapshot?.status['computeAuthorization'];
      if (authorization is Map &&
          authorization['state'] == 'COMPUTE_AUTHORIZATION_REQUIRED') {
        return KubusNodeConnectionDetail.computeAuthorizationRequired;
      }
      return switch (service.activeTransport) {
        KubusNodeTransportKind.localDirect =>
          KubusNodeConnectionDetail.lanConnected,
        KubusNodeTransportKind.webRtcDirect =>
          KubusNodeConnectionDetail.webRtcDirectConnected,
        KubusNodeTransportKind.webRtcRelay =>
          KubusNodeConnectionDetail.turnConnected,
        KubusNodeTransportKind.remoteHttps =>
          KubusNodeConnectionDetail.httpsConnected,
        null => KubusNodeConnectionDetail.error,
      };
    }
    if (isPaired) return KubusNodeConnectionDetail.pairedOffline;
    if (_ownedNodes.any((node) => node['remoteAttachAvailable'] == true)) {
      return KubusNodeConnectionDetail.ownedNodeAvailable;
    }
    if (_error != null) return KubusNodeConnectionDetail.error;
    return KubusNodeConnectionDetail.noNode;
  }

  List<Map<String, dynamic>> _ownedNodes = const [];
  List<Map<String, dynamic>> get ownedNodes => List.unmodifiable(_ownedNodes);
  bool _loadingOwnedNodes = false;
  bool get loadingOwnedNodes => _loadingOwnedNodes;
  String? _discoveryError;
  String? get discoveryError => _discoveryError;

  Future<void> loadOwnedNodes() async {
    if (_loadingOwnedNodes) return;
    _loadingOwnedNodes = true;
    _discoveryError = null;
    notifyListeners();
    try {
      _ownedNodes = await BackendApiService().getMyAvailabilityNodes();
    } catch (error) {
      _ownedNodes = const [];
      _discoveryError = error.toString();
    } finally {
      _loadingOwnedNodes = false;
      notifyListeners();
    }
  }

  Future<void> attachOwnedNode(Map<String, dynamic> node) async {
    final identity = node['identity'];
    if (node['remoteAttachAvailable'] != true || identity is! Map) {
      throw StateError(
          'This Node is offline or needs remote identity enrollment.');
    }
    _state = KubusNodeConnectionState.connecting;
    _error = null;
    _connectionFailure = null;
    notifyListeners();
    final backend = BackendApiService();
    try {
      await service.attachRemote(
        nodeId: node['nodeId'] as String,
        publicKey: identity['publicKey'] as String,
        fingerprint: identity['fingerprint'] as String,
        signalingBaseUrl: backend.baseUrl,
        authToken: () async => backend.getAuthToken(),
        iceConfiguration: _turnCredentialService.loadIceConfiguration,
        authorize: (sessionId, deviceId, verifierHash) =>
            backend.createNodeAttachAuthorization(
          nodeId: node['nodeId'] as String,
          sessionId: sessionId,
          deviceId: deviceId,
          verifierHash: verifierHash,
        ),
      );
      await refresh();
      if (_state != KubusNodeConnectionState.paired) {
        throw StateError('Node attached, but is currently unavailable.');
      }
    } catch (error) {
      _state = KubusNodeConnectionState.error;
      _connectionFailure = error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Phase of an explicit compute permission rotation, or null when idle.
  String? _permissionUpdatePhase;
  String? get permissionUpdatePhase => _permissionUpdatePhase;
  bool get updatingPermissions => _permissionUpdatePhase == 'WORKING';

  /// Looks up what a Node setup code is asking this account to approve.
  Future<Map<String, dynamic>> lookupInstallation(String code) =>
      BackendApiService().getNodeInstallationByCode(code.trim().toUpperCase());

  Future<void> authorizeInstallation(String installationId) =>
      BackendApiService().authorizeNodeInstallation(installationId);

  Future<void> declineInstallation(String installationId) =>
      BackendApiService().declineNodeInstallation(installationId);

  /// Rotates this Node's operator credential to the current scope contract.
  ///
  /// The Node mints the grant (only it can prove the identity the grant is
  /// bound to), this account authorizes it, and the Node then collects and
  /// stores the replacement. Nothing here edits the historical credential, so
  /// declining or failing leaves the Node exactly as it was.
  Future<void> updateComputePermissions() async {
    if (updatingPermissions) return;
    _permissionUpdatePhase = 'WORKING';
    _error = null;
    notifyListeners();
    try {
      final begun = await service.beginComputePermissionUpdate();
      final installationId = begun['installationId'];
      if (installationId is! String || installationId.isEmpty) {
        throw StateError('This Node did not start a permission update.');
      }
      await authorizeInstallation(installationId);
      // The Node applies the rotation itself; poll it rather than assuming the
      // credential landed, because only the Node knows it reached disk.
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final status = await service.computePermissionUpdateStatus();
        final phase = (status['phase'] ?? '').toString();
        if (phase == 'COMPLETED') {
          _permissionUpdatePhase = 'COMPLETED';
          notifyListeners();
          return;
        }
        if (phase == 'DECLINED' || phase == 'EXPIRED' || phase == 'FAILED') {
          _permissionUpdatePhase = phase == 'DECLINED' ? 'DECLINED' : 'FAILED';
          notifyListeners();
          return;
        }
      }
      _permissionUpdatePhase = 'FAILED';
    } catch (error) {
      _permissionUpdatePhase = 'FAILED';
      _error = error.toString();
    }
    notifyListeners();
  }

  void clearPermissionUpdate() {
    _permissionUpdatePhase = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestPublication({
    required String spatialId,
    required String artworkId,
    String? markerId,
  }) async {
    final record = await service.getSpatial(spatialId);
    final manifest = record['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw StateError('The local spatial manifest is unavailable.');
    }
    return BackendApiService().publishExistingSpatialCid(
      spatial: manifest,
      artworkId: artworkId,
      markerId: markerId,
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (!await service.initialize()) {
        _state = KubusNodeConnectionState.unpaired;
        notifyListeners();
        return;
      }
    } catch (error) {
      _state = KubusNodeConnectionState.error;
      _connectionFailure = error;
      _error = error.toString();
      notifyListeners();
      return;
    }
    await refresh();
    unawaited(_restoreRemoteRouteThenRefresh());
  }

  Future<void> pair(KubusNodePairingPayload payload) async {
    _state = KubusNodeConnectionState.connecting;
    _error = null;
    _connectionFailure = null;
    notifyListeners();
    try {
      await service.pair(payload);
      await refresh();
      unawaited(_restoreRemoteRouteThenRefresh());
    } catch (error) {
      _state = KubusNodeConnectionState.error;
      _error = error.toString();
      _connectionFailure = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      _snapshot = await service.fetchSnapshot();
      _jobs = await service.listJobs();
      try {
        _computeSettings = await service.getComputeSettings();
      } catch (_) {
        _computeSettings = const {};
      }
      _state = KubusNodeConnectionState.paired;
      _error = null;
      _connectionFailure = null;
    } catch (error) {
      _state = KubusNodeConnectionState.unavailable;
      _connectionFailure = error;
      _error = error.toString();
    }
    notifyListeners();
  }

  Future<KubusNodeJob> startReconstruction({
    required String captureId,
    required String artworkId,
    String? markerId,
  }) async {
    final job = await service.createJob(
      type: 'spatial.reconstruct',
      input: {
        'captureId': captureId,
        'artworkId': artworkId,
        if (markerId != null) 'markerId': markerId,
      },
      // The capture is this request's durable identity, so a retry after an
      // ambiguous failure — or a second tap on Process — reaches the same job
      // instead of queueing the same reconstruction twice. The node releases
      // the key when a job fails, so a deliberate re-run still starts work.
      requestId: captureId,
    );
    await refresh();
    return job;
  }

  String _backendAuthorization() {
    final token = (BackendApiService().getAuthToken() ?? '').trim();
    if (token.isEmpty) {
      throw StateError('Sign in to art.kubus before using network compute.');
    }
    return 'Bearer $token';
  }

  Future<List<KubusComputeCandidate>> loadComputeCandidates({
    required int inputBytes,
    int minimumVramBytes = 0,
  }) async {
    _computeCandidates = await service.findComputeCandidates(
      backendAuthorization: _backendAuthorization(),
      inputBytes: inputBytes,
      minimumVramBytes: minimumVramBytes,
    );
    notifyListeners();
    return _computeCandidates;
  }

  Future<KubusRemoteComputeJob> startRemoteReconstruction({
    required String captureId,
    required KubusComputeCandidate provider,
    required Map<String, dynamic> requirements,
  }) async {
    _remoteJob = await service.createRemoteComputeJob(
      backendAuthorization: _backendAuthorization(),
      captureId: captureId,
      provider: provider,
      requirements: requirements,
    );
    notifyListeners();
    return _remoteJob!;
  }

  Future<KubusRemoteComputeJob> refreshRemoteJob(String id) async {
    _remoteJob = await service.getRemoteComputeJob(id, _backendAuthorization());
    notifyListeners();
    return _remoteJob!;
  }

  Future<Map<String, dynamic>> retrieveRemoteResult(String id) =>
      service.retrieveRemoteComputeResult(id, _backendAuthorization());

  Future<KubusRemoteComputeJob> acknowledgeRemoteResult(
    String id, {
    required bool accepted,
    String? reason,
  }) async {
    _remoteJob = await service.acknowledgeRemoteComputeResult(
      id: id,
      backendAuthorization: _backendAuthorization(),
      accepted: accepted,
      reason: reason,
    );
    notifyListeners();
    return _remoteJob!;
  }

  Future<void> updateComputeSettings(Map<String, dynamic> settings) async {
    if (!computeSettingsAvailable) {
      throw StateError('Remote compute settings are unavailable on this node.');
    }
    try {
      _computeSettings = await service.updateComputeSettings(settings);
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelRemoteJob(String id) async {
    _remoteJob = await service.cancelRemoteComputeJob(
      id,
      _backendAuthorization(),
    );
    notifyListeners();
  }

  Future<void> unpair() async {
    await service.unpair();
    _snapshot = null;
    _jobs = const [];
    _computeCandidates = const [];
    _remoteJob = null;
    _computeSettings = const {};
    _state = KubusNodeConnectionState.unpaired;
    _error = null;
    _connectionFailure = null;
    notifyListeners();
  }

  /// Restores the route that survives leaving the Node's LAN.
  ///
  /// Failure is intentionally silent here: this is opportunistic remote
  /// coordination. The following refresh still tests the direct route, so a
  /// signaling or TURN outage never makes a nearby Node look unpaired.
  /// Brings up the signalling-backed rung, reporting whether one was installed.
  Future<bool> _restoreRemoteRoute() async {
    if (!service.supportsRemoteIdentityVerification ||
        (service.nodeId ?? '').isEmpty) {
      return false;
    }
    final backend = BackendApiService();
    if ((backend.getAuthToken() ?? '').trim().isEmpty) return false;
    try {
      await service.connectRemote(
        signalingBaseUrl: backend.baseUrl,
        authToken: () async => backend.getAuthToken(),
        iceConfiguration: _turnCredentialService.loadIceConfiguration,
      );
      return true;
    } on Object {
      // The resolver retains any working direct rungs. Connection state is set
      // by refresh from an actual Node response, not from this coordination
      // attempt alone.
      return false;
    }
  }

  /// Installs the remote rung, then re-reads state if that changed what is
  /// reachable.
  ///
  /// A cold start away from the Node's LAN runs [refresh] while the only rung
  /// is the LAN one. It fails, and the provider settles on `unavailable`. The
  /// remote rung then comes up and works — but nothing has asked the Node
  /// anything since, so every screen keeps showing an unreachable Node until
  /// some unrelated action happens to refresh. Re-reading here is what turns a
  /// working transport into state a user can see.
  ///
  /// Skipped when the provider is already paired: the LAN rung answered, so a
  /// second round trip would tell us what we know.
  Future<void> _restoreRemoteRouteThenRefresh() async =>
      refreshAfterRouteRestored(await _restoreRemoteRoute());

  /// The half of the above that decides whether to re-read.
  ///
  /// Split out so the cold-start-off-LAN case can be tested without standing up
  /// signalling, TURN and a backend session: what regressed before was this
  /// decision, not the connection.
  @visibleForTesting
  Future<void> refreshAfterRouteRestored(bool installedRoute) async {
    if (!installedRoute) return;
    if (_state == KubusNodeConnectionState.paired) return;
    await refresh();
  }
}
