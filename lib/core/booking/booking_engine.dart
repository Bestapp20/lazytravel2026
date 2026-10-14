/// v2 extension point. Booking / suppliers are intentionally unimplemented in v1.
library;

class PackageOffer {
  const PackageOffer({
    required this.id,
    required this.totalIls,
    this.flights = const [],
    this.hotels = const [],
  });

  final String id;
  final num totalIls;
  final List<Map<String, dynamic>> flights;
  final List<Map<String, dynamic>> hotels;
}

class BookingSearchParams {
  const BookingSearchParams({
    required this.origin,
    required this.destinations,
    this.start,
    this.end,
    this.adults = 1,
    this.kids = 0,
    this.budgetIls,
  });

  final String origin;
  final List<String> destinations;
  final DateTime? start;
  final DateTime? end;
  final int adults;
  final int kids;
  final num? budgetIls;
}

abstract class BookingEngine {
  Future<List<PackageOffer>> searchPackages(BookingSearchParams params);
  Future<String> checkout(PackageOffer offer);
}

/// Placeholder used until Duffel / LiteAPI / Stripe land in v2.
class UnimplementedBookingEngine implements BookingEngine {
  const UnimplementedBookingEngine();

  @override
  Future<List<PackageOffer>> searchPackages(BookingSearchParams params) {
    throw UnimplementedError('Booking is planned for v2.');
  }

  @override
  Future<String> checkout(PackageOffer offer) {
    throw UnimplementedError('Booking is planned for v2.');
  }
}
