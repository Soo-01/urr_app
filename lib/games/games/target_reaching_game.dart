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

/// ============================================================================
/// [C1] 시계 도달 (Clock Reaching Game)
/// InMotion ARM의 Clock Game 기반 — 상지 재활에서 가장 많이 연구된 게임 유형
///
/// 임상 근거:
/// - Krebs et al. (MIT InMotion ARM): 8방향 타겟 도달, 400회/세션
/// - 어깨 굽힘/폄 각도 = 커서 Y위치, 팔꿈치 굽힘/폄 = 커서 X위치
/// - 전체 ROM을 균일하게 사용하도록 타겟 위치 설계
///
/// 관절: lShoulderEF (기본) 또는 lElbow 선택 가능
/// 각도 → 화면 매핑:
///   어깨 굽힘/폄: normalizedAngle 0.0=아래, 1.0=위 → Y축 제어
///   팔꿈치 굽힘/폄: normalizedAngle 0.0=폄, 1.0=굽힘 → X+Y 혼합 제어
/// ============================================================================

// 8방향 시계 위치 (각도, 라디안): 12시부터 시계방향
const _clockAngles = [
  -pi / 2,       // 12시 (위)
  -pi / 4,       // 1시30분 (우상)
  0,             // 3시 (오른쪽)
  pi / 4,        // 4시30분 (우하)
  pi / 2,        // 6시 (아래)
  3 * pi / 4,   // 7시30분 (좌하)
  pi,            // 9시 (왼쪽)
  -3 * pi / 4,  // 10시30분 (좌상)
];

const _targetColors = [
  Color(0xFFFF6B6B), Color(0xFFFF9F43), Color(0xFFFFEE58),
  Color(0xFF66BB6A), Color(0xFF42A5F5), Color(0xFF7E57C2),
  Color(0xFFEC407A), Color(0xFF26C6DA),
];

class ClockReachingFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;

  // 어깨 굽힘/폄: Y축, 팔꿈치: X+Y 혼합
  double _normAngle = 0.5; // 0.0~1.0
  double _cursorX = 0;
  double _cursorY = 0;

  int score = 0;
  int totalHits = 0;
  int totalMisses = 0;
  double timeRemaining;
  bool isRunning = false;
  final Random _rng = Random();

  // 타겟 순서
  final List<int> _sequence = []; // 타겟 인덱스 순서
  int _sequenceIdx = 0;
  int _setCount = 0;       // 완료한 세트 수
  int _targetCount = 0;    // 총 시도 타겟 수

  // 현재 타겟 상태
  late _ClockTarget _currentTarget;
  late _Cursor _cursor;
  late _HudText _scoreText;
  late _HudText _timerText;
  late _HudText _setText;
  late _HudText _instructionText;

  double _reachRadius = 0.0; // 타겟 반경 (정규화 단위)

  ClockReachingFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  }) : timeRemaining = config.gameDuration.inSeconds.toDouble();

  @override
  Color backgroundColor() => const Color(0xFF06001A);

  double get _orbitRadius => size.y * 0.32 * config.romRatio;

  @override
  Future<void> onLoad() async {
    _applyDifficulty();
    _buildSequence();

    // ── 우주 배경 이미지 ──
    final bgSprite = await loadSprite('kenney_space-shooter-redux/Backgrounds/purple.png');
    add(SpriteComponent(sprite: bgSprite, size: size, priority: -10));

    // 레이더 오버레이 (레벨 2 이상)
    if (config.cognitiveLevel.bgComplexity >= 1) {
      add(_RadarBackground(gameSize: size));
    }

    // 8개 타겟 위치 표시 (어두운 가이드)
    for (int i = 0; i < 8; i++) {
      add(_TargetSlot(
        center: _targetCenter(i),
        radius: _slotRadius,
        color: _targetColors[i].withValues(alpha: 0.15),
      ));
    }

    // 중앙 기준점
    add(_CenterMark(center: _gameCenter));

    // 현재 타겟
    _currentTarget = _ClockTarget(
      center: _targetCenter(_sequence[_sequenceIdx]),
      radius: _slotRadius,
      color: _targetColors[_sequence[_sequenceIdx]],
      colorIndex: _sequence[_sequenceIdx],
      pulseEnabled: config.cognitiveLevel.level >= 2,
    );
    add(_currentTarget);

    // 커서
    _cursor = _Cursor(position: _gameCenter.clone(), trailEnabled: config.cognitiveLevel.bgComplexity >= 1);
    add(_cursor);

    // HUD
    _scoreText = _HudText('★ 0', Vector2(20, 14), Anchor.topLeft, 22);
    _timerText = _HudText('${timeRemaining.toInt()}s', Vector2(size.x - 20, 14), Anchor.topRight, 22);
    _setText   = _HudText('Set 0', Vector2(size.x / 2, 14), Anchor.topCenter, 18);
    _instructionText = _HudText('', Vector2(size.x / 2, size.y - 30), Anchor.bottomCenter, 16);
    add(_scoreText);
    if (config.cognitiveLevel.showTimer) add(_timerText);
    add(_setText);
    add(_instructionText);

    _updateCursorFromAngle();
    _sub = inputStream?.listen((v) {
      _normAngle = v.clamp(0.0, 1.0);
      _updateCursorFromAngle();
    });
    isRunning = true;
  }

  void _applyDifficulty() {
    // 타겟 반경: 난이도 높을수록 작아짐
    const radii = [0.14, 0.11, 0.09, 0.07, 0.05];
    _reachRadius = radii[(config.difficultyLevel - 1).clamp(0, 4)];
  }

  double get _slotRadius => _orbitRadius * _reachRadius;

  Vector2 get _gameCenter => Vector2(size.x / 2, size.y / 2);

  Vector2 _targetCenter(int slotIndex) {
    final angle = _clockAngles[slotIndex];
    return Vector2(
      _gameCenter.x + cos(angle) * _orbitRadius,
      _gameCenter.y + sin(angle) * _orbitRadius,
    );
  }

  // 관절 각도 → 커서 위치
  // 어깨 굽힘/폄: 각도 → Y축 (위아래)
  // 팔꿈치 굽힘/폄: 각도 → 화면 내 극좌표 (전체 범위 활용)
  void _updateCursorFromAngle() {
    if (config.bodyPart.contains('ShoulderEF') || config.bodyPart.contains('Elbow')) {
      // 1D 각도 → Y축 제어 (어깨 굽힘=위, 팔꿈치 굽힘=아래)
      final yRange = _orbitRadius * 2;
      final yOffset = config.bodyPart.contains('Elbow')
          ? (1.0 - _normAngle) * yRange - _orbitRadius
          : (1.0 - _normAngle) * yRange - _orbitRadius;
      _cursorY = _gameCenter.y + yOffset;
      _cursorX = _gameCenter.x; // X는 고정 (1D 입력)
    } else {
      // 기타 관절: X축 제어
      final xRange = _orbitRadius * 2;
      _cursorX = _gameCenter.x + (_normAngle - 0.5) * xRange;
      _cursorY = _gameCenter.y;
    }
    _cursor.setPosition(Vector2(_cursorX, _cursorY));
  }

  void _buildSequence() {
    // 8방향 순서: 기본 시계방향. 난이도 높으면 랜덤 순서 섞기
    _sequence.clear();
    if (config.difficultyLevel <= 2) {
      // 시계방향 순서
      _sequence.addAll(List.generate(8, (i) => i));
    } else {
      // 랜덤 순서 (이전 타겟과 겹치지 않게)
      final all = List.generate(8, (i) => i)..shuffle(_rng);
      _sequence.addAll(all);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    timeRemaining -= dt;
    _timerText.updateText('${timeRemaining.toInt()}s');
    if (timeRemaining <= 0) { endGame(); return; }

    // 타겟 도달 판정
    final target = _targetCenter(_sequence[_sequenceIdx]);
    final dx = _cursorX - target.x;
    final dy = _cursorY - target.y;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist < _slotRadius) {
      _onTargetHit();
    }
  }

  void _onTargetHit() {
    totalHits++;
    _targetCount++;
    final points = config.cognitiveLevel.level >= 2 ? 3 : 1;
    score += points;
    _scoreText.updateText('★ $score');

    // 히트 파티클
    if (config.cognitiveLevel.particleCount > 0) {
      final hitPos = _targetCenter(_sequence[_sequenceIdx]);
      add(ParticleSystemComponent(
        position: hitPos,
        particle: fp.Particle.generate(
          count: config.cognitiveLevel.particleCount,
          lifespan: 0.5,
          generator: (i) => fp.AcceleratedParticle(
            speed: Vector2(_rng.nextDouble() * 180 - 90, _rng.nextDouble() * 180 - 90),
            acceleration: Vector2(0, 150),
            child: fp.ScalingParticle(
              to: 0,
              child: fp.CircleParticle(
                radius: 2 + _rng.nextDouble() * 3,
                paint: Paint()..color = _targetColors[_sequence[_sequenceIdx]],
              ),
            ),
          ),
        ),
      ));
    }

    // 타겟 제거 애니메이션
    _currentTarget.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.08)),
      RemoveEffect(),
    ]));

    // 다음 타겟으로
    _sequenceIdx++;
    if (_sequenceIdx >= _sequence.length) {
      _sequenceIdx = 0;
      _setCount++;
      _buildSequence();
      _setText.updateText('Set $_setCount');

      // 세트 완료 플래시
      add(_FloatingLabel(
        pos: Vector2(size.x / 2, size.y / 2),
        text: 'Set $_setCount Complete!',
        color: Colors.amber,
        fontSize: 28,
      ));
    }

    // 새 타겟 생성
    _currentTarget = _ClockTarget(
      center: _targetCenter(_sequence[_sequenceIdx]),
      radius: _slotRadius,
      color: _targetColors[_sequence[_sequenceIdx]],
      colorIndex: _sequence[_sequenceIdx],
      pulseEnabled: config.cognitiveLevel.level >= 2,
    );
    add(_currentTarget);

    // 방향 안내 (인지 레벨 1에서는 강조)
    if (config.cognitiveLevel.level == 1) {
      final nextAngle = _clockAngles[_sequence[_sequenceIdx]];
      final isUp = nextAngle < -pi / 4;
      final isDown = nextAngle > pi / 4 && nextAngle < 3 * pi / 4;
      _instructionText.updateText(isUp ? '위로 ↑' : (isDown ? '아래로 ↓' : ''));
    }
  }

  void endGame() {
    if (!isRunning) return;
    isRunning = false;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'clock_reaching',
      score: score,
      maxPossibleScore: _targetCount * 3 + 30,
      accuracy: _targetCount > 0 ? totalHits / _targetCount : 0.0,
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: totalHits,
      misses: totalMisses,
    ));
  }

  void setSimPosition(double v) {
    _normAngle = v.clamp(0.0, 1.0);
    _updateCursorFromAngle();
  }

  @override
  void onRemove() { _sub?.cancel(); super.onRemove(); }
}

// ─── Star sprite pool (matched to _targetColors index) ───
const _starSpritePaths = [
  'powerupRed_star.png',    // 0 red
  'powerupYellow_star.png', // 1 orange
  'powerupYellow_star.png', // 2 yellow
  'powerupGreen_star.png',  // 3 green
  'powerupBlue_star.png',   // 4 blue
  'powerupBlue_star.png',   // 5 purple
  'powerupRed_star.png',    // 6 pink
  'powerupBlue_star.png',   // 7 cyan
];

// ─── Components ───

class _ClockTarget extends PositionComponent with HasGameReference<ClockReachingFlameGame> {
  final double radius;
  final Color color;
  final bool pulseEnabled;
  final int colorIndex;
  double _pulse = 0;
  Sprite? _starSprite;

  _ClockTarget({required Vector2 center, required this.radius, required this.color,
      required this.pulseEnabled, required this.colorIndex})
      : super(position: center, anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    final path = 'kenney_space-shooter-redux/PNG/Power-ups/${_starSpritePaths[colorIndex]}';
    _starSprite = await game.loadSprite(path);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (pulseEnabled) _pulse += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    final scale = pulseEnabled ? 1.0 + sin(_pulse) * 0.08 : 1.0;
    final r = radius * scale;

    // 외곽 글로우
    canvas.drawCircle(Offset.zero, r + 10,
        Paint()..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    if (_starSprite != null) {
      _starSprite!.render(canvas,
        position: Vector2(-r, -r),
        size: Vector2.all(r * 2),
      );
    } else {
      // 폴백 링
      canvas.drawCircle(Offset.zero, r,
          Paint()..color = color.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 4);
      canvas.drawCircle(Offset.zero, r * 0.6,
          Paint()..color = color.withValues(alpha: 0.4));
    }

    // 색상 하이라이트 링 (항상 표시)
    canvas.drawCircle(Offset.zero, r + 2,
        Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

class _Cursor extends PositionComponent with HasGameReference<ClockReachingFlameGame> {
  Vector2 _target;
  final bool trailEnabled;
  final List<Vector2> _trail = [];
  Sprite? _shipSprite;

  _Cursor({required Vector2 position, required this.trailEnabled})
      : _target = position.clone(),
        super(position: position.clone(), anchor: Anchor.center, priority: 10);

  @override
  Future<void> onLoad() async {
    _shipSprite = await game.loadSprite('kenney_space-shooter-redux/PNG/playerShip1_orange.png');
  }

  void setPosition(Vector2 p) => _target = p.clone();

  @override
  void update(double dt) {
    super.update(dt);
    position.lerp(_target, (15 * dt).clamp(0, 1));
    if (trailEnabled) {
      _trail.insert(0, position.clone());
      if (_trail.length > 10) _trail.removeLast();
    }
  }

  @override
  void render(Canvas canvas) {
    // 움직임 잔상
    if (trailEnabled) {
      for (int i = 1; i < _trail.length; i++) {
        final a = (1.0 - i / _trail.length) * 0.2;
        canvas.drawCircle(
          Offset(_trail[i].x - position.x, _trail[i].y - position.y),
          5 - i * 0.4,
          Paint()..color = Colors.cyanAccent.withValues(alpha: a),
        );
      }
    }
    // 엔진 글로우
    canvas.drawCircle(Offset.zero, 22,
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // 선박 스프라이트
    if (_shipSprite != null) {
      _shipSprite!.render(canvas,
        position: Vector2(-18, -22),
        size: Vector2(36, 44),
      );
    } else {
      canvas.drawCircle(Offset.zero, 14, Paint()..color = Colors.cyanAccent);
      canvas.drawCircle(Offset.zero, 8,  Paint()..color = Colors.white);
    }
  }
}

class _TargetSlot extends PositionComponent {
  final double radius;
  final Color color;

  _TargetSlot({required Vector2 center, required this.radius, required this.color})
      : super(position: center, anchor: Anchor.center, priority: 1);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

class _CenterMark extends PositionComponent {
  _CenterMark({required Vector2 center}) : super(position: center, anchor: Anchor.center, priority: 2);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 6,
        Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.drawCircle(Offset.zero, 3,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
  }
}

class _RadarBackground extends PositionComponent {
  final Vector2 _gs;
  double _sweep = 0;

  _RadarBackground({required Vector2 gameSize}) : _gs = gameSize, super(priority: 0);

  @override
  void update(double dt) {
    super.update(dt);
    _sweep += dt * 0.4;
    if (_sweep > 2 * pi) _sweep -= 2 * pi;
  }

  @override
  void render(Canvas canvas) {
    final cx = _gs.x / 2;
    final cy = _gs.y / 2;
    final r = _gs.y * 0.38;
    final paint = Paint()..color = Colors.cyanAccent.withValues(alpha: 0.04)..strokeWidth = 0.5..style = PaintingStyle.stroke;

    // 동심원
    for (double dr = r * 0.33; dr <= r; dr += r * 0.33) {
      canvas.drawCircle(Offset(cx, cy), dr, paint);
    }

    // 방사선
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(a) * r, cy + sin(a) * r),
        paint,
      );
    }

    // 스윕 扇形
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.cyanAccent.withValues(alpha: 0.12), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      _sweep, pi / 6, true, sweepPaint,
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
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
    )).render(canvas, _text, Vector2.zero(), anchor: anchor);
  }
}

class _FloatingLabel extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  double _life = 0;

  _FloatingLabel({required Vector2 pos, required this.text, required this.color, this.fontSize = 22})
      : super(position: pos, anchor: Anchor.center, priority: 20);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= 40 * dt;
    if (_life > 1.2) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1.0 - _life / 1.2).clamp(0.0, 1.0);
    TextPaint(style: GoogleFonts.orbitron(
      fontSize: fontSize, color: color.withValues(alpha: a),
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
    )).render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

// ─── Flutter Wrapper ───

class TargetReachingGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const TargetReachingGame({super.key, required this.bluetoothService, required this.config});
  @override
  State<TargetReachingGame> createState() => _TargetReachingGameState();
}

class _TargetReachingGameState extends State<TargetReachingGame> {
  late ClockReachingFlameGame _game;
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
    _game = ClockReachingFlameGame(
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
      body: Column(children: [
        Expanded(child: GameWidget(game: _game)),
        if (_isSim) _simSlider(),
        _controlBar(loc),
      ]),
    );
  }

  Widget _simSlider() => Container(
    color: const Color(0xFF0A1628),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    child: Column(children: [
      Text('시뮬레이션: 관절 각도 (${(_simValue * 100).toInt()}%)',
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
      SliderTheme(
        data: SliderThemeData(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
          trackHeight: 8,
          activeTrackColor: Colors.cyanAccent,
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
    color: const Color(0xFF0A1628),
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
        onPressed: () => setState(() => _game.isRunning = !_game.isRunning),
        icon: const Icon(Icons.pause),
        label: Text(loc.pauseGame),
      ),
      const SizedBox(width: 16),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
        onPressed: () => _game.endGame(),
        icon: const Icon(Icons.stop),
        label: Text(loc.stop),
      ),
    ]),
  );
}
