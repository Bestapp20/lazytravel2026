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
import 'widgets/itinerary_timeline.dart';

class TripHubScreen extends ConsumerStatefulWidget {
  const TripHubScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripHubScreen> createState() => _TripHubScreenState();
}

class _TripHubScreenState extends ConsumerState<TripHubScreen> {
  int _tab = 0;
  int _day = 1;

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final docsAsync = ref.watch(documentsProvider(widget.tripId));
    return tripAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (trip) {
        final days = daysAsync.valueOrNull ?? [];
        final day = days.isEmpty ? null : days.firstWhere((d) => d.dayIndex == _day, orElse: () => days.first);
        return Scaffold(
          backgroundColor: AppColors.bgLight,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.go('/home')),
                ),
                actions: [
                  LtIconCircle(icon: Icons.ios_share, onTap: () => context.push('/trips/${trip.id}/share')),
                  const SizedBox(width: 8),
                  if (trip.isOwner)
                    LtIconCircle(icon: Icons.edit, onTap: () {}),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      LtNetworkOrAsset(asset: AppAssets.forDestination(trip.city), url: trip.coverImageUrl),
                      Container(color: Colors.black.withValues(alpha: 0.25)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(trip.city, style: GoogleFonts.notoSansHebrew(fontSize: 28, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.sectionTint, borderRadius: BorderRadius.circular(100)),
                            child: Text(trip.status == 'done' ? 'הושלם' : 'פעיל', style: GoogleFonts.notoSansHebrew(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          LtChip(label: heDateRange(trip.startDate, trip.endDate), leading: const Icon(Icons.calendar_today, size: 12, color: AppColors.accent)),
                          LtChip(label: '${nightsBetween(trip.startDate, trip.endDate)} לילות', leading: const Icon(Icons.nights_stay, size: 14, color: AppColors.accent)),
                          LtChip(label: '${trip.travelers} נוסעים', leading: const Icon(Icons.group, size: 14, color: AppColors.accent)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _tabs(),
                      const SizedBox(height: 12),
                      if (_tab == 0) ...[
                        if (days.isNotEmpty)
                          LtDayChips(count: days.length, selected: _day, onSelected: (d) => setState(() => _day = d)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            LtChip(label: 'רשימה', selected: true, onTap: () {
                              if (day != null) context.push('/trips/${trip.id}/day/${day.id}');
                            }),
                            const SizedBox(width: 8),
                            LtChip(label: 'מפה', onTap: () => context.push('/trips/${trip.id}/map?day=${day?.id ?? ''}')),
                            const Spacer(),
                            if (day != null)
                              Text(day.title ?? 'יום $_day', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (day == null || day.items.isEmpty)
                          Text('אין נקודות ביום זה עדיין.', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody))
                        else
                          ItineraryTimeline(trip: trip, items: day.items, compact: true),
                      ] else if (_tab == 1) ...[
                        _logistics(trip, docsAsync.valueOrNull ?? []),
                      ] else ...[
                        LtPrimaryButton(label: 'פתח תקציב מלא', onPressed: () => context.push('/trips/${trip.id}/budget')),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: trip.isOwner
              ? FloatingActionButton(
                  backgroundColor: AppColors.accent,
                  onPressed: () => context.push('/trips/${trip.id}/item/add?day=${day?.id ?? ''}'),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          bottomNavigationBar: _tripNav(trip, day),
        );
      },
    );
  }

  Widget _tabs() {
    const labels = ['מסלול', 'לוגיסטיקה', 'תקציב'];
    return Row(
      children: List.generate(3, (i) {
        final on = _tab == i;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() => _tab = i),
            child: Column(
              children: [
                Text(labels[i], style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, color: on ? AppColors.primaryDark : AppColors.textBody)),
                const SizedBox(height: 6),
                Container(height: 3, color: on ? AppColors.accent : Colors.transparent),
              ],
            ),
          ),
        );
      }),
    );
  }



  Widget _logistics(Trip trip, List<TripDocument> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open, color: AppColors.accent),
          title: Text('מסמכים (${docs.length})', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push('/trips/${trip.id}/docs'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hotel, color: AppColors.accent),
          title: Text(trip.hotel?.name ?? 'לא הוגדר מלון', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
          subtitle: Text(trip.hotel?.address ?? 'ניתן להוסיף בזמן בניית המסלול', style: GoogleFonts.notoSansHebrew(fontSize: 12)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flight, color: AppColors.accent),
          title: Text('טיסות והזמנות', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
          subtitle: Text('הזמנה אצל ספקים תגיע ב‑v2. בינתיים העלו שוברים למסמכים.', style: GoogleFonts.notoSansHebrew(fontSize: 12)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.share, color: AppColors.accent),
          title: Text('שיתוף עם המשפחה', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
          onTap: () => context.push('/trips/${trip.id}/share'),
        ),
      ],
    );
  }

  Widget _tripNav(Trip trip, TripDay? day) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.home_outlined, 'ראשי', () => context.go('/home')),
            _nav(Icons.route, 'מסלול', () {
              if (day != null) context.push('/trips/${trip.id}/day/${day.id}');
            }),
            _nav(Icons.map_outlined, 'מפה', () => context.push('/trips/${trip.id}/map')),
            _nav(Icons.account_balance_wallet_outlined, 'תקציב', () => context.push('/trips/${trip.id}/budget')),
            _nav(Icons.more_horiz, 'עוד', () => context.push('/trips/${trip.id}/live')),
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData i, String l, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, color: AppColors.primaryDark, size: 20),
          Text(l, style: GoogleFonts.notoSansHebrew(fontSize: 10, color: AppColors.textBody)),
        ],
      ),
    );
  }
}
