import 'dart:convert';

import '../utils/media_url_resolver.dart';
import 'event.dart' show KubusEvent;

class InstitutionDiscipline {
  const InstitutionDiscipline(
      {required this.code, required this.labelEn, required this.labelSl});
  final String code;
  final String labelEn;
  final String labelSl;

  String labelFor(String languageCode) =>
      languageCode == 'sl' && labelSl.isNotEmpty ? labelSl : labelEn;
  Map<String, dynamic> toJson() =>
      {'code': code, 'labelEn': labelEn, 'labelSl': labelSl};
  @override
  bool operator ==(Object other) =>
      other is InstitutionDiscipline &&
      code == other.code &&
      labelEn == other.labelEn &&
      labelSl == other.labelSl;
  @override
  int get hashCode => Object.hash(code, labelEn, labelSl);
}

/// Public venue kind. The exact backend `kind` code is used when present; the
/// older `type` guess (museum, gallery, cultural_center) is only a fallback.
enum InstitutionKind {
  museum,
  gallery,
  artsCentre,
  exhibitionSpace,
  culturalCentre,
  other;

  /// Resolves the displayed kind, or null when neither field names one.
  /// Unrecognised exact codes (archive, library, ...) resolve to [other].
  static InstitutionKind? resolve({String? kind, String? type}) {
    final code = kind?.trim().toLowerCase();
    if (code != null && code.isNotEmpty) {
      return switch (code) {
        'museum' => InstitutionKind.museum,
        'gallery' => InstitutionKind.gallery,
        'arts_centre' => InstitutionKind.artsCentre,
        'exhibition_space' => InstitutionKind.exhibitionSpace,
        'cultural_centre' => InstitutionKind.culturalCentre,
        _ => InstitutionKind.other,
      };
    }
    return switch (type?.trim().toLowerCase()) {
      'museum' => InstitutionKind.museum,
      'gallery' => InstitutionKind.gallery,
      'cultural_center' => InstitutionKind.culturalCentre,
      _ => null,
    };
  }
}

/// Admission category approved in visitor information.
enum InstitutionAdmission {
  free,
  paid,
  mixed;

  static InstitutionAdmission? parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'free' => InstitutionAdmission.free,
      'paid' => InstitutionAdmission.paid,
      'mixed' => InstitutionAdmission.mixed,
      _ => null,
    };
  }
}

/// Public credit and links supplied for one institution image.
/// Invalid or absent URLs are discarded at the JSON boundary.
class InstitutionImageAttribution {
  const InstitutionImageAttribution({
    this.credit,
    this.author,
    this.sourceUrl,
    this.licenseUrl,
    this.depictedWorks = const [],
  });

  /// The full credit line required by the licence.
  final String? credit;

  /// The photographer alone, when the backend provides it.
  final String? author;
  final String? sourceUrl;
  final String? licenseUrl;

  /// Creators of works visible in the image, credited whatever their
  /// copyright status. A credit is not a permission.
  final List<InstitutionDepictedWork> depictedWorks;

  /// Short attribution for display next to separate licence and source links:
  /// the author when known, otherwise the full credit line.
  String? get displayCredit => author ?? credit;

  bool get isEmpty => credit == null && sourceUrl == null && licenseUrl == null;

  static final RegExp _ccVersion = RegExp(r'^\d+\.\d+$');
  static const Set<String> _ccTypes = {
    'by',
    'by-sa',
    'by-nc',
    'by-nd',
    'by-nc-sa',
    'by-nc-nd',
  };

  /// Canonical Creative Commons path segments of [licenseUrl], or null.
  List<String>? get _licensePath {
    final url = licenseUrl;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'creativecommons.org') return null;
    return uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
  }

  /// Short licence name derived from [licenseUrl], for example `CC BY-SA 4.0`.
  /// Null when the URL is not a recognised Creative Commons licence.
  String? get licenseName {
    final path = _licensePath;
    if (path == null || path.length != 3) return null;
    final version = path[2];
    if (!_ccVersion.hasMatch(version)) return null;
    if (path[0] == 'licenses' && _ccTypes.contains(path[1])) {
      return 'CC ${path[1].toUpperCase()} $version';
    }
    if (path[0] == 'publicdomain' && path[1] == 'zero') {
      return 'CC0 $version';
    }
    return null;
  }

  /// True when [licenseUrl] is the Creative Commons public domain mark.
  bool get isPublicDomain {
    final path = _licensePath;
    return path != null &&
        path.length == 3 &&
        path[0] == 'publicdomain' &&
        path[1] == 'mark' &&
        _ccVersion.hasMatch(path[2]);
  }

  @override
  bool operator ==(Object other) =>
      other is InstitutionImageAttribution &&
      other.credit == credit &&
      other.author == author &&
      _sameWorks(other.depictedWorks, depictedWorks) &&
      other.sourceUrl == sourceUrl &&
      other.licenseUrl == licenseUrl;

  @override
  int get hashCode => Object.hash(
      credit, author, sourceUrl, licenseUrl, Object.hashAll(depictedWorks));

  static bool _sameWorks(
      List<InstitutionDepictedWork> a, List<InstitutionDepictedWork> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  factory InstitutionImageAttribution.fromJson(Object? value) {
    if (value is! Map) return const InstitutionImageAttribution();
    return InstitutionImageAttribution(
      credit: _cleanText(value['credit']),
      author: _cleanText(value['author']),
      depictedWorks:
          InstitutionDepictedWork.listFromJson(value['depictedWorks']),
      sourceUrl: _safeAttributionUrl(value['sourceUrl']),
      licenseUrl: _safeAttributionUrl(value['licenseUrl']),
    );
  }

  Map<String, dynamic> toJson() => {
        'credit': credit,
        if (author != null) 'author': author,
        if (depictedWorks.isNotEmpty)
          'depictedWorks': [for (final w in depictedWorks) w.toJson()],
        'sourceUrl': sourceUrl,
        'licenseUrl': licenseUrl,
      };

  static String? _cleanText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String? _safeAttributionUrl(Object? value) {
    final text = _cleanText(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }
}

/// The creator of a work visible in an institution image (the building's
/// architect, a sculptor), credited beside the photographer.
class InstitutionDepictedWork {
  const InstitutionDepictedWork({required this.type, required this.author});

  /// `architecture`, `sculpture`, `mural` or `artwork`.
  final String type;
  final String author;

  bool get isArchitecture => type == 'architecture';

  static const Set<String> _types = {
    'architecture',
    'sculpture',
    'mural',
    'artwork'
  };

  static List<InstitutionDepictedWork> listFromJson(Object? value) {
    if (value is! List) return const [];
    final out = <InstitutionDepictedWork>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final type = entry['type'];
      final author = entry['author'];
      if (type is! String || !_types.contains(type)) continue;
      if (author is! String || author.trim().isEmpty) continue;
      out.add(InstitutionDepictedWork(type: type, author: author.trim()));
    }
    return List.unmodifiable(out);
  }

  Map<String, dynamic> toJson() => {'type': type, 'author': author};

  @override
  bool operator ==(Object other) =>
      other is InstitutionDepictedWork &&
      other.type == type &&
      other.author == author;

  @override
  int get hashCode => Object.hash(type, author);
}

/// Public visitor information approved independently from source collection.
class InstitutionVisitorAccess {
  const InstitutionVisitorAccess(
      {required this.sourceUrl,
      required this.verifiedAt,
      required this.visitorInfo,
      this.bookingUrl});

  final String sourceUrl;
  final DateTime verifiedAt;
  final Map<String, dynamic> visitorInfo;
  final String? bookingUrl;

  String? _infoText(String key) {
    final value = visitorInfo[key];
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// Opening hours as approved text, in the language of its source.
  String? get openingHoursText => _infoText('openingHoursText');

  /// Accessibility information as approved text.
  String? get accessibilityNote => _infoText('accessibilityNote');

  /// Known admission category, or null when the text is free-form or unknown.
  InstitutionAdmission? get admission =>
      InstitutionAdmission.parse(_infoText('admission'));

  /// Admission text that is not one of the known categories, or null.
  String? get admissionText {
    final raw = _infoText('admission');
    if (raw == null ||
        InstitutionAdmission.parse(raw) != null ||
        raw.toLowerCase() == 'unknown') {
      return null;
    }
    return raw;
  }

  static InstitutionVisitorAccess? fromJson(Object? value) {
    if (value is! Map || value['status'] != 'approved') return null;
    final source =
        InstitutionImageAttribution._safeAttributionUrl(value['sourceUrl']);
    final date = value['verifiedAt'] is String
        ? DateTime.tryParse(value['verifiedAt'] as String)
        : null;
    if (source == null || date == null) return null;
    final rawInfo = value['visitorInfo'];
    final info = rawInfo is Map
        ? Map<String, dynamic>.fromEntries(rawInfo.entries
            .where((e) => e.key is String)
            .map((e) => MapEntry(e.key as String, e.value)))
        : <String, dynamic>{};
    return InstitutionVisitorAccess(
        sourceUrl: source,
        verifiedAt: date,
        visitorInfo: info,
        bookingUrl: InstitutionImageAttribution._safeAttributionUrl(
            value['bookingUrl']));
  }

  Map<String, dynamic> toJson() => {
        'status': 'approved',
        'sourceUrl': sourceUrl,
        'verifiedAt': verifiedAt.toIso8601String(),
        'visitorInfo': visitorInfo,
        'bookingUrl': bookingUrl
      };

  @override
  bool operator ==(Object other) =>
      other is InstitutionVisitorAccess &&
      sourceUrl == other.sourceUrl &&
      verifiedAt == other.verifiedAt &&
      bookingUrl == other.bookingUrl &&
      jsonEncode(visitorInfo) == jsonEncode(other.visitorInfo);
  @override
  int get hashCode =>
      Object.hash(sourceUrl, verifiedAt, bookingUrl, jsonEncode(visitorInfo));
}

// Institution and Events Models
class Institution {
  final String id;
  final String name;
  final String description;
  final String type; // 'gallery', 'museum', 'cultural_center'

  /// Exact venue kind code from the backend (`museum`, `arts_centre`, ...).
  /// Null for payloads that predate the field.
  final String? kind;
  final String address;
  final double latitude;
  final double longitude;
  final String contactEmail;
  final String website;

  /// Schema-backed cover (`institutions.cover_image_url`), raw reference.
  final String? coverImageUrl;

  /// Schema-backed logo (`institutions.logo_url`), raw reference.
  final String? logoUrl;
  final InstitutionImageAttribution? coverAttribution;
  final InstitutionImageAttribution? logoAttribution;
  final InstitutionVisitorAccess? visitorAccess;
  final List<InstitutionDiscipline> disciplines;
  final InstitutionStats stats;
  final bool isVerified;
  final DateTime createdAt;

  /// True only for the synthetic entry the provider builds from the signed-in
  /// user's own wallet. It is the user's own identity, so it is a default
  /// (event creator) but must not appear in search or map subject lists.
  final bool isSelfDerivedFromWallet;

  Institution({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.kind,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.contactEmail,
    required this.website,
    this.coverImageUrl,
    this.logoUrl,
    this.coverAttribution,
    this.logoAttribution,
    this.visitorAccess,
    this.disciplines = const [],
    required this.stats,
    this.isVerified = false,
    required this.createdAt,
    this.isSelfDerivedFromWallet = false,
  });

  /// Hero imagery for an institution: the first safe of the cover, then the
  /// logo. An unsafe cover falls through to the logo.
  ///
  /// Every surface (detail hero, search thumbnail) uses this one order.
  String? get heroImageRef =>
      MediaUrlResolver.firstSafeRef(<String?>[coverImageUrl, logoUrl]);

  /// The venue kind to display, from [kind] or the legacy [type] guess.
  InstitutionKind? get institutionKind =>
      InstitutionKind.resolve(kind: kind, type: type);

  factory Institution.fromJson(Map<String, dynamic> json) {
    final boundary = _InstitutionImageBoundary.read(json);
    return Institution(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      kind: _nullableTrimmedString(json['kind']),
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      contactEmail: json['contactEmail'],
      website: json['website'],
      coverImageUrl: boundary.coverImageUrl,
      logoUrl: boundary.logoUrl,
      coverAttribution: _attribution(json['coverAttribution']),
      logoAttribution: _attribution(json['logoAttribution']),
      visitorAccess: InstitutionVisitorAccess.fromJson(json['visitorAccess']),
      disciplines: (json['disciplines'] is List
              ? json['disciplines'] as List
              : const [])
          .whereType<Map>()
          .where((v) =>
              v['code'] is String &&
              v['labelEn'] is String &&
              (v['labelEn'] as String).trim().isNotEmpty)
          .map((v) => InstitutionDiscipline(
              code: v['code'] as String,
              labelEn: v['labelEn'] as String,
              labelSl: v['labelSl'] is String ? v['labelSl'] as String : ''))
          .toList(growable: false),
      stats: InstitutionStats.fromJson(json['stats']),
      isVerified: json['isVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      if (kind != null) 'kind': kind,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contactEmail': contactEmail,
      'website': website,
      'coverImageUrl': coverImageUrl,
      'logoUrl': logoUrl,
      if (coverAttribution != null)
        'coverAttribution': coverAttribution!.toJson(),
      if (logoAttribution != null) 'logoAttribution': logoAttribution!.toJson(),
      if (visitorAccess != null) 'visitorAccess': visitorAccess!.toJson(),
      'disciplines': disciplines.map((d) => d.toJson()).toList(growable: false),
      'stats': stats.toJson(),
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Institution copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    String? kind,
    String? address,
    double? latitude,
    double? longitude,
    String? contactEmail,
    String? website,
    String? coverImageUrl,
    String? logoUrl,
    InstitutionImageAttribution? coverAttribution,
    InstitutionImageAttribution? logoAttribution,
    InstitutionVisitorAccess? visitorAccess,
    List<InstitutionDiscipline>? disciplines,
    InstitutionStats? stats,
    bool? isVerified,
    DateTime? createdAt,
    bool? isSelfDerivedFromWallet,
  }) {
    return Institution(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      coverAttribution: coverAttribution ?? this.coverAttribution,
      logoAttribution: logoAttribution ?? this.logoAttribution,
      visitorAccess: visitorAccess ?? this.visitorAccess,
      disciplines: disciplines ?? this.disciplines,
      stats: stats ?? this.stats,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      isSelfDerivedFromWallet:
          isSelfDerivedFromWallet ?? this.isSelfDerivedFromWallet,
    );
  }

  static InstitutionImageAttribution? _attribution(Object? value) {
    if (value == null) return null;
    final attribution = InstitutionImageAttribution.fromJson(value);
    return attribution.isEmpty ? null : attribution;
  }
}

/// Normalization boundary for institution imagery.
///
/// Typed schema names (`coverImageUrl`/`cover_image_url`, `logoUrl`/`logo_url`)
/// are canonical. The legacy `imageUrls` array (what the backend sent before it
/// exposed the schema fields) is read only here: its first entry is the cover
/// and its second entry the logo, the order the backend has always used.
class _InstitutionImageBoundary {
  final String? coverImageUrl;
  final String? logoUrl;

  const _InstitutionImageBoundary({this.coverImageUrl, this.logoUrl});

  static _InstitutionImageBoundary read(Map<String, dynamic> json) {
    final legacy = json['imageUrls'];
    final legacyRefs = legacy is List
        ? legacy
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final cover = _firstString([
          json['coverImageUrl'],
          json['cover_image_url'],
        ]) ??
        (legacyRefs.isNotEmpty ? legacyRefs.first : null);
    final logo = _firstString([
          json['logoUrl'],
          json['logo_url'],
        ]) ??
        (legacyRefs.length > 1 ? legacyRefs[1] : null);
    return _InstitutionImageBoundary(coverImageUrl: cover, logoUrl: logo);
  }

  static String? _firstString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}

class InstitutionStats {
  final int totalVisitors;
  final int activeEvents;
  final int artworkViews;
  final double revenue;
  final double visitorGrowth;
  final double revenueGrowth;

  InstitutionStats({
    required this.totalVisitors,
    required this.activeEvents,
    required this.artworkViews,
    required this.revenue,
    required this.visitorGrowth,
    required this.revenueGrowth,
  });

  factory InstitutionStats.fromJson(Map<String, dynamic> json) {
    return InstitutionStats(
      totalVisitors: json['totalVisitors'],
      activeEvents: json['activeEvents'],
      artworkViews: json['artworkViews'],
      revenue: json['revenue'].toDouble(),
      visitorGrowth: json['visitorGrowth'].toDouble(),
      revenueGrowth: json['revenueGrowth'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalVisitors': totalVisitors,
      'activeEvents': activeEvents,
      'artworkViews': artworkViews,
      'revenue': revenue,
      'visitorGrowth': visitorGrowth,
      'revenueGrowth': revenueGrowth,
    };
  }

  InstitutionStats copyWith({
    int? totalVisitors,
    int? activeEvents,
    int? artworkViews,
    double? revenue,
    double? visitorGrowth,
    double? revenueGrowth,
  }) {
    return InstitutionStats(
      totalVisitors: totalVisitors ?? this.totalVisitors,
      activeEvents: activeEvents ?? this.activeEvents,
      artworkViews: artworkViews ?? this.artworkViews,
      revenue: revenue ?? this.revenue,
      visitorGrowth: visitorGrowth ?? this.visitorGrowth,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
    );
  }
}

enum EventType {
  exhibition,
  workshop,
  conference,
  performance,
  galleryOpening,
  auction
}

enum EventCategory {
  art,
  photography,
  sculpture,
  digital,
  mixedMedia,
  installation
}

class Event {
  final String id;
  final String title;
  final String description;
  final EventType type;
  final EventCategory category;
  final String institutionId;
  final Institution? institution;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final double? latitude;
  final double? longitude;
  final double? price;
  final int? capacity;
  final int currentAttendees;
  final bool isPublic;
  final bool allowRegistration;

  /// Gallery images only. The cover is held separately in [coverUrl].
  final List<String> imageUrls;
  final String? coverUrl;
  final List<String> featuredArtworkIds;
  final List<String> artistIds;
  final DateTime createdAt;
  final String createdBy;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.institutionId,
    this.institution,
    required this.startDate,
    required this.endDate,
    required this.location,
    this.latitude,
    this.longitude,
    this.price,
    this.capacity,
    this.currentAttendees = 0,
    this.isPublic = true,
    this.allowRegistration = true,
    this.imageUrls = const [],
    this.coverUrl,
    this.featuredArtworkIds = const [],
    this.artistIds = const [],
    required this.createdAt,
    required this.createdBy,
  });

  /// Hero imagery for an event: the first safe of the cover, then the gallery
  /// images in order. An unsafe cover falls through to the gallery.
  ///
  /// Search thumbnails, map cards and detail headers all use this order.
  String? get heroImageRef =>
      MediaUrlResolver.firstSafeRef(<String?>[coverUrl, ...imageUrls]);

  bool get isFree => price == null || price == 0;
  bool get hasCapacity => capacity == null || currentAttendees < capacity!;
  bool get isActive =>
      DateTime.now().isBefore(endDate) && DateTime.now().isAfter(startDate);
  bool get isUpcoming => DateTime.now().isBefore(startDate);

  String get formattedPrice {
    if (isFree) return 'Free';
    return '\$${price!.toStringAsFixed(2)}';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      category:
          EventCategory.values.firstWhere((e) => e.name == json['category']),
      institutionId: json['institutionId'],
      institution: json['institution'] != null
          ? Institution.fromJson(json['institution'])
          : null,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      location: json['location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      price: json['price']?.toDouble(),
      capacity: json['capacity'],
      currentAttendees: json['currentAttendees'] ?? 0,
      isPublic: json['isPublic'] ?? true,
      allowRegistration: json['allowRegistration'] ?? true,
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      coverUrl: _nullableEventString(json['coverUrl'] ?? json['cover_url']),
      featuredArtworkIds: List<String>.from(json['featuredArtworkIds'] ?? []),
      artistIds: List<String>.from(json['artistIds'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
    );
  }

  factory Event.fromBackendJson(
    Map<String, dynamic> json, {
    Institution? institution,
  }) {
    final kubusEvent = KubusEvent.fromJson(json);
    return Event.fromKubusEvent(
      kubusEvent,
      raw: json,
      institution: institution,
    );
  }

  factory Event.fromKubusEvent(
    KubusEvent event, {
    Map<String, dynamic> raw = const <String, dynamic>{},
    Institution? institution,
  }) {
    final startDate = event.startsAt ??
        _eventDate(raw['startDate'] ?? raw['start_date']) ??
        DateTime.now();
    final endDate = event.endsAt ??
        _eventDate(raw['endDate'] ?? raw['end_date']) ??
        startDate.add(const Duration(hours: 2));
    final institutionId = _eventString(
      raw['institutionId'] ??
          raw['institution_id'] ??
          (raw['institution'] is Map ? raw['institution']['id'] : null) ??
          raw['hostInstitutionId'] ??
          raw['host_institution_id'] ??
          institution?.id ??
          event.host?.walletAddress ??
          event.host?.id,
    );
    final location = _eventString(event.locationName);
    final cityCountry = [
      _eventString(event.city),
      _eventString(event.country),
    ].where((value) => value.isNotEmpty).join(', ');

    return Event(
      id: event.id,
      title: event.title,
      description: event.description ?? '',
      type: _eventType(raw['type'] ?? raw['eventType'] ?? raw['event_type']),
      category: _eventCategory(raw['category']),
      institutionId: institutionId,
      institution: institution,
      startDate: startDate,
      endDate: endDate,
      location: location.isNotEmpty ? location : cityCountry,
      latitude: event.lat,
      longitude: event.lng,
      price: _eventDouble(
          raw['price'] ?? raw['ticketPrice'] ?? raw['ticket_price']),
      capacity: _eventInt(
          raw['capacity'] ?? raw['maxAttendees'] ?? raw['max_attendees']),
      currentAttendees: _eventInt(
            raw['currentAttendees'] ??
                raw['current_attendees'] ??
                raw['attendeeCount'] ??
                raw['attendee_count'] ??
                raw['registrationsCount'] ??
                raw['registrations_count'],
          ) ??
          0,
      isPublic:
          _eventBool(raw['isPublic'] ?? raw['is_public'] ?? raw['public']) ??
              true,
      allowRegistration: _eventBool(
            raw['allowRegistration'] ??
                raw['allow_registration'] ??
                raw['registrationEnabled'] ??
                raw['registration_enabled'],
          ) ??
          true,
      imageUrls: _eventStringList(
          raw['imageUrls'] ?? raw['image_urls'] ?? raw['images']),
      coverUrl: _nullableEventString(event.coverUrl),
      featuredArtworkIds: _eventStringList(
        raw['featuredArtworkIds'] ?? raw['featured_artwork_ids'],
      ),
      artistIds: _eventStringList(raw['artistIds'] ?? raw['artist_ids']),
      createdAt: event.createdAt ??
          _eventDate(raw['createdAt'] ?? raw['created_at']) ??
          DateTime.now(),
      createdBy: _eventString(
        raw['createdBy'] ??
            raw['created_by'] ??
            raw['hostUserId'] ??
            raw['host_user_id'] ??
            event.host?.id,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'category': category.name,
      'institutionId': institutionId,
      'institution': institution?.toJson(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
      'capacity': capacity,
      'currentAttendees': currentAttendees,
      'isPublic': isPublic,
      'allowRegistration': allowRegistration,
      'imageUrls': imageUrls,
      'coverUrl': coverUrl,
      'featuredArtworkIds': featuredArtworkIds,
      'artistIds': artistIds,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    EventType? type,
    EventCategory? category,
    String? institutionId,
    Institution? institution,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    double? latitude,
    double? longitude,
    double? price,
    int? capacity,
    int? currentAttendees,
    bool? isPublic,
    bool? allowRegistration,
    List<String>? imageUrls,
    String? coverUrl,
    List<String>? featuredArtworkIds,
    List<String>? artistIds,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      category: category ?? this.category,
      institutionId: institutionId ?? this.institutionId,
      institution: institution ?? this.institution,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      currentAttendees: currentAttendees ?? this.currentAttendees,
      isPublic: isPublic ?? this.isPublic,
      allowRegistration: allowRegistration ?? this.allowRegistration,
      imageUrls: imageUrls ?? this.imageUrls,
      coverUrl: coverUrl ?? this.coverUrl,
      featuredArtworkIds: featuredArtworkIds ?? this.featuredArtworkIds,
      artistIds: artistIds ?? this.artistIds,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

String? _nullableTrimmedString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _eventString(dynamic value) => (value ?? '').toString().trim();

String? _nullableEventString(dynamic value) {
  final trimmed = _eventString(value);
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _eventDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

double? _eventDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _eventInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _eventBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

String _normalizedEnumToken(dynamic value) =>
    _eventString(value).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

EventType _eventType(dynamic value) {
  switch (_normalizedEnumToken(value)) {
    case 'workshop':
      return EventType.workshop;
    case 'conference':
    case 'talk':
    case 'artisttalk':
      return EventType.conference;
    case 'performance':
      return EventType.performance;
    case 'galleryopening':
    case 'opening':
      return EventType.galleryOpening;
    case 'auction':
      return EventType.auction;
    case 'exhibition':
    default:
      return EventType.exhibition;
  }
}

EventCategory _eventCategory(dynamic value) {
  switch (_normalizedEnumToken(value)) {
    case 'photography':
      return EventCategory.photography;
    case 'sculpture':
      return EventCategory.sculpture;
    case 'digital':
      return EventCategory.digital;
    case 'mixedmedia':
      return EventCategory.mixedMedia;
    case 'installation':
      return EventCategory.installation;
    case 'art':
    default:
      return EventCategory.art;
  }
}

List<String> _eventStringList(dynamic value) {
  if (value is List) {
    return value
        .map(_eventString)
        .where((item) => item.isNotEmpty)
        .toList(growable: true);
  }
  final single = _eventString(value);
  if (single.isEmpty) return <String>[];
  return <String>[single];
}
