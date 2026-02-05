import 'package:flame/components.dart';
import 'bowls_atlas.dart';

/// Houdt de wereldgrootte uniform, ongeacht de bron-sprite-afmeting.
/// Voor bv. grote bowl ~ 96w x 64h world-units; kleine schaal je desnoods kleiner.
class BowlComponent extends SpriteGroupComponent<int> with HasGameRef {
  final BowlsAtlas atlas;
  final BowlVariant variant;
  final int initialLevel; // 0 = vol
  final Vector2? worldSize; // hoe groot op het scherm (in game units)

  late final List<Sprite> _sprites;

  BowlComponent({
    required this.atlas,
    required this.variant,
    this.initialLevel = 0,
    this.worldSize, // = const Vector2(96, 64),
    Vector2? position,
  }) : super(
          position: position ?? Vector2.zero(),
          anchor: Anchor.bottomCenter, // staat netjes op de “vloer”
        );

  @override
  Future<void> onLoad() async {
    await atlas.load();
    _sprites = atlas.spritesFor(variant);

    // init met juiste level
    sprites = {
      for (var i = 0; i < _sprites.length; i++) i: _sprites[i],
    };
    current = initialLevel.clamp(0, _sprites.length - 1);

    // Wereldgrootte consistent houden (ongeacht bron-rect)
    size = worldSize!;
    scale = Vector2.all(0.5);
  }

  void setLevel(int level) {
    current = level.clamp(0, _sprites.length - 1);
  }
}
