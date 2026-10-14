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

class WizardStep1Screen extends ConsumerStatefulWidget {
  const WizardStep1Screen({super.key});

  @override
  ConsumerState<WizardStep1Screen> createState() => _WizardStep1ScreenState();
}

class _WizardStep1ScreenState extends ConsumerState<WizardStep1Screen> {
  final _search = TextEditingController();
  List<PlaceSuggestion> _hints = [];
  Timer? _debounce;
  bool _optional = false;
  final _flight = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _flight.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      final repo = ref.read(placesRepositoryProvider);
      if (repo == null || q.trim().length < 2) {
        setState(() => _hints = []);
        return;
      }
      try {
        final r = await repo.autocomplete(q);
        if (mounted) setState(() => _hints = r);
      } catch (_) {
        if (mounted) setState(() => _hints = []);
      }
    });
  }

  Future<void> _pickHint(PlaceSuggestion s) async {
    final details = await ref.read(placesRepositoryProvider)?.details(s.placeId);
    final d = Destination(
      city: details?.name ?? s.name,
      country: details?.subtitle ?? s.subtitle,
      placeId: s.placeId,
      lat: details?.lat,
      lng: details?.lng,
    );
    ref.read(wizardProvider.notifier).addDestination(d);
    _search.clear();
    setState(() => _hints = []);
  }

  Future<void> _pickDate({required bool start}) async {
    final w = ref.read(wizardProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 800)),
      initialDate: start ? (w.startDate ?? now) : (w.endDate ?? w.startDate ?? now),
      locale: const Locale('he'),
    );
    if (picked == null) return;
    if (start) {
      ref.read(wizardProvider.notifier).setDates(picked, w.endDate);
    } else {
      ref.read(wizardProvider.notifier).setDates(w.startDate, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(wizardProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
                  const Spacer(),
                  Column(
                    children: [
                      Text('1 מתוך 3', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _dot(true),
                        const SizedBox(width: 6),
                        _dot(false),
                        const SizedBox(width: 6),
                        _dot(false),
                      ]),
                    ],
                  ),
                  const Spacer(),
                  LtIconCircle(icon: Icons.close, onTap: () => context.go('/home')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('לאן נוסעים? 🌍', style: GoogleFonts.notoSansHebrew(fontSize: 30, fontWeight: FontWeight.w900)),
                  Text('ניתן להוסיף מספר יעדים', style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
                  const SizedBox(height: 16),
                  LtCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: TextField(
                      controller: _search,
                      onChanged: _onQuery,
                      decoration: InputDecoration(
                        hintText: 'חפש עיר או מדינה...',
                        border: InputBorder.none,
                        filled: false,
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.accent),
                      ),
                    ),
                  ),
                  if (_hints.isNotEmpty)
                    LtCard(
                      child: Column(
                        children: _hints
                            .map(
                              (h) => ListTile(
                                onTap: () => _pickHint(h),
                                title: Text(h.name, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
                                subtitle: Text(h.subtitle ?? '', style: GoogleFonts.notoSansHebrew(fontSize: 12)),
                                trailing: const Icon(Icons.chevron_left, color: AppColors.border),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('יעדים שנבחרו', style: GoogleFonts.notoSansHebrew(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                  const SizedBox(height: 8),
                  ...w.destinations.asMap().entries.map((e) {
                    final i = e.key;
                    final d = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LtCard(
                        padding: EdgeInsets.zero,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                              child: Image.asset(AppAssets.forDestination(d.city), width: 100, height: 88, fit: BoxFit.cover),
                            ),
                            Expanded(
                              child: ListTile(
                                title: Text(d.city, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800)),
                                subtitle: Text(d.country ?? '', style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
                                trailing: IconButton(
                                  onPressed: () => ref.read(wizardProvider.notifier).removeDestination(i),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => _search.text.isEmpty ? null : _onQuery(_search.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text('הוסף יעד נוסף +', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600, color: AppColors.textBody)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('תאריכי הטיול', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dateBtn('תאריך הגעה', w.startDate, () => _pickDate(start: true)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dateBtn('תאריך עזיבה', w.endDate, () => _pickDate(start: false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LtCard(
                    onTap: () => setState(() => _optional = !_optional),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('פרטי טיסה ומלון', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600)),
                            ),
                            Text('אופציונלי', style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.accent)),
                          ],
                        ),
                        if (_optional) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _flight,
                            onChanged: (v) => ref.read(wizardProvider.notifier).setFlightRef(v),
                            decoration: const InputDecoration(hintText: '✈️ מספר טיסה / חברה'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: LtPrimaryButton(
                label: 'המשך',
                icon: Icons.arrow_back,
                onPressed: w.destinations.isEmpty || w.startDate == null || w.endDate == null
                    ? null
                    : () => context.push('/wizard/step2'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool on) => Container(
        height: 6,
        width: on ? 24 : 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: on ? AppColors.accent : AppColors.border,
        ),
      );

  Widget _dateBtn(String label, DateTime? v, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: v != null ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.notoSansHebrew(fontSize: 10, color: AppColors.textBody)),
            Text(
              v == null ? 'בחר תאריך' : '${v.day}/${v.month}',
              style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, color: v == null ? const Color(0xFFA8C4CC) : AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}
