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
/// [E2] 목공 장인 (Carpenter)
/// 관절: 팔꿈치 굽힘/폄 (lElbow)
/// 메카닉: 톱질 — 팔꿈치를 반복적으로 굽혔다 펴서 나무를 자른다.
///         완전 굽힘→완전 폄 1사이클 = 1컷. 나무가 잘리면 점수.
/// 임상 근거: JMIR "Carpenter game" — 팔꿈치 반복 운동 재활 효과 입증
/// ============================================================================
class CarpenterFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  int score = 0;
  int totalCuts = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  // 톱질 상태
  double _cycleMin = 1.0; // 현재 사이클 내 최소값 (굽힘 끝)
  double _cycleMax = 0.0; // 현재 사이클 내 최대값 (폄 끝)
  bool _wentLow = false; // 충분히 굽혔는지
  bool _wentHigh = false; // 충분히 폈는지
  double _requiredRom = 0.5; // 필요한 ROM 비율 (0~1 중 이만큼 이동해야 1컷)

  // 나무 상태
  double _woodProgress = 0.0; // 0~1 (1이면 완전히 잘림)
  int _furnitureLevel = 0; // 완성 가구 수

  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _cutsText;

  CarpenterFlameGame({this.inputStream, required this.config, required this.onGameEnd})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF1C0F00);

  @override
  Future<void> onLoad() async {
    _applyDifficulty();
    add(_WoodshopBackground(gameSize: size));

    // 배경 (인지 레벨 2+)
    if (config.cognitiveLevel.bgComplexity >= 1) {
      // 작업대
      add(RectangleComponent(position: Vector2(0, size.y * 0.65),
          size: Vector2(size.x, size.y * 0.35),
          paint: Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.5)));
    }

    _scoreText = _HudText(text: '🪑 0', pos: Vector2(20, 16), anchor: Anchor.topLeft,
        fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22);
    add(_scoreText);

    _cutsText = _HudText(text: '톱질: 0', pos: Vector2(size.x / 2, 16),
        anchor: Anchor.topCenter, color: Colors.orange);
    add(_cutsText);

    if (config.cognitiveLevel.showTimer) {
      _timerText = _HudText(text: '${timeRemaining.toInt()}s',
          pos: Vector2(size.x - 20, 16), anchor: Anchor.topRight, color: Colors.white70);
      add(_timerText);
    } else {
      _timerText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;
  }

  void _applyDifficulty() {
    final stage = config.brunnstromStage.level;
    // Stage가 낮을수록 적은 ROM으로 1컷 인정
    _requiredRom = const {2: 0.3, 3: 0.4, 4: 0.5, 5: 0.6, 6: 0.7}[stage] ?? 0.5;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    // 사이클 추적: 굽힘(0쪽)→폄(1쪽) 왕복
    if (currentPosition < 0.2) _wentLow = true;
    if (currentPosition > 0.8) _wentHigh = true;

    _cycleMin = min(_cycleMin, currentPosition);
    _cycleMax = max(_cycleMax, currentPosition);

    // ROM이 충분하면 1컷 완성
    final rom = _cycleMax - _cycleMin;
    if (_wentLow && _wentHigh && rom >= _requiredRom) {
      _onCut();
      // 사이클 리셋
      _cycleMin = 1.0;
      _cycleMax = 0.0;
      _wentLow = false;
      _wentHigh = false;
    }
  }

  void _onCut() {
    totalCuts++;
    _cutsText.updateText('톱질: $totalCuts');

    // 나무 진행
    _woodProgress += 0.2; // 5컷에 1개 완성
    if (_woodProgress >= 1.0) {
      _woodProgress = 0.0;
      _furnitureLevel++;
      score += 50;
      _scoreText.updateText('🪑 $score');

      add(_FloatingLabel(pos: Vector2(size.x * 0.5, size.y * 0.35),
          text: _furnitureName(), color: Colors.amberAccent));

      // 완성 파티클
      if (config.cognitiveLevel.particleCount > 0) {
        _spawnWoodParticles(Vector2(size.x * 0.5, size.y * 0.5));
      }
    } else {
      score += 10;
      _scoreText.updateText('🪑 $score');

      // 톱밥 파티클
      if (config.cognitiveLevel.particleCount > 0) {
        _spawnSawdustParticles();
      }
    }
  }

  String _furnitureName() {
    const names = ['의자 완성! 🪑', '탁자 완성! 🪵', '책장 완성! 📚', '침대 완성! 🛏️', '장롱 완성! 🗄️'];
    return names[(_furnitureLevel - 1) % names.length];
  }

  void _spawnSawdustParticles() {
    final cutX = size.x * 0.5;
    final cutY = size.y * 0.55;
    add(ParticleSystemComponent(position: Vector2(cutX, cutY),
      particle: fp.Particle.generate(count: config.cognitiveLevel.particleCount, lifespan: 0.4,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 80 - 40, -_rng.nextDouble() * 60),
          acceleration: Vector2(0, 200),
          child: fp.CircleParticle(radius: 1 + _rng.nextDouble() * 2,
            paint: Paint()..color = const Color(0xFFDEB887).withValues(alpha: 0.7))))));
  }

  void _spawnWoodParticles(Vector2 pos) {
    add(ParticleSystemComponent(position: pos,
      particle: fp.Particle.generate(count: config.cognitiveLevel.particleCount, lifespan: 0.8,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 160 - 80, -_rng.nextDouble() * 140),
          acceleration: Vector2(0, 250),
          child: fp.ScalingParticle(to: 0,
            child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 4,
              paint: Paint()..color = Colors.amberAccent.withValues(alpha: 0.8)))))));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'carpenter', score: score, maxPossibleScore: score + 50,
      accuracy: totalCuts > 0 ? 1.0 : 0.0, duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel, bodyPart: config.bodyPart,
      timestamp: DateTime.now(), calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle, hits: totalCuts, misses: 0,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);
  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = size.x * 0.5;
    final woodY = size.y * 0.55;

    // 나무판
    final woodW = size.x * 0.6;
    final woodH = 40.0;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, woodY), width: woodW, height: woodH),
        const Radius.circular(4)),
        Paint()..color = const Color(0xFF8D6E63));
    // 나무결
    for (int i = 0; i < 5; i++) {
      final ly = woodY - woodH / 2 + 8 + i * 7.0;
      canvas.drawLine(Offset(cx - woodW / 2 + 10, ly), Offset(cx + woodW / 2 - 10, ly),
          Paint()..color = const Color(0xFF6D4C41).withValues(alpha: 0.3)..strokeWidth = 1);
    }

    // 절단선 (진행도)
    final cutX = cx;
    final cutDepth = woodH * _woodProgress;
    if (_woodProgress > 0) {
      canvas.drawLine(Offset(cutX, woodY - woodH / 2),
          Offset(cutX, woodY - woodH / 2 + cutDepth),
          Paint()..color = const Color(0xFF3E2723)..strokeWidth = 3);
    }

    // 톱 (현재 위치에 따라 좌우 이동)
    final sawX = cx - woodW * 0.3 + currentPosition * woodW * 0.6;
    final sawY = woodY - woodH / 2 - 5;
    _drawSaw(canvas, Offset(sawX, sawY));

    // 진행도 바 (하단)
    final barY = size.y * 0.78;
    final barW = size.x * 0.6;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, barY, barW, 12), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, barY, barW * _woodProgress, 12), const Radius.circular(6)),
        Paint()..color = Colors.orange);

    // ROM 가이드 (좌: 굽힘, 우: 폄)
    final guideY = size.y * 0.85;
    final guideColor = Colors.white.withValues(alpha: 0.3);
    TextPaint(style: TextStyle(fontSize: 13, color: guideColor))
        .render(canvas, '굽힘 ←', Vector2(cx - barW / 2, guideY), anchor: Anchor.topLeft);
    TextPaint(style: TextStyle(fontSize: 13, color: guideColor))
        .render(canvas, '→ 폄', Vector2(cx + barW / 2, guideY), anchor: Anchor.topRight);

    // 왕복 상태 표시
    final lowOk = _wentLow ? Colors.greenAccent : Colors.white24;
    final highOk = _wentHigh ? Colors.greenAccent : Colors.white24;
    canvas.drawCircle(Offset(cx - barW / 2 - 15, barY + 6), 6, Paint()..color = lowOk);
    canvas.drawCircle(Offset(cx + barW / 2 + 15, barY + 6), 6, Paint()..color = highOk);

    // 완성 가구 카운터
    if (_furnitureLevel > 0) {
      TextPaint(style: const TextStyle(fontSize: 16, color: Colors.amberAccent))
          .render(canvas, '완성: $_furnitureLevel개', Vector2(cx, size.y * 0.92), anchor: Anchor.center);
    }
  }

  void _drawSaw(Canvas canvas, Offset pos) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    // 손잡이
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -20, 16, 20), const Radius.circular(3)),
        Paint()..color = const Color(0xFF8D6E63));
    // 톱날
    final bladePath = Path()..moveTo(-15, 0);
    for (int i = 0; i < 10; i++) {
      bladePath.lineTo(-15 + i * 5.0, (i % 2 == 0) ? -4 : 0);
    }
    bladePath.lineTo(35, 0);
    bladePath.lineTo(-15, 0);
    canvas.drawPath(bladePath, Paint()..color = const Color(0xFFBDBDBD));
    canvas.restore();
  }
}

// ─── Components ───

class _FloatingLabel extends PositionComponent {
  final String text; final Color color; double _life = 0;
  _FloatingLabel({required Vector2 pos, required this.text, required this.color})
      : super(position: pos, anchor: Anchor.center, priority: 20);
  @override
  void update(double dt) { super.update(dt); _life += dt; position.y -= 35 * dt; if (_life > 1.5) removeFromParent(); }
  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.5).clamp(0.0, 1.0);
    TextPaint(style: TextStyle(fontSize: 24, color: color.withValues(alpha: a), fontWeight: FontWeight.bold,
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
  @override
  void render(Canvas canvas) {
    if (_text.isEmpty) return;
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: _color, fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
    )).render(canvas, _text, Vector2.zero(), anchor: anchor);
  }
}

class _WoodshopBackground extends PositionComponent {
  final Vector2 _gs;
  _WoodshopBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: -10);
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF3E2000), Color(0xFF1C0F00)],
    ).createShader(rect));
    // 나뭇결 패턴
    final grainPaint = Paint()..color = Colors.brown.withValues(alpha: 0.08)..strokeWidth = 1;
    for (double y = 0; y < _gs.y; y += 12) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < _gs.x; x += 30) {
        path.lineTo(x + 15, y + 2);
        path.lineTo(x + 30, y);
      }
      canvas.drawPath(path, grainPaint);
    }
  }
}

// ─── Flutter Wrapper ───

class CarpenterGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const CarpenterGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<CarpenterGame> createState() => _CarpenterGameState();
}

class _CarpenterGameState extends State<CarpenterGame> {
  late CarpenterFlameGame _game;
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
    _game = CarpenterFlameGame(inputStream: stream, config: widget.config, onGameEnd: (r) {
      _motor.safeStop(); _motor.dispose();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
    });
    if (!_isSim) { _motor.selectJoint(widget.config.bodyPart); _motor.startWatchdog(); }
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
          color: const Color(0xFF3E2723), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Row(children: [
            const Text('굽힘', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Expanded(child: SliderTheme(
              data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                  trackHeight: 8, activeTrackColor: Colors.orange, thumbColor: Colors.white, inactiveTrackColor: Colors.white24),
              child: Slider(value: _simValue, onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); }),
            )),
            const Text('폄', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        Container(color: const Color(0xFF3E2723), padding: const EdgeInsets.only(bottom: 6, top: 2),
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
