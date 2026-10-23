void dispatchPublicEntityRouteParsed({
  required String type,
  required String id,
  required String path,
  required String locale,
}) {}

void dispatchPublicEntityReady({
  required String type,
  required String id,
  required String path,
  required String locale,
}) {}

void dispatchPublicEntityFailed({
  required String type,
  required String id,
  required String path,
  required String locale,
}) {}

Map<String, dynamic>? readPublicEntityBootstrap() => null;

String? readPublicEntityDocumentTitle() => null;
