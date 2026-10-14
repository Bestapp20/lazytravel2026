import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile?.displayName ?? 'אורח';
    final hero = trips.maybeWhen(
      data: (list) => list.isEmpty ? null : list.first,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Image.asset(AppAssets.logo, width: 36, height: 36),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(tripsProvider),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _header(context, name),
                    if (hero != null) _hero(context, hero) else _emptyHero(context),
                    _quickActions(context, hero?.id),
                    LtSectionHeader(
                      title: 'הטיולים שלי',
                      action: 'הכל',
                      onAction: () {},
                    ),
                    trips.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('$e', style: GoogleFonts.notoSansHebrew()),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'עוד אין טיולים. לחצו על תכנן ונתחיל.',
                              style: GoogleFonts.notoSansHebrew(color: AppColors.textBody),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 214,
                          child: ListView.separated(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 14),
                            itemBuilder: (_, i) => _tripCard(context, list[i]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const LtSectionHeader(title: 'לאן בא לך לברוח? ✨'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            'AI בחר עבורך בהתאם לטעמך',
                            style: GoogleFonts.notoSansHebrew(
                              fontSize: 12,
                              color: AppColors.textBody,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: const BoxDecoration(
                              gradient: AppColors.ctaSimple,
                              borderRadius: BorderRadius.all(Radius.circular(100)),
                            ),
                            child: Text(
                              'מותאם אישית',
                              style: GoogleFonts.notoSansHebrew(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 196,
                      child: ListView(
                        reverse: true,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _suggest(context, AppAssets.lisbon, 'ליסבון 🇵🇹', 'מוסיקה, אוכל ונופים', 'מ-₪2,400'),
                          const SizedBox(width: 14),
                          _suggest(context, AppAssets.kyoto, 'קיוטו 🇯🇵', 'טמפלים, גנים ותרבות', 'מ-₪4,100'),
                          const SizedBox(width: 14),
                          _suggest(context, AppAssets.amalfi, 'אמאלפי 🇮🇹', 'חוף, פיצה ולה דולצ\'ה ויטה', 'מ-₪3,200'),
                          const SizedBox(width: 14),
                          _suggest(context, AppAssets.bali, 'באלי 🇮🇩', 'טבע, ספא ושלווה', 'מ-₪2,900'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.home),
    );
  }

  Widget _header(BuildContext context, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2.5),
              ),
              child: ClipOval(child: Image.asset(AppAssets.avatarEdward, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ברוך הבא חזרה',
                style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody),
              ),
              Text(
                'שלום, $name 👋',
                style: GoogleFonts.notoSansHebrew(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          LtIconCircle(icon: Icons.search, onTap: () => context.go('/explore')),
          const SizedBox(width: 10),
          const LtIconCircle(icon: Icons.notifications_none),
        ],
      ),
    );
  }

  Widget _emptyHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: LtCard(
        onTap: () => context.push('/wizard/step1'),
        child: Column(
          children: [
            Text(
              'הטיול הראשון שלכם מחכה',
              style: GoogleFonts.notoSansHebrew(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ספרו לאן נוסעים — וה‑AI יבנה מסלול סביב המלון.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansHebrew(color: AppColors.textBody),
            ),
            const SizedBox(height: 14),
            LtPrimaryButton(
              label: 'תכנן טיול',
              icon: Icons.auto_awesome,
              onPressed: () => context.push('/wizard/step1'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, Trip trip) {
    final left = daysUntil(trip.startDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GestureDetector(
        onTap: () => context.push('/trips/${trip.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 228,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(AppAssets.forDestination(trip.city), fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      trip.status == 'done' ? 'הושלם' : 'טיול פעיל',
                      style: GoogleFonts.notoSansHebrew(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 18,
                  right: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.city} ${trip.destinations.firstOrNull?.flag ?? ''}',
                        style: GoogleFonts.notoSansHebrew(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${heDateRange(trip.startDate, trip.endDate)}   ${left > 0 ? '⏳ $left ימים נותרו' : ''}',
                        style: GoogleFonts.notoSansHebrew(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      LtPrimaryButton(
                        label: 'המשך לתכנן',
                        icon: Icons.arrow_back,
                        onPressed: () => context.push('/trips/${trip.id}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, String? tripId) {
    final actions = [
      (Icons.favorite_border, 'מועדפים', () => context.go('/explore')),
      (Icons.account_balance_wallet_outlined, 'תקציב', () {
        if (tripId != null) context.push('/trips/$tripId/budget');
      }),
      (Icons.route_outlined, 'מסלולים', () {
        if (tripId != null) context.push('/trips/$tripId');
      }),
      (Icons.flight_outlined, 'טיסות', () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הזמנת טיסות תגיע ב‑v2')),
        );
      }),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: actions
            .map(
              (a) => Expanded(
                child: GestureDetector(
                  onTap: a.$3,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.sectionTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Icon(a.$1, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.$2,
                        style: GoogleFonts.notoSansHebrew(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tripCard(BuildContext context, Trip trip) {
    final done = trip.status == 'done';
    return GestureDetector(
      onTap: () => context.push('/trips/${trip.id}'),
      child: Container(
        width: 162,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                AppAssets.forDestination(trip.city),
                width: 162,
                height: 98,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.city,
                    style: GoogleFonts.notoSansHebrew(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    heDateRange(trip.startDate, trip.endDate),
                    style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      done ? 'הושלם ✓' : (trip.isOwner ? 'בתכנון' : 'צפייה'),
                      style: GoogleFonts.notoSansHebrew(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: done ? AppColors.primaryDark : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggest(BuildContext context, String img, String dest, String desc, String price) {
    return GestureDetector(
      onTap: () => context.push('/wizard/step1'),
      child: Container(
        width: 142,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(img, width: 142, height: 94, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dest,
                    style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    desc,
                    maxLines: 2,
                    style: GoogleFonts.notoSansHebrew(fontSize: 11, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: GoogleFonts.notoSansHebrew(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
