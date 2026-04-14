part of 'backend_api_service.dart';

// Signed-action transport owns JWT-authenticated writes and public-sync outbox
// queuing. Offline public mutations must either queue explicit payloads or fail
// with signer-required errors instead of silently manufacturing authority.
