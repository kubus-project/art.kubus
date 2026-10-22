import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

String? readPublicEntityDocumentTitle() => web.document
    .querySelector('meta[property="og:title"]')
    ?.getAttribute('content');

void dispatchPublicEntityRouteParsed({
  required String type,
  required String id,
  required String path,
  required String locale,
}) {
  _dispatch('kubus:public-entity-route-parsed',
      type: type, id: id, path: path, locale: locale);
}

void dispatchPublicEntityReady({
  required String type,
  required String id,
  required String path,
  required String locale,
}) {
  _dispatch('kubus:public-entity-ready',
      type: type, id: id, path: path, locale: locale);
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
  required String locale,
}) {
  final detail = jsonEncode(<String, String>{
    'type': type,
    'id': id,
    'path': path,
    'locale': locale,
  }).toJS;
  web.window.dispatchEvent(
    web.CustomEvent(eventName, web.CustomEventInit(detail: detail)),
  );
}
