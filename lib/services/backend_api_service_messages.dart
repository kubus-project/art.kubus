part of 'backend_api_service.dart';

Future<Map<String, dynamic>> _backendApiFetchConversationsImpl(
  BackendApiService service,
) async {
  try {
    try {
      await service._ensureAuthWithStoredWallet();
    } catch (_) {}
    AppConfig.debugPrint(
      'BackendApiService.fetchConversations: authToken present=${service._authToken != null && service._authToken!.isNotEmpty}',
    );
    final response = await service._get(
      Uri.parse('${service.baseUrl}/api/messages'),
      headers: service._getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.fetchConversations failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiFetchMessagesImpl(
  BackendApiService service,
  String conversationId, {
  int page = 1,
  int limit = 50,
}) async {
  try {
    try {
      await service._ensureAuthWithStoredWallet();
    } catch (_) {}
    AppConfig.debugPrint(
      'BackendApiService.fetchMessages: conversationId=$conversationId authToken present=${service._authToken != null && service._authToken!.isNotEmpty}',
    );
    final uri = Uri.parse('${service.baseUrl}/api/messages/$conversationId/messages')
        .replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await service._get(uri, headers: service._getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.fetchMessages failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiSendMessageImpl(
  BackendApiService service,
  String conversationId,
  String message, {
  Map<String, dynamic>? data,
  String? replyToId,
}) async {
  service._throwIfIpfsFallbackUnavailable('Messages');
  try {
    final body = <String, dynamic>{'message': message};
    if (data != null) body['data'] = data;
    if (replyToId != null && replyToId.isNotEmpty) {
      body['replyToId'] = replyToId;
    }
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/messages'),
      headers: service._getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body,
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.sendMessage failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiFetchConversationMembersImpl(
  BackendApiService service,
  String conversationId,
) async {
  try {
    try {
      await service._ensureAuthWithStoredWallet();
    } catch (_) {}
    final response = await service._get(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/members'),
      headers: service._getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 429) {
      AppConfig.debugPrint(
        'BackendApiService.fetchConversationMembers: 429 Too Many Requests for $conversationId',
      );
      return {
        'success': false,
        'status': 429,
        'retryAfter': response.headers['retry-after'],
      };
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.fetchConversationMembers failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiUploadMessageAttachmentImpl(
  BackendApiService service,
  String conversationId,
  List<int> bytes,
  String filename,
  String contentType,
) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/messages/$conversationId/messages');
    final placeholder =
        filename.isNotEmpty ? 'Attachment - $filename' : 'Shared an attachment';

    http.MultipartRequest buildRequest() {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Accept': 'application/json'});
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
      request.fields['message'] = placeholder;
      request.fields['content'] = placeholder;
      return request;
    }

    final response = await service._sendMultipart(buildRequest, includeAuth: true);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body,
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.uploadMessageAttachment failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiCreateConversationImpl(
  BackendApiService service, {
  String? title,
  bool isGroup = false,
  List<String>? members,
}) async {
  service._throwIfIpfsFallbackUnavailable('Messages');
  try {
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/messages'),
      headers: service._getHeaders(),
      body: jsonEncode({
        'title': title,
        'members': members ?? <String>[],
        'isGroup': isGroup,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.createConversation failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiUploadConversationAvatarImpl(
  BackendApiService service,
  String conversationId,
  List<int> bytes,
  String filename,
  String contentType,
) async {
  try {
    var uri = Uri.parse('${service.baseUrl}/api/conversations/$conversationId/avatar');

    http.MultipartRequest buildPrimary() {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Accept': 'application/json'});
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
      return request;
    }

    var response = await service._sendMultipart(buildPrimary, includeAuth: true);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    uri = Uri.parse('${service.baseUrl}/api/messages/$conversationId/avatar');

    http.MultipartRequest buildFallback() {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Accept': 'application/json'});
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
      return request;
    }

    response = await service._sendMultipart(buildFallback, includeAuth: true);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body,
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.uploadConversationAvatar failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiAddConversationMemberImpl(
  BackendApiService service,
  String conversationId,
  String walletAddress,
) async {
  try {
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/members'),
      headers: service._getHeaders(),
      body: jsonEncode({'walletAddress': walletAddress}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.addConversationMember failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiRemoveConversationMemberImpl(
  BackendApiService service,
  String conversationId,
  String walletOrUsername,
) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/messages/$conversationId/members');
    final response = await service._delete(
      uri,
      headers: service._getHeaders(),
      body: jsonEncode({
        'walletAddress': walletOrUsername,
        'username': walletOrUsername,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return {'success': true};
    }

    final fallback = await service._post(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/members/remove'),
      headers: service._getHeaders(),
      body: jsonEncode({'walletAddress': walletOrUsername}),
    );
    if (fallback.statusCode == 200 || fallback.statusCode == 201) {
      return jsonDecode(fallback.body) as Map<String, dynamic>;
    }

    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.removeConversationMember failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiTransferConversationOwnerImpl(
  BackendApiService service,
  String conversationId,
  String newOwnerWallet,
) async {
  try {
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/transfer-owner'),
      headers: service._getHeaders(),
      body: jsonEncode({'newOwnerWallet': newOwnerWallet}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.transferConversationOwner failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiMarkConversationReadImpl(
  BackendApiService service,
  String conversationId,
) async {
  try {
    final response = await service._put(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/read'),
      headers: service._getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.markConversationRead failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiMarkMessageReadImpl(
  BackendApiService service,
  String conversationId,
  String messageId,
) async {
  try {
    final response = await service._put(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/messages/$messageId/read'),
      headers: service._getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false, 'status': response.statusCode};
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.markMessageRead failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiRenameConversationImpl(
  BackendApiService service,
  String conversationId,
  String newTitle,
) async {
  try {
    final response = await service._patch(
      Uri.parse('${service.baseUrl}/api/messages/$conversationId/rename'),
      headers: service._getHeaders(),
      body: jsonEncode({'title': newTitle}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to rename conversation: ${response.statusCode}');
  } catch (e) {
    throw Exception('Failed to rename conversation: $e');
  }
}
