import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';

/// Single furniture definition (cropping + metadata)

class FurnDef {
  final String id;
  final Rect src; // x,y,w,h uit atlas
  final Offset pivot; // 0..1 — waar de sprite "op" de vloer staat
  final Size? worldSize; // optioneel, schaal in wereld
  final double zBias;

  const FurnDef({
    required this.id,
    required this.src,
    required this.pivot,
    this.worldSize,
    this.zBias = 0,
  });
}

class FurnitureAtlas {
  final Images images;
  final String imagePath;
  late Image _image;

  final Map<String, FurnDef> defs = {};

  FurnitureAtlas(this.images, this.imagePath);

  static Future<FurnitureAtlas> loadFromJson({
    required Images images,
    required String jsonPath,
    required String imagePath,
  }) async {
    // 1) JSON-bestand lezen
    final raw = await Flame.assets.readFile(jsonPath);
    final dynamic decoded = json.decode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'FurnitureAtlas: root of "$jsonPath" is not a JSON object. '
        'Got: ${decoded.runtimeType}',
      );
    }

    final root = decoded as Map<String, dynamic>;

    // 🔍 We ondersteunen 2 vormen:
    // A) "platte" vorm (wat jij stuurde):
    //    { "tower_beige": { ... }, "bed_soft_blue": { ... } }
    // B) geneste vorm:
    //    { "items": { "tower_beige": {...}, ... } }
    Map<String, dynamic> items;
    if (root.containsKey('items')) {
      final dynItems = root['items'];
      if (dynItems is! Map<String, dynamic>) {
        throw Exception(
          'FurnitureAtlas: "items" in "$jsonPath" is not a JSON object. '
          'Got: ${dynItems.runtimeType}',
        );
      }
      items = dynItems;
    } else {
      items = root;
    }

    // 2) PNG laden
    final atlas = FurnitureAtlas(images, imagePath);
    atlas._image = await images.load(imagePath);

    // 3) Items parsen
    items.forEach((key, value) {
      if (value == null) {
        throw Exception(
          'FurnitureAtlas: item "$key" in "$jsonPath" is null. '
          'Check your JSON structure.',
        );
      }
      if (value is! Map<String, dynamic>) {
        throw Exception(
          'FurnitureAtlas: item "$key" is not an object. Got: ${value.runtimeType}',
        );
      }

      final map = value;

      final srcDyn = map['src'];
      if (srcDyn is! Map<String, dynamic>) {
        throw Exception(
          'FurnitureAtlas: item "$key" has no valid "src" map. Got: ${srcDyn.runtimeType}',
        );
      }
      final pivotDyn = map['pivot'];
      if (pivotDyn is! Map<String, dynamic>) {
        throw Exception(
          'FurnitureAtlas: item "$key" has no valid "pivot" map. Got: ${pivotDyn.runtimeType}',
        );
      }
      final wsDyn = map['worldSize'];

      final src = srcDyn;
      final pivot = pivotDyn;
      final ws = wsDyn is Map<String, dynamic> ? wsDyn : null;

      atlas.defs[key] = FurnDef(
        id: key,
        src: Rect.fromLTWH(
          (src['x'] as num).toDouble(),
          (src['y'] as num).toDouble(),
          (src['w'] as num).toDouble(),
          (src['h'] as num).toDouble(),
        ),
        pivot: Offset(
          (pivot['x'] as num).toDouble(),
          (pivot['y'] as num).toDouble(),
        ),
        worldSize: ws == null
            ? null
            : Size(
                (ws['w'] as num).toDouble(),
                (ws['h'] as num).toDouble(),
              ),
        zBias: (map['zBias'] as num?)?.toDouble() ?? 0,
      );
    });

    if (atlas.defs.isEmpty) {
      throw Exception(
        'FurnitureAtlas: no furniture items loaded from "$jsonPath". '
        'Check if the JSON has items at the root or under "items".',
      );
    }

    return atlas;
  }

  FurnDef getDef(String id) {
    final def = defs[id];
    if (def == null) {
      throw Exception('FurnitureAtlas: unknown furniture id "$id"');
    }
    return def;
  }

  Sprite sprite(String id) {
    final d = getDef(id);
    return Sprite(
      _image,
      srcPosition: Vector2(d.src.left, d.src.top),
      srcSize: Vector2(d.src.width, d.src.height),
    );
  }
}
