import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'widgets/itinerary_timeline.dart';

class DailyItineraryScreen extends ConsumerStatefulWidget {
  const DailyItineraryScreen({super.key, required this.tripId, required this.dayId});
  final String tripId;
  final String dayId;

  @override
  ConsumerState<DailyItineraryScreen> createState() => _DailyItineraryScreenState();
}

class _DailyItineraryScreenState extends ConsumerState<DailyItineraryScreen> {
  late String _dayId;

  @override
  void initState() {
    super.initState();
    _dayId = widget.dayId;
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).valueOrNull;
    final days = ref.watch(tripDaysProvider(widget.tripId)).valueOrNull ?? [];
    final day = days.where((d) => d.id == _dayId).cast<TripDay?>().firstOrNull ?? (days.isEmpty ? null : days.first);
    if (trip == null || day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
        title: Column(
          children: [
            Text(trip.city, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${days.length} ימים · ${days.fold<int>(0, (p, d) => p + d.items.length)} מקומות', style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody)),
          ],
        ),
        actions: [LtIconCircle(icon: Icons.ios_share, onTap: () => context.push('/trips/${trip.id}/share')), const SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          LtDayChips(
            count: days.length,
            selected: day.dayIndex,
            onSelected: (i) {
              final d = days.firstWhere((x) => x.dayIndex == i, orElse: () => day);
              setState(() => _dayId = d.id);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                LtChip(label: 'רשימה', selected: true),
                const SizedBox(width: 8),
                LtChip(label: 'מפה', onTap: () => context.push('/trips/${trip.id}/map?day=${day.id}')),
                const Spacer(),
                Text(day.title ?? 'יום ${day.dayIndex}', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                LtChip(label: '${day.items.length} עצירות'),
                if (day.weather?['temp_c'] != null) LtChip(label: '${day.weather!['temp_c']}°'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [ItineraryTimeline(trip: trip, items: day.items)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (trip.isOwner)
                LtIconCircle(icon: Icons.add, size: 48, onTap: () => context.push('/trips/${trip.id}/item/add?day=${day.id}')),
              if (trip.isOwner) const SizedBox(width: 10),
              Expanded(child: LtPrimaryButton(label: 'גלה במפה', leading: const Icon(Icons.map, color: Colors.white, size: 18), onPressed: () => context.push('/trips/${trip.id}/map?day=${day.id}'))),
            ],
          ),
        ),
      ),
    );
  }
}
