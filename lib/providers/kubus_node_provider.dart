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
  String? _error;
  bool _initialized = false;
  KubusNodeConnectionState get state => _state;
  KubusNodeSnapshot? get snapshot => _snapshot;
  List<KubusNodeJob> get jobs => _jobs;
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
    );
    await refresh();
    return job;
  }

  Future<void> unpair() async {
    await service.unpair();
    _snapshot = null;
    _jobs = const [];
    _state = KubusNodeConnectionState.unpaired;
    _error = null;
    notifyListeners();
  }
}
