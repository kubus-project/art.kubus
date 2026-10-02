import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

void dispatchPublicEntityRouteParsed({
  required String type,
  required String id,
  required String path,
}) {
  _dispatch('kubus:public-entity-route-parsed', type: type, id: id, path: path);
}

void dispatchPublicEntityReady({
  required String type,
  required String id,
  required String path,
}) {
  _dispatch('kubus:public-entity-ready', type: type, id: id, path: path);
}

Map<String, dynamic>? readPublicEntityBootstrap() {
  final element = web.document.getElementById('kubus-public-entity-bootstrap');
  final text = element?.textContent;
  if (text == null || text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

void _dispatch(
  String eventName, {
  required String type,
  required String id,
  required String path,
}) {
  final detail = jsonEncode(<String, String>{
    'type': type,
    'id': id,
    'path': path,
  }).toJS;
  web.window.dispatchEvent(
    web.CustomEvent(eventName, web.CustomEventInit(detail: detail)),
  );
}
