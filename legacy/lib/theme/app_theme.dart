import 'package:flutter/material.dart';

class AppPalette {
  // Basis
  static const Color bgDark = Color(0xFF1C1F2A);       // diep donkerblauw
  static const Color bgDark2 = Color(0xFF23283A);      // iets lichter
  static const Color creamText = Color(0xFFFFEBC1);    // warme crème
  static const Color gold = Color(0xFFD6B05F);         // goudaccent
  static const Color neon = Color(0xFF5DE3D3);         // turquoise/neon
  static const Color neon2 = Color(0xFF2CB7F6);        // blauwe edge
  static const Color cardBorder = Color(0xFFE9C784);   // lichte goudrand

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2230), Color(0xFF2B2342)],
  );

  static const gradientXp = LinearGradient(
    colors: [neon, neon2],
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
      primary: AppPalette.gold,
      secondary: AppPalette.neon,
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
    textTheme: base.textTheme.apply(
      bodyColor: AppPalette.creamText,
      displayColor: AppPalette.creamText,
    ),
  );
}