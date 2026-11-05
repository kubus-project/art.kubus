import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/utils/map_marker_subject_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _institutionWallet = 'LoaderSelfDerivedWallet1111111111111111111';

UserProfile _institutionAccount() {
  return UserProfile(
    id: 'loader-self-derived',
    walletAddress: _institutionWallet,
    username: 'loader_gallery',
    displayName: 'Loader Gallery',
    bio: '',
    avatar: '',
    isInstitution: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'both marker subject call sites exclude the self-derived institution and keep directory entries',
      (tester) async {
    final profiles = ProfileProvider()..setCurrentUser(_institutionAccount());
    final institutions = InstitutionProvider()..bindProfileProvider(profiles);
    final artworks = ArtworkProvider();
    final dao = DAOProvider();
    final exhibitions = ExhibitionsProvider();
    final wallet = WalletProvider();

    late BuildContext captured;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profiles),
        ChangeNotifierProvider<InstitutionProvider>.value(value: institutions),
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<DAOProvider>.value(value: dao),
        ChangeNotifierProvider<ExhibitionsProvider>.value(value: exhibitions),
        ChangeNotifierProvider<WalletProvider>.value(value: wallet),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    // Seed directory entries (no backend: the initialize call falls back to
    // the local mock seed), then confirm the derived entry is present.
    await tester.runAsync(() => institutions.initialize(seedMockIfEmpty: true));
    final derived = institutions.getInstitutionById(_institutionWallet);
    expect(derived, isNotNull);
    expect(derived!.isSelfDerivedFromWallet, isTrue);
    final directoryIds = institutions.institutions
        .where((i) => !i.isSelfDerivedFromWallet)
        .map((i) => i.id)
        .toList();
    expect(directoryIds, isNotEmpty);

    // Call site 1: snapshot().
    final snapshot = MarkerSubjectLoader(captured).snapshot();
    expect(
      snapshot.institutions.any((i) => i.id == _institutionWallet),
      isFalse,
      reason: 'snapshot must not offer the self-derived institution',
    );
    expect(snapshot.institutions.map((i) => i.id), directoryIds);

    // Call site 2: refresh(). Network-bound fetches fail fast under
    // flutter_test's HTTP override and are handled inside the providers.
    final refreshed = await tester
        .runAsync(() => MarkerSubjectLoader(captured).refresh(force: true));
    expect(refreshed, isNotNull);
    expect(refreshed!.wasRefreshed, isTrue);
    expect(
      refreshed.institutions.any((i) => i.id == _institutionWallet),
      isFalse,
      reason: 'refresh must not offer the self-derived institution',
    );
    expect(refreshed.institutions.map((i) => i.id), directoryIds);

    // Drain the real providers' startup timers (auth retry backoff) inside the
    // fake clock so the binding does not fail on pending timers.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
  });
}
