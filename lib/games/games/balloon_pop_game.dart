import 'dart:async';
import 'dart:math';
import 'package:flame/collisions.dart';
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
/// [E1] 벽돌 깨기 (Brick Breaker) — Space Shooter Redux 에셋 적용
/// 관절: 팔꿈치 굽힘/폄 (lElbow)
/// ============================================================================

// ─── Constants ───
const double _wallWidth = 6;
const double _paddleHeight = 18;
const double _ballRadius = 9;
const double _brickHeight = 28;
const double _brickPadding = 4;

// ─── Brick Colors (neon — used as tint over meteor sprite) ───
const _rowColors = [
  Color(0xFFFF1744), Color(0xFFFF6D00), Color(0xFFFFD600),
  Color(0xFF00E676), Color(0xFF00B0FF), Color(0xFF651FFF),
  Color(0xFFD500F9), Color(0xFFF50057),
];

// ─── Meteor sprite pool ───
const _meteorSprites = [
  'meteorBrown_big1.png', 'meteorBrown_big2.png',
  'meteorBrown_big3.png', 'meteorBrown_big4.png',
  'meteorGrey_big1.png',  'meteorGrey_big2.png',
  'meteorGrey_big3.png',  'meteorGrey_big4.png',
];

// ─── Main Game ───
class BrickBreakerGame extends FlameGame with HasCollisionDetection {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  int score = 0;
  int lives = 3;
  int combo = 0;
  double comboTimer = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  int _totalBricks = 0;
  int _brokenBricks = 0;

  late _Paddle _paddle;
  late _Ball _ball;
  late _Hud _hud;

  BrickBreakerGame({this.inputStream, required this.config, required this.onGameEnd})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF0D0018);

  double get paddleWidth => (110.0 - config.difficultyLevel * 10).clamp(50, 110) * config.targetSizeMultiplier;

  @override
  Future<void> onLoad() async {
    // ── Background image ──
    final bgSprite = await loadSprite('kenney_space-shooter-redux/Backgrounds/darkPurple.png');
    add(SpriteComponent(sprite: bgSprite, size: size, priority: -10));

    // ── Walls ──
    add(_Wall(Vector2(0, 0), Vector2(_wallWidth, size.y)));
    add(_Wall(Vector2(size.x - _wallWidth, 0), Vector2(_wallWidth, size.y)));
    add(_Wall(Vector2(0, 0), Vector2(size.x, _wallWidth)));

    // ── Starfield overlay ──
    for (int i = 0; i < 25; i++) {
      add(_StarBg(gameSize: size, rng: _rng));
    }

    // ── Paddle ──
    _paddle = _Paddle(gameSize: size, width: paddleWidth);
    add(_paddle);

    // ── Ball ──
    _ball = _Ball(gameSize: size);
    add(_ball);

    // ── Bricks ──
    _createBricks();

    // ── HUD ──
    _hud = _Hud(game: this);
    add(_hud);

    // ── Input ──
    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (isRunning) _launchBall();
    });
  }

  void _createBricks() {
    final rows = (config.brunnstromStage.level + 2).clamp(3, 8);
    final cols = ((size.x - _wallWidth * 2 - 20) / 80).floor().clamp(5, 14);
    final brickW = (size.x - _wallWidth * 2 - 20 - (cols - 1) * _brickPadding) / cols;
    const startY = 50.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = _wallWidth + 10 + c * (brickW + _brickPadding);
        final y = startY + r * (_brickHeight + _brickPadding);
        final hp = r < 2 ? 2 : 1;
        final color = _rowColors[r % _rowColors.length];

        add(_Brick(
          pos: Vector2(x, y),
          brickSize: Vector2(brickW, _brickHeight),
          color: color,
          hitPoints: hp,
        ));
        _totalBricks++;
      }
    }
  }

  void _launchBall() {
    if (_ball.launched) return;
    _ball.launched = true;
    final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.5;
    final speed = 260.0 + config.difficultyLevel * 35 * config.speedMultiplier;
    _ball.velocity = Vector2(cos(angle) * speed, sin(angle) * speed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (timeRemaining <= 0) { endGame(); return; }

    comboTimer += dt;
    if (comboTimer > 2.0) combo = 0;

    _paddle.targetX = _wallWidth + 10 + currentPosition * (size.x - _wallWidth * 2 - 20);

    if (!_ball.launched) {
      _ball.position
        ..x = _paddle.position.x
        ..y = _paddle.position.y - _paddleHeight - _ballRadius - 2;
    }

    if (_ball.position.y > size.y + 30) {
      lives--;
      _hud.update(0);
      if (lives <= 0) { endGame(); return; }
      _resetBall();
    }

    if (_brokenBricks >= _totalBricks) {
      score += (timeRemaining * 5).toInt();
      endGame();
    }
  }

  void _resetBall() {
    _ball.launched = false;
    _ball.velocity = Vector2.zero();
    _ball.position = Vector2(_paddle.position.x, _paddle.position.y - _paddleHeight - _ballRadius - 2);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (isRunning) _launchBall();
    });
  }

  void onBrickDestroyed(_Brick brick) {
    _brokenBricks++;
    combo++;
    comboTimer = 0;
    final comboBonus = combo >= 5 ? 3 : (combo >= 3 ? 2 : (combo >= 2 ? 1 : 0));
    score += 10 * brick.maxHp + comboBonus * 5;

    final pCount = config.cognitiveLevel.particleCount;
    if (pCount > 0) {
      add(ParticleSystemComponent(
        position: brick.position + brick.brickSize / 2,
        particle: fp.Particle.generate(count: pCount, lifespan: 0.5,
          generator: (i) => fp.AcceleratedParticle(
            speed: Vector2(_rng.nextDouble() * 200 - 100, _rng.nextDouble() * 80 - 140),
            acceleration: Vector2(0, 400),
            child: fp.ScalingParticle(to: 0,
              child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 3,
                paint: Paint()..color = brick.color.withValues(alpha: 0.9))))),
      ));
    }

    add(_FloatingScore(
      pos: brick.position + brick.brickSize / 2,
      text: '+${10 * brick.maxHp}',
      color: brick.color,
    ));

    if (combo >= 3 && config.cognitiveLevel.showCombo) {
      add(_FloatingScore(
        pos: Vector2(size.x / 2, size.y * 0.4),
        text: '${combo}x COMBO!',
        color: combo >= 5 ? Colors.amber : Colors.cyanAccent,
        fontSize: 28,
      ));
    }

    if (_rng.nextDouble() < 0.15) {
      add(_PowerUp(
        pos: brick.position + brick.brickSize / 2,
        type: _rng.nextBool() ? _PowerUpType.wide : _PowerUpType.multi,
      ));
    }
  }

  void activatePowerUp(_PowerUpType type) {
    switch (type) {
      case _PowerUpType.wide:
        _paddle.widen();
        break;
      case _PowerUpType.multi:
        score += 30;
        break;
    }
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'brick_breaker', score: score, maxPossibleScore: _totalBricks * 20,
      accuracy: _totalBricks > 0 ? _brokenBricks / _totalBricks : 0.0,
      duration: config.gameDuration, difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart, timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle, calibrationMax: config.normalizer.maxAngle,
      hits: _brokenBricks, misses: _totalBricks - _brokenBricks,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Paddle ───
class _Paddle extends PositionComponent with CollisionCallbacks, HasGameReference<BrickBreakerGame> {
  double targetX;
  double _flashTimer = 0;
  double _originalWidth;
  double _widenTimer = 0;
  Sprite? _shipSprite;

  _Paddle({required Vector2 gameSize, required double width})
      : targetX = gameSize.x / 2,
        _originalWidth = width,
        super(
          position: Vector2(gameSize.x / 2, gameSize.y * 0.88),
          size: Vector2(width, _paddleHeight),
          anchor: Anchor.center,
          priority: 10,
          children: [RectangleHitbox()],
        );

  @override
  Future<void> onLoad() async {
    _shipSprite = await game.loadSprite('kenney_space-shooter-redux/PNG/playerShip2_orange.png');
  }

  void flash() => _flashTimer = 0.12;

  void widen() {
    size.x = _originalWidth * 1.5;
    _widenTimer = 8.0;
    children.whereType<RectangleHitbox>().first.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (targetX - position.x) * 14 * dt;
    if (_flashTimer > 0) _flashTimer -= dt;

    if (_widenTimer > 0) {
      _widenTimer -= dt;
      if (_widenTimer <= 0) {
        size.x = _originalWidth;
        children.whereType<RectangleHitbox>().first.size = size;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final isFlash = _flashTimer > 0;
    final isWide = _widenTimer > 0;
    final baseColor = isFlash ? Colors.white : (isWide ? const Color(0xFF76FF03) : const Color(0xFF00E5FF));

    // Outer glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.x / 2, size.y / 2), width: size.x + 18, height: size.y + 14),
        const Radius.circular(12)),
      Paint()..color = baseColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Ship sprite (rotated 180° — thrusters face down) clipped to paddle rect
    if (_shipSprite != null) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(9)));
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(pi); // nose points up → thrusters face paddle-side
      canvas.translate(-size.x / 2, -size.y / 2);
      _shipSprite!.render(canvas, size: size);
      canvas.restore();
    } else {
      // Gradient fallback
      final rect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [baseColor, baseColor.withValues(alpha: 0.5)],
        ).createShader(rect),
      );
    }

    // Top highlight stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.x * 0.1, 2, size.x * 0.8, 3), const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }
}

// ─── Ball ───
class _Ball extends PositionComponent with CollisionCallbacks, HasGameReference<BrickBreakerGame> {
  Vector2 velocity = Vector2.zero();
  bool launched = false;
  final List<Vector2> _trail = [];
  double _trailTimer = 0;

  _Ball({required Vector2 gameSize})
      : super(
          position: Vector2(gameSize.x / 2, gameSize.y * 0.85),
          size: Vector2.all(_ballRadius * 2),
          anchor: Anchor.center,
          priority: 8,
          children: [CircleHitbox()],
        );

  @override
  Future<void> onLoad() async {
    final frames = await Future.wait<Sprite>(
      List.generate(20, (i) => game.loadSprite(
        'kenney_space-shooter-redux/PNG/Effects/fire${i.toString().padLeft(2, '0')}.png',
      )),
    );
    final anim = SpriteAnimation.spriteList(frames, stepTime: 0.04, loop: true);
    // SpriteAnimationComponent as child — Flame handles update/render automatically
    add(SpriteAnimationComponent(
      animation: anim,
      size: Vector2.all(_ballRadius * 2),
      anchor: Anchor.center,
      priority: 0,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!launched) return;
    position += velocity * dt;

    _trailTimer += dt;
    if (_trailTimer > 0.02) {
      _trailTimer = 0;
      _trail.add(position.clone());
      if (_trail.length > 12) _trail.removeAt(0);
    }
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);

    if (other is _Paddle) {
      final hitOffset = (position.x - other.position.x) / (other.size.x / 2);
      final clamped = hitOffset.clamp(-1.0, 1.0);
      const maxAngle = 70.0 * (pi / 180.0);
      final angle = clamped * maxAngle;
      final speed = velocity.length * 1.005;

      velocity
        ..x = speed * sin(angle)
        ..y = -(speed * cos(angle)).abs();

      position.y = other.position.y - other.size.y / 2 - _ballRadius - 1;
      other.flash();

    } else if (other is _Brick) {
      if (other.destroyed) return;
      final cp = points.first;
      final bc = other.position + other.brickSize / 2;
      final diff = cp - bc;
      if (diff.x.abs() / other.brickSize.x > diff.y.abs() / other.brickSize.y) {
        velocity.x = -velocity.x;
      } else {
        velocity.y = -velocity.y;
      }
      other.hit();

    } else if (other is _Wall) {
      if (other.size.x < other.size.y) {
        velocity.x = -velocity.x;
      } else {
        velocity.y = -velocity.y;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Flame trail
    for (int i = 0; i < _trail.length; i++) {
      final t = _trail[i];
      final a = i / _trail.length * 0.25;
      final r = _ballRadius * (0.2 + i / _trail.length * 0.5);
      canvas.drawCircle(
        Offset(t.x - position.x, t.y - position.y), r,
        Paint()..color = const Color(0xFFFF6600).withValues(alpha: a),
      );
    }

    // Outer glow (orange fire)
    canvas.drawCircle(
      Offset.zero, _ballRadius + 8,
      Paint()..color = const Color(0xFFFF4400).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Fire sprite is rendered by child SpriteAnimationComponent
    // Fallback glow dot (shown before async load completes)
    if (children.whereType<SpriteAnimationComponent>().isEmpty) {
      canvas.drawCircle(Offset.zero, _ballRadius,
          Paint()..color = Colors.orangeAccent);
    }
  }
}

// ─── Brick ───
class _Brick extends PositionComponent with CollisionCallbacks, HasGameReference<BrickBreakerGame> {
  final Vector2 brickSize;
  Color color;
  int hitPoints;
  final int maxHp;
  bool destroyed = false;
  Sprite? _meteorSprite;

  _Brick({required Vector2 pos, required this.brickSize, required this.color, required this.hitPoints})
      : maxHp = hitPoints,
        super(position: pos, size: brickSize, priority: 5,
            children: [RectangleHitbox()]);

  @override
  Future<void> onLoad() async {
    final idx = (position.x.toInt() + position.y.toInt()) % _meteorSprites.length;
    _meteorSprite = await game.loadSprite(
      'kenney_space-shooter-redux/PNG/Meteors/${_meteorSprites[idx]}',
    );
  }

  void hit() {
    hitPoints--;
    if (hitPoints <= 0) {
      destroyed = true;
      (parent as BrickBreakerGame?)?.onBrickDestroyed(this);
      add(SequenceEffect([
        ScaleEffect.to(Vector2(1.2, 0.2), EffectController(duration: 0.08)),
        RemoveEffect(),
      ]));
    } else {
      color = Color.lerp(color, Colors.white, 0.35)!;
      add(SequenceEffect([
        MoveEffect.by(Vector2(3, 0), EffectController(duration: 0.03)),
        MoveEffect.by(Vector2(-6, 0), EffectController(duration: 0.03)),
        MoveEffect.by(Vector2(3, 0), EffectController(duration: 0.03)),
      ]));
    }
  }

  @override
  void render(Canvas canvas) {
    if (destroyed) return;
    final rect = Rect.fromLTWH(0, 0, brickSize.x, brickSize.y);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // Shadow
    canvas.drawRRect(rr.shift(const Offset(2, 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.4));

    // Clipped content
    canvas.save();
    canvas.clipRRect(rr);

    if (_meteorSprite != null) {
      // Meteor texture base
      _meteorSprite!.render(canvas, size: brickSize);
      // Row color tint overlay
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.45));
    } else {
      // Gradient fallback
      canvas.drawRect(rect, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.black, 0.35)!],
      ).createShader(rect));
    }

    // Top highlight
    canvas.drawRect(Rect.fromLTWH(0, 0, brickSize.x, brickSize.y * 0.3),
        Paint()..color = Colors.white.withValues(alpha: 0.15));

    canvas.restore();

    // Crack marks (damaged)
    if (hitPoints < maxHp) {
      final crack = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(brickSize.x * 0.25, brickSize.y * 0.2),
          Offset(brickSize.x * 0.5, brickSize.y * 0.8), crack);
      canvas.drawLine(Offset(brickSize.x * 0.5, brickSize.y * 0.5),
          Offset(brickSize.x * 0.75, brickSize.y * 0.25), crack);
    }

    // HP indicator
    if (maxHp > 1) {
      TextPaint(style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.bold))
          .render(canvas, '$hitPoints', Vector2(brickSize.x / 2, brickSize.y / 2), anchor: Anchor.center);
    }
  }
}

// ─── Wall ───
class _Wall extends PositionComponent with CollisionCallbacks {
  _Wall(Vector2 pos, Vector2 wallSize)
      : super(position: pos, size: wallSize, priority: 0,
            children: [RectangleHitbox()]);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF1A0A2E).withValues(alpha: 0.8));
  }
}

// ─── Power-Up ───
enum _PowerUpType { wide, multi }

class _PowerUp extends PositionComponent with CollisionCallbacks, HasGameReference<BrickBreakerGame> {
  final _PowerUpType type;
  final Vector2 _velocity = Vector2(0, 120);
  double _pulse = 0;
  Sprite? _puSprite;

  _PowerUp({required Vector2 pos, required this.type})
      : super(position: pos, size: Vector2.all(28), anchor: Anchor.center, priority: 7,
            children: [RectangleHitbox()]);

  @override
  Future<void> onLoad() async {
    final path = type == _PowerUpType.wide
        ? 'kenney_space-shooter-redux/PNG/Power-ups/powerupGreen_bolt.png'
        : 'kenney_space-shooter-redux/PNG/Power-ups/powerupBlue_star.png';
    _puSprite = await game.loadSprite(path);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += _velocity * dt;
    _pulse += dt * 5;
    if (position.y > 2000) removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is _Paddle) {
      (parent as BrickBreakerGame?)?.activatePowerUp(type);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final glow = (sin(_pulse) + 1) / 2 * 0.3 + 0.5;
    final c = type == _PowerUpType.wide ? Colors.greenAccent : Colors.blueAccent;

    // Pulsing glow
    canvas.drawCircle(Offset.zero, 18,
        Paint()..color = c.withValues(alpha: glow * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Sprite or fallback
    if (_puSprite != null) {
      _puSprite!.render(canvas,
        position: Vector2(-14, -14),
        size: Vector2.all(28),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -10, 20, 20), const Radius.circular(5)),
        Paint()..color = c.withValues(alpha: glow),
      );
      final icon = type == _PowerUpType.wide ? '↔' : '★';
      TextPaint(style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold))
          .render(canvas, icon, Vector2.zero(), anchor: Anchor.center);
    }
  }
}

// ─── Background Stars (subtle overlay on top of bg image) ───
class _StarBg extends PositionComponent {
  final double brightness;
  final double speed;

  _StarBg({required Vector2 gameSize, required Random rng})
      : brightness = 0.05 + rng.nextDouble() * 0.2,
        speed = 8 + rng.nextDouble() * 18,
        super(position: Vector2(rng.nextDouble() * gameSize.x, rng.nextDouble() * gameSize.y), priority: -5);

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
    if (position.y > 2000) position.y = -5;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 0.8 + brightness * 2,
        Paint()..color = Colors.white.withValues(alpha: brightness));
  }
}

// ─── HUD ───
class _Hud extends PositionComponent {
  final BrickBreakerGame game;
  _Hud({required this.game}) : super(priority: 100);

  @override
  void render(Canvas canvas) {
    final baseStyle = GoogleFonts.orbitron(
      fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
    );

    // Score
    TextPaint(style: baseStyle)
        .render(canvas, '${game.score}', Vector2(80, 14), anchor: Anchor.topLeft);

    // Lives
    final hearts = List.filled(game.lives, '♥').join(' ');
    TextPaint(style: baseStyle.copyWith(color: Colors.redAccent, fontSize: 16))
        .render(canvas, hearts.isEmpty ? '✕' : hearts, Vector2(16, 14), anchor: Anchor.topLeft);

    // Timer
    if (game.config.cognitiveLevel.showTimer) {
      final timeColor = game.timeRemaining <= 10 ? Colors.redAccent : Colors.cyanAccent;
      TextPaint(style: baseStyle.copyWith(color: timeColor))
          .render(canvas, '${game.timeRemaining.toInt()}s', Vector2(game.size.x - 16, 14), anchor: Anchor.topRight);
    }

    // Combo
    if (game.combo >= 2 && game.config.cognitiveLevel.showCombo) {
      final comboColor = game.combo >= 5 ? Colors.amber : Colors.cyanAccent;
      TextPaint(style: baseStyle.copyWith(color: comboColor))
          .render(canvas, '${game.combo}x', Vector2(game.size.x / 2, 14), anchor: Anchor.topCenter);
    }
  }
}

// ─── Floating Score Text ───
class _FloatingScore extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  double _life = 0;

  _FloatingScore({required Vector2 pos, required this.text, required this.color, this.fontSize = 18})
      : super(position: pos, anchor: Anchor.center, priority: 20);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= 45 * dt;
    if (_life > 0.7) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 0.7).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

// ─── Flutter Wrapper ───
class BalloonPopGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const BalloonPopGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _BalloonPopGameState extends State<BalloonPopGame> {
  late BrickBreakerGame _game;
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
    _game = BrickBreakerGame(inputStream: stream, config: widget.config, onGameEnd: (r) {
      _motor.safeStop(); _motor.dispose();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
    });
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
          if (_isSim) Container(
            color: const Color(0xFF0D0018),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                trackHeight: 8,
                activeTrackColor: Colors.orangeAccent,
                thumbColor: Colors.white,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(value: _simValue, onChanged: (v) {
                setState(() => _simValue = v);
                _game.setSimPosition(v);
              }),
            ),
          ),
          Container(
            color: const Color(0xFF0D0018),
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                onPressed: () => _game.isRunning = !_game.isRunning,
                icon: const Icon(Icons.pause), label: Text(loc.pauseGame),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                onPressed: () { _motor.safeStop(); _game.endGame(); },
                icon: const Icon(Icons.stop), label: Text(loc.stop),
              ),
            ]),
          ),
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
}
