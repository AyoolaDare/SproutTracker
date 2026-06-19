import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const sage = Color(0xFF8B9D83);
  static const moss = Color(0xFF606C38);
  static const clay = Color(0xFFB08B6E);
  static const terracotta = Color(0xFFC66B3D);
  static const ochre = Color(0xFFC08E3A);
  static const sand = Color(0xFFE8DCC7);
  static const oat = Color(0xFFD4B895);
  static const ink = Color(0xFF23271A);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: moss,
      brightness: Brightness.light,
      primary: moss,
      secondary: clay,
      tertiary: terracotta,
      surface: sand,
    );

    return _buildTheme(scheme).copyWith(
      scaffoldBackgroundColor: sand,
      extensions: const [SproutPalette.light],
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: Brightness.dark,
      primary: sage,
      secondary: clay,
      tertiary: terracotta,
      surface: Color(0xFF202417),
    );

    return _buildTheme(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF171A11),
      extensions: const [SproutPalette.dark],
    );
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final body = GoogleFonts.epilogueTextTheme();
    final display = GoogleFonts.frauncesTextTheme();
    final textTheme = body.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontSize: 56, height: .96, fontWeight: FontWeight.w800),
      displayMedium: display.displayMedium?.copyWith(fontSize: 44, height: 1, fontWeight: FontWeight.w800),
      displaySmall: display.displaySmall?.copyWith(fontSize: 34, height: 1.04, fontWeight: FontWeight.w800),
      headlineLarge: display.headlineLarge?.copyWith(fontSize: 34, height: 1.06, fontWeight: FontWeight.w800),
      headlineMedium: display.headlineMedium?.copyWith(fontSize: 28, height: 1.08, fontWeight: FontWeight.w800),
      headlineSmall: display.headlineSmall?.copyWith(fontSize: 24, height: 1.1, fontWeight: FontWeight.w800),
      titleLarge: body.titleLarge?.copyWith(fontSize: 20, height: 1.2, fontWeight: FontWeight.w800),
      titleMedium: body.titleMedium?.copyWith(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700),
      titleSmall: body.titleSmall?.copyWith(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700),
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.35),
      labelLarge: body.labelLarge?.copyWith(fontSize: 13, height: 1.1, fontWeight: FontWeight.w800),
      labelMedium: body.labelMedium?.copyWith(fontSize: 12, height: 1.1, fontWeight: FontWeight.w700),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface.withValues(alpha: .7),
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SproutPalette extends ThemeExtension<SproutPalette> {
  const SproutPalette({
    required this.success,
    required this.warning,
    required this.cashIn,
    required this.cashOut,
    required this.paper,
  });

  final Color success;
  final Color warning;
  final Color cashIn;
  final Color cashOut;
  final Color paper;

  static const light = SproutPalette(
    success: AppTheme.moss,
    warning: AppTheme.ochre,
    cashIn: AppTheme.sage,
    cashOut: AppTheme.terracotta,
    paper: AppTheme.sand,
  );

  static const dark = SproutPalette(
    success: AppTheme.sage,
    warning: AppTheme.ochre,
    cashIn: Color(0xFFA8BE98),
    cashOut: Color(0xFFE29064),
    paper: Color(0xFF242817),
  );

  @override
  SproutPalette copyWith({
    Color? success,
    Color? warning,
    Color? cashIn,
    Color? cashOut,
    Color? paper,
  }) {
    return SproutPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      cashIn: cashIn ?? this.cashIn,
      cashOut: cashOut ?? this.cashOut,
      paper: paper ?? this.paper,
    );
  }

  @override
  SproutPalette lerp(ThemeExtension<SproutPalette>? other, double t) {
    if (other is! SproutPalette) return this;
    return SproutPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      cashIn: Color.lerp(cashIn, other.cashIn, t)!,
      cashOut: Color.lerp(cashOut, other.cashOut, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
    );
  }
}
