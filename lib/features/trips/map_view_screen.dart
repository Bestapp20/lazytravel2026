import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_style.dart';
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
  String? _fitKey;
  // Route geometry only depends on the visible points; recomputing the Catmull-Rom
  // spline + arrow markers on every rebuild (each marker tap / map event) caused jank.
  String? _geoKey;
  List<LatLng> _smoothPts = const [];
  List<Marker> _arrowMarkers = const [];
  static final _tiles = _TileImages(); // one provider => tiles stay in Flutter's ImageCache

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fit(List<LatLng> pts) {
    try {
      if (pts.length == 1) {
        _map.move(pts.first, 15);
      } else {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.fromLTRB(48, 220, 48, 250),
          maxZoom: 16,
        ));
      }
    } catch (_) {}
  }

  /// Catmull-Rom smoothing so the route reads as a flowing path rather than straight zig-zags.
  static List<LatLng> _smooth(List<LatLng> p) {
    if (p.length < 3) return p;
    final out = <LatLng>[];
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = p[math.max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[math.min(p.length - 1, i + 2)];
      for (var k = 0; k < 12; k++) {
        final t = k / 12, t2 = t * t, t3 = t2 * t;
        double f(double a, double b, double c, double d) =>
            0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
        out.add(LatLng(f(p0.latitude, p1.latitude, p2.latitude, p3.latitude), f(p0.longitude, p1.longitude, p2.longitude, p3.longitude)));
      }
    }
    out.add(p.last);
    return out;
  }

  /// Direction arrows at each leg's midpoint, rotated along the leg.
  static List<Marker> _arrows(List<LatLng> p) => [
        for (var i = 0; i < p.length - 1; i++)
          Marker(
            point: LatLng((p[i].latitude + p[i + 1].latitude) / 2, (p[i].longitude + p[i + 1].longitude) / 2),
            width: 22,
            height: 22,
            child: Transform.rotate(
              angle: math.atan2(p[i + 1].longitude - p[i].longitude, p[i + 1].latitude - p[i].latitude),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)]),
                child: const Icon(Icons.navigation_rounded, size: 15, color: AppColors.primaryDark),
              ),
            ),
          ),
      ];

  @override
  void initState() {
    super.initState();
    _dayId = widget.dayId;
  }

  Marker _marker(List<TripItem> items, int i) {
    final it = items[i];
    final sel = i == _sheet;
    return Marker(
      point: LatLng(it.lat!, it.lng!),
      width: sel ? 62 : 52,
      height: sel ? 62 : 52,
      child: GestureDetector(
        onTap: () {
          setState(() => _sheet = i);
          _map.move(LatLng(it.lat!, it.lng!), _map.camera.zoom);
        },
        child: RepaintBoundary(child: CategoryMarker(style: catStyle(it.category, it.placeName), order: i + 1, selected: sel)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).valueOrNull;
    final days = ref.watch(tripDaysProvider(widget.tripId)).valueOrNull ?? [];
    if (trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final day = days.where((d) => d.id == _dayId).cast<TripDay?>().firstOrNull ?? (days.isEmpty ? null : days.first);
    final items = (day?.items ?? []).where((i) => i.lat != null && i.lng != null).where((i) {
      if (_cat == 'all') return true;
      return catStyle(i.category, i.placeName).key == _cat;
    }).toList();
    final center = items.isNotEmpty
        ? LatLng(items.first.lat!, items.first.lng!)
        : LatLng(trip.hotel?.lat ?? trip.destinations.firstOrNull?.lat ?? 41.39, trip.hotel?.lng ?? trip.destinations.firstOrNull?.lng ?? 2.17);
    final current = items.isEmpty ? null : items[_sheet.clamp(0, items.length - 1)];
    final pts = items.map((e) => LatLng(e.lat!, e.lng!)).toList();
    final fitKey = '${day?.id}|$_cat|${pts.length}';
    if (fitKey != _fitKey && pts.isNotEmpty) {
      _fitKey = fitKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(pts));
    }
    final dayCats = <String, CatStyle>{
      for (final i in (day?.items ?? const <TripItem>[]).where((i) => i.lat != null)) catStyle(i.category, i.placeName).key: catStyle(i.category, i.placeName),
    };
    if (_geoKey != fitKey) {
      _geoKey = fitKey;
      _smoothPts = _smooth(pts);
      _arrowMarkers = items.length > 1 ? _arrows(pts) : const [];
    }
    final smooth = _smoothPts;

    return Scaffold(
      body: Stack(
        children: [
          // The map canvas is direction-agnostic; RTL ambient direction breaks tile placement.
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              initialCameraFit: pts.length > 1
                  ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.fromLTRB(48, 220, 48, 250), maxZoom: 16)
                  : null,
            ),
            children: [
              TileLayer(
                // Esri World Street Map (keyless). CARTO now needs an API key and OSM's
                // public tile servers block app traffic (tiles stayed blank).
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                maxNativeZoom: 19,
                retinaMode: RetinaMode.isHighDensity(context),
                tileDisplay: const TileDisplay.instantaneous(),
                userAgentPackageName: 'com.lazytravel.lazy_travel',
                tileProvider: _tiles,
                keepBuffer: 1,
                panBuffer: 0,
                              ),
              const SimpleAttributionWidget(source: Text('Tiles © Esri — Esri, HERE, Garmin, © OpenStreetMap contributors', style: TextStyle(fontSize: 9)), alignment: Alignment.topLeft),
              if (items.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(points: smooth, color: Colors.white, strokeWidth: 9),
                    Polyline(
                      points: smooth,
                      strokeWidth: 5.5,
                      gradientColors: const [AppColors.accent, AppColors.primaryDark],
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              if (items.length > 1) MarkerLayer(markers: _arrowMarkers),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < items.length; i++)
                    if (i != _sheet) _marker(items, i),
                  if (items.isNotEmpty) _marker(items, _sheet.clamp(0, items.length - 1)),
                ],
              ),
            ],
          )),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        LtChip(label: 'הכל', selected: _cat == 'all', onTap: () => setState(() { _cat = 'all'; _sheet = 0; })),
                        for (final c in dayCats.values) ...[
                          const SizedBox(width: 6),
                          LtChip(
                            label: c.label,
                            leading: Icon(c.icon, size: 14, color: _cat == c.key ? Colors.white : c.color),
                            selected: _cat == c.key,
                            onTap: () => setState(() { _cat = c.key; _sheet = 0; }),
                          ),
                        ],
                      ],
                    ),
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
                                Text('${categoryLabel(current.category, current.placeName)}${current.startTime != null ? '  ·  ${hhmm(current.startTime)}' : ''}', style: GoogleFonts.notoSansHebrew(color: catStyle(current.category, current.placeName).color, fontSize: 12, fontWeight: FontWeight.w800)),
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


/// Loads tiles through Flutter's own image pipeline (dart:io HttpClient + ImageCache).
/// flutter_map's default http-based provider left tiles blank on Android.
class _TileImages extends TileProvider {
  _TileImages() : super(headers: {'User-Agent': 'LazyTravel/1.0 (com.lazytravel.lazy_travel)'});
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return NetworkImage(url, headers: headers);
  }
}
