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
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      background: AppPalette.bgDark,
      surface: AppPalette.bgDark2,
      primary: AppPalette.amber,
      secondary: AppPalette.teal,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AppPalette.bgDark,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        color: AppPalette.creamText,
        fontSize: 22,
      ),
    ),
    cardTheme: CardTheme(
      color: AppPalette.bgDark2,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A3046),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppPalette.creamText,
      displayColor: AppPalette.creamText,
    ),
  );
}

ThemeData buildRpgLightTheme(Color seed) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: const Color(0xFF6A4C93),
      secondary: const Color(0xFF10A89D),
    ),
    fontFamily: 'Poppins',
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
      color: base.colorScheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: base.colorScheme.surface.withOpacity(0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class AtmosphereBackground extends StatelessWidget {
  final Widget child;
  const AtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF0F2526), Color(0xFF174446), Color(0xFF102A2B)]
                  : const [Color(0xFFFFF4E3), Color(0xFFE7F8F6), Color(0xFFEAF4FF)],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -30,
          child: _blob(const Color(0x22FFFFFF), 240),
        ),
        Positioned(
          bottom: -70,
          left: -40,
          child: _blob(const Color(0x1A22B8A7), 220),
        ),
        child,
      ],
    );
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
