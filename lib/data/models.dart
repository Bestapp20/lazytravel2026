class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.city,
    this.bio,
    this.travelStyle,
    this.interests = const [],
    this.kosher = false,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? city;
  final String? bio;
  final String? travelStyle;
  final List<String> interests;
  final bool kosher;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        city: m['city'] as String?,
        bio: m['bio'] as String?,
        travelStyle: m['travel_style'] as String?,
        interests: (m['interests'] as List?)?.cast<String>() ?? const [],
        kosher: m['kosher'] == true,
      );
}

class Destination {
  const Destination({
    required this.city,
    this.country,
    this.placeId,
    this.lat,
    this.lng,
    this.flag,
  });

  final String city;
  final String? country;
  final String? placeId;
  final double? lat;
  final double? lng;
  final String? flag;

  Map<String, dynamic> toMap() => {
        'city': city,
        'country': country,
        'place_id': placeId,
        'lat': lat,
        'lng': lng,
        'flag': flag,
      };

  factory Destination.fromMap(Map<String, dynamic> m) => Destination(
        city: (m['city'] ?? '') as String,
        country: m['country'] as String?,
        placeId: m['place_id'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        flag: m['flag'] as String?,
      );
}

class HotelInfo {
  const HotelInfo({
    required this.name,
    this.placeId,
    this.lat,
    this.lng,
    this.address,
  });

  final String name;
  final String? placeId;
  final double? lat;
  final double? lng;
  final String? address;

  Map<String, dynamic> toMap() => {
        'name': name,
        'place_id': placeId,
        'lat': lat,
        'lng': lng,
        'address': address,
      };

  factory HotelInfo.fromMap(Map<String, dynamic> m) => HotelInfo(
        name: (m['name'] ?? '') as String,
        placeId: m['place_id'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        address: m['address'] as String?,
      );
}

class Trip {
  const Trip({
    required this.id,
    required this.ownerId,
    required this.title,
    this.coverImageUrl,
    this.destinations = const [],
    this.startDate,
    this.endDate,
    this.travelers = 1,
    this.kids = 0,
    this.companionType,
    this.pace,
    this.budgetTier,
    this.budgetTotal,
    this.currency = 'ILS',
    this.kosher = false,
    this.hotel,
    this.status = 'planned',
    this.myRole = 'owner',
  });

  final String id;
  final String ownerId;
  final String title;
  final String? coverImageUrl;
  final List<Destination> destinations;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travelers;
  final int kids;
  final String? companionType;
  final String? pace;
  final String? budgetTier;
  final num? budgetTotal;
  final String currency;
  final bool kosher;
  final HotelInfo? hotel;
  final String status;
  final String myRole;

  bool get isOwner => myRole == 'owner';

  String get city => destinations.isNotEmpty ? destinations.first.city : title;

  factory Trip.fromMap(Map<String, dynamic> m, {String role = 'owner'}) {
    final dests = (m['destinations'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Destination.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return Trip(
      id: m['id'] as String,
      ownerId: m['owner_id'] as String,
      title: m['title'] as String? ?? '',
      coverImageUrl: m['cover_image_url'] as String?,
      destinations: dests,
      startDate: DateTime.tryParse(m['start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(m['end_date']?.toString() ?? ''),
      travelers: (m['travelers'] as num?)?.toInt() ?? 1,
      kids: (m['kids'] as num?)?.toInt() ?? 0,
      companionType: m['companion_type'] as String?,
      pace: m['pace'] as String?,
      budgetTier: m['budget_tier'] as String?,
      budgetTotal: m['budget_total'] as num?,
      currency: m['currency'] as String? ?? 'ILS',
      kosher: m['kosher'] == true,
      hotel: m['hotel'] is Map
          ? HotelInfo.fromMap(Map<String, dynamic>.from(m['hotel'] as Map))
          : null,
      status: m['status'] as String? ?? 'planned',
      myRole: role,
    );
  }
}

class TripDay {
  const TripDay({
    required this.id,
    required this.tripId,
    required this.dayIndex,
    this.date,
    this.title,
    this.weather,
    this.items = const [],
  });

  final String id;
  final String tripId;
  final int dayIndex;
  final DateTime? date;
  final String? title;
  final Map<String, dynamic>? weather;
  final List<TripItem> items;

  factory TripDay.fromMap(Map<String, dynamic> m) => TripDay(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        dayIndex: (m['day_index'] as num).toInt(),
        date: DateTime.tryParse(m['date']?.toString() ?? ''),
        title: m['title'] as String?,
        weather: m['weather'] is Map
            ? Map<String, dynamic>.from(m['weather'] as Map)
            : null,
      );

  TripDay copyWith({List<TripItem>? items}) => TripDay(
        id: id,
        tripId: tripId,
        dayIndex: dayIndex,
        date: date,
        title: title,
        weather: weather,
        items: items ?? this.items,
      );
}

class TripItem {
  const TripItem({
    required this.id,
    required this.tripId,
    required this.dayId,
    required this.placeName,
    this.googlePlaceId,
    this.category,
    this.address,
    this.lat,
    this.lng,
    this.mapLink,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.sortOrder = 0,
    this.notes,
    this.aiTip,
    this.rating,
    this.priceLevel,
    this.photoUrl,
    this.photoReference,
    this.estimatedCost,
    this.transportToNext,
  });

  final String id;
  final String tripId;
  final String dayId;
  final String placeName;
  final String? googlePlaceId;
  final String? category;
  final String? address;
  final double? lat;
  final double? lng;
  final String? mapLink;
  final String? startTime;
  final String? endTime;
  final int? durationMinutes;
  final int sortOrder;
  final String? notes;
  final String? aiTip;
  final num? rating;
  final int? priceLevel;
  final String? photoUrl;
  final String? photoReference;
  final num? estimatedCost;
  final Map<String, dynamic>? transportToNext;

  factory TripItem.fromMap(Map<String, dynamic> m) => TripItem(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        dayId: m['day_id'] as String,
        placeName: m['place_name'] as String? ?? '',
        googlePlaceId: m['google_place_id'] as String?,
        category: m['category'] as String?,
        address: m['address'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        mapLink: m['map_link'] as String?,
        startTime: m['start_time']?.toString(),
        endTime: m['end_time']?.toString(),
        durationMinutes: (m['duration_minutes'] as num?)?.toInt(),
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        notes: m['notes'] as String?,
        aiTip: m['ai_tip'] as String?,
        rating: m['rating'] as num?,
        priceLevel: (m['price_level'] as num?)?.toInt(),
        photoUrl: m['photo_url'] as String?,
        photoReference: m['photo_reference'] as String?,
        estimatedCost: m['estimated_cost'] as num?,
        transportToNext: m['transport_to_next'] is Map
            ? Map<String, dynamic>.from(m['transport_to_next'] as Map)
            : null,
      );
}

class TripDocument {
  const TripDocument({
    required this.id,
    required this.tripId,
    required this.ownerId,
    required this.docType,
    required this.title,
    required this.storagePath,
    this.dayId,
    this.itemId,
    this.mimeType,
    this.fileSize,
    this.createdAt,
  });

  final String id;
  final String tripId;
  final String ownerId;
  final String docType;
  final String title;
  final String storagePath;
  final String? dayId;
  final String? itemId;
  final String? mimeType;
  final int? fileSize;
  final DateTime? createdAt;

  bool get isImage => (mimeType ?? '').startsWith('image/');
  bool get isPdf => (mimeType ?? '') == 'application/pdf' ||
      storagePath.toLowerCase().endsWith('.pdf');

  factory TripDocument.fromMap(Map<String, dynamic> m) => TripDocument(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        ownerId: m['owner_id'] as String,
        docType: m['doc_type'] as String? ?? 'other',
        title: m['title'] as String? ?? '',
        storagePath: m['storage_path'] as String? ?? '',
        dayId: m['day_id'] as String?,
        itemId: m['item_id'] as String?,
        mimeType: m['mime_type'] as String?,
        fileSize: (m['file_size'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amount,
    this.title,
    this.currency = 'ILS',
    this.spentAt,
  });

  final String id;
  final String tripId;
  final String category;
  final num amount;
  final String? title;
  final String currency;
  final DateTime? spentAt;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        category: m['category'] as String? ?? 'other',
        amount: m['amount'] as num? ?? 0,
        title: m['title'] as String?,
        currency: m['currency'] as String? ?? 'ILS',
        spentAt: DateTime.tryParse(m['spent_at']?.toString() ?? ''),
      );
}

class TripMember {
  const TripMember({
    required this.tripId,
    required this.userId,
    required this.role,
    this.invitedEmail,
    this.displayName,
  });

  final String tripId;
  final String userId;
  final String role;
  final String? invitedEmail;
  final String? displayName;

  factory TripMember.fromMap(Map<String, dynamic> m) => TripMember(
        tripId: m['trip_id'] as String,
        userId: m['user_id'] as String,
        role: m['role'] as String? ?? 'viewer',
        invitedEmail: m['invited_email'] as String?,
        displayName: (m['profiles'] is Map)
            ? (m['profiles'] as Map)['display_name'] as String?
            : null,
      );
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    this.subtitle,
    this.lat,
    this.lng,
    this.address,
    this.rating,
    this.photoReference,
    this.photoUrl,
    this.types,
  });

  final String placeId;
  final String name;
  final String? subtitle;
  final double? lat;
  final double? lng;
  final String? address;
  final num? rating;
  final String? photoReference;
  final String? photoUrl;
  final List<String>? types;
}

class PlaceReview {
  const PlaceReview({required this.text, this.author, this.rating, this.when});
  final String text;
  final String? author;
  final num? rating;
  final String? when;
}

/// Rich place info for the add-place sheet (photos resolved server-side).
class PlaceFull {
  const PlaceFull({
    required this.placeId,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.rating,
    this.ratingCount,
    this.priceLevel,
    this.types,
    this.mapLink,
    this.photos = const [],
    this.photoReference,
    this.hours,
    this.openNow,
    this.summary,
    this.website,
    this.phone,
    this.reviews = const [],
  });

  final String placeId;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final num? rating;
  final int? ratingCount;
  final int? priceLevel;
  final List<String>? types;
  final String? mapLink;
  final List<String> photos;
  final String? photoReference;
  final List<String>? hours;
  final bool? openNow;
  final String? summary;
  final String? website;
  final String? phone;
  final List<PlaceReview> reviews;

  factory PlaceFull.fromMap(Map<String, dynamic> m) => PlaceFull(
        placeId: m['place_id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        address: m['address'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        rating: m['rating'] as num?,
        ratingCount: (m['user_rating_count'] as num?)?.toInt(),
        priceLevel: (m['price_level'] as num?)?.toInt(),
        types: (m['types'] as List?)?.map((e) => '$e').toList(),
        mapLink: m['map_link'] as String?,
        photos: (m['photos'] as List?)?.map((e) => '$e').toList() ?? const [],
        photoReference: m['photo_reference'] as String?,
        hours: (m['hours'] as List?)?.map((e) => '$e').toList(),
        openNow: m['open_now'] as bool?,
        summary: m['summary'] as String?,
        website: m['website'] as String?,
        phone: m['phone'] as String?,
        reviews: ((m['reviews'] as List?) ?? const [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .map((r) => PlaceReview(
                  text: r['text'] as String? ?? '',
                  author: r['author'] as String?,
                  rating: r['rating'] as num?,
                  when: r['when'] as String?,
                ))
            .toList(),
      );
}

class WizardState {
  const WizardState({
    this.destinations = const [],
    this.startDate,
    this.endDate,
    this.adults = 2,
    this.kids = 0,
    this.kidAges = const [],
    this.companion = 'couple',
    this.pace = 'balanced',
    this.budgetTier = 'mid',
    this.budgetTotal = 10000,
    this.kosher = false,
    this.interests = const {},
    this.hotel,
    this.originCity,
    this.flightRef,
  });

  final List<Destination> destinations;
  final DateTime? startDate;
  final DateTime? endDate;
  final int adults;
  final int kids;
  final List<int> kidAges;
  final String companion;
  final String pace;
  final String budgetTier;
  final double budgetTotal;
  final bool kosher;
  final Map<String, int> interests;
  final HotelInfo? hotel;
  final String? originCity;
  final String? flightRef;

  Destination? get primary =>
      destinations.isEmpty ? null : destinations.first;

  WizardState copyWith({
    List<Destination>? destinations,
    DateTime? startDate,
    DateTime? endDate,
    int? adults,
    int? kids,
    List<int>? kidAges,
    String? companion,
    String? pace,
    String? budgetTier,
    double? budgetTotal,
    bool? kosher,
    Map<String, int>? interests,
    HotelInfo? hotel,
    bool clearHotel = false,
    String? originCity,
    String? flightRef,
  }) {
    return WizardState(
      destinations: destinations ?? this.destinations,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      adults: adults ?? this.adults,
      kids: kids ?? this.kids,
      kidAges: kidAges ?? this.kidAges,
      companion: companion ?? this.companion,
      pace: pace ?? this.pace,
      budgetTier: budgetTier ?? this.budgetTier,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      kosher: kosher ?? this.kosher,
      interests: interests ?? this.interests,
      hotel: clearHotel ? null : (hotel ?? this.hotel),
      originCity: originCity ?? this.originCity,
      flightRef: flightRef ?? this.flightRef,
    );
  }

  Map<String, dynamic> toGeneratePayload() => {
        'destination': primary?.toMap(),
        'extra_cities': destinations.skip(1).map((e) => e.toMap()).toList(),
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'adults': adults,
        'kids': kids,
        'kid_ages': kidAges,
        'companion_type': companion,
        'pace': pace,
        'budget_tier': budgetTier,
        'budget_total': budgetTotal,
        'currency': 'ILS',
        'kosher': kosher,
        'interests': interests,
        'hotel': hotel?.toMap(),
        'origin_city': originCity,
        'flight_ref': flightRef,
      };
}
