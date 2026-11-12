import 'package:flutter/material.dart';

class AppPalette {
  // Warm + fresh palette (avoid default purple bias)
  static const Color bgDark = Color(0xFF102A2B);
  static const Color bgDark2 = Color(0xFF143839);
  static const Color creamText = Color(0xFFFFF2D9);
  static const Color amber = Color(0xFFDD9B2E);
  static const Color teal = Color(0xFF22B8A7);
  static const Color cyan = Color(0xFF35D0FF);
  static const Color cardBorder = Color(0xFFECC98C);

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2230), Color(0xFF2B2342)],
  );

  static const gradientXp = LinearGradient(
    colors: [teal, cyan],
  );
}

ThemeData buildRpgTheme(Color seed) {
  final seedHsl = HSLColor.fromColor(seed);
  final darkBg = seedHsl
      .withSaturation((seedHsl.saturation * 0.34).clamp(0.14, 0.40))
      .withLightness(0.10)
      .toColor();
  final darkSurface = seedHsl
      .withHue((seedHsl.hue + 16) % 360)
      .withSaturation((seedHsl.saturation * 0.40).clamp(0.18, 0.52))
      .withLightness(0.15)
      .toColor();

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      background: darkBg,
      surface: darkSurface,
      primary: seed,
      secondary: seedHsl.withHue((seedHsl.hue + 34) % 360).toColor(),
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: darkBg,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        color: AppPalette.creamText,
        fontSize: 22,
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: base.colorScheme.surface.withOpacity(0.75),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: base.colorScheme.surface.withOpacity(0.92),
      indicatorColor: base.colorScheme.primary.withOpacity(0.24),
      labelTextStyle: MaterialStatePropertyAll(
        TextStyle(color: base.colorScheme.onSurface),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppPalette.creamText,
      displayColor: AppPalette.creamText,
    ),
  );
}

/// Night board: donker, strak, één accentkleur (de seed, standaard violet) met
/// mint en goud als ondersteunende kleuren. Vaste inktkleuren voor vlakken.
/// Lettertype: systeemfont (Sora uit het concept vraagt een eigen font-bundel).
class NightPalette {
  static const ink = Color(0xFF0F1115);
  static const card = Color(0xFF171A21);
  static const cardHigh = Color(0xFF1B1F29);
  static const nav = Color(0xFF12151B);
  static const line = Color(0xFF272C37);
  static const text = Color(0xFFF2F3F5);
  static const textMuted = Color(0xFF8B93A3);
  static const mint = Color(0xFF3DDC97);
  static const gold = Color(0xFFF5C451);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildNightTheme(Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: seed,
    onPrimary: NightPalette.ink,
    secondary: NightPalette.mint,
    onSecondary: NightPalette.ink,
    tertiary: NightPalette.gold,
    onTertiary: NightPalette.ink,
    error: NightPalette.danger,
    surface: NightPalette.ink,
    onSurface: NightPalette.text,
    onSurfaceVariant: NightPalette.textMuted,
    surfaceContainerLowest: NightPalette.ink,
    surfaceContainerLow: NightPalette.card,
    surfaceContainer: NightPalette.card,
    surfaceContainerHigh: NightPalette.cardHigh,
    surfaceContainerHighest: NightPalette.cardHigh,
    outline: NightPalette.textMuted,
    outlineVariant: NightPalette.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: NightPalette.ink,
  );
  final text = base.textTheme.apply(
    bodyColor: NightPalette.text,
    displayColor: NightPalette.text,
  );

  final rounded12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: NightPalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NightPalette.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: NightPalette.line, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: seed,
      side: const BorderSide(color: NightPalette.line),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: text.bodySmall?.copyWith(color: NightPalette.textMuted),
      secondaryLabelStyle: text.bodySmall?.copyWith(color: NightPalette.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: rounded12, textStyle: text.labelLarge),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded12,
        side: const BorderSide(color: NightPalette.line),
        foregroundColor: NightPalette.text,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: NightPalette.card,
        foregroundColor: NightPalette.textMuted,
        selectedBackgroundColor: seed,
        selectedForegroundColor: NightPalette.ink,
        side: const BorderSide(color: NightPalette.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NightPalette.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NightPalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NightPalette.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NightPalette.cardHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: NightPalette.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NightPalette.nav,
      surfaceTintColor: Colors.transparent,
      indicatorColor: seed.withValues(alpha: 0.18),
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected) ? seed : NightPalette.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? seed : NightPalette.textMuted,
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: seed,
      linearTrackColor: NightPalette.line,
    ),
  );
}

ThemeData buildRpgLightTheme(Color seed) {
  final seedHsl = HSLColor.fromColor(seed);
  final lightBg = seedHsl
      .withSaturation((seedHsl.saturation * 0.26).clamp(0.08, 0.34))
      .withLightness(0.96)
      .toColor();
  final lightSurface = seedHsl
      .withHue((seedHsl.hue + 26) % 360)
      .withSaturation((seedHsl.saturation * 0.30).clamp(0.10, 0.38))
      .withLightness(0.93)
      .toColor();

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: seedHsl.withHue((seedHsl.hue + 42) % 360).toColor(),
      background: lightBg,
      surface: lightSurface,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: lightBg,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: base.colorScheme.surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        color: base.colorScheme.onSurface,
        fontSize: 22,
      ),
    ),
   
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: base.colorScheme.surface.withOpacity(0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: base.colorScheme.surface.withOpacity(0.94),
      indicatorColor: base.colorScheme.primary.withOpacity(0.20),
      labelTextStyle: MaterialStatePropertyAll(
        TextStyle(color: base.colorScheme.onSurface),
      ),
    ),
  );
}

class AtmosphereBackground extends StatelessWidget {
  final Widget child;
  const AtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SizedBox.expand(child: child),
      );
    }
    final seed = Theme.of(context).colorScheme.primary;
    final tones = _backgroundTones(seed: seed, dark: dark);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tones,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -30,
          child: _blob(dark ? const Color(0x22FFFFFF) : tones[1].withOpacity(0.22), 240),
        ),
        Positioned(
          bottom: -70,
          left: -40,
          child: _blob(dark ? tones[2].withOpacity(0.20) : tones[0].withOpacity(0.18), 220),
        ),
        child,
      ],
    );
  }

  List<Color> _backgroundTones({required Color seed, required bool dark}) {
    final hsl = HSLColor.fromColor(seed);
    if (dark) {
      final c1 = hsl
          .withSaturation((hsl.saturation * 0.55).clamp(0.28, 0.60))
          .withLightness(0.14)
          .toColor();
      final c2 = hsl
          .withHue((hsl.hue + 28) % 360)
          .withSaturation((hsl.saturation * 0.70).clamp(0.32, 0.72))
          .withLightness(0.20)
          .toColor();
      final c3 = hsl
          .withHue((hsl.hue + 300) % 360)
          .withSaturation((hsl.saturation * 0.45).clamp(0.22, 0.52))
          .withLightness(0.12)
          .toColor();
      return [c1, c2, c3];
    }

    final c1 = hsl
        .withSaturation((hsl.saturation * 0.28).clamp(0.10, 0.32))
        .withLightness(0.95)
        .toColor();
    final c2 = hsl
        .withHue((hsl.hue + 36) % 360)
        .withSaturation((hsl.saturation * 0.30).clamp(0.12, 0.38))
        .withLightness(0.91)
        .toColor();
    final c3 = hsl
        .withHue((hsl.hue + 322) % 360)
        .withSaturation((hsl.saturation * 0.24).clamp(0.10, 0.30))
        .withLightness(0.93)
        .toColor();
    return [c1, c2, c3];
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      );
}

class EnterMotion extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const EnterMotion({super.key, required this.child, this.delayMs = 0});

  @override
  State<EnterMotion> createState() => _EnterMotionState();
}

class _EnterMotionState extends State<EnterMotion> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _show ? Offset.zero : const Offset(0, 0.05),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _show ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        child: widget.child,
      ),
    );
  }
}
