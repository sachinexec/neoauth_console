import 'package:flutter/material.dart';

/// Material 3 themes. Colours come from one seed so both modes keep
/// contrast-checked pairs (onPrimary on primary, etc.).
class AppTheme {
  static const seed = Color(0xFF3355CC);

  static ThemeData light() => _build(ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark() => _build(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      // 48dp minimum touch targets everywhere.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      chipTheme: base.chipTheme.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    );
  }
}

/// Semantic status colours that read well in both modes.
extension StatusColors on ColorScheme {
  Color get success => brightness == Brightness.light ? const Color(0xFF1B6E3A) : const Color(0xFF8FD8A4);
  Color get onSuccessContainer => brightness == Brightness.light ? const Color(0xFF0A3A1C) : const Color(0xFFCFF5D9);
  Color get successContainer => brightness == Brightness.light ? const Color(0xFFCFF5D9) : const Color(0xFF12512A);
  Color get warningContainer => brightness == Brightness.light ? const Color(0xFFFFE6B3) : const Color(0xFF5C4200);
  Color get onWarningContainer => brightness == Brightness.light ? const Color(0xFF3D2B00) : const Color(0xFFFFE6B3);
}

/// Breakpoints: phones get a bottom NavigationBar, wider screens a rail.
class Breakpoints {
  static const rail = 720.0;
  static const extendedRail = 1100.0;
  static bool useRail(BuildContext context) => MediaQuery.sizeOf(context).width >= rail;
}
