import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class AiGenerationScreen extends ConsumerStatefulWidget {
  const AiGenerationScreen({super.key});

  @override
  ConsumerState<AiGenerationScreen> createState() => _AiGenerationScreenState();
}

class _AiGenerationScreenState extends ConsumerState<AiGenerationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;
  String? _error;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final repo = ref.read(tripsRepositoryProvider);
    final payload = ref.read(wizardProvider).toGeneratePayload();
    if (repo == null) {
      setState(() => _error = 'Supabase לא מוגדר');
      return;
    }
    try {
      setState(() => _step = 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      setState(() => _step = 2);
      final id = await repo.generateRoute(payload);
      if (!mounted) return;
      ref.invalidate(tripsProvider);
      context.go('/trips/$id');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(wizardProvider).primary?.city ?? 'היעד';
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppAssets.logo, width: 36, height: 36),
                const SizedBox(width: 8),
                Text('lazy travel', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ],
            ),
            const SizedBox(height: 12),
            Text('ה‑AI בונה את הטיול שלכם ✨', textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('כמה שניות וקיבלתם תוכנית מושלמת', textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.border)),
                child: Text(city, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
              ),
            ),
            AnimatedBuilder(
              animation: _float,
              builder: (_, _) => Transform.translate(
                offset: Offset(0, -8 * _float.value),
                child: Image.asset(AppAssets.globe, height: 160),
              ),
            ),
            LtCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _row('מכיר את $city...', 'אוסף מידע על האזור', _step >= 1),
                  _row('מוצא מקומות שמתאימים לכם...', 'מסנן לפי העדפות', _step >= 1),
                  _row('מסדר את המסלול לפי מרחקים...', 'אופטימיזציה סביב המלון', _step >= 2),
                  _row('בודק מסעדות ואטרקציות...', 'Google Places + LLM', false),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: GoogleFonts.notoSansHebrew(color: AppColors.danger)),
              const SizedBox(height: 12),
              LtSecondaryButton(label: 'חזרה לעריכה', onPressed: () => context.go('/wizard/step3')),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Text(
                'ידעת? המסלול נבנה סביב המלון כנקודת התחלה וסיום לכל יום, לפי הדירוג שנתתם לתחומי העניין.',
                style: GoogleFonts.notoSansHebrew(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String t, String s, bool done) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: done ? AppColors.success.withValues(alpha: 0.15) : AppColors.sectionTint,
        child: Icon(done ? Icons.check : Icons.hourglass_empty, size: 16, color: done ? AppColors.success : AppColors.textBody),
      ),
      title: Text(t, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(s, style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody)),
    );
  }
}
