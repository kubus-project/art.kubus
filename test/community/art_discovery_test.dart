import 'package:art_kubus/community/art_discovery.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

final DateTime _now = DateTime.utc(2026, 10, 11, 12);

// Ljubljana centre.
const ArtDiscoveryLocation _ljubljana = ArtDiscoveryLocation(
  latitude: 46.0511,
  longitude: 14.5051,
  source: ArtDiscoveryLocationSource.mapCenter,
);

CommunityPost _post(
  String id, {
  String wallet = 'wallet-a',
  String content = 'A post',
  String category = 'post',
  Duration age = const Duration(days: 1),
  double? lat,
  double? lng,
  double? distanceKm,
  int likes = 0,
  int comments = 0,
  String? artworkId,
}) =>
    CommunityPost(
      id: id,
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {
          'displayName': 'Name $wallet',
          'username': wallet,
          'walletAddress': wallet
        },
        fallbackLabel: 'x',
      ),
      content: content.isEmpty ? 'x' : '$content $id',
      timestamp: _now.subtract(age),
      category: category,
      likeCount: likes,
      commentCount: comments,
      distanceKm: distanceKm,
      location: lat == null ? null : CommunityLocation(lat: lat, lng: lng),
      artwork: artworkId == null
          ? null
          : CommunityArtworkReference(id: artworkId, title: 't'),
    );

Artwork _art(
  String id, {
  String wallet = 'wallet-a',
  Duration age = const Duration(days: 30),
  double lat = 0,
  double lng = 0,
  bool liked = false,
  int likes = 0,
}) =>
    Artwork(
      id: id,
      walletAddress: wallet,
      title: 'Artwork $id',
      artist: wallet,
      description: '',
      position: LatLng(lat, lng),
      rewards: 0,
      createdAt: _now.subtract(age),
      isLikedByCurrentUser: liked,
      likesCount: likes,
    );

Exhibition _show(
  String id, {
  bool published = true,
  Duration? startsIn,
  Duration? endsIn,
  double? lat,
  double? lng,
}) =>
    Exhibition(
      id: id,
      title: 'Show $id',
      status: published ? 'published' : 'draft',
      startsAt: startsIn == null ? null : _now.add(startsIn),
      endsAt: endsIn == null ? null : _now.add(endsIn),
      lat: lat,
      lng: lng,
      createdAt: _now.subtract(const Duration(days: 3)),
    );

List<ArtDiscoveryItem> _rank(
  ArtDiscoveryCandidates c, {
  ArtDiscoverySignals signals = ArtDiscoverySignals.none,
  ArtDiscoveryLocation? location,
  double radiusKm = 3,
}) =>
    ArtDiscoveryRanker.rank(
      candidates: c,
      signals: signals,
      now: _now,
      location: location,
      radiusKm: radiusKm,
    );

void main() {
  test('a qualifying artwork video is not suppressed by an earlier still post',
      () {
    final still = _post('still', artworkId: 'work', likes: 5);
    final video = _post('video', artworkId: 'work')
        .copyWith(mediaUrls: ['https://example.test/work.mp4']);
    final duplicateVideo = _post('duplicate-video', artworkId: 'work')
        .copyWith(mediaUrls: ['https://example.test/work.mp4']);
    final items = _rank(
        ArtDiscoveryCandidates(publicPosts: [still, video, duplicateVideo]));
    expect(items.where((item) => item.kind == ArtDiscoveryKind.post),
        hasLength(2));
    expect(items.any((item) => item.id == 'still'), isTrue);
    expect(
        items.any(
            (item) => item.post!.mediaUrls.any((url) => url.endsWith('.mp4'))),
        isTrue);
  });

  group('personalised signals', () {
    test('a followed artist outranks a fresher stranger', () {
      final items = _rank(
        ArtDiscoveryCandidates(
          publicPosts: [
            _post('stranger',
                wallet: 'wallet-z', age: const Duration(hours: 1)),
            _post('friend', wallet: 'wallet-f', age: const Duration(days: 6)),
          ],
        ),
        signals: const ArtDiscoverySignals(followedWallets: {'wallet-f'}),
      );
      expect(items.first.id, 'friend');
      expect(items.first.reason, ArtDiscoveryReason.fromFollowed);
    });

    test('saved artworks are a signal, and a like counts as one too', () {
      final items = _rank(
        ArtDiscoveryCandidates(artworks: [
          _art('plain', wallet: 'w1'),
          _art('saved', wallet: 'w2'),
          _art('liked', wallet: 'w3', liked: true),
        ]),
        signals: const ArtDiscoverySignals(savedArtworkIds: {'saved'}),
      );
      expect(items.map((i) => i.id).toList().last, 'plain');
      expect(items.first.reason, ArtDiscoveryReason.forYou);
    });

    test('a guest with no signals still gets real public content', () {
      final items = _rank(
        ArtDiscoveryCandidates(
          publicPosts: [_post('p1', category: 'review')],
          artworks: [_art('fresh', age: const Duration(days: 2))],
          exhibitions: [_show('e1', endsIn: const Duration(days: 20))],
        ),
      );
      expect(items.map((i) => i.kind).toSet(), {
        ArtDiscoveryKind.post,
        ArtDiscoveryKind.artwork,
        ArtDiscoveryKind.exhibition,
      });
      expect(
        items.firstWhere((i) => i.id == 'fresh').reason,
        ArtDiscoveryReason.newArtwork,
      );
      expect(
        items.firstWhere((i) => i.id == 'p1').reason,
        ArtDiscoveryReason.recentReview,
      );
    });
  });

  group('nearby is honest', () {
    test('only entries inside the radius are labelled nearby', () {
      final items = _rank(
        ArtDiscoveryCandidates(
          artworks: [
            _art('close', lat: 46.0520, lng: 14.5060),
            _art('far', lat: 48.2082, lng: 16.3738),
          ],
        ),
        location: _ljubljana,
      );
      final close = items.firstWhere((i) => i.id == 'close');
      final far = items.firstWhere((i) => i.id == 'far');
      expect(close.reason, ArtDiscoveryReason.nearby);
      expect(close.distanceKm, isNotNull);
      expect(far.reason, isNot(ArtDiscoveryReason.nearby));
      expect(far.distanceKm, isNull);
    });

    test('a public post is nearby only through its own coordinates', () {
      final items = _rank(
        ArtDiscoveryCandidates(publicPosts: [
          _post('here', lat: 46.0530, lng: 14.5070),
          _post('elsewhere', lat: 41.9028, lng: 12.4964),
          _post('unlocated'),
        ]),
        location: _ljubljana,
      );
      expect(
        items.firstWhere((i) => i.id == 'here').reason,
        ArtDiscoveryReason.nearby,
      );
      expect(
        items.firstWhere((i) => i.id == 'elsewhere').reason,
        ArtDiscoveryReason.communityDiscussion,
      );
      expect(
        items.firstWhere((i) => i.id == 'unlocated').reason,
        ArtDiscoveryReason.communityDiscussion,
      );
    });

    test('the server distance of an area post is trusted', () {
      final items = _rank(
        ArtDiscoveryCandidates(nearbyPosts: [
          _post('srv', distanceKm: 1.2),
          _post('srv-far', distanceKm: 40),
        ]),
        location: _ljubljana,
      );
      expect(
        items.firstWhere((i) => i.id == 'srv').reason,
        ArtDiscoveryReason.nearby,
      );
      expect(
        items.firstWhere((i) => i.id == 'srv-far').reason,
        isNot(ArtDiscoveryReason.nearby),
      );
    });

    test('a widened radius never turns distant content into "nearby"', () {
      final items = _rank(
        ArtDiscoveryCandidates(artworks: [
          // Zagreb: ~118 km away, inside a widened 250 km radius.
          _art('zagreb', lat: 45.8150, lng: 15.9819),
        ]),
        location: _ljubljana,
        radiusKm: 250,
      );
      expect(items.single.reason, isNot(ArtDiscoveryReason.nearby));
      expect(items.single.distanceKm, isNotNull,
          reason: 'still a ranking signal and still known');
    });

    test('closer beats farther at equal age', () {
      final items = _rank(
        ArtDiscoveryCandidates(artworks: [
          _art('a-far', wallet: 'a', lat: 46.0700, lng: 14.5300),
          _art('b-near', wallet: 'b', lat: 46.0512, lng: 14.5052),
        ]),
        location: _ljubljana,
        radiusKm: 5,
      );
      expect(items.first.id, 'b-near');
    });
  });

  group('exhibitions', () {
    test('ended and unpublished shows never appear', () {
      final items = _rank(ArtDiscoveryCandidates(exhibitions: [
        _show('past', endsIn: const Duration(days: -1)),
        _show('draft', published: false),
        _show('live', endsIn: const Duration(days: 5)),
        _show('soon', startsIn: const Duration(days: 4)),
        _show('later', startsIn: const Duration(days: 90)),
      ]));
      expect(items.map((i) => i.id).toSet(), {'live', 'soon'});
    });
  });

  group('composition', () {
    test('one author cannot fill the feed', () {
      final posts = [
        for (var i = 0; i < 6; i++)
          _post('a$i', wallet: 'prolific', age: Duration(hours: i + 1)),
        _post('b1', wallet: 'other-1', age: const Duration(days: 3)),
        _post('b2', wallet: 'other-2', age: const Duration(days: 3)),
      ];
      final items = _rank(ArtDiscoveryCandidates(publicPosts: posts));
      final firstFour = items.take(4).map((i) => i.authorKey).toList();
      expect(
        firstFour.where((a) => a == 'prolific').length,
        lessThan(4),
        reason: 'damping lets other voices in before the fourth entry',
      );
    });

    test('one post per artwork and no copy of the same text', () {
      final items = _rank(ArtDiscoveryCandidates(
        publicPosts: [
          _post('r1', artworkId: 'art-1', category: 'review'),
          _post('r2',
              wallet: 'wallet-b', artworkId: 'art-1', category: 'review'),
          CommunityPost(
            id: 'dup1',
            authorIdentityData: ProfileIdentityData.fromCompactAuthor(
              const {'displayName': 'c', 'username': 'c', 'walletAddress': 'c'},
              fallbackLabel: 'x',
            ),
            content: 'Same   text',
            timestamp: _now,
          ),
          CommunityPost(
            id: 'dup2',
            authorIdentityData: ProfileIdentityData.fromCompactAuthor(
              const {'displayName': 'c', 'username': 'c', 'walletAddress': 'c'},
              fallbackLabel: 'x',
            ),
            content: 'same text',
            timestamp: _now.subtract(const Duration(minutes: 1)),
          ),
        ],
      ));
      expect(items.where((i) => i.artworkRefId == 'art-1').length, 1);
      expect(items.where((i) => i.id.startsWith('dup')).length, 1);
    });

    group('captionless posts', () {
      CommunityPost media(
        String id, {
        String wallet = 'c',
        String content = '',
        List<String> urls = const <String>[],
        String? originalPostId,
        bool anonymous = false,
      }) =>
          CommunityPost(
            id: id,
            authorIdentityData: ProfileIdentityData.fromCompactAuthor(
              anonymous
                  ? const <String, dynamic>{}
                  : {
                      'displayName': wallet,
                      'username': wallet,
                      'walletAddress': wallet,
                    },
              fallbackLabel: 'x',
            ),
            content: content,
            mediaUrls: urls,
            originalPostId: originalPostId,
            timestamp: _now,
          );

      List<String> kept(List<CommunityPost> posts) =>
          _rank(ArtDiscoveryCandidates(publicPosts: posts))
              .map((i) => i.id)
              .toList();

      test('distinct media from one author stays distinct', () {
        final ids = kept([
          media('m1', urls: const ['https://x/a.jpg']),
          media('m2', urls: const ['https://x/b.jpg']),
          media('m3', urls: const ['https://x/c.mp4']),
        ]);
        expect(ids.toSet(), {'m1', 'm2', 'm3'});
      });

      test('the very same media from the same author is one entry', () {
        final ids = kept([
          media('m1', urls: const ['https://x/a.jpg']),
          media('m2', urls: const [' https://x/a.jpg ']),
        ]);
        expect(ids.length, 1);
      });

      test('captionless posts with nothing to compare are never copies', () {
        final ids = kept([media('e1'), media('e2'), media('e3')]);
        expect(ids.toSet(), {'e1', 'e2', 'e3'});
      });

      test('unknown authors never collapse unrelated posts', () {
        final ids = kept([
          media('u1', anonymous: true, urls: const ['https://x/a.jpg']),
          media('u2', anonymous: true, urls: const ['https://x/a.jpg']),
          media('u3', anonymous: true, content: 'same words'),
          media('u4', anonymous: true, content: 'same words'),
        ]);
        expect(ids.toSet(), {'u1', 'u2', 'u3', 'u4'});
      });

      test('reposts of different originals stay distinct', () {
        final ids = kept([
          media('r1', originalPostId: 'orig-1'),
          media('r2', originalPostId: 'orig-2'),
        ]);
        expect(ids.toSet(), {'r1', 'r2'});
      });

      test('the same caption with different pictures is not a copy', () {
        final ids = kept([
          media('s1',
              content: 'Opening night', urls: const ['https://x/1.jpg']),
          media('s2',
              content: 'Opening night', urls: const ['https://x/2.jpg']),
        ]);
        expect(ids.toSet(), {'s1', 's2'});
      });
    });

    test('an entry offered twice is kept once', () {
      final p = _post('same');
      final items = _rank(ArtDiscoveryCandidates(
        nearbyPosts: [p],
        publicPosts: [p],
      ));
      expect(items.where((i) => i.id == 'same').length, 1);
    });

    test('the same input always gives the same order', () {
      final candidates = ArtDiscoveryCandidates(
        publicPosts: [for (var i = 0; i < 12; i++) _post('p$i', wallet: 'w$i')],
        artworks: [for (var i = 0; i < 12; i++) _art('a$i', wallet: 'x$i')],
      );
      final one = _rank(candidates).map((i) => i.key).toList();
      final two = _rank(candidates).map((i) => i.key).toList();
      final reversed = _rank(ArtDiscoveryCandidates(
        publicPosts: candidates.publicPosts.reversed.toList(),
        artworks: candidates.artworks.reversed.toList(),
      )).map((i) => i.key).toList();
      expect(two, one);
      expect(reversed, one);
    });

    test('no invented content: empty input gives an empty feed', () {
      expect(_rank(const ArtDiscoveryCandidates()), isEmpty);
    });

    test('private or inactive artworks are never offered', () {
      final hidden = Artwork(
        id: 'hidden',
        title: 't',
        artist: 'a',
        description: '',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: _now,
        isPublic: false,
      );
      expect(
        _rank(ArtDiscoveryCandidates(artworks: [hidden])),
        isEmpty,
      );
    });
  });

  test('haversine matches a known distance', () {
    final km = ArtDiscoveryRanker.haversineKm(
      const LatLng(46.0569, 14.5058),
      const LatLng(45.8150, 15.9819),
    );
    expect(km, closeTo(117.3, 1));
  });
}
