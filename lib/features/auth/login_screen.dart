import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lt_widgets.dart';
import '../../data/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn, {String? ok}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await fn();
      if (ok != null && mounted) setState(() => _message = ok);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_confirmed' || e.message.toLowerCase().contains('not confirmed')) {
        context.go('/verify-email', extra: _email.text.trim());
      } else if (e.code == 'invalid_credentials' || e.message.toLowerCase().contains('invalid login')) {
        setState(() => _message = 'מייל או סיסמה שגויים');
      } else if (e.code == 'user_already_exists') {
        setState(() => _message = 'כתובת המייל כבר רשומה. נסו להתחבר.');
      } else if (e.statusCode == '429' || (e.code ?? '').contains('rate_limit')) {
        setState(() => _message = 'יותר מדי ניסיונות. נסו שוב בעוד כמה דקות.');
      } else {
        setState(() => _message = 'ההתחברות נכשלה: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: LtIconCircle(icon: Icons.arrow_forward, onTap: () => context.go('/welcome')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Center(child: Image.asset(AppAssets.logo, width: 56, height: 56)),
          const SizedBox(height: 12),
          Text(
            _register ? 'יצירת חשבון' : 'ברוכים הבאים חזרה',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansHebrew(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'התחברו באימייל וסיסמה, או קבלו קישור קסם למייל.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansHebrew(color: AppColors.textBody),
          ),
          const SizedBox(height: 28),
          if (_register)
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'שם מלא'),
            ),
          if (_register) const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'אימייל'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'סיסמה'),
          ),
          const SizedBox(height: 20),
          LtPrimaryButton(
            label: _busy ? 'רגע...' : (_register ? 'הרשמה' : 'התחברות'),
            onPressed: _busy || auth == null
                ? null
                : () => _run(() async {
                      if (_register) {
                        await auth.signUp(_email.text.trim(), _password.text, _name.text.trim());
                        if (auth.session == null) {
                          if (mounted) context.go('/verify-email', extra: _email.text.trim());
                          return;
                        }
                      } else {
                        await auth.signInWithPassword(_email.text.trim(), _password.text);
                      }
                      await auth.acceptInvites();
                    }),
          ),
          const SizedBox(height: 12),
          LtSecondaryButton(
            label: 'שלחו לי קישור קסם',
            icon: Icons.auto_awesome,
            onPressed: _busy || auth == null
                ? null
                : () => _run(
                      () => auth.sendMagicLink(_email.text.trim()),
                      ok: 'שלחנו קישור למייל. בדקו גם בספאם.',
                    ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => setState(() => _register = !_register),
            child: Text(
              _register ? 'יש לי כבר חשבון' : 'אין לי חשבון עדיין',
              style: GoogleFonts.notoSansHebrew(
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansHebrew(color: AppColors.primaryDark),
              ),
            ),
        ],
      ),
    );
  }
}
