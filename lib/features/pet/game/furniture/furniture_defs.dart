// lib/features/pet/game/furniture/furniture_defs.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

/// Soorten meubels — kan je vrij uitbreiden
enum FurnitureKind {
  bed,
  bowl,
  tower,          // krabpaal / kattentoren
  shelf,
  plant,
  windowFrame,
  curtain,
  table,
  scratchPost,    // staande krabpaal
  toy,
  foodBag,
  decor,
}

/// Eén sprite-definitie uit de atlas (sheet)
// class FurnDef {
//   final String key;             // unieke key ("bed_blue_large")
//   final FurnitureKind kind;
//   final ui.Rect src;            // bron-rect in pixels op de sheet
//   final Vector2? pivot;          // 0..1 (0,0 = linksboven, 0.5,1 = midden-onder)
//   final Vector2? worldSize;     // optioneel: gewenste world size (px in Flame world)
//   final int zBias;              // optioneel: diepte-correctie (render volgorde)

//   const FurnDef({
//     required this.key,
//     required this.kind,
//     required this.src,
//     this.pivot, //= const Vector2(0.5, 1.0), // meestal "op de vloer" verankeren
//     this.worldSize,
//     this.zBias = 0,
//   });
// }

// /// ============================
// /// 📍 VUL HIER JE RECTS IN
// /// ============================
// /// Let op: dit zijn *placeholders*!
// /// Pak de sheet (assets/pets/furniture.png) en meet de juiste pixelposities.
// /// Tip: maak een snel debug overlay in Flame of open in een editor (Krita/GIMP)
// /// en lees x,y,w,h uit. Werk iteratief: begin met een paar items, test in game,
// /// breid dan uit.
//  List<FurnDef> furnitureCatalog = [
//   // Beds – rij 1 (voorbeeldwaarden!)
//   FurnDef(
//     key: 'bed_blue',
//     kind: FurnitureKind.bed,
//     src: ui.Rect.fromLTWH(128,  96, 96, 64), // TODO: vervang met echte coords
//     worldSize: Vector2(128, 86),
//   ),
//   FurnDef(
//     key: 'bed_grey',
//     kind: FurnitureKind.bed,
//     src: ui.Rect.fromLTWH(232,  96, 96, 64), // TODO
//     worldSize: Vector2(128, 86),
//   ),
//   FurnDef(
//     key: 'bed_mint',
//     kind: FurnitureKind.bed,
//     src: ui.Rect.fromLTWH(336,  96, 96, 64), // TODO
//     worldSize: Vector2(128, 86),
//   ),

//   // Krabtorens / towers (links boven; meerdere hoogtes/kleuren)
//   FurnDef(
//     key: 'tower_small_beige',
//     kind: FurnitureKind.tower,
//     src: ui.Rect.fromLTWH(448,  64, 64, 96),  // TODO
//     worldSize: Vector2(90, 140),
//   ),
//   FurnDef(
//     key: 'tower_big_ivory',
//     kind: FurnitureKind.tower,
//     src: ui.Rect.fromLTWH(520,  48, 96, 140), // TODO
//     worldSize: Vector2(130, 200),
//   ),

//   // Ramen + gordijnen
//   FurnDef(
//     key: 'window_large',
//     kind: FurnitureKind.windowFrame,
//     src: ui.Rect.fromLTWH(640,  32, 128, 128), // TODO
//     worldSize: Vector2(220, 220),
//     pivot: Vector2(0.5, 0.95), // net iets boven vloer "zweven"
//   ),
//   FurnDef(
//     key: 'curtain_beige',
//     kind: FurnitureKind.curtain,
//     src: ui.Rect.fromLTWH(640, 168, 128, 64),  // TODO
//     worldSize: Vector2(220, 110),
//     pivot: Vector2(0.5, 0.9),
//   ),

//   // Planten
//   FurnDef(
//     key: 'plant_tall_green',
//     kind: FurnitureKind.plant,
//     src: ui.Rect.fromLTWH(64,  320, 64, 96),  // TODO
//     worldSize: Vector2(80, 130),
//   ),
//   FurnDef(
//     key: 'plant_small_pot',
//     kind: FurnitureKind.plant,
//     src: ui.Rect.fromLTWH(132, 336, 32, 48),  // TODO
//     worldSize: Vector2(40, 60),
//   ),

//   // Tafels / bijzettafels
//   FurnDef(
//     key: 'table_hex_grey',
//     kind: FurnitureKind.table,
//     src: ui.Rect.fromLTWH(720, 320, 64, 64),  // TODO
//     worldSize: Vector2(90, 90),
//   ),
//   FurnDef(
//     key: 'table_hex_beige',
//     kind: FurnitureKind.table,
//     src: ui.Rect.fromLTWH(784, 320, 64, 64),  // TODO
//     worldSize: Vector2(90, 90),
//   ),

//   // Speeltjes
//   FurnDef(
//     key: 'toy_mouse',
//     kind: FurnitureKind.toy,
//     src: ui.Rect.fromLTWH(420, 420, 48, 32),  // TODO
//     worldSize: Vector2(60, 40),
//   ),

//   // Voerzak
//   FurnDef(
//     key: 'food_bag',
//     kind: FurnitureKind.foodBag,
//     src: ui.Rect.fromLTWH(520, 420, 40, 60),  // TODO
//     worldSize: Vector2(50, 80),
//   ),

//   // Kastsysteem / planken
//   FurnDef(
//     key: 'shelf_blue',
//     kind: FurnitureKind.shelf,
//     src: ui.Rect.fromLTWH(16,  420, 80, 110), // TODO
//     worldSize: Vector2(110, 150),
//   ),
//   FurnDef(
//     key: 'shelf_green',
//     kind: FurnitureKind.shelf,
//     src: ui.Rect.fromLTWH(104, 420, 80, 110), // TODO
//     worldSize: Vector2(110, 150),
//   ),
// ];

// /// helper om een def te vinden
// FurnDef? findFurn(String key) {
//   for (final d in furnitureCatalog) {
//     if (d.key == key) return d;
//   }
//   return null;
// }