import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class WizardStep2Screen extends ConsumerWidget {
  const WizardStep2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(wizardProvider);
    final n = ref.read(wizardProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
              child: Row(
                children: [
                  LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
                  const Spacer(),
                  Text('שלב 2 מתוך 3', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  Text('איך נראה\nהטיול שלכם? ✈️', style: GoogleFonts.notoSansHebrew(fontSize: 27, fontWeight: FontWeight.w900, height: 1.25)),
                  const SizedBox(height: 8),
                  Text('ספרו לנו קצת על עצמכם ואנחנו נבנה את החוויה המושלמת', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                  const SizedBox(height: 22),
                  _label('👥  עם מי אתם נוסעים?'),
                  Row(
                    children: [
                      _opt(context, 'alone', 'לבד', Icons.person_outline, w.companion == 'alone', () => n.setCompanion('alone')),
                      _opt(context, 'couple', 'זוג', Icons.favorite_border, w.companion == 'couple', () => n.setCompanion('couple')),
                      _opt(context, 'family', 'משפחה', Icons.home_outlined, w.companion == 'family', () => n.setCompanion('family')),
                      _opt(context, 'friends', 'חברים', Icons.group_outlined, w.companion == 'friends', () => n.setCompanion('friends')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('נוסעים'),
                  Row(
                    children: [
                      Expanded(child: _stepper('מבוגרים', w.adults, (v) => n.setAdults(v.clamp(1, 12)))),
                      const SizedBox(width: 12),
                      Expanded(child: _stepper('ילדים', w.kids, (v) => n.setKids(v.clamp(0, 8)))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('⚡  קצב הטיול'),
                  Row(
                    children: [
                      _wide(context, 'relaxed', 'רגוע', 'נשימות עמוקות', Icons.beach_access_outlined, w.pace == 'relaxed', () => n.setPace('relaxed')),
                      _wide(context, 'balanced', 'מאוזן', 'שילוב נכון', Icons.balance_outlined, w.pace == 'balanced', () => n.setPace('balanced')),
                      _wide(context, 'intense', 'אינטנסיבי', 'מקסימום חוויות', Icons.bolt_outlined, w.pace == 'intense', () => n.setPace('intense')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label('💰  תקציב'),
                  Row(
                    children: [
                      _wide(context, 'budget', 'חסכוני', 'חכם ומשתלם', Icons.savings_outlined, w.budgetTier == 'budget', () => n.setBudgetTier('budget')),
                      _wide(context, 'mid', 'בינוני', 'איזון נכון', Icons.account_balance_wallet_outlined, w.budgetTier == 'mid', () => n.setBudgetTier('mid')),
                      _wide(context, 'luxury', 'מפנק', 'הטוב ביותר', Icons.diamond_outlined, w.budgetTier == 'luxury', () => n.setBudgetTier('luxury')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('תקציב כולל ₪${w.budgetTotal.round()}', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                  Slider(
                    value: w.budgetTotal,
                    min: 2000,
                    max: 40000,
                    divisions: 38,
                    activeColor: AppColors.accent,
                    onChanged: n.setBudgetTotal,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: LtPrimaryButton(label: 'המשך', icon: Icons.arrow_back, onPressed: () => context.push('/wizard/step3')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  Widget _opt(BuildContext c, String v, String l, IconData i, bool on, VoidCallback tap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: on ? AppColors.accent.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? AppColors.accent : AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                Icon(i, color: on ? AppColors.accent : AppColors.textBody),
                const SizedBox(height: 6),
                Text(l, style: GoogleFonts.notoSansHebrew(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wide(BuildContext c, String v, String l, String s, IconData i, bool on, VoidCallback tap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: BoxDecoration(
              color: on ? AppColors.accent.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? AppColors.accent : AppColors.border, width: 2),
            ),
            child: Column(
              children: [
                Icon(i, color: on ? AppColors.accent : AppColors.textBody),
                const SizedBox(height: 8),
                Text(l, textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(s, textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(fontSize: 10, color: AppColors.textBody)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return LtCard(
      child: Row(
        children: [
          Expanded(child: Text('$label\n$value', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline, color: AppColors.accent)),
          IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline, color: AppColors.accent)),
        ],
      ),
    );
  }
}
