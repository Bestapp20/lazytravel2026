import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String name) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
  }

  Future<void> sendMagicLink(String email) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'io.lazytravel.app://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> myProfile() async {
    final id = user?.id;
    if (id == null) return null;
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<void> acceptInvites() async {
    try {
      await _client.rpc('accept_my_invites');
    } catch (e) {
      debugPrint('accept_my_invites: $e');
    }
  }

  Future<void> updateProfile({String? displayName, String? city, String? bio}) async {
    final id = user?.id;
    if (id == null) return;
    await _client.from('profiles').update({
      'display_name': ?displayName,
      'city': ?city,
      'bio': ?bio,
    }).eq('id', id);
  }
}

class TripsRepository {
  TripsRepository(this._client);
  final SupabaseClient _client;

  Future<List<Trip>> listMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final members = await _client
        .from('trip_members')
        .select('trip_id, role, trips(*)')
        .eq('user_id', uid);
    final out = <Trip>[];
    for (final row in members as List) {
      final t = row['trips'];
      if (t is Map) {
        out.add(Trip.fromMap(Map<String, dynamic>.from(t), role: row['role'] as String? ?? 'viewer'));
      }
    }
    out.sort((a, b) {
      final da = a.startDate ?? DateTime(1970);
      final db = b.startDate ?? DateTime(1970);
      return db.compareTo(da);
    });
    return out;
  }

  Future<Trip> getTrip(String id) async {
    final uid = _client.auth.currentUser?.id;
    final trip = await _client.from('trips').select().eq('id', id).single();
    String role = 'viewer';
    if (uid != null) {
      final m = await _client
          .from('trip_members')
          .select('role')
          .eq('trip_id', id)
          .eq('user_id', uid)
          .maybeSingle();
      role = m?['role'] as String? ?? 'viewer';
    }
    return Trip.fromMap(trip, role: role);
  }

  Future<List<TripDay>> daysFor(String tripId) async {
    final rows = await _client
        .from('days')
        .select()
        .eq('trip_id', tripId)
        .order('day_index');
    final items = await _client
        .from('items')
        .select()
        .eq('trip_id', tripId)
        .order('sort_order');
    final byDay = <String, List<TripItem>>{};
    for (final r in items as List) {
      final it = TripItem.fromMap(Map<String, dynamic>.from(r as Map));
      byDay.putIfAbsent(it.dayId, () => []).add(it);
    }
    return (rows as List)
        .map((r) {
          final d = TripDay.fromMap(Map<String, dynamic>.from(r as Map));
          return d.copyWith(items: byDay[d.id] ?? const []);
        })
        .toList();
  }

  Future<TripDay> createDay(String tripId, int dayIndex, DateTime? date) async {
    final row = await _client
        .from('days')
        .insert({
          'trip_id': tripId,
          'day_index': dayIndex,
          'date': date?.toIso8601String().substring(0, 10),
          'title': 'יום $dayIndex',
        })
        .select()
        .single();
    return TripDay.fromMap(row);
  }

  Future<TripItem> upsertItem(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      final row = await _client.from('items').insert(data).select().single();
      return TripItem.fromMap(row);
    }
    final row = await _client.from('items').update(data).eq('id', id).select().single();
    return TripItem.fromMap(row);
  }

  Future<void> deleteItem(String id) => _client.from('items').delete().eq('id', id);

  Future<void> updateTrip(String id, Map<String, dynamic> data) {
    return _client.from('trips').update(data).eq('id', id);
  }

  Future<String> generateRoute(Map<String, dynamic> payload) async {
    final res = await _client.functions.invoke('generate-route', body: payload);
    final data = res.data;
    if (data is Map && data['trip_id'] != null) return data['trip_id'] as String;
    throw Exception(data is Map ? data['error'] ?? 'generate-route failed' : 'generate-route failed');
  }

  Future<List<TripMember>> members(String tripId) async {
    final rows = await _client
        .from('trip_members')
        .select('*, profiles(display_name, avatar_url)')
        .eq('trip_id', tripId);
    return (rows as List)
        .map((r) => TripMember.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> invite(String tripId, String email) async {
    final res = await _client.functions.invoke(
      'invite-member',
      body: {'trip_id': tripId, 'email': email},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}

class ExpensesRepository {
  ExpensesRepository(this._client);
  final SupabaseClient _client;

  Future<List<Expense>> forTrip(String tripId) async {
    final rows = await _client.from('expenses').select().eq('trip_id', tripId).order('created_at');
    return (rows as List)
        .map((r) => Expense.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> add({
    required String tripId,
    required String category,
    required num amount,
    String? title,
    String? dayId,
  }) {
    return _client.from('expenses').insert({
      'trip_id': tripId,
      'category': category,
      'amount': amount,
      'title': title,
      'day_id': dayId,
      'spent_at': DateTime.now().toIso8601String().substring(0, 10),
      'created_by': _client.auth.currentUser?.id,
    });
  }
}

class DocumentsRepository {
  DocumentsRepository(this._client);
  final SupabaseClient _client;

  Future<List<TripDocument>> forTrip(String tripId) async {
    final rows =
        await _client.from('documents').select().eq('trip_id', tripId).order('created_at');
    return (rows as List)
        .map((r) => TripDocument.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<TripDocument> upload({
    required String tripId,
    required File file,
    required String title,
    required String docType,
    String? dayId,
    String? itemId,
  }) async {
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = p.extension(file.path);
    final path = '$tripId/${const Uuid().v4()}$ext';
    await _client.storage.from('trip-docs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    final row = await _client
        .from('documents')
        .insert({
          'trip_id': tripId,
          'day_id': dayId,
          'item_id': itemId,
          'owner_id': _client.auth.currentUser!.id,
          'doc_type': docType,
          'title': title,
          'storage_path': path,
          'mime_type': mime,
          'file_size': bytes.length,
        })
        .select()
        .single();
    return TripDocument.fromMap(row);
  }

  Future<Uint8List> download(String storagePath) {
    return _client.storage.from('trip-docs').download(storagePath);
  }

  Future<String> signedUrl(String storagePath) async {
    final url = await _client.storage.from('trip-docs').createSignedUrl(storagePath, 3600);
    return url;
  }

  Future<void> delete(TripDocument doc) async {
    await _client.storage.from('trip-docs').remove([doc.storagePath]);
    await _client.from('documents').delete().eq('id', doc.id);
  }
}

class PlacesRepository {
  PlacesRepository(this._client);
  final SupabaseClient _client;

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    final res = await _client.functions.invoke(
      'places-autocomplete',
      body: {'input': input, 'types': '(cities)'},
    );
    final data = res.data;
    final preds = (data is Map ? data['predictions'] : null) as List? ?? [];
    return preds.map((p) {
      final m = Map<String, dynamic>.from(p as Map);
      final terms = (m['structured_formatting'] as Map?) ?? {};
      return PlaceSuggestion(
        placeId: m['place_id'] as String? ?? '',
        name: terms['main_text'] as String? ?? m['description'] as String? ?? '',
        subtitle: terms['secondary_text'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<PlaceSuggestion>> search(String query, {double? lat, double? lng}) async {
    final res = await _client.functions.invoke('places-search', body: {
      'query': query,
      'lat': ?lat,
      'lng': ?lng,
    });
    final data = res.data;
    final results = (data is Map ? data['results'] : null) as List? ?? [];
    return results.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return PlaceSuggestion(
        placeId: m['place_id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        subtitle: m['address'] as String?,
        address: m['address'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        rating: m['rating'] as num?,
        photoReference: m['photo_reference'] as String?,
      );
    }).toList();
  }

  Future<PlaceSuggestion?> details(String placeId) async {
    final res = await _client.functions.invoke(
      'places-search',
      body: {'place_id': placeId},
    );
    final data = res.data;
    final m = data is Map ? data['result'] : null;
    if (m is! Map) return null;
    final map = Map<String, dynamic>.from(m);
    return PlaceSuggestion(
      placeId: map['place_id'] as String? ?? placeId,
      name: map['name'] as String? ?? '',
      address: map['address'] as String?,
      subtitle: map['address'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      rating: map['rating'] as num?,
      photoReference: map['photo_reference'] as String?,
    );
  }
}
