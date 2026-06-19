import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core palette ────────────────────────────────────────────────────────────
  static const sage       = Color(0xFF8B9D83);
  static const moss       = Color(0xFF606C38);
  static const clay       = Color(0xFFB08B6E);
  static const terracotta = Color(0xFFC66B3D);
  static const ochre      = Color(0xFFC08E3A);
  static const sand       = Color(0xFFE8DCC7);
  static const oat        = Color(0xFFD4B895);
  static const ink        = Color(0xFF23271A);

  // Lighter warm canvas — better reading comfort than pure sand
  static const canvas = Color(0xFFF2EDE1);

  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: moss,
      brightness: Brightness.light,
      primary: moss,
      secondary: clay,
      tertiary: terracotta,
      surface: const Color(0xFFFCFAF6),
    );
    return _buildTheme(scheme).copyWith(
      scaffoldBackgroundColor: canvas,
      extensions: const [SproutPalette.light],
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: Brightness.dark,
      primary: sage,
      secondary: clay,
      tertiary: terracotta,
      surface: const Color(0xFF202417),
    );
    return _buildTheme(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF171A11),
      extensions: const [SproutPalette.dark],
    );
  }

  // ── Shared build ────────────────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme scheme) {
    final body    = GoogleFonts.epilogueTextTheme();
    final display = GoogleFonts.frauncesTextTheme();

    final textTheme = body
        .copyWith(
          // Fraunces for all display / headline levels
          displayLarge:   display.displayLarge?.copyWith(fontSize: 56,  height: .96,  fontWeight: FontWeight.w800),
          displayMedium:  display.displayMedium?.copyWith(fontSize: 44, height: 1.0,  fontWeight: FontWeight.w800),
          displaySmall:   display.displaySmall?.copyWith(fontSize: 34,  height: 1.04, fontWeight: FontWeight.w800),
          headlineLarge:  display.headlineLarge?.copyWith(fontSize: 30,  height: 1.06, fontWeight: FontWeight.w800),
          headlineMedium: display.headlineMedium?.copyWith(fontSize: 24, height: 1.1,  fontWeight: FontWeight.w800),
          headlineSmall:  display.headlineSmall?.copyWith(fontSize: 20,  height: 1.15, fontWeight: FontWeight.w800),
          // Epilogue for titles / body / labels
          titleLarge:  body.titleLarge?.copyWith(fontSize: 17,   height: 1.25, fontWeight: FontWeight.w800),
          titleMedium: body.titleMedium?.copyWith(fontSize: 15,   height: 1.3,  fontWeight: FontWeight.w700),
          titleSmall:  body.titleSmall?.copyWith(fontSize: 13,   height: 1.25, fontWeight: FontWeight.w700),
          bodyLarge:   body.bodyLarge?.copyWith(fontSize: 15,   height: 1.55),
          bodyMedium:  body.bodyMedium?.copyWith(fontSize: 13.5, height: 1.55),
          bodySmall:   body.bodySmall?.copyWith(fontSize: 12,   height: 1.4),
          labelLarge:  body.labelLarge?.copyWith(fontSize: 12.5, height: 1.1,  fontWeight: FontWeight.w700, letterSpacing: .2),
          labelMedium: body.labelMedium?.copyWith(fontSize: 11.5, height: 1.1, fontWeight: FontWeight.w600),
          labelSmall:  body.labelSmall?.copyWith(fontSize: 10.5, height: 1.1,  fontWeight: FontWeight.w600, letterSpacing: .3),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,

      // ── Cards ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.epilogue(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: .2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: GoogleFonts.epilogue(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: .2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: GoogleFonts.epilogue(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
      ),

      // ── Dialogs ─────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          height: 1.2,
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: GoogleFonts.epilogue(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),

      // ── Dividers ────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .5),
        space: 1,
        thickness: 1,
      ),

      // ── Snackbars ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.epilogue(
          fontSize: 13.5,
          color: scheme.onInverseSurface,
        ),
      ),

      // ── Navigation rail (used on tablet) ────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface.withValues(alpha: .7),
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: GoogleFonts.epilogue(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: GoogleFonts.epilogue(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),

      // ── App bar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

// ── SproutPalette (semantic colour extension) ──────────────────────────────────
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
  }) =>
      SproutPalette(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        cashIn: cashIn ?? this.cashIn,
        cashOut: cashOut ?? this.cashOut,
        paper: paper ?? this.paper,
      );

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
