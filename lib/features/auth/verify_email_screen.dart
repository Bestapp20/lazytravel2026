import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

/// Shown when sign-up/sign-in succeeded but the e-mail address is not confirmed yet.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldown = 60;
  int _left = 0;
  bool _busy = false;
  String? _msg;
  bool _err = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _left = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final c = ref.read(supabaseProvider);
    if (c == null || widget.email.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await c.auth.resend(type: OtpType.signup, email: widget.email);
      _msg = 'שלחנו שוב. בדקו גם בתיבת הספאם.';
      _err = false;
      _startCooldown();
    } on AuthException catch (e) {
      _err = true;
      _msg = (e.statusCode == '429' || e.code == 'over_email_send_rate_limit')
          ? 'נשלחו יותר מדי הודעות. נסו שוב בעוד כמה דקות.'
          : 'לא הצלחנו לשלוח. נסו שוב מאוחר יותר.';
      _startCooldown();
    } catch (_) {
      _err = true;
      _msg = 'אין חיבור. נסו שוב.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.go('/login'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 72, color: AppColors.accent),
          const SizedBox(height: 18),
          Text('צריך לאשר את כתובת המייל',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansHebrew(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 10),
          Text('שלחנו קישור אישור אל',
              textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
          if (widget.email.isNotEmpty)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(widget.email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansHebrew(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            ),
          const SizedBox(height: 8),
          Text('לחצו על הקישור במייל, ואז חזרו לכאן והתחברו.',
              textAlign: TextAlign.center, style: GoogleFonts.notoSansHebrew(color: AppColors.textBody)),
          const SizedBox(height: 28),
          LtPrimaryButton(
            label: _left > 0 ? 'שליחה חוזרת בעוד $_left שנ׳' : (_busy ? 'שולח...' : 'שלח שוב'),
            icon: Icons.refresh,
            onPressed: _busy || _left > 0 || widget.email.isEmpty ? null : _resend,
          ),
          const SizedBox(height: 12),
          LtSecondaryButton(label: 'חזרה להתחברות', icon: Icons.login, onPressed: () => context.go('/login')),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_msg!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansHebrew(
                      fontWeight: FontWeight.w700, color: _err ? AppColors.danger : AppColors.success)),
            ),
        ],
      ),
    );
  }
}
