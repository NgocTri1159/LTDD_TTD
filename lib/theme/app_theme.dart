
import 'package:material_ui/material_ui.dart';

/// Design System chính thức của QuizMaster.
class AppTheme {
  // ===========================================================================
  // FONT FAMILY
  // ===========================================================================
  static const String fontFamily = 'BeVietnamPro';
  static const String specialFontFamily = 'MontserratAlternates';

  // ===========================================================================
  // COLORS
  // ===========================================================================
  static const Color primary = Color(0xFF5B5FEF);
  static const Color primaryLight = Color(0xFF8588F5);
  static const Color primaryDark = Color(0xFF4549D5);
  static const Color primaryContainer = Color(0xFFE8E9FF);

  static const Color background = Color(0xFFF5F7FF);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE6E9F5);

  static const Color textPrimary = Color(0xFF252A45);
  static const Color textSecondary = Color(0xFF69708A);
  static const Color textMuted = Color(0xFF9AA0B5);
  static const Color textWhite = Colors.white;

  // Màu tương tác
  static const Color interact = Color(0xFFFFB84D);
  static const Color interactLight = Color(0xFFFFE7BF);

  // Màu trạng thái
  static const Color success = Color(0xFF2EAD72);
  static const Color successContainer = Color(0xFFE5F7EE);

  static const Color warning = Color(0xFFFFB84D);
  static const Color warningContainer = Color(0xFFFFF4DF);

  static const Color error = Color(0xFFEF5350);
  static const Color errorContainer = Color(0xFFFFEBEE);

  static const Color info = Color(0xFF399BEF);
  static const Color infoContainer = Color(0xFFE7F2FF);

  // ===========================================================================
  // GRADIENT
  // ===========================================================================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B5FEF), Color(0xFF8588F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFB84D), Color(0xFFFFD27A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF399BEF), Color(0xFF75C7FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===========================================================================
  // BORDER RADIUS
  // ===========================================================================
  static const double radiusSmall = 8;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
  static const double radiusXLarge = 28;

  static final BorderRadius borderRadiusSmall =
      BorderRadius.circular(radiusSmall);

  static final BorderRadius borderRadiusMedium =
      BorderRadius.circular(radiusMedium);

  static final BorderRadius borderRadiusLarge =
      BorderRadius.circular(radiusLarge);

  static final BorderRadius borderRadiusXLarge =
      BorderRadius.circular(radiusXLarge);

  // ===========================================================================
  // SHADOWS
  // ===========================================================================
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primary.withAlpha(15),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: primary.withAlpha(35),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  // ===========================================================================
  // TYPOGRAPHY
  // ===========================================================================

  // Title: Bold 30px
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  // Subtitle: SemiBold 24px
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  // Tiêu đề nội dung
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // Question: SemiBold 20px
  static const TextStyle question = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );

  // Answer: Medium 16px
  static const TextStyle answer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.5,
  );

  // Text: Regular 16px
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.4,
  );

  // Button: SemiBold 16px
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textWhite,
  );

  static const TextStyle labelLarge = button;

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  // PIN: Montserrat Alternates
  static const TextStyle pinCode = TextStyle(
    fontFamily: specialFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 4,
  );

  // Ranking: Montserrat Alternates
  static const TextStyle ranking = TextStyle(
    fontFamily: specialFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  // ===========================================================================
  // THEME DATA
  // ===========================================================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: textWhite,
        primaryContainer: primaryContainer,
        onPrimaryContainer: textPrimary,
        secondary: interact,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: textWhite,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMedium,
          side: const BorderSide(color: cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusMedium,
          ),
          textStyle: button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusMedium,
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: bodyMedium.copyWith(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 1.8),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusLarge,
        ),
        titleTextStyle: titleLarge,
        contentTextStyle: bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: bodyMedium.copyWith(color: textWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusSmall,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }

          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }

          return const IconThemeData(color: textMuted, size: 24);
        }),
      ),
    );
  }
}
