import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId)).valueOrNull;
    final expenses = ref.watch(expensesProvider(tripId)).valueOrNull ?? [];
    if (trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final spent = expenses.fold<num>(0, (p, e) => p + e.amount);
    final total = trip.budgetTotal ?? 0;
    final pct = total == 0 ? 0.0 : (spent / total).clamp(0, 1).toDouble();
    final nights = nightsBetween(trip.startDate, trip.endDate).clamp(1, 365);
    final byCat = <String, num>{};
    for (final e in expenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('תקציב הטיול'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          LtCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text(trip.city, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, color: AppColors.accent)),
                    const Spacer(),
                    if (daysUntil(trip.startDate) > 0)
                      LtChip(label: '${daysUntil(trip.startDate)} ימים נותרו'),
                  ],
                ),
                const SizedBox(height: 8),
                Text('תקציב כללי', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                Text(
                  '${ils(spent)} / ${ils(total)}',
                  style: GoogleFonts.notoSansHebrew(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  width: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 12,
                        backgroundColor: AppColors.border,
                        color: AppColors.accent,
                        strokeCap: StrokeCap.round,
                      ),
                      Text('${(pct * 100).round()}%\nנוצל', textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _mini(ils(spent), 'הוצאתי'),
                    _mini(ils((total - spent).clamp(0, total)), 'נותר'),
                    _mini(ils(spent / nights), 'ליום'),
                  ],
                ),
              ],
            ),
          ),
          if (pct >= 0.9) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Text('שימו לב: ניצלתם ${(pct * 100).round()}% מהתקציב. מומלץ לנהל הוצאות בזהירות.', style: GoogleFonts.notoSansHebrew()),
            ),
          ],
          const SizedBox(height: 18),
          Text('לפי קטגוריה', style: GoogleFonts.notoSansHebrew(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...['flights', 'hotel', 'food', 'activities', 'transport', 'other'].map((c) {
            final v = byCat[c] ?? 0;
            final labels = {
              'flights': 'טיסות',
              'hotel': 'מלון',
              'food': 'אוכל',
              'activities': 'אטרקציות',
              'transport': 'תחבורה',
              'other': 'אחר',
            };
            final p = total == 0 ? 0.0 : (v / total).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LtCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(labels[c]!, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(ils(v), style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(value: p.toDouble(), minHeight: 8, color: AppColors.accent, backgroundColor: AppColors.border),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: trip.isOwner
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: LtPrimaryButton(
                  label: 'הוסף הוצאה +',
                  onPressed: () => _add(context, ref),
                ),
              ),
            )
          : null,
    );
  }

  Widget _mini(String v, String l) {
    return Expanded(
      child: Column(
        children: [
          Text(v, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          Text(l, style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final title = TextEditingController();
    var cat = 'food';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('הוצאה חדשה', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(hintText: 'תיאור')),
              const SizedBox(height: 8),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'סכום ₪')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: cat,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'flights', child: Text('טיסות')),
                  DropdownMenuItem(value: 'hotel', child: Text('מלון')),
                  DropdownMenuItem(value: 'food', child: Text('אוכל')),
                  DropdownMenuItem(value: 'activities', child: Text('אטרקציות')),
                  DropdownMenuItem(value: 'transport', child: Text('תחבורה')),
                  DropdownMenuItem(value: 'other', child: Text('אחר')),
                ],
                onChanged: (v) => setS(() => cat = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              LtPrimaryButton(label: 'שמירה', onPressed: () => Navigator.pop(ctx, true)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ref.read(expensesRepositoryProvider)?.add(
            tripId: tripId,
            category: cat,
            amount: num.tryParse(amount.text) ?? 0,
            title: title.text,
          );
      ref.invalidate(expensesProvider(tripId));
    }
  }
}
