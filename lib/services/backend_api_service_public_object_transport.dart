part of 'backend_api_service.dart';

// Public object transport owns public and optional-auth reads plus DNSLink/IPFS
// snapshot fallback reads. These calls must not imply backend session or signer
// restoration.
