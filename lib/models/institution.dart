// Institution and Events Models
class Institution {
  final String id;
  final String name;
  final String description;
  final String type; // 'gallery', 'museum', 'cultural_center'
  final String address;
  final double latitude;
  final double longitude;
  final String contactEmail;
  final String website;
  final List<String> imageUrls;
  final InstitutionStats stats;
  final bool isVerified;
  final DateTime createdAt;

  Institution({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.contactEmail,
    required this.website,
    this.imageUrls = const [],
    required this.stats,
    this.isVerified = false,
    required this.createdAt,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      contactEmail: json['contactEmail'],
      website: json['website'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
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
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contactEmail': contactEmail,
      'website': website,
      'imageUrls': imageUrls,
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
    String? address,
    double? latitude,
    double? longitude,
    String? contactEmail,
    String? website,
    List<String>? imageUrls,
    InstitutionStats? stats,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return Institution(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      imageUrls: imageUrls ?? this.imageUrls,
      stats: stats ?? this.stats,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
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

enum EventType { exhibition, workshop, conference, performance, galleryOpening, auction }
enum EventCategory { art, photography, sculpture, digital, mixedMedia, installation }

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
  final List<String> imageUrls;
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
    this.featuredArtworkIds = const [],
    this.artistIds = const [],
    required this.createdAt,
    required this.createdBy,
  });

  bool get isFree => price == null || price == 0;
  bool get hasCapacity => capacity == null || currentAttendees < capacity!;
  bool get isActive => DateTime.now().isBefore(endDate) && DateTime.now().isAfter(startDate);
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
      category: EventCategory.values.firstWhere((e) => e.name == json['category']),
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
      featuredArtworkIds: List<String>.from(json['featuredArtworkIds'] ?? []),
      artistIds: List<String>.from(json['artistIds'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
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
      featuredArtworkIds: featuredArtworkIds ?? this.featuredArtworkIds,
      artistIds: artistIds ?? this.artistIds,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
