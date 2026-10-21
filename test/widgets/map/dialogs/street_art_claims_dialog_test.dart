import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/street_art_claim.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/street_art_claims_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/map/dialogs/street_art_claims_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/qa_font_loader.dart';

class _FakeMarkerApi implements MarkerBackendApi {
  _FakeMarkerApi({this.claims = const [], this.pending, this.fail = false});
  final List<StreetArtClaim> claims;
  final Completer<List<StreetArtClaim>>? pending;
  final bool fail;
  int reviewCalls = 0;
  @override
  String? getAuthToken() => 'synthetic-test-token';
  @override
  Future<List<StreetArtClaim>> getStreetArtClaims(String markerId) async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Synthetic offline fixture');
    return claims;
  }

  @override
  Future<StreetArtClaim> submitStreetArtClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
  }) async =>
      throw UnimplementedError();
  @override
  Future<StreetArtClaim?> reviewStreetArtClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
  }) async {
    reviewCalls += 1;
    return null;
  }

  @override
  Future<List<ArtMarker>> getArtMarkersByArtwork(String artworkId) async =>
      const [];
  @override
  Future<List<ArtMarker>> getMyArtMarkers() async => const [];
  @override
  Future<ArtMarker?> createArtMarkerRecord(
    Map<String, dynamic> payload,
  ) async =>
      null;
  @override
  Future<ArtMarker?> updateArtMarkerRecord(
    String markerId,
    Map<String, dynamic> updates,
  ) async =>
      null;
  @override
  Future<bool> deleteArtMarkerRecord(String markerId) async => true;
}

final _marker = ArtMarker(
  id: 'fixture-marker-001',
  name: 'Community mural',
  description: 'Synthetic local dialog fixture.',
  position: const LatLng(46.0569, 14.5058),
  type: ArtMarkerType.streetArt,
  createdAt: DateTime.utc(2026, 1, 1),
  createdBy: 'synthetic-user',
  ownerWalletAddress: 'synthetic-owner',
);

late Directory _captureDirectory;

StreetArtClaim _claim(
  String id, {
  String? name,
  String? reason,
}) =>
    StreetArtClaim(
      id: id,
      markerId: _marker.id,
      claimantWallet: 'synthetic-wallet-address-123456789',
      claimantProfileName: name,
      reason: reason ??
          'I created this mural and can provide dated photographs and local confirmation.',
      evidenceUrl: 'https://example.invalid/evidence/fixture',
      status: StreetArtClaimStatus.pendingOwnerReview,
      reviewStage: StreetArtClaimStage.ownerReview,
      createdAt: DateTime.utc(2026, 5, 1),
    );

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Size size,
  required Brightness brightness,
  required bool owner,
  List<StreetArtClaim> claims = const [],
  bool fail = false,
  Completer<List<StreetArtClaim>>? pending,
  bool keyboard = false,
  bool reducedMotion = false,
  bool nestedReview = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 300 : 0);
  SharedPreferences.setMockInitialValues({
    'kubus_reduce_effects': reducedMotion,
    'kubus_reduce_effects_user_touched': reducedMotion,
  });
  final profile = ProfileProvider();
  profile.setCurrentUser(
    UserProfile(
      id: 'synthetic-user',
      userId: 'synthetic-user',
      walletAddress: 'synthetic-wallet',
      username: 'fixture',
      displayName: 'Synthetic profile',
      bio: '',
      avatar: '',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  final api = _FakeMarkerApi(claims: claims, pending: pending, fail: fail);
  final claimsProvider = StreetArtClaimsProvider(api: api);
  final glass = GlassCapabilitiesProvider();
  final theme = ThemeProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<StreetArtClaimsProvider>.value(
          value: claimsProvider,
        ),
        ChangeNotifierProvider<GlassCapabilitiesProvider>.value(value: glass),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  StreetArtClaimsDialog.show(
                    context: context,
                    marker: _marker,
                    isMarkerOwner: owner,
                  ),
                ),
                child: const Text('Open ownership requests'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open ownership requests'));
  await tester.pump();
  final dialogContext = tester.element(find.byType(StreetArtClaimsDialog));
  expect(MediaQuery.of(dialogContext).disableAnimations, reducedMotion);
  if (reducedMotion) {
    expect(ModalRoute.of(dialogContext)?.animation?.value, 1);
  }
  await tester.pump(const Duration(milliseconds: 260));
  if (keyboard && !nestedReview) {
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 100));
    final focusedField = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(focusedField.focusNode.hasFocus, isTrue);
  } else {
    await tester.pump(const Duration(milliseconds: 80));
  }
  if (nestedReview) {
    await tester.tap(find.text('Approve').first);
    await tester.pump();
    if (reducedMotion) {
      final noteRoute = ModalRoute.of(
        tester.element(find.byType(Dialog).last),
      );
      expect(noteRoute?.animation?.value, 1);
    }
    await tester.pump(const Duration(milliseconds: 260));
    final field = find.byType(TextField).first;
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 100));
    final focusedField = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(focusedField.focusNode.hasFocus, isTrue);
  }
  expect(find.byType(StreetArtClaimsDialog), findsOneWidget);
  expect(tester.takeException(), isNull);
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  if (fail) {
    expect(find.text(l10n.commonActionFailedToast), findsOneWidget);
    expect(find.text(l10n.mapMarkerClaimNoClaims), findsNothing);
    expect(find.text('Bad state: Synthetic offline fixture'), findsNothing);
  }
  if (pending != null) {
    expect(find.text(l10n.mapMarkerClaimLoading), findsOneWidget);
    final loadingBox = find
        .ancestor(
          of: find.text(l10n.mapMarkerClaimLoading),
          matching: find.byType(SizedBox),
        )
        .first;
    expect(tester.getSize(loadingBox).height, 120);
  }
  if (claims.isEmpty && !fail && pending == null) {
    expect(find.text(l10n.mapMarkerClaimNoClaims), findsOneWidget);
    final emptyBox = find
        .ancestor(
          of: find.text(l10n.mapMarkerClaimNoClaims),
          matching: find.byType(SizedBox),
        )
        .first;
    expect(tester.getSize(emptyBox).height, 120);
  }
  if (claims.isNotEmpty && owner) {
    final name = claims.first.claimantProfileName;
    if (name != null) expect(find.text(name), findsOneWidget);
    expect(find.text(l10n.mapMarkerClaimActionApprove), findsWidgets);
  }
  if (keyboard && nestedReview) {
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.mapMarkerClaimActionApprove), findsWidgets);
  } else if (keyboard) {
    expect(find.text(l10n.mapMarkerClaimSubmitButton), findsWidgets);
    expect(find.text(l10n.commonClose), findsOneWidget);
  }
  final dialogSize = tester.getSize(find.byType(LiquidGlassPanel).last);
  // A single short claim should wrap to its content rather than reserve the
  // old 340px list viewport. This leaves room for more of the underlying map.
  if (claims.length == 1 && owner && !nestedReview) {
    expect(dialogSize.height, lessThan(420));
    expect(tester.getSize(find.byType(ListView)).height, lessThan(340));
  }
  if (keyboard) {
    final actions = nestedReview
        ? find.text(l10n.commonCancel)
        : find.text(l10n.commonClose);
    expect(
      tester.getRect(actions.last).bottom,
      lessThanOrEqualTo(size.height - 300),
    );
  }
  // Print actual laid-out dialog dimensions to preserve reproducible visual
  // evidence alongside the rendered PNGs.
  // ignore: avoid_print
  print('R17 $name panel=$dialogSize');
  final root = tester.binding.rootElement!.renderObject!;
  final layer = root.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(root.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  final screenshotPath =
      '${_captureDirectory.path}${Platform.pathSeparator}$name.png';
  File(screenshotPath).writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('R17 screenshot=$screenshotPath');
  if (nestedReview) {
    await tester.tap(find.text(l10n.commonCancel).last);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(api.reviewCalls, 0);
  }
  await tester.tap(find.text(l10n.commonClose).last);
  await tester.pumpAndSettle();
  expect(find.byType(StreetArtClaimsDialog), findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  profile.dispose();
  glass.dispose();
  theme.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    _captureDirectory = await Directory.systemTemp.createTemp(
      'street-art-claims-r17-',
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('capture responsive ownership dialog states', (tester) async {
    await _capture(
      tester,
      name: '390-light-request-empty',
      size: const Size(390, 844),
      brightness: Brightness.light,
      owner: false,
    );
    await _capture(
      tester,
      name: '390-dark-request-keyboard-reduced',
      size: const Size(390, 844),
      brightness: Brightness.dark,
      owner: false,
      keyboard: true,
      reducedMotion: true,
    );
    await _capture(
      tester,
      name: '1440-light-request-keyboard-reduced',
      size: const Size(1440, 900),
      brightness: Brightness.light,
      owner: false,
      keyboard: true,
      reducedMotion: true,
    );
    await _capture(
      tester,
      name: '1440-light-owner-populated',
      size: const Size(1440, 900),
      brightness: Brightness.light,
      owner: true,
      claims: [
        _claim(
          'fixture-1',
          name: 'Long synthetic artist profile name for layout review',
          reason:
              'I created this public mural near the river in 2022 and have signed dated photographs, witnesses, and local archive references to establish authorship.',
        ),
      ],
    );
    await _capture(
      tester,
      name: '1440-dark-owner-error',
      size: const Size(1440, 900),
      brightness: Brightness.dark,
      owner: true,
      fail: true,
    );
    await _capture(
      tester,
      name: '390-light-owner-review-note-keyboard',
      size: const Size(390, 844),
      brightness: Brightness.light,
      owner: true,
      claims: [_claim('fixture-2')],
      keyboard: true,
      reducedMotion: false,
      nestedReview: true,
    );
    final pending = Completer<List<StreetArtClaim>>();
    await _capture(
      tester,
      name: '390-dark-request-loading',
      size: const Size(390, 844),
      brightness: Brightness.dark,
      owner: false,
      pending: pending,
    );
    pending.complete(const []);
  });
}
