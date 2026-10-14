import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  String _chip = 'popular';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider).valueOrNull?.displayName ?? '';
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.primaryDark, Color(0xFF163F4A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'שלום' : 'שלום, $name 👋',
                                style: GoogleFonts.notoSansHebrew(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'לאן נטוס היום?',
                                style: GoogleFonts.notoSansHebrew(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: AssetImage(AppAssets.avatarEdward),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic_none, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              style: GoogleFonts.notoSansHebrew(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'לאן מתחשק לנסוע?',
                                hintStyle: GoogleFonts.notoSansHebrew(color: Colors.white70),
                                border: InputBorder.none,
                                filled: false,
                              ),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24, top: 16),
              children: [
                SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      LtChip(label: 'משפחות 👨‍👩‍👧', selected: _chip == 'family', onTap: () => setState(() => _chip = 'family')),
                      const SizedBox(width: 8),
                      LtChip(label: 'זוגות 💑', selected: _chip == 'couples', onTap: () => setState(() => _chip = 'couples')),
                      const SizedBox(width: 8),
                      LtChip(label: 'סופש״ב 🏖️', selected: _chip == 'weekend', onTap: () => setState(() => _chip = 'weekend')),
                      const SizedBox(width: 8),
                      LtChip(label: 'פופולרי 🔥', selected: _chip == 'popular', onTap: () => setState(() => _chip = 'popular')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => context.push('/wizard/step1'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, Color(0xFF1A5A66)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✨ AI מתאים לך יעד אישי',
                                  style: GoogleFonts.notoSansHebrew(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'ספר מה בא לך ואקצר לך את הדרך לחופשה',
                                  style: GoogleFonts.notoSansHebrew(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_left, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
                const LtSectionHeader(title: '✈️ יעדים מומלצים', action: 'הכל'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _dest(AppAssets.kyoto, 'קיוטו', 'יפן', 'תרבות וטבע קסום')),
                      const SizedBox(width: 12),
                      Expanded(child: _dest(AppAssets.lisbon, 'ליסבון', 'פורטוגל', 'אוכל, ים וחיי לילה')),
                    ],
                  ),
                ),
                const LtSectionHeader(title: 'מתאים לסופש״ב קרוב', action: 'הכל'),
                SizedBox(
                  height: 140,
                  child: ListView(
                    reverse: true,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _wide(AppAssets.santorini, 'סנטוריני'),
                      const SizedBox(width: 12),
                      _wide(AppAssets.amalfi, 'אמאלפי'),
                      const SizedBox(width: 12),
                      _wide(AppAssets.rome, 'רומא'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.explore),
    );
  }

  Widget _dest(String img, String city, String country, String desc) {
    return GestureDetector(
      onTap: () => context.push('/wizard/step1'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.asset(img, height: 180, width: double.infinity, fit: BoxFit.cover),
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('AI בחר', style: GoogleFonts.notoSansHebrew(color: Colors.white, fontSize: 10)),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city, style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(country, style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 12)),
                  Text(desc, style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wide(String img, String title) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.asset(img, width: 200, height: 140, fit: BoxFit.cover),
          Positioned(
            bottom: 10,
            right: 12,
            child: Text(
              title,
              style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
