import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'place_preview_screen.dart';

class PlaceCategory {
  const PlaceCategory(this.id, this.label, this.icon, this.query, this.itemCategory);
  final String id;
  final String label;
  final IconData icon;
  final String query;
  final String itemCategory;
}

const kPlaceCategories = [
  PlaceCategory('food', 'מסעדות', Icons.restaurant, 'best restaurants', 'food'),
  PlaceCategory('cafe', 'בתי קפה', Icons.local_cafe, 'best cafes', 'food'),
  PlaceCategory('attraction', 'אטרקציות', Icons.attractions, 'top tourist attractions', 'attraction'),
  PlaceCategory('beach', 'חופים', Icons.beach_access, 'best beaches', 'nature'),
  PlaceCategory('park', 'פארקים וטבע', Icons.park, 'parks nature viewpoints', 'nature'),
  PlaceCategory('museum', 'מוזיאונים', Icons.museum, 'museums', 'museum'),
  PlaceCategory('market', 'שווקים', Icons.storefront, 'night markets and local markets', 'shopping'),
  PlaceCategory('temple', 'מקדשים', Icons.temple_buddhist, 'temples', 'attraction'),
  PlaceCategory('nightlife', 'חיי לילה', Icons.nightlife, 'bars and nightlife', 'nightlife'),
  PlaceCategory('kids', 'לילדים ולנוער', Icons.family_restroom, 'family attractions for kids and teens', 'attraction'),
];

/// Anchor for recommendations: where the traveller is on that day.
class DayAnchor {
  const DayAnchor({required this.city, this.lat, this.lng, this.nearName});
  final String city;
  final double? lat;
  final double? lng;
  final String? nearName;
}

DayAnchor anchorFor(Trip trip, List<TripDay> days, String? dayId) {
  final idx = days.indexWhere((d) => d.id == dayId);
  final ordered = idx < 0 ? days : [...days.sublist(0, idx + 1).reversed];
  TripItem? hit;
  for (final d in ordered) {
    for (final it in d.items.reversed) {
      if (it.lat != null && it.lng != null && it.category != 'flight') {
        hit = it;
        break;
      }
    }
    if (hit != null) break;
  }
  final dests = trip.destinations;
  if (hit == null) {
    final d = dests.isNotEmpty ? dests.first : null;
    return DayAnchor(city: d?.city ?? trip.city, lat: d?.lat, lng: d?.lng);
  }
  var city = trip.city;
  var best = double.infinity;
  for (final d in dests) {
    if (d.lat == null || d.lng == null) continue;
    final dist = math.pow(d.lat! - hit.lat!, 2) + math.pow(d.lng! - hit.lng!, 2);
    if (dist < best) {
      best = dist.toDouble();
      city = d.city;
    }
  }
  return DayAnchor(city: city, lat: hit.lat, lng: hit.lng, nearName: hit.placeName.replaceFirst(RegExp(r"^צ'ק-אין:\s*"), ''));
}

class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key, required this.tripId, this.dayId});
  final String tripId;
  final String? dayId;

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  PlaceCategory _cat = kPlaceCategories.first;
  final Map<String, Future<List<PlaceSuggestion>>> _cache = {};

  Future<List<PlaceSuggestion>> _load(DayAnchor a) {
    final key = '${_cat.id}|${a.city}|${a.lat}';
    return _cache.putIfAbsent(key, () async {
      final repo = ref.read(placesRepositoryProvider);
      if (repo == null) return <PlaceSuggestion>[];
      return repo.topPlaces('${_cat.query} in ${a.city}', lat: a.lat, lng: a.lng, limit: 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).valueOrNull;
    final days = ref.watch(tripDaysProvider(widget.tripId)).valueOrNull;
    if (trip == null || days == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = days.where((d) => d.id == widget.dayId).cast<TripDay?>().firstOrNull ?? (days.isEmpty ? null : days.first);
    final anchor = anchorFor(trip, days, day?.id);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
        title: Column(children: [
          Text('מקום חדש', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
          if (day != null)
            Text('יום ${day.dayIndex}${day.title != null ? ' · ${day.title}' : ''}',
                style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppColors.ctaSimple, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('המלצות ב${anchor.city}',
                      style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  if (anchor.nearName != null)
                    Text('קרוב ל: ${anchor.nearName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kPlaceCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = kPlaceCategories[i];
                final on = c.id == _cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _cat = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 84,
                    decoration: BoxDecoration(
                      gradient: on ? AppColors.ctaSimple : null,
                      color: on ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: on ? Colors.transparent : AppColors.border),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(c.icon, color: on ? Colors.white : AppColors.accent, size: 26),
                      const SizedBox(height: 6),
                      Text(c.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansHebrew(
                              fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.primaryDark)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('5 המובילים · ${_cat.label}',
              style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
          const SizedBox(height: 10),
          FutureBuilder<List<PlaceSuggestion>>(
            future: _load(anchor),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
              }
              final list = snap.data ?? const [];
              if (snap.hasError || list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('לא נמצאו מקומות. נסו קטגוריה אחרת או הוסיפו ידנית.',
                      style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                );
              }
              return Column(children: [for (var i = 0; i < list.length; i++) _placeCard(trip, day, list[i], i + 1)]);
            },
          ),
          const SizedBox(height: 18),
          LtSecondaryButton(
            label: 'הוספה ידנית',
            icon: Icons.edit_note,
            onPressed: () => context.push('/trips/${trip.id}/item/edit?day=${day?.id ?? ''}'),
          ),
        ],
      ),
    );
  }

  Widget _placeCard(Trip trip, TripDay? day, PlaceSuggestion p, int rank) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LtCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlacePreviewScreen(tripId: trip.id, dayId: day?.id, place: p, itemCategory: _cat.itemCategory),
        )),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(16)).resolve(Directionality.of(context)),
            child: LtNetworkOrAsset(asset: AppAssets.forDestination(trip.city), url: p.photoUrl, width: 104, height: 104),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.sectionTint),
                  child: Text('$rank', style: GoogleFonts.notoSansHebrew(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accent)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ]),
              const SizedBox(height: 4),
              if (p.rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                  Text(' ${p.rating}', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              if (p.address != null)
                Text(p.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansHebrew(fontSize: 11.5, color: AppColors.textBody)),
            ]),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_left, color: AppColors.border)),
        ]),
      ),
    );
  }
}
