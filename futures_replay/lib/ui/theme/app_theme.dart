import 'package:flutter/material.dart';

/// 应用主题和颜色常量
class AppColors {
  // 主色调
  static const Color primary = Color(0xFF2962FF);
  static const Color primaryLight = Color(0xFF448AFF);
  static const Color accent = Color(0xFF00B0FF);

  // 背景色
  static const Color bgDark = Color(0xFF0A0E17);
  static const Color bgCard = Color(0xFF111827);
  static const Color bgCardLight = Color(0xFF1A2332);
  static const Color bgSurface = Color(0xFF1E293B);
  static const Color bgOverlay = Color(0xFF0F172A);

  // K线颜色
  static const Color bullish = Color(0xFFEF5350);  // 涨 - 红
  static const Color bearish = Color(0xFF26A69A);   // 跌 - 绿
  static const Color bullishBright = Color(0xFFFF5252);
  static const Color bearishBright = Color(0xFF00E676);

  // 文字颜色
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // 指标颜色
  static const Color ma5 = Color(0xFFFFEB3B);     // MA5 黄色
  static const Color ma10 = Color(0xFFE040FB);    // MA10 紫色
  static const Color ma20 = Color(0xFF00BCD4);    // MA20 青色
  static const Color bollUp = Color(0xFFFF5252);  // BOLL上轨
  static const Color bollMid = Color(0xFFFFEB3B); // BOLL中轨
  static const Color bollDn = Color(0xFF448AFF);  // BOLL下轨
  static const Color dif = Color(0xFFFFEB3B);     // DIF 黄色
  static const Color dea = Color(0xFF00BCD4);     // DEA 青色
  static const Color volMa5 = Color(0xFFFFEB3B);  // VOL MA5
  static const Color volMa10 = Color(0xFFE040FB); // VOL MA10

  // 边框色
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);
  static const Color grid = Color(0x1AFFFFFF);     // 网格线

  // 功能色
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF448AFF);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.border,
    );
  }
}
