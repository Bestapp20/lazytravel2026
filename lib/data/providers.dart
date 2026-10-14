import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/booking/booking_engine.dart';
import '../core/config/app_config.dart';
import 'models.dart';
import 'repositories.dart';

final supabaseProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.isConfigured) return null;
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final c = ref.watch(supabaseProvider);
  if (c == null) return null;
  return AuthRepository(c);
});

final tripsRepositoryProvider = Provider<TripsRepository?>((ref) {
  final c = ref.watch(supabaseProvider);
  if (c == null) return null;
  return TripsRepository(c);
});

final expensesRepositoryProvider = Provider<ExpensesRepository?>((ref) {
  final c = ref.watch(supabaseProvider);
  if (c == null) return null;
  return ExpensesRepository(c);
});

final documentsRepositoryProvider = Provider<DocumentsRepository?>((ref) {
  final c = ref.watch(supabaseProvider);
  if (c == null) return null;
  return DocumentsRepository(c);
});

final placesRepositoryProvider = Provider<PlacesRepository?>((ref) {
  final c = ref.watch(supabaseProvider);
  if (c == null) return null;
  return PlacesRepository(c);
});

final bookingEngineProvider = Provider<BookingEngine>((ref) {
  return const UnimplementedBookingEngine();
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.authChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider)?.user;
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider)?.myProfile();
});

final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(tripsRepositoryProvider);
  if (repo == null) return [];
  return repo.listMine();
});

final tripProvider = FutureProvider.family<Trip, String>((ref, id) async {
  final repo = ref.watch(tripsRepositoryProvider);
  if (repo == null) throw Exception('Supabase not configured');
  return repo.getTrip(id);
});

final tripDaysProvider = FutureProvider.family<List<TripDay>, String>((ref, id) async {
  final repo = ref.watch(tripsRepositoryProvider);
  if (repo == null) return [];
  return repo.daysFor(id);
});

final expensesProvider = FutureProvider.family<List<Expense>, String>((ref, id) async {
  final repo = ref.watch(expensesRepositoryProvider);
  if (repo == null) return [];
  return repo.forTrip(id);
});

final documentsProvider = FutureProvider.family<List<TripDocument>, String>((ref, id) async {
  final repo = ref.watch(documentsRepositoryProvider);
  if (repo == null) return [];
  return repo.forTrip(id);
});

final membersProvider = FutureProvider.family<List<TripMember>, String>((ref, id) async {
  final repo = ref.watch(tripsRepositoryProvider);
  if (repo == null) return [];
  return repo.members(id);
});

class WizardController extends Notifier<WizardState> {
  @override
  WizardState build() => const WizardState();

  void setDestinations(List<Destination> v) => state = state.copyWith(destinations: v);
  void addDestination(Destination d) =>
      state = state.copyWith(destinations: [...state.destinations, d]);
  void removeDestination(int i) {
    final next = [...state.destinations]..removeAt(i);
    state = state.copyWith(destinations: next);
  }

  void setDates(DateTime? start, DateTime? end) =>
      state = state.copyWith(startDate: start, endDate: end);
  void setCompanion(String v) => state = state.copyWith(companion: v);
  void setPace(String v) => state = state.copyWith(pace: v);
  void setBudgetTier(String v) => state = state.copyWith(budgetTier: v);
  void setBudgetTotal(double v) => state = state.copyWith(budgetTotal: v);
  void setAdults(int v) => state = state.copyWith(adults: v);
  void setKids(int v) => state = state.copyWith(kids: v);
  void setKosher(bool v) => state = state.copyWith(kosher: v);
  void setInterest(String id, int weight) {
    final next = Map<String, int>.from(state.interests);
    if (weight <= 0) {
      next.remove(id);
    } else {
      next[id] = weight;
    }
    state = state.copyWith(interests: next);
  }

  void setHotel(HotelInfo? h) =>
      state = h == null ? state.copyWith(clearHotel: true) : state.copyWith(hotel: h);
  void setFlightRef(String v) => state = state.copyWith(flightRef: v);
  void reset() => state = const WizardState();
}

final wizardProvider = NotifierProvider<WizardController, WizardState>(WizardController.new);
