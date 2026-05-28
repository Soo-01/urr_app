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
import '../game_result_screen.dart';
import '../kenney_atlas.dart';

/// ============================================================================
/// [C3] 오브젝트 치기/피하기 (Object Hit & Avoid) — 수중 테마
/// KINARM Object Hit and Avoid 기반
///
/// 비주얼: PDF 컨셉 아트 기반 수중 산호초 씬
///   • 빨간 물고기 = 타겟 (터치 → 물방울 파티클)
///   • 파란 해파리 = 장애물 (접촉 → 전기 섬광 이펙트)
///   • 배경: 깊은 바다 + 산호 + 볼류메트릭 빛 기둥
/// MMSE 스케일링:
///   Level 1: 단일 빨간 물고기, 단순 배경
///   Level 2: 물고기+해파리, 점수 표시
///   Level 3: 풀 산호초, 콤보 보너스, 풍부한 배경
/// ============================================================================

const double _cursorRadius = 22.0;

class ObjectHitAvoidGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double _normAngle = 0.5;
  double _cursorX = 0;

  int score = 0;
  int hits = 0;
  int misses = 0;
  int mistakes = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  double _spawnTimer = 0;
  double _spawnInterval = 1.2;
  int _combo = 0;

  late _Crosshair _cursor;
  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _comboText;
  late _HudText _instructionText;

  ObjectHitAvoidGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  }) : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF001428);

  double get _objSize {
    const radii = [40.0, 34.0, 28.0, 24.0, 20.0];
    return radii[(config.difficultyLevel - 1).clamp(0, 4)] * config.targetSizeMultiplier;
  }

  @override
  Future<void> onLoad() async {
    _applyDifficulty();

    // ── 수중 배경 ──
    add(_UnderwaterBackground(gameSize: size, cogLevel: config.cognitiveLevel.level));

    // 커서 가이드 라인 (해저 바닥)
    add(_SeaFloorLine(gameSize: size));

    // 커서 (십자선)
    _cursorX = size.x / 2;
    _cursor = _Crosshair(gameSize: size, cogLevel: config.cognitiveLevel.level);
    add(_cursor);

    // HUD
    _scoreText = _HudText('🐟 0', Vector2(20, 14), Anchor.topLeft, 22);
    _timerText = _HudText('${timeRemaining.toInt()}s', Vector2(size.x - 20, 14), Anchor.topRight, 22);
    _comboText = _HudText('', Vector2(size.x / 2, 14), Anchor.topCenter, 18);
    _instructionText = _HudText(
      config.cognitiveLevel.level == 1 ? '빨간 물고기를 잡으세요!' : '🐟 잡기  🪼 피하기',
      Vector2(size.x / 2, size.y - 28),
      Anchor.bottomCenter,
      14,
    );

    add(_scoreText);
    if (config.cognitiveLevel.showTimer) add(_timerText);
    if (config.cognitiveLevel.showCombo) add(_comboText);
    add(_instructionText);

    _updateCursor();
    _sub = inputStream?.listen((v) {
      _normAngle = v.clamp(0.0, 1.0);
      _updateCursor();
    });
    isRunning = true;
  }

  void _applyDifficulty() {
    const intervals = [1.6, 1.2, 0.9, 0.7, 0.5];
    _spawnInterval = intervals[(config.difficultyLevel - 1).clamp(0, 4)] * (1 / config.speedMultiplier);
  }

  void _updateCursor() {
    const margin = 60.0;
    _cursorX = margin + _normAngle * (size.x - margin * 2);
    _cursor.targetX = _cursorX;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnObject();
    }

    final cursorPos = Vector2(_cursor.position.x, size.y * 0.82);
    for (final obj in children.whereType<_UnderwaterObject>().toList()) {
      if (obj.collected) continue;
      final dx = obj.position.x - cursorPos.x;
      final dy = obj.position.y - cursorPos.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < _objSize + _cursorRadius) {
        _onCollision(obj);
      }
      if (obj.position.y > size.y + 50 && !obj.collected) {
        obj.collected = true;
        obj.removeFromParent();
        if (obj.isTarget) {
          misses++;
          _combo = 0;
          _comboText.updateText('');
        }
      }
    }
  }

  void _spawnObject() {
    const margin = 60.0;
    final x = margin + _rng.nextDouble() * (size.x - margin * 2);

    final avoidRatio = config.cognitiveLevel.level == 1 ? 0.0
        : config.cognitiveLevel.level == 2 ? 0.28
        : 0.38 + config.difficultyLevel * 0.02;
    final isAvoid = _rng.nextDouble() < avoidRatio;

    final speed = (140 + config.difficultyLevel * 36) * config.speedMultiplier;

    add(_UnderwaterObject(
      pos: Vector2(x, -_objSize),
      isTarget: !isAvoid,
      speed: speed,
      radius: _objSize,
      cognitiveLevel: config.cognitiveLevel.level,
    ));
  }

  void _onCollision(_UnderwaterObject obj) {
    obj.collected = true;

    if (obj.isTarget) {
      hits++;
      _combo++;
      final comboBonus = _combo >= 5 ? 3 : (_combo >= 3 ? 2 : 1);
      score += comboBonus;
      _scoreText.updateText('🐟 $score');

      if (_combo >= 3 && config.cognitiveLevel.showCombo) {
        _comboText.updateText('$_combo콤보!');
      }

      // 물방울 파티클
      if (config.cognitiveLevel.particleCount > 0) {
        add(ParticleSystemComponent(
          position: obj.position.clone(),
          particle: fp.Particle.generate(
            count: config.cognitiveLevel.particleCount + 4,
            lifespan: 0.6,
            generator: (i) {
              final angle = _rng.nextDouble() * pi * 2;
              final spd = 60 + _rng.nextDouble() * 100;
              return fp.AcceleratedParticle(
                speed: Vector2(cos(angle) * spd, sin(angle) * spd),
                acceleration: Vector2(0, 120),
                child: fp.ScalingParticle(
                  to: 0,
                  child: fp.CircleParticle(
                    radius: 2 + _rng.nextDouble() * 3,
                    paint: Paint()..color = [
                      const Color(0xFF4FC3F7),
                      const Color(0xFF81D4FA),
                      Colors.white,
                      const Color(0xFFB3E5FC),
                    ][i % 4],
                  ),
                ),
              );
            },
          ),
        ));
      }

      add(_FloatingLabel(
        pos: obj.position.clone(),
        text: _combo >= 3 ? '+$_combo 콤보!' : '+1',
        color: _combo >= 3 ? Colors.amber : Colors.cyanAccent,
      ));
    } else {
      // 해파리 충돌 — 전기 섬광
      mistakes++;
      _combo = 0;
      _comboText.updateText('');
      score = (score - 1).clamp(0, 9999);
      _scoreText.updateText('🐟 $score');

      // 전기 파티클
      add(ParticleSystemComponent(
        position: obj.position.clone(),
        particle: fp.Particle.generate(
          count: 12,
          lifespan: 0.4,
          generator: (i) {
            final angle = (i / 12) * pi * 2 + _rng.nextDouble() * 0.3;
            final spd = 80 + _rng.nextDouble() * 80;
            return fp.AcceleratedParticle(
              speed: Vector2(cos(angle) * spd, sin(angle) * spd),
              acceleration: Vector2.zero(),
              child: fp.ScalingParticle(
                to: 0,
                child: fp.CircleParticle(
                  radius: 1.5 + _rng.nextDouble() * 2,
                  paint: Paint()..color = [
                    const Color(0xFFFFEE58),
                    const Color(0xFFCE93D8),
                    const Color(0xFF80DEEA),
                    Colors.white,
                  ][i % 4],
                ),
              ),
            );
          },
        ),
      ));

      add(_FloatingLabel(
        pos: obj.position.clone(),
        text: '⚡ -1',
        color: Colors.purpleAccent,
      ));
    }

    obj.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.6), EffectController(duration: 0.08)),
      RemoveEffect(),
    ]));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    final total = hits + misses;
    onGameEnd(GameResult(
      gameId: 'object_hit_avoid',
      score: score,
      maxPossibleScore: (total + hits) * 3,
      accuracy: total > 0 ? hits / total : 0.0,
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: hits,
      misses: misses + mistakes,
    ));
  }

  void setSimPosition(double v) {
    _normAngle = v.clamp(0.0, 1.0);
    _updateCursor();
  }

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Components ───

/// 십자선 커서 — 수중 조준경 스타일
class _Crosshair extends PositionComponent with HasGameReference<ObjectHitAvoidGame> {
  double targetX;
  final int cogLevel;
  double _pulse = 0;

  _Crosshair({required Vector2 gameSize, required this.cogLevel})
      : targetX = gameSize.x / 2,
        super(
          position: Vector2(gameSize.x / 2, gameSize.y * 0.82),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (targetX - position.x) * 14 * dt;
    _pulse += dt * 2.5;
  }

  @override
  void render(Canvas canvas) {
    // 크기: 인지 레벨에 따라 조정 (레벨 1은 크게)
    final outerR = cogLevel == 1 ? 36.0 : cogLevel == 2 ? 28.0 : 22.0;
    final innerR = outerR * 0.35;
    final glowAlpha = 0.15 + sin(_pulse) * 0.06;
    const color = Color(0xFF00E5FF);

    // 외부 글로우
    canvas.drawCircle(Offset.zero, outerR + 8,
        Paint()..color = color.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // 외부 원 (실선)
    canvas.drawCircle(Offset.zero, outerR,
        Paint()..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // 내부 원
    canvas.drawCircle(Offset.zero, innerR,
        Paint()..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // 십자선 (4방향)
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final gap = innerR + 2;
    canvas.drawLine(Offset(-outerR * 0.9, 0), Offset(-gap, 0), linePaint);
    canvas.drawLine(Offset(gap, 0), Offset(outerR * 0.9, 0), linePaint);
    canvas.drawLine(Offset(0, -outerR * 0.9), Offset(0, -gap), linePaint);
    canvas.drawLine(Offset(0, gap), Offset(0, outerR * 0.9), linePaint);

    // 중앙 점
    canvas.drawCircle(Offset.zero, 3,
        Paint()..color = color.withValues(alpha: 0.9));
  }
}

/// 수중 오브젝트 — 빨간 물고기(타겟) 또는 파란 해파리(장애물)
class _UnderwaterObject extends PositionComponent with HasGameReference<ObjectHitAvoidGame> {
  final bool isTarget;
  final double speed;
  final double radius;
  final int cognitiveLevel;
  bool collected = false;
  double _phase = 0;
  Sprite? _fishSprite;

  // 타겟 물고기: red/orange/pink (밝은 색)
  static const _targetFish = ['fish_red', 'fish_orange', 'fish_pink'];

  _UnderwaterObject({
    required Vector2 pos,
    required this.isTarget,
    required this.speed,
    required this.radius,
    required this.cognitiveLevel,
  }) : super(position: pos, anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    if (isTarget) {
      final atlas = await FishAtlas.load();
      final idx = (position.x.toInt() + position.y.toInt()) % _targetFish.length;
      _fishSprite = atlas.spriteOrNull(_targetFish[idx]);
    }
    // 해파리는 커스텀 드로우
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (collected) return;
    position.y += speed * dt;
    _phase += dt * (isTarget ? 2.8 : 1.6);
    // 물고기: 좌우 유영. 해파리: 천천히 흔들
    position.x += sin(_phase) * (isTarget ? 0.5 : 1.2);
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    final pulse = sin(_phase) * 0.08 + 1.0;
    final r = radius * pulse;

    if (isTarget) {
      _renderFish(canvas, r);
    } else {
      _renderJellyfish(canvas, r);
    }
  }

  void _renderFish(Canvas canvas, double r) {
    // 빨간 물고기 글로우
    canvas.drawCircle(Offset.zero, r * 1.3,
        Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    if (_fishSprite != null) {
      // 물고기가 아래를 향하도록 90° 회전 후 렌더
      canvas.save();
      canvas.rotate(pi / 2); // 아래 방향으로 회전
      _fishSprite!.render(canvas,
          position: Vector2(-r * 0.9, -r * 0.65),
          size: Vector2(r * 1.8, r * 1.3));
      canvas.restore();
    } else {
      // 폴백: 빨간 물고기 모양
      _drawFallbackFish(canvas, r);
    }

    // 인지 레벨 2+: 타겟 마커 (빛 발산)
    if (cognitiveLevel >= 2) {
      canvas.drawCircle(Offset.zero, r * 0.3,
          Paint()..color = const Color(0xFFFFCDD2).withValues(alpha: 0.6));
    }
  }

  void _drawFallbackFish(Canvas canvas, double r) {
    final path = Path();
    path.moveTo(r * 0.7, 0);
    path.quadraticBezierTo(0, -r * 0.5, -r * 0.7, 0);
    path.quadraticBezierTo(0, r * 0.5, r * 0.7, 0);
    // 꼬리
    path.moveTo(-r * 0.7, 0);
    path.lineTo(-r * 1.1, -r * 0.35);
    path.lineTo(-r * 1.1, r * 0.35);
    path.close();
    canvas.drawPath(path,
        Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.9));
  }

  void _renderJellyfish(Canvas canvas, double r) {
    const jellyColor = Color(0xFF40C4FF);

    // 외부 글로우
    canvas.drawCircle(Offset(0, -r * 0.2), r * 1.5,
        Paint()..color = jellyColor.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // 몸통 (반구형 돔)
    final bodyPath = Path();
    bodyPath.addArc(
        Rect.fromCenter(center: Offset(0, -r * 0.1), width: r * 1.6, height: r * 1.2),
        pi, pi); // 상반부만
    bodyPath.lineTo(-r * 0.8, -r * 0.1);
    bodyPath.close();

    canvas.drawPath(bodyPath,
        Paint()..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.0,
          colors: [
            jellyColor.withValues(alpha: 0.9),
            jellyColor.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromCenter(
            center: Offset(0, -r * 0.3), width: r * 2, height: r * 1.4)));

    // 내부 패턴 (반투명 밝은 영역)
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -r * 0.5), width: r * 0.8, height: r * 0.4),
        Paint()..color = Colors.white.withValues(alpha: 0.25));

    // 촉수 (6개)
    final tentaclePaint = Paint()
      ..color = jellyColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final tx = (i - 2.5) * r * 0.25;
      final tentPath = Path();
      tentPath.moveTo(tx, -r * 0.1);
      // 사인파 촉수
      for (double dy = 0; dy <= r * 0.85; dy += 4) {
        tentPath.lineTo(
            tx + sin(_phase + i * 0.8 + dy * 0.15) * r * 0.12,
            -r * 0.1 + dy);
      }
      canvas.drawPath(tentPath, tentaclePaint);
    }

    // 위험 표시 (인지 레벨 2+)
    if (cognitiveLevel >= 2) {
      TextPaint(style: const TextStyle(
        fontSize: 12, color: Color(0xFFFFEE58), fontWeight: FontWeight.bold,
      )).render(canvas, '⚡', Vector2(0, -r * 1.6), anchor: Anchor.center);
    }
  }
}

/// 수중 배경 — 산호초 + 볼류메트릭 빛 기둥
class _UnderwaterBackground extends PositionComponent with HasGameReference<ObjectHitAvoidGame> {
  final Vector2 _gs;
  final int cogLevel;
  double _time = 0;
  double _scrollOffset = 0;
  final List<_CoralDecor> _corals = [];
  bool _spritesLoaded = false;
  final Random _rng = Random(42);

  // 빛 기둥 데이터
  final List<_LightShaft> _shafts = [];

  _UnderwaterBackground({required Vector2 gameSize, required this.cogLevel})
      : _gs = gameSize, super(priority: -10);

  @override
  Future<void> onLoad() async {
    // 볼류메트릭 빛 기둥 생성 (인지 레벨 2+)
    if (cogLevel >= 2) {
      final shaftCount = cogLevel == 2 ? 3 : 5;
      for (int i = 0; i < shaftCount; i++) {
        _shafts.add(_LightShaft(
          x: (i + 1) * _gs.x / (shaftCount + 1) + _rng.nextDouble() * 40 - 20,
          width: 40 + _rng.nextDouble() * 30,
          alpha: 0.035 + _rng.nextDouble() * 0.025,
          speed: 0.3 + _rng.nextDouble() * 0.2,
          phase: _rng.nextDouble() * pi * 2,
        ));
      }
    }

    // 산호 + 해조류 (인지 레벨 3)
    if (cogLevel >= 3) {
      final atlas = await FishAtlas.load();
      for (final name in [...FishAtlas.seaweeds, ...FishAtlas.rocks]) {
        final sprite = atlas.spriteOrNull(name);
        if (sprite == null) continue;
        for (int j = 0; j < 4; j++) {
          _corals.add(_CoralDecor(
            sprite: sprite,
            x: _rng.nextDouble() * _gs.x * 2,
            y: _gs.y * 0.78 + _rng.nextDouble() * _gs.y * 0.18,
            size: 32 + _rng.nextDouble() * 28,
            scrollFactor: 0.15 + _rng.nextDouble() * 0.2,
          ));
        }
      }
    }

    _spritesLoaded = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _scrollOffset += dt * 18;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);

    // 깊은 바다 그라디언트
    final bgColors = cogLevel == 1
        ? [const Color(0xFF001830), const Color(0xFF002244)]
        : cogLevel == 2
            ? [const Color(0xFF000F20), const Color(0xFF001428), const Color(0xFF002850), const Color(0xFF00366A)]
            : [const Color(0xFF000C18), const Color(0xFF001228), const Color(0xFF002240), const Color(0xFF003055), const Color(0xFF01437A)];

    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: bgColors,
    ).createShader(rect));

    // 볼류메트릭 빛 기둥
    for (final shaft in _shafts) {
      final alpha = shaft.alpha * (0.8 + sin(_time * shaft.speed + shaft.phase) * 0.2);
      final shaftPath = Path();
      shaftPath.moveTo(shaft.x - shaft.width * 0.3, 0);
      shaftPath.lineTo(shaft.x + shaft.width * 0.3, 0);
      shaftPath.lineTo(shaft.x + shaft.width * 0.7, _gs.y * 0.85);
      shaftPath.lineTo(shaft.x - shaft.width * 0.7, _gs.y * 0.85);
      shaftPath.close();
      canvas.drawPath(shaftPath,
          Paint()..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue.withValues(alpha: alpha),
              Colors.lightBlue.withValues(alpha: alpha * 0.1),
            ],
          ).createShader(Rect.fromLTWH(shaft.x - 40, 0, 80, _gs.y * 0.85)));
    }

    // 산호 + 해조류 (인지 레벨 3)
    if (_spritesLoaded && cogLevel >= 3) {
      for (final c in _corals) {
        final x = (c.x - _scrollOffset * c.scrollFactor) % (_gs.x + c.size);
        canvas.save();
        canvas.translate(x, c.y);
        c.sprite.render(canvas,
            position: Vector2(-c.size / 2, -c.size / 2),
            size: Vector2.all(c.size),
            overridePaint: Paint()..color = Colors.white.withValues(alpha: 0.7));
        canvas.restore();
      }
    }

    // 부유 기포
    final bubblePaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final bubbleCount = cogLevel == 1 ? 8 : cogLevel == 2 ? 14 : 20;
    for (int i = 0; i < bubbleCount; i++) {
      final bx = (i * 93.7 + _scrollOffset * 0.08) % _gs.x;
      final by = (_time * (12 + (i % 4) * 6) + i * 57.3) % _gs.y;
      canvas.drawCircle(Offset(bx, by), 2.0 + (i % 3), bubblePaint);
    }

    // 물결 레이어
    if (cogLevel >= 2) {
      final wavePaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.07)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (double y = 60; y < _gs.y; y += 65) {
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < _gs.x; x += 18) {
          path.lineTo(x, y + sin(_time * 0.5 + x / 70) * 3);
        }
        canvas.drawPath(path, wavePaint);
      }
    }
  }
}

class _LightShaft {
  double x, width, alpha, speed, phase;
  _LightShaft({required this.x, required this.width, required this.alpha,
      required this.speed, required this.phase});
}

class _CoralDecor {
  final Sprite sprite;
  final double x, y, size, scrollFactor;
  const _CoralDecor({required this.sprite, required this.x, required this.y,
      required this.size, required this.scrollFactor});
}

/// 해저 바닥 라인 (커서 가이드)
class _SeaFloorLine extends PositionComponent {
  final Vector2 _gs;
  _SeaFloorLine({required Vector2 gameSize}) : _gs = gameSize, super(priority: 1);

  @override
  void render(Canvas canvas) {
    final y = _gs.y * 0.82;
    // 모래 바닥 느낌
    canvas.drawLine(
      Offset(30, y),
      Offset(_gs.x - 30, y),
      Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.25)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // 작은 물결 패턴
    for (double x = 40; x < _gs.x - 40; x += 18) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y + 4), width: 14, height: 5),
        0, pi, false,
        Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
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
    super.update(dt);
    _life += dt;
    position.y -= 55 * dt;
    if (_life > 0.85) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 0.85).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: 20, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

// ─── Flutter Wrapper ───

class TrackingGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const TrackingGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<TrackingGame> createState() => _State();
}

class _State extends State<TrackingGame> {
  late ObjectHitAvoidGame _game;
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    final stream = _isSim
        ? null
        : widget.bluetoothService.dataStream
            .map((s) => double.tryParse(s.trim()))
            .where((v) => v != null)
            .map((a) => widget.config.normalizer.normalize(a!));
    _game = ObjectHitAvoidGame(
      inputStream: stream,
      config: widget.config,
      onGameEnd: (r) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GameResultScreen(result: r)),
          );
        }
      },
    );
  }

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
            onPressed: () => _game.endGame(),
            child: const Icon(Icons.stop, color: Colors.white, size: 32),
          ),
        ),
      ]),
    );
  }

  Widget _simSlider() => Container(
    color: const Color(0xFF001428),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Column(children: [
      Text('시뮬레이션: 관절 각도 (${(_simValue * 100).toInt()}%)',
          style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
      SliderTheme(
        data: SliderThemeData(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
          trackHeight: 8,
          activeTrackColor: const Color(0xFF00E5FF),
          thumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
        ),
        child: Slider(
          value: _simValue,
          onChanged: (v) {
            setState(() => _simValue = v);
            _game.setSimPosition(v);
          },
        ),
      ),
    ]),
  );

  Widget _controlBar(AppLocalizations loc) => Container(
    color: const Color(0xFF001428),
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12, foregroundColor: Colors.white),
        onPressed: () => setState(() => _game.isRunning = !_game.isRunning),
        icon: const Icon(Icons.pause),
        label: Text(loc.pauseGame),
      ),
      const SizedBox(width: 16),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent)),
        onPressed: () => _game.endGame(),
        icon: const Icon(Icons.stop),
        label: Text(loc.stop),
      ),
    ]),
  );
}
