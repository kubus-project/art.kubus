/// Verifies that the peer on the other end of a data channel is the Node this
/// device paired with.
///
/// This is the security boundary the whole remote-connection story rests on.
/// Once a Node is reachable from anywhere, "the peer that answered" and "my
/// Node" are different statements, and only one of them is worth sending a
/// credential to.
///
/// None of the following is proof, and each is tempting:
///
/// - **ICE connected.** Someone answered on a path. Nothing about who.
/// - **DTLS connected.** The channel is encrypted against a passive observer.
///   The fingerprint it authenticates comes from the same SDP the impostor
///   sent, so it certifies the impostor's own key.
/// - **A matching claimed node id or fingerprint.** Both are published in the
///   pairing QR. Anyone who has seen one can repeat it.
///
/// The only thing that distinguishes the real Node is possession of the
/// private key whose public half this device recorded at pairing time. So the
/// device picks a random challenge and requires a signature over it.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// The protocol both sides build the signed message from.
///
/// Bumping this invalidates every previously-minted proof, which is the point:
/// a signature produced under different rules must never verify under these.
const String kIdentityProofProtocolVersion = 'kubus-node/1';

/// The session id bound into every identity proof taken over HTTP.
///
/// A data-channel proof binds the real signalling session. HTTP has none, so
/// this constant stands in its place and does the job that still matters: it
/// keeps the two transports' proofs disjoint, so a proof minted for a data
/// channel can never be presented as an HTTP proof or the reverse. Freshness
/// is not its job -- the 32-byte nonce carries that.
///
/// Both ends hardcode it. Neither reads it from the other, because a peer that
/// could choose what gets signed could ask for a proof bound to a session it
/// does not own. The Node's copy is `HTTP_IDENTITY_SESSION_ID` in
/// `src/localApi/dispatch.ts`; the two must stay byte-identical.
const String kHttpIdentitySessionId = 'local-http/v1';

const String _domainSeparator = 'kubus-node-identity-proof/v1';
const int _nonceLength = 32;
const int _publicKeyLength = 32;
const int _signatureLength = 64;

/// Why a proof was rejected. Distinguished so the UI can say something true.
enum NodeIdentityFailure {
  /// The response was not a well-formed proof at all.
  malformed,

  /// The peer presented a different public key than the one paired with.
  wrongIdentity,

  /// The signature did not verify. The peer does not hold the private key.
  badSignature,

  /// The proof was minted for a different session, protocol, or nonce.
  replayed,

  /// This device has no recorded public key, so nothing can be verified.
  notPaired,
}

class NodeIdentityException implements Exception {
  const NodeIdentityException(this.failure, [this.detail]);

  final NodeIdentityFailure failure;
  final String? detail;

  @override
  String toString() => 'NodeIdentityException(${failure.name}'
      '${detail == null ? '' : ': $detail'})';
}

/// A challenge this device issued, held until the answer comes back.
class NodeIdentityChallenge {
  NodeIdentityChallenge({required this.nonce, required this.sessionId});

  /// Fresh 32 random bytes. A repeated nonce would let a recorded proof be
  /// replayed, so this is generated from a cryptographic source every time.
  factory NodeIdentityChallenge.generate({
    required String sessionId,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    final nonce = Uint8List(_nonceLength);
    for (var i = 0; i < _nonceLength; i++) {
      nonce[i] = source.nextInt(256);
    }
    return NodeIdentityChallenge(nonce: nonce, sessionId: sessionId);
  }

  final Uint8List nonce;

  /// The signalling session this connection belongs to.
  ///
  /// Binding it means a proof captured from one connection cannot be presented
  /// on another, even by an attacker who recorded a legitimate exchange.
  final String sessionId;

  /// The request metadata the Node answers.
  Map<String, dynamic> toRequestMetadata() => <String, dynamic>{
        'nonce': base64Encode(nonce),
        'protocolVersion': kIdentityProofProtocolVersion,
      };
}

/// Builds the exact bytes both sides sign and verify.
///
/// The layout is restated here in full because the Node implements it
/// independently in TypeScript, and a description that drifts from the other
/// side is worse than none. Every field is bound for a specific reason, and
/// dropping any one reopens a specific attack:
///
/// - the domain separator stops a signature minted for this protocol being
///   replayed into a different one that happens to sign the same bytes;
/// - `sessionId` binds the proof to one signalling session;
/// - the nonce makes each challenge unique within that session;
/// - the public key stops a valid proof for one key being re-presented under
///   a substituted one;
/// - the role stops a proof signed by one end being reflected back as if the
///   other end had signed it.
///
/// Text fields are NUL-terminated; the nonce and key are fixed-length, so no
/// separator is needed around them and no length prefix can disagree with the
/// bytes present.
Uint8List buildIdentityProofMessage({
  required String protocolVersion,
  required String sessionId,
  required Uint8List nonce,
  required Uint8List publicKey,
  required String clientRole,
}) {
  if (nonce.length != _nonceLength) {
    throw const NodeIdentityException(
      NodeIdentityFailure.malformed,
      'nonce must be 32 bytes',
    );
  }
  if (publicKey.length != _publicKeyLength) {
    throw const NodeIdentityException(
      NodeIdentityFailure.malformed,
      'public key must be 32 bytes',
    );
  }
  final builder = BytesBuilder(copy: false);
  void textField(String value) {
    builder.add(utf8.encode(value));
    builder.addByte(0);
  }

  textField(_domainSeparator);
  textField(protocolVersion);
  textField(sessionId);
  builder.add(nonce);
  builder.add(publicKey);
  textField(clientRole);
  return builder.takeBytes();
}

/// The fingerprint form shown to a person and stored at pairing time.
///
/// Derived from the public key so that comparing fingerprints is comparing
/// keys. The previous scheme hashed a shared secret, which could be repeated
/// by anyone who had seen it.
String nodeFingerprintFromPublicKey(Uint8List publicKey) =>
    crypto.sha256.convert(publicKey).toString();

/// Groups the first 16 hex characters for on-screen comparison.
///
/// Short enough that a person will actually read it, long enough that forging
/// a collision in the seconds a pairing screen is open is not practical.
String formatNodeFingerprint(String fingerprint) {
  final head =
      fingerprint.length <= 16 ? fingerprint : fingerprint.substring(0, 16);
  final upper = head.toUpperCase();
  final groups = <String>[];
  for (var i = 0; i < upper.length; i += 4) {
    groups.add(upper.substring(i, min(i + 4, upper.length)));
  }
  return groups.join(' ');
}

/// Checks a Node's answer to [challenge] against the paired public key.
///
/// Returns normally only when the peer holds the private key for
/// [pairedPublicKey]. Every other outcome throws with a distinguishable
/// reason, because "could not verify" and "verified as someone else" are
/// different things to tell a user.
Future<void> verifyNodeIdentityProof({
  required NodeIdentityChallenge challenge,
  required Map<String, dynamic> response,
  required Uint8List? pairedPublicKey,
}) async {
  if (pairedPublicKey == null || pairedPublicKey.length != _publicKeyLength) {
    throw const NodeIdentityException(NodeIdentityFailure.notPaired);
  }

  final presentedKey = _decodeBase64Url(response['publicKey']);
  final signature = _decodeBase64(response['signature']);
  final protocolVersion = response['protocolVersion'];
  final sessionId = response['sessionId'];

  if (presentedKey == null ||
      presentedKey.length != _publicKeyLength ||
      signature == null ||
      signature.length != _signatureLength ||
      protocolVersion is! String ||
      sessionId is! String) {
    throw const NodeIdentityException(NodeIdentityFailure.malformed);
  }

  // Compare against the key recorded at pairing, never against the key the
  // peer just supplied. Verifying a signature against its own presented key
  // proves only that the peer can sign — which every peer can.
  if (!_constantTimeEquals(presentedKey, pairedPublicKey)) {
    throw const NodeIdentityException(NodeIdentityFailure.wrongIdentity);
  }

  if (protocolVersion != kIdentityProofProtocolVersion) {
    throw const NodeIdentityException(
      NodeIdentityFailure.replayed,
      'proof was minted for a different protocol version',
    );
  }
  if (sessionId != challenge.sessionId) {
    throw const NodeIdentityException(
      NodeIdentityFailure.replayed,
      'proof belongs to a different signalling session',
    );
  }

  final message = buildIdentityProofMessage(
    protocolVersion: protocolVersion,
    sessionId: sessionId,
    nonce: challenge.nonce,
    publicKey: pairedPublicKey,
    clientRole: 'client',
  );

  final verified = await Ed25519().verify(
    message,
    signature: Signature(
      signature,
      publicKey: SimplePublicKey(pairedPublicKey, type: KeyPairType.ed25519),
    ),
  );
  if (!verified) {
    throw const NodeIdentityException(NodeIdentityFailure.badSignature);
  }
}

Uint8List? _decodeBase64Url(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
  } on FormatException {
    return null;
  }
}

Uint8List? _decodeBase64(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return Uint8List.fromList(base64.decode(base64.normalize(value)));
  } on FormatException {
    return null;
  }
}

/// Compares without an early exit on the first differing byte.
///
/// The keys here are public, so timing leaks nothing secret; it is written
/// this way so the habit holds if this helper is ever reused for something
/// that is secret.
bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
