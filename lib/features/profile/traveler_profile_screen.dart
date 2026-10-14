import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class TravelerProfileScreen extends ConsumerWidget {
  const TravelerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final trips = ref.watch(tripsProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('הפרופיל שלי'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider)?.signOut(),
            icon: const Icon(Icons.logout, color: AppColors.primaryDark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage: AssetImage(AppAssets.avatarEdward),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile?.displayName ?? 'מטייל',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansHebrew(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            profile?.city ?? 'ישראל',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansHebrew(color: AppColors.textBody),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('${trips.length}', 'טיולים'),
              _stat('${trips.where((t) => t.status == 'done').length}', 'הושלמו'),
              _stat(profile?.kosher == true ? 'כן' : 'לא', 'כשרות'),
            ],
          ),
          const SizedBox(height: 20),
          LtCard(
            child: Text(
              profile?.bio ?? 'כאן יופיע סגנון הטיול שלכם. עריכת פרופיל מלאה תורחב ב‑v2.',
              style: GoogleFonts.notoSansHebrew(color: AppColors.textBody, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) {
    return Expanded(
      child: LtCard(
        child: Column(
          children: [
            Text(v, style: GoogleFonts.notoSansHebrew(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accent)),
            Text(l, style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
          ],
        ),
      ),
    );
  }
}
