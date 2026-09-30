import 'dart:async';
import 'dart:math';
// dart:ui.Image 는 material.dart의 Image 위젯과 이름이 겹쳐 접두사로 구분.
import 'dart:ui' as ui;
// dart:async의 Timer(주기적 모터 저항 동기화용)와 이름이 겹쳐 숨김 처리.
import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

/// 플레이어가 로프를 당기는 힘을 만드는 방식.
/// - [cycle]: 팔꿈치를 굽혔다 펴는 동작을 **반복**해 힘을 누적한다(등장성). 기존 방식.
/// - [hold]: 굽힌 자세를 **계속 유지**해 힘을 만든다(등척성). 슬라이더(또는 모터)가
///   폄 방향(왼쪽/0.0)으로 계속 되돌리므로, 버티지 못하면 로프가 밀려 패배한다.
enum TugMode { cycle, hold }

/// 범용 파티클 (먼지·물보라·색종이·불꽃·힘줄기 연출 공용).
/// shield_guard_game.dart의 _Particle과 동일 패턴 + 중력/소멸속도/회전을 옵션화.
/// image가 지정되면 원/사각형 대신 그 이미지(또는 srcRect로 자른 일부)를
/// life에 따라 페이드아웃하며 그린다 — 물보라·색종이 스프라이트용.
class _Particle {
  double x, y, vx, vy;
  double life = 1.0;
  final Color color;
  final double radius;
  final double gravity; // px/s^2 (아래 방향)
  final double fade; // life 감소 속도 (1/s)
  final bool rect; // true면 회전하는 사각형(색종이)
  final bool sparkle; // true면 네 꼭짓점 반짝임(별) 모양
  double angle;
  final double spin; // rad/s
  final ui.Image? image; // 지정 시 도형 대신 이 이미지를 그린다
  final Rect? srcRect; // image 안에서 잘라 쓸 영역 (null이면 전체)
  final double scale; // image 렌더 배율 (radius 기준 목표 폭 계산용)

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    this.gravity = 220,
    this.fade = 1.2,
    this.rect = false,
    this.sparkle = false,
    this.angle = 0,
    this.spin = 0,
    this.image,
    this.srcRect,
    this.scale = 1.0,
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

  // ── 힘 생성 방식 (cycle: 반복 당기기 / hold: 자세 유지) ──────────────────
  TugMode _mode;
  TugMode get mode => _mode;
  set mode(TugMode m) {
    if (_mode == m) return;
    _mode = m;
    _pullPower = 0;
    _isPulling = false;
  }

  // hold 모드 튜닝값
  static const double _holdDeadzone = 0.15; // 이 이하로 내려가면 당기는 힘 0
  static const double _holdMaxPull = 18.0; // 완전히 굽혀 버틸 때의 당기는 힘
  double _holdSeconds = 0; // 유효하게 버틴 누적 시간(점수 환산용)

  // ── 상대(AI) 힘 — 동물 종류별 기본 힘 + 적응형 보정 + 고유 당기기 패턴 ────
  double _aiPower = 3.0;
  late final AnimalType _currentAnimal;

  // ── 실제 스프라이트 (플레이어 + 동물 3종) ────────────────────────────────
  // assets/tugofwar/player 1~4.png, champ/gor/or 1~4.png — 숫자가 클수록
  // 더 세게 힘을 쓰는 자세. 로드 실패 시 목록이 비어 있게 되고, 그 경우
  // 각각 기존 절차적 그래픽(_paintHuman/_paintChimp/_paintOrangutan/
  // _paintGorilla)으로 자동 대체된다.
  List<ui.Image> _playerFrames = [];
  List<ui.Image> _champFrames = [];
  List<ui.Image> _gorFrames = [];
  List<ui.Image> _orFrames = [];
  static const double _playerSpriteH = 150.0; // 목표 높이(px) — 1번 프레임 기준
  static const double _champSpriteH = 140.0;
  static const double _gorSpriteH = 150.0;
  static const double _orSpriteH = 145.0;
  // 프레임마다 원본 픽셀 크기가 제각각이라(포즈별로 따로 생성된 이미지),
  // "이번 프레임 높이를 targetH에 맞춘다"는 식으로 매번 다시 스케일하면
  // 포즈가 바뀔 때마다 캐릭터가 커졌다 작아졌다 하는 것처럼 보인다. 그래서
  // 1번 프레임 기준으로 배율을 한 번만 계산해 4프레임 전부에 동일하게
  // 적용한다 — _loadFighterSprites()에서 세팅.
  double _playerSpriteScale = 1.0;
  double _champSpriteScale = 1.0;
  double _gorSpriteScale = 1.0;
  double _orSpriteScale = 1.0;
  // 각 프레임에서 로프를 쥔 손(맞잡은 주먹)이 이미지 안 어디쯤(너비/높이
  // 대비 비율)에 있는지 실측한 값 — Python/PIL로 후보 좌표에 십자 표시를
  // 그려 눈으로 확인하는 방식으로 잡았다. 발이 지면에 닿도록 배치한 뒤,
  // 이 비율로 해당 프레임의 로프 손 앵커(로컬 좌표)를 계산한다
  // (_spriteGripLocal 참고). assets/tugofwar 스프라이트를 교체하면 이
  // 값들도 다시 맞춰야 한다.
  // (2026-09-22 재측정: 이전 값들이 손목/팔뚝 근처에 머물러 있었다 — 3배
  // 확대해서 다시 보니 실제 맞잡은 주먹 관절은 그보다 한참 더 오른쪽에
  // 있었음. 아래 값은 3배 확대 이미지에 십자 표시를 찍어 주먹 위에 정확히
  // 오는지 눈으로 확인하며 다시 잡았다.)
  static const double _playerHandFracX = 0.80, _playerHandFracY = 0.49;
  static const double _champHandFracX = 0.80, _champHandFracY = 0.47;
  static const double _gorHandFracX = 0.83, _gorHandFracY = 0.50;
  static const double _orHandFracX = 0.83, _orHandFracY = 0.51;

  // ── 배경/땅/매듭 스프라이트 ───────────────────────────────────────────────
  // 하나라도 로드 실패하면 그 부분만 기존 절차적 그래픽으로 자동 대체된다.
  // rope.png(로프 몸통)는 의도적으로 로드하지 않는다 — 작은 타일을 이어
  // 붙이는 스탬프 방식이 매끄럽지 않아(이음새가 도드라짐) 당분간 절차적
  // (canvas) 로프를 쓰기로 했다. knot.png(중앙 매듭)는 새 버전이 로프가
  // 겹쳐 그려지지 않는 독립된 매듭 그림이라 계속 사용한다.
  ui.Image? _bgImage; // background.png — 하늘/먼 산/캐노피
  ui.Image? _landImage; // left land.png — 좌우 각각 한 번씩(오른쪽은 반전)
  ui.Image? _knotImage; // knot.png — 중앙 매듭(로프 뭉치+리본), 로프 없음
  ui.Image? _splashImage; // water splash.png — 낙하 착지 물보라
  ui.Image? _winImage; // win.png — 승리 색종이 시트(여러 조각을 잘라 씀)

  /// 모터에 등장성(isotonic) 저항으로 그대로 전송되는 현재 상대 힘.
  double get aiPower => _aiPower;

  /// 현재 등장한 상대 동물 (Brunnstrom 단계 2~3=침팬지, 4=오랑우탄, 5~6=고릴라).
  AnimalType get currentAnimal => _currentAnimal;

  // ── 줄다리기 로프 위치: -1.0(패배) ~ 0.0(중앙) ~ 1.0(승리) ───────────────
  double _ropePosition = 0.0;

  int _pullCount = 0;
  double _elapsedSeconds = 0; // 현재 라운드 경과 시간 (라운드마다 0으로 리셋)
  double _matchElapsedSeconds = 0; // 전체 경기 경과 시간 (결과 화면용, 리셋 안 됨)

  // ── HUD / 난이도 연동 (step 7·8) ────────────────────────────────────────
  /// 라운드당 제한 시간(초). 0이면 무제한. onLoad()에서 config.gameDuration으로 설정
  /// (docs/tug_of_war_build_guide.md 6번 "라운드 시간" 참고).
  double _timeLimit = 0;
  /// difficultyLevel(1~5) 파생 미세 보정 — 높을수록 상대는 세고 내 힘은 덜 붙는다.
  double _aiStrengthMul = 1.0;
  double _playerPowerMul = 1.0;

  // ── 라운드 시스템: 3전 2선승 (docs/tug_of_war_build_guide.md §2, §10 Phase 4) ─
  static const int _totalRounds = 3;
  int _currentRound = 1; // 1-base, 진행 중인 라운드
  int _playerRoundWins = 0;
  int _animalRoundWins = 0;
  /// 라운드별 결과 (null=아직 안 함, true=플레이어 승, false=상대 승).
  final List<bool?> _roundResults = List<bool?>.filled(_totalRounds, null);

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
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  // ── 이펙트 (step 6): 화면 흔들림 + 승패 플래시 + 당기기 리듬 파티클 ────────
  double _shake = 0; // 현재 흔들림 진폭(px)
  double _resultFlash = 0; // 승패 순간 화면 플래시 (1.0 → 0)
  bool _resultWin = false;
  double _fxPuffTimer = 0; // hold 모드 힘주기 퍼프 간격
  Offset _lastKnotPos = Offset.zero; // 매듭 화면 좌표 (렌더에서 갱신)
  Offset _lastGripPos = Offset.zero; // 플레이어 손 화면 좌표

  // 최종 승리 축하 연출 — 색종이/스파클이 실제로 떨어지는 걸 볼 수 있도록,
  // 매치가 끝나도 결과 화면으로 바로 넘어가지 않고 잠깐 붙잡아 둔다.
  // (이전엔 confetti를 스폰한 바로 다음 줄에서 _endGame을 호출해, 화면이
  // 즉시 결과 화면으로 전환되는 바람에 색종이가 뜨는 걸 볼 새가 없었음.)
  bool _celebrating = false;
  double _celebrationTimer = 0;
  static const double _celebrationDuration = 5.0; // 초
  // 색종이/스파클은 각각 1~3초 안에 다 사그라들어서, 5초짜리 축하 연출을
  // 한 번의 스폰만으로 채우면 뒷부분이 텅 비어 보인다. 그래서 홀드가 끝날
  // 때까지 일정 간격으로 새로 터뜨려 계속 축하하는 느낌을 유지한다.
  double _celebrationBurstTimer = 0;
  static const double _celebrationBurstInterval = 0.9; // 초

  // 낙하 완료 직후 홀드 — 낙하가 끝나자마자(같은 프레임에) 다음 라운드를
  // 시작하거나 결과 화면으로 넘어가면, 방금까지 축 늘어져 있던 로프가
  // _ropePosition=0으로 리셋되며 순간적으로 "위로 튕겨 올라가는" 것처럼
  // 보인다. 그래서 낙하가 끝난 상태(로프가 진 쪽으로 늘어진 채 고정된
  // 상태) 그대로 잠깐 붙잡아 뒀다가 라운드를 넘긴다 — 실제 로프가 진 쪽이
  // 놓은 뒤 이긴 쪽 손에 늘어져 걸려 있는 것처럼 보이게.
  bool _postFallHold = false;
  double _postFallTimer = 0;
  static const double _postFallHoldDuration = 1.3; // 초

  /// 떨어지기 연출 진행 중 여부 (모터 등장성 저항 재전송 차단용).
  bool get isFalling => _isFalling;

  TugOfWarFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
    this.onFallTriggered,
    TugMode mode = TugMode.cycle,
  }) : _mode = mode;

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

    // ── 난이도 연동 (step 8) ────────────────────────────────────────────────
    // 제한 시간: 설정 화면에서 고른 게임 시간.
    _timeLimit = config.gameDuration.inSeconds.toDouble();

    // difficultyLevel(1~5): 단계 내 세부 난이도. 높을수록 상대는 세지고,
    // 플레이어 힘 보정은 줄어 더 부지런히 당겨야 한다.
    final d = config.difficultyLevel.clamp(1, 5);
    _aiStrengthMul = 0.82 + (d - 1) * 0.09; // 0.82 → 1.18
    _playerPowerMul = 1.20 - (d - 1) * 0.08; // 1.20 → 0.88

    // Brunnstrom 단계별 필요 ROM: 한 번의 당기기/버티기에서 요구되는 가동 범위.
    // romRatio 0.4(2단계) ~ 1.0(5·6단계) → 슬라이더/센서 이동량 목표로 환산.
    _romTarget = (config.romRatio * 0.5).clamp(0.18, 0.5);

    await _loadFighterSprites();
  }

  double _romTarget = 0.3;

  /// 플레이어(player 1~4.png)·침팬지(champ 1~4.png) 실사 스프라이트 로드.
  /// 실패해도 게임이 멈추지 않도록 개별적으로 try/catch — 실패한 쪽만 빈
  /// 목록으로 남아 절차적 그래픽으로 대체된다.
  Future<void> _loadFighterSprites() async {
    Future<ui.Image> load(String name) async {
      final data = await rootBundle.load('assets/tugofwar/$name');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    try {
      _playerFrames =
          await Future.wait([1, 2, 3, 4].map((i) => load('player $i.png')));
      _playerSpriteScale = _playerSpriteH / _playerFrames[0].height;
    } catch (_) {
      _playerFrames = [];
    }
    try {
      _champFrames =
          await Future.wait([1, 2, 3, 4].map((i) => load('champ $i.png')));
      _champSpriteScale = _champSpriteH / _champFrames[0].height;
    } catch (_) {
      _champFrames = [];
    }
    try {
      _gorFrames =
          await Future.wait([1, 2, 3, 4].map((i) => load('gor $i.png')));
      _gorSpriteScale = _gorSpriteH / _gorFrames[0].height;
    } catch (_) {
      _gorFrames = [];
    }
    try {
      _orFrames =
          await Future.wait([1, 2, 3, 4].map((i) => load('or $i.png')));
      _orSpriteScale = _orSpriteH / _orFrames[0].height;
    } catch (_) {
      _orFrames = [];
    }

    // 배경/땅/매듭/이펙트는 서로 독립적으로 시도 — 하나가 없어도 나머지는
    // 스프라이트로, 그 하나만 절차적 그래픽으로 자동 대체된다.
    try {
      _bgImage = await load('background.png');
    } catch (_) {
      _bgImage = null;
    }
    try {
      _landImage = await load('left land.png');
    } catch (_) {
      _landImage = null;
    }
    try {
      _knotImage = await load('knot.png');
    } catch (_) {
      _knotImage = null;
    }
    try {
      _splashImage = await load('water splash.png');
    } catch (_) {
      _splashImage = null;
    }
    try {
      _winImage = await load('win.png');
    } catch (_) {
      _winImage = null;
    }
  }

  // ── 업데이트 (모든 게임 로직은 여기에서만) ────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // 이펙트는 일시정지·낙하 중에도 자연스럽게 잦아든다.
    _shake = max(0.0, _shake - dt * 45);
    _resultFlash = max(0.0, _resultFlash - dt * 2.0);
    _updateParticles(dt);

    if (!isRunning || _hasEnded) return;

    // 낙하가 막 끝난 직후 홀드 — 로프/캐릭터를 그 상태 그대로 잠깐 유지한
    // 뒤에야 라운드를 넘긴다(_postFallHold 필드 선언부 주석 참고).
    if (_postFallHold) {
      _postFallTimer -= dt;
      if (_postFallTimer <= 0) {
        _postFallHold = false;
        _resolveRoundEnd();
      }
      return;
    }

    // 최종 승리 축하 연출 중 — 색종이/스파클이 떨어지는 걸 보여준 뒤 결과
    // 화면으로 넘어간다. 이 동안엔 낙하/카운트다운/게임 로직을 진행하지
    // 않는다(이미 매치가 결정됐으므로).
    if (_celebrating) {
      _celebrationTimer -= dt;
      _celebrationBurstTimer -= dt;
      if (_celebrationBurstTimer <= 0 && _celebrationTimer > 0) {
        _celebrationBurstTimer = _celebrationBurstInterval;
        _spawnConfetti();
        _spawnSparkles();
      }
      if (_celebrationTimer <= 0) {
        _celebrating = false;
        _endGame(won: true);
      }
      return;
    }

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
    _matchElapsedSeconds += dt;
    if (_mode == TugMode.hold) {
      _detectHold(dt);
    } else {
      _detectPull(dt);
    }
    _updateAnimalAi();
    _updateRopePosition(dt);

    // 제한 시간 종료 시: 현재 로프가 우세한 쪽 승리 (동점이면 플레이어 승).
    if (_timeLimit > 0 && _elapsedSeconds >= _timeLimit) {
      _triggerFall(isPlayerFalling: _ropePosition < 0);
    } else if (_ropePosition >= 1.0) {
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
    _resultWin = !isPlayerFalling;
    _resultFlash = 1.0;
    _addShake(10);
    onFallTriggered?.call();
  }

  /// 4단계 낙하 연출 진행: 0.0~0.2 비틀거림, 0.2~0.4 발 미끄러짐(먼지),
  /// 0.4~0.8 낙하, 0.8~1.0 착지/물보라. 완료되면 실제로 게임을 종료한다.
  void _updateFall(double dt) {
    final wasSlip = _fallProgress >= 0.2 && _fallProgress < 0.4;
    final wasSplash = _fallProgress >= 0.8;

    _fallProgress = (_fallProgress + dt / _fallDuration).clamp(0.0, 1.0);

    if (!wasSlip && _fallProgress >= 0.2 && _fallProgress < 0.4) {
      _spawnFallParticles(dust: true); // 발 미끄러짐 진입 -> 먼지
    }
    if (!wasSplash && _fallProgress >= 0.8) {
      _spawnFallParticles(dust: false); // 착지 진입 -> 물보라
      _addShake(14); // 착지 충격
    }

    if (_fallProgress >= 1.0) {
      // 바로 _resolveRoundEnd()를 부르지 않고 잠깐 홀드한다 — _isFalling은
      // 계속 true, _fallProgress도 1.0에 고정된 채라 로프/캐릭터가 지금
      // "완전히 떨어진" 상태 그대로 유지된다. 홀드가 끝나면 update()가
      // _resolveRoundEnd()를 호출한다.
      _postFallHold = true;
      _postFallTimer = _postFallHoldDuration;
    }
  }

  /// 한 라운드가 끝났을 때 호출: 결과를 기록하고, 3전 2선승이 결정 났으면 경기를
  /// 종료하고, 아니면 다음 라운드를 준비한다.
  /// (docs/tug_of_war_build_guide.md §2 `_totalRounds`, §10 Phase 4 라운드 시스템)
  void _resolveRoundEnd() {
    final roundWon = !_isPlayerFalling;
    _roundResults[_currentRound - 1] = roundWon;
    if (roundWon) {
      _playerRoundWins++;
    } else {
      _animalRoundWins++;
    }

    final matchOver = _playerRoundWins >= 2 ||
        _animalRoundWins >= 2 ||
        _currentRound >= _totalRounds;

    if (matchOver) {
      final matchWon = _playerRoundWins > _animalRoundWins;
      if (matchWon) {
        // 최종 승리: 색종이/스파클이 실제로 보이도록 잠깐 붙잡아 둔 다음
        // 결과 화면으로 넘어간다 (update()의 _celebrating 분기 참고).
        // _isFalling은 일부러 그대로 true로 둔다 — update()에서 _celebrating
        // 분기가 _isFalling 검사보다 먼저 return하므로 _updateFall이 다시
        // 실행될 일은 없고, 대신 render()가 계속 "낙하 완료(투명)" 상태로
        // 그려 방금 떨어진 캐릭터가 다시 팝업하듯 나타나지 않는다.
        _celebrating = true;
        _celebrationTimer = _celebrationDuration;
        _celebrationBurstTimer = _celebrationBurstInterval;
        _spawnConfetti();
        _spawnSparkles();
      } else {
        _endGame(won: false); // 패배는 축하 연출 없이 바로 결과 화면으로.
      }
    } else {
      _startNextRound();
    }
  }

  /// 다음 라운드 준비: 로프·힘·낙하·이펙트 상태만 초기화한다. 동물 종류
  /// (Brunnstrom 단계로 이미 정해짐)와 누적 반복 횟수(_pullCount) 등 경기
  /// 전체 통계는 그대로 유지한다.
  void _startNextRound() {
    _currentRound++;
    _isFalling = false;
    _isPlayerFalling = false;
    _fallProgress = 0.0;
    _ropePosition = 0.0;
    _pullPower = 0;
    _isPulling = false;
    _elapsedSeconds = 0; // 라운드별 제한 시간 리셋
    _countdown = 3.0;
    _particles.clear();
    _shake = 0;
    _resultFlash = 0;
    _fxPuffTimer = 0;

    // _aiPower/_ropePosition 관련 표시(HUD 게이지·상대 힘 수치, 모터 저항)가
    // 직전 라운드가 끝나던 순간의 극단적인 값을 그대로 보여주지 않도록, 이미
    // 리셋된 상태(_ropePosition=0, _elapsedSeconds=0)로 즉시 다시 계산한다.
    // (그렇지 않으면 다음 _updateAnimalAi() 호출 전까지 카운트다운 내내
    //  이전 라운드의 마지막 힘 수치가 화면/모터에 남아 "리셋 안 됨"으로 보임.)
    _updateAnimalAi();
  }

  void _addShake(double amt) => _shake = min(30.0, _shake + amt);

  void _spawnFallParticles({required bool dust}) {
    final x = _isPlayerFalling ? _playerCenterX(size.x) : _opponentCenterX(size.x);
    // 발 미끄러짐 먼지는 다리 위에서, 착지 물보라는 저 아래 강 수면에서.
    final y = dust ? _standY(x, size.x, size.y) + 14 : size.y * 0.9;
    final color = dust ? const Color(0xFF9E8563) : const Color(0xFF8ECFEA);
    final n = _fxCount(14);
    for (int i = 0; i < n; i++) {
      final angle = dust ? _rng.nextDouble() * pi : _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 100;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - (dust ? 0 : 80),
        color: color,
        radius: 3 + _rng.nextDouble() * 3,
      ));
    }

    // 착지 물보라: 작은 물방울들 위에 water splash.png 한 장을 크게 겹쳐
    // 그려 착지 순간을 확실히 보여준다 (스프라이트 없으면 물방울로만 표현).
    if (!dust && _splashImage != null) {
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: 0,
        vy: -8,
        color: Colors.white, // 이미지 파티클은 color를 쓰지 않음
        radius: 55,
        gravity: 0,
        fade: 1.1,
        image: _splashImage,
      ));
    }
  }

  /// 승리 시 화면 위에서 쏟아지는 반짝이는 색종이(승리 스파클).
  /// win.png(색종이 조각이 흩어진 시트)가 로드됐으면 그 안에서 무작위 작은
  /// 영역을 잘라 조각 텍스처로 쓰고, 없으면 단색 사각형으로 대체한다.
  void _spawnConfetti() {
    const palette = [
      Color(0xFFFFC857),
      Color(0xFF5AC8FA),
      Color(0xFFFF6B6B),
      Color(0xFF7BE495),
      Color(0xFFC792EA),
    ];
    final win = _winImage;
    final n = _fxCount(46);
    for (int i = 0; i < n; i++) {
      Rect? srcRect;
      if (win != null) {
        const cropSize = 46.0;
        final maxX = max(0.0, win.width - cropSize);
        final maxY = max(0.0, win.height - cropSize);
        srcRect = Rect.fromLTWH(
          _rng.nextDouble() * maxX,
          _rng.nextDouble() * maxY,
          cropSize,
          cropSize,
        );
      }
      _particles.add(_Particle(
        x: _rng.nextDouble() * size.x,
        y: -10 - _rng.nextDouble() * size.y * 0.3,
        vx: (_rng.nextDouble() * 2 - 1) * 60,
        vy: 60 + _rng.nextDouble() * 90,
        color: palette[_rng.nextInt(palette.length)],
        radius: win != null ? 11 + _rng.nextDouble() * 5 : 3 + _rng.nextDouble() * 3,
        gravity: 40,
        fade: 0.35,
        rect: win == null,
        angle: _rng.nextDouble() * pi,
        spin: (_rng.nextDouble() * 2 - 1) * 6,
        image: win,
        srcRect: srcRect,
      ));
    }
  }

  /// 승리 시 화면 곳곳에서 반짝이는 별빛 스파클. 색종이(_spawnConfetti)와는
  /// 별개로, 화면에 고정된 채 짧게 깜빡이다 사라진다.
  void _spawnSparkles() {
    final n = _fxCount(26);
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble() * size.x,
        y: _rng.nextDouble() * size.y * 0.75,
        vx: 0,
        vy: -6, // 아주 살짝 위로 떠오르며 사라짐
        color: _rng.nextBool() ? const Color(0xFFFFF3B0) : Colors.white,
        radius: 3 + _rng.nextDouble() * 4,
        gravity: 0,
        fade: 0.6 + _rng.nextDouble() * 0.7,
        angle: _rng.nextDouble() * pi,
        spin: (_rng.nextDouble() * 2 - 1) * 3,
        sparkle: true,
      ));
    }
  }

  /// 힘을 쓰는 순간의 짧은 퍼프 (한 번의 당기기 완료 / 버티기 유지 중).
  void _spawnEffortPuff(Offset at, {int count = 6, Color? color}) {
    final n = _fxCount(count);
    for (int i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = 30 + _rng.nextDouble() * 70;
      _particles.add(_Particle(
        x: at.dx,
        y: at.dy,
        vx: cos(a) * sp,
        vy: sin(a) * sp - 20,
        color: color ?? const Color(0xFFDCE6EC),
        radius: 2 + _rng.nextDouble() * 2.5,
        gravity: 60,
        fade: 2.2,
      ));
    }
  }

  /// 매듭에서 튀는 장력 불꽃 (강한 당기기 순간).
  void _spawnTensionSparks(Offset at) {
    final n = _fxCount(8);
    for (int i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = 80 + _rng.nextDouble() * 140;
      _particles.add(_Particle(
        x: at.dx,
        y: at.dy,
        vx: cos(a) * sp,
        vy: sin(a) * sp,
        color: const Color(0xFFFFE08A),
        radius: 1.5 + _rng.nextDouble() * 2,
        gravity: 30,
        fade: 3.0,
      ));
    }
  }

  /// 인지 레벨(particleCount)에 맞춰 파티클 수를 제한한다.
  int _fxCount(int base) {
    final cap = (config.cognitiveLevel.particleCount * 3).clamp(4, 60);
    return min(base, cap);
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
      p.angle += p.spin * dt;
      p.life -= dt * p.fade;
    }
    _particles.removeWhere((p) => p.life <= 0);
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
        // 요구 ROM(_romTarget)을 채울수록 힘이 온전히 실린다 (최소 35%는 인정).
        final romQuality = (pullRange / _romTarget).clamp(0.35, 1.0);
        final gain = pullRange * pullSpeed * 20.0 * _playerPowerMul * romQuality;
        _pullPower += gain;
        if (pullRange >= _romTarget * 0.4) _pullCount++;

        // 한 번의 당기기 완료 이펙트: 손에 퍼프, 세게 당겼으면 매듭에서 불꽃 + 흔들림.
        _spawnEffortPuff(_lastGripPos, color: const Color(0xFFBFD4E0));
        if (gain > 3.0) {
          _spawnTensionSparks(_lastKnotPos);
          _addShake((gain * 0.6).clamp(0.0, 6.0));
        }
      }
    }

    _prevPosition = currentPosition;
  }

  /// hold 모드: 사이클 누적이 아니라 "굽힌 자세를 유지하는 정도"를 그대로 당기는
  /// 힘으로 쓴다(등척성). 자세를 놓으면(슬라이더/팔이 폄 쪽으로 되돌아가면) 힘이
  /// 빠르게 사라져 상대가 로프를 가져간다. 슬라이더의 자동 되돌림은 Flutter
  /// 래퍼(_holdReturn 타이머)가, 모터 연결 시엔 등장성 저항이 담당한다.
  void _detectHold(double dt) {
    // 요구 ROM(_romTarget×2 ≈ romRatio)까지 굽히면 100%. 낮은 단계일수록
    // 더 적게 굽혀도 완전한 버티기로 인정된다.
    final span = (_romTarget * 2 * (1 - _holdDeadzone)).clamp(0.2, 0.85);
    final held =
        ((currentPosition - _holdDeadzone) / span).clamp(0.0, 1.0);
    final targetPull = held * _holdMaxPull * _playerPowerMul;

    // 목표 힘으로 부드럽게 수렴 (버틸 땐 서서히 차오르고, 놓으면 빠르게 0으로).
    final k = (dt * (targetPull >= _pullPower ? 4.0 : 9.0)).clamp(0.0, 1.0);
    _pullPower += (targetPull - _pullPower) * k;

    if (held > 0.2) {
      _holdSeconds += dt;
      _pullCount = (_holdSeconds / 2.0).floor(); // 2초 버티기 = 1회로 환산

      // 버티는 동안 주기적으로 손에서 힘줄기 퍼프.
      _fxPuffTimer -= dt;
      if (_fxPuffTimer <= 0) {
        _fxPuffTimer = 0.45;
        _spawnEffortPuff(_lastGripPos,
            count: 4, color: const Color(0xFF9FE7C7));
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

    // _aiStrengthMul: difficultyLevel(1~5) 파생 미세 보정.
    _aiPower = baseStrength * _aiStrengthMul * adaptiveFactor * (1.0 + wave);
  }

  void _updateRopePosition(double dt) {
    final netForce = _pullPower - _aiPower;
    _ropePosition = (_ropePosition + netForce * dt * 0.05).clamp(-1.0, 1.0);

    // hold 모드의 힘은 _detectHold가 매 프레임 자세로부터 다시 산출하므로
    // 아래의 사이클용 감쇠를 적용하지 않는다 (적용하면 이중 감쇠가 됨).
    if (_mode == TugMode.hold) return;

    // 당긴 힘은 시간이 지나면 서서히 줄어든다 -> 계속 당겨야 로프가 밀린다.
    // (기존 1.5는 반감기 약 0.46초로, 실제 재활 환자는 물론 슬라이더로도
    //  그 속도로 반복 당기기가 불가능해 상대(7~15)를 절대 못 이기는 문제가
    //  있었음. 이 값은 build guide에 명시되지 않은 튜닝값이라 0.6으로 완화 —
    //  반감기 약 1.16초, 1~2초 간격의 현실적인 반복 당기기로도 버틸 수 있게.)
    _pullPower *= (1 - dt * 0.6).clamp(0.0, 1.0);
  }

  // ── 렌더 (그리기만, 로직 없음) ────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;

    // 화면 흔들림: 월드(배경~파티클)에만 적용하고 HUD/카운트다운은 고정.
    canvas.save();
    if (_shake > 0.05) {
      canvas.translate(
        (_rng.nextDouble() * 2 - 1) * _shake,
        (_rng.nextDouble() * 2 - 1) * _shake,
      );
    }

    // 배경: 정글 협곡 + 아래 강, 좌우 절벽. (원장님 지시로 다리는 제거 —
    // 강에 빠지는 낙하 연출은 그대로 유지하고, 흔들리는 다리로 인한 긴장감만 없앤다.)
    _drawCanyon(canvas, w, h);

    // 실제로 늘어지는 로프 + 가운데 매듭(nut). 매듭은 로프 위치에 따라 좌우로
    // 이동하고, 당기는 힘이 셀수록 로프가 팽팽해지며(처짐 감소) 미세하게 떨린다.
    _drawRope(canvas, w, h);

    // 플레이어 (사람) — 왼쪽 절벽 끝에서 오른쪽(로프)을 향해 버틴다.
    final px = _playerCenterX(w);
    _drawFighter(
      canvas,
      center: Offset(px, _standY(px, w, h) - 48),
      facing: 1,
      falling: _isFalling && _isPlayerFalling,
      strength: _poseStrength(_pullPower),
      cadence: 5.0,
      paint: _paintPlayer,
    );

    // 상대 (동물) — 오른쪽 절벽 끝에서 왼쪽(로프)을 향한다. 종류마다 체형이 다르다.
    final ox = _opponentCenterX(w);
    _drawFighter(
      canvas,
      center: Offset(ox, _standY(ox, w, h) - 48),
      facing: -1,
      falling: _isFalling && !_isPlayerFalling,
      strength: _poseStrength(_aiPower),
      cadence: switch (_currentAnimal) {
        AnimalType.chimpanzee => 9.0,
        AnimalType.orangutan => 2.6,
        AnimalType.gorilla => 1.7,
      },
      paint: _paintAnimal,
    );

    _drawParticles(canvas);

    canvas.restore(); // 흔들림 종료

    // 승패 순간 화면 플래시 (승=초록, 패=빨강).
    if (_resultFlash > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = (_resultWin ? Colors.greenAccent : Colors.redAccent)
              .withValues(alpha: _resultFlash * 0.22),
      );
    }

    _drawHud(canvas, w, h);

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

      // 2라운드부터는 새 라운드가 시작됨을 알려준다 (per-round reset 안내).
      if (_currentRound > 1) {
        TextPaint(
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ).render(canvas, '라운드 $_currentRound / $_totalRounds',
            Vector2(w / 2, h / 2 + 70), anchor: Anchor.center);
      }
    }
  }

  // ── HUD (step 7) ────────────────────────────────────────────────────────
  // 상단 중앙: 줄다리기 우세 게이지(-1 나 ~ +1 상대). 좌우 끝: '나' / 동물 이름.
  // 좌상단: 방식 뱃지. 인지 레벨에 따라 타이머·힘 수치·진행 정보를 추가로 표시.
  void _drawHud(Canvas canvas, double w, double h) {
    final cog = config.cognitiveLevel;

    // 라운드 표시 (●○○) — 3전 2선승 진행 상황. 핵심 정보라 인지 레벨과 무관하게 항상 표시.
    _drawRoundDots(canvas, w);

    // 우세 게이지
    final gaugeW = w * 0.58, gaugeH = 14.0;
    final gx = (w - gaugeW) / 2, gy = 34.0;
    final cx = gx + gaugeW / 2;
    final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(gx, gy, gaugeW, gaugeH), const Radius.circular(7));
    canvas.drawRRect(track, Paint()..color = Colors.black.withValues(alpha: 0.45));

    final p = _ropePosition.clamp(-1.0, 1.0);
    final fillW = (gaugeW / 2) * p.abs();
    final fillRect = p >= 0
        ? Rect.fromLTWH(cx, gy, fillW, gaugeH)
        : Rect.fromLTWH(cx - fillW, gy, fillW, gaugeH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(7)),
      Paint()
        ..color = (p >= 0 ? Colors.lightBlueAccent : Colors.deepOrangeAccent)
            .withValues(alpha: 0.9),
    );
    canvas.drawRRect(
        track,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white24);
    canvas.drawLine(Offset(cx, gy - 4), Offset(cx, gy + gaugeH + 4),
        Paint()..color = Colors.white54..strokeWidth = 2);

    // 게이지 위 매듭 표식
    final knobX = cx + (gaugeW / 2) * p;
    final knobC = Offset(knobX, gy + gaugeH / 2);
    canvas.drawCircle(knobC, 8, Paint()..color = const Color(0xFFB07C3F));
    canvas.drawCircle(
        knobC,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF5C3C1B));

    final hud = TextPaint(
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
    final hudDim = TextPaint(
      style: const TextStyle(
        fontSize: 12,
        color: Colors.white70,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );

    hud.render(canvas, '나', Vector2(gx - 8, gy + gaugeH / 2),
        anchor: Anchor.centerRight);
    hud.render(canvas, _animalName(), Vector2(gx + gaugeW + 8, gy + gaugeH / 2),
        anchor: Anchor.centerLeft);

    final rowY = gy + gaugeH + 12;

    // 방식 뱃지
    _drawPill(
      canvas,
      Offset(12, rowY),
      _mode == TugMode.hold ? '버티기' : '반복',
      _mode == TugMode.hold ? Colors.tealAccent : Colors.lightBlueAccent,
    );

    // 타이머 (인지 레벨 2 이상)
    if (cog.showTimer) {
      final t = _timeLimit > 0
          ? (_timeLimit - _elapsedSeconds).clamp(0.0, _timeLimit)
          : _elapsedSeconds;
      hud.render(canvas, _fmtTime(t), Vector2(w / 2, rowY),
          anchor: Anchor.topCenter);
      hudDim.render(canvas, '당기는 힘 ${_pullPower.toStringAsFixed(1)}',
          Vector2(12, rowY + 22), anchor: Anchor.topLeft);
      hudDim.render(canvas, '상대 힘 ${_aiPower.toStringAsFixed(1)}',
          Vector2(w - 12, rowY + 22), anchor: Anchor.topRight);
    }

    // 진행 정보 (인지 레벨 2 이상)
    if (cog.showCombo) {
      final info = _mode == TugMode.hold
          ? '버틴 시간 ${_holdSeconds.toStringAsFixed(0)}s'
          : '당긴 횟수 $_pullCount';
      hudDim.render(canvas, info, Vector2(w - 12, rowY),
          anchor: Anchor.topRight);
    }
  }

  /// 라운드 진행 표시 (●○○): 끝난 라운드는 승패 색으로 채우고, 남은 라운드는
  /// 빈 원으로 둔다. (docs/tug_of_war_build_guide.md §12 "라운드 (●○○)")
  void _drawRoundDots(Canvas canvas, double w) {
    const r = 5.0, gap = 16.0;
    const totalW = (_totalRounds - 1) * gap;
    final startX = w / 2 - totalW / 2;
    for (int i = 0; i < _totalRounds; i++) {
      final result = _roundResults[i];
      final color = result == null
          ? Colors.white24
          : (result ? Colors.lightBlueAccent : Colors.deepOrangeAccent);
      final c = Offset(startX + i * gap, 9);
      canvas.drawCircle(c, r, Paint()..color = color);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white38,
      );
    }
  }

  String _animalName() => switch (_currentAnimal) {
        AnimalType.chimpanzee => '침팬지',
        AnimalType.orangutan => '오랑우탄',
        AnimalType.gorilla => '고릴라',
      };

  String _fmtTime(double s) {
    final total = s.ceil();
    final m = total ~/ 60;
    final sec = (total % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _drawPill(Canvas canvas, Offset topLeft, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padX = 9.0, padY = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            topLeft.dx, topLeft.dy, tp.width + padX * 2, tp.height + padY * 2),
        const Radius.circular(10),
      ),
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(topLeft.dx + padX, topLeft.dy + padY));
  }

  // ── 캐릭터 위치 (지는 쪽이 상대에게 끌려간다) ────────────────────────────
  // 실제 줄다리기처럼 로프가 팽팽한 채로, 이기는 쪽이 로프를 감아 당기면 지는
  // 쪽 사람이 자기 땅의 안쪽(강 쪽) 가장자리(_dragLimitL/R)까지 끌려온다.
  // _ropePosition +1 = 플레이어 우세(상대가 끌려옴), -1 = 플레이어 열세
  // (플레이어가 끌려옴).
  // (원장님 지시: 다리를 없애 두 땅 사이에 아무 연결도 없게 만들어야 더
  // 긴장감 있다 — 지면 바로 발밑이 낭떠러지. 그래서 땅은 왼쪽/오른쪽에 각각
  // 하나씩만 놓고 가운데는 강이 보이는 허공으로 비워 둔다. 가장자리를 넘는
  // 순간 낙하 연출이 시작되어 그 허공(강)으로 떨어진다.)
  double _playerCenterX(double w) {
    final dragged = (_ropePosition < 0 ? -_ropePosition : 0.0); // 0~1
    var x = w * 0.15 + dragged * (w * _dragLimitL - w * 0.15); // 최대치=땅 가장자리
    if (_isFalling && _isPlayerFalling) x += _fallProgress * (w * 0.09);
    return x;
  }

  double _opponentCenterX(double w) {
    final dragged = (_ropePosition > 0 ? _ropePosition : 0.0);
    var x = w * 0.85 - dragged * (w * 0.85 - w * _dragLimitR);
    if (_isFalling && !_isPlayerFalling) x -= _fallProgress * (w * 0.09);
    return x;
  }

  // 지는 쪽이 낙하 전까지 최대로 끌려올 수 있는, 자기 땅의 안쪽(강 쪽)
  // 가장자리 (w 비율). _landWidthFrac(0.34)보다 살짝 안쪽이라 캐릭터가
  // 절대 땅 밖으로 발을 내밀고 서 있는 것처럼 보이지 않는다.
  static const double _dragLimitL = 0.30;
  static const double _dragLimitR = 0.70;

  double _standY(double x, double w, double h) => h * 0.63;

  // ── 배경: 정글 + 강 + 좌우로 분리된 두 땅(가운데는 허공) ────────────────
  // 인지 레벨(bgComplexity 0/1/2)에 따라 장식 요소를 단계적으로 줄인다.
  void _drawCanyon(Canvas canvas, double w, double h) {
    final detail = config.cognitiveLevel.bgComplexity; // 0=단순 ~ 2=풍부
    final bg = _bgImage;

    if (bg != null) {
      // 하늘/먼 산/캐노피 스프라이트를 화면 전체에 늘려 채운다.
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Rect.fromLTWH(0, 0, w, h),
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      // 절차적 대체: 하늘/캐노피 그라데이션
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF35564A), Color(0xFF223438), Color(0xFF16232A)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      // 먼 정글 실루엣 (풍부 레벨에서만)
      if (detail >= 2) {
        final canopy = Paint()
          ..color = const Color(0xFF3B5A48).withValues(alpha: 0.5);
        for (int i = 0; i <= 6; i++) {
          final cx = w * (i / 6.0);
          canvas.drawCircle(Offset(cx, h * 0.16), h * 0.11, canopy);
          canvas.drawCircle(Offset(cx + w * 0.08, h * 0.23), h * 0.09, canopy);
        }
      }
      // 옅은 안개 띠 (보통 레벨 이상)
      if (detail >= 1) {
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.40, w, h * 0.24),
          Paint()..color = const Color(0xFFAEC6C0).withValues(alpha: 0.09),
        );
      }
    }

    // 협곡 아래 강
    final riverTop = h * 0.85;
    canvas.drawRect(
      Rect.fromLTWH(0, riverTop, w, h - riverTop),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C6E7E), Color(0xFF163F49)],
        ).createShader(Rect.fromLTWH(0, riverTop, w, h - riverTop)),
    );
    // 흐르는 물결 (보통 레벨 이상)
    if (detail >= 1) {
      final ripple = Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (int i = 0; i < 5; i++) {
        final ry = riverTop + 10 + i * (h - riverTop) / 6;
        final phase = _elapsedSeconds * 1.5 + i;
        final path = Path()..moveTo(0, ry);
        for (double x = 0; x <= w; x += 22) {
          path.lineTo(x, ry + sin(x / 40 + phase) * 2.5);
        }
        canvas.drawPath(path, ripple);
      }
    }

    _drawGround(canvas, w, h, detail: detail);
  }

  // 각 땅이 차지하는 화면 폭 비율. _dragLimitL/R(0.30/0.70)보다 살짝 넓게
  // 잡아, 지는 쪽이 최대로 끌려와도 시각적으로 여전히 땅 위에 서 있다.
  static const double _landWidthFrac = 0.34;

  /// 좌우로 분리된 두 땅. left land.png를 왼쪽엔 그대로, 오른쪽엔 좌우
  /// 반전해서 화면 가장자리에 한 번씩만 놓는다 — 서로 잇지 않고 가운데는
  /// _drawCanyon이 이미 그린 강/배경이 그대로 보이는 허공으로 남긴다.
  void _drawGround(Canvas canvas, double w, double h, {required int detail}) {
    final topY = h * 0.63;
    final land = _landImage;
    final landW = w * _landWidthFrac;

    if (land != null) {
      final tileH = h - (topY - 6); // 풀밭 라인부터 화면 맨 아래까지
      // left land.png는 위쪽 ~16%가 듬성듬성한 잎사귀 끝(투명 배경 위)이고,
      // 실제로 꽉 찬 잔디 표면은 그보다 아래에서 시작한다(실측: 높이 353px
      // 중 약 56px 지점부터 폭이 거의 꽉 참). 이 여백을 그대로 스트레치하면
      // "꽉 찬 땅"이 실제 화면상 topY보다 한참 아래에서 시작해, 그 위에 서는
      // 캐릭터 발이 잔디 위 허공에 떠 있는 것처럼 보인다. 그래서 소스에서
      // 이 여백을 잘라내고 꽉 찬 부분만 목적지(topY-6 ~ 화면 맨 아래)에
      // 채운다 — 캐릭터 발밑 그림자 높이(topY)와 잔디 표면이 맞아떨어진다.
      const marginFrac = 56 / 353;
      final srcTop = land.height * marginFrac;
      final src = Rect.fromLTWH(
          0, srcTop, land.width.toDouble(), land.height - srcTop);
      final paint = Paint()..filterQuality = FilterQuality.medium;

      // 왼쪽 땅 — 화면 왼쪽 가장자리에 딱 한 번.
      canvas.drawImageRect(
          land, src, Rect.fromLTWH(0, topY - 6, landW, tileH), paint);

      // 오른쪽 땅 — 같은 이미지를 좌우 반전해 오른쪽 가장자리에 딱 한 번.
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
          land, src, Rect.fromLTWH(0, topY - 6, landW, tileH), paint);
      canvas.restore();
      return;
    }

    // 절차적 대체 — 좌우 각각 절벽 하나씩, 가운데는 비워 강이 그대로 보인다.
    _drawProceduralCliff(canvas, w, h, left: true, width: landW, detail: detail);
    _drawProceduralCliff(canvas, w, h,
        left: false, width: landW, detail: detail);
  }

  void _drawProceduralCliff(Canvas canvas, double w, double h,
      {required bool left, required double width, required int detail}) {
    final topY = h * 0.63;
    final x0 = left ? 0.0 : w - width;
    final edgeX = left ? width : w - width; // 안쪽(강 쪽) 가장자리
    final outX = left ? -2.0 : w + 2;
    final dir = left ? 1.0 : -1.0;
    const steps = 7;

    // 바위 덩어리 — 안쪽 가장자리를 지그재그로 깎아 절벽 느낌.
    final rock = Path()..moveTo(outX, topY - 6);
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = topY + t * (h - topY + 4);
      final jag = (i.isEven ? 12.0 : -4.0) * dir + sin(i * 2.0) * 4 * dir;
      rock.lineTo(edgeX + jag, y);
    }
    rock
      ..lineTo(outX, h + 2)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF3B322A));
    canvas.drawPath(
      rock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF2A231D),
    );

    // 풀 덮인 윗면
    canvas.drawRect(Rect.fromLTWH(x0, topY - 6, width, 12),
        Paint()..color = const Color(0xFF497A3C));
    canvas.drawRect(Rect.fromLTWH(x0, topY - 6, width, 4),
        Paint()..color = const Color(0xFF5FA04D));

    if (detail >= 1) {
      final blade = Paint()
        ..color = const Color(0xFF5FA04D)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final bx = x0 + width * (i + 0.5) / 6;
        final lean = (i.isEven ? 1 : -1) * 3.0;
        canvas.drawLine(
            Offset(bx, topY - 2), Offset(bx + lean, topY + 7), blade);
      }
    }

    // 매달린 덩굴 (풍부 레벨에서만)
    if (detail >= 2) {
      final vine = Paint()
        ..color = const Color(0xFF3C6B3A)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final vx = edgeX + dir * (6.0 + i * 12);
        final sway = sin(_elapsedSeconds * 1.2 + i) * 4;
        canvas.drawPath(
          Path()
            ..moveTo(vx, topY - 2)
            ..quadraticBezierTo(
                vx + sway, topY + 30, vx + sway * 1.6, topY + 58),
          vine,
        );
        canvas.drawCircle(Offset(vx + sway * 1.6, topY + 58), 3,
            Paint()..color = const Color(0xFF4C7A3E));
      }
    }
  }

  // ── 로프 렌더 ────────────────────────────────────────────────────────────
  // 로프 양 끝을 두 캐릭터의 "손"에 고정한다. 가운데 매듭(nut)은 로프를 감아
  // 당기는 쪽(이기는 쪽)으로 이동한다. 로프는 힘의 합이 클수록 팽팽해지며,
  // 전체가 균일하게 처진다 — 지는 쪽만 느슨해지지 않는다(오히려 끌려가는 쪽이
  // 더 팽팽하다). 실제로 축 늘어지는 건 이미 떨어진 사람 쪽 구간뿐이다.
  void _drawRope(Canvas canvas, double w, double h) {
    // 손 위치는 _drawFighter가 실제로 그릴 때 쓰는 것과 똑같은 변환(안간힘
    // 젖힘 회전 + 낙하 기울임/축소)을 그대로 적용해 계산한다 — 그래야
    // 캐릭터가 뒤로 젖혀지거나 낙하로 기울어질 때도 로프가 항상 손을
    // 따라간다(_handWorldPos 참고).
    final pcx = _playerCenterX(w), ocx = _opponentCenterX(w);
    final playerCenter = Offset(pcx, _standY(pcx, w, h) - 48);
    final opponentCenter = Offset(ocx, _standY(ocx, w, h) - 48);
    final oppCfg = _opponentSpriteConfig();

    final leftHand = _handWorldPos(
      center: playerCenter,
      facing: 1,
      falling: _isFalling && _isPlayerFalling,
      strength: _poseStrength(_pullPower),
      cadence: 5.0,
      frames: _playerFrames,
      scale: _playerSpriteScale,
      fracX: _playerHandFracX,
      fracY: _playerHandFracY,
    );
    final rightHand = _handWorldPos(
      center: opponentCenter,
      facing: -1,
      falling: _isFalling && !_isPlayerFalling,
      strength: _poseStrength(_aiPower),
      cadence: switch (_currentAnimal) {
        AnimalType.chimpanzee => 9.0,
        AnimalType.orangutan => 2.6,
        AnimalType.gorilla => 1.7,
      },
      frames: oppCfg?.frames,
      scale: oppCfg?.scale,
      fracX: oppCfg?.fracX,
      fracY: oppCfg?.fracY,
    );

    // 낙하 연출: 진 쪽 로프 구간만 추가로 축 늘어진다(손 위치 자체는 이미
    // 위 _handWorldPos가 낙하 기울임/하강을 반영해 계산했다).
    final fallenSlack = _isFalling ? 70 * _fallProgress : 0.0;

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

    // 파티클 스폰 위치로 재사용 (렌더가 update 뒤에 돌므로 한 프레임 지연은 무해).
    _lastKnotPos = knot;
    _lastGripPos = leftHand;
  }

  /// 한쪽 로프 구간을 2차 베지어를 따라 절차적으로 그린다: 굵은 외곽선 →
  /// 밝은 심 → 꼬임 눈금. (rope.png 스프라이트는 작은 타일을 이어 붙이는
  /// 스탬프 방식이 이음새가 도드라져 당분간 쓰지 않기로 했다 — 위 필드
  /// 선언부 주석 참고. 손 앵커(_playerHandFracX/Y 등)가 정확해 스프라이트
  /// 캐릭터의 맞잡은 손 바로 위로 이 로프가 자연스럽게 이어진다.)
  void _drawRopeSegment(Canvas canvas, Offset a, Offset b, double sag) {
    // 중점을 sag 만큼 끌어내리도록 제어점 y 를 2*sag 로.
    final ctrl = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + sag * 2);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    // 그림자 — 살짝 아래로 오프셋한 흐린 선으로 로프가 허공에 걸려 있는
    // 입체감을 준다.
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.14),
    );
    canvas.restore();

    // 외곽선(어두운 갈색) → 중간 톤 몸통. 두 가닥이 감아 도는 무늬는 아래
    // strand 루프에서 따로 그려 원통형 꼬임을 표현한다.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5C3B1E),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB98A4E),
    );

    // 두 가닥이 서로 꼬이며 로프 몸통을 감아 도는 모양 — 곡선을 따라가며
    // 접선에 수직인 방향으로 사인파처럼 좌우로 오가는 얇은 줄무늬 두 개를
    // (반 바퀴 어긋나게) 그린다.
    final len = (b - a).distance + sag.abs();
    final turns = (len / 16).clamp(3.0, 40.0);
    const steps = 40;
    for (int strand = 0; strand < 2; strand++) {
      final strandPath = Path();
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final p = _quad(a, ctrl, b, t);
        final tan = _quadTangent(a, ctrl, b, t);
        final tlen = tan.distance == 0 ? 1.0 : tan.distance;
        final nx = -tan.dy / tlen, ny = tan.dx / tlen; // 접선의 법선(수직) 방향
        final phase = t * turns * 2 * pi + (strand == 0 ? 0 : pi);
        final off = sin(phase) * 3.2; // 로프 두께 안에서 좌우로 왔다갔다
        final px = p.dx + nx * off;
        final py = p.dy + ny * off;
        if (i == 0) {
          strandPath.moveTo(px, py);
        } else {
          strandPath.lineTo(px, py);
        }
      }
      canvas.drawPath(
        strandPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = strand == 0
              ? const Color(0xFF7A5226).withValues(alpha: 0.85)
              : const Color(0xFFE0B878).withValues(alpha: 0.7),
      );
    }
  }

  /// 가운데 매듭(nut) — 둥근 로프 뭉치(교차로 꼬인 두 가닥) + 위로 세운
  /// 짧은 깃대에 달린 삼각 표식기. 로프가 느슨할수록 살짝 더 흔들린다.
  void _drawKnot(Canvas canvas, Offset c, double tension) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sin(_elapsedSeconds * 3.0) * (0.05 + (1.0 - tension) * 0.05));

    final knotImg = _knotImage;

    // 그림자 — knot.png 사용 시 실제 매듭 크기(아래 targetW)에 맞춰 작게.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 6),
        width: knotImg != null ? 16 : 30,
        height: knotImg != null ? 7 : 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    if (knotImg != null) {
      // 로프(굵기 12px 내외) 옆에서 너무 커 보이지 않도록 실측 크기보다
      // 훨씬 작게(폭 22px) 그린다 — knot.png는 위쪽 ~40%가 둥근 매듭 뭉치,
      // 아래 ~60%는 늘어진 리본이다(실측: 128px 중 매듭 중심은 약 27px
      // 지점). 이미지 전체를 (0,0)에 중앙 정렬하면 매듭 뭉치가 로프보다
      // 한참 위로 뜨므로, 매듭 중심이 정확히 로프 지점(로컬 (0,0))에 오도록
      // 세로 위치를 보정한다.
      const targetW = 22.0;
      final targetH = targetW * (knotImg.height / knotImg.width);
      const ballCenterFrac = 27 / 128; // 매듭 뭉치 중심의 세로 비율(실측)
      canvas.drawImageRect(
        knotImg,
        Rect.fromLTWH(0, 0, knotImg.width.toDouble(), knotImg.height.toDouble()),
        Rect.fromLTWH(
            -targetW / 2, -targetH * ballCenterFrac, targetW, targetH),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }

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
    final pose = _computeFighterPose(
        facing: facing, falling: falling, strength: strength, cadence: cadence);
    if (pose.alpha <= 0) return;

    // 발밑 그림자 (월드 공간, 회전 영향 없음)
    if (!falling || _fallProgress < 0.4) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(center.dx, center.dy + 48), width: 62, height: 14),
        Paint()..color = Colors.black.withValues(alpha: 0.20 * pose.alpha),
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy + pose.dy);
    canvas.rotate(pose.lean * facing); // 월드 공간 젖힘 (facing 으로 방향 보정)
    canvas.scale(facing * pose.scale, pose.scale); // 좌우 반전 + 낙하 축소
    if (pose.alpha < 1.0) {
      canvas.saveLayer(
        const Rect.fromLTRB(-150, -170, 150, 170),
        Paint()..color = Colors.white.withValues(alpha: pose.alpha.clamp(0.0, 1.0)),
      );
      paint(canvas, pose.heave, pose.effort);
      canvas.restore();
    } else {
      paint(canvas, pose.heave, pose.effort);
    }
    canvas.restore();
  }

  /// 승부가 이미 결정된 동안(낙하 중/낙하 직후 홀드/최종 승리 축하 연출)에는
  /// 이긴 쪽 자세 계산에 쓰는 strength를 0으로 죽인다. 그렇지 않으면 승리를
  /// 확정짓는 마지막 순간의 (거의 최대치인) 힘 값이 그대로 얼어붙어, 이긴
  /// 쪽이 계속 "온 힘을 다해 안간힘 쓰는" 극단적인 포즈(프레임4)로 멈춰
  /// 있게 되고 — 그 포즈에서는 실측 그립 비율이 딱 맞지 않아 로프 끝이
  /// 손에서 벗어나 보인다. 승부가 끝났으니 이긴 쪽은 차분한 자세(프레임1에
  /// 가까움, 그립 정렬이 가장 잘 맞는 포즈)로 쉬는 게 자연스럽기도 하다.
  double _poseStrength(double raw) =>
      (_isFalling || _postFallHold || _celebrating) ? 0.0 : raw;

  /// 파이터의 자세(젖힘/낙하 기울임/흔들림/스케일/힘씀 정도)를 계산한다.
  /// _drawFighter가 실제로 그릴 때, _handWorldPos가 로프 손 위치를 미리
  /// 계산할 때 둘 다 이 함수를 써서 — 두 계산이 항상 정확히 일치한다.
  ({double dy, double lean, double scale, double alpha, double heave, double effort})
      _computeFighterPose({
    required int facing,
    required bool falling,
    required double strength,
    required double cadence,
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
        // 캐릭터 자체는 안 보이지만(alpha=0), 로프 손 앵커는 이 pose를 계속
        // 참조한다(_handWorldPos). 여기서 dy/scale을 안 채우면 기본값(0,
        // 1.0=평소 서 있는 자세)으로 되돌아가 버려서, 착지 단계(p>=0.8)로
        // 넘어가는 순간 로프가 "평소 손 위치"로 순간이동한 것처럼 위로
        // 튀어 오르는 버그가 있었다. p=0.8 시점의 최종값(다 가라앉고 다
        // 줄어든 상태)을 그대로 이어받아야 로프가 계속 가라앉은 채로 있다.
        dy = 12 + 96 * 4;
        scale = 0.25;
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

    return (dy: dy, lean: lean, scale: scale, alpha: alpha, heave: heave, effort: effort);
  }

  /// 로프가 잡는 손의 월드 좌표. _drawFighter가 캐릭터를 그릴 때 적용하는
  /// 변환(translate → rotate(lean) → scale)을 로컬 그립 포인트에 그대로
  /// 적용해서 구한다 — 그래서 안간힘으로 뒤로 젖혀지거나 낙하로 기울어져도
  /// 로프가 항상 정확히 손 위치에서 시작한다.
  Offset _handWorldPos({
    required Offset center,
    required int facing,
    required bool falling,
    required double strength,
    required double cadence,
    List<ui.Image>? frames,
    double? scale,
    double? fracX,
    double? fracY,
  }) {
    final pose = _computeFighterPose(
        facing: facing, falling: falling, strength: strength, cadence: cadence);

    Offset local;
    if (frames != null &&
        frames.isNotEmpty &&
        scale != null &&
        fracX != null &&
        fracY != null) {
      final img = frames[_frameIndex(pose.effort)];
      local = _spriteGripLocal(img, scale, fracX, fracY);
    } else {
      local = const Offset(23, -6); // 절차적 그래픽용 기존 고정 앵커
    }

    // canvas.scale(facing*scale, scale) 다음 canvas.rotate(lean*facing) 순서를
    // 그대로 재현 (역순으로 적용하면 결과가 달라지므로 순서 주의).
    final sx = local.dx * facing * pose.scale;
    final sy = local.dy * pose.scale;
    final theta = pose.lean * facing;
    final cosT = cos(theta), sinT = sin(theta);
    final rx = sx * cosT - sy * sinT;
    final ry = sx * sinT + sy * cosT;
    return Offset(center.dx + rx, center.dy + pose.dy + ry);
  }

  /// 스프라이트 캐릭터의 그립(맞잡은 손) 로컬 좌표. 발이 지면(로컬 y=48,
  /// _drawFighter의 발밑 그림자와 같은 높이)에 닿도록 이미지를 배치했을 때,
  /// handFracX/Y 비율에 해당하는 이미지 내부 지점이 로컬 공간 어디에 오는지
  /// 계산한다. _drawSpriteFighter의 배치 방식과 반드시 일치해야 한다.
  Offset _spriteGripLocal(
      ui.Image img, double scale, double handFracX, double handFracY) {
    final w = img.width * scale;
    final h = img.height * scale;
    const groundY = 48.0;
    final left = -w / 2;
    final top = groundY - h;
    return Offset(left + w * handFracX, top + h * handFracY);
  }

  /// 현재 상대 동물의 스프라이트 자원(프레임/배율/그립 비율)을 반환한다.
  /// 스프라이트가 없으면(로드 실패) null — 이 경우 절차적 그래픽으로 대체.
  ({List<ui.Image> frames, double scale, double fracX, double fracY})?
      _opponentSpriteConfig() {
    switch (_currentAnimal) {
      case AnimalType.chimpanzee:
        if (_champFrames.isEmpty) return null;
        return (
          frames: _champFrames,
          scale: _champSpriteScale,
          fracX: _champHandFracX,
          fracY: _champHandFracY,
        );
      case AnimalType.orangutan:
        if (_orFrames.isEmpty) return null;
        return (
          frames: _orFrames,
          scale: _orSpriteScale,
          fracX: _orHandFracX,
          fracY: _orHandFracY,
        );
      case AnimalType.gorilla:
        if (_gorFrames.isEmpty) return null;
        return (
          frames: _gorFrames,
          scale: _gorSpriteScale,
          fracX: _gorHandFracX,
          fracY: _gorHandFracY,
        );
    }
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

  /// 효과 강도(effort, 0~1)를 4단계 프레임 인덱스(0~3)로 변환한다. 숫자가
  /// 클수록(=player/champ 4.png) 더 세게 힘을 쓰는 자세.
  int _frameIndex(double effort) => (effort * 4).floor().clamp(0, 3);

  /// 실사 스프라이트 한 프레임을 그린다. 발이 지면(로컬 y=48, 발밑 그림자와
  /// 같은 높이)에 닿도록 배치하고, 고정 배율(scale, 1번 프레임 기준으로 한
  /// 번만 계산됨)을 그대로 써서 포즈가 바뀌어도 캐릭터 크기가 흔들리지
  /// 않는다. 스프라이트는 항상 오른쪽(로프)을 보도록 제작되어 있어,
  /// _drawFighter가 이미 적용한 facing 반전을 그대로 물려받는다.
  void _drawSpriteFighter(Canvas c, ui.Image img, double scale, double effort) {
    final w = img.width * scale;
    final h = img.height * scale;
    const groundY = 48.0;
    final dst = Rect.fromLTWH(-w / 2, groundY - h, w, h);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    c.drawImageRect(
        img, src, dst, Paint()..filterQuality = FilterQuality.medium);
    _strainFx(c, effort);
  }

  /// 플레이어 — 스프라이트가 로드됐으면 effort에 맞는 실사 프레임을, 아니면
  /// 기존 절차적 그래픽(_paintHuman)을 대신 그린다.
  void _paintPlayer(Canvas c, double heave, double effort) {
    if (_playerFrames.isEmpty) {
      _paintHuman(c, heave, effort);
      return;
    }
    _drawSpriteFighter(
        c, _playerFrames[_frameIndex(effort)], _playerSpriteScale, effort);
  }

  /// 사람(플레이어) 절차적 그래픽 — player 1~4.png 로드 실패 시 대체용.
  /// 오른쪽(로프)을 향해 두 팔을 뻗어 버티는 자세.
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

  /// 상대 동물 — 스프라이트가 있으면 effort에 맞는 실사 프레임을, 없으면
  /// 절차적 그래픽을 그린다.
  void _paintAnimal(Canvas c, double heave, double effort) {
    final cfg = _opponentSpriteConfig();
    if (cfg == null) {
      switch (_currentAnimal) {
        case AnimalType.chimpanzee:
          _paintChimp(c, heave, effort);
        case AnimalType.orangutan:
          _paintOrangutan(c, heave, effort);
        case AnimalType.gorilla:
          _paintGorilla(c, heave, effort);
      }
      return;
    }
    _drawSpriteFighter(c, cfg.frames[_frameIndex(effort)], cfg.scale, effort);
  }

  /// 침팬지 절차적 그래픽 — champ 1~4.png 로드 실패 시 대체용. 작고 웅크린
  /// 체형, 긴 팔, 큰 귀. 빠르고 불규칙하게 당긴다.
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

  void _drawParticles(Canvas canvas) {
    for (final p in _particles) {
      final a = p.life.clamp(0.0, 1.0);
      final img = p.image;
      if (img != null) {
        // 스프라이트 파티클(물보라 조각/색종이 조각) — 크기는 고정, 투명도만
        // life에 따라 줄어든다. srcRect가 있으면 시트에서 그 영역만 자른다.
        final src = p.srcRect ??
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final targetW = p.radius * 2 * p.scale;
        final targetH = targetW * (src.height / src.width);
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.angle);
        canvas.drawImageRect(
          img,
          src,
          Rect.fromCenter(center: Offset.zero, width: targetW, height: targetH),
          Paint()
            ..color = Colors.white.withValues(alpha: a)
            ..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        continue;
      }

      final paint = Paint()..color = p.color.withValues(alpha: a);
      if (p.sparkle) {
        // 네 꼭짓점 별 모양 — 짧은 십자형 반짝임. 중심에 작은 밝은 코어를
        // 더해 반짝이는 느낌을 강조한다.
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.angle);
        final r = p.radius * a;
        final star = Path();
        for (int k = 0; k < 4; k++) {
          final outerA = k * pi / 2;
          final innerA = outerA + pi / 4;
          final op = Offset(cos(outerA) * r, sin(outerA) * r);
          final ip = Offset(cos(innerA) * r * 0.35, sin(innerA) * r * 0.35);
          if (k == 0) {
            star.moveTo(op.dx, op.dy);
          } else {
            star.lineTo(op.dx, op.dy);
          }
          star.lineTo(ip.dx, ip.dy);
        }
        star.close();
        canvas.drawPath(star, paint);
        canvas.drawCircle(Offset.zero, r * 0.28,
            Paint()..color = Colors.white.withValues(alpha: a));
        canvas.restore();
      } else if (p.rect) {
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.angle);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.radius * 2.4, height: p.radius * 1.4),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(p.x, p.y), p.radius * a, paint);
      }
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

    // 점수: 반복/버티기로 쌓은 노력(_pullCount) + 이긴 라운드 수 보너스, 100점 상한.
    final score =
        (_pullCount * 6 + _playerRoundWins * 20).clamp(0, 100);

    final result = GameResult(
      gameId: 'tug_of_war',
      score: score,
      maxPossibleScore: 100,
      accuracy: won ? 1.0 : 0.0,
      duration: Duration(milliseconds: (_matchElapsedSeconds * 1000).round()),
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: _pullCount,
      misses: _animalRoundWins,
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

  /// 힘 생성 방식 — 게임 시작 전 설정 화면에서 선택한다.
  final TugMode mode;

  const TugOfWarGame({
    super.key,
    required this.bluetoothService,
    required this.config,
    this.mode = TugMode.cycle,
  });

  @override
  State<TugOfWarGame> createState() => _TugOfWarGameState();
}

class _TugOfWarGameState extends State<TugOfWarGame> {
  late TugOfWarFlameGame _game;
  late GameMotorController _motor;
  Timer? _resistanceSync;

  /// hold 모드에서 슬라이더를 왼쪽(폄/0.0)으로 자동으로 되돌리는 타이머.
  Timer? _holdReturn;
  static const double _holdReturnRate = 0.55; // 초당 되돌아가는 양 (약 1.8초에 1.0→0)

  double _simValue = 0.5;
  bool _isSim = false;
  late TugMode _mode;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);
    _mode = widget.mode; // 설정 화면에서 선택 (반복 당기기 / 버티기)

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
      mode: _mode,
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

    if (_mode == TugMode.hold) {
      _simValue = 0.0; // 버티기 모드: 슬라이더는 왼쪽(폄)에서 시작
      _game.setSimPosition(0.0);
    }

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

    // 버티기 모드 + 시뮬레이터: 슬라이더를 조금씩 왼쪽으로 되돌린다. 플레이어가
    // 계속 오른쪽으로 끌어올려 자세를 유지해야 로프가 버틴다. (모터 연결 시엔
    // 실제 등장성 저항이 이 역할을 하므로 불필요.)
    const tick = Duration(milliseconds: 32);
    _holdReturn = Timer.periodic(tick, (_) {
      if (_mode != TugMode.hold || !_isSim) return;
      if (!_game.isRunning || _game.isCountingDown || _game.isFalling) return;
      final next =
          (_simValue - _holdReturnRate * tick.inMilliseconds / 1000)
              .clamp(0.0, 1.0);
      if (next != _simValue) {
        setState(() => _simValue = next);
        _game.setSimPosition(next);
      }
    });
  }

  @override
  void dispose() {
    _resistanceSync?.cancel();
    _holdReturn?.cancel();
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
    final hold = _mode == TugMode.hold;
    return Container(
      color: const Color(0xFF1B2A32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: [
        Icon(hold ? Icons.keyboard_double_arrow_left : Icons.arrow_back,
            color: hold ? Colors.redAccent : Colors.white54),
        Expanded(
          child: Slider(
            value: _simValue,
            // 버티기 모드: 슬라이더가 계속 왼쪽으로 되돌아가므로 오른쪽으로
            // 끌어올려 자세를 유지해야 한다.
            activeColor: hold ? Colors.greenAccent : null,
            onChanged: (v) {
              setState(() => _simValue = v);
              _game.setSimPosition(v);
            },
          ),
        ),
        Icon(Icons.arrow_forward, color: hold ? Colors.greenAccent : Colors.white54),
      ]),
    );
  }
}
