import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Uint8List _decodeBase64Url(String value) {
  return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
}

String _encodeBase64Url(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

Uint8List _bufferToBytes(JSArrayBuffer buffer) {
  return JSUint8Array(buffer).toDart;
}

List<String> _stringListFromJson(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

JSArray<JSString> _transportsToJs(List<String> transports) {
  return transports.map((transport) => transport.toJS).toList().toJS;
}

web.PublicKeyCredentialDescriptor _descriptorFromJson(
    Map<String, dynamic> json) {
  final transports = _stringListFromJson(json['transports']);
  if (transports.isEmpty) {
    return web.PublicKeyCredentialDescriptor(
      type: (json['type'] ?? 'public-key').toString(),
      id: _decodeBase64Url((json['id'] ?? '').toString()).toJS,
    );
  }

  return web.PublicKeyCredentialDescriptor(
    type: (json['type'] ?? 'public-key').toString(),
    id: _decodeBase64Url((json['id'] ?? '').toString()).toJS,
    transports: _transportsToJs(transports),
  );
}

web.PublicKeyCredentialCreationOptions _creationOptionsFromJson(
  Map<String, dynamic> json,
) {
  final rp = Map<String, dynamic>.from(
      json['rp'] as Map? ?? const <String, dynamic>{});
  final user = Map<String, dynamic>.from(
      json['user'] as Map? ?? const <String, dynamic>{});
  final pubKeyCredParams =
      (json['pubKeyCredParams'] as List? ?? const <Object>[])
          .whereType<Object>()
          .map((item) {
    final value = Map<String, dynamic>.from(item as Map);
    return web.PublicKeyCredentialParameters(
      type: (value['type'] ?? 'public-key').toString(),
      alg: (value['alg'] as num?)?.toInt() ?? -7,
    );
  }).toList(growable: false);
  final excludeCredentials = (json['excludeCredentials'] as List? ??
          const <Object>[])
      .whereType<Object>()
      .map(
          (item) => _descriptorFromJson(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
  final selection = Map<String, dynamic>.from(
      json['authenticatorSelection'] as Map? ?? const <String, dynamic>{});

  final rpName = (rp['name'] ?? '').toString();
  final rpId = (rp['id'] ?? '').toString().trim();
  final rpEntity = rpId.isEmpty
      ? web.PublicKeyCredentialRpEntity(name: rpName)
      : web.PublicKeyCredentialRpEntity(name: rpName, id: rpId);
  final residentKey = (selection['residentKey'] ?? 'preferred').toString();
  final requireResidentKey = selection['requireResidentKey'] == true;
  final userVerification =
      (selection['userVerification'] ?? 'required').toString();
  final attachment =
      (selection['authenticatorAttachment'] ?? '').toString().trim();
  final authenticatorSelection = attachment.isEmpty
      ? web.AuthenticatorSelectionCriteria(
          residentKey: residentKey,
          requireResidentKey: requireResidentKey,
          userVerification: userVerification,
        )
      : web.AuthenticatorSelectionCriteria(
          residentKey: residentKey,
          requireResidentKey: requireResidentKey,
          userVerification: userVerification,
          authenticatorAttachment: attachment,
        );

  if (excludeCredentials.isEmpty) {
    return web.PublicKeyCredentialCreationOptions(
      rp: rpEntity,
      user: web.PublicKeyCredentialUserEntity(
        name: (user['name'] ?? '').toString(),
        id: _decodeBase64Url((user['id'] ?? '').toString()).toJS,
        displayName: (user['displayName'] ?? '').toString(),
      ),
      challenge: _decodeBase64Url((json['challenge'] ?? '').toString()).toJS,
      pubKeyCredParams: pubKeyCredParams.toJS,
      timeout: (json['timeout'] as num?)?.toInt() ?? 60000,
      authenticatorSelection: authenticatorSelection,
      attestation: (json['attestation'] ?? 'none').toString(),
    );
  }

  return web.PublicKeyCredentialCreationOptions(
    rp: rpEntity,
    user: web.PublicKeyCredentialUserEntity(
      name: (user['name'] ?? '').toString(),
      id: _decodeBase64Url((user['id'] ?? '').toString()).toJS,
      displayName: (user['displayName'] ?? '').toString(),
    ),
    challenge: _decodeBase64Url((json['challenge'] ?? '').toString()).toJS,
    pubKeyCredParams: pubKeyCredParams.toJS,
    timeout: (json['timeout'] as num?)?.toInt() ?? 60000,
    excludeCredentials: excludeCredentials.toJS,
    authenticatorSelection: authenticatorSelection,
    attestation: (json['attestation'] ?? 'none').toString(),
  );
}

web.PublicKeyCredentialRequestOptions _requestOptionsFromJson(
  Map<String, dynamic> json,
) {
  final allowCredentials = (json['allowCredentials'] as List? ??
          const <Object>[])
      .whereType<Object>()
      .map(
          (item) => _descriptorFromJson(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);

  if (allowCredentials.isEmpty) {
    return web.PublicKeyCredentialRequestOptions(
      challenge: _decodeBase64Url((json['challenge'] ?? '').toString()).toJS,
      timeout: (json['timeout'] as num?)?.toInt() ?? 60000,
      rpId: (json['rpId'] ?? json['rpID'] ?? '').toString(),
      userVerification: (json['userVerification'] ?? 'required').toString(),
    );
  }

  return web.PublicKeyCredentialRequestOptions(
    challenge: _decodeBase64Url((json['challenge'] ?? '').toString()).toJS,
    timeout: (json['timeout'] as num?)?.toInt() ?? 60000,
    rpId: (json['rpId'] ?? json['rpID'] ?? '').toString(),
    allowCredentials: allowCredentials.toJS,
    userVerification: (json['userVerification'] ?? 'required').toString(),
  );
}

Map<String, dynamic> _registrationResponseToJson(
  web.PublicKeyCredential credential,
) {
  final response = credential.response as web.AuthenticatorAttestationResponse;
  final transports =
      response.getTransports().toDart.map((value) => value.toDart).toList();
  final publicKey = response.getPublicKey();

  return <String, dynamic>{
    'id': credential.id,
    'rawId': _encodeBase64Url(_bufferToBytes(credential.rawId)),
    'response': <String, dynamic>{
      'clientDataJSON': _encodeBase64Url(
        _bufferToBytes(response.clientDataJSON),
      ),
      'attestationObject': _encodeBase64Url(
        _bufferToBytes(response.attestationObject),
      ),
      'authenticatorData': _encodeBase64Url(
        _bufferToBytes(response.getAuthenticatorData()),
      ),
      'transports': transports,
      'publicKeyAlgorithm': response.getPublicKeyAlgorithm(),
      if (publicKey != null)
        'publicKey': _encodeBase64Url(_bufferToBytes(publicKey)),
    },
    'type': credential.type,
    'clientExtensionResults': <String, dynamic>{},
    if (credential.authenticatorAttachment != null &&
        credential.authenticatorAttachment!.isNotEmpty)
      'authenticatorAttachment': credential.authenticatorAttachment,
  };
}

Map<String, dynamic> _authenticationResponseToJson(
  web.PublicKeyCredential credential,
) {
  final response = credential.response as web.AuthenticatorAssertionResponse;
  final userHandle = response.userHandle;

  return <String, dynamic>{
    'id': credential.id,
    'rawId': _encodeBase64Url(_bufferToBytes(credential.rawId)),
    'response': <String, dynamic>{
      'clientDataJSON': _encodeBase64Url(
        _bufferToBytes(response.clientDataJSON),
      ),
      'authenticatorData': _encodeBase64Url(
        _bufferToBytes(response.authenticatorData),
      ),
      'signature': _encodeBase64Url(
        _bufferToBytes(response.signature),
      ),
      if (userHandle != null)
        'userHandle': _encodeBase64Url(_bufferToBytes(userHandle)),
    },
    'type': credential.type,
    'clientExtensionResults': <String, dynamic>{},
    if (credential.authenticatorAttachment != null &&
        credential.authenticatorAttachment!.isNotEmpty)
      'authenticatorAttachment': credential.authenticatorAttachment,
  };
}

Future<bool> isWalletBackupPasskeySupported() async {
  try {
    final available = await web.PublicKeyCredential
            .isUserVerifyingPlatformAuthenticatorAvailable()
        .toDart;
    return available.toDart;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> createWalletBackupPasskeyCredential(
  Map<String, dynamic> creationOptions,
) async {
  final credential = await web.window.navigator.credentials
      .create(
        web.CredentialCreationOptions(
          publicKey: _creationOptionsFromJson(creationOptions),
        ),
      )
      .toDart;
  if (credential == null) {
    throw StateError('Passkey registration was cancelled.');
  }

  return _registrationResponseToJson(credential as web.PublicKeyCredential);
}

Future<Map<String, dynamic>> getWalletBackupPasskeyAssertion(
  Map<String, dynamic> requestOptions,
) async {
  final credential = await web.window.navigator.credentials
      .get(
        web.CredentialRequestOptions(
          publicKey: _requestOptionsFromJson(requestOptions),
        ),
      )
      .toDart;
  if (credential == null) {
    throw StateError('Passkey authentication was cancelled.');
  }

  return _authenticationResponseToJson(credential as web.PublicKeyCredential);
}
