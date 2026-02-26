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
    cardTheme: CardTheme(
      color: base.colorScheme.surface.withOpacity(0.88),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
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
    cardTheme: CardTheme(
      color: base.colorScheme.surface.withOpacity(0.94),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
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
