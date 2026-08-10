/// Contribution telemetry at the four real production creation boundaries.
///
/// These assert against the methods the product actually calls —
/// `ArtworkDraftsProvider.submitDraft`, `EventsProvider.createEvent`,
/// `ExhibitionsProvider.createExhibition` and the two marker paths — rather
/// than against an alternate or older API, so an activation that the funnel
/// counts corresponds to something a member really published.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/artwork_drafts_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/telemetry/contribution_type.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'WalletContribution11111111111111111111111111111';

class _NoopSender implements TelemetrySender {
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async =>
      TelemetrySendResult.ok();
}

/// A queue that fails every write, to prove telemetry cannot fail a product
/// transaction that already succeeded.
class _BrokenQueue extends InMemoryTelemetryEventQueue {
  @override
  Future<void> enqueue(AppTelemetryEvent event) async {
    throw StateError('storage unavailable');
  }
}

Uint8List _png1x1() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    );

http.Response _json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryTelemetryEventQueue queue;
  late TelemetryService telemetry;

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KubusClientContext.instance.setEnabled(false);
    BackendApiService().setAuthTokenForTesting('token');
    queue = InMemoryTelemetryEventQueue();
    telemetry = TelemetryService.createForTest(
      queue: queue,
      sender: _NoopSender(),
    );
    await telemetry.ensureInitialized();
  });

  tearDown(() {
    telemetry.setAnalyticsPreferenceEnabled(false);
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
    KubusClientContext.instance.setEnabled(false);
  });

  /// Contribution events, in order, as `type:contribution_type` pairs.
  ///
  /// Pumps first: every emission is deliberately `unawaited`, because a product
  /// transaction must never wait on analytics. That is the behaviour under
  /// test, so the assertion has to let the microtasks drain rather than the
  /// production code having to await them.
  Future<List<String>> contributions() async {
    await pumpEventQueue();
    final events = await queue.peekBatch(200);
    return events
        .where((e) =>
            e.eventType == 'contribution_started' ||
            e.eventType == 'contribution_submitted')
        .map((e) => '${e.eventType}:${e.metadata['contribution_type']}')
        .toList(growable: false);
  }

  Future<List<AppTelemetryEvent>> eventsOfType(String type) async {
    await pumpEventQueue();
    return (await queue.peekBatch(200))
        .where((e) => e.eventType == type)
        .toList(growable: false);
  }

  Future<ArtworkDraftsProvider> artworkProviderWith(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    BackendApiService().setHttpClient(MockClient(handler));
    return ArtworkDraftsProvider(telemetry: telemetry);
  }

  Future<String> seededDraft(ArtworkDraftsProvider provider) async {
    final draftId = provider.createDraft();
    provider.updateBasics(
      draftId: draftId,
      title: 'Open call piece',
      description: 'Submitted from the campaign',
    );
    provider.setCover(
      draftId: draftId,
      bytes: _png1x1(),
      fileName: 'cover.png',
    );
    return draftId;
  }

  group('artwork', () {
    test('submitDraft emits started then submitted on a durable artwork',
        () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final provider = await artworkProviderWith((request) async {
        if (request.url.path == '/api/upload') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'relativeUrl': '/uploads/cover.png'},
          });
        }
        if (request.url.path == '/api/artworks') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': '5a4f1d2e-9c3b-4a6d-8e7f-1b2c3d4e5f60',
              'title': 'Open call piece',
              'description': 'Submitted from the campaign',
              'imageUrl': '/uploads/cover.png',
              'artist': _wallet,
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      });
      final draftId = await seededDraft(provider);

      final artwork = await provider.submitDraft(
        draftId: draftId,
        walletAddress: _wallet,
        l10n: l10n,
      );

      expect(artwork, isNotNull);
      expect(await contributions(), <String>[
        'contribution_started:artwork',
        'contribution_submitted:artwork',
      ]);
    });

    test('a failed create emits started but never submitted', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final provider = await artworkProviderWith((request) async {
        if (request.url.path == '/api/upload') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'relativeUrl': '/uploads/cover.png'},
          });
        }
        if (request.url.path == '/api/artworks') {
          return _json(
            <String, Object?>{'success': false, 'error': 'write failed'},
            422,
          );
        }
        return http.Response('unexpected ${request.url.path}', 500);
      });
      final draftId = await seededDraft(provider);

      final artwork = await provider.submitDraft(
        draftId: draftId,
        walletAddress: _wallet,
        l10n: l10n,
      );

      expect(artwork, isNull);
      // A failed API call is not activation. Nor is the successful cover upload
      // that preceded it.
      expect(await contributions(), <String>['contribution_started:artwork']);
    });

    test('validation failure before any upload is not activation', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final provider = await artworkProviderWith(
        (request) async => http.Response('should not be called', 500),
      );
      // No cover set: the draft cannot be published.
      final draftId = provider.createDraft();
      provider.updateBasics(
        draftId: draftId,
        title: 'No cover',
        description: 'No cover',
      );

      final artwork = await provider.submitDraft(
        draftId: draftId,
        walletAddress: _wallet,
        l10n: l10n,
      );

      expect(artwork, isNull);
      expect(await contributions(), <String>['contribution_started:artwork']);
    });

    test('a published artwork survives a telemetry subsystem that throws',
        () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final brokenTelemetry = TelemetryService.createForTest(
        queue: _BrokenQueue(),
        sender: _NoopSender(),
      );
      await brokenTelemetry.ensureInitialized();
      addTearDown(() => brokenTelemetry.setAnalyticsPreferenceEnabled(false));

      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/upload') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'relativeUrl': '/uploads/cover.png'},
          });
        }
        if (request.url.path == '/api/artworks') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': '7c8d9e0f-1a2b-4c3d-9e8f-0a1b2c3d4e5f',
              'title': 'Resilient',
              'description': 'Telemetry is not transaction logic',
              'imageUrl': '/uploads/cover.png',
              'artist': _wallet,
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));
      final provider = ArtworkDraftsProvider(telemetry: brokenTelemetry);
      final draftId = await seededDraft(provider);

      final artwork = await provider.submitDraft(
        draftId: draftId,
        walletAddress: _wallet,
        l10n: l10n,
      );

      expect(
        artwork,
        isNotNull,
        reason: 'analytics is observability, never part of the transaction',
      );
      expect(provider.getDraft(draftId)?.submitError, isNull);
    });
  });

  group('event', () {
    test('createEvent emits started then submitted', () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/events' && request.method == 'POST') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f',
              'title': 'Opening night',
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));

      final provider = EventsProvider(telemetry: telemetry);
      final created = await provider.createEvent(<String, dynamic>{
        'title': 'Opening night',
      });

      expect(created, isNotNull);
      expect(await contributions(), <String>[
        'contribution_started:event',
        'contribution_submitted:event',
      ]);
    });

    test('updateEvent is not a new contribution', () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        return _json(<String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'id': 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f',
            'title': 'Renamed opening',
          },
        });
      }));

      final provider = EventsProvider(telemetry: telemetry);
      final updated = await provider.updateEvent(
        'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f',
        <String, dynamic>{'title': 'Renamed opening'},
      );

      expect(updated, isNotNull);
      expect(
        await contributions(),
        isEmpty,
        reason: 'renaming last month\'s opening is not activating again',
      );
    });
  });

  group('exhibition', () {
    test('createExhibition emits started then submitted', () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/exhibitions' &&
            request.method == 'POST') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'd4e5f6a7-b8c9-4d0e-9f1a-2b3c4d5e6f70',
              'title': 'Group show',
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));

      final provider = ExhibitionsProvider(telemetry: telemetry);
      final created = await provider.createExhibition(<String, dynamic>{
        'title': 'Group show',
      });

      expect(created, isNotNull);
      expect(await contributions(), <String>[
        'contribution_started:exhibition',
        'contribution_submitted:exhibition',
      ]);
    });

    test('updateExhibition is not a new contribution', () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        return _json(<String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'id': 'd4e5f6a7-b8c9-4d0e-9f1a-2b3c4d5e6f70',
            'title': 'Group show, revised',
          },
        });
      }));

      final provider = ExhibitionsProvider(telemetry: telemetry);
      await provider.updateExhibition(
        'd4e5f6a7-b8c9-4d0e-9f1a-2b3c4d5e6f70',
        <String, dynamic>{'title': 'Group show, revised'},
      );

      expect(await contributions(), isEmpty);
    });
  });

  group('marker', () {
    /// The marker editor's production path. It talks to the backend itself
    /// rather than delegating to MapMarkerService, which is why both own their
    /// telemetry — see docs/analytics/campaign-activation-contract.md.
    test('MarkerManagementProvider.createMarker emits one started + submitted',
        () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/art-markers' &&
            request.method == 'POST') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'e5f6a7b8-c9d0-4e1f-8a2b-3c4d5e6f7081',
              'title': 'Wall piece',
              'latitude': 46.05,
              'longitude': 14.5,
              'creator': _wallet,
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));

      final provider = MarkerManagementProvider(telemetry: telemetry);
      final created = await provider.createMarker(<String, dynamic>{
        'title': 'Wall piece',
        'latitude': 46.05,
        'longitude': 14.5,
      });

      expect(created, isA<ArtMarker>());
      expect(await contributions(), <String>[
        'contribution_started:marker',
        'contribution_submitted:marker',
      ]);
    });

    test('a nonce-recovered creation emits exactly one submitted', () async {
      // The create request fails after the backend committed. Recovery finds
      // the marker by client nonce; it must produce one submitted event —
      // these are precisely the slow submissions that would otherwise be
      // missing from activation reporting, and double-counting them would be
      // just as wrong as losing them.
      const nonce = 'nonce-recovered-marker';
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/art-markers' &&
            request.method == 'POST') {
          return http.Response('gateway timeout', 504);
        }
        if (request.url.path == '/api/art-markers/mine') {
          return _json(<String, Object?>{
            'success': true,
            'data': <Object?>[
              <String, Object?>{
                'id': 'f6a7b8c9-d0e1-4f2a-8b3c-4d5e6f708192',
                'title': 'Recovered piece',
                'latitude': 46.05,
                'longitude': 14.5,
                'creator': _wallet,
                'metadata': <String, Object?>{'clientNonce': nonce},
              },
            ],
          });
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));

      final provider = MarkerManagementProvider(telemetry: telemetry);
      final created = await provider.createMarker(<String, dynamic>{
        'title': 'Recovered piece',
        'latitude': 46.05,
        'longitude': 14.5,
        'metadata': <String, dynamic>{'clientNonce': nonce},
      });

      expect(created, isNotNull, reason: 'the backend did commit this marker');
      final submitted = (await contributions())
          .where((e) => e.startsWith('contribution_submitted'))
          .toList(growable: false);
      expect(submitted, <String>['contribution_submitted:marker']);
    });

    test('a concurrent duplicate submission is deduped by nonce', () async {
      var posts = 0;
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/art-markers' &&
            request.method == 'POST') {
          posts += 1;
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'a7b8c9d0-e1f2-4a3b-8c4d-5e6f70819203',
              'title': 'Double tap',
              'latitude': 46.05,
              'longitude': 14.5,
              'creator': _wallet,
            },
          }, 201);
        }
        return http.Response('unexpected ${request.url.path}', 500);
      }));

      final provider = MarkerManagementProvider(telemetry: telemetry);
      final payload = <String, dynamic>{
        'title': 'Double tap',
        'latitude': 46.05,
        'longitude': 14.5,
        'metadata': <String, dynamic>{'clientNonce': 'same-nonce'},
      };
      await Future.wait(<Future<ArtMarker?>>[
        provider.createMarker(Map<String, dynamic>.from(payload)),
        provider.createMarker(Map<String, dynamic>.from(payload)),
      ]);

      expect(posts, 1);
      expect(await contributions(), <String>[
        'contribution_started:marker',
        'contribution_submitted:marker',
      ]);
    });
  });

  group('first-contribution milestone', () {
    test('fires once for an account and again for a different account',
        () async {
      const userA = '11111111-2222-4333-8444-555555555555';
      const userB = '66666666-7777-4888-8999-aaaaaaaaaaaa';

      telemetry.setActorUserId(userA);
      await telemetry.trackSuccessfulContribution(ContributionType.artwork);
      await telemetry.trackSuccessfulContribution(ContributionType.artwork);

      expect(
        await eventsOfType('first_contribution_completed'),
        hasLength(1),
        reason: 'a second artwork is not a first contribution',
      );

      // Same browser, same install: user A logs out, user B logs in. The v1
      // key was install-wide, so B could never record a first contribution.
      telemetry.setActorUserId(userB);
      await telemetry.trackSuccessfulContribution(ContributionType.artwork);

      final milestones = await eventsOfType('first_contribution_completed');
      expect(milestones, hasLength(2));
      expect(
        milestones.map((e) => e.actorUserId).toSet(),
        <String>{userA, userB},
      );
    });

    test('a legacy v1 flag suppresses at most one account', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_telemetry_first_contribution_v1': true,
      });
      final legacyQueue = InMemoryTelemetryEventQueue();
      final svc = TelemetryService.createForTest(
        queue: legacyQueue,
        sender: _NoopSender(),
      );
      await svc.ensureInitialized();
      addTearDown(() => svc.setAnalyticsPreferenceEnabled(false));

      const first = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff';
      const second = 'cccccccc-dddd-4eee-8fff-000000000000';

      svc.setActorUserId(first);
      await svc.trackSuccessfulContribution(ContributionType.marker);
      svc.setActorUserId(second);
      await svc.trackSuccessfulContribution(ContributionType.marker);

      await pumpEventQueue();
      final milestones = (await legacyQueue.peekBatch(200))
          .where((e) => e.eventType == 'first_contribution_completed')
          .toList(growable: false);
      expect(
        milestones.map((e) => e.actorUserId).toList(),
        <String>[second],
        reason: 'the flag claims the first account only, never all of them',
      );
    });
  });
}
