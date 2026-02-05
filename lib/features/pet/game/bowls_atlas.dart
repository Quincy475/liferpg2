import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 1 level = 1 statisch frame (geen anim), we wisselen sprite bij level-change.
class BowlVariant {
  final String id;
  final List<ui.Rect> levels; // van VOL (index 0) -> LEEG (laatste)
  const BowlVariant({required this.id, required this.levels});
}

/// Tip: vul deze Rects 1x goed in (px in de sheet). Gebruik evt. jouw grid overlay of
/// een image editor om x,y,w,h te meten. Onderstaande waardes zijn PLACEHOLDERS:
/// pas ze aan naar jouw sheet (x,y,width,height in pixels).
const _px = 1.0;
const bowlsAtlas = <BowlVariant>[
  // Blauwe kommen – 4 levels (vol->leeg), rij 1
  BowlVariant(id: 'bowl_blue', levels: [
    Rect.fromLTWH(0 * _px, 0 * _px, 64, 64),
    Rect.fromLTWH(64 * _px, 0 * _px, 64, 64),
    Rect.fromLTWH(128 * _px, 0 * _px, 64, 64),
    Rect.fromLTWH(192 * _px, 0 * _px, 64, 64),
  ]),
  // Groene kommen – 4 levels (vol->leeg), rij 2
  BowlVariant(id: 'bowl_green', levels: [
    Rect.fromLTWH(0 * _px, 64 * _px, 64, 64),
    Rect.fromLTWH(64 * _px, 64 * _px, 64, 64),
    Rect.fromLTWH(128 * _px, 64 * _px, 64, 64),
    Rect.fromLTWH(192 * _px, 64 * _px, 64, 64),
  ]),
  // Bruine kommen – 4 levels (kleiner), rij 3
  BowlVariant(id: 'bowl_brown', levels: [
    Rect.fromLTWH(0 * _px, 128 * _px, 48, 48),
    Rect.fromLTWH(48 * _px, 128 * _px, 48, 48),
    Rect.fromLTWH(96 * _px, 128 * _px, 48, 48),
    Rect.fromLTWH(144 * _px, 128 * _px, 48, 48),
  ]),
  // Kleine kommen (iconisch), 4 levels – rij 4
  BowlVariant(id: 'bowl_small', levels: [
    Rect.fromLTWH(0 * _px, 194 * _px, 16, 14),
    Rect.fromLTWH(16 * _px, 194 * _px, 16, 14),
    Rect.fromLTWH(32 * _px, 194 * _px, 16, 14),
    Rect.fromLTWH(48 * _px, 194 * _px, 16, 14),
  ]),
];

class BowlsAtlas {
  final Images images;
  final String imagePath; // bv. 'assets/pets/bowls.png'
  ui.Image? _image;

  BowlsAtlas(this.images, {required this.imagePath});

  Future<void> load() async {
    _image ??= await images.load(imagePath);
  }

  /// Bouw Sprites voor één variant (alle levels).
  List<Sprite> spritesFor(BowlVariant variant) {
    final img = _image!;
    return variant.levels.map((r) {
      return Sprite(
        img,
        srcPosition: Vector2(r.left, r.top),
        srcSize: Vector2(r.width, r.height),
      );
    }).toList();
  }
}
