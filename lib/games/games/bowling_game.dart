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
/// [C3] 볼링 마스터 (Bowling Master)
/// 관절: 팔꿈치 굽힘/폄 (lElbow) → 조준 + 어깨 굽힘/폄 (lShoulderEF) → 스윙 발사
///
/// 메카닉 (관절 전환 4단계 사이클):
///   Step 1 — 조준 (lElbow): 팔꿈치 각도 → 공 X 위치. 유지 → 조준 확정
///   Step 2 — 백스윙 (lShoulderEF): 어깨 폄(Extension, normAngle < backswingZone) 감지
///   Step 3 — 발사 (lShoulderEF): 어깨 굴곡 방향 스윙 속도 > 임계값 → 자동 발사
///   Step 4 — 결과/리셋: 핀 충돌 판정 → 스코어 → 리셋
///
/// 임상 근거:
///   • 어깨 스윙 중 팔꿈치 고정 = 공동운동 패턴 분리 훈련 (Stage 4~5 핵심)
///   • 동적 어깨 ROM + 속도 제어 = 기능적 던지기/밀기 ADL 복원
/// ============================================================================

// ─── 게임 단계 ───
enum _Phase { aiming, backswing, releasing, rolling, result }

class BowlingFlameGame extends FlameGame {
  /// 입력 스트림 — 현재 활성 관절의 정규화 각도 (0~1)
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  /// 외부에서 관절 전환을 요청하는 콜백
  final void Function(String joint)? onJointSwitch;

  StreamSubscription<double>? _sub;
  double _normAngle = 0.5;
  double _lastNormAngle = 0.5;
  double _angleVelocity = 0.0; // 어깨 각도 변화율 (스윙 속도 감지용)

  _Phase _phase = _Phase.aiming;

  int score = 0;
  int _framesPlayed = 0;
  int _pinsKnockedTotal = 0;
  bool isRunning = false;
  final Random _rng = Random();

  // 조준 단계
  double _aimX = 0.5;           // 팔꿈치 정규화 위치 (0~1)
  double _aimHoldTimer = 0.0;   // 조준 유지 타이머
  double _lockedAimX = 0.5;     // 확정된 조준 X

  // 어깨 스윙 단계
  bool _backswingReached = false;
  double _releaseSpeed = 0.0;   // 발사 순간 스윙 속도
  double _rollTimer = 0.0;

  // 결과 단계
  double _resultTimer = 0.0;
  int _pinsKnockedThisFrame = 0;

  late _BowlingBall _ball;
  late _HudText _scoreText;
  late _HudText _phaseText;
  late _HudText _frameText;
  late _AimLine _aimLine;
  late _HoldGauge _holdGauge;
  late _SwingMeter _swingMeter;
  final List<_BowlingPin> _pins = [];

  BowlingFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
    this.onJointSwitch,
  });

  @override
  Color backgroundColor() => const Color(0xFF2B1A0A);

  // ─── 파라미터 (Brunnstrom 단계 기반) ───

  double get _laneWidthRatio {
    const ratios = [0.80, 0.72, 0.60, 0.52, 0.45];
    return ratios[(config.difficultyLevel - 1).clamp(0, 4)];
  }

  double get _aimHoldRequired {
    const holds = [0.5, 0.7, 1.0, 1.2, 1.5];
    return holds[(config.difficultyLevel - 1).clamp(0, 4)];
  }

  double get _releaseThreshold {
    const thresholds = [0.5, 0.8, 1.0, 1.4, 1.8];
    return thresholds[(config.difficultyLevel - 1).clamp(0, 4)];
  }

  double get _pinHitRadius {
    const radii = [45.0, 38.0, 30.0, 25.0, 20.0];
    return radii[(config.difficultyLevel - 1).clamp(0, 4)] * config.targetSizeMultiplier;
  }

  double get _backswingZone => 0.25; // 어깨 정규화 각도 < 이 값 = 백스윙 달성

  int get _pinCount {
    if (config.cognitiveLevel.level == 1) return 1;
    if (config.cognitiveLevel.level == 2) return 3;
    return 6;
  }

  double get _laneLeft => size.x * (1 - _laneWidthRatio) / 2;
  double get _laneRight => size.x - _laneLeft;
  double get _ballBaseY => size.y * 0.82;
  double get _pinZoneY => size.y * 0.12;

  @override
  Future<void> onLoad() async {
    // 배경
    add(_LaneBackground(gameSize: size));

    // 볼링공
    _ball = _BowlingBall(pos: Vector2(size.x / 2, _ballBaseY));
    add(_ball);

    // 조준선
    _aimLine = _AimLine(
      startX: size.x / 2, startY: _ballBaseY - 20,
      endY: _pinZoneY + 30, screenWidth: size.x,
    );
    if (config.cognitiveLevel.showAimLine) add(_aimLine);

    // 유지 게이지 (조준 확정)
    _holdGauge = _HoldGauge(ballRef: _ball);
    add(_holdGauge);

    // 스윙 미터 (어깨 스윙 속도)
    _swingMeter = _SwingMeter(pos: Vector2(size.x - 60, size.y * 0.5));
    if (config.cognitiveLevel.level >= 2) add(_swingMeter);

    // HUD
    _scoreText = _HudText('점수: 0', Vector2(20, 14), Anchor.topLeft, 20);
    add(_scoreText);

    _frameText = _HudText('1프레임', Vector2(size.x / 2, 14), Anchor.topCenter, 16);
    add(_frameText);

    _phaseText = _HudText('팔꿈치로 조준하세요', Vector2(size.x / 2, size.y - 20),
        Anchor.bottomCenter, 15);
    add(_phaseText);

    // 핀 배치
    _spawnPins();

    // 입력 구독 (팔꿈치로 시작)
    _sub = inputStream?.listen((v) => _normAngle = v.clamp(0.0, 1.0));
    isRunning = true;
    // onJointSwitch → setState()가 빌드 도중 호출되지 않도록 다음 프레임으로 지연
    Future.microtask(_switchToAiming);
  }

  // ─── 단계 전환 ───

  void _switchToAiming() {
    _phase = _Phase.aiming;
    _aimHoldTimer = 0;
    _backswingReached = false;
    onJointSwitch?.call('lElbow');
    _phaseText.updateText(config.cognitiveLevel.level == 1
        ? '팔꿈치로 조준하세요'
        : '팔꿈치: 조준 후 유지하세요');
    _aimLine.visible = config.cognitiveLevel.showAimLine;
    _holdGauge.setRatio(0);
  }

  void _switchToBackswing() {
    _phase = _Phase.backswing;
    _lockedAimX = _aimX;
    _aimLine.visible = false;
    onJointSwitch?.call('lShoulderEF');
    _phaseText.updateText(config.cognitiveLevel.level == 1
        ? '어깨를 뒤로 당기세요'
        : '어깨 백스윙 → 앞으로 던지세요');
    _holdGauge.setRatio(0);
  }

  void _launch() {
    _phase = _Phase.rolling;
    _rollTimer = 0;
    onJointSwitch?.call('x'); // 어깨 정지
    _ball.startRolling(
      targetX: _laneLeft + _lockedAimX * (_laneRight - _laneLeft),
      targetY: _pinZoneY,
      speed: 600 + _releaseSpeed * 200,
    );
    _phaseText.updateText('');
    _swingMeter.setRatio(0);
  }

  void _showResult() {
    _phase = _Phase.result;
    _resultTimer = 0;
    _pinsKnockedThisFrame = _checkPinCollisions();
    _pinsKnockedTotal += _pinsKnockedThisFrame;
    score += _pinsKnockedThisFrame * (_pinsKnockedThisFrame == _pinCount ? 2 : 1);
    _scoreText.updateText('점수: $score');
    _framesPlayed++;
    _frameText.updateText('$_framesPlayed프레임');

    final label = _pinsKnockedThisFrame == _pinCount ? '스트라이크!' : '$_pinsKnockedThisFrame개!';
    _phaseText.updateText(label);

    if (config.cognitiveLevel.particleCount > 0 && _pinsKnockedThisFrame > 0) {
      _spawnHitParticles();
    }
  }

  void _resetFrame() {
    _ball.resetTo(Vector2(size.x / 2, _ballBaseY));
    for (final pin in _pins) { pin.removeFromParent(); }
    _pins.clear();
    _spawnPins();
    _switchToAiming();
  }

  // ─── update ───

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    // 각도 변화율 (어깨 스윙 속도용)
    final dAngle = _normAngle - _lastNormAngle;
    _angleVelocity = dAngle / dt.clamp(0.001, 0.1);
    _lastNormAngle = _normAngle;

    switch (_phase) {
      case _Phase.aiming:
        _updateAiming(dt);
      case _Phase.backswing:
        _updateBackswing(dt);
      case _Phase.releasing:
        break; // 발사 처리 완료 대기
      case _Phase.rolling:
        _updateRolling(dt);
      case _Phase.result:
        _updateResult(dt);
    }
  }

  void _updateAiming(double dt) {
    // 팔꿈치 각도 → 공 X 위치
    _aimX = _normAngle;
    final targetX = _laneLeft + _aimX * (_laneRight - _laneLeft);
    _ball.aimTo(targetX, dt);
    _aimLine.updateX(targetX);

    // 조준 유지 판정 (각도 변화가 작으면 유지 중)
    if (_angleVelocity.abs() < 0.3) {
      _aimHoldTimer += dt;
    } else {
      _aimHoldTimer = (_aimHoldTimer - dt * 2).clamp(0, _aimHoldRequired);
    }
    _holdGauge.setRatio(_aimHoldTimer / _aimHoldRequired);

    if (_aimHoldTimer >= _aimHoldRequired) {
      _switchToBackswing();
    }
  }

  void _updateBackswing(double dt) {
    _swingMeter.setRatio(_normAngle);

    // 백스윙 감지: 어깨 폄(extension) 위치 도달
    if (_normAngle < _backswingZone) {
      _backswingReached = true;
    }

    // 발사 감지: 백스윙 이후 어깨 굴곡(flexion) 방향으로 빠른 스윙
    if (_backswingReached && _angleVelocity > _releaseThreshold) {
      _releaseSpeed = (_angleVelocity - _releaseThreshold).clamp(0, 5);
      _launch();
    }
  }

  void _updateRolling(double dt) {
    _rollTimer += dt;
    if (_ball.hasReachedTarget || _rollTimer > 2.0) {
      _showResult();
    }
  }

  void _updateResult(double dt) {
    _resultTimer += dt;
    if (_resultTimer > 1.2) {
      if (_framesPlayed >= 10) {
        endGame();
      } else {
        _resetFrame();
      }
    }
  }

  // ─── 핀 배치 / 충돌 ───

  void _spawnPins() {
    final cx = size.x / 2;
    final py = _pinZoneY;
    final spacing = 28.0 * config.targetSizeMultiplier;

    final positions = <Vector2>[];
    switch (_pinCount) {
      case 1:
        positions.add(Vector2(cx, py));
      case 3:
        positions.addAll([
          Vector2(cx, py),
          Vector2(cx - spacing, py + spacing * 0.8),
          Vector2(cx + spacing, py + spacing * 0.8),
        ]);
      default: // 6
        positions.addAll([
          Vector2(cx, py),
          Vector2(cx - spacing, py + spacing * 0.8),
          Vector2(cx + spacing, py + spacing * 0.8),
          Vector2(cx - spacing * 2, py + spacing * 1.6),
          Vector2(cx, py + spacing * 1.6),
          Vector2(cx + spacing * 2, py + spacing * 1.6),
        ]);
    }

    for (final pos in positions) {
      final pin = _BowlingPin(pos: pos, radius: _pinHitRadius * 0.45);
      _pins.add(pin);
      add(pin);
    }
  }

  int _checkPinCollisions() {
    int count = 0;
    for (final pin in _pins) {
      if (pin.knocked) continue;
      final dist = (pin.position - _ball.position).length;
      if (dist < _pinHitRadius) {
        pin.knockDown();
        count++;
      }
    }
    return count;
  }

  void _spawnHitParticles() {
    final cx = size.x / 2;
    add(ParticleSystemComponent(
      position: Vector2(cx, _pinZoneY),
      particle: fp.Particle.generate(
        count: config.cognitiveLevel.particleCount,
        lifespan: 0.6,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(
            _rng.nextDouble() * 200 - 100,
            _rng.nextDouble() * 200 - 50,
          ),
          acceleration: Vector2(0, 300),
          child: fp.ScalingParticle(
            to: 0,
            child: fp.CircleParticle(
              radius: 3 + _rng.nextDouble() * 4,
              paint: Paint()..color = [
                Colors.white, Colors.amber, Colors.red,
              ][_rng.nextInt(3)],
            ),
          ),
        ),
      ),
    ));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onJointSwitch?.call('x');
    onGameEnd(GameResult(
      gameId: 'bowling', score: score,
      maxPossibleScore: _framesPlayed * _pinCount * 2,
      accuracy: _framesPlayed > 0 ? _pinsKnockedTotal / (_framesPlayed * _pinCount) : 0,
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart, timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: _pinsKnockedTotal,
      misses: _framesPlayed * _pinCount - _pinsKnockedTotal,
    ));
  }

  void setSimAngle(double v) {
    _normAngle = v.clamp(0.0, 1.0);
  }

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Components ───

class _BowlingBall extends PositionComponent with HasGameReference<BowlingFlameGame> {
  // rolling-ball-assets: ball_red_large/alt — 64×64 고화질 스프라이트
  final List<Sprite> _frames = [];
  double? _targetX;
  double? _targetY;
  double _rollSpeed = 0;
  bool hasReachedTarget = false;
  bool _rolling = false;
  double _rotation = 0;
  final List<Offset> _trail = [];
  double _trailTimer = 0;

  _BowlingBall({required Vector2 pos})
      : super(position: pos, size: Vector2.all(72), anchor: Anchor.center, priority: 10);

  @override
  Future<void> onLoad() async {
    // rolling-ball-assets에서 64×64 고화질 공 스프라이트 로드
    final atlas = await RollingBallAtlas.load();
    for (final name in RollingBallAtlas.balls) {
      final s = atlas.spriteOrNull(name);
      if (s != null) _frames.add(s);
    }
  }

  void aimTo(double x, double dt) {
    if (!_rolling) position.x += (x - position.x) * 8 * dt;
  }

  void startRolling({required double targetX, required double targetY, required double speed}) {
    _targetX = targetX;
    _targetY = targetY;
    _rollSpeed = speed;
    _rolling = true;
    hasReachedTarget = false;
    _trail.clear();
  }

  void resetTo(Vector2 pos) {
    position = pos.clone();
    _rolling = false;
    _targetX = null;
    _targetY = null;
    hasReachedTarget = false;
    _rotation = 0;
    _trail.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_rolling && _targetX != null && _targetY != null) {
      final dx = _targetX! - position.x;
      final dy = _targetY! - position.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 8) {
        hasReachedTarget = true;
        _rolling = false;
      } else {
        final step = _rollSpeed * dt;
        position.x += dx / dist * step;
        position.y += dy / dist * step;
        _rotation += _rollSpeed * dt * 0.05;
        // 트레일 포인트 추가
        _trailTimer += dt;
        if (_trailTimer > 0.03) {
          _trailTimer = 0;
          _trail.add(Offset(position.x, position.y));
          if (_trail.length > 14) _trail.removeAt(0);
        }
      }
    } else if (!_rolling && _targetX != null) {
      position.x += (_targetX! - position.x) * 8 * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    const r = 34.0;

    // 롤링 트레일 (공 뒤에 잔상)
    if (_rolling) {
      for (int i = 0; i < _trail.length; i++) {
        final alpha = (i / _trail.length) * 0.35;
        final trailR = r * (0.4 + 0.6 * i / _trail.length);
        canvas.drawCircle(
          Offset(_trail[i].dx - position.x, _trail[i].dy - position.y),
          trailR,
          Paint()..color = Colors.orange.withValues(alpha: alpha),
        );
      }
    }

    canvas.save();
    canvas.rotate(_rotation);

    // 그림자
    canvas.drawCircle(Offset(4, 6), r * 0.85,
        Paint()..color = Colors.black.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // 글로우 (조준 중: 주황, 발사 중: 흰색)
    final glowColor = _rolling
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFFFF8F00).withValues(alpha: 0.35);
    canvas.drawCircle(Offset.zero, r + 10,
        Paint()..color = glowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    if (_frames.isNotEmpty) {
      final frameIdx = (_rotation * 2).toInt().abs() % _frames.length;
      _frames[frameIdx].render(canvas,
          position: Vector2(-r, -r), size: Vector2.all(r * 2));
    } else {
      // 폴백: 고품질 커스텀 볼링공
      final ballPaint = Paint()..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.8,
        colors: const [Color(0xFF9C3A2C), Color(0xFF6B1A10), Color(0xFF3D0A05)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
      canvas.drawCircle(Offset.zero, r, ballPaint);
      // 하이라이트
      canvas.drawCircle(const Offset(-10, -12), r * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // 손가락 구멍
      for (final offset in [const Offset(-8, -6), const Offset(4, -10), const Offset(9, 3)]) {
        canvas.drawCircle(offset, 5,
            Paint()..color = Colors.black.withValues(alpha: 0.6));
      }
    }
    canvas.restore();
  }
}

class _BowlingPin extends PositionComponent {
  final double radius;
  bool knocked = false;

  _BowlingPin({required Vector2 pos, required this.radius})
      : super(position: pos, anchor: Anchor.center, priority: 5);

  void knockDown() {
    knocked = true;
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.4), EffectController(duration: 0.08)),
      ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.15)),
      RemoveEffect(),
    ]));
  }

  @override
  void render(Canvas canvas) {
    if (knocked) return;
    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(2, radius * 1.15), width: radius * 0.8, height: radius * 0.18),
      Paint()..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // 핀 몸통 (흰색 — 광택 그라디언트)
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: radius * 1.1, height: radius * 2.4);
    canvas.drawOval(bodyRect,
      Paint()..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFCCCCCC), Color(0xFFFFFFFF), Color(0xFFEEEEEE)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(bodyRect),
    );
    // 빨간 줄무늬
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -radius * 0.22),
          width: radius * 0.75, height: radius * 0.38),
      Paint()..color = const Color(0xFFCC0000),
    );
    // 머리
    canvas.drawCircle(Offset(0, -radius * 0.85), radius * 0.34,
        Paint()..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFFFFFF), Color(0xFFDDDDDD)],
        ).createShader(Rect.fromCircle(center: Offset(0, -radius * 0.85), radius: radius * 0.34)));
    // 핀 광택 (하이라이트)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-radius * 0.2, -radius * 0.5),
          width: radius * 0.25, height: radius * 0.6),
      Paint()..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
}

class _AimLine extends PositionComponent {
  double _x;
  final double startY;
  final double endY;
  final double screenWidth;
  bool visible = true;

  _AimLine({
    required double startX, required this.startY,
    required this.endY, required this.screenWidth,
  }) : _x = startX, super(priority: 3);

  void updateX(double x) => _x = x;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double y = startY;
    while (y > endY) {
      canvas.drawLine(Offset(_x, y), Offset(_x, y - 10), paint);
      y -= 18;
    }
  }
}

class _HoldGauge extends PositionComponent {
  final _BowlingBall ballRef;
  double _ratio = 0;

  _HoldGauge({required this.ballRef}) : super(priority: 15);

  void setRatio(double r) => _ratio = r.clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    if (_ratio <= 0) return;
    final cx = ballRef.position.x;
    final cy = ballRef.position.y - 36;
    const w = 44.0;
    const h = 6.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
          const Radius.circular(3)),
      Paint()..color = Colors.white24,
    );
    if (_ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w / 2, cy - h / 2, w * _ratio, h),
            const Radius.circular(3)),
        Paint()..color = Colors.amber,
      );
    }
  }
}

class _SwingMeter extends PositionComponent {
  double _ratio = 0.5;
  final double _height = 140;

  _SwingMeter({required Vector2 pos}) : super(position: pos, priority: 100);

  void setRatio(double r) => _ratio = r.clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    const w = 16.0;
    final h = _height;

    // 배경 트랙
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(8)),
      Paint()..color = Colors.white12,
    );

    // 백스윙 존 (하단, 어깨 폄)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, h / 2 - h * 0.25, w, h * 0.25),
          const Radius.circular(4)),
      Paint()..color = Colors.blue.withValues(alpha: 0.3),
    );

    // 현재 위치
    final markerY = h / 2 - _ratio * h;
    canvas.drawCircle(Offset(0, markerY), w / 2,
        Paint()..color = Colors.amber);

    // 레이블
    TextPaint(style: GoogleFonts.orbitron(fontSize: 9, color: Colors.white54))
        .render(canvas, 'SWING', Vector2(0, -h / 2 - 14), anchor: Anchor.center);
  }
}

class _LaneBackground extends PositionComponent {
  final Vector2 _gs;
  // rolling-ball-assets: background_brown 타일을 레인 바닥으로 사용
  Sprite? _tileSprite;

  _LaneBackground({required Vector2 gameSize})
      : _gs = gameSize, super(priority: -10);

  @override
  Future<void> onLoad() async {
    final atlas = await RollingBallAtlas.load();
    _tileSprite = atlas.spriteOrNull('background_brown');
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);

    if (_tileSprite != null) {
      // 타일 스프라이트를 격자로 깔기
      const tileSize = 64.0;
      final cols = (_gs.x / tileSize).ceil() + 1;
      final rows = (_gs.y / tileSize).ceil() + 1;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          _tileSprite!.render(canvas,
              position: Vector2(c * tileSize, r * tileSize),
              size: Vector2.all(tileSize));
        }
      }
      // 어두운 오버레이로 깊이감 추가
      canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.35));

      // 레인 화살표 마커 (볼링장 공식 마커)
      final arrowPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      final arrowPositions = [0.25, 0.375, 0.5, 0.625, 0.75];
      for (final xRatio in arrowPositions) {
        final x = _gs.x * xRatio;
        final y = _gs.y * 0.62;
        final path = Path()
          ..moveTo(x, y - 10)
          ..lineTo(x - 6, y + 4)
          ..lineTo(x + 6, y + 4)
          ..close();
        canvas.drawPath(path, arrowPaint);
      }
    } else {
      // 폴백: 나무 그라디언트
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3E2409), Color(0xFF5C3510), Color(0xFF7A4A1A)],
      ).createShader(rect));
    }

    // 레인 수직선 (나무결 느낌)
    final linePaint = Paint()
      ..color = Colors.brown.shade900.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (int i = 1; i < 10; i++) {
      final x = _gs.x * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, _gs.y), linePaint);
    }

    // 레인 테두리 (양쪽 거터)
    final gutterPaint = Paint()..color = Colors.black54..strokeWidth = 8;
    canvas.drawLine(Offset.zero, Offset(0, _gs.y), gutterPaint);
    canvas.drawLine(Offset(_gs.x, 0), Offset(_gs.x, _gs.y), gutterPaint);

    // 파울 라인 (빨간)
    canvas.drawLine(
      Offset(0, _gs.y * 0.78),
      Offset(_gs.x, _gs.y * 0.78),
      Paint()..color = Colors.redAccent.withValues(alpha: 0.85)..strokeWidth = 2.5,
    );

    // 파울 라인 레이블
    TextPaint(style: const TextStyle(
      fontSize: 9, color: Colors.redAccent, letterSpacing: 2,
    )).render(canvas, 'FOUL LINE',
        Vector2(_gs.x / 2, _gs.y * 0.78 - 10), anchor: Anchor.bottomCenter);

    // 핀 존 표시 (반원 아치)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(_gs.x / 2, _gs.y * 0.12),
          width: _gs.x * 0.55, height: 24),
      0, pi, false,
      Paint()..color = Colors.white24..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );
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

// ─── Flutter Wrapper ───

extension _CogExt on CognitiveLevel {
  bool get showAimLine => level <= 2;
}

class BowlingGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const BowlingGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<BowlingGame> createState() => _BowlingGameState();
}

class _BowlingGameState extends State<BowlingGame> {
  late BowlingFlameGame _game;
  late GameMotorController _motor;
  double _simValue = 0.5;
  bool _isSim = false;
  String _currentJoint = 'lElbow';
  String _phaseLabel = '팔꿈치 조준';

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

    _game = BowlingFlameGame(
      inputStream: stream,
      config: widget.config,
      onJointSwitch: (joint) {
        if (!mounted) return;
        if (joint == 'x') {
          _motor.safeStop();
          setState(() { _phaseLabel = '결과'; });
          return;
        }
        _motor.selectJoint(joint);
        setState(() {
          _currentJoint = joint;
          _phaseLabel = joint == 'lElbow' ? '팔꿈치 조준' : '어깨 스윙';
        });
      },
      onGameEnd: (r) {
        _motor.safeStop(); _motor.dispose();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
        }
      },
    );

    if (!_isSim) {
      _motor.selectJoint('lElbow');
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
          // 관절 단계 표시 바
          _jointIndicator(),
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

  Widget _jointIndicator() => Container(
    color: const Color(0xFF1A0A00),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _JointChip(label: '팔꿈치 조준', active: _currentJoint == 'lElbow',
          color: Colors.orange),
      const SizedBox(width: 16),
      const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
      const SizedBox(width: 16),
      _JointChip(label: '어깨 스윙', active: _currentJoint == 'lShoulderEF',
          color: Colors.amber),
      const SizedBox(width: 16),
      Text(_phaseLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]),
  );

  Widget _simSlider() => Container(
    color: const Color(0xFF1A0A00),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Column(children: [
      Text('시뮬레이션: $_phaseLabel (${(_simValue * 100).toInt()}%)',
          style: const TextStyle(color: Colors.amber, fontSize: 12)),
      SliderTheme(
        data: SliderThemeData(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
          trackHeight: 8,
          activeTrackColor: _currentJoint == 'lElbow' ? Colors.orange : Colors.amber,
          thumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
        ),
        child: Slider(
          value: _simValue,
          onChanged: (v) { setState(() => _simValue = v); _game.setSimAngle(v); },
        ),
      ),
    ]),
  );

  Widget _controlBar(AppLocalizations loc) => Container(
    color: const Color(0xFF1A0A00),
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12, foregroundColor: Colors.white),
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

class _JointChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  const _JointChip({required this.label, required this.active, required this.color});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: active ? color.withValues(alpha: 0.25) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: active ? color : Colors.white24, width: active ? 1.5 : 1),
    ),
    child: Text(label, style: TextStyle(
      color: active ? color : Colors.white38, fontSize: 12,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
    )),
  );
}
