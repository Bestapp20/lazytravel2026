import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'widgets/itinerary_timeline.dart' show durationLabel;

const _kTips = <String, List<String>>{
  'food': ['מומלץ להזמין מקום מראש, במיוחד בערב', 'שאלו על מנת היום, היא לרוב משתלמת יותר'],
  'museum': ['כדאי להזמין כרטיסים מראש באתר הרשמי כדי לדלג על התור'],
  'nature': ['הגיעו מוקדם: אור טוב ופחות אנשים', 'קחו מים, כובע וקרם הגנה'],
  'shopping': ['שווה להתמקח בשווקים, ולשלם במזומן'],
  'nightlife': ['בדקו קוד לבוש ושעות פתיחה לפני שיוצאים'],
  'attraction': ['הגיעו מוקדם בבוקר כדי להימנע מעומס', 'שמרו על חפצי ערך באזורים הומי תיירים'],
};

const _kDefaultDuration = {'food': 75, 'museum': 120, 'nature': 120, 'shopping': 90, 'nightlife': 120, 'attraction': 90};

class PlacePreviewScreen extends ConsumerStatefulWidget {
  const PlacePreviewScreen({super.key, required this.tripId, required this.place, required this.itemCategory, this.dayId});
  final String tripId;
  final String? dayId;
  final PlaceSuggestion place;
  final String itemCategory;

  @override
  ConsumerState<PlacePreviewScreen> createState() => _PlacePreviewScreenState();
}

class _PlacePreviewScreenState extends ConsumerState<PlacePreviewScreen> {
  late final Future<PlaceFull?> _future;
  final _page = PageController();
  int _photo = 0;
  TimeOfDay? _time;
  late int _duration = _kDefaultDuration[widget.itemCategory] ?? 90;
  bool _saving = false;
  bool _hoursOpen = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(placesRepositoryProvider)?.detailsFull(widget.place.placeId) ?? Future.value(null);
  }

  TimeOfDay _suggestedTime(List<TripItem> items) {
    var minutes = 10 * 60;
    for (final it in items) {
      final t = it.startTime;
      if (t == null || t.length < 5) continue;
      final start = int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));
      final end = start + (it.durationMinutes ?? 60) + 30;
      if (end > minutes) minutes = end;
    }
    minutes = ((minutes + 14) ~/ 15) * 15;
    if (minutes > 22 * 60) minutes = 22 * 60;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _add(PlaceFull? full, TripDay day) async {
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      final time = _fmt(_time ?? _suggestedTime(day.items));
      final p = widget.place;
      final tips = _kTips[widget.itemCategory] ?? _kTips['attraction']!;
      final created = await repo.upsertItem({
        'trip_id': widget.tripId,
        'day_id': day.id,
        'place_name': full?.name ?? p.name,
        'google_place_id': p.placeId,
        'category': widget.itemCategory,
        'address': full?.address ?? p.address,
        'lat': full?.lat ?? p.lat,
        'lng': full?.lng ?? p.lng,
        'map_link': full?.mapLink,
        'start_time': time,
        'duration_minutes': _duration,
        'rating': full?.rating ?? p.rating,
        'price_level': full?.priceLevel,
        'photo_url': (full?.photos.isNotEmpty ?? false) ? full!.photos.first : p.photoUrl,
        'photo_reference': full?.photoReference ?? p.photoReference,
        'ai_tip': tips.first,
        'notes': full?.summary,
        'sort_order': day.items.length,
      });
      // Re-number so the new stop sits at its time slot.
      final ordered = [...day.items];
      var insertAt = ordered.length;
      for (var i = 0; i < ordered.length; i++) {
        final t = ordered[i].startTime;
        if (t != null && t.length >= 5 && t.substring(0, 5).compareTo(time) > 0) {
          insertAt = i;
          break;
        }
      }
      ordered.insert(insertAt, created);
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].sortOrder != i || ordered[i].id == created.id) {
          await repo.upsertItem({'sort_order': i}, id: ordered[i].id);
        }
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('נוסף למסלול ב-$time ✓')));
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(tripDaysProvider(widget.tripId)).valueOrNull ?? const <TripDay>[];
    final day = days.where((d) => d.id == widget.dayId).cast<TripDay?>().firstOrNull ?? (days.isEmpty ? null : days.first);
    return FutureBuilder<PlaceFull?>(
      future: _future,
      builder: (_, snap) {
        final full = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        final photos = full?.photos.isNotEmpty == true
            ? full!.photos
            : [if (widget.place.photoUrl != null) widget.place.photoUrl!];
        return Scaffold(
          backgroundColor: AppColors.bgLight,
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.primaryDark,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: LtIconCircle(icon: Icons.arrow_forward, onTap: () => Navigator.of(context).pop()),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  if (photos.isEmpty)
                    Container(color: AppColors.sectionTint)
                  else
                    PageView.builder(
                      controller: _page,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: AppColors.sectionTint)),
                    ),
                  if (photos.length > 1)
                    Positioned(
                      bottom: 14,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < photos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _photo ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _photo ? Colors.white : Colors.white60,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (photos.length > 1)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: const Alignment(0.9, 0.75),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(100)),
                            child: Text('${_photo + 1}/${photos.length}',
                                style: GoogleFonts.notoSansHebrew(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 140),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(full?.name ?? widget.place.name,
                      style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if ((full?.rating ?? widget.place.rating) != null)
                      LtChip(
                        label: '${full?.rating ?? widget.place.rating}${full?.ratingCount != null ? ' (${full!.ratingCount})' : ''}',
                        leading: const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                      ),
                    if (full?.openNow != null)
                      LtChip(
                        label: full!.openNow! ? 'פתוח עכשיו' : 'סגור עכשיו',
                        leading: Icon(Icons.circle, size: 9, color: full.openNow! ? AppColors.success : AppColors.danger),
                      ),
                    if (full?.priceLevel != null) LtChip(label: '₪' * (full!.priceLevel!.clamp(1, 4))),
                  ]),
                  if (loading)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  if (full?.summary != null) ...[
                    const SizedBox(height: 14),
                    Text(full!.summary!, style: GoogleFonts.notoSansHebrew(fontSize: 14.5, height: 1.5, color: AppColors.textDark)),
                  ],
                  const SizedBox(height: 14),
                  _infoCard(full),
                  const SizedBox(height: 14),
                  _sectionTitle(Icons.lightbulb_outline, 'טיפים'),
                  for (final t in _kTips[widget.itemCategory] ?? _kTips['attraction']!) _bullet(t),
                  if (full != null && full.reviews.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionTitle(Icons.forum_outlined, 'מה אומרים מטיילים'),
                    for (final r in full.reviews) _review(r),
                  ],
                ]),
              ),
            ),
          ]),
          bottomSheet: day == null ? null : _addBar(full, day),
        );
      },
    );
  }

  Widget _sectionTitle(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(t, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: AppColors.accent)),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: GoogleFonts.notoSansHebrew(fontSize: 13.5, color: AppColors.textDark))),
        ]),
      );

  Widget _infoCard(PlaceFull? full) {
    final address = full?.address ?? widget.place.address;
    return LtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (address != null) _infoRow(Icons.place_outlined, address),
        if (full?.hours != null && full!.hours!.isNotEmpty)
          InkWell(
            onTap: () => setState(() => _hoursOpen = !_hoursOpen),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow(Icons.schedule, _hoursOpen ? 'שעות פתיחה' : 'שעות פתיחה (הקישו להצגה)'),
              if (_hoursOpen)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 30, bottom: 6),
                  child: Text(full.hours!.join('\n'), style: GoogleFonts.notoSansHebrew(fontSize: 12.5, height: 1.6)),
                ),
            ]),
          ),
        if (full?.phone != null) _infoRow(Icons.phone_outlined, full!.phone!),
        if (full?.mapLink != null || full?.website != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, children: [
              if (full?.mapLink != null)
                LtChip(label: 'פתח במפות', leading: const Icon(Icons.map, size: 14, color: AppColors.accent),
                    onTap: () => launchUrl(Uri.parse(full!.mapLink!), mode: LaunchMode.externalApplication)),
              if (full?.website != null)
                LtChip(label: 'אתר', leading: const Icon(Icons.language, size: 14, color: AppColors.accent),
                    onTap: () => launchUrl(Uri.parse(full!.website!), mode: LaunchMode.externalApplication)),
            ]),
          ),
      ]),
    );
  }

  Widget _infoRow(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: GoogleFonts.notoSansHebrew(fontSize: 13.5))),
        ]),
      );

  Widget _review(PlaceReview r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(r.author ?? 'מטייל', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            if (r.rating != null) Text('★' * r.rating!.round(), style: const TextStyle(color: AppColors.warning, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Text(r.text, maxLines: 5, overflow: TextOverflow.ellipsis, style: GoogleFonts.notoSansHebrew(fontSize: 12.5, height: 1.45)),
          if (r.when != null) Text(r.when!, style: GoogleFonts.notoSansHebrew(fontSize: 10.5, color: AppColors.textBody)),
        ]),
      );

  Widget _addBar(PlaceFull? full, TripDay day) {
    final t = _time ?? _suggestedTime(day.items);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: _pickerChip(Icons.schedule, 'שעה · ${_fmt(t)}', () async {
                final picked = await showTimePicker(context: context, initialTime: t);
                if (picked != null) setState(() => _time = picked);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pickerChip(Icons.hourglass_bottom, durationLabel(_duration), () {
                const opts = [30, 45, 60, 75, 90, 120, 150, 180, 240];
                final i = opts.indexOf(_duration);
                setState(() => _duration = opts[(i + 1) % opts.length]);
              }),
            ),
          ]),
          const SizedBox(height: 10),
          LtPrimaryButton(
            label: _saving ? 'מוסיף...' : 'הוסף למסלול · יום ${day.dayIndex}',
            leading: const Icon(Icons.add_location_alt, color: Colors.white, size: 18),
            onPressed: _saving ? null : () => _add(full, day),
          ),
        ]),
      ),
    );
  }

  Widget _pickerChip(IconData i, String label, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ]),
        ),
      );
}
