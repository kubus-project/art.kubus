import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/artwork_private_preview_client.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/artwork_private_preview_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _artworkId = '11111111-1111-4111-8111-111111111111';
const _coverPath = '/api/artworks/$_artworkId/media/cover';

Artwork _draftArtwork() => Artwork(
      id: _artworkId,
      title: 'Draft',
      artist: '',
      description: '',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime.utc(2026),
      isPublic: false,
      mediaPreview: const ArtworkMediaPreviewDescriptor(
        auth: 'bearer',
        cover: _coverPath,
        gallery: <String?>[],
        poap: null,
      ),
    );

class _PreviewApi implements ArtworkPrivatePreviewApi {
  Future<Artwork> Function()? onDetail;
  Future<List<int>> Function()? onBytes;
  int detailCalls = 0;
  int byteCalls = 0;

  @override
  Future<Artwork> getArtworkDetailWithMediaPreview(String artworkId) async {
    detailCalls += 1;
    return onDetail?.call() ?? _draftArtwork();
  }

  @override
  Future<List<int>> getArtworkPrivateMediaBytes({
    required String artworkId,
    required String slot,
    required String descriptorPath,
  }) async {
    byteCalls += 1;
    return onBytes?.call() ?? <int>[1, 2, 3];
  }
}

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, height: 120, child: child)),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey('preview-owner');
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
  });

  testWidgets(
    'public artwork keeps its normal fallback and skips preview transport',
    (tester) async {
      final api = _PreviewApi();
      final client = ArtworkPrivatePreviewClient(
        api: api,
        listenForIdentityChanges: false,
      );
      const fallback = Text('public media');

      await tester.pumpWidget(
        _app(
          ArtworkPrivatePreviewImage(
            artworkId: _artworkId,
            isPublic: true,
            slot: 'cover',
            publicFallback: fallback,
            client: client,
          ),
        ),
      );

      expect(find.text('public media'), findsOneWidget);
      expect(api.detailCalls, 0);
      expect(api.byteCalls, 0);
      client.dispose();
    },
  );

  testWidgets(
    'a denied private preview shows unavailable copy without public fallback',
    (tester) async {
      final api = _PreviewApi()
        ..onBytes = () async => throw const BackendApiRequestException(
              statusCode: 404,
              path: _coverPath,
            );
      final client = ArtworkPrivatePreviewClient(
        api: api,
        listenForIdentityChanges: false,
      );

      await tester.pumpWidget(
        _app(
          ArtworkPrivatePreviewImage(
            artworkId: _artworkId,
            isPublic: false,
            slot: 'cover',
            descriptor: _draftArtwork().mediaPreview,
            publicFallback: const Text('unsafe public fallback'),
            client: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('unsafe public fallback'), findsNothing);
      expect(find.bySemanticsLabel('This preview is not available.'),
          findsOneWidget);
      expect(api.byteCalls, 1);
      client.dispose();
    },
  );

  testWidgets('authorized draft bytes render from an in-memory image', (
    tester,
  ) async {
    final api = _PreviewApi()
      ..onBytes = () async => base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/yL8AAAAASUVORK5CYII=',
          );
    final client = ArtworkPrivatePreviewClient(
      api: api,
      listenForIdentityChanges: false,
    );
    await tester.pumpWidget(
      _app(
        ArtworkPrivatePreviewImage(
          artworkId: _artworkId,
          isPublic: false,
          slot: 'cover',
          descriptor: _draftArtwork().mediaPreview,
          publicFallback: const Text('unsafe public fallback'),
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('private-artwork-preview-bytes')),
    );
    expect(image.image, isA<MemoryImage>());
    expect(api.byteCalls, 1);
    expect(find.text('unsafe public fallback'), findsNothing);
    client.dispose();
  });

  testWidgets('late private bytes are rejected and cleared on account change', (
    tester,
  ) async {
    final bytesFuture = Completer<List<int>>();
    final api = _PreviewApi()..onBytes = () => bytesFuture.future;
    final client = ArtworkPrivatePreviewClient(api: api);
    await tester.pumpWidget(
      _app(
        ArtworkPrivatePreviewImage(
          artworkId: _artworkId,
          isPublic: false,
          slot: 'cover',
          descriptor: _draftArtwork().mediaPreview,
          publicFallback: const Text('unsafe public fallback'),
          client: client,
        ),
      ),
    );
    await tester.pump();

    AccountIdentity.setAccountKey('preview-other-account');
    await AccountIdentity.notifyChanged();
    bytesFuture.complete(<int>[1, 2, 3]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('private-artwork-preview-bytes')),
      findsNothing,
    );
    expect(find.text('unsafe public fallback'), findsNothing);
    expect(
      find.bySemanticsLabel('This preview is not available.'),
      findsOneWidget,
    );
    client.dispose();
  });

  testWidgets('received bytes reach the image without a second copy', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/yL8AAAAASUVORK5CYII=',
    );
    final api = _PreviewApi()..onBytes = () async => bytes;
    final client = ArtworkPrivatePreviewClient(
      api: api,
      listenForIdentityChanges: false,
    );
    await tester.pumpWidget(
      _app(
        ArtworkPrivatePreviewImage(
          artworkId: _artworkId,
          isPublic: false,
          slot: 'cover',
          descriptor: _draftArtwork().mediaPreview,
          publicFallback: const Text('unsafe public fallback'),
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('private-artwork-preview-bytes')),
    );
    expect((image.image as MemoryImage).bytes, same(bytes));
    client.dispose();
  });
}
