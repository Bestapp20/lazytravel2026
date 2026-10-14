import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class WizardStep3Screen extends ConsumerStatefulWidget {
  const WizardStep3Screen({super.key});

  @override
  ConsumerState<WizardStep3Screen> createState() => _WizardStep3ScreenState();
}

class _WizardStep3ScreenState extends ConsumerState<WizardStep3Screen> {
  final _hotel = TextEditingController();
  List<PlaceSuggestion> _hotels = [];
  Timer? _t;

  @override
  void dispose() {
    _hotel.dispose();
    _t?.cancel();
    super.dispose();
  }

  void _searchHotel(String q) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 320), () async {
      final w = ref.read(wizardProvider);
      final repo = ref.read(placesRepositoryProvider);
      if (repo == null || q.trim().length < 2) return;
      final city = w.primary?.city ?? '';
      final r = await repo.search('lodging $q $city', lat: w.primary?.lat, lng: w.primary?.lng);
      if (mounted) setState(() => _hotels = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(wizardProvider);
    final n = ref.read(wizardProvider.notifier);
    final selected = w.interests.values.where((v) => v > 0).length;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Image.asset(AppAssets.logo, width: 32, height: 32),
                  const SizedBox(width: 8),
                  Text('lazy travel', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  LtIconCircle(icon: Icons.chevron_right, onTap: () => context.pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('שלב 3 מתוך 3', style: GoogleFonts.notoSansHebrew(color: AppColors.accent, fontWeight: FontWeight.w600)),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                    child: LinearProgressIndicator(value: 1, minHeight: 4, color: AppColors.accent, backgroundColor: AppColors.border),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                children: [
                  Text('מה אתם אוהבים\nלעשות? 🎭', style: GoogleFonts.notoSansHebrew(fontSize: 28, fontWeight: FontWeight.w900, height: 1.25)),
                  const SizedBox(height: 6),
                  Text('בחרו, וליחצו שוב כדי לדרג 1–3', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kInterests.map((i) {
                      final weight = w.interests[i.id] ?? 0;
                      final on = weight > 0;
                      return GestureDetector(
                        onTap: () {
                          final next = on ? (weight >= 3 ? 0 : weight + 1) : 2;
                          n.setInterest(i.id, next);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: on ? AppColors.ctaSimple : null,
                            color: on ? null : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: on ? Colors.transparent : AppColors.border, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(i.emoji),
                              const SizedBox(width: 6),
                              Text(i.label, style: GoogleFonts.notoSansHebrew(color: on ? Colors.white : AppColors.textBody, fontWeight: FontWeight.w500)),
                              if (on) ...[
                                const SizedBox(width: 6),
                                Text('$weight', style: GoogleFonts.notoSansHebrew(color: Colors.white, fontWeight: FontWeight.w800)),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('$selected תחומי עניין נבחרו', style: GoogleFonts.notoSansHebrew(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => n.setKosher(!w.kosher),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: w.kosher ? AppColors.accent.withValues(alpha: 0.07) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: w.kosher ? AppColors.accent : AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Text('🕍', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('שומר כשרות', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('נסנן מסעדות ואטרקציות בהתאם', style: GoogleFonts.notoSansHebrew(fontSize: 13, color: AppColors.textBody)),
                              ],
                            ),
                          ),
                          Switch(value: w.kosher, activeThumbColor: AppColors.accent, onChanged: n.setKosher),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('מלון כנקודת התחלה/סיום לכל יום', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hotel,
                    onChanged: _searchHotel,
                    decoration: InputDecoration(
                      hintText: w.hotel?.name ?? 'חפשו מלון, או השאירו ריק',
                      prefixIcon: const Icon(Icons.hotel_outlined, color: AppColors.accent),
                    ),
                  ),
                  if (w.hotel != null)
                    TextButton(
                      onPressed: () => n.setHotel(null),
                      child: Text('בלי מלון', style: GoogleFonts.notoSansHebrew(color: AppColors.accent)),
                    ),
                  ..._hotels.map(
                    (h) => ListTile(
                      onTap: () {
                        n.setHotel(HotelInfo(name: h.name, placeId: h.placeId, lat: h.lat, lng: h.lng, address: h.address));
                        _hotel.text = h.name;
                        setState(() => _hotels = []);
                      },
                      title: Text(h.name, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600)),
                      subtitle: Text(h.address ?? '', style: GoogleFonts.notoSansHebrew(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: LtPrimaryButton(
                label: 'תבנה לי את הטיול',
                leading: const Text('✨', style: TextStyle(fontSize: 16)),
                onPressed: selected == 0 ? null : () => context.push('/wizard/generating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
