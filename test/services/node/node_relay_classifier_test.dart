import 'dart:async';

import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_transport_policy.dart';
import 'package:art_kubus/services/node/rtc/node_relay_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Relay classification, driven against scripted ICE stats.
///
/// A real peer connection cannot be made to produce the cases that matter on
/// demand — stats that answer late, stats that never answer, stats naming a
/// candidate pair whose candidate reports are missing — and those are exactly
/// the cases where guessing "direct" hands a TURN relay the routing of a direct
/// link. Scripted reports make all of them ordinary tests.
StatsReport _candidatePair({
  String id = 'pair',
  String local = 'local',
  String remote = 'remote',
  bool? selected,
  String state = 'succeeded',
}) =>
    StatsReport(id, 'candidate-pair', 0, <String, dynamic>{
      if (selected != null) 'selected': selected,
      'state': state,
      'localCandidateId': local,
      'remoteCandidateId': remote,
    });

StatsReport _localCandidate(String id, String type) =>
    StatsReport(id, 'local-candidate', 0, <String, dynamic>{
      'candidateType': type,
    });

StatsReport _remoteCandidate(String id, String type) =>
    StatsReport(id, 'remote-candidate', 0, <String, dynamic>{
      'candidateType': type,
    });

final List<StatsReport> _directReports = <StatsReport>[
  _candidatePair(selected: true),
  _localCandidate('local', 'host'),
  _remoteCandidate('remote', 'srflx'),
];

final List<StatsReport> _relayReports = <StatsReport>[
  _candidatePair(selected: true),
  _localCandidate('local', 'relay'),
  _remoteCandidate('remote', 'srflx'),
];

/// A bulk transfer, where a relay costs someone else's bandwidth.
const _bulk = TransportSelectionContext(
  operationClass: NodeOperationClass.bulkUpload,
  network: NetworkClass.wifi,
);

/// A small call on a connection the user pays for by the byte.
const _metered = TransportSelectionContext(
  operationClass: NodeOperationClass.interactive,
  network: NetworkClass.mobile,
);

const _policy = NativeTransportPolicy();

void main() {
  group('reading a stats report', () {
    test('a direct candidate pair classifies as direct', () {
      expect(
        NodeRelayClassifier.classify(_directReports),
        KubusRtcRouteClass.direct,
      );
    });

    test('a relayed local candidate classifies as relay', () {
      expect(
        NodeRelayClassifier.classify(_relayReports),
        KubusRtcRouteClass.relayed,
      );
    });

    test('a relayed remote candidate classifies as relay', () {
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(selected: true),
          _localCandidate('local', 'host'),
          _remoteCandidate('remote', 'relay'),
        ]),
        KubusRtcRouteClass.relayed,
      );
    });

    test('a candidate carrying a relay protocol classifies as relay', () {
      // Some native reports spell `candidateType` differently but always
      // populate the relay protocol, and only a relayed candidate has one.
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(selected: true),
          StatsReport('local', 'local-candidate', 0, <String, dynamic>{
            'candidateType': 'unknown',
            'relayProtocol': 'udp',
          }),
          _remoteCandidate('remote', 'srflx'),
        ]),
        KubusRtcRouteClass.relayed,
      );
    });

    test('an empty report is undetermined, never direct', () {
      expect(
        NodeRelayClassifier.classify(const <StatsReport>[]),
        KubusRtcRouteClass.undetermined,
      );
    });

    test('a pair with no state and no nomination is undetermined', () {
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(state: 'in-progress'),
          _localCandidate('local', 'host'),
          _remoteCandidate('remote', 'host'),
        ]),
        KubusRtcRouteClass.undetermined,
      );
    });

    test('a selected pair whose candidate reports are missing is undetermined',
        () {
      // "We could not tell" and "no relay" are different facts. Only one of
      // them is safe to route a capture upload on.
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(selected: true),
        ]),
        KubusRtcRouteClass.undetermined,
      );
    });

    test('a nominated direct pair outranks a merely succeeded relay pair', () {
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(id: 'chosen', selected: true),
          _candidatePair(
            id: 'other',
            local: 'relayLocal',
            remote: 'relayRemote',
          ),
          _localCandidate('local', 'host'),
          _remoteCandidate('remote', 'host'),
          _localCandidate('relayLocal', 'relay'),
          _remoteCandidate('relayRemote', 'relay'),
        ]),
        KubusRtcRouteClass.direct,
      );
    });

    test('with nothing nominated, any succeeded relay pair wins', () {
      // Nothing says which pair carries traffic, so the pessimistic reading is
      // the only safe one.
      expect(
        NodeRelayClassifier.classify(<StatsReport>[
          _candidatePair(id: 'a'),
          _candidatePair(id: 'b', local: 'relayLocal', remote: 'relayRemote'),
          _localCandidate('local', 'host'),
          _remoteCandidate('remote', 'host'),
          _localCandidate('relayLocal', 'relay'),
          _remoteCandidate('relayRemote', 'host'),
        ]),
        KubusRtcRouteClass.relayed,
      );
    });
  });

  group('naming the rung', () {
    test('only a proven direct route is registered as the direct rung', () {
      // This is the exact mapping `NodeRtcConnector` applies to the settled
      // verdict, so an undetermined route can never become `webRtcDirect`.
      expect(
        KubusRtcRouteClass.direct.transportKind,
        KubusNodeTransportKind.webRtcDirect,
      );
      expect(
        KubusRtcRouteClass.relayed.transportKind,
        KubusNodeTransportKind.webRtcRelay,
      );
      expect(
        KubusRtcRouteClass.undetermined.transportKind,
        KubusNodeTransportKind.webRtcRelay,
      );
      expect(KubusRtcRouteClass.undetermined.isRelayed, isTrue);
      expect(KubusRtcRouteClass.direct.isRelayed, isFalse);
    });
  });

  group('settling a verdict', () {
    test('stats that already answer direct settle to direct', () async {
      final classifier = NodeRelayClassifier(
        readStats: () async => _directReports,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(seconds: 5),
      );
      addTearDown(classifier.dispose);

      expect(await classifier.settle(), KubusRtcRouteClass.direct);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcDirect);
      expect(classifier.isRelayed, isFalse);
      expect(_policy.penaltyFor(classifier.transportKind, _bulk), 0);
    });

    test('a TURN-backed connection settles to relay, never direct', () async {
      final classifier = NodeRelayClassifier(
        readStats: () async => _relayReports,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(seconds: 5),
      );
      addTearDown(classifier.dispose);

      expect(await classifier.settle(), KubusRtcRouteClass.relayed);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcRelay);
      expect(_policy.penaltyFor(classifier.transportKind, _bulk), 5000);
    });

    test('delayed stats are never read as direct in the interim', () async {
      var reports = <StatsReport>[];
      final classifier = NodeRelayClassifier(
        readStats: () async => reports,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(seconds: 5),
      );
      addTearDown(classifier.dispose);

      final settled = classifier.settle();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // The window the old code got wrong: the channel is usable, the proof is
      // done, and stats have said nothing yet.
      expect(classifier.routeClass, KubusRtcRouteClass.undetermined);
      expect(classifier.isRelayed, isTrue);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcRelay);

      // Routing charges it the relay penalties for exactly that reason.
      expect(_policy.penaltyFor(classifier.transportKind, _bulk), 5000);
      expect(_policy.penaltyFor(classifier.transportKind, _metered), 1000);

      reports = _directReports;

      expect(await settled, KubusRtcRouteClass.direct);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcDirect);
      expect(_policy.penaltyFor(classifier.transportKind, _bulk), 0);
      expect(_policy.penaltyFor(classifier.transportKind, _metered), 0);
    });

    test('delayed stats that reveal a relay settle to relay', () async {
      var reports = <StatsReport>[];
      final classifier = NodeRelayClassifier(
        readStats: () async => reports,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(seconds: 5),
      );
      addTearDown(classifier.dispose);

      final settled = classifier.settle();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      reports = _relayReports;

      expect(await settled, KubusRtcRouteClass.relayed);
    });

    test('stats that never answer settle pessimistically, not direct',
        () async {
      final classifier = NodeRelayClassifier(
        readStats: () async => <StatsReport>[],
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(milliseconds: 120),
      );
      addTearDown(classifier.dispose);

      final verdict = await classifier.settle();

      expect(verdict, KubusRtcRouteClass.relayed);
      expect(classifier.routeClass, KubusRtcRouteClass.relayed);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcRelay);
      expect(_policy.penaltyFor(classifier.transportKind, _bulk), 5000);
      // Settled for good: a verdict already acted on is not revised.
      expect(await classifier.settle(), KubusRtcRouteClass.relayed);
    });

    test('stats that throw settle pessimistically rather than failing',
        () async {
      final classifier = NodeRelayClassifier(
        readStats: () async => throw StateError('no stats on this platform'),
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(milliseconds: 120),
      );
      addTearDown(classifier.dispose);

      expect(await classifier.settle(), KubusRtcRouteClass.relayed);
    });

    test('the wait is bounded even when stats hang forever', () async {
      final classifier = NodeRelayClassifier(
        readStats: () => Completer<List<StatsReport>>().future,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(milliseconds: 120),
      );
      addTearDown(classifier.dispose);

      final stopwatch = Stopwatch()..start();
      expect(await classifier.settle(), KubusRtcRouteClass.relayed);
      stopwatch.stop();

      // Connection setup is delayed, never deadlocked.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('disposing releases a caller still awaiting a verdict', () async {
      final classifier = NodeRelayClassifier(
        readStats: () => Completer<List<StatsReport>>().future,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(minutes: 5),
      );

      final settled = classifier.settle();
      classifier.dispose();

      expect(await settled, KubusRtcRouteClass.relayed);
    });

    test('disposing does not overwrite a verdict already reached', () async {
      final classifier = NodeRelayClassifier(
        readStats: () async => _directReports,
        pollInterval: const Duration(milliseconds: 5),
        settleTimeout: const Duration(seconds: 5),
      );

      expect(await classifier.settle(), KubusRtcRouteClass.direct);
      classifier.dispose();

      expect(classifier.routeClass, KubusRtcRouteClass.direct);
      expect(classifier.transportKind, KubusNodeTransportKind.webRtcDirect);
    });
  });
}
