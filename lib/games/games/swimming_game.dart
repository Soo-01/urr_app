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
import '../kenney_atlas.dart';

/// ============================================================================
/// [S6] 수영 선수 (Swimming)
/// 관절: 어깨 굽힘/폄 (lShoulderEF)
/// 메카닉:
///   • 어깨 각도값 → 수영 선수 Y 위치 (상하 레인 선택)
///   • 어깨 각도 변화율(|dAngle/dt|) → 스트로크 파워 → 전진 속도
///   • 팔을 멈추면 물 저항으로 속도 감소 (최소 15% 유지)
///   • 빠르게 반복 운동할수록 빠르게 전진 → 능동적 ROM 훈련 보상
/// 임상 근거: ARAT 어깨 굽힘 컴포넌트 — 수직 도달 + 반복 능동 ROM 훈련
/// ============================================================================

class SwimmingFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double _normAngle = 0.5;
  double _lastNormAngle = 0.5;
  double _strokePower = 0.0;  // 0~5, 평활화된 각도 변화율
  double _scrollSpeed = 0.0;  // 현재 전진 속도 (px/s)
  double get scrollSpeed => _scrollSpeed;

  int score = 0;
  int hits = 0;
  int misses = 0;
  int mistakes = 0;
  int _combo = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  double _spawnTimer = 0;
  double _spawnInterval = 1.2;

  late _Swimmer _swimmer;
  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _comboText;
  late _SpeedBar _speedBar;

  SwimmingFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  }) : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF003366);

  double get _hitRadius {
    const radii = [55.0, 48.0, 40.0, 34.0, 28.0];
    return radii[(config.difficultyLevel - 1).clamp(0, 4)] * config.targetSizeMultiplier;
  }

  double get _objectSpeed {
    const speeds = [80.0, 110.0, 140.0, 170.0, 200.0];
    return speeds[(config.difficultyLevel - 1).clamp(0, 4)] * config.speedMultiplier;
  }

  @override
  Future<void> onLoad() async {
    // 배경
    add(_OceanBackground(gameSize: size));
    add(_BubbleEmitter(gameSize: size));

    // 수영 레인 라인
    for (int i = 1; i < 4; i++) {
      add(_LaneLine(y: size.y * i / 4, width: size.x));
    }

    // 수영 선수
    _swimmer = _Swimmer(gameSize: size, sizeMultiplier: config.targetSizeMultiplier);
    add(_swimmer);

    // HUD
    _scoreText = _HudText('⭐ 0', Vector2(20, 14), Anchor.topLeft, 22);
    add(_scoreText);

    _timerText = _HudText('', Vector2(size.x - 20, 14), Anchor.topRight, 22);
    if (config.cognitiveLevel.showTimer) add(_timerText);

    _comboText = _HudText('', Vector2(size.x / 2, 14), Anchor.topCenter, 18);
    if (config.cognitiveLevel.showCombo) add(_comboText);

    // 속도 게이지
    _speedBar = _SpeedBar(Vector2(size.x / 2, size.y - 16), size.x * 0.44);
    add(_speedBar);

    // 인지 레벨 1: 가이드 텍스트
    if (config.cognitiveLevel.level == 1) {
      add(_HudText('위아래로 움직이세요', Vector2(size.x / 2, size.y - 32),
          Anchor.bottomCenter, 14));
    }

    _applyDifficulty();
    _sub = inputStream?.listen((v) {
      _normAngle = v.clamp(0.0, 1.0);
      _updateSwimmer();
    });
    isRunning = true;
  }

  void _applyDifficulty() {
    const intervals = [2.0, 1.6, 1.2, 0.9, 0.7];
    _spawnInterval = intervals[(config.difficultyLevel - 1).clamp(0, 4)] / config.speedMultiplier;
  }

  void _updateSwimmer() {
    final margin = size.y * 0.08;
    // 각도 1.0(굽힘=어깨 올림) → 화면 위, 0.0(폄) → 화면 아래
    _swimmer.targetY = size.y - margin - _normAngle * (size.y - margin * 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    // 물 저항 / 스트로크 파워 → 전진 속도
    final dAngle = (_normAngle - _lastNormAngle).abs();
    _lastNormAngle = _normAngle;
    final instantVel = dt > 0.001 ? (dAngle / dt).clamp(0.0, 5.0) : _strokePower;
    _strokePower += (instantVel - _strokePower) * (4.0 * dt).clamp(0.0, 1.0);
    final minSpeed = _objectSpeed * 0.15;
    final targetScroll = minSpeed + (_strokePower / 5.0) * (_objectSpeed - minSpeed);
    _scrollSpeed += (targetScroll - _scrollSpeed) * (2.5 * dt).clamp(0.0, 1.0);
    _speedBar.setRatio(_scrollSpeed / _objectSpeed);

    // 스폰
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnObject();
    }

    // 충돌 판정
    final swimY = _swimmer.position.y;
    for (final obj in children.whereType<_WaterObject>().toList()) {
      if (obj.collected) continue;
      final dx = obj.position.x - _swimmer.position.x;
      final dy = (obj.position.y - swimY).abs();
      if (dx < 0 && dx > -_hitRadius * 2 && dy < _hitRadius) {
        _onCollision(obj);
      }
      if (obj.position.x < -60 && !obj.collected) {
        obj.collected = true;
        obj.removeFromParent();
        if (obj.isTarget) {
          misses++;
          _combo = 0;
          if (config.cognitiveLevel.showCombo) _comboText.updateText('');
        }
      }
    }
  }

  void _spawnObject() {
    final avoidRatio = config.cognitiveLevel.level == 1 ? 0.0
        : config.cognitiveLevel.level == 2 ? 0.25
        : 0.35 + config.difficultyLevel * 0.02;
    final isAvoid = _rng.nextDouble() < avoidRatio;

    // ROM 비율 기반 Y 범위
    final romR = config.romRatio;
    final margin = size.y * 0.1;
    final yRange = (size.y - margin * 2) * romR;
    final yCenter = size.y / 2;
    final y = yCenter + (_rng.nextDouble() - 0.5) * yRange;

    add(_WaterObject(
      pos: Vector2(size.x + 40, y.clamp(margin, size.y - margin)),
      isTarget: !isAvoid,
      radius: _hitRadius * 0.7,
    ));
  }

  void _onCollision(_WaterObject obj) {
    obj.collected = true;
    if (obj.isTarget) {
      hits++;
      _combo++;
      final comboBonus = _combo >= 5 ? 3 : (_combo >= 3 ? 2 : 1);
      score += comboBonus;
      _scoreText.updateText('⭐ $score');

      if (_combo >= 3 && config.cognitiveLevel.showCombo) {
        _comboText.updateText('$_combo콤보!');
      }

      if (config.cognitiveLevel.particleCount > 0) {
        add(ParticleSystemComponent(
          position: obj.position.clone(),
          particle: fp.Particle.generate(
            count: config.cognitiveLevel.particleCount,
            lifespan: 0.5,
            generator: (i) => fp.AcceleratedParticle(
              speed: Vector2(_rng.nextDouble() * 100 - 50, _rng.nextDouble() * 100 - 100),
              acceleration: Vector2(0, 200),
              child: fp.ScalingParticle(
                to: 0,
                child: fp.CircleParticle(
                  radius: 2 + _rng.nextDouble() * 3,
                  paint: Paint()..color = const Color(0xFFFFD700),
                ),
              ),
            ),
          ),
        ));
      }

      add(_FloatingLabel(pos: obj.position.clone(),
          text: _combo >= 3 ? '+$_combo!' : '+1',
          color: _combo >= 3 ? Colors.amber : Colors.greenAccent));
    } else {
      mistakes++;
      _combo = 0;
      if (config.cognitiveLevel.showCombo) _comboText.updateText('');
      score = (score - 1).clamp(0, 9999);
      _scoreText.updateText('⭐ $score');
      add(_FloatingLabel(pos: obj.position.clone(), text: '⚡ -1', color: Colors.redAccent));
    }

    obj.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.08)),
      RemoveEffect(),
    ]));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    final total = hits + misses;
    onGameEnd(GameResult(
      gameId: 'swimming', score: score,
      maxPossibleScore: (total + hits) * 3,
      accuracy: total > 0 ? hits / total : 0.0,
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart, timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: hits, misses: misses + mistakes,
    ));
  }

  void setSimPosition(double v) {
    _normAngle = v.clamp(0.0, 1.0);
    _updateSwimmer();
  }

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Components ───

class _Swimmer extends PositionComponent with HasGameReference<SwimmingFlameGame> {
  double targetY;
  final double sizeMultiplier;
  Sprite? _sprite;
  double _bobPhase = 0.0;

  _Swimmer({required Vector2 gameSize, this.sizeMultiplier = 1.0})
      : targetY = gameSize.y / 2,
        super(
          position: Vector2(gameSize.x * 0.2, gameSize.y / 2),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    // fish-pack: 물고기 중 가장 큰 grey_long_a를 수영 선수로 사용 (옆으로 긴 형태)
    final atlas = await FishAtlas.load();
    _sprite = atlas.spriteOrNull('fish_grey_long_a')
        ?? atlas.spriteOrNull('fish_blue')
        ?? await game.loadSprite('kenney_space-shooter-redux/PNG/playerShip2_blue.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += (targetY - position.y) * 10 * dt;
    // 정지 중에도 수영 동작 표현 (미세 상하 진동)
    _bobPhase += dt * 3.0;
    position.y += sin(_bobPhase) * 0.5;
  }

  @override
  void render(Canvas canvas) {
    const w = 72.0;
    const h = 48.0;

    // 물 흔적 — 수영 속도에 따라 강도 변화
    final speedRatio = (game.scrollSpeed / 200.0).clamp(0.0, 1.0);
    final trailCount = 3 + (speedRatio * 5).toInt();
    for (int i = 1; i <= trailCount; i++) {
      final a = (1 - i / (trailCount + 1)) * (0.12 + speedRatio * 0.3);
      final trailW = 5.0 + speedRatio * 5;
      final trailH = 2.5 + speedRatio * 2;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-w * 0.5 - i * 10, 0), width: trailW, height: trailH),
        Paint()..color = Colors.cyanAccent.withValues(alpha: a),
      );
    }

    // 글로우
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w + 16, height: h + 12),
      Paint()..color = Colors.cyanAccent.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (_sprite != null) {
      // 물고기는 이미 옆을 향하므로 그대로 렌더링 (오른쪽→왼쪽 방향 반전)
      canvas.save();
      canvas.scale(-1, 1); // 물고기가 왼쪽을 향하도록 수평 반전
      _sprite!.render(canvas, position: Vector2(-w / 2, -h / 2), size: Vector2(w, h));
      canvas.restore();
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.8, height: h * 0.6),
          Paint()..color = Colors.cyanAccent);
    }
  }
}

class _WaterObject extends PositionComponent with HasGameReference<SwimmingFlameGame> {
  final bool isTarget;
  final double radius;
  bool collected = false;
  double _wobble = 0;
  Sprite? _sprite;

  // 수집 물고기: fish_blue/orange/pink/red/green 중 랜덤
  static const _collectNames = FishAtlas.collectibles;
  // 장애물 해골물고기
  static const _obstacleNames = FishAtlas.obstacles;

  _WaterObject({required Vector2 pos, required this.isTarget, required this.radius})
      : super(position: pos, anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    final atlas = await FishAtlas.load();
    final rng = game.config.normalizer.hashCode; // 결정적 인덱스 (위치 기반)
    if (isTarget) {
      final idx = (position.y.toInt().abs() + rng) % _collectNames.length;
      _sprite = atlas.spriteOrNull(_collectNames[idx]);
    } else {
      final idx = (position.y.toInt().abs() + rng) % _obstacleNames.length;
      _sprite = atlas.spriteOrNull(_obstacleNames[idx]);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (collected) return;
    position.x -= game.scrollSpeed * dt;
    _wobble += dt * (isTarget ? 2.5 : 1.8);
    // 물고기: 살짝 위아래 유영, 해골물고기: 더 불규칙하게
    if (isTarget) {
      position.y += sin(_wobble) * 0.4;
    } else {
      position.y += sin(_wobble * 1.3) * 0.8;
    }
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;
    final glowColor = isTarget ? const Color(0xFF4FC3F7) : const Color(0xFFEF5350);
    final pulse = sin(_wobble) * 0.08 + 1.0;

    // 글로우
    canvas.drawCircle(Offset.zero, radius * 1.3 * pulse,
        Paint()..color = glowColor.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    if (_sprite != null) {
      final r = radius * pulse;
      // 물고기가 진행 방향(왼쪽)을 바라보도록
      canvas.save();
      canvas.scale(-1, 1);
      _sprite!.render(canvas, position: Vector2(-r * 1.2, -r), size: Vector2(r * 2.4, r * 2.0));
      canvas.restore();
    } else {
      canvas.drawCircle(Offset.zero, radius,
          Paint()..color = glowColor.withValues(alpha: 0.85));
    }

    // 인지 레벨 2+: 장애물 경고 (빨간 X 표시)
    if (!isTarget && game.config.cognitiveLevel.level >= 2) {
      TextPaint(style: const TextStyle(
        fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold))
          .render(canvas, '✕', Vector2(0, -radius * 1.6), anchor: Anchor.center);
    }
  }
}

class _OceanBackground extends PositionComponent with HasGameReference<SwimmingFlameGame> {
  final Vector2 _gs;
  double _wave = 0;
  double _scrollOffset = 0;

  // fish-pack 배경 장식 스프라이트 (해조류·바위 등)
  final List<_BgDecor> _decors = [];
  bool _spritesLoaded = false;

  _OceanBackground({required Vector2 gameSize})
      : _gs = gameSize, super(priority: -10);

  @override
  Future<void> onLoad() async {
    final atlas = await FishAtlas.load();
    final rng = Random(42);

    // 바닥 해조류 — 화면 하단 20% 영역
    for (final name in [...FishAtlas.seaweeds, ...FishAtlas.rocks]) {
      final sprite = atlas.spriteOrNull(name);
      if (sprite == null) continue;
      for (int j = 0; j < 3; j++) {
        _decors.add(_BgDecor(
          sprite: sprite,
          x: rng.nextDouble() * _gs.x * 2,   // 넓은 범위에 배치 (스크롤)
          y: _gs.y * 0.75 + rng.nextDouble() * _gs.y * 0.2,
          size: 36 + rng.nextDouble() * 24,
          scrollFactor: 0.3 + rng.nextDouble() * 0.2, // 시차 스크롤
        ));
      }
    }

    // 배경 바위 — 화면 상단 10% 영역 (천장)
    final rockSprite = atlas.spriteOrNull('background_rock_a');
    if (rockSprite != null) {
      for (int j = 0; j < 4; j++) {
        _decors.add(_BgDecor(
          sprite: rockSprite,
          x: rng.nextDouble() * _gs.x * 2,
          y: rng.nextDouble() * _gs.y * 0.08,
          size: 40 + rng.nextDouble() * 20,
          scrollFactor: 0.15,
        ));
      }
    }

    _spritesLoaded = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speedRatio = game.scrollSpeed / 200.0;
    _wave += dt * (0.4 + speedRatio * 1.2);
    _scrollOffset += game.scrollSpeed * dt * 0.35; // 배경 패럴랙스
  }

  @override
  void render(Canvas canvas) {
    // 깊은 바다 그라디언트
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF001022), Color(0xFF001A3C), Color(0xFF002A55), Color(0xFF003366)],
      stops: [0.0, 0.3, 0.7, 1.0],
    ).createShader(rect));

    // fish-pack 배경 장식 (해조류·바위) — 패럴랙스 스크롤
    if (_spritesLoaded) {
      for (final d in _decors) {
        final x = (d.x - _scrollOffset * d.scrollFactor) % (_gs.x + d.size);
        canvas.save();
        canvas.translate(x, d.y);
        d.sprite.render(canvas,
            position: Vector2(-d.size / 2, -d.size / 2),
            size: Vector2.all(d.size),
            overridePaint: Paint()..color = Colors.white.withValues(alpha: 0.75));
        canvas.restore();
      }
    }

    // 물결 레이어
    final wavePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double y = 50; y < _gs.y; y += 55) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < _gs.x; x += 20) {
        path.lineTo(x, y + sin(_wave + x / 65) * 4);
      }
      canvas.drawPath(path, wavePaint);
    }

    // 부유 기포 (fish-pack 버블 느낌)
    final bubblePaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 12; i++) {
      final bx = (i * 97.3 + _scrollOffset * 0.1) % _gs.x;
      final by = (_wave * 20 + i * 65.7) % _gs.y;
      canvas.drawCircle(Offset(bx, by), 2.5 + (i % 4), bubblePaint);
    }
  }
}

class _BgDecor {
  final Sprite sprite;
  final double x, y, size, scrollFactor;
  const _BgDecor({
    required this.sprite, required this.x, required this.y,
    required this.size, required this.scrollFactor,
  });
}

/// 지속적으로 기포를 상승시키는 배경 컴포넌트
class _BubbleEmitter extends PositionComponent with HasGameReference<SwimmingFlameGame> {
  final Vector2 _gs;
  final Random _rng = Random();
  final List<_Bubble> _bubbles = [];
  Sprite? _bubbleSprite;
  double _spawnTimer = 0;

  _BubbleEmitter({required Vector2 gameSize})
      : _gs = gameSize, super(priority: -5);

  @override
  Future<void> onLoad() async {
    final atlas = await FishAtlas.load();
    _bubbleSprite = atlas.spriteOrNull('bubble_a')
        ?? atlas.spriteOrNull('bubble_b');
    // 초기 기포 배치
    for (int i = 0; i < 8; i++) {
      _bubbles.add(_Bubble(
        x: _rng.nextDouble() * _gs.x,
        y: _rng.nextDouble() * _gs.y,
        size: 6 + _rng.nextDouble() * 12,
        speed: 20 + _rng.nextDouble() * 30,
        wobble: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer += dt;
    if (_spawnTimer > 0.4) {
      _spawnTimer = 0;
      _bubbles.add(_Bubble(
        x: _rng.nextDouble() * _gs.x,
        y: _gs.y + 10,
        size: 5 + _rng.nextDouble() * 14,
        speed: 18 + _rng.nextDouble() * 28,
        wobble: _rng.nextDouble() * pi * 2,
      ));
    }
    _bubbles.removeWhere((b) => b.y < -20);
    for (final b in _bubbles) {
      b.y -= b.speed * dt;
      b.wobble += dt * 1.5;
      b.x += sin(b.wobble) * 0.6;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final b in _bubbles) {
      final alpha = ((b.y / _gs.y) * 0.5 + 0.1).clamp(0.05, 0.55);
      if (_bubbleSprite != null) {
        _bubbleSprite!.render(canvas,
          position: Vector2(b.x - b.size / 2, b.y - b.size / 2),
          size: Vector2.all(b.size),
          overridePaint: Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(Offset(b.x, b.y), b.size / 2,
          Paint()..color = Colors.cyanAccent.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }
}

class _Bubble {
  double x, y, size, speed, wobble;
  _Bubble({required this.x, required this.y, required this.size,
      required this.speed, required this.wobble});
}

class _LaneLine extends PositionComponent {
  @override
  final double width;
  _LaneLine({required double y, required this.width})
      : super(position: Vector2(0, y), priority: -5);

  @override
  void render(Canvas canvas) {
    // 점선 레인 구분선
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    double x = 0;
    while (x < width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 15, 0), paint);
      x += 30;
    }
  }
}

class _HudText extends PositionComponent {
  String _text;
  final double fontSize;
  _HudText(this._text, Vector2 pos, Anchor anc, this.fontSize)
      : super(position: pos, anchor: anc, priority: 100);
  void updateText(String t) => _text = t;
  @override
  void render(Canvas canvas) {
    if (_text.isEmpty) return;
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
    )).render(canvas, _text, Vector2.zero(), anchor: anchor);
  }
}

class _FloatingLabel extends PositionComponent {
  final String text;
  final Color color;
  double _life = 0;

  _FloatingLabel({required Vector2 pos, required this.text, required this.color})
      : super(position: pos, anchor: Anchor.center, priority: 20);

  @override
  void update(double dt) {
    super.update(dt); _life += dt; position.y -= 50 * dt;
    if (_life > 0.8) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 0.8).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: 20, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

class _SpeedBar extends PositionComponent with HasGameReference<SwimmingFlameGame> {
  double _ratio = 0.15;
  final double barWidth;

  _SpeedBar(Vector2 pos, this.barWidth)
      : super(position: pos, anchor: Anchor.center, priority: 100);

  void setRatio(double r) => _ratio = r.clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    // 배경 트랙
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: barWidth, height: 9),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white12,
    );
    // 속도 채움
    if (_ratio > 0) {
      final fillW = barWidth * _ratio;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-barWidth / 2, -4.5, fillW, 9),
          const Radius.circular(4),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.cyan.withValues(alpha: 0.7), Colors.cyanAccent],
          ).createShader(Rect.fromLTWH(-barWidth / 2, -4.5, fillW, 9))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    // 레이블
    TextPaint(style: GoogleFonts.orbitron(fontSize: 9, color: Colors.cyanAccent.withValues(alpha: 0.7)))
        .render(canvas, 'SPD', Vector2(-barWidth / 2 - 28, 0), anchor: Anchor.centerLeft);
  }
}

// ─── Flutter Wrapper ───

class SwimmingGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const SwimmingGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<SwimmingGame> createState() => _SwimmingGameState();
}

class _SwimmingGameState extends State<SwimmingGame> {
  late SwimmingFlameGame _game;
  late GameMotorController _motor;
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);

    final stream = _isSim
        ? null
        : widget.bluetoothService.dataStream
            .map((s) => double.tryParse(s.trim()))
            .where((v) => v != null)
            .map((a) => widget.config.normalizer.normalize(a!));

    _game = SwimmingFlameGame(
      inputStream: stream,
      config: widget.config,
      onGameEnd: (r) {
        _motor.safeStop(); _motor.dispose();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
        }
      },
    );

    if (!_isSim) {
      _motor.selectJoint(widget.config.bodyPart);
      _motor.startWatchdog();
    }
  }

  @override
  void dispose() { _motor.safeStop(); _motor.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(children: [
        Column(children: [
          Expanded(child: GameWidget(game: _game)),
          if (_isSim) _simSlider(),
          _controlBar(loc),
        ]),
        Positioned(
          right: 16, bottom: 80,
          child: FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () { _motor.emergencyStop(); _game.endGame(); },
            child: const Icon(Icons.stop, color: Colors.white, size: 32),
          ),
        ),
      ]),
    );
  }

  Widget _simSlider() => Container(
    color: const Color(0xFF003366),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Column(children: [
      Text('시뮬레이션: 어깨 각도 (${(_simValue * 100).toInt()}%)',
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
      SliderTheme(
        data: SliderThemeData(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
          trackHeight: 8, activeTrackColor: Colors.cyanAccent,
          thumbColor: Colors.white, inactiveTrackColor: Colors.white24,
        ),
        child: Slider(
          value: _simValue,
          onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); },
        ),
      ),
    ]),
  );

  Widget _controlBar(AppLocalizations loc) => Container(
    color: const Color(0xFF003366),
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
        onPressed: () => setState(() => _game.isRunning = !_game.isRunning),
        icon: const Icon(Icons.pause), label: Text(loc.pauseGame),
      ),
      const SizedBox(width: 16),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent)),
        onPressed: () { _motor.safeStop(); _game.endGame(); },
        icon: const Icon(Icons.stop), label: Text(loc.stop),
      ),
    ]),
  );
}
