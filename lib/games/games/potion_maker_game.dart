import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bluetooth.dart';
import '../../generated/l10n.dart';
import '../game_base.dart';
import '../game_graphics_utils.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';

/// ============================================================================
/// [E3] 물약 제조 (Potion Maker)
/// 관절: 팔꿈치 굽힘/폄 (lElbow)
/// 메카닉: 가마솥의 온도(=각도)를 정확히 맞추고 일정 시간 유지하면 물약 완성.
/// 비주얼: 마법 연구실 — 석벽, 선반, 촛불, 거대 가마솥, 액체 소용돌이
/// ============================================================================

class PotionMakerFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  int score = 0;
  int brewed = 0;
  int failed = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  double _targetPosition = 0.5;
  double _targetRadius = 0.12;
  double _holdTime = 0;
  double _requiredHoldTime = 2.5;
  bool _inTarget = false;
  bool _potionActive = true;
  double _bubbleTimer = 0;
  double _time = 0;

  static const _potionColors = [
    Color(0xFFE53935), Color(0xFF2196F3), Color(0xFF4CAF50),
    Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFFFEB3B),
    Color(0xFF00BCD4), Color(0xFFE91E63),
  ];
  int _potionIndex = 0;

  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _potionLabel;

  PotionMakerFlameGame({this.inputStream, required this.config, required this.onGameEnd})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF0A000F);

  @override
  Future<void> onLoad() async {
    _applyDifficulty();

    // 배경 레이어
    add(_LabBackground(gameSize: size, cogLevel: config.cognitiveLevel.level));

    // HUD
    _scoreText = _HudText(
      text: '⚗ 0',
      pos: Vector2(20, 16),
      anchor: Anchor.topLeft,
      fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22,
    );
    add(_scoreText);

    _potionLabel = _HudText(
      text: '물약 #1',
      pos: Vector2(size.x / 2, 16),
      anchor: Anchor.topCenter,
      color: _potionColors[0],
      fontSize: 18,
    );
    add(_potionLabel);

    if (config.cognitiveLevel.showTimer) {
      _timerText = _HudText(
        text: '${timeRemaining.toInt()}s',
        pos: Vector2(size.x - 20, 16),
        anchor: Anchor.topRight,
        color: Colors.white60,
      );
      add(_timerText);
    } else {
      _timerText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;
    _generateNewPotion();
  }

  void _applyDifficulty() {
    final stage = config.brunnstromStage.level;
    _requiredHoldTime = const {2: 1.5, 3: 2.0, 4: 2.5, 5: 3.0, 6: 4.0}[stage] ?? 2.5;
    _targetRadius = const {2: 0.22, 3: 0.18, 4: 0.14, 5: 0.10, 6: 0.07}[stage] ?? 0.14;
    _targetRadius *= config.cognitiveLevel.sizeMultiplier;
  }

  void _generateNewPotion() {
    final romR = config.romRatio;
    final margin = (1.0 - romR) / 2;
    _targetPosition = margin + _rng.nextDouble() * romR;
    _holdTime = 0;
    _inTarget = false;
    _potionActive = true;
    _potionIndex = brewed % _potionColors.length;
    _potionLabel.updateText('물약 #${brewed + 1}');
    _potionLabel.setColor(_potionColors[_potionIndex]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    _time += dt;
    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    _bubbleTimer += dt;

    if (!_potionActive) return;

    final dist = (currentPosition - _targetPosition).abs();
    _inTarget = dist <= _targetRadius;

    if (_inTarget) {
      _holdTime += dt;
      if (_bubbleTimer > 0.12 && config.cognitiveLevel.bgComplexity >= 1) {
        _bubbleTimer = 0;
        final cx = size.x * 0.38;
        final cy = size.y * 0.54;
        add(_Bubble(
          pos: Vector2(cx + _rng.nextDouble() * 70 - 35, cy + 10),
          color: _potionColors[_potionIndex],
        ));
      }
      if (_holdTime >= _requiredHoldTime) _onPotionComplete();
    } else {
      _holdTime = (_holdTime - dt * 0.5).clamp(0.0, _requiredHoldTime);
    }
  }

  void _onPotionComplete() {
    _potionActive = false;
    brewed++;
    score += 30;
    _scoreText.updateText('⚗ $score');

    add(_FloatingLabel(
      pos: Vector2(size.x * 0.38, size.y * 0.28),
      text: '✨ 완성!',
      color: _potionColors[_potionIndex],
    ));

    if (config.cognitiveLevel.particleCount > 0) {
      add(ParticleSystemComponent(
        position: Vector2(size.x * 0.38, size.y * 0.42),
        particle: GfxUtils.magicStarBurst(_rng, config.cognitiveLevel.particleCount + 8,
            _potionColors[_potionIndex]),
      ));
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (isRunning) _generateNewPotion();
    });
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    final total = brewed + failed;
    onGameEnd(GameResult(
      gameId: 'potion_maker',
      score: score,
      maxPossibleScore: (total + 1) * 30,
      accuracy: total > 0 ? brewed / total : (brewed > 0 ? 1.0 : 0.0),
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: brewed,
      misses: failed,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 가마솥 + 불꽃 + 온도계 + 유지 게이지를 FlameGame.render() 에서 직접 그림
    _renderCauldron(canvas);
    _renderThermometer(canvas);
    _renderHoldProgress(canvas);
    _renderPotionCollection(canvas);
  }

  // ── 가마솥 렌더 ─────────────────────────────────────────────
  void _renderCauldron(Canvas canvas) {
    final cx = size.x * 0.38;
    final cy = size.y * 0.52;
    final potionColor = _potionColors[_potionIndex];
    final pulse = sin(_time * 3) * 0.06 + 1.0;

    // 가마솥 아래 불꽃
    GfxUtils.drawFlame(canvas, Offset(cx - 18, cy + 68), 28, 38, _time,
        innerColor: Colors.yellow, outerColor: Colors.orange);
    GfxUtils.drawFlame(canvas, Offset(cx + 18, cy + 68), 22, 32, _time + 0.5,
        innerColor: Colors.orange, outerColor: const Color(0xFFFF5722));

    // 가마솥 다리 (3개)
    final legPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 55, cy + 52), Offset(cx - 65, cy + 78), legPaint);
    canvas.drawLine(Offset(cx + 55, cy + 52), Offset(cx + 65, cy + 78), legPaint);
    canvas.drawLine(Offset(cx, cy + 60), Offset(cx, cy + 78), legPaint);

    // 가마솥 몸체 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 68), width: 150, height: 18),
      Paint()..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 가마솥 본체 (주철 느낌 — 어두운 그라디언트)
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + 10), width: 160, height: 130);
    final bodyPath = _cauldronBodyPath(cx, cy);

    // 외부 테두리 (리벳 느낌)
    canvas.drawPath(bodyPath,
        Paint()..color = const Color(0xFF212121)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(bodyPath,
        Paint()..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF546E7A), const Color(0xFF263238), const Color(0xFF37474F)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bodyRect));

    // 내부 액체
    final liquidPath = _cauldronLiquidPath(cx, cy);
    final glowAlpha = _inTarget ? 0.85 : 0.55;
    canvas.drawPath(liquidPath, Paint()..color = potionColor.withValues(alpha: glowAlpha));

    // 액체 표면 소용돌이 (회전 타원)
    if (config.cognitiveLevel.bgComplexity >= 1) {
      canvas.save();
      canvas.clipPath(liquidPath);
      for (int i = 0; i < 3; i++) {
        final swAngle = _time * (0.8 + i * 0.3) + i * pi * 0.6;
        final swX = cx + cos(swAngle) * 22;
        final swY = cy - 8 + sin(swAngle) * 8;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(swX, swY), width: 40 + i * 10, height: 10 + i * 3),
          Paint()..color = Colors.white.withValues(alpha: 0.10 - i * 0.02)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.restore();
    }

    // 목표 도달 시 추가 글로우
    if (_inTarget) {
      canvas.drawPath(liquidPath,
          Paint()..color = potionColor.withValues(alpha: 0.4 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }

    // 가마솥 테두리 하이라이트 (상단)
    canvas.drawPath(bodyPath,
        Paint()..color = const Color(0xFF78909C).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // 가마솥 상단 링
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 28), width: 164, height: 30),
      pi, pi,
      false,
      Paint()..color = const Color(0xFF455A64)..strokeWidth = 10..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 28), width: 164, height: 30),
      pi, pi,
      false,
      Paint()..color = const Color(0xFF78909C).withValues(alpha: 0.5)
        ..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );

    // 리벳 (볼트) 4개
    final rivetPositions = [
      Offset(cx - 75, cy + 10), Offset(cx + 75, cy + 10),
      Offset(cx - 65, cy + 40), Offset(cx + 65, cy + 40),
    ];
    for (final rp in rivetPositions) {
      canvas.drawCircle(rp, 5, Paint()..color = const Color(0xFF455A64));
      canvas.drawCircle(Offset(rp.dx - 1, rp.dy - 1), 2,
          Paint()..color = const Color(0xFF78909C).withValues(alpha: 0.5));
    }

    // 증기 (목표 도달 시)
    if (_inTarget && config.cognitiveLevel.bgComplexity >= 1) {
      for (int i = 0; i < 3; i++) {
        final steamX = cx + (i - 1) * 28.0;
        final steamAlpha = sin(_time * 2 + i * 1.2) * 0.12 + 0.12;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(steamX, cy - 45 - sin(_time * 1.5 + i) * 8),
            width: 20, height: 28,
          ),
          Paint()..color = Colors.white.withValues(alpha: steamAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  Path _cauldronBodyPath(double cx, double cy) {
    return Path()
      ..moveTo(cx - 82, cy - 28)
      ..quadraticBezierTo(cx - 88, cy + 30, cx - 55, cy + 55)
      ..lineTo(cx + 55, cy + 55)
      ..quadraticBezierTo(cx + 88, cy + 30, cx + 82, cy - 28)
      ..close();
  }

  Path _cauldronLiquidPath(double cx, double cy) {
    return Path()
      ..moveTo(cx - 74, cy - 18)
      ..quadraticBezierTo(cx - 80, cy + 20, cx - 50, cy + 40)
      ..lineTo(cx + 50, cy + 40)
      ..quadraticBezierTo(cx + 80, cy + 20, cx + 74, cy - 18)
      ..close();
  }

  // ── 온도계 렌더 ─────────────────────────────────────────────
  void _renderThermometer(Canvas canvas) {
    final potionColor = _potionColors[_potionIndex];
    final tx = size.x * 0.82;
    final tTop = size.y * 0.10;
    final tH = size.y * 0.72;

    // 외부 케이스
    GfxUtils.drawShinyRRect(
      canvas,
      Rect.fromLTWH(tx - 12, tTop, 24, tH),
      12,
      const Color(0xFF37474F),
      const Color(0xFF78909C),
      strokeWidth: 1.5,
    );

    // 눈금 + 레이블
    final stages = config.cognitiveLevel.level >= 2
        ? [0.0, 0.25, 0.5, 0.75, 1.0]
        : [0.0, 0.5, 1.0];
    for (final ratio in stages) {
      final y = tTop + (1.0 - ratio) * tH;
      canvas.drawLine(
        Offset(tx - 14, y), Offset(tx - 8, y),
        Paint()..color = Colors.white38..strokeWidth = 1.2,
      );
      if (config.cognitiveLevel.level >= 2) {
        TextPaint(style: const TextStyle(fontSize: 10, color: Colors.white38))
            .render(canvas, '${(ratio * 90).toInt()}°', Vector2(tx - 28, y), anchor: Anchor.centerRight);
      }
    }

    // 목표 존 (녹색 하이라이트)
    final targetCenterY = tTop + (1.0 - _targetPosition) * tH;
    final zoneH = _targetRadius * tH * 2;
    final targetColor = _inTarget ? Colors.greenAccent : potionColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(tx, targetCenterY), width: 32, height: zoneH.clamp(10, tH * 0.4)),
        const Radius.circular(6),
      ),
      Paint()..color = targetColor.withValues(alpha: _inTarget ? 0.4 : 0.25),
    );
    // 목표 존 테두리
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(tx, targetCenterY), width: 32, height: zoneH.clamp(10, tH * 0.4)),
        const Radius.circular(6),
      ),
      Paint()..color = targetColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    // 목표 레이블
    if (config.cognitiveLevel.level >= 2) {
      TextPaint(style: TextStyle(fontSize: 9, color: targetColor.withValues(alpha: 0.8),
          fontWeight: FontWeight.bold))
          .render(canvas, 'TARGET', Vector2(tx + 20, targetCenterY), anchor: Anchor.centerLeft);
    }

    // 현재 수은 채움
    final curY = tTop + (1.0 - currentPosition) * tH;
    final mercuryRect = Rect.fromLTRB(tx - 6, curY, tx + 6, tTop + tH - 12);
    if (mercuryRect.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(mercuryRect, const Radius.circular(4)),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.redAccent, const Color(0xFFB71C1C)],
        ).createShader(mercuryRect),
      );
    }

    // 수은 구형 하단
    canvas.drawCircle(Offset(tx, tTop + tH - 12), 10,
        Paint()..color = const Color(0xFFB71C1C));
    GfxUtils.drawShinyCircle(canvas, Offset(tx, tTop + tH - 12), 10,
        const Color(0xFFB71C1C), Colors.redAccent);

    // 수은 현재 위치 마커
    GfxUtils.drawGlow(canvas, Offset(tx, curY), 8, Colors.redAccent,
        blurSigma: 6, alpha: 0.5);
    canvas.drawCircle(Offset(tx, curY), 7, Paint()..color = Colors.redAccent);
    canvas.drawCircle(Offset(tx - 2, curY - 2), 2.5,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  // ── 유지 프로그레스 ───────────────────────────────────────────
  void _renderHoldProgress(Canvas canvas) {
    if (!_potionActive) return;
    final progress = (_holdTime / _requiredHoldTime).clamp(0.0, 1.0);
    final cx = size.x * 0.38;
    final cy = size.y * 0.52;
    final ringR = 100.0;

    // 배경 트랙
    canvas.drawCircle(Offset(cx, cy + 10), ringR,
        Paint()..color = Colors.white.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    if (progress > 0) {
      final arcColor = Color.lerp(Colors.redAccent, Colors.greenAccent, progress)!;
      // 글로우
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy + 10), radius: ringR),
        -pi / 2, progress * 2 * pi, false,
        Paint()..color = arcColor.withValues(alpha: 0.3)
          ..strokeWidth = 12..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // 실선
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy + 10), radius: ringR),
        -pi / 2, progress * 2 * pi, false,
        Paint()..color = arcColor
          ..strokeWidth = 5..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // 진행 끝 점
      final endAngle = -pi / 2 + progress * 2 * pi;
      final ex = cx + cos(endAngle) * ringR;
      final ey = cy + 10 + sin(endAngle) * ringR;
      GfxUtils.drawGlow(canvas, Offset(ex, ey), 6, arcColor, blurSigma: 5);
      canvas.drawCircle(Offset(ex, ey), 5, Paint()..color = arcColor);
    }

    // 퍼센트 텍스트 (인지 레벨 2+)
    if (config.cognitiveLevel.level >= 2 && progress > 0) {
      TextPaint(style: GoogleFonts.orbitron(
        fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold,
      )).render(canvas, '${(progress * 100).toInt()}%',
          Vector2(cx, cy + 10), anchor: Anchor.center);
    }
  }

  // ── 완성 물약 도감 ───────────────────────────────────────────
  void _renderPotionCollection(Canvas canvas) {
    if (brewed == 0) return;
    final count = min(brewed, 8);
    final startX = size.x * 0.38 - (count - 1) * 22.0 / 2;
    final by = size.y * 0.90;

    for (int i = 0; i < count; i++) {
      final bx = startX + i * 22.0;
      final col = _potionColors[i % _potionColors.length];

      // 병 그림자
      canvas.drawOval(Rect.fromCenter(center: Offset(bx, by + 14), width: 14, height: 4),
          Paint()..color = Colors.black.withValues(alpha: 0.35));

      // 병 몸체
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bx, by + 4), width: 14, height: 22),
          const Radius.circular(4),
        ),
        Paint()..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [col.withValues(alpha: 0.9), col.withValues(alpha: 0.6)],
        ).createShader(Rect.fromCenter(center: Offset(bx, by + 4), width: 14, height: 22)),
      );

      // 병 하이라이트
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bx - 2, by - 1), width: 4, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );

      // 병 마개
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bx, by - 9), width: 7, height: 5),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF6D4C41),
      );

      // 글로우
      GfxUtils.drawGlow(canvas, Offset(bx, by + 4), 9, col,
          blurSigma: 6, alpha: 0.35);
    }
  }
}

// ─── Components ───

class _Bubble extends PositionComponent {
  final Color color;
  double _life = 0;
  final double _speed;
  final double _wobbleOffset;

  _Bubble({required Vector2 pos, required this.color})
      : _speed = 28 + Random().nextDouble() * 22,
        _wobbleOffset = Random().nextDouble() * 6,
        super(position: pos, priority: 6);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= _speed * dt;
    position.x += sin(_life * 4.5 + _wobbleOffset) * 0.6;
    if (_life > 1.6) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.6).clamp(0.0, 1.0);
    final r = 3.5 + _life * 2.5;
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = color.withValues(alpha: a * 0.25));
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = color.withValues(alpha: a * 0.45)
          ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    // 하이라이트
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: a * 0.6));
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
    position.y -= 28 * dt;
    if (_life > 1.3) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.3).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: 26, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: color.withValues(alpha: a * 0.5), blurRadius: 12)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

class _HudText extends PositionComponent {
  String _text;
  Color _color;
  final double fontSize;

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

/// 마법 연구실 배경 — 석벽 + 선반 + 촛불 + 마법진
class _LabBackground extends PositionComponent {
  final Vector2 _gs;
  final int cogLevel;
  double _time = 0;

  _LabBackground({required Vector2 gameSize, required this.cogLevel})
      : _gs = gameSize, super(priority: -10);

  @override
  void update(double dt) { super.update(dt); _time += dt; }

  @override
  void render(Canvas canvas) {
    final w = _gs.x;
    final h = _gs.y;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // ── 배경 그라디언트 ──
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0A000F), Color(0xFF120020), Color(0xFF0D0018)],
      stops: [0.0, 0.5, 1.0],
    ).createShader(rect));

    // ── 석벽 (벽돌 패턴) — 인지 레벨 2+ ──
    if (cogLevel >= 2) {
      _drawStoneWall(canvas, w, h);
    }

    // ── 나무 선반 + 물약병들 (우측) — 인지 레벨 2+ ──
    if (cogLevel >= 2) {
      _drawShelf(canvas, w * 0.68, h * 0.18, w * 0.28, 12);
      _drawShelf(canvas, w * 0.68, h * 0.42, w * 0.28, 10);
      _drawShelfPotions(canvas, w, h);
    }

    // ── 촛불 (좌측) ──
    _drawCandle(canvas, Offset(w * 0.08, h * 0.28), _time);
    if (cogLevel >= 2) {
      _drawCandle(canvas, Offset(w * 0.12, h * 0.55), _time + 0.7);
    }

    // ── 마법진 (바닥) — 인지 레벨 3 ──
    if (cogLevel >= 3) {
      _drawMagicCircle(canvas, Offset(w * 0.38, h * 0.80), 60, _time);
    }

    // ── 주변 마법 파티클 ──
    if (cogLevel >= 2) {
      for (int i = 0; i < 8; i++) {
        final px = w * (0.05 + (i * 0.13) % 0.9);
        final py = h * 0.15 + sin(_time * 0.6 + i * 0.9) * h * 0.08;
        final alpha = sin(_time * 1.2 + i * 1.5) * 0.08 + 0.08;
        canvas.drawCircle(Offset(px, py), 1.5 + (i % 3),
            Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: alpha));
      }
    }
  }

  void _drawStoneWall(Canvas canvas, double w, double h) {
    final mortarPaint = Paint()..color = const Color(0xFF1A0030).withValues(alpha: 0.4);
    final stonePaint = Paint()..color = const Color(0xFF1E0035).withValues(alpha: 0.35);

    const brickH = 28.0;
    const brickW = 55.0;
    int row = 0;
    for (double y = 0; y < h; y += brickH) {
      final offset = (row % 2) * (brickW / 2);
      for (double x = -offset; x < w; x += brickW) {
        canvas.drawRect(
          Rect.fromLTWH(x + 1, y + 1, brickW - 2, brickH - 2),
          stonePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(x, y, brickW, brickH),
          mortarPaint..style = PaintingStyle.stroke..strokeWidth = 1.0,
        );
      }
      row++;
    }
  }

  void _drawShelf(Canvas canvas, double x, double y, double width, double depth) {
    // 선반 상판
    canvas.drawRect(Rect.fromLTWH(x, y, width, depth.toDouble()),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF5D4037), const Color(0xFF3E2723)],
        ).createShader(Rect.fromLTWH(x, y, width, depth.toDouble())));
    // 선반 앞면 하이라이트
    canvas.drawLine(Offset(x, y), Offset(x + width, y),
        Paint()..color = const Color(0xFF8D6E63).withValues(alpha: 0.6)..strokeWidth = 1.5);
    // 선반 하단 그림자
    canvas.drawRect(Rect.fromLTWH(x, y + depth, width, 4),
        Paint()..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _drawShelfPotions(Canvas canvas, double w, double h) {
    // 상단 선반 물약들
    final bottles = [
      (w * 0.70, h * 0.13, const Color(0xFF9C27B0), 14.0, 24.0),
      (w * 0.77, h * 0.12, const Color(0xFF2196F3), 11.0, 28.0),
      (w * 0.83, h * 0.14, const Color(0xFF4CAF50), 13.0, 20.0),
      (w * 0.89, h * 0.13, const Color(0xFFFF9800), 10.0, 26.0),
    ];
    for (final b in bottles) {
      _drawDecorBottle(canvas, b.$1, b.$2, b.$3, b.$4, b.$5, _time);
    }
    // 하단 선반
    final bottles2 = [
      (w * 0.71, h * 0.37, const Color(0xFFE91E63), 12.0, 22.0),
      (w * 0.78, h * 0.36, const Color(0xFF00BCD4), 14.0, 18.0),
      (w * 0.85, h * 0.38, const Color(0xFFFFEB3B), 10.0, 24.0),
      (w * 0.92, h * 0.37, const Color(0xFFE53935), 12.0, 20.0),
    ];
    for (final b in bottles2) {
      _drawDecorBottle(canvas, b.$1, b.$2, b.$3, b.$4, b.$5, _time + 0.5);
    }
  }

  void _drawDecorBottle(Canvas canvas, double bx, double by, Color col,
      double bw, double bh, double time) {
    // 글로우
    canvas.drawCircle(Offset(bx, by + bh * 0.4), bw * 0.6,
        Paint()..color = col.withValues(alpha: 0.2 + sin(time * 1.5) * 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // 병 몸체
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx, by + bh * 0.4), width: bw, height: bh),
        const Radius.circular(4),
      ),
      Paint()..color = col.withValues(alpha: 0.75),
    );

    // 하이라이트
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx - bw * 0.2, by + bh * 0.15), width: bw * 0.3, height: bh * 0.45),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // 마개
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx, by - 2), width: bw * 0.5, height: 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6D4C41),
    );
  }

  void _drawCandle(Canvas canvas, Offset base, double time) {
    // 촛농 + 몸체
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy + 8), width: 14, height: 35),
        const Radius.circular(3),
      ),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, const Color(0xFFFFF9C4), const Color(0xFFFFF59D)],
      ).createShader(Rect.fromCenter(center: Offset(base.dx, base.dy + 8), width: 14, height: 35)),
    );

    // 심지
    canvas.drawLine(Offset(base.dx, base.dy - 9), Offset(base.dx + 1, base.dy - 16),
        Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.5..strokeCap = StrokeCap.round);

    // 불꽃
    GfxUtils.drawFlame(canvas, Offset(base.dx + 1, base.dy - 14), 10, 16, time,
        innerColor: Colors.yellow, outerColor: Colors.orange);

    // 촛불 광원 글로우
    final glowAlpha = sin(time * 6) * 0.04 + 0.12;
    canvas.drawCircle(Offset(base.dx, base.dy - 20), 28,
        Paint()..color = Colors.amber.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
  }

  void _drawMagicCircle(Canvas canvas, Offset center, double radius, double time) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 외부 회전 원
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(time * 0.3);
    paint.color = const Color(0xFF7C4DFF).withValues(alpha: 0.25);
    canvas.drawCircle(Offset.zero, radius, paint);
    // 8각 별
    canvas.drawPath(
      GfxUtils.starPath(Offset.zero, radius * 0.92, radius * 0.55, 8),
      Paint()..color = const Color(0xFF9C27B0).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    canvas.restore();

    // 내부 역방향 원
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-time * 0.5);
    paint.color = const Color(0xFFAA00FF).withValues(alpha: 0.18);
    canvas.drawCircle(Offset.zero, radius * 0.6, paint);
    canvas.restore();
  }
}

// ─── Flutter Wrapper ───

class PotionMakerGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const PotionMakerGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<PotionMakerGame> createState() => _PotionMakerGameState();
}

class _PotionMakerGameState extends State<PotionMakerGame> {
  late PotionMakerFlameGame _game;
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
    _game = PotionMakerFlameGame(
      inputStream: stream,
      config: widget.config,
      onGameEnd: (r) {
        _motor.safeStop();
        _motor.dispose();
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
    color: const Color(0xFF1a0a2e),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Row(children: [
      const Text('굽힘', style: TextStyle(color: Colors.white54, fontSize: 12)),
      Expanded(child: SliderTheme(
        data: SliderThemeData(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
          trackHeight: 8,
          activeTrackColor: Colors.purpleAccent,
          thumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
        ),
        child: Slider(
          value: _simValue,
          onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); },
        ),
      )),
      const Text('폄', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]),
  );

  Widget _controlBar(AppLocalizations loc) => Container(
    color: const Color(0xFF1a0a2e),
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12, foregroundColor: Colors.white),
        onPressed: () => _game.isRunning = !_game.isRunning,
        icon: const Icon(Icons.pause),
        label: Text(loc.pauseGame),
      ),
      const SizedBox(width: 16),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent)),
        onPressed: () { _motor.safeStop(); _game.endGame(); },
        icon: const Icon(Icons.stop),
        label: Text(loc.stop),
      ),
    ]),
  );
}
