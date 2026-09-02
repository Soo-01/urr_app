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
    final x = _isPlayerFalling ? _playerCenterX(size.x) : _opponentCenterX(size.x);
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

    // 다리(발판) — 화면 하단 사각형
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.75, w, h * 0.25),
      Paint()..color = const Color(0xFF6B4F3A),
    );

    // 실제로 늘어지는 로프 + 가운데 매듭(nut). 매듭은 로프 위치에 따라 좌우로
    // 이동하고, 당기는 힘이 셀수록 로프가 팽팽해지며(처짐 감소) 미세하게 떨린다.
    _drawRope(canvas, w, h);

    // 플레이어 (사람) — 왼쪽에서 오른쪽(로프)을 향해 버틴다.
    _drawFighter(
      canvas,
      center: Offset(_playerCenterX(w), h * 0.65),
      facing: 1,
      falling: _isFalling && _isPlayerFalling,
      strength: _pullPower,
      cadence: 5.0,
      paint: _paintHuman,
    );

    // 상대 (동물) — 오른쪽에서 왼쪽(로프)을 향한다. 종류마다 체형이 다르다.
    _drawFighter(
      canvas,
      center: Offset(_opponentCenterX(w), h * 0.65),
      facing: -1,
      falling: _isFalling && !_isPlayerFalling,
      strength: _aiPower,
      cadence: switch (_currentAnimal) {
        AnimalType.chimpanzee => 9.0,
        AnimalType.orangutan => 2.6,
        AnimalType.gorilla => 1.7,
      },
      paint: _paintAnimal,
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
    final labelX = _opponentCenterX(w);
    nameStyle.render(canvas, animalLabel, Vector2(labelX, h * 0.65 - 65),
        anchor: Anchor.center);
    powerStyle.render(canvas, '힘 ${_aiPower.toStringAsFixed(1)}',
        Vector2(labelX, h * 0.65 - 48),
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

  // ── 캐릭터 위치 (지는 쪽이 상대에게 끌려간다) ────────────────────────────
  // 실제 줄다리기처럼 로프가 팽팽한 채로, 이기는 쪽이 로프를 감아 당기면 지는
  // 쪽 사람이 통째로 중앙(물웅덩이)으로 끌려온다. _ropePosition +1 = 플레이어
  // 우세(상대가 끌려옴), -1 = 플레이어 열세(플레이어가 끌려옴).
  // 낙하 연출 중에는 계속 중앙 쪽으로 미끄러지며 떨어진다.
  double _playerCenterX(double w) {
    final dragged = (_ropePosition < 0 ? -_ropePosition : 0.0); // 0~1
    var x = w * 0.12 + dragged * (w * 0.26);
    if (_isFalling && _isPlayerFalling) x += _fallProgress * (w * 0.10);
    return x;
  }

  double _opponentCenterX(double w) {
    final dragged = (_ropePosition > 0 ? _ropePosition : 0.0);
    var x = w * 0.88 - dragged * (w * 0.26);
    if (_isFalling && !_isPlayerFalling) x -= _fallProgress * (w * 0.10);
    return x;
  }

  // ── 로프 렌더 ────────────────────────────────────────────────────────────
  // 로프 양 끝을 두 캐릭터의 "손"에 고정한다. 가운데 매듭(nut)은 로프를 감아
  // 당기는 쪽(이기는 쪽)으로 이동한다. 로프는 힘의 합이 클수록 팽팽해지며,
  // 전체가 균일하게 처진다 — 지는 쪽만 느슨해지지 않는다(오히려 끌려가는 쪽이
  // 더 팽팽하다). 실제로 축 늘어지는 건 이미 떨어진 사람 쪽 구간뿐이다.
  void _drawRope(Canvas canvas, double w, double h) {
    final handY = h * 0.65 - 8;
    var leftHand = Offset(_playerCenterX(w) + 22, handY);
    var rightHand = Offset(_opponentCenterX(w) - 22, handY);

    // 낙하 연출: 진 쪽 손이 캐릭터를 따라 아래로 내려가며 그 구간만 축 늘어진다.
    double fallenSlack = 0;
    if (_isFalling) {
      fallenSlack = 70 * _fallProgress;
      final drop = _fallProgress * h * 0.9;
      if (_isPlayerFalling) {
        leftHand = Offset(leftHand.dx, leftHand.dy + drop);
      } else {
        rightHand = Offset(rightHand.dx, rightHand.dy + drop);
      }
    }

    // 매듭 위치: t=0 플레이어 손, t=1 상대 손. 플레이어가 우세할수록(+1) 매듭이
    // 플레이어 쪽(t 작음)으로 감겨온다.
    final t = (0.5 - _ropePosition * 0.34).clamp(0.08, 0.92);
    final knot = Offset(
      leftHand.dx + (rightHand.dx - leftHand.dx) * t,
      leftHand.dy + (rightHand.dy - leftHand.dy) * t,
    );

    // 팽팽함: 플레이어 + 상대 힘이 클수록 1.0(완전 팽팽)에 가까워짐.
    final tension = ((_pullPower + _aiPower) / 40.0).clamp(0.0, 1.0);
    final wobble = sin(_elapsedSeconds * 5.0) * (0.6 + (1.0 - tension) * 2.2);
    final baseSag = 12 * (1.0 - tension * 0.8) + wobble;

    final leftSag =
        baseSag + (_isFalling && _isPlayerFalling ? fallenSlack : 0);
    final rightSag =
        baseSag + (_isFalling && !_isPlayerFalling ? fallenSlack : 0);

    _drawRopeSegment(canvas, leftHand, knot, leftSag);
    _drawRopeSegment(canvas, knot, rightHand, rightSag);

    _drawKnot(canvas, knot, tension);
  }

  /// 한쪽 로프 구간을 2차 베지어로 그린다: 굵은 외곽선 → 밝은 심 → 꼬임 눈금.
  void _drawRopeSegment(Canvas canvas, Offset a, Offset b, double sag) {
    // 중점을 sag 만큼 끌어내리도록 제어점 y 를 2*sag 로.
    final ctrl = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + sag * 2);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6E4A21),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD8B27C),
    );

    // 꼬임(twist) 눈금: 곡선을 따라가며 접선에 기울인 짧은 어두운 선.
    final twist = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF9C6B34);
    const steps = 22;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final p = _quad(a, ctrl, b, t);
      final tan = _quadTangent(a, ctrl, b, t);
      final len = tan.distance == 0 ? 1.0 : tan.distance;
      // 접선을 살짝 회전시킨 방향으로 눈금을 그어 새끼줄 느낌.
      final nx = (tan.dx * 0.5 - tan.dy) / len;
      final ny = (tan.dy * 0.5 + tan.dx) / len;
      canvas.drawLine(
        Offset(p.dx - nx * 4, p.dy - ny * 4),
        Offset(p.dx + nx * 4, p.dy + ny * 4),
        twist,
      );
    }
  }

  /// 가운데 매듭(nut) — 둥근 로프 뭉치(교차로 꼬인 두 가닥) + 위로 세운
  /// 짧은 깃대에 달린 삼각 표식기. 로프가 느슨할수록 살짝 더 흔들린다.
  void _drawKnot(Canvas canvas, Offset c, double tension) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sin(_elapsedSeconds * 3.0) * (0.05 + (1.0 - tension) * 0.05));

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 30, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // 둥근 매듭 덩어리
    canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFFB07C3F));
    canvas.drawCircle(
      Offset.zero,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6E4A21),
    );

    // X 자로 교차하며 꼬인 두 가닥
    canvas.drawPath(
      Path()
        ..moveTo(-10, -8)
        ..quadraticBezierTo(0, 0, 10, 8)
        ..moveTo(-10, 8)
        ..quadraticBezierTo(0, 0, 10, -8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A5E2E),
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, 0), radius: 11),
      -0.5,
      1.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC79355),
    );

    // 중앙 표식 — 위로 세운 짧은 깃대 + 옆으로 나부끼는 삼각기
    final flap = sin(_elapsedSeconds * 6.0) * 3.0;
    canvas.drawLine(
      const Offset(0, -12),
      const Offset(0, -30),
      Paint()
        ..color = const Color(0xFF5C3C1B)
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -30)
        ..lineTo(15 + flap, -25.5)
        ..lineTo(0, -21)
        ..close(),
      Paint()..color = Colors.redAccent,
    );
    canvas.restore();
  }

  /// 2차 베지어 위 점.
  Offset _quad(Offset p0, Offset c, Offset p1, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * c.dx + t * t * p1.dx,
      u * u * p0.dy + 2 * u * t * c.dy + t * t * p1.dy,
    );
  }

  /// 2차 베지어 위 접선 벡터(정규화 안 함).
  Offset _quadTangent(Offset p0, Offset c, Offset p1, double t) {
    final u = 1 - t;
    return Offset(
      2 * u * (c.dx - p0.dx) + 2 * t * (p1.dx - c.dx),
      2 * u * (c.dy - p0.dy) + 2 * t * (p1.dy - c.dy),
    );
  }

  /// 한 파이터(사람/동물)를 그린다. 그림은 항상 오른쪽(로프)을 보도록 그리고
  /// facing 으로 좌우를 뒤집는다. falling==true면 기존 4단계 낙하 연출
  /// (비틀거림 → 발 미끄러짐 → 낙하 → 착지/물보라), 아니면 당기는 리듬(heave)에
  /// 맞춰 몸을 뒤로 젖힌다. effort(0~1)는 "얼마나 지고 있는가" 와 "당기는 힘이
  /// 얼마나 큰가" 중 큰 값으로, 값이 클수록 더 깊게 젖히고·빠르게 떨고·힘주는
  /// 표시(동작선/땀/이 악뭄)를 painter 에 넘긴다.
  void _drawFighter(
    Canvas canvas, {
    required Offset center,
    required int facing, // +1: 오른쪽을 봄, -1: 왼쪽을 봄
    required bool falling,
    required double strength,
    required double cadence,
    required void Function(Canvas c, double heave, double effort) paint,
  }) {
    double dy = 0, lean = 0, scale = 1.0, alpha = 1.0, heave = 0, effort = 0;

    if (falling) {
      final p = _fallProgress;
      if (p < 0.2) {
        lean = sin((p / 0.2) * pi * 6) * 0.35;
      } else if (p < 0.4) {
        final t = (p - 0.2) / 0.2;
        dy = t * 12;
        lean = 0.3; // 앞(중앙 웅덩이)으로 고꾸라짐
      } else if (p < 0.8) {
        final t = (p - 0.4) / 0.4;
        dy = 12 + t * 96 * 4;
        scale = 1.0 - t * 0.75;
        alpha = 1.0 - t * 0.7;
      } else {
        alpha = 0;
      }
    } else if (_countdown <= 0) {
      // 짐(로프 위치) 또는 당기는 힘 중 큰 쪽으로 "안간힘" 정도를 정한다.
      final strengthNorm = (strength / 16.0).clamp(0.0, 1.0);
      final losing = facing == 1
          ? (-_ropePosition).clamp(0.0, 1.0) // 플레이어는 ropePosition<0 이면 짐
          : _ropePosition.clamp(0.0, 1.0); // 동물은 ropePosition>0 이면 짐
      effort = max(strengthNorm, losing * 0.95);

      final osc = sin(_elapsedSeconds * cadence * (1.0 + effort * 0.6));
      heave = osc * (1.0 + effort * 1.6);
      final intensity = 0.05 + effort * 0.16;
      lean = -intensity * (0.6 + 0.4 * osc); // 로프 반대(뒤)로 젖힘
      lean += sin(_elapsedSeconds * 38.0) * effort * 0.02; // 안간힘 떨림
      dy = -osc.abs() * (1.5 + effort * 2.0);
    }

    if (alpha <= 0) return;

    // 발밑 그림자 (월드 공간, 회전 영향 없음)
    if (!falling || _fallProgress < 0.4) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(center.dx, center.dy + 48), width: 62, height: 14),
        Paint()..color = Colors.black.withValues(alpha: 0.20 * alpha),
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy + dy);
    canvas.rotate(lean * facing); // 월드 공간 젖힘 (facing 으로 방향 보정)
    canvas.scale(facing * scale, scale); // 좌우 반전 + 낙하 축소
    if (alpha < 1.0) {
      canvas.saveLayer(
        const Rect.fromLTRB(-150, -170, 150, 170),
        Paint()..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
      paint(canvas, heave, effort);
      canvas.restore();
    } else {
      paint(canvas, heave, effort);
    }
    canvas.restore();
  }

  /// 파이터 팔다리용 둥근 끝 굵은 선.
  void _fs(Canvas c, Offset a, Offset b, double width, Color color) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// 힘을 쥐어짜는 표시: 몸 뒤쪽 짧은 동작선 + 튀는 땀방울. effort 0~1.
  void _strainFx(Canvas c, double effort) {
    if (effort < 0.15) return;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.30 * effort)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final n = (1 + effort * 3).round();
    for (int i = 0; i < n; i++) {
      final y = -26.0 + i * 12.0;
      final x = -20.0 - (i.isEven ? 4.0 : 0.0);
      c.drawLine(Offset(x, y), Offset(x - 7 - effort * 5, y - 2), line);
    }
    if (effort > 0.4) {
      final t = (_elapsedSeconds * 3.0) % 1.0;
      c.drawCircle(
        Offset(-14 - t * 18, -40 - t * 6 + t * t * 22),
        2.2,
        Paint()..color = const Color(0xFFBFE6F5).withValues(alpha: (1 - t) * effort),
      );
    }
  }

  /// 사람(플레이어) — 오른쪽(로프)을 향해 두 팔을 뻗어 버티는 자세.
  void _paintHuman(Canvas c, double heave, double effort) {
    final skin =
        Color.lerp(const Color(0xFFE8B98C), const Color(0xFFD87E63), effort * 0.55)!;
    const shirt = Color(0xFF2E6BE6);
    const pants = Color(0xFF39424D);
    const hair = Color(0xFF3A2A1E);

    _strainFx(c, effort);

    // 다리 — 세게 버틸수록 앞발을 더 앞으로 딛고 무릎을 굽힌다
    final braceX = 14.0 + effort * 8.0;
    _fs(c, const Offset(2, 10), const Offset(-15, 28), 11, pants);
    _fs(c, const Offset(-15, 28), const Offset(-24, 46), 10, pants);
    _fs(c, const Offset(4, 10), Offset(braceX - 4, 26 + effort * 3), 12, pants);
    _fs(c, Offset(braceX - 4, 26 + effort * 3), Offset(braceX, 46), 11, pants);
    c.drawOval(Rect.fromCenter(center: const Offset(-24, 46), width: 18, height: 8),
        Paint()..color = pants);
    c.drawOval(Rect.fromCenter(center: Offset(braceX + 2, 46), width: 18, height: 8),
        Paint()..color = pants);

    // 몸통
    final torso = Path()
      ..moveTo(-12, 10)
      ..lineTo(12, 10)
      ..lineTo(9, -22)
      ..lineTo(-13, -22)
      ..close();
    c.drawPath(torso, Paint()..color = shirt);

    // 목 + 머리
    _fs(c, const Offset(-3, -22), const Offset(-3, -30), 8, skin);
    c.drawCircle(const Offset(-2, -40), 12, Paint()..color = skin);
    c.drawArc(
      Rect.fromCircle(center: const Offset(-2, -40), radius: 12),
      pi * 0.15,
      pi * 1.2,
      false,
      Paint()
        ..color = hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.drawCircle(const Offset(10, -39), 2.2, Paint()..color = skin); // 코
    if (effort > 0.35) {
      _fs(c, const Offset(6, -35), const Offset(12, -35), 2, Colors.white70); // 이 악뭄
    }

    // 팔 — 로프를 잡고 뒤로 당김 (힘줄수록 그립을 몸쪽으로 끌어당김)
    final ex = heave * 2.0 - effort * 3.0;
    final grip = Offset(24 + heave * 2.0 - effort * 5.0, -6);
    _fs(c, const Offset(0, -18), Offset(15 + ex, -13), 9, shirt);
    _fs(c, Offset(15 + ex, -13), grip, 7, skin);
    _fs(c, const Offset(-2, -16), Offset(13 + ex, -8), 8, skin);
    _fs(c, Offset(13 + ex, -8), grip + const Offset(-1, 1), 7, skin);
    c.drawCircle(grip, 5, Paint()..color = skin);
  }

  /// 상대 동물 — 종류에 따라 완전히 다른 체형/자세로 그린다.
  void _paintAnimal(Canvas c, double heave, double effort) {
    switch (_currentAnimal) {
      case AnimalType.chimpanzee:
        _paintChimp(c, heave, effort);
      case AnimalType.orangutan:
        _paintOrangutan(c, heave, effort);
      case AnimalType.gorilla:
        _paintGorilla(c, heave, effort);
    }
  }

  /// 침팬지 — 작고 웅크린 체형, 긴 팔, 큰 귀. 빠르고 불규칙하게 당긴다.
  void _paintChimp(Canvas c, double heave, double effort) {
    const fur = Color(0xFF2C2420);
    final skin =
        Color.lerp(const Color(0xFFC7A184), const Color(0xFFB86A55), effort * 0.5)!;
    final j = heave * 4.0 + sin(_elapsedSeconds * 20.0) * effort * 2.0 - effort * 4.0;

    _strainFx(c, effort);

    // 웅크린 다리
    _fs(c, const Offset(-2, 16), const Offset(-14, 30), 10, fur);
    _fs(c, const Offset(-14, 30), const Offset(-16, 46), 9, fur);
    _fs(c, const Offset(4, 16), const Offset(6, 32), 10, fur);
    _fs(c, const Offset(6, 32), const Offset(2, 46), 9, fur);
    c.drawOval(Rect.fromCenter(center: const Offset(-16, 46), width: 16, height: 7),
        Paint()..color = fur);
    c.drawOval(Rect.fromCenter(center: const Offset(3, 46), width: 16, height: 7),
        Paint()..color = fur);

    // 앞으로 숙인 몸통
    final torso = Path()
      ..moveTo(-14, 16)
      ..lineTo(8, 18)
      ..lineTo(12, -10)
      ..lineTo(-8, -14)
      ..close();
    c.drawPath(torso, Paint()..color = fur);

    // 긴 팔 — 로프까지 멀리 뻗음
    final grip = Offset(26 + j, -6);
    _fs(c, const Offset(-4, -8), Offset(16 + j, 2), 9, fur);
    _fs(c, Offset(16 + j, 2), grip, 8, fur);
    _fs(c, const Offset(-6, -6), Offset(14 + j, 8), 8, fur);
    _fs(c, Offset(14 + j, 8), Offset(24 + j, -3), 7, fur);
    c.drawCircle(grip, 5, Paint()..color = skin);

    // 머리 — 낮고 앞으로, 큰 귀
    c.drawCircle(const Offset(2, -16), 6.5, Paint()..color = fur);
    c.drawCircle(const Offset(16, -12), 6.5, Paint()..color = fur);
    c.drawCircle(const Offset(9, -15), 10, Paint()..color = fur);
    c.drawOval(Rect.fromCenter(center: const Offset(12, -12), width: 12, height: 14),
        Paint()..color = skin);
    c.drawCircle(const Offset(10, -15), 1.6, Paint()..color = fur);
    c.drawCircle(const Offset(15, -14), 1.6, Paint()..color = fur);
    if (effort > 0.35) {
      _fs(c, const Offset(9, -8), const Offset(16, -8), 2, Colors.white70); // 드러낸 이
    }
  }

  /// 오랑우탄 — 크고 둥근 체형, 텁수룩한 붉은 털, 아주 긴 팔, 볼 주머니.
  /// 느리지만 꾸준히 당긴다.
  void _paintOrangutan(Canvas c, double heave, double effort) {
    const fur = Color(0xFF9C4A1E);
    const dark = Color(0xFF5E2F13);
    const skin = Color(0xFF7A4A34);
    final f = heave * 3.0 - effort * 5.0;

    _strainFx(c, effort);

    // 짧게 접힌 다리
    _fs(c, const Offset(-8, 20), const Offset(-16, 44), 13, fur);
    _fs(c, const Offset(8, 20), const Offset(12, 44), 13, fur);
    c.drawOval(Rect.fromCenter(center: const Offset(-16, 46), width: 18, height: 8),
        Paint()..color = dark);
    c.drawOval(Rect.fromCenter(center: const Offset(12, 46), width: 18, height: 8),
        Paint()..color = dark);

    // 크고 둥근 몸통 + 털 프린지
    final belly = Rect.fromCenter(center: const Offset(-1, 6), width: 42, height: 48);
    _furFringe(c, belly, fur, 26);
    c.drawOval(belly, Paint()..color = fur);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: 24, height: 28),
        Paint()..color = dark.withValues(alpha: 0.35));

    // 아주 긴 팔
    final grip = Offset(30 + f, -6);
    _fs(c, const Offset(-8, -14), Offset(18 + f, 2), 13, fur);
    _fs(c, Offset(18 + f, 2), grip, 11, fur);
    _fs(c, const Offset(-10, -10), Offset(16 + f, 10), 11, fur);
    _fs(c, Offset(16 + f, 10), Offset(27 + f, -2), 9, fur);
    c.drawCircle(grip, 6, Paint()..color = skin);

    // 넓은 얼굴 (볼 주머니 플랜지)
    c.drawOval(Rect.fromCenter(center: const Offset(2, -28), width: 34, height: 24),
        Paint()..color = dark);
    c.drawCircle(const Offset(4, -28), 11, Paint()..color = fur);
    c.drawOval(Rect.fromCenter(center: const Offset(6, -26), width: 12, height: 15),
        Paint()..color = skin);
    c.drawCircle(const Offset(3, -28), 1.6, Paint()..color = dark);
    c.drawCircle(const Offset(9, -27), 1.6, Paint()..color = dark);
    _fs(c, const Offset(0, -18), const Offset(-2, -10), 6, fur); // 턱수염
  }

  /// 고릴라 — 거대한 어깨와 팔, 검은 털, 작은 볏 달린 머리, 은색 등판.
  /// 평소 버티다 가끔 폭발적으로 당긴다.
  void _paintGorilla(Canvas c, double heave, double effort) {
    const fur = Color(0xFF211D1D);
    const chest = Color(0xFF3A3535);
    const silver = Color(0xFF6E6E6E);
    const skin = Color(0xFF2A2424);
    final burst = (sin(_elapsedSeconds * 0.3) > 0.8) ? 5.0 : 0.0;
    final f = heave * 1.5 + burst - effort * 5.0;

    _strainFx(c, effort);

    // 짧고 굵은 다리
    _fs(c, const Offset(-8, 16), const Offset(-16, 44), 17, fur);
    _fs(c, const Offset(10, 16), const Offset(12, 44), 17, fur);
    c.drawOval(Rect.fromCenter(center: const Offset(-16, 47), width: 22, height: 9),
        Paint()..color = fur);
    c.drawOval(Rect.fromCenter(center: const Offset(12, 47), width: 22, height: 9),
        Paint()..color = fur);

    // 몸통 + 은색 등판 + 가슴
    final trunk = Path()
      ..moveTo(-18, 20)
      ..lineTo(16, 20)
      ..lineTo(20, -14)
      ..lineTo(-22, -18)
      ..close();
    c.drawPath(trunk, Paint()..color = fur);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -14, 16, 32), const Radius.circular(6)),
      Paint()..color = silver,
    );
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(4, 2), width: 22 + effort * 4, height: 26),
        Paint()..color = chest);

    // 거대한 어깨 + 팔
    c.drawCircle(const Offset(-2, -14), 13, Paint()..color = fur);
    final grip = Offset(28 + f, -4);
    _fs(c, const Offset(0, -14), Offset(20 + f, 2), 17, fur);
    _fs(c, Offset(20 + f, 2), grip, 15, fur);
    _fs(c, const Offset(-4, -10), Offset(17 + f, 12), 14, fur);
    _fs(c, Offset(17 + f, 12), Offset(26 + f, 2), 12, fur);
    c.drawCircle(grip, 8, Paint()..color = skin); // 주먹

    // 작은 머리 (어깨 사이) + 볏 + 눈두덩
    c.drawCircle(const Offset(8, -22), 9, Paint()..color = fur);
    final crest = Path()
      ..moveTo(2, -28)
      ..lineTo(8, -34)
      ..lineTo(13, -27)
      ..close();
    c.drawPath(crest, Paint()..color = fur);
    _fs(c, const Offset(3, -24), const Offset(14, -22), 4, chest);
    c.drawCircle(const Offset(11, -20), 3, Paint()..color = skin);
  }

  /// 둥근 몸통 둘레에 짧은 털 프린지를 그려 텁수룩하게 보이게 한다.
  void _furFringe(Canvas c, Rect r, Color color, int n) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < n; i++) {
      final a = i / n * 2 * pi;
      final ox = r.center.dx + cos(a) * r.width / 2;
      final oy = r.center.dy + sin(a) * r.height / 2;
      c.drawLine(Offset(ox, oy), Offset(ox + cos(a) * 7, oy + sin(a) * 7), p);
    }
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
