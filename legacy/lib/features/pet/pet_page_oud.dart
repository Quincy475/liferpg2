import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/painting.dart' show applyBoxFit, BoxFit;

/// --- Concept ---
/// We spelen animaties uit een horizontale spritesheet:
///  [frame0][frame1][frame2]...[frameN-1]
/// Elk frame is even breed, totale breedte = frameWidth * frameCount.
/// Voor eenvoudige demo geven we per animatie: assetPath, frames, fps, loopOfNiet.
///
/// Na user input valt de kat automatisch terug naar IDLE na idleTimeout.

class PetPage extends StatefulWidget {
  const PetPage({super.key});
  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  double _speed = 0.9; // 80% snelheid (1.0 = normaal, <1 = langzamer, >1 = sneller)
  double _accumMs = 0; // tijd-accumulator in milliseconden

  // Animatieconfig (pas counts/fps aan jouw sheets aan)
  // Als je spritesheet uit je screenshot 8 frames heeft: frames: 8
  // fps 8–12 voelt natuurlijk. Pas naar wens aan.
// vervang de _anims-definitie door:
  final Map<String, _AnimConfig> _anims = {
    'IDLE': const _AnimConfig('assets/pets/cat/idle.png', frames: 8, fps: 9, loop: true),
    'WALK': const _AnimConfig('assets/pets/cat/walk.png', frames: 12, fps: 10, loop: true),
    'RUN': const _AnimConfig('assets/pets/cat/run.png', frames: 8, fps: 14, loop: true),
    'ATTACK 1': const _AnimConfig('assets/pets/cat/attack_1.png', frames: 8, fps: 12, loop: false),
    'ATTACK 2': const _AnimConfig('assets/pets/cat/attack_2.png', frames: 9, fps: 12, loop: false),
    'SCARE': const _AnimConfig('assets/pets/cat/scare.png', frames: 11, fps: 12, loop: false),
    'JUMP': const _AnimConfig('assets/pets/cat/jump.png', frames: 3, fps: 10, loop: false),
    'HURT': const _AnimConfig('assets/pets/cat/hurt.png', frames: 4, fps: 8, loop: false),
    'LICK': const _AnimConfig('assets/pets/cat/lick.png', frames: 15, fps: 12, loop: true),
    'SLEEP': const _AnimConfig('assets/pets/cat/sleep.png', frames: 8, fps: 6, loop: true),
    'WALL SLIDE': const _AnimConfig('assets/pets/cat/wall_slide.png', frames: 3, fps: 10, loop: true),
    'CLIMB': const _AnimConfig('assets/pets/cat/climb.png', frames: 9, fps: 10, loop: true),
    'EAT': const _AnimConfig('assets/pets/cat/eat.png', frames: 7, fps: 10, loop: false),
    'DEATH': const _AnimConfig('assets/pets/cat/death.png', frames: 9, fps: 10, loop: false),
  };

  String _current = 'IDLE';
  ui.Image? _image; // geladen spritesheet
  _AnimConfig get _cfg => _anims[_current]!;
  int _currentFrame = 0;
  int _animStartMs = 0; // starttijd in ms sinds epoch
  Timer? _idleTimer; // fallback naar idle na one-shots

  // Idle fallback (na knopdruk weer terug naar idle)
  final Duration idleTimeout = const Duration(seconds: 2);

  // Cache van ingeladen images per asset
  final Map<String, ui.Image> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadCurrentImage(); // laad IDLE
  }

  @override
  void dispose() {
    _ticker.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (_image == null) return;

    final cfg = _cfg; // jouw getter op _anims[_current]!
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final effFps = (cfg.fps * _speed).clamp(1.0, 60.0);

    int newFrame;

    if (cfg.loop) {
      // Loopende animaties → frame = floor( (t * fps) ) % frames
      final tSec = (nowMs - _animStartMs) / 1000.0;
      newFrame = (tSec * effFps).floor() % cfg.frames;
    } else {
      // One-shot → p van 0..1 over totale duur, vervolgens clamp
      final durationMs = (cfg.frames / effFps) * 1000.0;
      final p = ((nowMs - _animStartMs) / durationMs).clamp(0.0, 1.0);
      newFrame = (p * cfg.frames).floor().clamp(0, cfg.frames - 1);

      // Als klaar, plan terug naar IDLE (één keer)
      if (p >= 1.0 && _idleTimer == null) {
        _idleTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _idleTimer = null;
          _setAnim('IDLE');
        });
      }
    }

    if (newFrame != _currentFrame) {
      setState(() => _currentFrame = newFrame);
    }
  }

  void _scheduleIdleFallback() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      if (!mounted) return;
      _setAnim('IDLE');
    });
  }

  Future<void> _loadCurrentImage() async {
    final cfg = _cfg;
    // debug log
    // ignore: avoid_print
    print('Loading sprite: ${cfg.asset}');
    // Image vanuit cache of laden
    if (_imageCache.containsKey(cfg.asset)) {
      setState(() {
        _image = _imageCache[cfg.asset];
        _elapsed = Duration.zero;
        _currentFrame = 0;
      });
      return;
    }
    final image = await _loadImage(cfg.asset);
    if (!mounted) return;
    setState(() {
      _imageCache[cfg.asset] = image;
      _image = image;
      _elapsed = Duration.zero;
      _currentFrame = 0;
    });
  }

  Future<ui.Image> _loadImage(String asset) async {
    try {
      final bytes = await rootBundle.load(asset);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes.buffer.asUint8List(), (img) {
        completer.complete(img);
      });
      return completer.future;
    } catch (e, st) {
      // zichtbaar maken in console én UI
      // ignore: avoid_print
      print('❌ Failed to load/decode asset: $asset\n$e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kon asset niet laden: $asset')),
        );
      }
      rethrow;
    }
  }

  Future<void> _setAnim(String key) async {
    final cfg = _anims[key];
    if (cfg == null) return;

    setState(() {
      _current = key;
    });

    // (her)laad image indien nodig (jouw bestaande loader)
    await _loadCurrentImage();

    _animStartMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _currentFrame = 0;
    });

    // Fallback naar idle: alleen voor one-shots, nadat ze klaar zijn;
    // we plannen 'm niet meteen, dat doet _onTick wanneer p>=1.
    _idleTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final cfg = _cfg;

    return Scaffold(
      appBar: AppBar(title: const Text('Pet — Cat')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Text('State: $_current', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // --- Sprite Canvas ---
          Expanded(
            child: Center(
              child: SizedBox(
                width: 240, // kies gerust 240×192 (3× canvas 80×64) of 320×256
                height: 192,
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _image == null
                        ? const Center(child: CircularProgressIndicator())
                        : _SpriteView(
                            image: _image!,
                            frames: _cfg.frames,
                            frameIndex: _currentFrame,
                          ),
                  ),
                ),
              ),
            ),
          ),

          // --- Controls ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _animBtn('IDLE'),
                _animBtn('WALK'),
                _animBtn('RUN'),
                _animBtn('JUMP'),
                _animBtn('RUNNING JUMP'),
                _animBtn('ATTACK 1'),
                _animBtn('HURT'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 8),
          Text('Speed: ${_speed.toStringAsFixed(2)}x'),
          Slider(
            value: _speed,
            min: 0.3, // langzamer
            max: 1.5, // sneller
            onChanged: (v) => setState(() => _speed = v),
          ),
        ],
      ),
    );
  }

  Widget _animBtn(String key) {
    final selected = _current == key;
    return FilledButton.tonalIcon(
      onPressed: () => _setAnim(key),
      icon: Icon(_iconFor(key)),
      label: Text(key, overflow: TextOverflow.ellipsis),
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (selected) return Theme.of(context).colorScheme.secondaryContainer;
          return null;
        }),
      ),
    );
  }

  IconData _iconFor(String k) {
    switch (k) {
      case 'IDLE':
        return Icons.self_improvement;
      case 'WALK':
        return Icons.directions_walk;
      case 'RUN':
        return Icons.directions_run;
      case 'JUMP':
        return Icons.north;
      case 'RUNNING JUMP':
        return Icons.arrow_circle_up;
      case 'ATTACK 1':
        return Icons.flash_on;
      case 'HURT':
        return Icons.health_and_safety;
      default:
        return Icons.pets;
    }
  }
}

class _AnimConfig {
  final String asset;
  final int frames;
  final int fps;
  final bool loop;
  const _AnimConfig(this.asset, {required this.frames, required this.fps, required this.loop});
}

/// Tekent één frame uit een horizontale spritesheet met [frames] totaal.
/// We gebruiken CustomPaint + paintImage met sourceRect.
///
class _SpriteView extends StatelessWidget {
  final ui.Image image;
  final int frames;
  final int frameIndex;
  const _SpriteView({required this.image, required this.frames, required this.frameIndex});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpritePainter(image, frames, frameIndex),
      isComplex: true,
      willChange: true,
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frames;
  final int frameIndex;
  _SpritePainter(this.image, this.frames, this.frameIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (image.width <= 0 || image.height <= 0 || frames <= 0) return;

    // ▶️ Auto-detecteer framegrootte uit sheet
    double fw = (image.width / frames).floorToDouble();
    double fh = image.height.toDouble();

    // Veilig clampen (als fw*frames net niet exact gelijk is aan image.width)
    double maxSx = (image.width - fw).clamp(0, image.width.toDouble());
    double sx = (fw * frameIndex).clamp(0.0, maxSx);

    final src = Rect.fromLTWH(sx, 0, fw, fh);

    // Netjes schalen/centreren binnen available size (contain)
    final fitted = applyBoxFit(BoxFit.contain, Size(fw, fh), size);
    final dstW = fitted.destination.width;
    final dstH = fitted.destination.height;
    final dx = (size.width - dstW) / 2;
    final dy = (size.height - dstH) / 2;
    final dst = Rect.fromLTWH(dx, dy, dstW, dstH);

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none; // pixelart crispy
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.image != image || old.frames != frames || old.frameIndex != frameIndex;
}
