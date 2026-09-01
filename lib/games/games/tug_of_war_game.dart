import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../bluetooth.dart';
import '../../robot_protocol.dart';
import '../game_base.dart';
import '../game_result_screen.dart';

// ============================================================================
// [C-TOW] 줄다리기 (Tug of War) — 기초 뼈대 (로직 + 도형만)
// 관절: 팔꿈치 굽힘/폄 (lElbow)
//
// 이 파일은 docs/claude_code_game_dev_guide.md의 4단계 표 중 1~4단계까지만
// 구현한 첫 버전이다:
//   1. 빈 게임 실행     -> FlameGame 골격 + Flutter 래퍼
//   2. 입력 연결         -> inputStream 구독 + setSimPosition 슬라이더
//   3. 핵심 오브젝트     -> render()에서 원/사각형만 사용
//   4. 게임 로직         -> update()에서 당기기 감지 + 힘겨루기 계산
//
// 스프라이트, 파티클, 사운드, 한국어 HUD 텍스트, 난이도(Brunnstrom) 연동은
// 다음 단계에서 추가한다. (shield_guard_game.dart의 완성된 버전 참고)
// ============================================================================

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

  // ── 상대(AI) 힘 — 기초 버전: 고정값 + 아주 약한 균형 보정 ────────────────
  double _aiPower = 3.0;

  // ── 줄다리기 로프 위치: -1.0(패배) ~ 0.0(중앙) ~ 1.0(승리) ───────────────
  double _ropePosition = 0.0;

  int _pullCount = 0;
  double _elapsedSeconds = 0;

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
  }

  // ── 업데이트 (모든 게임 로직은 여기에서만) ────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning || _hasEnded) return;

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

  /// 기초 버전 상대 AI: 일정한 힘 + 로프가 한쪽으로 너무 기울면 살짝 보정.
  /// (동물별 패턴, 페이즈별 난이도는 다음 단계에서 추가)
  void _updateAnimalAi() {
    double adaptiveFactor = 1.0;
    if (_ropePosition > 0.3) adaptiveFactor = 1.15; // 플레이어가 이기는 중 -> 상대 강화
    if (_ropePosition < -0.3) adaptiveFactor = 0.85; // 플레이어가 지는 중 -> 상대 약화
    _aiPower = 3.0 * adaptiveFactor;
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
  }

  /// 블루투스 미연결 시 슬라이더로 값을 직접 넣기 위한 훅.
  void setSimPosition(double v) {
    currentPosition = v.clamp(0.0, 1.0);
  }

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
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();

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
    return Scaffold(
      body: Column(children: [
        Expanded(child: GameWidget(game: _game)),
        if (_isSim) _buildSlider(),
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
