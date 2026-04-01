// import 'dart:math' as math;

// import 'package:flame/components.dart';
// import 'package:flame/events.dart';

// import 'furniture/furniture_atlas.dart';

// class WindowComponent extends PositionComponent with TapCallbacks, DragCallbacks {
//   final FurnitureAtlas atlas;
//   final String keyName;

//   late final FurnDef def;
//   SpriteComponent? _sprite;

//   bool dragging = false;

//   WindowComponent({
//     required this.atlas,
//     required this.keyName,
//     Vector2? position,
//   }) : super(
//           position: position ?? Vector2.zero(),
//           anchor: Anchor.center, // ✅ muur-item: center werkt meestal beter
//         );

//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();

//     def = atlas.getDef(keyName);
//     final sprite = atlas.sprite(keyName);

//     const double globalScale = 1.6;

//     _sprite = SpriteComponent(
//       sprite: sprite,
//       anchor: Anchor.center, // ✅ center zodat positioneren simpel is
//     );
//     add(_sprite!);

//     final srcW = def.src.width;
//     final srcH = def.src.height;

//     // Zelfde sizing logic als FurnitureComponent (maar zonder floor pivot gedoe)
//     if (def.worldSize != null) {
//       final targetW = def.worldSize!.width;
//       final targetH = def.worldSize!.height;

//       final baseScale = math.min(targetW / srcW, targetH / srcH);
//       final scaleFactor = baseScale * globalScale;

//       size = Vector2(srcW * scaleFactor, srcH * scaleFactor);
//       _sprite!.scale = Vector2.all(scaleFactor);
//     } else {
//       size = Vector2(srcW * globalScale, srcH * globalScale);
//       _sprite!.scale = Vector2.all(globalScale);
//     }

//     // sprite in het midden
//     _sprite!.position = size / 2;
//   }

//   @override
//   void update(double dt) {
//     super.update(dt);
//     // ❌ geen priority = y sorting (window hoort "vast" op de muur)
//   }

//   // ---- Drag (optioneel, handig voor debug positioneren) ----
//   @override
//   void onDragStart(DragStartEvent event) {
//     dragging = true;
//     event.handled = true;
//   }

//   @override
//   void onDragUpdate(DragUpdateEvent event) {
//     if (!dragging) return;
//     position += event.delta;
//     event.handled = true;
//   }

//   @override
//   void onDragEnd(DragEndEvent event) {
//     dragging = false;
//     event.handled = true;
//   }

//   @override
//   void onTapDown(TapDownEvent event) {
//     event.handled = true;
//   }
// }
