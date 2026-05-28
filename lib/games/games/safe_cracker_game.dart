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
/// [S4] 금고 털이범 (Safe Cracker)
/// 관절: 어깨 내회전/외회전 (lShoulderRo) — 팔꿈치 90° 굽힘 고정
/// 메카닉: 금고 다이얼을 어깨 회전으로 돌려 목표 숫자에 맞추고 유지.
/// 공동운동 분리 핵심 운동: 팔꿈치 고정 상태에서 어깨 회전만 독립 수행
/// ============================================================================
class SafeCrackerFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  int score = 0;
  int cracked = 0;
  int failed = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  // 금고 상태
  late List<double> _combination; // 현재 금고의 목표 조합 (정규화 0~1)
  int _currentStep = 0; // 조합 내 현재 단계
  double _holdTime = 0;
  bool _inTarget = false;
  double _requiredHoldTime = 2.0;
  double _targetRadius = 0.12;
  int _safesOpened = 0;
  int _comboCount = 2; // 금고당 조합 수

  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _safeText;

  SafeCrackerFlameGame({this.inputStream, required this.config, required this.onGameEnd})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF0A0A14);

  @override
  Future<void> onLoad() async {
    _applyDifficulty();
    add(_VaultBackground(gameSize: size));

    _scoreText = _HudText(text: '💰 0', pos: Vector2(20, 16), anchor: Anchor.topLeft,
        fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22);
    add(_scoreText);

    _safeText = _HudText(text: '금고 #1', pos: Vector2(size.x / 2, 16),
        anchor: Anchor.topCenter, color: Colors.amberAccent);
    add(_safeText);

    if (config.cognitiveLevel.showTimer) {
      _timerText = _HudText(text: '${timeRemaining.toInt()}s',
          pos: Vector2(size.x - 20, 16), anchor: Anchor.topRight, color: Colors.white70);
      add(_timerText);
    } else {
      _timerText = _HudText(text: '', pos: Vector2.zero(), anchor: Anchor.topLeft);
    }

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;
    _generateNewSafe();
  }

  void _applyDifficulty() {
    final stage = config.brunnstromStage.level;
    _comboCount = const {2: 2, 3: 2, 4: 3, 5: 3, 6: 4}[stage] ?? 3;
    _requiredHoldTime = const {2: 1.0, 3: 1.5, 4: 2.0, 5: 2.5, 6: 3.0}[stage] ?? 2.0;
    _targetRadius = const {2: 0.20, 3: 0.15, 4: 0.10, 5: 0.07, 6: 0.05}[stage] ?? 0.10;
    _targetRadius *= config.cognitiveLevel.sizeMultiplier;
  }

  void _generateNewSafe() {
    _combination = List.generate(_comboCount, (_) {
      final romR = config.romRatio;
      final margin = (1.0 - romR) / 2;
      return margin + _rng.nextDouble() * romR;
    });
    _currentStep = 0;
    _holdTime = 0;
    _inTarget = false;
    _safesOpened++;
    _safeText.updateText('금고 #$_safesOpened');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    if (_currentStep >= _combination.length) return; // 애니메이션 대기

    final target = _combination[_currentStep];
    final dist = (currentPosition - target).abs();
    _inTarget = dist <= _targetRadius;

    if (_inTarget) {
      _holdTime += dt;
      if (_holdTime >= _requiredHoldTime) {
        _onStepSuccess();
      }
    } else {
      _holdTime = (_holdTime - dt * 0.3).clamp(0.0, _requiredHoldTime);
    }
  }

  void _onStepSuccess() {
    cracked++;
    score += 15;
    _scoreText.updateText('💰 $score');

    // 잠금해제 이펙트
    if (config.cognitiveLevel.particleCount > 0) {
      _spawnLockParticles();
    }
    add(_FloatingLabel(pos: Vector2(size.x * 0.5, size.y * 0.3),
        text: '🔓 ${_currentStep + 1}/${_combination.length}', color: Colors.greenAccent));

    _currentStep++;
    _holdTime = 0;
    _inTarget = false;

    // 금고 오픈 완료
    if (_currentStep >= _combination.length) {
      score += 30; // 금고 보너스
      _scoreText.updateText('💰 $score');
      add(_FloatingLabel(pos: Vector2(size.x * 0.5, size.y * 0.45),
          text: '💎 SAFE OPENED!', color: Colors.amberAccent));

      // 다음 금고
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (isRunning) _generateNewSafe();
      });
    }
  }

  void _spawnLockParticles() {
    add(ParticleSystemComponent(position: Vector2(size.x * 0.5, size.y * 0.5),
      particle: fp.Particle.generate(count: config.cognitiveLevel.particleCount, lifespan: 0.6,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 140 - 70, -_rng.nextDouble() * 100),
          acceleration: Vector2(0, 250),
          child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 3,
            paint: Paint()..color = Colors.amberAccent.withValues(alpha: 0.8))))));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'safe_cracker', score: score, maxPossibleScore: score + failed * 15,
      accuracy: (cracked + failed) > 0 ? cracked / (cracked + failed) : 0.0,
      duration: config.gameDuration, difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart, timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle, calibrationMax: config.normalizer.maxAngle,
      hits: cracked, misses: failed,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);
  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cx = size.x * 0.5;
    final cy = size.y * 0.5;
    final dialR = min(size.x, size.y) * 0.3;

    // 금고 몸체
    final safeRect = Rect.fromCenter(center: Offset(cx, cy), width: dialR * 2.6, height: dialR * 2.6);
    canvas.drawRRect(RRect.fromRectAndRadius(safeRect, const Radius.circular(16)),
        Paint()..color = const Color(0xFF37474F));
    canvas.drawRRect(RRect.fromRectAndRadius(safeRect, const Radius.circular(16)),
        Paint()..color = const Color(0xFF546E7A)..style = PaintingStyle.stroke..strokeWidth = 4);

    // 다이얼 배경
    canvas.drawCircle(Offset(cx, cy), dialR + 6,
        Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(Offset(cx, cy), dialR,
        Paint()..color = const Color(0xFF455A64));
    canvas.drawCircle(Offset(cx, cy), dialR,
        Paint()..color = const Color(0xFF78909C)..style = PaintingStyle.stroke..strokeWidth = 3);

    // 눈금 표시
    for (int i = 0; i < 40; i++) {
      final angle = i * 2 * pi / 40 - pi / 2;
      final isMajor = i % 5 == 0;
      final innerR = dialR * (isMajor ? 0.82 : 0.88);
      canvas.drawLine(
        Offset(cx + cos(angle) * innerR, cy + sin(angle) * innerR),
        Offset(cx + cos(angle) * dialR * 0.95, cy + sin(angle) * dialR * 0.95),
        Paint()..color = Colors.white.withValues(alpha: isMajor ? 0.6 : 0.3)..strokeWidth = (isMajor ? 2 : 1),
      );
    }

    // 목표 존 표시 (현재 단계)
    if (_currentStep < _combination.length) {
      final target = _combination[_currentStep];
      final targetAngle = target * 2 * pi - pi / 2;
      final arcExtent = _targetRadius * 2 * pi;

      // 목표 영역 호
      final zoneColor = _inTarget ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.amberAccent.withValues(alpha: 0.2);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: dialR * 0.7),
          targetAngle - arcExtent / 2, arcExtent, true,
          Paint()..color = zoneColor);

      // 목표 마커
      final tx = cx + cos(targetAngle) * dialR * 0.7;
      final ty = cy + sin(targetAngle) * dialR * 0.7;
      canvas.drawCircle(Offset(tx, ty), 8 * config.targetSizeMultiplier,
          Paint()..color = _inTarget ? Colors.greenAccent : Colors.amberAccent);

      // 유지 프로그레스 (원형)
      final progress = (_holdTime / _requiredHoldTime).clamp(0.0, 1.0);
      if (progress > 0) {
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: dialR + 12),
            -pi / 2, progress * 2 * pi, false,
            Paint()..color = Color.lerp(Colors.red, Colors.green, progress)!..strokeWidth = 6..style = PaintingStyle.stroke);
      }
    }

    // 완료된 단계 표시
    for (int i = 0; i < _currentStep && i < _combination.length; i++) {
      final angle = _combination[i] * 2 * pi - pi / 2;
      final mx = cx + cos(angle) * dialR * 0.7;
      final my = cy + sin(angle) * dialR * 0.7;
      canvas.drawCircle(Offset(mx, my), 6, Paint()..color = Colors.greenAccent.withValues(alpha: 0.6));
      // 체크마크
      TextPaint(style: const TextStyle(fontSize: 10, color: Colors.white))
          .render(canvas, '✓', Vector2(mx, my), anchor: Anchor.center);
    }

    // 현재 바늘
    final needleAngle = currentPosition * 2 * pi - pi / 2;
    final nx = cx + cos(needleAngle) * dialR * 0.85;
    final ny = cy + sin(needleAngle) * dialR * 0.85;
    canvas.drawLine(Offset(cx, cy), Offset(nx, ny),
        Paint()..color = Colors.redAccent..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.redAccent);
    canvas.drawCircle(Offset(nx, ny), 5, Paint()..color = Colors.redAccent);

    // 단계 표시 텍스트
    if (_currentStep < _combination.length) {
      TextPaint(style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)))
          .render(canvas, '${_currentStep + 1} / ${_combination.length}',
              Vector2(cx, cy + dialR + 30), anchor: Anchor.center);
    }

    // 자세 안내 (하단)
    TextPaint(style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)))
        .render(canvas, '팔꿈치 90° 굽힘 유지 · 어깨 돌림',
            Vector2(cx, size.y - 50), anchor: Anchor.center);
  }
}

// ─── Components ───

class _FloatingLabel extends PositionComponent {
  final String text; final Color color; double _life = 0;
  _FloatingLabel({required Vector2 pos, required this.text, required this.color})
      : super(position: pos, anchor: Anchor.center, priority: 20);
  @override
  void update(double dt) { super.update(dt); _life += dt; position.y -= 30 * dt; if (_life > 1.2) removeFromParent(); }
  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.2).clamp(0.0, 1.0);
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

class _VaultBackground extends PositionComponent {
  final Vector2 _gs;
  _VaultBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: -10);
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const RadialGradient(
      center: Alignment.center, radius: 0.8,
      colors: [Color(0xFF1A1A3E), Color(0xFF0A0A14)],
    ).createShader(rect));
    // 금속 패널 라인
    final panelPaint = Paint()..color = const Color(0xFF2A2A4A)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double x = 0; x < _gs.x; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, _gs.y), panelPaint);
    }
    for (double y = 0; y < _gs.y; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(_gs.x, y), panelPaint);
    }
  }
}

// ─── Flutter Wrapper ───

class SafeCrackerGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const SafeCrackerGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<SafeCrackerGame> createState() => _SafeCrackerGameState();
}

class _SafeCrackerGameState extends State<SafeCrackerGame> {
  late SafeCrackerFlameGame _game;
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
    _game = SafeCrackerFlameGame(inputStream: stream, config: widget.config, onGameEnd: (r) {
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
    return Scaffold(body: Stack(children: [
      Column(children: [
        Expanded(child: GameWidget(game: _game)),
        if (_isSim) Container(
          color: const Color(0xFF1a1a2e), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Row(children: [
            const Text('↺ 안쪽', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Expanded(child: SliderTheme(
              data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                  trackHeight: 8, activeTrackColor: Colors.amberAccent, thumbColor: Colors.white, inactiveTrackColor: Colors.white24),
              child: Slider(value: _simValue, onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); }),
            )),
            const Text('바깥 ↻', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        Container(color: const Color(0xFF1a1a2e), padding: const EdgeInsets.only(bottom: 6, top: 2),
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
