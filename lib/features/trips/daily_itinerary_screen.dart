import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: day.items.length,
              itemBuilder: (_, i) {
                final it = day.items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: LtCard(
                    onTap: () => context.push('/trips/${trip.id}/place/${it.id}'),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: LtNetworkOrAsset(asset: AppAssets.forDestination(trip.city), url: it.photoUrl, height: 150, width: double.infinity),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(100)),
                                child: Text(categoryLabel(it.category), style: GoogleFonts.notoSansHebrew(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 12,
                              child: Text(it.placeName, style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, shadows: const [Shadow(blurRadius: 8)])),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (it.startTime != null) LtChip(label: hhmm(it.startTime), leading: const Icon(Icons.schedule, size: 12, color: AppColors.accent)),
                                  const Spacer(),
                                  if (it.rating != null) Text('${it.rating} ★', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (it.aiTip != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(12)),
                                  child: Text('טיפ AI · ${it.aiTip}', style: GoogleFonts.notoSansHebrew(fontSize: 13, color: AppColors.primaryDark)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                LtIconCircle(icon: Icons.add, size: 48, onTap: () => context.push('/trips/${trip.id}/item/edit?day=${day.id}')),
              if (trip.isOwner) const SizedBox(width: 10),
              Expanded(child: LtPrimaryButton(label: 'גלה במפה', leading: const Icon(Icons.map, color: Colors.white, size: 18), onPressed: () => context.push('/trips/${trip.id}/map?day=${day.id}'))),
            ],
          ),
        ),
      ),
    );
  }
}
