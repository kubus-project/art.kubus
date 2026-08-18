import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/utils/node_state_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests are about what a person reads, not about plumbing: that runtime
/// vocabulary never reaches the screen, that a fact the runtime does not
/// measure is not invented, and that both languages say the same thing.
void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations sl = AppLocalizationsSl();

  group('participation', () {
    test('translates every runtime state', () {
      const states = [
        'CONTRIBUTING',
        'JOINING',
        'DEGRADED',
        'LOCKED',
        'UNCONFIGURED'
      ];
      for (final state in states) {
        final description = NodeStatePresentation.participation(en, state);
        expect(description.title, isNotEmpty);
        expect(description.body, isNotEmpty);
        // The raw machine form must never be what the person reads. (An
        // English word may happen to uppercase to the enum name, so this
        // compares the actual rendered string, not a normalised one.)
        expect(description.title, isNot(state));
        expect(description.title, isNot(contains('_')));
      }
    });

    test('an unknown state falls back to setup rather than showing a code', () {
      final description = NodeStatePresentation.participation(en, 'WAT');
      expect(description.title, en.kubusNodeStateUnconfigured);
    });

    test('a gated node is never told it is locked out', () {
      for (final l10n in [en, sl]) {
        final description = NodeStatePresentation.participation(l10n, 'LOCKED');
        final text = '${description.title} ${description.body}'.toLowerCase();
        for (final forbidden in [
          'denied',
          'locked',
          'violation',
          'forbidden',
          'zaklenjeno',
          'zavrnjen',
          'prepoved',
        ]) {
          expect(text, isNot(contains(forbidden)),
              reason: 'gate copy must read as reciprocity, not enforcement');
        }
        expect(description.actionLabel, isNotNull);
      }
    });

    test('contributing is good, a gate is attention, not a failure', () {
      expect(NodeStatePresentation.participation(en, 'CONTRIBUTING').severity,
          NodeSeverity.good);
      expect(NodeStatePresentation.participation(en, 'LOCKED').severity,
          NodeSeverity.attention);
      expect(NodeStatePresentation.participation(en, 'JOINING').severity,
          NodeSeverity.neutral);
    });
  });

  group('spatial worker', () {
    test('a ready GPU answers yes', () {
      final description = NodeStatePresentation.worker(en, {
        'status': 'ready',
        'gpu': {'available': true, 'model': 'RTX 3080 Ti'},
      });
      expect(description.title, en.kubusNodeWorkerReady);
      expect(description.severity, NodeSeverity.good);
    });

    test('no GPU is a fact about the hardware, not an alarm', () {
      final description = NodeStatePresentation.worker(en, {
        'status': 'unsupported',
        'gpu': {'available': false},
      });
      expect(description.severity, NodeSeverity.neutral);
    });

    test('a GPU with no worker is a fixable problem', () {
      final description = NodeStatePresentation.worker(en, {
        'status': 'unavailable',
        'gpu': {'available': true, 'model': 'RTX 4090'},
      });
      expect(description.title, en.kubusNodeWorkerDown);
      expect(description.severity, NodeSeverity.attention);
    });

    test('driver diagnostics never reach the description', () {
      final description = NodeStatePresentation.worker(en, {
        'status': 'degraded',
        'gpu': {'available': true},
        'detail': 'CUDA error 999: unknown',
      });
      expect(
          '${description.title} ${description.body}', isNot(contains('CUDA')));
    });

    test('formats the GPU as a name and a size', () {
      expect(
        NodeStatePresentation.gpuLabel({
          'gpu': {
            'available': true,
            'model': 'RTX 3080 Ti',
            'totalVramBytes': 12 * 1024 * 1024 * 1024,
          },
        }),
        'RTX 3080 Ti · 12.0 GB',
      );
      expect(
          NodeStatePresentation.gpuLabel({
            'gpu': {'available': false}
          }),
          isNull);
    });
  });

  group('job progress', () {
    test('local progress is determinate because the worker reports a fraction',
        () {
      final progress = NodeStatePresentation.localJob(en, 'running', 0.5);
      expect(progress.determinate, isTrue);
      expect(progress.fraction, 0.5);
    });

    test('remote progress is stage-based, never a fabricated percentage', () {
      for (final state in ['REQUESTED', 'MATCHED', 'RUNNING', 'VERIFYING']) {
        final progress = NodeStatePresentation.remoteJob(en, state);
        expect(progress.determinate, isFalse);
        expect(progress.fraction, isNull);
      }
    });

    test('remote stages advance in order through the state machine', () {
      int stage(String state) =>
          NodeStatePresentation.remoteJob(en, state).stageIndex;
      expect(stage('REQUESTED'), lessThan(stage('MATCHED')));
      expect(stage('MATCHED'), lessThan(stage('RUNNING')));
      expect(stage('RUNNING'), lessThan(stage('VERIFYING')));
      expect(stage('VERIFYING'), lessThan(stage('COMPLETED')));
    });

    test('a failure is terminal and says the capture survived', () {
      final failed = NodeStatePresentation.remoteJob(en, 'FAILED');
      expect(failed.failed, isTrue);
      expect(failed.terminal, isTrue);
      expect(failed.body, en.spatialFailedRemoteBody);

      // Cancelling is not a failure.
      final cancelled = NodeStatePresentation.remoteJob(en, 'CANCELLED');
      expect(cancelled.terminal, isTrue);
      expect(cancelled.failed, isFalse);
    });

    test('every stage list is fully localized in both languages', () {
      for (final l10n in [en, sl]) {
        expect(NodeStatePresentation.remoteStages(l10n), hasLength(9));
        expect(NodeStatePresentation.localStages(l10n), hasLength(5));
        for (final stage in NodeStatePresentation.remoteStages(l10n)) {
          expect(stage.trim(), isNotEmpty);
        }
      }
      // The two languages must not accidentally share a string table.
      expect(NodeStatePresentation.remoteStages(en),
          isNot(NodeStatePresentation.remoteStages(sl)));
    });
  });

  group('errors', () {
    test('known codes become sentences', () {
      expect(
        NodeStatePresentation.translateError(en, 'NO_COMPATIBLE_PROVIDER'),
        en.spatialErrorNoProvider,
      );
      expect(
        NodeStatePresentation.translateError(en, 'COMPUTE_JOB_EXPIRED'),
        en.spatialErrorExpired,
      );
    });

    test('an unknown code never leaks to the surface', () {
      final message =
          NodeStatePresentation.translateError(en, 'SOME_INTERNAL_THING');
      expect(message, en.spatialErrorGeneric);
      expect(message, isNot(contains('SOME_INTERNAL_THING')));
      expect(NodeStatePresentation.translateError(en, null),
          en.spatialErrorGeneric);
    });
  });

  group('formatting', () {
    test('storage reads in human units, never bytes', () {
      expect(NodeStatePresentation.formatBytes(0), '0 B');
      expect(NodeStatePresentation.formatBytes(512), '512 B');
      expect(NodeStatePresentation.formatBytes(1024 * 1024), '1.0 MB');
      expect(
        NodeStatePresentation.formatBytes(12.4 * 1024 * 1024 * 1024),
        '12.4 GB',
      );
    });

    test('percentages drop noise digits', () {
      expect(NodeStatePresentation.formatPercent(1), '100%');
      expect(NodeStatePresentation.formatPercent(0.986), '98.6%');
      expect(NodeStatePresentation.formatPercent(0.5), '50%');
      // Out-of-range input cannot produce a nonsense figure.
      expect(NodeStatePresentation.formatPercent(1.5), '100%');
    });

    test('KUB8 is a fixed-precision record, with no currency attached', () {
      expect(NodeStatePresentation.formatKub8(8.4), '8.40');
      expect(NodeStatePresentation.formatKub8(null), '0.00');
    });

    test('identifiers truncate in the middle so both ends stay recognisable',
        () {
      const cid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
      final short = NodeStatePresentation.shortId(cid);
      expect(short, startsWith('bafybeig'));
      expect(short, endsWith('55fbzdi'.substring(1)));
      expect(short, contains('…'));
      expect(short.length, lessThan(cid.length));
      // Something already short is left alone rather than mangled.
      expect(NodeStatePresentation.shortId('node-1'), 'node-1');
      expect(NodeStatePresentation.shortId(''), '—');
    });
  });

  group('pairing code', () {
    test('reads the complete v2 URI form the node QR encodes', () {
      final payload = KubusNodePairingPayload.parse(
        'kubus-node://pair?v=2&e=http%3A%2F%2F192.168.1.24%3A8787&a=https%3A%2F%2Fnode.example.test&s=session-1&k=secret-value&n=node-1&f=fingerprint-value&l=Studio',
      );
      expect(payload.endpoint.toString(), 'http://192.168.1.24:8787');
      expect(payload.sessionId, 'session-1');
      expect(payload.secret, 'secret-value');
      expect(payload.nodeId, 'node-1');
      expect(
          payload.alternateEndpoints, [Uri.parse('https://node.example.test')]);
    });

    test('accepts a phone-reachable endpoint in the node response', () {
      final payload = KubusNodePairingPayload.parse(
        '{"sessionId":"s1","secret":"k1",'
        '"node":{"endpoint":"http://192.168.1.24:8787","label":"ROK-DESKTOP"}}',
      );
      expect(payload.sessionId, 's1');
      expect(payload.label, 'ROK-DESKTOP');
    });

    test('rejects anything that is not a pairing code', () {
      for (final raw in [
        '',
        'https://art.kubus/some/page',
        'kubus-node://pair?e=http%3A%2F%2F127.0.0.1%3A8787&s=a&k=b',
        'kubus-node://pair?e=http://x&s=&k=abc',
        'kubus-node://pair?v=2&e=http%3A%2F%2F192.168.1.2&s=a&k=b',
        'kubus-node://pair?s=a&k=b',
        '{"not":"pairing"}',
      ]) {
        expect(
          () => KubusNodePairingPayload.parse(raw),
          throwsA(isA<FormatException>()),
          reason: 'must not accept "$raw"',
        );
      }
    });
  });
}
