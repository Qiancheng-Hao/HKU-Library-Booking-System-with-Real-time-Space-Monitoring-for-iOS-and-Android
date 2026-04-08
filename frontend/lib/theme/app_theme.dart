import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Brand & design tokens
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Light mode brand
  static const Color hkuGreen = Color(0xFF006F51);

  // Dark tech palette
  static const Color cyberCyan    = Color(0xFF00D4C8);
  static const Color deepNavy     = Color(0xFF1A2540); // scaffold bg
  static const Color navySurface  = Color(0xFF233050); // app bg surface
  static const Color navyCard     = Color(0xFF2C3D60); // card fill
  static const Color navyCardHigh = Color(0xFF364C74); // elevated card
  static const Color navyOutline  = Color(0xFF445D88); // borders

  // Semantic status (same in both modes)
  static const Color statusAvailable = Color(0xFF2ECC8E);
  static const Color statusModerate  = Color(0xFFF5A623);
  static const Color statusBusy      = Color(0xFFE05252);
}

class AppSpacing {
  AppSpacing._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double pill = 999;
}

// ---------------------------------------------------------------------------
// AppBar gradient decoration (exposed so RootShell can use it)
// ---------------------------------------------------------------------------

/// The animated cyan glow line at the bottom of the dark AppBar.
class AppBarGlowBorder extends StatelessWidget implements PreferredSizeWidget {
  const AppBarGlowBorder({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(1.5);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.cyberCyan.withValues(alpha: 0.9),
            Colors.transparent,
          ],
          stops: const [0.05, 0.5, 0.95],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyberCyan.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme builders
// ---------------------------------------------------------------------------

class AppTheme {
  AppTheme._();

  static ThemeData light() => _buildLight();
  static ThemeData dark()  => _buildDark();

  // ---- LIGHT (clean HKU green) -------------------------------------------

  static ThemeData _buildLight() {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.hkuGreen,
      brightness: Brightness.light,
    );
    final tt = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    return _base(cs, tt).copyWith(
      scaffoldBackgroundColor: const Color(0xFFEDF5F1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: const Color(0xFFDEEFE9),
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }

  // ---- DARK TECH (deep navy + cyber cyan) ---------------------------------

  static ThemeData _buildDark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.cyberCyan,
      brightness: Brightness.dark,
    );

    // Override generated tones with the hand-crafted navy palette.
    final cs = base.copyWith(
      primary:                    AppColors.cyberCyan,
      onPrimary:                  AppColors.deepNavy,
      primaryContainer:           const Color(0xFF00332F),
      onPrimaryContainer:         AppColors.cyberCyan,
      secondary:                  const Color(0xFF4DD8FF),
      onSecondary:                AppColors.deepNavy,
      secondaryContainer:         const Color(0xFF003A4A),
      onSecondaryContainer:       const Color(0xFF87EEFF),
      surface:                    AppColors.navySurface,
      onSurface:                  const Color(0xFFE2EAF8),
      surfaceContainerLowest:     AppColors.deepNavy,
      surfaceContainerLow:        AppColors.navyCard,
      surfaceContainer:           AppColors.navyCard,
      surfaceContainerHigh:       AppColors.navyCardHigh,
      surfaceContainerHighest:    const Color(0xFF415A84),
      onSurfaceVariant:           const Color(0xFFA0BAD8),
      outline:                    AppColors.navyOutline,
      outlineVariant:             const Color(0xFF2E4568),
      inverseSurface:             const Color(0xFFDEE8F8),
      onInverseSurface:           AppColors.deepNavy,
      inversePrimary:             AppColors.hkuGreen,
      shadow:                     Colors.black,
      scrim:                      Colors.black,
    );

    final tt = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    return _base(cs, tt).copyWith(
      scaffoldBackgroundColor: AppColors.deepNavy,

      // Card glow border
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.navyCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: AppColors.cyberCyan.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom nav — deep navy background, cyan indicator
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.cyberCyan.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.cyberCyan,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.cyberCyan, size: 24);
          }
          return const IconThemeData(color: Color(0xFF8A9FBF), size: 24);
        }),
      ),

      // Inputs — dark fill, cyan focus ring
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.navyOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.navyOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.cyberCyan, width: 1.5),
        ),
        labelStyle: tt.bodyMedium?.copyWith(color: const Color(0xFF8A9FBF)),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.navyOutline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ---- Shared base (applied to both light & dark) -------------------------

  static ThemeData _base(ColorScheme cs, TextTheme tt) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      textTheme: tt,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        indicatorColor: cs.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        labelStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.secondaryContainer,
        labelStyle: tt.labelLarge,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: tt.titleSmall,
      ),
    );
  }
}
