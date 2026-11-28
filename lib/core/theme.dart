import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFFF5F7FF); // #F5F7FF
  static const Color base = Color(0xFF5B5FEF);       // #5B5FEF (Màu chủ đạo)
  static const Color text = Color(0xFF252A45);       // #252A45 (Màu chữ chính)
  static const Color interact = Color(0xFFFFB84D);   // #FFB84D (Màu điểm nhấn/tương tác)
}

class AppTextStyles {
  // Font chính: Be Vietnam Pro
  static TextStyle title = GoogleFonts.beVietnamPro(
    fontSize: 30,
    fontWeight: FontWeight.bold, // 700
    color: AppColors.text,
  );

  static TextStyle subTitle = GoogleFonts.beVietnamPro(
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.text,
  );

  static TextStyle question = GoogleFonts.beVietnamPro(
    fontSize: 20,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.text,
  );

  static TextStyle answer = GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.text,
  );

  static TextStyle text = GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.text,
  );

  static TextStyle button = GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    color: Colors.white,
  );

  // Font riêng cho mã PIN và Thứ hạng: Montserrat Alternates
  static TextStyle pinAndRank({double fontSize = 24, Color? color}) {
    return GoogleFonts.montserratAlternates(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color ?? AppColors.base,
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.base,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.base,
        primary: AppColors.base,
        secondary: AppColors.interact,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.beVietnamProTextTheme().apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.base,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: AppTextStyles.subTitle.copyWith(color: Colors.white, fontSize: 20),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.interact,
        foregroundColor: AppColors.text,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.base,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}