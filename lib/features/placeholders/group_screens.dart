import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class GroupPlaceholderScreen extends ConsumerWidget {
  const GroupPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('טיול קבוצתי')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.asset(AppAssets.amalfi, height: 180, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Text(
                    'טיול משפחתי',
                    style: GoogleFonts.notoSansHebrew(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ComingSoonBody(
            title: 'צ׳אט, הצבעות וחברים',
            subtitle: 'ב‑v1 אפשר לשתף טיול עם המשפחה כצופים בלבד. צ׳אט קבוצתי, הצבעות על מקומות ותקציב משותף יגיעו ב‑v2.',
            emoji: '👨‍👩‍👧',
          ),
          const SizedBox(height: 12),
          if (trips.isNotEmpty)
            LtPrimaryButton(
              label: 'שתפו טיול עם המשפחה',
              onPressed: () => context.push('/trips/${trips.first.id}/share'),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.group),
    );
  }
}

class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('צ׳אט קבוצתי'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: const ComingSoonBody(
        title: 'VoyagerAI והצ׳אט',
        subtitle: 'הודעות, ריאקציות, סקרים ועוזר AI יופיעו כאן ב‑v2 עם Supabase Realtime.',
        emoji: '💬',
      ),
    );
  }
}
