import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.tripId, required this.itemId});
  final String tripId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId)).valueOrNull;
    final days = ref.watch(tripDaysProvider(tripId)).valueOrNull ?? [];
    TripItem? item;
    for (final d in days) {
      for (final i in d.items) {
        if (i.id == itemId) item = i;
      }
    }
    if (trip == null || item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final it = item;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: LtNetworkOrAsset(asset: AppAssets.forDestination(trip.city), url: it.photoUrl),
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
                      Expanded(
                        child: Text(it.placeName, style: GoogleFonts.notoSansHebrew(fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                      LtChip(label: categoryLabel(it.category, it.placeName)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (it.rating != null)
                    Text('${it.rating} ★   ·   ${it.durationMinutes ?? 90} דקות מומלץ', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                  const SizedBox(height: 16),
                  LtCard(
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(child: Text(it.address ?? 'אין כתובת', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LtCard(
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Text('${hhmm(it.startTime)}  ${it.durationMinutes != null ? '· ${it.durationMinutes} דק׳' : ''}', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (it.notes != null && it.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LtCard(child: Text(it.notes!, style: GoogleFonts.notoSansHebrew(height: 1.45))),
                  ],
                  if (it.aiTip != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.sectionTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('ה‑AI ממליץ:\n${it.aiTip}', style: GoogleFonts.notoSansHebrew(height: 1.45)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LtPrimaryButton(
                      label: 'פתח ניווט',
                      icon: Icons.near_me,
                      onPressed: () {
                        final link = it.mapLink ??
                            (it.lat != null ? 'https://www.google.com/maps/dir/?api=1&destination=${it.lat},${it.lng}' : null);
                        if (link != null) launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LtSecondaryButton(
                      label: trip.isOwner ? 'עריכה' : 'שמור לטיול',
                      icon: Icons.bookmark_outline,
                      onPressed: trip.isOwner ? () => context.push('/trips/$tripId/item/edit?item=${it.id}&day=${it.dayId}') : null,
                    ),
                  ),
                ],
              ),
              if (trip.isOwner)
                TextButton(
                  onPressed: () async {
                    await ref.read(tripsRepositoryProvider)?.deleteItem(it.id);
                    ref.invalidate(tripDaysProvider(tripId));
                    if (context.mounted) context.pop();
                  },
                  child: Text('החלף / מחק מקום ביום זה', style: GoogleFonts.notoSansHebrew(color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
