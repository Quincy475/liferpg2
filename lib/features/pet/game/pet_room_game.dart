// // lib/features/pet/game/pet_room_game.dart
// import 'dart:math' as math;

// import 'package:flame/components.dart';
// import 'package:flame/game.dart';
// import 'package:flame/image_composition.dart';
// import 'package:flame/sprite.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:household_rpg/data/models/Pet.dart';

// import 'package:household_rpg/features/pet/game/bowl_component.dart';
// import 'package:household_rpg/features/pet/game/bowls_atlas.dart';
// import 'package:household_rpg/features/pet/game/cat_sheet_layout.dart';
// import 'package:household_rpg/features/pet/game/furniture/furniture_atlas.dart';
// import 'package:household_rpg/features/pet/game/furniture/furniture_component.dart';
// import 'package:household_rpg/features/pet/game/window_component.dart';

// class PetRoomGame extends FlameGame {
//   final String uid;
//   final String backgroundAsset; // bv 'assets/rooms/1.png'
//   final String sheetAsset; // bv 'assets/pets/cat/AllCats.png'
//   final CatSheetLayout layout;
//   final String initialMood;

//   PetRoomGame({
//     required this.uid,
//     required this.backgroundAsset,
//     required this.sheetAsset,
//     required this.layout,
//     this.initialMood = 'idle',
//   }) : _mood = initialMood;

//   // -----------------------
//   // State & components
//   // -----------------------
//   Image? _bgImage;
//   SpriteComponent? _bg;

//   late SpriteSheet _sheet;
//   final Map<String, SpriteAnimation> _anims = {};
//   SpriteAnimationComponent? _cat;

//   BowlsAtlas? _bowlsAtlas;
//   BowlComponent? _bowl;

//   late FurnitureAtlas furnAtlas;
//   FurnitureComponent? _furn;

//   bool _ready = false;
//   RoomLayout? _pendingRoom;
//   final Map<String, _PlacedRuntime> _placed = {};
//   String _mood; // 'idle', 'eat', 'sleep', etc.

//   // HUD demo waardes (optioneel)
//   int hudHunger = 60;
//   int hudEnergy = 80;
//   int hudHappiness = 70;

//   String? _activeWindowId;
//   WindowComponent? _activeWindow;

//   FurnitureComponent? _activeFurniture;
//   String? _activeFurnitureId;

//   final _db = FirebaseFirestore.instance;
//   void Function(PlacedItem updated)? onPlacedChanged;
//   void Function(String instanceId)? onPlacedRemoved;

// // vloer bounds (default). later kan je dit mooier maken obv room asset.
//   Rect _floorBounds(Vector2 canvasSize) {
//     // normalized to pixels
//     final left = canvasSize.x * 0.08;
//     final right = canvasSize.x * 0.92;
//     final top = canvasSize.y * 0.35;
//     final bottom = canvasSize.y * 0.98;
//     return Rect.fromLTRB(left, top, right, bottom);
//   }

//   Future<void> _loadRoomStateAndApply() async {
//     final snap = await _db.collection('rooms').doc(uid).get();
//     final data = snap.data() ?? {};

//     final activeFurnitureId = data['activeFurnitureId'] as String?;
//     final activeWindowId = data['activeWindowId'] as String?;

//     // eerst window (laag), dan furniture (hoger) maakt niet super uit maar is clean
//     await setActiveWindowLocally(activeWindowId);
//     await setActiveFurnitureLocally(activeFurnitureId);
//   }

//   // -----------------------
//   // Lifecycle
//   // -----------------------
//   @override
// Future<void> onLoad() async {
//   await super.onLoad();

//   images.prefix = '';

//   // 1) Background
//   _bgImage = await images.load(backgroundAsset);
//   _bg = SpriteComponent(
//     sprite: Sprite(_bgImage!),
//     anchor: Anchor.topLeft,
//     position: Vector2.zero(),
//   );
//   add(_bg!);

//   // 2) Cat sheet + anims
//   final catImg = await images.load(sheetAsset);
//   _sheet = SpriteSheet(
//     image: catImg,
//     srcSize: Vector2(layout.frameW.toDouble(), layout.frameH.toDouble()),
//   );
//   _prebuildAnimations();

//   _cat = SpriteAnimationComponent(
//     animation: _anims['idle'],
//     size: Vector2(layout.frameW.toDouble(), layout.frameH.toDouble()),
//     anchor: Anchor.bottomCenter,
//   )..priority = 10;
//   add(_cat!);

//   // 3) Bowl
//   _bowlsAtlas = BowlsAtlas(images, imagePath: 'assets/objects/BowlSprites.png');
//   await _bowlsAtlas!.load();
//   final variant = bowlsAtlas.firstWhere((v) => v.id == 'bowl_small');
//   _bowl = BowlComponent(
//     atlas: _bowlsAtlas!,
//     variant: variant,
//     initialLevel: 0,
//     worldSize: Vector2(96, 64),
//   )..priority = 9;
//   add(_bowl!);

//   // 4) Furniture atlas
//   furnAtlas = await FurnitureAtlas.loadFromJson(
//     images: images,
//     jsonPath: 'objects/furniture_atlas.json',
//     imagePath: 'assets/objects/Furnitures.png',
//   );

//   // 5) Layout op eerste size
//   _applyLayout(size);

//   overlays.add('inventory');

//   // ✅ NEW: mark ready + apply any pending room
//   _ready = true;
//   if (_pendingRoom != null) {
//     await applyRoomLayout(_pendingRoom!);
//     _pendingRoom = null;
//   }
// }
// Future<void> applyRoomLayout(RoomLayout room) async {
//   if (!_ready) {
//     _pendingRoom = room;
//     return;
//   }

//   // remove missing
//   final incomingIds = room.placed.map((p) => p.instanceId).toSet();
//   final toRemove = _placed.keys.where((id) => !incomingIds.contains(id)).toList();
//   for (final id in toRemove) {
//     _placed[id]?.comp.removeFromParent();
//     _placed.remove(id);
//   }

//   // upsert incoming
//   for (final p in room.placed) {
//     final existing = _placed[p.instanceId];
//     if (existing == null) {
//       final comp = _createPlacedComponent(p);
//       _placed[p.instanceId] = _PlacedRuntime(item: p, comp: comp);
//       add(comp);
//     } else {
//       // update locked/scale etc if changed
//       existing.comp.locked = p.locked;
//       existing.comp.userScale = p.scale;

//       _placed[p.instanceId] = existing.copyWith(item: p);
//     }
//   }

//   // set positions based on current canvas
//   _applyLayout(size);
//   _applyPlacedPositions(size);
// }


// void _applyPlacedPositions(Vector2 canvasSize) {
//   for (final rt in _placed.values) {
//     final p = rt.item;
//     // normalized -> pixels
//     rt.comp.position = Vector2(p.x * canvasSize.x, p.y * canvasSize.y);
//   }
// }


//   Future<void> setActiveWindowLocally(String? windowId) async {
//     _activeWindow?.removeFromParent();
//     _activeWindow = null;

//     _activeWindowId = windowId;
//     if (windowId == null) return;

//     final w = WindowComponent(
//       atlas: furnAtlas, // ✅ gebruikt jouw furniture atlas
//       keyName: windowId, // ✅ "window_gray" etc.
//     )..priority = 5; // ✅ muurlaag (achter furn/bowl/cat)

//     _activeWindow = w;
//     add(w);

//     _applyLayout(size);
//   }

//   Future<void> setActiveFurnitureLocally(String? furnitureId) async {
//     // 1. vorige furniture verwijderen
//     _activeFurniture?.removeFromParent();
//     _activeFurniture = null;

//     _activeFurnitureId = furnitureId;

//     // 2. als null → niks actief
//     if (furnitureId == null) return;

//     // 3. nieuwe FurnitureComponent maken
//     final furn = FurnitureComponent(
//       atlas: furnAtlas,
//       keyName: furnitureId,
//     )..priority = 8;

//     _activeFurniture = furn;
//     add(furn);

//     // 4. direct juiste positie toepassen op basis van huidige game size
//     _applyLayout(size); // `size` is de Flame game size (Vector2)
//   }

//   @override
//   void onGameResize(Vector2 canvasSize) {
//     super.onGameResize(canvasSize);
//     _applyLayout(canvasSize);
//   }
// FurnitureComponent _createPlacedComponent(PlacedItem p) {
//   final comp = FurnitureComponent(
//     atlas: furnAtlas,
//     keyName: p.itemId,
//   )
//     ..priority = 8;

//   comp.locked = p.locked;
//   comp.userScale = p.scale;

//   // On drag end → check collision and update state locally (not saved yet)
//   comp.onUserMoved = (newPosPx) {
//     // clamp to floor bounds
//     final floor = _floorBounds(size);
//     final clamped = Vector2(
//       newPosPx.x.clamp(floor.left, floor.right),
//       newPosPx.y.clamp(floor.top, floor.bottom),
//     );

//     comp.position = clamped;

//     // update local model normalized
//     final updated = p.copyWith(
//       x: (clamped.x / size.x).clamp(0.0, 1.0),
//       y: (clamped.y / size.y).clamp(0.0, 1.0),
//       locked: false, // still moving
//     );

//     _placed[p.instanceId] = _placed[p.instanceId]!.copyWith(item: updated);
//   };

//   // On lock request (✅)
//   comp.onLockRequested = () {
//     final current = _placed[p.instanceId]!.item;

//     // collision only for floor
//     final ok = _canLock(current.instanceId);
//     if (!ok) {
//       // simple feedback: unlock stays + little snap back upwards
//       comp.position = comp.position - Vector2(0, 12);
//       return;
//     }

//     final lockedItem = current.copyWith(locked: true);

//     _placed[p.instanceId] = _placed[p.instanceId]!.copyWith(item: lockedItem);
//     comp.locked = true;

//     // notify UI/Repo
//     onPlacedChanged?.call(lockedItem);
//   };

//   return comp;
// }

//  void _applyLayout(Vector2 canvasSize) {
//   if (canvasSize.x == 0 || canvasSize.y == 0) return;

//   // 1) Background: cover
//   if (_bgImage != null && _bg != null) {
//     final imgW = _bgImage!.width.toDouble();
//     final imgH = _bgImage!.height.toDouble();
//     final scale = math.max(canvasSize.x / imgW, canvasSize.y / imgH);

//     _bg!
//       ..size = Vector2(imgW * scale, imgH * scale)
//       ..position = Vector2.zero()
//       ..priority = -1000;
//   }

//   // 2) Cat
//   if (_cat != null) {
//     _cat!.position = Vector2(canvasSize.x * 0.8, canvasSize.y * 0.98);
//   }

//   // 3) Bowl
//   if (_bowl != null) {
//     _bowl!.position = Vector2(canvasSize.x * 0.72, canvasSize.y * 0.90);
//   }

//   // ✅ NEW: apply placed items positions
//   _applyPlacedPositions(canvasSize);

//   // ✅ Window positioning (if you still use window comp)
//   if (_activeWindow != null) {
//     _activeWindow!
//       ..position = Vector2(canvasSize.x * 0.2, canvasSize.y * 0.25)
//       ..anchor = Anchor.center;
//   }
// }

//   // -----------------------
//   // Animaties
//   // -----------------------
//   void _prebuildAnimations() {
//     _anims.clear();
//     for (final entry in layout.animations.entries) {
//       final name = entry.key;
//       final def = entry.value;
//       final int cappedEnd = def.end.clamp(0, layout.columns - 1);
//       _anims[name] = _animFromRow(
//         _sheet,
//         row: def.row,
//         start: def.start,
//         end: cappedEnd,
//         stepTime: def.stepTime,
//         loop: def.loop,
//         seamless: def.seamless,
//       );
//     }
//   }

//   SpriteAnimation _animFromRow(
//     SpriteSheet sheet, {
//     required int row,
//     required int start,
//     required int end,
//     double stepTime = 0.12,
//     bool loop = true,
//     bool seamless = true,
//   }) {
//     final frames = <SpriteAnimationFrame>[];

//     final int s = start.clamp(0, layout.columns - 1);
//     final int e = end.clamp(0, layout.columns - 1);
//     final int dir = s <= e ? 1 : -1;

//     for (int c = s; dir == 1 ? c <= e : c >= e; c += dir) {
//       frames.add(SpriteAnimationFrame(sheet.getSprite(row, c), stepTime));
//     }

//     if (loop && seamless && frames.length > 1) {
//       frames.removeLast(); // simpele flicker-fix
//     }

//     return SpriteAnimation(frames, loop: loop);
//   }

//   // -----------------------
//   // Public API voor UI
//   // -----------------------
//   List<String> get availableMoods => layout.animations.keys.toList()..sort();
//   String get currentMood => _mood;

//   void setMood(String mood) {
//     _mood = mood;
//     setPetMood(mood);
//   }

//   void setPetSprite(String moodOrState) => setMood(moodOrState);

//   void setPetMood(String mood) {
//     if (_cat == null) return;
//     final anim = _animationForMood(mood);
//     if (anim != null) {
//       _cat!.animation = anim;
//     }
//   }

//   SpriteAnimation? _animationForMood(String mood) {
//     final def = layout.animations[mood];
//     if (def == null) return null;
//     return _anims[mood] ??
//         _animFromRow(
//           _sheet,
//           row: def.row,
//           start: def.start,
//           end: def.end,
//           stepTime: def.stepTime,
//           loop: def.loop,
//         );
//   }
// }
// class _PlacedRuntime {
//   final PlacedItem item;
//   final FurnitureComponent comp;

//   _PlacedRuntime({required this.item, required this.comp});

//   _PlacedRuntime copyWith({PlacedItem? item, FurnitureComponent? comp}) =>
//       _PlacedRuntime(item: item ?? this.item, comp: comp ?? this.comp);
// }