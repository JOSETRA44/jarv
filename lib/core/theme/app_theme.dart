import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkBackground,
      secondaryContainer: AppColors.darkSecondaryContainer,
      onSecondaryContainer: AppColors.darkSecondary,
      error: AppColors.darkError,
      onError: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      surfaceContainerHighest: AppColors.darkCard,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutline,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: AppColors.darkOnSurface,
      onInverseSurface: AppColors.darkSurface,
      inversePrimary: AppColors.lightPrimary,
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData get light {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.lightSecondaryContainer,
      onSecondaryContainer: AppColors.lightSecondary,
      error: AppColors.lightError,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      surfaceContainerHighest: AppColors.lightCard,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutline,
      shadow: Colors.black26,
      scrim: Colors.black38,
      inverseSurface: AppColors.lightOnSurface,
      onInverseSurface: AppColors.lightSurface,
      inversePrimary: AppColors.darkPrimary,
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final bg = isLight ? AppColors.lightBackground : AppColors.darkBackground;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: colorScheme.onSurface),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: colorScheme.onSurface),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: colorScheme.onSurface),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: colorScheme.onSurface),
        titleSmall: AppTextStyles.titleSmall.copyWith(color: colorScheme.onSurface),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: colorScheme.onSurface),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
        ),
        labelSmall: AppTextStyles.labelSmall.copyWith(
          color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? AppColors.lightSurface : AppColors.darkSurface,
        indicatorColor: colorScheme.primary.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 22);
          }
          return IconThemeData(
            color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.labelSmall.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTextStyles.labelSmall.copyWith(
            color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
          );
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: isLight ? AppColors.lightMuted : AppColors.darkMuted,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: (isLight ? AppColors.lightMuted : AppColors.darkMuted).withOpacity(0.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTextStyles.titleSmall,
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTextStyles.titleSmall,
          minimumSize: const Size(0, 48),
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight ? AppColors.lightCard : AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isLight ? AppColors.lightOutline : AppColors.darkOutline,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: AppTextStyles.labelSmall.copyWith(color: colorScheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
