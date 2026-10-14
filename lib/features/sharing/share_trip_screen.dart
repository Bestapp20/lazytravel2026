import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class ShareTripScreen extends ConsumerStatefulWidget {
  const ShareTripScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ShareTripScreen> createState() => _ShareTripScreenState();
}

class _ShareTripScreenState extends ConsumerState<ShareTripScreen> {
  final _email = TextEditingController();
  String? _msg;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(tripsRepositoryProvider)?.invite(widget.tripId, _email.text.trim());
      ref.invalidate(membersProvider(widget.tripId));
      setState(() => _msg = 'ההזמנה נשלחה. אם יש להם חשבון — הם יראו את הטיול כצופים.');
      _email.clear();
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).valueOrNull;
    final members = ref.watch(membersProvider(widget.tripId)).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('שיתוף עם המשפחה'),
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'הזמינו באימייל. בני המשפחה יקבלו גישת צפייה בלבד — בלי לערוך את המסלול.',
            style: GoogleFonts.notoSansHebrew(color: AppColors.textBody, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (trip?.isOwner == true) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'אימייל של אמא / אבא / אח'),
            ),
            const SizedBox(height: 12),
            LtPrimaryButton(label: _busy ? 'שולח...' : 'שלח הזמנה', onPressed: _busy ? null : _invite),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_msg!, style: GoogleFonts.notoSansHebrew(color: AppColors.primaryDark)),
              ),
            const SizedBox(height: 24),
          ],
          Text('חברי הטיול', style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          ...members.map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.sectionTint,
                child: Text(m.role == 'owner' ? '★' : '👁'),
              ),
              title: Text(m.displayName ?? m.invitedEmail ?? m.userId, style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w700)),
              subtitle: Text(m.role == 'owner' ? 'בעלים' : 'צופה', style: GoogleFonts.notoSansHebrew(fontSize: 12, color: AppColors.textBody)),
            ),
          ),
        ],
      ),
    );
  }
}
