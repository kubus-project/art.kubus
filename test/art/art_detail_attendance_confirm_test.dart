import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/collab_member.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/collab_api.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeArtworkBackendApi implements ArtworkBackendApi {
  final Artwork artwork;

  _FakeArtworkBackendApi(this.artwork);

  @override
  Future<Artwork> getArtwork(String artworkId) async => artwork;

  @override
  Future<int?> recordArtworkView(String artworkId) async => null;

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Artwork?> updateArtwork(String artworkId, Map<String, dynamic> updates) {
    throw UnimplementedError();
  }

  @override
  Future<Artwork?> publishArtwork(String artworkId) {
    throw UnimplementedError();
  }

  @override
  Future<Artwork?> unpublishArtwork(String artworkId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> likeArtwork(String artworkId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> unlikeArtwork(String artworkId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> discoverArtworkWithCount(String artworkId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ArtworkComment> createArtworkComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ArtworkComment> editArtworkComment({
    required String commentId,
    required String content,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int?> deleteArtworkComment(String commentId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> likeComment(String commentId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> unlikeComment(String commentId) {
    throw UnimplementedError();
  }
}

class _FakeCollabApi implements CollabApi {
  @override
  String? getAuthToken() => null;

  @override
  Future<List<CollabMember>> listCollaborators(String entityType, String entityId) async =>
      const <CollabMember>[];

  @override
  Future<List<CollabInvite>> listMyCollabInvites() async => const <CollabInvite>[];

  @override
  Future<CollabInvite?> inviteCollaborator(String entityType, String entityId, String invitedIdentifier, String role) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    throw UnimplementedError();
  }

  @override
  Future<void> declineInvite(String inviteId) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateCollaboratorRole(String entityType, String entityId, String memberUserId, String role) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeCollaborator(String entityType, String entityId, String memberUserId) {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Confirm attendance button toggles with proximity', (tester) async {
    const artworkId = 'art_1';
    const markerId = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';

    final artwork = Artwork(
      id: artworkId,
      title: 'Artwork',
      artist: 'Artist',
      description: 'Desc',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime(2020, 1, 1),
    );

    final artworkProvider = ArtworkProvider(
      backendApi: _FakeArtworkBackendApi(artwork),
    )..addOrUpdateArtwork(artwork);

    final profileProvider = ProfileProvider()
      ..setCurrentUser(UserProfile(
        id: 'user_1',
        walletAddress: '0xabc',
        username: 'user',
        displayName: 'User',
        bio: '',
        avatar: '',
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime(2020, 1, 1),
      ));

    final walletProvider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting('0xabc');

    final attendanceProvider = AttendanceProvider()
      ..bindAuthContext(isSignedIn: true, walletAddress: '0xabc')
      ..updateProximity(
        markerId: markerId,
        lat: 0,
        lng: 0,
        distanceMeters: 10,
        activationRadiusMeters: 50,
        requiresProximity: true,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );

    attendanceProvider.stateFor(markerId).challenge = AttendanceChallengeDto(
      markerId: markerId,
      alreadyAttended: false,
      challengeToken: 'token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

    expect(attendanceProvider.stateFor(markerId).canAttemptConfirm, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: artworkProvider),
          ChangeNotifierProvider.value(value: profileProvider),
          ChangeNotifierProvider.value(value: walletProvider),
          ChangeNotifierProvider.value(value: TaskProvider()),
          ChangeNotifierProvider(
            create: (_) => CollabProvider(api: _FakeCollabApi()),
          ),
          ChangeNotifierProvider.value(value: attendanceProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArtDetailScreen(
            artworkId: artworkId,
            attendanceMarkerId: markerId,
          ),
        ),
      ),
    );

    // Wait for the detail screen to complete its post-frame artwork load.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(InlineLoading).evaluate().isEmpty) break;
    }

    await tester.scrollUntilVisible(
      find.text('Confirm attendance'),
      800,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Confirm attendance'), findsOneWidget);

    attendanceProvider.updateProximity(
      markerId: markerId,
      lat: 0,
      lng: 0,
      distanceMeters: 200,
      activationRadiusMeters: 50,
      requiresProximity: true,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    await tester.pump();

    expect(find.text('Confirm attendance'), findsNothing);
  });
}
