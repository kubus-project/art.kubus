import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kubus_node_models.dart';
import '../services/kubus_node_service.dart';
import '../services/backend_api_service.dart';

class KubusNodeProvider extends ChangeNotifier {
  KubusNodeProvider({KubusNodeService? service})
      : service = service ?? KubusNodeService();
  final KubusNodeService service;
  KubusNodeConnectionState _state = KubusNodeConnectionState.unpaired;
  KubusNodeSnapshot? _snapshot;
  List<KubusNodeJob> _jobs = const [];
  List<KubusComputeCandidate> _computeCandidates = const [];
  KubusRemoteComputeJob? _remoteJob;
  Map<String, dynamic> _computeSettings = const {};
  String? _error;
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
    if (!await service.initialize()) {
      _state = KubusNodeConnectionState.unpaired;
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> pair(KubusNodePairingPayload payload) async {
    _state = KubusNodeConnectionState.connecting;
    _error = null;
    notifyListeners();
    try {
      await service.pair(payload);
      await refresh();
    } catch (error) {
      _state = KubusNodeConnectionState.error;
      _error = error.toString();
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
    } catch (error) {
      _state = KubusNodeConnectionState.unavailable;
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
    notifyListeners();
  }
}
