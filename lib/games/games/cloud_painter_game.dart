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
/// [S2] 구름 위 화가 (Cloud Painter)
/// 관절: 어깨 굽힘/폄 또는 어깨 회전
/// 메카닉: 캔버스를 관절 각도로 움직여 칠한다. 전체 ROM을 골고루 사용해야 점수.
/// 재활 가치: 편향 교정 — 특정 범위만 반복하는 경향을 교정하여 전체 ROM 균일 사용 유도
/// ============================================================================
class CloudPainterFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  // 칠하기 영역: 0.0~1.0을 20개 구간으로 나눔
  static const int _segmentCount = 20;
  final List<double> _paintedAmount = List.filled(_segmentCount, 0.0); // 0.0~1.0 각 구간 칠한 정도
  double _totalPainted = 0.0; // 0.0~1.0 전체 완성도
  int _score = 0;
  double _brushTrailTimer = 0;

  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _percentText;

  CloudPainterFlameGame({this.inputStream, required this.config, required this.onGameEnd})
      : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    add(_SkyGradientBackground(gameSize: size));
    // 구름 배경 (인지 레벨 2+)
    if (config.cognitiveLevel.bgComplexity >= 2) {
      for (int i = 0; i < 4; i++) {
        add(_Cloud(pos: Vector2(_rng.nextDouble() * size.x, 20 + _rng.nextDouble() * 50),
            speed: 5 + _rng.nextDouble() * 10, gameWidth: size.x));
      }
    }

    // HUD
    _scoreText = _HudText(text: '🎨 0', pos: Vector2(20, 16), anchor: Anchor.topLeft,
        fontSize: config.cognitiveLevel == CognitiveLevel.simple ? 32 : 22);
    add(_scoreText);

    _percentText = _HudText(text: '0%', pos: Vector2(size.x / 2, 16), anchor: Anchor.topCenter,
        color: Colors.white);
    add(_percentText);

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

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    if (config.cognitiveLevel.showTimer) _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    // 현재 위치의 구간에 칠하기
    final seg = (currentPosition * (_segmentCount - 1)).round().clamp(0, _segmentCount - 1);
    final paintSpeed = 0.8 * dt; // 초당 80% 칠함
    if (_paintedAmount[seg] < 1.0) {
      _paintedAmount[seg] = (_paintedAmount[seg] + paintSpeed).clamp(0.0, 1.0);

      // 새 구간 완전히 칠하면 점수
      if (_paintedAmount[seg] >= 1.0) {
        _score += 10;
        _scoreText.updateText('🎨 $_score');

        // 파티클
        if (config.cognitiveLevel.particleCount > 0) {
          final y = size.y * 0.1 + (1.0 - seg / _segmentCount) * size.y * 0.75;
          _spawnPaintParticles(Vector2(size.x * 0.5, y));
        }
      }
    }

    // 전체 완성도 계산
    _totalPainted = _paintedAmount.fold(0.0, (a, b) => a + b) / _segmentCount;
    _percentText.updateText('${(_totalPainted * 100).toInt()}%');
    _percentText.setColor(_totalPainted >= 0.9 ? Colors.greenAccent : Colors.white);

    // 100% 달성 보너스
    if (_totalPainted >= 1.0) {
      _score += (timeRemaining * 3).toInt();
      endGame();
      return;
    }

    // 붓 트레일 이펙트
    _brushTrailTimer += dt;
    if (_brushTrailTimer > 0.05 && config.cognitiveLevel.bgComplexity >= 1) {
      _brushTrailTimer = 0;
      final y = size.y * 0.1 + (1.0 - currentPosition) * size.y * 0.75;
      add(_BrushDot(pos: Vector2(size.x * 0.5, y), segIndex: seg));
    }
  }

  void _spawnPaintParticles(Vector2 pos) {
    final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
    add(ParticleSystemComponent(
      position: pos,
      particle: fp.Particle.generate(
        count: config.cognitiveLevel.particleCount,
        lifespan: 0.6,
        generator: (i) => fp.AcceleratedParticle(
          speed: Vector2(_rng.nextDouble() * 100 - 50, -_rng.nextDouble() * 80),
          acceleration: Vector2(0, 200),
          child: fp.CircleParticle(radius: 2 + _rng.nextDouble() * 3,
            paint: Paint()..color = colors[_rng.nextInt(colors.length)]),
        ),
      ),
    ));
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();

    // 균일도 보너스: 모든 구간이 골고루 칠해졌으면 추가 점수
    final minPaint = _paintedAmount.reduce(min);
    final uniformityBonus = (minPaint * 50).toInt();
    _score += uniformityBonus;

    final painted = _paintedAmount.where((p) => p >= 1.0).length;
    onGameEnd(GameResult(
      gameId: 'cloud_painter', score: _score, maxPossibleScore: _segmentCount * 10 + 50,
      accuracy: _totalPainted, duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel, bodyPart: config.bodyPart,
      timestamp: DateTime.now(), calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle, hits: painted, misses: _segmentCount - painted,
    ));
  }

  void setSimPosition(double v) => currentPosition = v.clamp(0.0, 1.0);
  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }

  // 캔버스 렌더링 (게임 배경 위에 칠하기 바 + 브러시 표시)
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final barX = size.x * 0.12;
    final barW = size.x * 0.76;
    final barTop = size.y * 0.08;
    final barH = size.y * 0.78;
    final segH = barH / _segmentCount;

    // 칠해야 할 영역 (점선 윤곽)
    final outlineRect = Rect.fromLTWH(barX, barTop, barW, barH);
    canvas.drawRRect(RRect.fromRectAndRadius(outlineRect, const Radius.circular(12)),
        Paint()..color = Colors.white.withValues(alpha: 0.15));

    // 무지개 색상 팔레트
    final rainbowColors = [
      const Color(0xFFE53935), const Color(0xFFFF7043), const Color(0xFFFFA726),
      const Color(0xFFFFEE58), const Color(0xFF66BB6A), const Color(0xFF26C6DA),
      const Color(0xFF42A5F5), const Color(0xFF5C6BC0), const Color(0xFF7E57C2),
      const Color(0xFFEC407A),
    ];

    // 각 구간 칠하기 상태 렌더링
    for (int i = 0; i < _segmentCount; i++) {
      final y = barTop + (_segmentCount - 1 - i) * segH;
      final painted = _paintedAmount[i];

      if (painted > 0) {
        final color = rainbowColors[i % rainbowColors.length];
        final paintedW = barW * painted;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(barX, y + 1, paintedW, segH - 2), const Radius.circular(4)),
          Paint()..color = color.withValues(alpha: 0.7 + painted * 0.3),
        );
      }

      // 미칠한 구간: 점선 표시
      if (painted < 1.0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(barX, y + 1, barW, segH - 2), const Radius.circular(4)),
          Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1,
        );
      }
    }

    // 현재 위치 표시 (붓)
    final brushY = barTop + (1.0 - currentPosition) * barH;
    // 붓 본체
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(barX - 25, brushY), width: 16, height: 30), const Radius.circular(4)),
      Paint()..color = const Color(0xFF8D6E63),
    );
    // 붓끝
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(barX - 25, brushY + 18), width: 14, height: 12), const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    // 위치 가이드 선
    canvas.drawLine(Offset(barX, brushY), Offset(barX + barW, brushY),
        Paint()..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 1);
  }
}

// ─── Components ───

class _BrushDot extends PositionComponent {
  final int segIndex;
  double _life = 0;
  static const _colors = [
    Color(0xFFE53935), Color(0xFFFF7043), Color(0xFFFFA726), Color(0xFFFFEE58),
    Color(0xFF66BB6A), Color(0xFF26C6DA), Color(0xFF42A5F5), Color(0xFF5C6BC0),
  ];

  _BrushDot({required Vector2 pos, required this.segIndex})
      : super(position: pos, priority: 3);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life > 2.0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 2.0).clamp(0.0, 1.0);
    canvas.drawCircle(Offset.zero, 4,
        Paint()..color = _colors[segIndex % _colors.length].withValues(alpha: a * 0.5));
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
    final p = Paint()..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 60, height: 20), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-15, -8), width: 30, height: 18), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(15, -5), width: 35, height: 16), p);
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

class _SkyGradientBackground extends PositionComponent {
  final Vector2 _gs;
  _SkyGradientBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: -10);
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, _gs.x, _gs.y);
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFF80DEEA)],
    ).createShader(rect));
  }
}

// ─── Flutter Wrapper ───

class CloudPainterGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const CloudPainterGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<CloudPainterGame> createState() => _CloudPainterGameState();
}

class _CloudPainterGameState extends State<CloudPainterGame> {
  late CloudPainterFlameGame _game;
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
    _game = CloudPainterFlameGame(inputStream: stream, config: widget.config, onGameEnd: (r) {
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
          color: const Color(0xFF1a1a3e), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          child: Row(children: [
            const Text('⬇', style: TextStyle(color: Colors.white54)),
            Expanded(child: SliderTheme(
              data: SliderThemeData(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                  trackHeight: 8, activeTrackColor: Colors.purpleAccent, thumbColor: Colors.white, inactiveTrackColor: Colors.white24),
              child: Slider(value: _simValue, onChanged: (v) { setState(() => _simValue = v); _game.setSimPosition(v); }),
            )),
            const Text('⬆', style: TextStyle(color: Colors.white54)),
          ]),
        ),
        Container(color: const Color(0xFF1a1a3e), padding: const EdgeInsets.only(bottom: 6, top: 2),
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
