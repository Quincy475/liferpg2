// import 'package:flame/components.dart';
// import 'package:flame/events.dart';

// import 'dart:math' as math;

// import 'furniture_atlas.dart';

// class FurnitureComponent extends PositionComponent with TapCallbacks, DragCallbacks {
//   final FurnitureAtlas atlas;
//   final String keyName;

//   late final FurnDef def;
//   SpriteComponent? _sprite;

//   bool dragging = false;

//   FurnitureComponent({
//     required this.atlas,
//     required this.keyName,
//     Vector2? position,
//   }) : super(
//           position: position ?? Vector2.zero(),
//           anchor: Anchor.bottomCenter,
//         );
//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();

//     def = atlas.getDef(keyName);

//     final sprite = atlas.sprite(keyName);
//     const double globalScale = 1.6; // 👈 alles 2x zo groot

//     _sprite = SpriteComponent(
//       sprite: sprite,
//       anchor: Anchor.bottomCenter,
//     );
//     add(_sprite!);

//     final srcW = def.src.width;
//     final srcH = def.src.height;

//     if (def.worldSize != null) {
//       // gewenste “doelgrootte” uit JSON
//       final targetW = def.worldSize!.width;
//       final targetH = def.worldSize!.height;

//       // uniforme schaal: zelfde factor in X en Y
//       final baseScale = math.min(targetW / srcW, targetH / srcH);
//       final scaleFactor = baseScale * globalScale; // 👈 hier factor 2

//       final w = srcW * scaleFactor;
//       final h = srcH * scaleFactor;

//       size = Vector2(srcW * globalScale, srcH * globalScale);
//       _sprite!.scale = Vector2.all(globalScale);
//     } else {
//       size = Vector2(srcW, srcH);
//       _sprite!.scale = Vector2.all(1.0);
//     }

//     // child positioneren volgens pivot
//     _sprite!.position = Vector2(
//       size.x * def.pivot.dx,
//       size.y * def.pivot.dy,
//     );
//   }

//   @override
//   void update(double dt) {
//     super.update(dt);

//     // simple depth sorting by y
//     priority = (y + def.zBias).toInt();
//   }

//   // ---------------- Drag ----------------

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
