import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const media = <String, dynamic>{
    'url': 'https://images.example.test/art.webp',
    'creator': 'Miro Photographer',
    'creditText': 'Courtesy of the artist',
    'license': 'CC BY-SA 4.0',
    'sourceUrl': 'https://commons.wikimedia.org/wiki/File:art.webp',
  };
  const place = <String, dynamic>{
    'label': 'Ljubljana',
    'city': 'Ljubljana',
    'country': 'Slovenia',
    'latitude': 46.05,
    'longitude': 14.5,
  };

  test('artwork bootstrap seeds the ordinary public artwork cache', () {
    final provider = ArtworkProvider();
    provider.seedPublicPresentation(<String, dynamic>{
      'id': 'art-1',
      'title': 'River Memory',
      'description': 'A public installation beside the river.',
      'authorship': <String, dynamic>{'name': 'Maja Novak'},
      'primaryMedia': media,
      'place': place,
      'provenance': <String, dynamic>{
        'recordSource': <String, dynamic>{
          'name': 'Wikimedia Commons',
          'id': 'File:art.webp',
        },
      },
    });

    final artwork = provider.getArtworkById('art-1');
    expect(artwork?.title, 'River Memory');
    expect(artwork?.artist, 'Maja Novak');
    expect(artwork?.imageAuthor, 'Miro Photographer');
    expect(artwork?.imageAttribution, 'Courtesy of the artist');
    expect(artwork?.imageLicense, 'CC BY-SA 4.0');
    expect(
      artwork?.imageSourceUrl,
      'https://commons.wikimedia.org/wiki/File:art.webp',
    );
    expect(artwork?.imageUrl, media['url']);
    expect(artwork?.isPublic, isTrue);
    expect(artwork?.walletAddress, isNull);
  });

  test(
      'legacy artwork bootstrap preserves its previously normalized provenance',
      () {
    final provider = ArtworkProvider();
    provider.seedPublicPresentation(<String, dynamic>{
      'version': 1,
      'id': 'artwork-legacy',
      'title': 'Older public record',
      'authorship': <String, dynamic>{'name': 'Maja Novak'},
      'primaryMedia': <String, dynamic>{
        'url': 'https://images.example.test/legacy.webp',
      },
      'provenance': <String, dynamic>{
        'imageCredit': <String, dynamic>{
          'credit': 'Legacy image credit',
          'license': 'CC BY-SA 4.0',
          'sourceUrl': 'https://commons.wikimedia.org/wiki/File:legacy.webp',
        },
        'source': <String, dynamic>{'name': 'Wikimedia Commons'},
      },
    });

    final artwork = provider.getArtworkById('artwork-legacy');
    final metadata = artwork?.metadata ?? const <String, dynamic>{};
    expect(artwork?.imageAuthor, 'Legacy image credit');
    expect(artwork?.imageAttribution, isNull);
    expect(artwork?.imageLicense, 'CC BY-SA 4.0');
    expect(
      artwork?.imageSourceUrl,
      'https://commons.wikimedia.org/wiki/File:legacy.webp',
    );
    expect(metadata['sourceName'], 'Wikimedia Commons');
  });

  test(
    'event and exhibition bootstrap seeds remain eligible for API revalidation',
    () {
      final events = EventsProvider();
      events.seedPublicPresentation(<String, dynamic>{
        'id': 'event-1',
        'title': 'Art by the River',
        'description': 'A public walk in Ljubljana.',
        'dates': <String, dynamic>{'start': '2026-09-12T17:00:00Z'},
        'primaryMedia': media,
        'place': place,
      });
      expect(events.eventById('event-1')?.title, 'Art by the River');
      expect(events.isEventDetailHydrated('event-1'), isFalse);

      final exhibitions = ExhibitionsProvider();
      exhibitions.seedPublicPresentation(<String, dynamic>{
        'id': 'exhibition-1',
        'title': 'Shared Currents',
        'description': 'A public exhibition in Ljubljana.',
        'dates': <String, dynamic>{'start': '2026-09-01T10:00:00Z'},
        'primaryMedia': media,
        'place': place,
      });
      expect(
        exhibitions.exhibitionById('exhibition-1')?.title,
        'Shared Currents',
      );
      expect(exhibitions.isExhibitionDetailHydrated('exhibition-1'), isFalse);
    },
  );

  test('collection bootstrap seeds an immediate public cache entry', () {
    final provider = CollectionsProvider();
    provider.seedPublicPresentation(<String, dynamic>{
      'id': 'collection-1',
      'title': 'River Works',
      'description': 'A public collection of river artworks.',
      'itemCount': 4,
      'primaryMedia': media,
    });

    final collection = provider.getCollectionById('collection-1');
    expect(collection?.name, 'River Works');
    expect(collection?.isPublic, isTrue);
    expect(collection?.artworkCount, 4);
    expect(collection?.walletAddress, isEmpty);
  });
}
