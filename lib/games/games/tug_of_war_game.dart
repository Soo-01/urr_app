import 'dart:async';
import 'dart:math';
// dart:async의 Timer(주기적 모터 저항 동기화용)와 이름이 겹쳐 숨김 처리.
import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../bluetooth.dart';
import '../../generated/l10n.dart';
import '../../robot_protocol.dart';
import '../game_base.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';

// ============================================================================
// [C-TOW] 줄다리기 (Tug of War) — 기초 뼈대 (로직 + 도형만)
// 관절: 최종 목표는 팔꿈치 굽힘/폄(lElbow/rElbow)이지만, 앱에 아직 해당 관절이
// 연동되지 않아 이 원장님 지시에 따라 현재는 어깨 굽힘/폄(rShoulderEF)으로
// 개발한다. 관절이 준비되면 game_hub.dart의 메뉴 배치와 joint 값만 바꾸면 된다
// (게임 로직은 config.bodyPart를 그대로 쓰므로 관절에 무관).
//
// 이 파일은 docs/claude_code_game_dev_guide.md의 4단계 표 중 1~4단계까지만
// 구현한 첫 버전이다:
//   1. 빈 게임 실행     -> FlameGame 골격 + Flutter 래퍼
//   2. 입력 연결         -> inputStream 구독 + setSimPosition 슬라이더
//   3. 핵심 오브젝트     -> render()에서 원/사각형만 사용
//   4. 게임 로직         -> update()에서 당기기 감지 + 힘겨루기 계산
//
// 모터 연동은 다른 게임과 동일하게 GameMotorController를 재사용한다:
// PART 선택 + 상대(AI) 힘을 등장성(isotonic) 저항으로 전송 (docs/
// tug_of_war_build_guide.md 4번 "모터 등장성 저항 연동" 항목).
//
// 스프라이트, 파티클, 사운드, 한국어 HUD 텍스트, 난이도(Brunnstrom) 연동은
// 다음 단계에서 추가한다. (shield_guard_game.dart의 완성된 버전 참고)
// ============================================================================

/// 난이도에 따라 등장하는 줄다리기 상대 동물 (docs/tug_of_war_build_guide.md 4번).
enum AnimalType { chimpanzee, orangutan, gorilla }

class TugOfWarFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;

  /// 정규화된 팔꿈치 각도 (0.0 = 완전히 폄, 1.0 = 완전히 굽힘)
  double currentPosition = 0.5;
  double _prevPosition = 0.5;

  bool isRunning = true;
  bool _hasEnded = false;

  // ── 당기기 감지 상태 ────────────────────────────────────────────────────
  bool _isPulling = false;
  double _pullStartPosition = 0.5;
  double _pullElapsed = 0;
  double _pullPower = 0; // 누적된 플레이어 당기는 힘

  static const double _pullThreshold = 0.02;

  // ── 상대(AI) 힘 — 동물 종류별 기본 힘 + 적응형 보정 + 고유 당기기 패턴 ────
  double _aiPower = 3.0;
  late final AnimalType _currentAnimal;

  /// 모터에 등장성(isotonic) 저항으로 그대로 전송되는 현재 상대 힘.
  double get aiPower => _aiPower;

  /// 현재 등장한 상대 동물 (Brunnstrom 단계 2~3=침팬지, 4=오랑우탄, 5~6=고릴라).
  AnimalType get currentAnimal => _currentAnimal;

  // ── 줄다리기 로프 위치: -1.0(패배) ~ 0.0(중앙) ~ 1.0(승리) ───────────────
  double _ropePosition = 0.0;

  int _pullCount = 0;
  double _elapsedSeconds = 0;

  // ── 시작 카운트다운 ──────────────────────────────────────────────────────
  // 카운트다운 중에는 AI도 당기지 않고 로프도 움직이지 않는다. 이게 없으면
  // 플레이어가 슬라이더를 만지기도 전에 상대 힘만으로 로프가 밀려 즉시 패배함.
  double _countdown = 3.0;
  bool get isCountingDown => _countdown > 0;

  TugOfWarFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  });

  @override
  Color backgroundColor() => const Color(0xFF1B2A32);

  @override
  Future<void> onLoad() async {
    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));

    // 상대 동물은 config.difficultyLevel(단계 내 세부 난이도, game_base.dart 참고)이
    // 아니라 Brunnstrom 단계(2~6)로 결정한다. shield_guard_game.dart도 핵심 난이도
    // (화살 속도/방패 크기)는 difficultyLevel이 아닌 brunnstromStage 파생값을
    // 쓰고, 이 게임의 build guide도 "Brunnstrom Target: Stages 3–5"로 명시함.
    final stage = config.brunnstromStage.level; // 2~6
    _currentAnimal = stage <= 3
        ? AnimalType.chimpanzee
        : stage == 4
            ? AnimalType.orangutan
            : AnimalType.gorilla;
  }

  // ── 업데이트 (모든 게임 로직은 여기에서만) ────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning || _hasEnded) return;

    if (_countdown > 0) {
      _countdown = (_countdown - dt).clamp(0.0, 3.0);
      // 카운트다운 중 입력 기준선만 갱신 (시작 직후 엉뚱한 당기기로 오판 방지).
      _prevPosition = currentPosition;
      return;
    }

    _elapsedSeconds += dt;
    _detectPull(dt);
    _updateAnimalAi();
    _updateRopePosition(dt);

    if (_ropePosition >= 1.0) {
      _endGame(won: true);
    } else if (_ropePosition <= -1.0) {
      _endGame(won: false);
    }
  }

  /// 정적인 각도가 아니라 폄 -> 굽힘으로의 동적 전환을 하나의 "당기기"로 센다.
  void _detectPull(double dt) {
    final delta = currentPosition - _prevPosition;

    // 1. 팔꿈치가 굽혀지기 시작 (당기기 시작)
    if (!_isPulling && delta < -_pullThreshold) {
      _isPulling = true;
      _pullStartPosition = currentPosition;
      _pullElapsed = 0;
    }

    if (_isPulling) {
      _pullElapsed += dt;

      // 2. 다시 펴지기 시작하면 한 번의 당기기 완료
      // (delta >= 0 이면 프레임 간 미세한 정지에도 조기 종료되어 슬라이더/센서
      //  입력이 힘으로 반영되지 않는 문제가 있었음 -> 임계값으로 완화)
      if (delta > _pullThreshold) {
        _isPulling = false;
        final pullRange = (_pullStartPosition - currentPosition).abs();
        final pullSpeed = pullRange / (_pullElapsed > 0 ? _pullElapsed : 0.1);
        _pullPower += pullRange * pullSpeed * 20.0;
        _pullCount++;
      }
    }

    _prevPosition = currentPosition;
  }

  /// 동물별 기본 힘 + 적응형 보정 + 동물 고유 당기기 패턴(wave).
  /// (docs/tug_of_war_build_guide.md 4번 "동물 AI 저항 알고리즘")
  void _updateAnimalAi() {
    final double baseStrength = switch (_currentAnimal) {
      AnimalType.chimpanzee => 7.0,
      AnimalType.orangutan => 11.0,
      AnimalType.gorilla => 15.0,
    };

    // 적응형 보정: 플레이어가 이기는 중이면 상대 강화, 지는 중이면 상대 약화.
    double adaptiveFactor = 1.0;
    if (_ropePosition > 0.3) adaptiveFactor = 1.15;
    if (_ropePosition < -0.3) adaptiveFactor = 0.85;

    // 동물별 고유 당기기 패턴: 침팬지=빠르고 불규칙, 오랑우탄=느리지만 꾸준,
    // 고릴라=평소 유지 + 가끔 폭발적 당기기.
    final double wave = switch (_currentAnimal) {
      AnimalType.chimpanzee => sin(_elapsedSeconds * 3.0) * 0.2,
      AnimalType.orangutan => sin(_elapsedSeconds * 1.5) * 0.15,
      AnimalType.gorilla => sin(_elapsedSeconds * 1.0) * 0.1 +
          (sin(_elapsedSeconds * 0.3) > 0.8 ? 0.35 : 0.0),
    };

    _aiPower = baseStrength * adaptiveFactor * (1.0 + wave);
  }

  void _updateRopePosition(double dt) {
    final netForce = _pullPower - _aiPower;
    _ropePosition = (_ropePosition + netForce * dt * 0.05).clamp(-1.0, 1.0);

    // 당긴 힘은 시간이 지나면 서서히 줄어든다 -> 계속 당겨야 로프가 밀린다.
    _pullPower *= (1 - dt * 1.5).clamp(0.0, 1.0);
  }

  // ── 렌더 (그리기만, 로직 없음) ────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final midY = h * 0.55;

    // 다리(발판) — 화면 하단 사각형
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.75, w, h * 0.25),
      Paint()..color = const Color(0xFF6B4F3A),
    );

    // 로프 — 중앙을 가로지르는 선
    canvas.drawLine(
      Offset(w * 0.1, midY),
      Offset(w * 0.9, midY),
      Paint()
        ..color = const Color(0xFFD8B27C)
        ..strokeWidth = 6,
    );

    // 중앙 깃발(원) — 로프 위치에 따라 좌우로 이동
    final flagX = w * 0.5 + _ropePosition * (w * 0.35);
    canvas.drawCircle(
      Offset(flagX, midY),
      18,
      Paint()..color = Colors.redAccent,
    );

    // 플레이어 (왼쪽 사각형, 파랑)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.12, h * 0.65),
        width: 60,
        height: 90,
      ),
      Paint()..color = Colors.blueAccent,
    );

    // 상대 (오른쪽 사각형, 주황)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.88, h * 0.65),
        width: 60,
        height: 90,
      ),
      Paint()..color = Colors.deepOrangeAccent,
    );

    // 임시 텍스트 HUD: 상대 동물 이름 + 힘 수치 (스프라이트 적용 전까지)
    final animalLabel = switch (_currentAnimal) {
      AnimalType.chimpanzee => 'chimpanzee',
      AnimalType.orangutan => 'orangutan',
      AnimalType.gorilla => 'gorilla',
    };
    final nameStyle = TextPaint(
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
    final powerStyle = TextPaint(
      style: const TextStyle(
        fontSize: 14,
        color: Colors.orangeAccent,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
    nameStyle.render(canvas, animalLabel, Vector2(w * 0.88, h * 0.65 - 65),
        anchor: Anchor.center);
    powerStyle.render(canvas, '힘 ${_aiPower.toStringAsFixed(1)}',
        Vector2(w * 0.88, h * 0.65 - 48),
        anchor: Anchor.center);

    // 시작 카운트다운 오버레이 — 이 동안은 상대도 당기지 않고 로프도 고정.
    if (_countdown > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      final n = _countdown.ceil();
      TextPaint(
        style: const TextStyle(
          fontSize: 96,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
        ),
      ).render(canvas, '$n', Vector2(w / 2, h / 2), anchor: Anchor.center);
    }
  }

  /// 블루투스 미연결 시 슬라이더로 값을 직접 넣기 위한 훅.
  void setSimPosition(double v) {
    currentPosition = v.clamp(0.0, 1.0);
  }

  /// 수동 정지(일시정지 바/비상 정지 버튼)용 공개 메서드 — 중단은 패배로 처리.
  void endGame() => _endGame(won: false);

  void _endGame({required bool won}) {
    if (_hasEnded) return;
    _hasEnded = true;
    isRunning = false;
    _sub?.cancel();

    final result = GameResult(
      gameId: 'tug_of_war',
      score: _pullCount * 10,
      maxPossibleScore: 100,
      accuracy: won ? 1.0 : 0.0,
      duration: Duration(milliseconds: (_elapsedSeconds * 1000).round()),
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: _pullCount,
      misses: 0,
    );
    onGameEnd(result);
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}

// ── Flutter 래퍼 ───────────────────────────────────────────────────────────

class TugOfWarGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;

  const TugOfWarGame({
    super.key,
    required this.bluetoothService,
    required this.config,
  });

  @override
  State<TugOfWarGame> createState() => _TugOfWarGameState();
}

class _TugOfWarGameState extends State<TugOfWarGame> {
  late TugOfWarFlameGame _game;
  late GameMotorController _motor;
  Timer? _resistanceSync;
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);

    // BT 연결 시: Jetson telemetry -> 관절 각도 -> 0.0~1.0 정규화.
    // 미연결 시: null 스트림, 아래 슬라이더로 setSimPosition() 직접 호출.
    final stream = _isSim
        ? null
        : widget.bluetoothService.telemetryStream
            .map((frame) => frame.jointForPart(widget.config.bodyPart))
            .where((joint) => joint != null && joint.online)
            .map((joint) => RobotProtocol.toUiDegrees(
                widget.config.bodyPart, joint!.positionDegrees))
            .map(widget.config.normalizer.normalize);

    _game = TugOfWarFlameGame(
      inputStream: stream,
      config: widget.config,
      onGameEnd: (r) {
        _motor.safeStop();
        _motor.dispose();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GameResultScreen(result: r)),
          );
        }
      },
    );

    if (!_isSim) {
      _motor.selectJoint(widget.config.bodyPart);
      _motor.startIsotonic(_game.aiPower);
      _motor.startWatchdog();
      // 상대(AI) 힘이 로프 위치에 따라 실시간으로 변하므로, 등장성 저항을
      // 주기적으로 갱신해 모터에 반영한다 (매 프레임 전송은 BT 스팸이 됨).
      _resistanceSync = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_game.isRunning) _motor.startIsotonic(_game.aiPower);
      });
    }
  }

  @override
  void dispose() {
    _resistanceSync?.cancel();
    _motor.safeStop();
    _motor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(children: [
        Column(children: [
          Expanded(child: GameWidget(game: _game)),
          if (_isSim) _buildSlider(),
          _buildControlBar(loc),
        ]),
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () {
              _motor.emergencyStop();
              _game.endGame();
            },
            child: const Icon(Icons.stop, color: Colors.white, size: 32),
          ),
        ),
      ]),
    );
  }

  Widget _buildControlBar(AppLocalizations loc) {
    return Container(
      color: const Color(0xFF1B2A32),
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _game.isRunning = !_game.isRunning,
          icon: const Icon(Icons.pause),
          label: Text(loc.pauseGame),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
          ),
          onPressed: () {
            _motor.safeStop();
            _game.endGame();
          },
          icon: const Icon(Icons.stop),
          label: Text(loc.stop),
        ),
      ]),
    );
  }

  Widget _buildSlider() {
    return Container(
      color: const Color(0xFF1B2A32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: [
        const Icon(Icons.arrow_back, color: Colors.white54),
        Expanded(
          child: Slider(
            value: _simValue,
            onChanged: (v) {
              setState(() => _simValue = v);
              _game.setSimPosition(v);
            },
          ),
        ),
        const Icon(Icons.arrow_forward, color: Colors.white54),
      ]),
    );
  }
}
