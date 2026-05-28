import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart' as fp;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bluetooth.dart';
import '../../generated/l10n.dart';
import '../game_base.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';

/// ============================================================================
/// [S1] 하늘 정원사 (Sky Gardener)
/// 관절: 어깨 굽힘/폄 (lShoulderEF)
/// 메카닉: 수직 정원에서 다양한 높이의 과일을 수확. 어깨 각도 = 손 높이.
/// Brunnstrom 적응: Stage 2~3 CPM 보조, Stage 4+ 자유 운동
/// 인지 레벨 적응: 레벨 1 단순, 레벨 3 풍부
/// ============================================================================
class SkyGardenerFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5; // 0.0=아래, 1.0=위
  int score = 0;
  int missed = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();
  double _spawnTimer = 0;

  late _Hand _hand;
  late _Basket _basket;
  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _comboText;
  int _combo = 0;

  SkyGardenerFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  }) : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF3A7BD5); // 하늘색 기본값 (배경 이미지로 덮임)

  double get _spawnInterval => (1.6 / config.speedMultiplier).clamp(0.4, 3.0);

  @override
  Future<void> onLoad() async {
    // ── 하늘 그라디언트 배경 ──
    add(_SkyBackground(gameSize: size));

    // ── foliage 스프라이트 배경 장식 (인지 레벨 1+) ──
    if (config.cognitiveLevel.bgComplexity >= 1) {
      await _addFoliageBackground();
    } else {
      _addSimpleGround();
    }

    // 구름 (인지 레벨 2+)
    if (config.cognitiveLevel.bgComplexity >= 2) {
      for (int i = 0; i < 3; i++) {
        add(_Cloud(
          pos: Vector2(size.x * (0.2 + i * 0.3), 30 + _rng.nextDouble() * 40),
          speed: 8 + _rng.nextDouble() * 12,
          gameWidth: size.x,
        ));
      }
    }

    // 바구니 (하단)
    _basket = _Basket(gameSize: size);
    add(_basket);

    // 손 (플레이어 - 수직 이동)
    _hand = _Hand(gameSize: size, sizeMultiplier: config.targetSizeMultiplier);
    add(_hand);

    // HUD
    _scoreText = _HudText(text: '🌻 0', pos: Vector2(20, 16), anchor: Anchor.topLeft,
        color: Colors.white, fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22);
    add(_scoreText);

    if (config.cognitiveLevel.showTimer) {
      _timerText = _HudText(text: '${timeRemaining.toInt()}s',
          pos: Vector2(size.x - 20, 16), anchor: Anchor.topRight, color: Colors.white70);
      add(_timerText);
    } else {
      _timerText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    if (config.cognitiveLevel.showCombo) {
      _comboText = _HudText(text: '', pos: Vector2(size.x / 2, 16), anchor: Anchor.topCenter);
      add(_comboText);
    } else {
      _comboText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;
  }

  void _addSimpleGround() {
    add(RectangleComponent(
      position: Vector2(0, size.y * 0.85),
      size: Vector2(size.x, size.y * 0.15),
      paint: Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.5),
      priority: 1,
    ));
  }

  Future<void> _addFoliageBackground() async {
    // 풀밭
    _addSimpleGround();

    // foliage 스프라이트: 좌우 나무 장식 (sprite_0001 ~ 0006 중 선택)
    final foliageFiles = [
      'kenney_foliage-sprites/PNG/Flat/sprite_0001.png',
      'kenney_foliage-sprites/PNG/Flat/sprite_0003.png',
      'kenney_foliage-sprites/PNG/Flat/sprite_0005.png',
      'kenney_foliage-sprites/PNG/Flat/sprite_0007.png',
    ];

    // 좌측 나무 (2개)
    for (int i = 0; i < 2; i++) {
      final sp = await loadSprite(foliageFiles[i]);
      final h = size.y * 0.55;
      add(SpriteComponent(
        sprite: sp,
        position: Vector2(-h * 0.15, size.y * 0.32 - h * 0.5 + i * h * 0.15),
        size: Vector2(h, h),
        priority: 1,
      ));
    }

    // 우측 나무 (2개)
    for (int i = 0; i < 2; i++) {
      final sp = await loadSprite(foliageFiles[i + 2]);
      final h = size.y * 0.50;
      add(SpriteComponent(
        sprite: sp,
        position: Vector2(size.x - h * 0.85, size.y * 0.35 - h * 0.5 + i * h * 0.15),
        size: Vector2(h, h),
        priority: 1,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    // 손 높이 = 어깨 각도 (0=바닥, 1=천장)
    final margin = size.y * 0.08;
    _hand.targetY = size.y - margin - currentPosition * (size.y * 0.75);

    // 과일 스폰
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnFruit();
    }

    // 충돌 체크
    final handR = 30.0 * config.targetSizeMultiplier;
    for (final fruit in children.whereType<_Fruit>().toList()) {
      if (fruit.collected) continue;
      final dx = (_hand.position.x - fruit.position.x).abs();
      final dy = (_hand.position.y - fruit.position.y).abs();
      if (dx < handR + fruit.fruitRadius && dy < handR + fruit.fruitRadius) {
        _collectFruit(fruit);
      }
      // 시간 초과로 사라짐
      if (fruit.life > fruit.maxLife) {
        fruit.removeFromParent();
        missed++;
        _combo = 0;
        if (config.cognitiveLevel.showCombo) _comboText.updateText('');
      }
    }
  }

  void _spawnFruit() {
    // 편측 무시 대응: 환측에 더 많이 스폰
    double xBias = 0.5;
    if (config.neglectSide == 'left') xBias = 0.35;
    if (config.neglectSide == 'right') xBias = 0.65;

    // ROM 비율에 따른 높이 범위
    final romR = config.romRatio;
    final minY = size.y * (1.0 - romR * 0.75) * 0.9;
    final maxY = size.y * 0.8;
    final y = minY + _rng.nextDouble() * (maxY - minY);

    final x = size.x * (0.2 + _rng.nextDouble() * 0.6 * (xBias > 0.5 ? 1.2 : 0.8));
    final isGold = _rng.nextDouble() < 0.12;
    final fruitType = _rng.nextInt(5); // 0=사과, 1=딸기, 2=해바라기, 3=포도, 4=오렌지

    final maxLife = (4.0 / config.speedMultiplier).clamp(2.0, 8.0);

    add(_Fruit(
      pos: Vector2(x.clamp(60, size.x - 60), y),
      fruitType: fruitType,
      isGold: isGold,
      maxLife: maxLife,
      sizeMultiplier: config.targetSizeMultiplier,
    ));
  }

  void _collectFruit(_Fruit fruit) {
    fruit.collected = true;
    _combo++;
    final points = fruit.isGold ? 5 : (fruit.fruitType == 2 ? 2 : 1); // 해바라기 2점
    final comboBonus = _combo >= 5 ? 2 : (_combo >= 3 ? 1 : 0);
    score += points + comboBonus;
    _scoreText.updateText('🌻 $score');

    if (config.cognitiveLevel.showCombo && _combo >= 3) {
      _comboText.updateText('${_combo}x COMBO!');
      _comboText.setColor(_combo >= 5 ? Colors.amber : Colors.lightGreenAccent);
    }

    // 수확 애니메이션 — 바구니로 이동
    fruit.add(SequenceEffect([
      MoveEffect.to(_basket.position.clone() + Vector2(0, -10),
          EffectController(duration: 0.3, curve: Curves.easeIn)),
      ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.15)),
      RemoveEffect(),
    ]));

    // 파티클 (인지 레벨에 따라)
    final pCount = config.cognitiveLevel.particleCount;
    if (pCount > 0) {
      _spawnCollectParticles(fruit.position.clone(), fruit.fruitColor, pCount);
    }

    // 떠오르는 점수
    add(_FloatingScore(
      pos: fruit.position.clone() + Vector2(0, -20),
      text: '+${points + comboBonus}',
      color: fruit.isGold ? Colors.amber : Colors.white,
    ));
  }

  void _spawnCollectParticles(Vector2 pos, Color color, int count) {
    add(ParticleSystemComponent(
      position: pos,
      particle: fp.Particle.generate(
        count: count,
        lifespan: 0.5,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 120 - 60, -_rng.nextDouble() * 100 - 40),
          acceleration: Vector2(0, 250),
          child: fp.ScalingParticle(to: 0,
            child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 3,
              paint: Paint()..color = color.withValues(alpha: 0.8))),
        ),
      ),
    ));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    final total = score + missed;
    onGameEnd(GameResult(
      gameId: 'sky_gardener', score: score, maxPossibleScore: total,
      accuracy: total > 0 ? score / total : 0.0, duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel, bodyPart: config.bodyPart,
      timestamp: DateTime.now(), calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle, hits: score, misses: missed,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);
  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Components ───

class _Hand extends PositionComponent {
  double targetY;
  final double sizeMultiplier;

  _Hand({required Vector2 gameSize, this.sizeMultiplier = 1.0})
      : targetY = gameSize.y * 0.5,
        super(position: Vector2(gameSize.x * 0.5, gameSize.y * 0.5),
            anchor: Anchor.center, priority: 10);

  @override
  void update(double dt) {
    super.update(dt);
    position.y += (targetY - position.y) * 10 * dt;
  }

  @override
  void render(Canvas canvas) {
    final r = 18.0 * sizeMultiplier;
    // 팔 (수직선)
    canvas.drawLine(Offset(0, r), Offset(0, r + 40),
        Paint()..color = const Color(0xFFFFCC80)..strokeWidth = 6..strokeCap = StrokeCap.round);
    // 손바닥
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = const Color(0xFFFFCC80));
    // 손바닥 하이라이트
    canvas.drawCircle(Offset(-r * 0.15, -r * 0.15), r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.3));
    // 손가락 5개
    for (int i = -2; i <= 2; i++) {
      final angle = -pi / 2 + i * 0.3;
      final fx = cos(angle) * r * 1.2;
      final fy = sin(angle) * r * 1.2;
      canvas.drawCircle(Offset(fx, fy), r * 0.28,
          Paint()..color = const Color(0xFFFFCC80));
    }
  }
}

class _Basket extends PositionComponent {
  _Basket({required Vector2 gameSize})
      : super(position: Vector2(gameSize.x * 0.5, gameSize.y * 0.92),
            anchor: Anchor.center, priority: 8);

  @override
  void render(Canvas canvas) {
    // 바구니
    final path = Path()
      ..moveTo(-50, -10)
      ..quadraticBezierTo(-55, 20, -30, 30)
      ..lineTo(30, 30)
      ..quadraticBezierTo(55, 20, 50, -10)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF8B6914));
    canvas.drawPath(path, Paint()..color = const Color(0xFFDEB887)..style = PaintingStyle.stroke..strokeWidth = 2);
    // 격자
    for (int i = -35; i <= 35; i += 14) {
      canvas.drawLine(Offset(i.toDouble(), -5), Offset(i * 0.7, 25),
          Paint()..color = const Color(0xFFDEB887).withValues(alpha: 0.4)..strokeWidth = 1);
    }
  }
}

class _Fruit extends PositionComponent {
  final int fruitType;
  final bool isGold;
  final double maxLife;
  final double sizeMultiplier;
  bool collected = false;
  double life = 0;
  double _pulse = 0;

  static const _fruitColors = [
    Color(0xFFE53935), // 사과: 빨강
    Color(0xFFE91E63), // 딸기: 분홍
    Color(0xFFFDD835), // 해바라기: 노랑
    Color(0xFF7B1FA2), // 포도: 보라
    Color(0xFFFF9800), // 오렌지: 주황
  ];

  _Fruit({required Vector2 pos, required this.fruitType, required this.isGold,
      required this.maxLife, required this.sizeMultiplier})
      : super(position: pos, anchor: Anchor.center, priority: 5);

  Color get fruitColor => isGold ? const Color(0xFFFFD700) : _fruitColors[fruitType % 5];
  double get fruitRadius => (14.0 + fruitType * 2) * sizeMultiplier;

  @override
  void update(double dt) {
    super.update(dt);
    if (!collected) {
      life += dt;
      _pulse += dt * 4;
      // 사라지기 전 점멸
      // 사라지기 전 크기 점멸로 경고
      if (life > maxLife * 0.7) {
        final blink = (sin(_pulse * 8) > 0) ? 1.0 : 0.7;
        scale = Vector2.all(blink);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final r = fruitRadius;
    // 글로우
    canvas.drawCircle(Offset.zero, r + 4,
        Paint()..color = fruitColor.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    switch (fruitType) {
      case 0: _drawApple(canvas, r); break;
      case 1: _drawStrawberry(canvas, r); break;
      case 2: _drawSunflower(canvas, r); break;
      case 3: _drawGrape(canvas, r); break;
      default: _drawOrange(canvas, r);
    }

    // 골드 반짝
    if (isGold) {
      canvas.drawCircle(Offset(r * 0.3, -r * 0.3), 3,
          Paint()..color = Colors.white.withValues(alpha: 0.9));
      canvas.drawCircle(Offset(-r * 0.2, -r * 0.5), 2,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  void _drawApple(Canvas canvas, double r) {
    canvas.drawCircle(Offset.zero, r, Paint()..color = fruitColor);
    canvas.drawCircle(Offset(-r * 0.2, -r * 0.2), r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.25));
    // 꼭지
    canvas.drawLine(Offset(0, -r), Offset(2, -r - 6),
        Paint()..color = const Color(0xFF4E342E)..strokeWidth = 2..strokeCap = StrokeCap.round);
    // 잎
    final leafPath = Path()..moveTo(2, -r - 4)..quadraticBezierTo(10, -r - 10, 8, -r - 2);
    canvas.drawPath(leafPath, Paint()..color = const Color(0xFF4CAF50)..strokeWidth = 1.5..style = PaintingStyle.stroke);
  }

  void _drawStrawberry(Canvas canvas, double r) {
    final path = Path()
      ..moveTo(0, -r * 0.8)
      ..quadraticBezierTo(r, -r * 0.3, r * 0.6, r * 0.8)
      ..lineTo(0, r)
      ..lineTo(-r * 0.6, r * 0.8)
      ..quadraticBezierTo(-r, -r * 0.3, 0, -r * 0.8);
    canvas.drawPath(path, Paint()..color = fruitColor);
    // 씨앗 점
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(-r * 0.2 + i * r * 0.15, r * 0.1 + (i % 2) * r * 0.2), 1.5,
          Paint()..color = Colors.yellow.withValues(alpha: 0.6));
    }
  }

  void _drawSunflower(Canvas canvas, double r) {
    // 꽃잎
    for (int i = 0; i < 10; i++) {
      final angle = i * pi / 5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cos(angle) * r * 0.6, sin(angle) * r * 0.6), width: r * 0.5, height: r * 0.25),
        Paint()..color = fruitColor,
      );
    }
    // 중심
    canvas.drawCircle(Offset.zero, r * 0.4, Paint()..color = const Color(0xFF5D4037));
  }

  void _drawGrape(Canvas canvas, double r) {
    for (int row = 0; row < 3; row++) {
      final count = 3 - row;
      for (int i = 0; i < count; i++) {
        final ox = (i - (count - 1) / 2) * r * 0.5;
        final oy = row * r * 0.45 - r * 0.3;
        canvas.drawCircle(Offset(ox, oy), r * 0.3, Paint()..color = fruitColor);
        canvas.drawCircle(Offset(ox - 1, oy - 1), r * 0.1, Paint()..color = Colors.white.withValues(alpha: 0.3));
      }
    }
  }

  void _drawOrange(Canvas canvas, double r) {
    canvas.drawCircle(Offset.zero, r, Paint()..color = fruitColor);
    canvas.drawCircle(Offset(-r * 0.15, -r * 0.15), r * 0.35, Paint()..color = Colors.white.withValues(alpha: 0.2));
    // 꼭지
    canvas.drawCircle(Offset(0, -r + 2), 3, Paint()..color = const Color(0xFF4CAF50));
  }
}

class _SkyBackground extends PositionComponent {
  final Vector2 _gs;
  _SkyBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: -10);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFF80DEEA), Color(0xFF4CAF50)],
      stops: [0.0, 0.45, 0.75, 1.0],
    ).createShader(rect));
  }
}

class _Cloud extends PositionComponent {
  final double speed;
  final double gameWidth;
  _Cloud({required Vector2 pos, required this.speed, required this.gameWidth})
      : super(position: pos, priority: 0);

  @override
  void update(double dt) {
    super.update(dt);
    position.x += speed * dt;
    if (position.x > gameWidth + 80) position.x = -80;
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 60, height: 20), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-15, -8), width: 30, height: 18), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(15, -5), width: 35, height: 16), p);
  }
}

class _FloatingScore extends PositionComponent {
  final String text;
  final Color color;
  double _life = 0;
  _FloatingScore({required Vector2 pos, required this.text, required this.color})
      : super(position: pos, anchor: Anchor.center, priority: 20);
  @override
  void update(double dt) {
    super.update(dt); _life += dt; position.y -= 50 * dt;
    if (_life > 0.7) removeFromParent();
  }
  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 0.7).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: 22, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

class _HudText extends PositionComponent {
  String _text; Color _color; final double fontSize;
  _HudText({required String text, required Vector2 pos, required Anchor anchor,
      Color color = Colors.white, this.fontSize = 22})
      : _text = text, _color = color, super(position: pos, anchor: anchor, priority: 100);
  void updateText(String t) => _text = t;
  void setColor(Color c) => _color = c;
  @override
  void render(Canvas canvas) {
    if (_text.isEmpty) return;
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: _color, fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
    )).render(canvas, _text, Vector2.zero(), anchor: anchor);
  }
}

// ─── Flutter Wrapper ───

class SkyGardenerGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const SkyGardenerGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<SkyGardenerGame> createState() => _SkyGardenerGameState();
}

class _SkyGardenerGameState extends State<SkyGardenerGame> {
  late SkyGardenerFlameGame _game;
  late GameMotorController _motor;
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);

    final stream = _isSim ? null : widget.bluetoothService.dataStream
        .map((s) => double.tryParse(s.trim())).where((v) => v != null)
        .map((a) => widget.config.normalizer.normalize(a!));

    _game = SkyGardenerFlameGame(inputStream: stream, config: widget.config, onGameEnd: (r) {
      _motor.safeStop();
      _motor.dispose();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
    });

    // 모터 연동 시작
    if (!_isSim) {
      _motor.selectJoint(widget.config.bodyPart);
      if (widget.config.needsCpmAssist) {
        _motor.startCPM(widget.config.normalizer.maxAngle, widget.config.normalizer.minAngle);
      }
      _motor.startWatchdog();
    }
  }

  @override
  void dispose() {
    _motor.safeStop();
    _motor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          Column(children: [
            Expanded(child: GameWidget(game: _game)),
            if (_isSim) _simSlider(),
            _controlBar(loc),
          ]),
          // 긴급 정지 FAB
          Positioned(right: 16, bottom: 80,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: () { _motor.emergencyStop(); _game.endGame(); },
              child: const Icon(Icons.stop, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  GameConfig get config => widget.config;

  Widget _simSlider() => Container(
    color: const Color(0xFF1a2e1a), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Row(children: [
      const RotatedBox(quarterTurns: 0, child: Text('⬇ 아래', style: TextStyle(color: Colors.white54, fontSize: 12))),
      Expanded(child: SliderTheme(
        data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
            trackHeight: 8, activeTrackColor: Colors.lightGreenAccent, thumbColor: Colors.white, inactiveTrackColor: Colors.white24),
        child: Slider(value: _simValue, onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); }),
      )),
      const Text('위 ⬆', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]),
  );

  Widget _controlBar(AppLocalizations loc) => Container(
    color: const Color(0xFF1a2e1a), padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
          onPressed: () => _game.isRunning = !_game.isRunning, icon: const Icon(Icons.pause), label: Text(loc.pauseGame)),
      const SizedBox(width: 16),
      OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
          onPressed: () { _motor.safeStop(); _game.endGame(); }, icon: const Icon(Icons.stop), label: Text(loc.stop)),
    ]),
  );
}
