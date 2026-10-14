import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(AppAssets.santorini, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'lazy travel',
                              style: GoogleFonts.notoSansHebrew(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(AppAssets.logo, width: 28, height: 28),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        child: Column(
                          children: [
                            Text(
                              'כל הטיול שלך\nבמקום אחד',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansHebrew(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'תגיד לנו לאן, ואנחנו נבנה לך\nאת הטיול המושלם',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansHebrew(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'תוכניות טיול פופולריות',
                          style: GoogleFonts.notoSansHebrew(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.sectionTint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '✨ AI',
                            style: GoogleFonts.notoSansHebrew(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 168,
                    child: ListView(
                      reverse: true,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        _WelcomeCard(
                          image: AppAssets.tokyo,
                          title: 'טוקיו',
                          flag: '🇯🇵',
                          meta: '7 ימים · 6 לילות',
                          tags: ['אוכל', 'תרבות'],
                        ),
                        SizedBox(width: 12),
                        _WelcomeCard(
                          image: AppAssets.santorini,
                          title: 'סנטוריני',
                          flag: '🇬🇷',
                          meta: '5 ימים · 4 לילות',
                          tags: ['רומנטי', 'חוף'],
                        ),
                        SizedBox(width: 12),
                        _WelcomeCard(
                          image: AppAssets.amalfi,
                          title: 'ניו יורק',
                          flag: '🇺🇸',
                          meta: '6 ימים · 5 לילות',
                          tags: ['עירוני', 'קניות'],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: LtPrimaryButton(
                      label: 'התחל לתכנן',
                      leading: const Text('✨', style: TextStyle(fontSize: 16)),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: LtSecondaryButton(
                      label: 'יש לי כבר חשבון',
                      icon: Icons.person_outline,
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.image,
    required this.title,
    required this.flag,
    required this.meta,
    required this.tags,
  });

  final String image;
  final String title;
  final String flag;
  final String meta;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(image, height: 86, width: 148, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$flag $title',
                  style: GoogleFonts.notoSansHebrew(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  meta,
                  style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sectionTint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            t,
                            style: GoogleFonts.notoSansHebrew(
                              fontSize: 10,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
