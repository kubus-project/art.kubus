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
