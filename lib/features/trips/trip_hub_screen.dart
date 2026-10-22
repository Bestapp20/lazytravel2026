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
import '../../core/utils/category_style.dart';
import 'widgets/itinerary_timeline.dart';

class TripHubScreen extends ConsumerStatefulWidget {
  const TripHubScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripHubScreen> createState() => _TripHubScreenState();
}

class _TripHubScreenState extends ConsumerState<TripHubScreen> {
  bool _ordering = false;
  bool _coverAsked = false;

  void _ensureCover(Trip trip) {
    if (_coverAsked || trip.coverImageUrl != null) return;
    _coverAsked = true;
    ref.read(tripsRepositoryProvider)?.ensureCover(trip.id).then((_) {
      if (mounted) ref.invalidate(tripProvider(trip.id));
    }).catchError((_) {});
  }

  Future<void> _optimizeAsk(Trip trip, TripDay day) async {
    final all = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.today), title: const Text('סדר את היום הזה'), onTap: () => Navigator.of(c).pop(false)),
          ListTile(leading: const Icon(Icons.date_range), title: const Text('סדר את כל ימי הטיול'), onTap: () => Navigator.of(c).pop(true)),
        ]),
      ),
    );
    if (all == null) return;
    if (!all) return _optimize(trip, day);
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    setState(() => _ordering = true);
    try {
      await repo.optimizeRoute(tripId: trip.id);
      ref.invalidate(tripDaysProvider(trip.id));
      ref.invalidate(tripProvider(trip.id));
      _snack('כל ימי הטיול סודרו לפי שעות פתיחה, שעה ביום ומרחקים ✓');
    } catch (e) {
      _snack('שגיאה בסידור: $e');
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _optimize(Trip trip, TripDay day) async {
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    setState(() => _ordering = true);
    try {
      final r = await repo.optimizeRoute(dayId: day.id);
      final d = ((r['days'] as List?) ?? []).cast<Map>().firstOrNull;
      final dropped = (d?['dropped'] as List?)?.cast<String>() ?? const [];
      ref.invalidate(tripDaysProvider(trip.id));
      _snack(dropped.isEmpty
          ? 'היום סודר לפי שעות פתיחה, שעה ביום ומרחקים ✓'
          : 'סודר ✓  לא נמצא חלון מתאים ל: ${dropped.join(', ')}');
    } catch (e) {
      _snack('שגיאה בסידור: $e');
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Future<void> _manualOrder(Trip trip, TripDay day) async {
    final list = [...day.items];
    final saved = await showModalBottomSheet<List<TripItem>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('גררו כדי לשנות סדר', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Expanded(
              child: ReorderableListView(
                onReorder: (a, b) => setS(() {
                  if (b > a) b--;
                  list.insert(b, list.removeAt(a));
                }),
                children: [
                  for (var i = 0; i < list.length; i++)
                    ListTile(
                      key: ValueKey(list[i].id),
                      leading: CategoryMarker(style: catStyle(list[i].category, list[i].placeName), order: i + 1, size: 30),
                      title: Text(list[i].placeName, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LtPrimaryButton(label: 'שמור סדר', onPressed: () => Navigator.of(ctx).pop(list)),
            ),
          ]),
        ),
      ),
    );
    if (saved == null) return;
    final repo = ref.read(tripsRepositoryProvider);
    if (repo == null) return;
    try {
      final warnings = await repo.reorderDay(day.id, saved.map((e) => e.id).toList());
      ref.invalidate(tripDaysProvider(trip.id));
      if (!mounted) return;
      if (warnings.isEmpty) {
        _snack('הסדר נשמר והשעות עודכנו ✓');
      } else {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('שימו לב לשעות', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('⚠️ ${w['name']} (${w['start_time']}): ${w['warning']}', style: GoogleFonts.notoSansHebrew(fontSize: 13)),
                ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('השאר כך')),
              FilledButton(
                onPressed: () {
                  Navigator.of(c).pop();
                  _optimize(trip, day);
                },
                child: const Text('סדר חכם'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _snack('שגיאה: $e');
    }
  }

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
        _ensureCover(trip);
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
                            if (day != null && day.items.length > 1) ...[
                              LtChip(
                                label: _ordering ? 'מסדר...' : 'סדר חכם',
                                leading: const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                                onTap: _ordering ? null : () => _optimizeAsk(trip, day),
                              ),
                              const SizedBox(width: 6),
                              LtChip(
                                label: 'סדר ידני',
                                leading: const Icon(Icons.swap_vert, size: 14, color: AppColors.accent),
                                onTap: () => _manualOrder(trip, day),
                              ),
                            ],
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
