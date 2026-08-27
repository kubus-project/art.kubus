import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/node/kubus_data_channel.dart';
import 'package:art_kubus/services/node/node_identity_proof.dart';
import 'package:art_kubus/services/node/rtc/node_rtc_connector.dart';
import 'package:art_kubus/services/node/rtc/node_signaling_client.dart';
import 'package:art_kubus/services/node/turn_configuration.dart';
import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// The identity handshake, driven over the real frame protocol.
///
/// A peer connection is not needed to exercise the part that decides whether
/// to trust anything: the challenge is an ordinary framed request, so an
/// in-memory channel carries it exactly as a data channel would. That keeps
/// the security-critical path testable without ICE, a platform plugin, or a
/// network — which is what makes it practical to cover every rejection case
/// rather than only the happy one.
///
/// The peer here signs the nonce it actually receives, because that is what a
/// real Node does and what the protocol requires. A fixture with a fixed nonce
/// cannot stand in: the client mints a fresh one per attempt, which is exactly
/// why a recorded answer is worthless to an attacker. Cross-language agreement
/// with the Node's real signer is proven separately, in
/// `node_identity_proof_test.dart`, where a fixed nonce is legitimate.
void main() {
  late SimpleKeyPair nodeKeyPair;
  late Uint8List nodePublicKey;
  late SimpleKeyPair otherKeyPair;
  late Uint8List otherPublicKey;

  const sessionId = 'session-under-test';

  setUpAll(() async {
    final algorithm = Ed25519();
    nodeKeyPair = await algorithm.newKeyPair();
    nodePublicKey = Uint8List.fromList(
      (await nodeKeyPair.extractPublicKey()).bytes,
    );
    otherKeyPair = await algorithm.newKeyPair();
    otherPublicKey = Uint8List.fromList(
      (await otherKeyPair.extractPublicKey()).bytes,
    );
  });

  Future<Uint8List> sign({
    required SimpleKeyPair keyPair,
    required Uint8List boundPublicKey,
    required Uint8List nonce,
    required String session,
    String protocolVersion = kIdentityProofProtocolVersion,
    String clientRole = 'client',
  }) async {
    final message = buildIdentityProofMessage(
      protocolVersion: protocolVersion,
      sessionId: session,
      nonce: nonce,
      publicKey: boundPublicKey,
      clientRole: clientRole,
    );
    final signature = await Ed25519().sign(message, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  NodeRtcConnector connector({Uint8List? key}) => NodeRtcConnector(
        signaling: NodeSignalingClient(
          baseUrl: 'https://example.invalid',
          authToken: () async => 'unused-in-this-test',
        ),
        iceConfiguration: () async => const IceConfiguration(),
        pairedPublicKey: () => key ?? nodePublicKey,
        proofTimeout: const Duration(milliseconds: 400),
      );

  /// A peer that answers the challenge, with knobs for each way it can lie.
  _ScriptedChannel peer({
    SimpleKeyPair? signWith,
    Uint8List? presentKey,
    Uint8List? bindToKey,
    String? answerSession,
    String? bindToSession,
    String? protocolVersion,
    String clientRole = 'client',
    Uint8List? signNonceInstead,
    bool refuse = false,
    bool silent = false,
    int splitInto = 1,
    int requestIdOffset = 0,
  }) {
    return _ScriptedChannel((frame) async {
      if (silent) return const <KubusFrame>[];
      if (refuse) {
        return <KubusFrame>[
          KubusFrame(
            type: KubusFrameType.error,
            requestId: frame.requestId,
            flags: KubusFrame.flagFinal,
            metadata: const <String, dynamic>{'message': 'refused'},
          ),
        ];
      }

      final nonce = Uint8List.fromList(
        base64.decode(frame.metadata!['nonce']! as String),
      );
      final signature = await sign(
        keyPair: signWith ?? nodeKeyPair,
        boundPublicKey: bindToKey ?? nodePublicKey,
        nonce: signNonceInstead ?? nonce,
        session: bindToSession ?? answerSession ?? sessionId,
        protocolVersion: protocolVersion ?? kIdentityProofProtocolVersion,
        clientRole: clientRole,
      );

      final body = utf8.encode(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'protocolVersion': protocolVersion ?? kIdentityProofProtocolVersion,
            'sessionId': answerSession ?? sessionId,
            'publicKey': base64Url.encode(presentKey ?? nodePublicKey),
            'fingerprint': nodeFingerprintFromPublicKey(
              presentKey ?? nodePublicKey,
            ),
            'signature': base64.encode(signature),
          },
        }),
      );

      final id = frame.requestId + requestIdOffset;
      if (splitInto <= 1) {
        return <KubusFrame>[
          KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: id,
            flags: KubusFrame.flagFinal,
            metadata: const <String, dynamic>{'status': 200},
            payload: Uint8List.fromList(body),
          ),
        ];
      }

      final size = (body.length / splitInto).ceil();
      final frames = <KubusFrame>[
        KubusFrame(
          type: KubusFrameType.responseHead,
          requestId: id,
          metadata: const <String, dynamic>{'status': 200},
        ),
      ];
      for (var offset = 0; offset < body.length; offset += size) {
        final end = (offset + size) > body.length ? body.length : offset + size;
        frames.add(
          KubusFrame(
            type: KubusFrameType.responseChunk,
            requestId: id,
            flags: end >= body.length ? KubusFrame.flagFinal : 0,
            payload: Uint8List.fromList(body.sublist(offset, end)),
          ),
        );
      }
      return frames;
    });
  }

  group('the challenge the client sends', () {
    test(
        'is a bodyless framed request carrying a fresh nonce and no credential',
        () async {
      final channel = peer();
      await connector().verifyIdentityOver(channel, sessionId);

      final sent = KubusFrameCodec.decode(channel.sent.single);
      expect(sent.type, KubusFrameType.requestHead);
      expect(sent.isFinal, isTrue);
      expect(sent.metadata!['path'], '/local/v1/identity/challenge');
      expect(sent.metadata!['method'], 'POST');
      expect(sent.metadata!['protocolVersion'], kIdentityProofProtocolVersion);
      expect(base64.decode(sent.metadata!['nonce']! as String), hasLength(32));
      // No credential travels before the peer has been verified — that is the
      // entire ordering this handshake exists to enforce.
      expect(sent.metadata!.containsKey('headers'), isFalse);
      expect(sent.payload, isNull);
    });

    test('uses a different nonce every attempt', () async {
      final first = peer();
      final second = peer();
      await connector().verifyIdentityOver(first, sessionId);
      await connector().verifyIdentityOver(second, sessionId);

      String nonceOf(_ScriptedChannel channel) =>
          KubusFrameCodec.decode(channel.sent.single).metadata!['nonce']!
              as String;
      expect(nonceOf(first), isNot(equals(nonceOf(second))));
    });
  });

  group('accepting the real Node', () {
    test('accepts a peer that signs the nonce with the paired key', () async {
      await connector().verifyIdentityOver(peer(), sessionId);
    });

    test('reassembles a chunked answer', () async {
      await connector().verifyIdentityOver(peer(splitInto: 4), sessionId);
    });

    test('ignores frames belonging to other requests', () async {
      // Noise on another request id must neither satisfy the challenge nor
      // derail it.
      final channel = _ScriptedChannel((frame) async {
        final nonce = Uint8List.fromList(
          base64.decode(frame.metadata!['nonce']! as String),
        );
        final signature = await sign(
          keyPair: nodeKeyPair,
          boundPublicKey: nodePublicKey,
          nonce: nonce,
          session: sessionId,
        );
        final body = utf8.encode(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'protocolVersion': kIdentityProofProtocolVersion,
              'sessionId': sessionId,
              'publicKey': base64Url.encode(nodePublicKey),
              'signature': base64.encode(signature),
            },
          }),
        );
        return <KubusFrame>[
          KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: frame.requestId + 99,
            flags: KubusFrame.flagFinal,
            metadata: const <String, dynamic>{'status': 200},
            payload: Uint8List.fromList(utf8.encode('{"data":{}}')),
          ),
          KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: frame.requestId,
            flags: KubusFrame.flagFinal,
            metadata: const <String, dynamic>{'status': 200},
            payload: Uint8List.fromList(body),
          ),
        ];
      });
      await connector().verifyIdentityOver(channel, sessionId);
    });
  });

  group('rejecting everything else', () {
    test('rejects a peer presenting a different key', () async {
      await expectLater(
        connector().verifyIdentityOver(
          peer(
            signWith: otherKeyPair,
            presentKey: otherPublicKey,
            bindToKey: otherPublicKey,
          ),
          sessionId,
        ),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.wrongIdentity,
          ),
        ),
      );
    });

    test('rejects a peer that claims the paired key it cannot sign for',
        () async {
      // The shape an attacker who read the pairing QR can produce: the right
      // identity claimed, the wrong key holding the pen.
      await expectLater(
        connector().verifyIdentityOver(peer(signWith: otherKeyPair), sessionId),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.badSignature,
          ),
        ),
      );
    });

    test('rejects a signature over a nonce the client did not send', () async {
      await expectLater(
        connector().verifyIdentityOver(
          peer(signNonceInstead: Uint8List.fromList(List<int>.filled(32, 5))),
          sessionId,
        ),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.badSignature,
          ),
        ),
      );
    });

    test('rejects a proof bound to a different session', () async {
      await expectLater(
        connector().verifyIdentityOver(
          peer(answerSession: 'not-this-session'),
          sessionId,
        ),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.replayed,
          ),
        ),
      );
    });

    test('rejects a proof minted under a different protocol version', () async {
      await expectLater(
        connector().verifyIdentityOver(
          peer(protocolVersion: 'kubus-node/99'),
          sessionId,
        ),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.replayed,
          ),
        ),
      );
    });

    test('rejects a client-role proof reflected back as the node role',
        () async {
      await expectLater(
        connector().verifyIdentityOver(peer(clientRole: 'node'), sessionId),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.badSignature,
          ),
        ),
      );
    });

    test('fails when the device has no paired key to check against', () async {
      await expectLater(
        connector(key: Uint8List(0)).verifyIdentityOver(peer(), sessionId),
        throwsA(
          isA<NodeIdentityException>().having(
            (e) => e.failure,
            'failure',
            NodeIdentityFailure.notPaired,
          ),
        ),
      );
    });

    test('fails when the peer refuses the challenge', () async {
      await expectLater(
        connector().verifyIdentityOver(peer(refuse: true), sessionId),
        throwsA(isA<NodeIdentityException>()),
      );
    });

    test('fails, rather than hanging, when the peer never answers', () async {
      await expectLater(
        connector().verifyIdentityOver(peer(silent: true), sessionId),
        throwsA(isA<NodeIdentityException>()),
      );
    });

    test('fails when the peer answers on the wrong request id only', () async {
      await expectLater(
        connector().verifyIdentityOver(peer(requestIdOffset: 7), sessionId),
        throwsA(isA<NodeIdentityException>()),
      );
    });
  });
}

/// An in-memory channel that answers each request with a scripted reply.
class _ScriptedChannel implements KubusDataChannel {
  _ScriptedChannel(this._respond);

  final Future<List<KubusFrame>> Function(KubusFrame request) _respond;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  /// Everything the client put on the wire, for asserting the request shape.
  final List<Uint8List> sent = <Uint8List>[];

  @override
  Stream<Uint8List> get messages => _controller.stream;

  @override
  bool get isOpen => !_controller.isClosed;

  @override
  Future<void> send(Uint8List data) async {
    sent.add(data);
    final request = KubusFrameCodec.decode(data);
    // Answer asynchronously so the caller's listener is attached first, which
    // is also the ordering a real channel produces.
    unawaited(
      Future<void>.delayed(Duration.zero, () async {
        for (final frame in await _respond(request)) {
          if (_controller.isClosed) return;
          _controller.add(KubusFrameCodec.encode(frame));
        }
      }),
    );
  }

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
