// import 'package:flutter/foundation.dart';

/// Eén animatie-definitie in de spritesheet.
class AnimDef {
  final int row; // welke rij in de sheet
  final int start; // start kolom (inclusief)
  final int end; // eind kolom (inclusief)
  final double stepTime; // tijd per frame
  final bool loop; // loopend of one-shot
  final bool seamless;

  const AnimDef({
    required this.row,
    required this.start,
    required this.end,
    this.stepTime = 0.12,
    this.loop = true,
    this.seamless = true,
  });
}

/// Indeling van de CAT-spritesheet + mapping van animatie-namen naar frames.
class CatSheetLayout {
  /// Breedte/hoogte per frame (pixels)
  final int frameW;
  final int frameH;

  /// Totaal aantal kolommen/rijen in de sheet (optioneel; nuttig voor checks)
  final int columns;
  final int rows;

  /// Alle animaties beschikbaar in deze sheet.
  /// Key = “mood” (bv. idle, blink, walk, sleep, …)
  final Map<String, AnimDef> animations;

  const CatSheetLayout({
    required this.frameW,
    required this.frameH,
    required this.columns,
    required this.rows,
    required this.animations,
  });

  /// Handige getter: lijst van alle moods/animaties.
  List<String> get moods => animations.keys.toList();

  /// Voorbeeld-layout (PAS DEZE AAN aan jouw echte sheet!):
  ///
  /// - Stel: elk frame is 64x64,
  /// - 10 kolommen per rij,
  /// - rijen 0..9 bevatten onderstaande animaties.
  ///
  /// ❗ Als je frames anders zijn (bijv. 32x32 of 96x96) of de frames zitten
  /// op andere rijen/kolommen, pas dan de waarden hier aan.
  factory CatSheetLayout.v1() {
    return const CatSheetLayout(
      frameW: 64,
      frameH: 64,
      columns: 10,
      rows: 10,
      animations: {
        // naam      row start end  step  loop
        'idle': AnimDef(row: 0, start: 0, end: 5, stepTime: 0.1, loop: true),
        'blink': AnimDef(row: 1, start: 0, end: 2, stepTime: 0.10, loop: true),
        'sleep_back': AnimDef(row: 2, start: 0, end: 0, stepTime: 0.10, loop: true),
        // 'walk': AnimDef(row: 2, start: 0, end: 7, stepTime: 0.10, loop: true),
        'sleep': AnimDef(row: 3, start: 0, end: 3, stepTime: 0.08, loop: true),
        'stretch': AnimDef(row: 4, start: 0, end: 9, stepTime: 0.14, loop: true),
        'run': AnimDef(row: 5, start: 0, end: 5, stepTime: 0.18, loop: true),
        'run_jump': AnimDef(row: 6, start: 0, end: 11, stepTime: 0.12, loop: true),
        'box_out': AnimDef(row: 7, start: 0, end: 11, stepTime: 0.12, loop: true),
        'box_in': AnimDef(row: 8, start: 0, end: 9, stepTime: 0.14, loop: true),
        'box_in_2': AnimDef(row: 9, start: 0, end: 11, stepTime: 0.10, loop: true),
        'cry': AnimDef(row: 10, start: 0, end: 3, stepTime: 0.10, loop: true),
        'dance': AnimDef(row: 11, start: 0, end: 3, stepTime: 0.10, loop: true),
        'bored': AnimDef(row: 12, start: 0, end: 7, stepTime: 0.10, loop: true),
        'happy': AnimDef(row: 13, start: 0, end: 1, stepTime: 0.10, loop: true),
        'sleep_back_2': AnimDef(row: 14, start: 0, end: 3, stepTime: 0.10, loop: true),
      },
    );
  }
}
