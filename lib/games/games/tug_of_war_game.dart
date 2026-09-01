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

/// 떨어지기 연출용 먼지/물보라 파티클 (shield_guard_game.dart의 _Particle과 동일 패턴).
class _FallParticle {
  double x, y, vx, vy;
  double life = 1.0;
  final Color color;
  final double radius;

  _FallParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
  });
}

class TugOfWarFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  /// 떨어지기 연출 시작 시 1회 호출 (모터 즉시 정지 등에 사용).
  /// docs/tug_of_war_build_guide.md 5번 "모터 즉시 정지" 참고.
  final VoidCallback? onFallTriggered;

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

  // ── 떨어지기 연출 (4단계: 비틀거림 → 발 미끄러짐 → 낙하 → 착지/물보라) ────
  // docs/tug_of_war_build_guide.md 5번 "떨어지기 애니메이션" 참고.
  bool _isFalling = false;
  bool _isPlayerFalling = false;
  double _fallProgress = 0.0; // 0.0~1.0
  static const double _fallDuration = 1.2; // 초
  final List<_FallParticle> _fallParticles = [];
  final Random _rng = Random();

  /// 떨어지기 연출 진행 중 여부 (모터 등장성 저항 재전송 차단용).
  bool get isFalling => _isFalling;

  TugOfWarFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
    this.onFallTriggered,
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

    if (_isFalling) {
      _updateFall(dt);
      return;
    }

    _elapsedSeconds += dt;
    _detectPull(dt);
    _updateAnimalAi();
    _updateRopePosition(dt);

    if (_ropePosition >= 1.0) {
      _triggerFall(isPlayerFalling: false); // 상대가 떨어짐 -> 승리
    } else if (_ropePosition <= -1.0) {
      _triggerFall(isPlayerFalling: true); // 플레이어가 떨어짐 -> 패배
    }
  }

  /// 떨어지기 연출 시작. 로프는 절벽 끝(±1.0)에 고정하고 모터를 즉시 멈춘다.
  void _triggerFall({required bool isPlayerFalling}) {
    if (_isFalling) return;
    _isFalling = true;
    _isPlayerFalling = isPlayerFalling;
    _fallProgress = 0.0;
    _ropePosition = isPlayerFalling ? -1.0 : 1.0;
    onFallTriggered?.call();
  }

  /// 4단계 낙하 연출 진행: 0.0~0.2 비틀거림, 0.2~0.4 발 미끄러짐(먼지),
  /// 0.4~0.8 낙하, 0.8~1.0 착지/물보라. 완료되면 실제로 게임을 종료한다.
  void _updateFall(double dt) {
    final wasSlip = _fallProgress >= 0.2 && _fallProgress < 0.4;
    final wasSplash = _fallProgress >= 0.8;

    _fallProgress = (_fallProgress + dt / _fallDuration).clamp(0.0, 1.0);
    _updateFallParticles(dt);

    if (!wasSlip && _fallProgress >= 0.2 && _fallProgress < 0.4) {
      _spawnFallParticles(dust: true); // 발 미끄러짐 진입 -> 먼지
    }
    if (!wasSplash && _fallProgress >= 0.8) {
      _spawnFallParticles(dust: false); // 착지 진입 -> 물보라
    }

    if (_fallProgress >= 1.0) {
      _endGame(won: !_isPlayerFalling);
    }
  }

  void _spawnFallParticles({required bool dust}) {
    final x = _isPlayerFalling ? size.x * 0.12 : size.x * 0.88;
    final y = dust ? size.y * 0.72 : size.y * 0.95;
    final color = dust ? const Color(0xFF9E8563) : const Color(0xFF8ECFEA);
    for (int i = 0; i < 14; i++) {
      final angle = dust ? _rng.nextDouble() * pi : _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 100;
      _fallParticles.add(_FallParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - (dust ? 0 : 80),
        color: color,
        radius: 3 + _rng.nextDouble() * 3,
      ));
    }
  }

  void _updateFallParticles(double dt) {
    for (final p in _fallParticles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 220 * dt;
      p.life -= dt * 1.2;
    }
    _fallParticles.removeWhere((p) => p.life <= 0);
  }

  /// 정적인 각도가 아니라 폄 -> 굽힘으로의 동적 전환을 하나의 "당기기"로 센다.
  void _detectPull(double dt) {
    final delta = currentPosition - _prevPosition;

    // 1. 팔꿈치가 굽혀지기 시작 (당기기 시작) — position 증가 = 폄(0.0)→굽힘(1.0).
    // (이전 코드는 부호가 반대였음: position이 "감소"할 때를 당기기 시작으로
    //  오판정해, 실제로 굽히는 방향으로만 움직여서는 당기기가 전혀 기록되지
    //  않는 버그가 있었음.)
    if (!_isPulling && delta > _pullThreshold) {
      _isPulling = true;
      _pullStartPosition = currentPosition;
      _pullElapsed = 0;
    }

    if (_isPulling) {
      _pullElapsed += dt;

      // 2. 다시 펴지기(position 감소) 시작하면 한 번의 당기기 완료.
      // (delta <= 0 이면 프레임 간 미세한 정지에도 조기 종료되어 슬라이더/센서
      //  입력이 힘으로 반영되지 않는 문제가 있었음 -> 임계값으로 완화)
      if (delta < -_pullThreshold) {
        _isPulling = false;
        final pullRange = (currentPosition - _pullStartPosition).abs();
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
    // (기존 1.5는 반감기 약 0.46초로, 실제 재활 환자는 물론 슬라이더로도
    //  그 속도로 반복 당기기가 불가능해 상대(7~15)를 절대 못 이기는 문제가
    //  있었음. 이 값은 build guide에 명시되지 않은 튜닝값이라 0.6으로 완화 —
    //  반감기 약 1.16초, 1~2초 간격의 현실적인 반복 당기기로도 버틸 수 있게.)
    _pullPower *= (1 - dt * 0.7).clamp(0.0, 1.0);
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
    _drawCharacterBox(
      canvas,
      center: Offset(w * 0.12, h * 0.65),
      width: 60,
      height: 90,
      color: Colors.blueAccent,
      falling: _isFalling && _isPlayerFalling,
    );

    // 상대 (오른쪽 사각형, 주황)
    _drawCharacterBox(
      canvas,
      center: Offset(w * 0.88, h * 0.65),
      width: 60,
      height: 90,
      color: Colors.deepOrangeAccent,
      falling: _isFalling && !_isPlayerFalling,
    );

    _drawFallParticles(canvas);

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

  /// 캐릭터 사각형 한 개를 그린다. falling==true면 4단계 낙하 연출
  /// (비틀거림 → 발 미끄러짐 → 낙하 → 착지/물보라, 사각형은 4단계에서 사라지고
  /// 이후는 파티클로만 표현)을 적용한다.
  void _drawCharacterBox(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required bool falling,
  }) {
    if (!falling) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: width, height: height),
        Paint()..color = color,
      );
      return;
    }

    final p = _fallProgress;
    double dy = 0, angle = 0, scale = 1.0, alpha = 1.0;

    if (p < 0.2) {
      // 1. 비틀거림: 빠르게 좌우로 휘청
      angle = sin((p / 0.2) * pi * 6) * 0.35;
    } else if (p < 0.4) {
      // 2. 발 미끄러짐: 살짝 가라앉으며 기울어짐 유지
      final t = (p - 0.2) / 0.2;
      dy = t * 12;
      angle = 0.3;
    } else if (p < 0.8) {
      // 3. 낙하: 아래로 떨어지며 점점 작아지고 옅어짐
      final t = (p - 0.4) / 0.4;
      dy = 12 + t * height * 4;
      scale = 1.0 - t * 0.75;
      alpha = 1.0 - t * 0.7;
    } else {
      // 4. 착지/물보라: 사각형은 사라지고 파티클로만 표현
      alpha = 0;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy + dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  void _drawFallParticles(Canvas canvas) {
    for (final p in _fallParticles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.radius * p.life.clamp(0.0, 1.0),
        Paint()..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0)),
      );
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
      onFallTriggered: () => _motor.safeStop(),
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
        if (_game.isRunning && !_game.isFalling) {
          _motor.startIsotonic(_game.aiPower);
        }
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
