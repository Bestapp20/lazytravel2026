import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum AppTab { home, explore, plan, group, match }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active});

  final AppTab active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _item(context, Icons.home_filled, 'בית', AppTab.home, '/home'),
            _item(context, Icons.explore_outlined, 'גילוי', AppTab.explore, '/explore'),
            _fab(context),
            _item(context, Icons.group_outlined, 'קבוצתי', AppTab.group, '/group'),
            _item(context, Icons.favorite_border, 'Match', AppTab.match, '/match'),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    AppTab tab,
    String path,
  ) {
    final on = active == tab;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(path),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: on ? AppColors.accent : AppColors.navInactive),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.notoSansHebrew(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: on ? AppColors.accent : AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wizard/step1'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cta,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'תכנן',
              style: GoogleFonts.notoSansHebrew(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
