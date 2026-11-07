part of 'backend_api_service.dart';

List<Map<String, dynamic>> _backendApiDecodeDaoMapList(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Future<List<Map<String, dynamic>>> _backendApiGetDAOProposals(
  BackendApiService service, {
  int limit = 50,
  int offset = 0,
  String? status,
}) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/dao/proposals').replace(
      queryParameters: <String, String>{
        'limit': '$limit',
        'offset': '$offset',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final response = await service._get(
      uri,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _backendApiDecodeDaoMapList(data['data'] ?? data['proposals']);
    } else if (response.statusCode == 404) {
      return const <Map<String, dynamic>>[];
    } else {
      throw Exception('Failed to get DAO proposals: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getDAOProposals failed: $e');
    return const <Map<String, dynamic>>[];
  }
}

Future<Map<String, dynamic>?> _backendApiCreateDAOProposal(
  BackendApiService service, {
  required Map<String, dynamic> envelope,
}) async {
  try {
    final walletAddress = (envelope['walletAddress'] ?? '').toString().trim();
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/dao/proposals'),
      headers: service._getHeaders(),
      body: jsonEncode(<String, dynamic>{'envelope': envelope}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = data['data'] ?? data['proposal'] ?? data;
      return payload is Map<String, dynamic> ? payload : null;
    } else {
      throw Exception(
        'Failed to create proposal: ${response.statusCode} ${response.body}',
      );
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.createDAOProposal failed: $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> _backendApiGetDAOVotes(
  BackendApiService service, {
  String? proposalId,
  int limit = 100,
  int offset = 0,
}) async {
  try {
    final uri = proposalId == null
        ? Uri.parse('${service.baseUrl}/api/dao/votes').replace(
            queryParameters: <String, String>{
              'limit': '$limit',
              'offset': '$offset',
            },
          )
        : Uri.parse('${service.baseUrl}/api/dao/proposals/$proposalId/votes')
            .replace(
            queryParameters: <String, String>{
              'limit': '$limit',
              'offset': '$offset',
            },
          );
    final response = await service._get(
      uri,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _backendApiDecodeDaoMapList(data['votes'] ?? data['data']);
    } else if (response.statusCode == 404) {
      return const <Map<String, dynamic>>[];
    } else {
      throw Exception('Failed to get DAO votes: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getDAOVotes failed: $e');
    return const <Map<String, dynamic>>[];
  }
}

Future<Map<String, dynamic>?> _backendApiSubmitDAOVote(
  BackendApiService service, {
  required String proposalId,
  required Map<String, dynamic> envelope,
}) async {
  try {
    final walletAddress = (envelope['walletAddress'] ?? '').toString().trim();
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/dao/proposals/$proposalId/votes'),
      headers: service._getHeaders(),
      body: jsonEncode(<String, dynamic>{'envelope': envelope}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>? ?? data;
    } else {
      throw Exception('Failed to submit DAO vote: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.submitDAOVote failed: $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> _backendApiGetDAODelegates(
  BackendApiService service,
) async {
  try {
    final response = await service._get(
      Uri.parse('${service.baseUrl}/api/dao/delegates'),
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _backendApiDecodeDaoMapList(data['delegates'] ?? data['data']);
    } else if (response.statusCode == 404) {
      return const <Map<String, dynamic>>[];
    } else {
      throw Exception('Failed to get DAO delegates: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getDAODelegates failed: $e');
    return const <Map<String, dynamic>>[];
  }
}

Future<Map<String, dynamic>?> _backendApiDelegateVotingPower(
  BackendApiService service, {
  required String delegateId,
  required Map<String, dynamic> envelope,
}) async {
  try {
    final walletAddress = (envelope['walletAddress'] ?? '').toString().trim();
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/dao/delegations'),
      headers: service._getHeaders(),
      body: jsonEncode(<String, dynamic>{
        'delegateId': delegateId,
        'envelope': envelope,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>? ?? data;
    } else {
      throw Exception(
        'Failed to delegate voting power: ${response.statusCode}',
      );
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.delegateVotingPower failed: $e');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> _backendApiGetDAOTransactions(
  BackendApiService service,
) async {
  try {
    final response = await service._get(
      Uri.parse('${service.baseUrl}/api/dao/transactions'),
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _backendApiDecodeDaoMapList(data['data'] ?? data['transactions']);
    } else if (response.statusCode == 404) {
      return const <Map<String, dynamic>>[];
    } else {
      throw Exception(
        'Failed to get DAO transactions: ${response.statusCode}',
      );
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getDAOTransactions failed: $e');
    return const <Map<String, dynamic>>[];
  }
}

class BackendDaoTransport {
  const BackendDaoTransport(this._service);

  final BackendApiService _service;

  Future<List<Map<String, dynamic>>> getProposals({
    String? status,
    int page = 1,
    int limit = 20,
  }) {
    return _service.getDAOProposals(
      status: status,
      limit: limit,
      offset: (page - 1) * limit,
    );
  }

  Future<Map<String, dynamic>?> createProposal({
    required Map<String, dynamic> envelope,
  }) {
    return _service.createDAOProposal(envelope: envelope);
  }

  Future<List<Map<String, dynamic>>> getVotes({
    String? proposalId,
    int limit = 100,
    int offset = 0,
  }) {
    return _service.getDAOVotes(
      proposalId: proposalId,
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>?> submitVote({
    required String proposalId,
    required Map<String, dynamic> envelope,
  }) {
    return _service.submitDAOVote(
      proposalId: proposalId,
      envelope: envelope,
    );
  }

  Future<List<Map<String, dynamic>>> getDelegates() {
    return _service.getDAODelegates();
  }

  Future<Map<String, dynamic>?> delegateVotingPower({
    required String delegateId,
    required Map<String, dynamic> envelope,
  }) {
    return _service.delegateVotingPower(
      delegateId: delegateId,
      envelope: envelope,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactions() {
    return _service.getDAOTransactions();
  }
}
