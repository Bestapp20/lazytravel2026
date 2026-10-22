import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/lt_widgets.dart';
import '../../../core/widgets/ticket_button.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';

/// Whether an item is logistics (ticket-bearing): flight, hotel, transfer.
bool isLogistics(TripItem it) => const {'flight', 'hotel', 'transport'}.contains(it.category);

bool _isBoat(TripItem it) {
  final t = '${it.placeName} ${it.notes ?? ''}'.toLowerCase();
  return ['סירה', 'מעבורת', 'boat', 'ferry', 'катер', 'speedboat', 'לונגטייל'].any(t.contains);
}

/// Image for an itinerary card: bundled art for flights/transfers, real photo otherwise.
({String asset, String? url}) cardImage(Trip trip, TripItem it) {
  switch (it.category) {
    case 'flight':
      return (asset: AppAssets.cardFlight, url: null);
    case 'transport':
      return (asset: _isBoat(it) ? AppAssets.cardBoat : AppAssets.cardTransfer, url: null);
    default:
      return (asset: AppAssets.forDestination(trip.city), url: it.photoUrl);
  }
}

IconData categoryIcon(String? c, [String name = '']) => catStyle(c, name).icon;

String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes דק׳';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hs = h == 1 ? 'שעה' : (h == 2 ? 'שעתיים' : '$h שעות');
  return m == 0 ? hs : '$hs ו-$m דק׳';
}

double _km(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Estimated leg between two stops. Null when it can't be estimated honestly.
({IconData icon, String label})? legBetween(TripItem a, TripItem b) {
  if (a.category == 'flight' || b.category == 'flight') {
    if (a.category == 'flight' && b.category == 'flight') return null;
  }
  if (a.lat == null || a.lng == null || b.lat == null || b.lng == null) return null;
  final km = _km(a.lat!, a.lng!, b.lat!, b.lng!);
  if (km > 150) return null; // a flight / long hop: not a ground leg
  if (km < 1.2) {
    final min = math.max(3, (km / 4.5 * 60).round());
    return (icon: Icons.directions_walk, label: '~$min דק׳ הליכה · ${km.toStringAsFixed(1)} ק״מ');
  }
  final min = (km / 30 * 60 + 5).round();
  return (icon: Icons.directions_car, label: '~${durationLabel(min)} נסיעה · ${km.toStringAsFixed(km < 10 ? 1 : 0)} ק״מ');
}

int? _mins(String? t) =>
    (t == null || t.length < 5) ? null : int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));

/// Fallback connector: time between the two stops when distance can't be estimated.
({IconData icon, String label})? _gap(TripItem a, TripItem b) {
  final s = _mins(a.startTime), e = _mins(b.startTime);
  if (s == null || e == null || e <= s) return null;
  return (icon: Icons.timelapse, label: '${durationLabel(e - s)} עד העצירה הבאה');
}

class ItineraryTimeline extends ConsumerStatefulWidget {
  const ItineraryTimeline({super.key, required this.trip, required this.items, this.compact = false});
  final Trip trip;
  final List<TripItem> items;
  final bool compact;

  @override
  ConsumerState<ItineraryTimeline> createState() => _ItineraryTimelineState();
}

class _ItineraryTimelineState extends ConsumerState<ItineraryTimeline> {
  final Set<String> _busy = {};

  Future<void> _attach(TripItem it) async {
    final repo = ref.read(documentsRepositoryProvider);
    if (repo == null) return;
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final path = r?.files.single.path;
    if (path == null) return;
    setState(() => _busy.add(it.id));
    try {
      final docType = switch (it.category) { 'flight' => 'flight', 'hotel' => 'hotel', _ => 'other' };
      await repo.upload(
        tripId: widget.trip.id,
        file: File(path),
        title: path.split(Platform.pathSeparator).last,
        docType: docType,
        dayId: it.dayId,
        itemId: it.id,
      );
      ref.invalidate(documentsProvider(widget.trip.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הכרטיס צורף ✓')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בהעלאה: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(it.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider(widget.trip.id)).valueOrNull ?? const <TripDocument>[];
    final items = widget.items;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      children.add(_stopRow(it, docs.where((d) => d.itemId == it.id).toList(), first: i == 0, last: i == items.length - 1));
      if (i < items.length - 1) children.add(_connector(it, items[i + 1]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _rail({required bool topLine, required bool bottomLine, required Widget node}) {
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          Container(width: 3, height: 18, color: topLine ? AppColors.accent.withValues(alpha: 0.45) : Colors.transparent),
          node,
          Expanded(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: bottomLine
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.45)],
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopRow(TripItem it, List<TripDocument> itemDocs, {required bool first, required bool last}) {
    final node = CategoryMarker(style: catStyle(it.category, it.placeName), size: 30);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rail(topLine: !first, bottomLine: !last, node: node),
          const SizedBox(width: 8),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: _card(it, itemDocs))),
        ],
      ),
    );
  }

  Widget _connector(TripItem a, TripItem b) {
    final leg = legBetween(a, b) ?? _gap(a, b);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Expanded(child: Container(width: 3, color: AppColors.accent.withValues(alpha: 0.45))),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                ),
                Expanded(child: Container(width: 3, color: AppColors.accent.withValues(alpha: 0.45))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: leg == null
                    ? Text('· · ·', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(leg.icon, size: 15, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(leg.label,
                                style: GoogleFonts.notoSansHebrew(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                            Text('  ·  משוער', style: GoogleFonts.notoSansHebrew(fontSize: 10, color: AppColors.textBody)),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(TripItem it, List<TripDocument> itemDocs) {
    final img = cardImage(widget.trip, it);
    final dur = it.durationMinutes;
    final busy = _busy.contains(it.id);
    return LtCard(
      onTap: () => context.push('/trips/${widget.trip.id}/place/${it.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                LtNetworkOrAsset(asset: img.asset, url: img.url, height: widget.compact ? 120 : 140, width: double.infinity),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: catStyle(it.category, it.placeName).color, borderRadius: BorderRadius.circular(100)),
                    child: Text(categoryLabel(it.category, it.placeName),
                        style: GoogleFonts.notoSansHebrew(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (it.startTime != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(100)),
                      child: Text(hhmm(it.startTime),
                          style: GoogleFonts.notoSansHebrew(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.placeName, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (dur != null && it.category != 'flight')
                      _pill(Icons.hourglass_bottom, it.category == 'hotel' ? 'צ׳ק-אין · ${durationLabel(dur)}' : 'זמן במקום · ${durationLabel(dur)}'),
                    if (it.rating != null && !const {'flight', 'transport'}.contains(it.category)) _pill(Icons.star_rounded, '${it.rating}'),
                  ],
                ),
                if (!isLogistics(it)) TicketButton(tripId: widget.trip.id, itemId: it.id, compact: true),
                if (isLogistics(it)) ...[
                  const SizedBox(height: 10),
                  _ticketRow(it, itemDocs, busy),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(100)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.notoSansHebrew(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
        ]),
      );

  Widget _ticketRow(TripItem it, List<TripDocument> itemDocs, bool busy) {
    final owner = widget.trip.isOwner;
    if (itemDocs.isNotEmpty) {
      final d = itemDocs.first;
      return Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/trips/${widget.trip.id}/docs/${d.id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemDocs.length > 1 ? '${itemDocs.length} כרטיסים מצורפים · פתח' : 'כרטיס מצורף · פתח',
                      style: GoogleFonts.notoSansHebrew(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                    ),
                  ),
                  Icon(d.isPdf ? Icons.picture_as_pdf : Icons.image, size: 18, color: AppColors.success),
                ]),
              ),
            ),
          ),
          if (owner) ...[
            const SizedBox(width: 8),
            LtIconCircle(icon: busy ? Icons.hourglass_top : Icons.add, size: 38, onTap: busy ? null : () => _attach(it)),
          ],
        ],
      );
    }
    if (!owner) return const SizedBox.shrink();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : () => _attach(it),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.attach_file, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(busy ? 'מעלה...' : 'צרף כרטיס',
                style: GoogleFonts.notoSansHebrew(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
