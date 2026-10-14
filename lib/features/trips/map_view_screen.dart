import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key, required this.tripId, this.dayId});
  final String tripId;
  final String? dayId;

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  String? _dayId;
  String _cat = 'all';
  int _sheet = 0;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _dayId = widget.dayId;
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).valueOrNull;
    final days = ref.watch(tripDaysProvider(widget.tripId)).valueOrNull ?? [];
    if (trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final day = days.where((d) => d.id == _dayId).cast<TripDay?>().firstOrNull ?? (days.isEmpty ? null : days.first);
    final items = (day?.items ?? []).where((i) => i.lat != null && i.lng != null).where((i) {
      if (_cat == 'all') return true;
      return i.category == _cat;
    }).toList();
    final center = items.isNotEmpty
        ? LatLng(items.first.lat!, items.first.lng!)
        : LatLng(trip.hotel?.lat ?? trip.destinations.firstOrNull?.lat ?? 41.39, trip.hotel?.lng ?? trip.destinations.firstOrNull?.lng ?? 2.17);
    final current = items.isEmpty ? null : items[_sheet.clamp(0, items.length - 1)];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lazytravel.lazy_travel',
              ),
              if (items.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: items.map((e) => LatLng(e.lat!, e.lng!)).toList(),
                      color: AppColors.accent,
                      strokeWidth: 4,
                      pattern: StrokePattern.dotted(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < items.length; i++)
                    Marker(
                      point: LatLng(items[i].lat!, items[i].lng!),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => setState(() => _sheet = i),
                        child: CircleAvatar(
                          backgroundColor: i == _sheet ? AppColors.primaryDark : AppColors.accent,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LtCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            '${trip.city} — יום ${day?.dayIndex ?? 1}',
                            style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (days.isNotEmpty)
                    LtDayChips(
                      count: days.length,
                      selected: day?.dayIndex ?? 1,
                      onSelected: (i) {
                        final d = days.firstWhere((x) => x.dayIndex == i);
                        setState(() {
                          _dayId = d.id;
                          _sheet = 0;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      LtChip(label: 'הכל', selected: _cat == 'all', onTap: () => setState(() => _cat = 'all')),
                      LtChip(label: 'אטרקציות', selected: _cat == 'attraction', onTap: () => setState(() => _cat = 'attraction')),
                      LtChip(label: 'אוכל', selected: _cat == 'food', onTap: () => setState(() => _cat = 'food')),
                      LtChip(label: 'מלונות', selected: _cat == 'hotel', onTap: () => setState(() => _cat = 'hotel')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (current != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: LtCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LtNetworkOrAsset(asset: AppAssets.forDestination(trip.city), url: current.photoUrl, width: 72, height: 72),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(categoryLabel(current.category), style: GoogleFonts.notoSansHebrew(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text(current.placeName, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
                                if (current.rating != null) Text('${current.rating} ★', style: GoogleFonts.notoSansHebrew(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LtSecondaryButton(
                              label: 'פרטים',
                              icon: Icons.info_outline,
                              onPressed: () => context.push('/trips/${trip.id}/place/${current.id}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LtPrimaryButton(
                              label: 'נווט',
                              icon: Icons.near_me,
                              onPressed: () {
                                final link = current.mapLink ??
                                    'https://www.google.com/maps/dir/?api=1&destination=${current.lat},${current.lng}';
                                launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
