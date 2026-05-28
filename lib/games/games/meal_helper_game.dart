import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
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
/// [C2] 식사 도우미 (Meal Helper)
/// 관절: 어깨 굽힘/폄 → 팔꿈치 굽힘/폄 (관절 전환)
/// 메카닉: 2단계 반복
///   1단계: 어깨를 움직여 팔을 뻗어 음식에 닿기 (lShoulderEF)
///   2단계: 팔꿈치를 구부려 음식을 입으로 가져오기 (lElbow)
/// ADL 시뮬레이션: 실제 식사 동작과 동일한 관절 시퀀스
/// ============================================================================
class MealHelperFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;
  final GameMotorController? motor;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  int score = 0;
  int eaten = 0;
  int missed = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  // 2단계 메카닉
  int _phase = 1; // 1=팔뻗기(어깨), 2=입으로(팔꿈치)
  double _targetPosition = 0.7; // 음식 위치
  double _targetRadius = 0.15;
  double _holdTime = 0;
  double _requiredHoldTime = 1.0;
  bool _inTarget = false;
  double _phaseTransitionTimer = 0;
  bool _transitioning = false;

  // 음식 종류
  static const _foodNames = ['밥 🍚', '국 🍲', '반찬 🥗', '고기 🍖', '생선 🐟', '과일 🍎'];
  static const _foodColors = [
    Color(0xFFFFFFFF), Color(0xFFFF7043), Color(0xFF66BB6A),
    Color(0xFF8D6E63), Color(0xFF42A5F5), Color(0xFFE53935),
  ];
  int _currentFood = 0;

  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _phaseText;

  MealHelperFlameGame({this.inputStream, required this.config, required this.onGameEnd, this.motor})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF1A1200);

  @override
  Future<void> onLoad() async {
    _applyDifficulty();
    add(_KitchenBackground(gameSize: size));

    // 식탁 배경
    if (config.cognitiveLevel.bgComplexity >= 1) {
      add(RectangleComponent(position: Vector2(0, size.y * 0.4),
          size: Vector2(size.x, size.y * 0.6),
          paint: Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.3)));
    }

    _scoreText = _HudText(text: '🍽 0', pos: Vector2(20, 16), anchor: Anchor.topLeft,
        fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22);
    add(_scoreText);

    _phaseText = _HudText(text: '1단계: 팔 뻗기 (어깨)', pos: Vector2(size.x / 2, 16),
        anchor: Anchor.topCenter, color: Colors.amberAccent);
    add(_phaseText);

    if (config.cognitiveLevel.showTimer) {
      _timerText = _HudText(text: '${timeRemaining.toInt()}s',
          pos: Vector2(size.x - 20, 16), anchor: Anchor.topRight, color: Colors.white70);
      add(_timerText);
    } else {
      _timerText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;
    _generateNewFood();
  }

  void _applyDifficulty() {
    final stage = config.brunnstromStage.level;
    _requiredHoldTime = const {2: 0.8, 3: 1.0, 4: 1.2, 5: 1.5, 6: 2.0}[stage] ?? 1.2;
    _targetRadius = const {2: 0.25, 3: 0.20, 4: 0.15, 5: 0.12, 6: 0.08}[stage] ?? 0.15;
    _targetRadius *= config.cognitiveLevel.sizeMultiplier;
  }

  void _generateNewFood() {
    _phase = 1;
    _currentFood = _rng.nextInt(_foodNames.length);
    final romR = config.romRatio;
    final margin = (1.0 - romR) / 2;
    _targetPosition = margin + 0.5 * romR + _rng.nextDouble() * 0.4 * romR; // 중간~높은 위치 (팔 뻗기)
    _holdTime = 0;
    _inTarget = false;
    _transitioning = false;
    _phaseText.updateText('1단계: 팔 뻗기 (어깨)');
    _phaseText.setColor(Colors.amberAccent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    if (_transitioning) {
      _phaseTransitionTimer += dt;
      if (_phaseTransitionTimer > 1.0) {
        _transitioning = false;
        _phaseTransitionTimer = 0;
      }
      return;
    }

    final dist = (currentPosition - _targetPosition).abs();
    _inTarget = dist <= _targetRadius;

    if (_inTarget) {
      _holdTime += dt;
      if (_holdTime >= _requiredHoldTime) {
        if (_phase == 1) {
          _onPhase1Complete();
        } else {
          _onPhase2Complete();
        }
      }
    } else {
      _holdTime = (_holdTime - dt * 0.3).clamp(0.0, _requiredHoldTime);
    }
  }

  void _onPhase1Complete() {
    // 1단계 성공: 음식 잡기
    score += 10;
    _scoreText.updateText('🍽 $score');

    add(_FloatingLabel(pos: Vector2(size.x * 0.5, size.y * 0.35),
        text: '✅ 음식 잡기 성공!', color: Colors.greenAccent));

    // 모터 전환: 어깨 → 팔꿈치
    motor?.safeStop();
    motor?.selectJoint('lElbow');

    // 2단계로 전환
    _phase = 2;
    _targetPosition = 0.2 + _rng.nextDouble() * 0.15; // 낮은 위치 (팔꿈치 굽힘 = 입으로)
    _holdTime = 0;
    _inTarget = false;
    _transitioning = true;
    _phaseTransitionTimer = 0;
    _phaseText.updateText('2단계: 입으로 가져오기 (팔꿈치)');
    _phaseText.setColor(Colors.lightGreenAccent);
  }

  void _onPhase2Complete() {
    // 2단계 성공: 식사 완료
    eaten++;
    score += 20;
    _scoreText.updateText('🍽 $score');

    final foodName = _foodNames[_currentFood];
    add(_FloatingLabel(pos: Vector2(size.x * 0.5, size.y * 0.3),
        text: '$foodName 맛있다!', color: _foodColors[_currentFood]));

    if (config.cognitiveLevel.particleCount > 0) {
      _spawnEatParticles();
    }

    // 모터 전환: 팔꿈치 → 어깨 (다음 음식)
    motor?.safeStop();
    motor?.selectJoint('lShoulderEF');

    // 다음 음식
    _transitioning = true;
    _phaseTransitionTimer = 0;
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (isRunning) _generateNewFood();
    });
  }

  void _spawnEatParticles() {
    add(ParticleSystemComponent(position: Vector2(size.x * 0.5, size.y * 0.25),
      particle: fp.Particle.generate(count: config.cognitiveLevel.particleCount, lifespan: 0.6,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 100 - 50, -_rng.nextDouble() * 80),
          acceleration: Vector2(0, 200),
          child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 3,
            paint: Paint()..color = _foodColors[_currentFood].withValues(alpha: 0.7))))));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'meal_helper', score: score, maxPossibleScore: score + missed * 30,
      accuracy: (eaten + missed) > 0 ? eaten / (eaten + missed) : (eaten > 0 ? 1.0 : 0.0),
      duration: config.gameDuration, difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart, timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle, calibrationMax: config.normalizer.maxAngle,
      hits: eaten, misses: missed,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);
  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cx = size.x * 0.5;

    // 접시 (중앙)
    final plateY = size.y * 0.55;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, plateY), width: 180, height: 50),
        Paint()..color = Colors.white.withValues(alpha: 0.15));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, plateY), width: 180, height: 50),
        Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2);

    // 음식 (접시 위)
    if (_phase == 1 || _transitioning) {
      _drawFood(canvas, Offset(cx, plateY - 10));
    }

    // 입 (상단)
    final mouthY = size.y * 0.18;
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: 50, height: 30),
        0.2, pi - 0.4, false,
        Paint()..color = const Color(0xFFE57373)..strokeWidth = 4..style = PaintingStyle.stroke);
    if (_phase == 2) {
      // 입 열기
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: 50, height: 40),
          0.3, pi - 0.6, false,
          Paint()..color = const Color(0xFFE57373)..style = PaintingStyle.fill);
    }

    // 숟가락/손 위치 표시
    final handY = size.y * 0.1 + (1.0 - currentPosition) * size.y * 0.7;
    _drawSpoon(canvas, Offset(cx + 100, handY), _phase == 2);

    // 타겟 존
    final targetY = size.y * 0.1 + (1.0 - _targetPosition) * size.y * 0.7;
    final zoneH = _targetRadius * size.y * 0.7 * 2;
    final zoneColor = _inTarget ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.amberAccent.withValues(alpha: 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 100, targetY), width: 60, height: zoneH),
        const Radius.circular(8)), Paint()..color = zoneColor);

    // 유지 프로그레스
    final progress = (_holdTime / _requiredHoldTime).clamp(0.0, 1.0);
    if (progress > 0 && !_transitioning) {
      final barW = 120.0 * progress;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 60, size.y * 0.85, barW, 10), const Radius.circular(5)),
          Paint()..color = Color.lerp(Colors.orange, Colors.green, progress)!);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 60, size.y * 0.85, 120, 10), const Radius.circular(5)),
          Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke);
    }

    // 단계 가이드
    final guideText = _phase == 1 ? '어깨: 팔을 뻗어 음식에 닿기' : '팔꿈치: 구부려서 입으로';
    TextPaint(style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)))
        .render(canvas, guideText, Vector2(cx, size.y * 0.93), anchor: Anchor.center);

    // 먹은 음식 카운터
    for (int i = 0; i < min(eaten, 10); i++) {
      final fx = size.x * 0.05 + i * 28.0;
      canvas.drawCircle(Offset(fx, size.y * 0.42), 8,
          Paint()..color = _foodColors[i % _foodColors.length].withValues(alpha: 0.6));
    }
  }

  void _drawFood(Canvas canvas, Offset pos) {
    final color = _foodColors[_currentFood];
    canvas.drawCircle(pos, 18, Paint()..color = color.withValues(alpha: 0.8));
    canvas.drawCircle(Offset(pos.dx - 3, pos.dy - 4), 5,
        Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  void _drawSpoon(Canvas canvas, Offset pos, bool hasFood) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    // 손잡이
    canvas.drawLine(const Offset(0, 8), const Offset(0, 35),
        Paint()..color = const Color(0xFFBDBDBD)..strokeWidth = 3..strokeCap = StrokeCap.round);
    // 숟가락 머리
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 18, height: 12),
        Paint()..color = const Color(0xFFBDBDBD));
    // 음식 (2단계)
    if (hasFood) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -1), width: 12, height: 7),
          Paint()..color = _foodColors[_currentFood].withValues(alpha: 0.8));
    }
    canvas.restore();
  }
}

// ─── Components ───

class _FloatingLabel extends PositionComponent {
  final String text; final Color color; double _life = 0;
  _FloatingLabel({required Vector2 pos, required this.text, required this.color})
      : super(position: pos, anchor: Anchor.center, priority: 20);
  @override
  void update(double dt) { super.update(dt); _life += dt; position.y -= 30 * dt; if (_life > 1.3) removeFromParent(); }
  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.3).clamp(0.0, 1.0);
    TextPaint(style: TextStyle(fontSize: 22, color: color.withValues(alpha: a), fontWeight: FontWeight.bold,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]))
        .render(canvas, text, Vector2.zero(), anchor: Anchor.center);
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

class _KitchenBackground extends PositionComponent {
  final Vector2 _gs;
  _KitchenBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: -10);
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF3E2800), Color(0xFF1A1200)],
    ).createShader(rect));
    // 타일 패턴
    final tilePaint = Paint()..color = Colors.white.withValues(alpha: 0.04)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double x = 0; x < _gs.x; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, _gs.y), tilePaint);
    }
    for (double y = 0; y < _gs.y; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(_gs.x, y), tilePaint);
    }
  }
}

// ─── Flutter Wrapper ───

class MealHelperGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const MealHelperGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<MealHelperGame> createState() => _MealHelperGameState();
}

class _MealHelperGameState extends State<MealHelperGame> {
  late MealHelperFlameGame _game;
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
    _game = MealHelperFlameGame(inputStream: stream, config: widget.config, motor: _isSim ? null : _motor,
        onGameEnd: (r) {
      _motor.safeStop(); _motor.dispose();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
    });
    if (!_isSim) {
      _motor.selectJoint('lShoulderEF'); // 1단계: 어깨부터 시작
      _motor.startWatchdog();
    }
  }

  @override
  void dispose() { _motor.safeStop(); _motor.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(body: Stack(children: [
      Column(children: [
        Expanded(child: GameWidget(game: _game)),
        if (_isSim) Container(
          color: const Color(0xFF2E1A0E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Row(children: [
            const Text('⬇', style: TextStyle(color: Colors.white54)),
            Expanded(child: SliderTheme(
              data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                  trackHeight: 8, activeTrackColor: Colors.amberAccent, thumbColor: Colors.white, inactiveTrackColor: Colors.white24),
              child: Slider(value: _simValue, onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); }),
            )),
            const Text('⬆', style: TextStyle(color: Colors.white54)),
          ]),
        ),
        Container(color: const Color(0xFF2E1A0E), padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                onPressed: () => _game.isRunning = !_game.isRunning, icon: const Icon(Icons.pause), label: Text(loc.pauseGame)),
            const SizedBox(width: 16),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                onPressed: () { _motor.safeStop(); _game.endGame(); }, icon: const Icon(Icons.stop), label: Text(loc.stop)),
          ])),
      ]),
      Positioned(right: 16, bottom: 80, child: FloatingActionButton(
        backgroundColor: Colors.red, onPressed: () { _motor.emergencyStop(); _game.endGame(); },
        child: const Icon(Icons.stop, color: Colors.white, size: 32))),
    ]));
  }
}
