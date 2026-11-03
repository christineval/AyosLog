import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  /// Neutral calendar colors follow the active light/dark theme.
  static ThemeData datePicker(ThemeData theme) {
    final colors = theme.colorScheme;
    final foreground = colors.onSurface;
    final surface = colors.surface;
    return theme.copyWith(
      colorScheme: colors.copyWith(
        primary: foreground,
        onPrimary: surface,
        primaryContainer: theme.inputDecorationTheme.fillColor,
        onPrimaryContainer: foreground,
        surfaceContainerHigh: surface,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: surface,
        headerForegroundColor: foreground,
        dividerColor: theme.dividerColor,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: foreground, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: foreground,
        selectionColor: foreground.withValues(alpha: .2),
        selectionHandleColor: foreground,
      ),
    );
  }

  static ThemeData _build(bool dark) {
    final bg = dark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final elevated = dark ? AppColors.darkElevated : AppColors.lightElevated;
    final text = dark ? AppColors.darkText : AppColors.lightText;
    final muted = dark ? AppColors.darkMuted : AppColors.lightMuted;
    final accent = dark ? AppColors.brandDark : AppColors.brand;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final scheme = ColorScheme.fromSeed(
            seedColor: accent,
            brightness: dark ? Brightness.dark : Brightness.light)
        .copyWith(
            primary: accent,
            onPrimary: Colors.white,
            surface: surface,
            onSurface: text,
            error: dark ? AppColors.errorDark : AppColors.error);
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          centerTitle: false),
      textTheme: TextTheme(
        headlineLarge: AppTypography.heading.copyWith(color: text),
        titleLarge: AppTypography.section.copyWith(color: text),
        titleMedium: AppTypography.cardTitle.copyWith(color: text),
        bodyMedium: AppTypography.body.copyWith(color: text),
        bodySmall: AppTypography.caption.copyWith(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              foregroundColor: accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button)),
              side: BorderSide(color: accent))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: elevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: BorderSide(color: accent, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: BorderSide(color: scheme.error)),
          hintStyle: TextStyle(color: muted)),
      cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              side: BorderSide(color: border))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: accent.withValues(alpha: .16),
          labelTextStyle:
              WidgetStatePropertyAll(TextStyle(color: text, fontSize: 11))),
      chipTheme: ChipThemeData(
          backgroundColor: elevated,
          selectedColor: accent.withValues(alpha: .18),
          shape: const StadiumBorder(),
          side: BorderSide.none),
      dividerTheme: DividerThemeData(color: border),
    );
  }
}
