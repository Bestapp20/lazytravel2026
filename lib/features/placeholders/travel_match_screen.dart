import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/lt_widgets.dart';

class TravelMatchScreen extends StatelessWidget {
  const TravelMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'מצא את שותף הטיול שלך',
                      style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '🌐 TravelMatch',
                      style: GoogleFonts.notoSansHebrew(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Image.asset(AppAssets.barcelonaHero, height: 200, width: double.infinity, fit: BoxFit.cover),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '94% התאמה',
                            style: GoogleFonts.notoSansHebrew(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const ComingSoonBody(
                  title: 'שותפים לטיול',
                  subtitle: 'פרופילים, אחוזי התאמה ובקשות הצטרפות הם v2. כרגע אפשר לשתף טיול עם המשפחה כצופים.',
                  emoji: '🤝',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.match),
    );
  }
}
