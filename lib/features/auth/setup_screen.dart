import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(child: Image.asset(AppAssets.logo, width: 72, height: 72)),
              const SizedBox(height: 18),
              Text(
                'חסר חיבור ל‑Supabase',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansHebrew(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'האפליקציה צריכה כתובת פרויקט ומפתח anon. הריצו עם dart-define כמו שמוסבר ב‑README.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansHebrew(
                  fontSize: 15,
                  color: AppColors.textBody,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
                  style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
