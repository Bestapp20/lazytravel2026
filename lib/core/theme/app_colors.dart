import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF1B4F5C);
  static const Color accent = Color(0xFF2DBFAD);
  static const Color accentLight = Color(0xFF3DD6C6);
  static const Color bgLight = Color(0xFFF0FAFA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF0D2B35);
  static const Color textBody = Color(0xFF4A7A87);
  static const Color border = Color(0xFFC8E8E8);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color sectionTint = Color(0xFFE8F6F6);
  static const Color navInactive = Color(0xFF9CA3AF);
  static const Color danger = Color(0xFFFF6B4A);

  static const LinearGradient cta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent, primaryDark],
  );

  static const LinearGradient ctaSimple = LinearGradient(
    colors: [accent, primaryDark],
  );
}
