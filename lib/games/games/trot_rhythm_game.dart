import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bluetooth.dart';
import '../game_base.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';

// ============================================================================
// [E4] 트로트 콘서트 응원 게임 (Trot Concert Cheer)
// 관절: 오른쪽 어깨 굽힘/폄 (rShoulderEF) — PART 코드는 허브가 넘기는 config.bodyPart를 쓴다.
// 메카닉: 응원단장의 응원봉 동작을 따라하기 (천천히 넓게 → 빠르게 좁게)
// 씬: 가수(무대) + 응원단장(중앙) + 관객(좌우) + 플레이어(하단 중앙)
// Phase 1: 스프라이트 없이 Canvas 도형으로 구현
// ============================================================================

// ─── 큐(Cue) — 응원단장의 동작 지시 ────────────────────────────────────────────

enum _Judgment { perfect, good, miss }

// 비트맵 큐 — 절대 곡 시각(time)에 목표각(targetAngle)에 도달/판정. 오디오 동기.
class _Cue {
  final double time;         // 곡 절대 시각(초)
  final double targetAngle;  // 목표 각도 (로드 시 교대 지정)
  bool judged = false;
  _Cue({required this.time, required this.targetAngle});
}

// ─── 팔 리그 파라미터 (tools/trot_arm_tuner.py 에서 확정) ──────────────────────
class _RigParams {
  final double bx, by, bscale;
  final double bsx, bsy, uSx, uSy, uEx, uEy, fEx, fEy, fWx, fWy;
  final double armScale, shExtDeg, shFlexDeg, elExtDeg, elFlexDeg;
  final bool flip;
  const _RigParams({
    required this.bx, required this.by, required this.bscale,
    required this.bsx, required this.bsy,
    required this.uSx, required this.uSy, required this.uEx, required this.uEy,
    required this.fEx, required this.fEy, required this.fWx, required this.fWy,
    required this.armScale, required this.shExtDeg, required this.shFlexDeg,
    required this.elExtDeg, required this.elFlexDeg, required this.flip,
  });
}

// ─── FlameGame 본체 ─────────────────────────────────────────────────────────────

class TrotRhythmFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  // 오디오
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioReady = false;
  final Map<String, AudioPlayer> _sfxPlayers = {};

  // SFX 로드 헬퍼
  Future<void> _loadSfx(String name, String path) async {
    try {
      final p = AudioPlayer();
      await p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      ));
      await p.setSource(AssetSource(path));
      _sfxPlayers[name] = p;
    } catch (e) {
      debugPrint('SFX Load error ($name): $e');
    }
  }

  void _playSfx(String name, {double volume = 1.0}) {
    final p = _sfxPlayers[name];
    if (p != null) {
      p.setVolume(volume);
      p.stop().then((_) => p.resume());
    }
  }

  // 스프라이트 (없으면 null → 절차적 렌더로 fallback). 관객 제거.
  ui.Image? _imgBg, _imgSinger, _imgBodyLeader, _imgBodyPlayer;
  ui.Image? _imgBodyLeaderFail, _imgBodyPlayerFail; // 실패(Miss) 시 몸통
  double _failTimer = 0.0;          // >0이면 실패 몸통 표시
  // 팔 리그 — 인물별 위팔/아래팔 분리 이미지 (아래팔에 손+봉 포함)
  ui.Image? _imgLeaderArmUpper, _imgLeaderArmFore;
  ui.Image? _imgPlayerArmUpper, _imgPlayerArmFore;
  ui.Image? _imgSingerMouthOpen, _imgSingerEyesClosed; // 가수 표정 오버레이

  Future<ui.Image?> _tryLoadImage(String name) async {
    try {
      return await images.load('trot_rhythm/$name');
    } catch (e) {
      debugPrint('Trot sprite missing ($name): $e');
      return null;
    }
  }

  // 응원단장 상태
  double _leaderAngle = 0.5;       // 현재 각도 (오디오 기반 보간)

  // 플레이어 상태 (BT 또는 슬라이더)
  double _playerAngle = 0.5;

  // 큐 시퀀스 (오디오 절대 시각 기반)
  late List<_Cue> _cues;
  int _cueIndex = 0;              // 다음 판정할 큐 인덱스
  double _songTime = 0.0;         // 오디오 재생 위치(초)
  double _globalTimer = 0.0;
  StreamSubscription<Duration>? _posSub; // 오디오 위치 구독


  // 판정 팝업
  _Judgment? _lastJudgment;
  double _judgmentAlpha = 0.0;
  double _judgmentY = 0.0;

  // 점수
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _hits = 0;
  int _misses = 0;
  int _lifeCount = 5;
  double _crowdEnergy = 0.3;
  bool _isRunning = false;
  double _elapsed = 0.0;

  // 카운트다운
  bool _isCountingDown = true;
  double _countdown = 3.0;

  // 피버 모드
  bool get _isFever => _combo >= 10;

  // TextPaint
  late TextPaint _tpCombo;

  // BT 구독
  StreamSubscription<double>? _sub;

  // ─── 레이아웃 (size 사용 가능 후) ──────────────────────────────────────────
  // 세 인물 가로 배치: 플레이어(왼쪽) — 응원단장(중앙) — 가수(오른쪽)
  // 가수 위치/크기 (튜너 확정값)
  double tuneSingerX = 0.745, tuneSingerY = 0.354, tuneSingerScale = 0.42;

  // 가사 (곡 시각, 텍스트) — 플레이스홀더. 실제 가사·타이밍 확보 시 교체. "달리자"는 크게 렌더.
  static const List<(double, String)> _lyricLines = [
    (14.57, '아침부터 꼬인 일들 많아도'),
    (17.79, '그럴 수도 있지, 웃고 넘겨'),
    (21.24, '식은 커피 한 모금 삼키면서'),
    (24.05, '오늘도 나는 발을 뗀다'),
    (27.6, '쉽지 않아도 괜찮아'),
    (30.72, '서둘 필요도 없어'),
    (34.38, '한 번 더 숨을 고르고'),
    (37.23, '다시 한 걸음 가보자'),
    (41.58, '오늘은 달리자, 오늘은 달리자'),
    (45.09, '지친 마음도 다시 뛰게'),
    (49.05, '한 번 더 가고, 한 번 더 웃고'),
    (52.37, '지금이 바로 그 순간이야'),
    (54.98, '오늘은 달리자, 오늘은 달리자'),
    (58.32, '어제는 뒤에 놓아두고'),
    (62.81, '다시 한번 발맞춰 가자'),
    (66.06, '오늘이 다시 시작이야'),
    (70.15, ''),
    (83.56, '밤이 깊어질수록 조용해져도'),
    (87.07, '마음만은 더 작아지지 않게'),
    (90.84, '넘어졌던 그 자리까지도'),
    (93.29, '지금의 나를 만든 거라 믿어'),
    (96.98, '세상이 날 몰라줘도'),
    (100.24, '나는 나를 안다'),
    (103.7, '천천히 가도 괜찮아'),
    (106.64, '끝까지 가면 되는 거야'),
    (110.96, '오늘은 달리자, 오늘은 달리자'),
    (114.25, '지친 마음도 다시 뛰게'),
    (118.48, '한 번 더 가고, 한 번 더 웃고'),
    (121.64, '지금이 바로 그 순간이야'),
    (124.4, '오늘은 달리자, 오늘은 달리자'),
    (127.72, '어제는 뒤에 놓아두고'),
    (132.12, '다시 한번 발맞춰 가자'),
    (135.32, '오늘이 다시 시작이야'),
    (139.4, '버텨온 날들이 결국 나를 만들고'),
    (145.93, '아팠던 시간까지도'),
    (149.19, '내 노래가 될 테니까'),
    (154.91, '오늘은 달리자, 오늘은 달리자'),
    (158.36, '가슴속에 불을 다시 켜'),
    (162.23, '한 번 더 뛰고, 한 번 더 서고'),
    (165.6, '나는 끝내 해내는 사람'),
    (168.17, '오늘은 달리자, 오늘은 달리자'),
    (171.6, '이제는 내가 나를 믿어'),
    (176.04, '다시 한번 크게 불러'),
    (179.43, '오늘이 진짜 시작이야'),
    (188.88, ''),
  ];
  // 응원단장/플레이어 = 리그 파라미터 (tools/trot_arm_tuner.py 확정)
  static const _RigParams _leaderRig = _RigParams(
    bx: 0.397, by: 0.477, bscale: 0.553, bsx: 0.581, bsy: 0.34,
    uSx: 0.492, uSy: 0.936, uEx: 0.484, uEy: 0.078,
    fEx: 0.495, fEy: 0.95, fWx: 0.495, fWy: 0.128,
    armScale: 0.109, shExtDeg: 0.0, shFlexDeg: 180.0,
    elExtDeg: 0.0, elFlexDeg: -140.0, flip: false);
  static const _RigParams _playerRig = _RigParams(
    bx: 0.141, by: 0.489, bscale: 0.556, bsx: 0.646, bsy: 0.256,
    uSx: 0.496, uSy: 0.939, uEx: 0.504, uEy: 0.089,
    fEx: 0.516, fEy: 0.958, fWx: 0.516, fWy: 0.114,
    armScale: 0.109, shExtDeg: 0.0, shFlexDeg: 180.0,
    elExtDeg: 0.0, elFlexDeg: -140.0, flip: false);

  double get _singerX => size.x * tuneSingerX;

  // 판정 허용 범위 (normalized 기준)
  double get _perfectTol => (0.12 - config.difficultyLevel * 0.01).clamp(0.06, 0.12);
  double get _goodTol    => (0.22 - config.difficultyLevel * 0.01).clamp(0.12, 0.22);


  TrotRhythmFlameGame({
    required this.inputStream,
    required this.config,
    required this.onGameEnd,
  });

  @override
  Color backgroundColor() => const Color(0xFF120824); // 콘서트 홀 딥 퍼플

  @override
  Future<void> onLoad() async {
    // 1. 박자 맵 JSON 로드 시도 (실패 시 난이도별 절차적 생성으로 fallback)
    try {
      final jsonStr = await rootBundle.loadString('assets/maps/trot_map_01.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final raw = data['cues'] as List<dynamic>;
      final maxTier = config.difficultyLevel.clamp(1, 5); // 난이도=밀도(tier)
      final times = <double>[
        for (final c in raw)
          if (((c['tier'] as num?)?.toInt() ?? 1) <= maxTier)
            (c['time'] as num).toDouble()
      ]..sort();
      _cues = _buildCues(times);
    } catch (e) {
      debugPrint('Fallback to procedural cues: $e');
      _cues = _buildCues(_fallbackBeatTimes());
    }


    _tpCombo = TextPaint(style: const TextStyle(
      fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFF87CEEB),
      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
    ));

    // 2. 신규 트로트 음원(오늘은 달리자.mp3) 로드
    try {
      await _audioPlayer.setSource(
          AssetSource('audio/trot_rhythm/오늘은 달리자.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _audioReady = true;
    } catch (e) {
      debugPrint('Trot BGM load error: $e');
    }
    // 오디오 실제 위치 → _songTime 드리프트 보정 (재생은 카운트다운 후 시작)
    _posSub = _audioPlayer.onPositionChanged.listen((d) {
      final p = d.inMilliseconds / 1000.0;
      if ((p - _songTime).abs() > 0.15) _songTime = p;
    });

    // 3. SFX 효과음 로드
    await Future.wait([
      _loadSfx('hit_perfect', 'audio/trot_rhythm/hit_perfect.ogg'),
      _loadSfx('hit_good', 'audio/trot_rhythm/hit_good.ogg'),
      _loadSfx('hit_miss', 'audio/trot_rhythm/hit_miss.ogg'),
      _loadSfx('fever_fanfare', 'audio/trot_rhythm/fever_fanfare.ogg'),
    ]);

    // 4. 스프라이트 로드 (없는 파일은 null → 절차적 렌더 fallback)
    final imgs = await Future.wait([
      _tryLoadImage('bg_trot_stage_mono.png'),
      _tryLoadImage('singer_avatar.png'),
      _tryLoadImage('body_leader.png'),
      _tryLoadImage('body_player.png'),
      _tryLoadImage('leader_arm_upper.png'),
      _tryLoadImage('leader_arm_fore.png'),
      _tryLoadImage('player_arm_upper.png'),
      _tryLoadImage('player_arm_fore.png'),
      _tryLoadImage('singer_mouth_open.png'),
      _tryLoadImage('singer_eyes_closed.png'),
      _tryLoadImage('body_leader_fail.png'),
      _tryLoadImage('body_player_fail.png'),
    ]);
    _imgBodyLeaderFail = imgs[10];
    _imgBodyPlayerFail = imgs[11];
    _imgBg = imgs[0];
    _imgSinger = imgs[1];
    _imgBodyLeader = imgs[2];
    _imgBodyPlayer = imgs[3];
    _imgLeaderArmUpper = imgs[4];
    _imgLeaderArmFore = imgs[5];
    _imgPlayerArmUpper = imgs[6];
    _imgPlayerArmFore = imgs[7];
    _imgSingerMouthOpen = imgs[8];
    _imgSingerEyesClosed = imgs[9];

    _sub = inputStream?.listen((v) => _playerAngle = v.clamp(0.0, 1.0));
  }

  // 시각 리스트 → 큐. 짝수=폄쪽/홀수=굽힘쪽으로 교대하되, 진폭(범위)을 쌍 단위로 순환해 변화.
  static const List<List<double>> _ampPairs = [
    [0.05, 0.95], // 큰 스윙
    [0.20, 0.85],
    [0.10, 0.65], // 작은~중간
    [0.35, 0.95],
    [0.15, 0.75],
    [0.05, 0.55], // 아래쪽 위주
  ];
  List<_Cue> _buildCues(List<double> times) {
    final out = <_Cue>[];
    for (int i = 0; i < times.length; i++) {
      final pair = _ampPairs[(i ~/ 2) % _ampPairs.length];
      out.add(_Cue(time: times[i], targetAngle: i.isEven ? pair[0] : pair[1]));
    }
    return out;
  }

  // 맵 로드 실패 시 폴백: 136 BPM 기반, 난이도로 간격 조절
  List<double> _fallbackBeatTimes() {
    const beat = 60.0 / 136.0;
    final step = beat * (6 - config.difficultyLevel).clamp(1, 5);
    final out = <double>[];
    for (double t = 2.0; t < 190.0; t += step) {
      out.add(double.parse(t.toStringAsFixed(3)));
    }
    return out;
  }


  // ─── 업데이트 ─────────────────────────────────────────────────────────────

  void setPlayerAngle(double v) => _playerAngle = v.clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);

    // 카운트다운
    if (_isCountingDown) {
      _globalTimer += dt; // 배경은 살아있게
      _countdown -= dt;
      if (_countdown <= 0) {
        _isCountingDown = false;
        _isRunning = true;
        _songTime = 0.0;
        if (_audioReady) _audioPlayer.resume();
      }
      return;
    }

    if (!_isRunning) return;

    _elapsed += dt;
    _globalTimer += dt;
    _songTime += dt; // 스무딩 — onPositionChanged가 드리프트 보정
    if (_failTimer > 0) _failTimer -= dt;

    _updateCue();
    _updateCrowdEnergy(dt);

    if (_judgmentAlpha > 0) {
      _judgmentAlpha -= dt * 1.6;
      _judgmentY -= 38 * dt;
    }
  }

  void _updateCue() {
    if (_cues.isEmpty) return;
    final n = _cues.length;

    // 리더 보간: _songTime 기준 [이전 큐 → 다음 큐]로 이동해 다음 큐 시각에 목표 도달.
    final double prevT, prevA, nextT, nextA;
    if (_cueIndex <= 0) {
      prevT = 0.0; prevA = 0.5;
    } else {
      prevT = _cues[_cueIndex - 1].time; prevA = _cues[_cueIndex - 1].targetAngle;
    }
    if (_cueIndex < n) {
      nextT = _cues[_cueIndex].time; nextA = _cues[_cueIndex].targetAngle;
    } else {
      nextT = prevT + 1.0; nextA = prevA;
    }
    final span = nextT - prevT;
    final t = span > 0 ? ((_songTime - prevT) / span).clamp(0.0, 1.0) : 1.0;
    _leaderAngle = prevA + (nextA - prevA) * _easeInOut(t);

    // 판정: _songTime이 큐 시각을 지나면 그 순간 플레이어 각도로 판정(비트 동기).
    while (_cueIndex < n && _songTime >= _cues[_cueIndex].time) {
      final cue = _cues[_cueIndex];
      if (!cue.judged) {
        cue.judged = true;
        final diff = (_playerAngle - cue.targetAngle).abs();
        if (diff < _perfectTol) {
          _onPerfect();
        } else if (diff < _goodTol) {
          _onGood();
        } else {
          _onMiss();
        }
      }
      _cueIndex++;
    }

    if (_cueIndex >= n && _isRunning) _endGame();
  }

  void _updateCrowdEnergy(double dt) {
    final target = (_combo / 10.0).clamp(0.2, 1.0);
    _crowdEnergy += (target - _crowdEnergy) * dt * 0.4;
  }

  double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  // ─── 판정 ────────────────────────────────────────────────────────────────

  void _onPerfect() {
    _score += 100 * (1 + _combo ~/ 5);
    _combo++;
    _hits++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    if (_combo == 10) {
      _playSfx('fever_fanfare', volume: 1.0);
    } else {
      _playSfx('hit_perfect', volume: 1.0);
    }
    _triggerPopup(_Judgment.perfect);
  }

  void _onGood() {
    _score += 50;
    _combo++;
    _hits++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    if (_combo == 10) {
      _playSfx('fever_fanfare', volume: 1.0);
    } else {
      _playSfx('hit_good', volume: 0.9);
    }
    _triggerPopup(_Judgment.good);
  }

  void _onMiss() {
    _failTimer = 0.8; // 실패 몸통 표시
    _combo = 0;
    _misses++;
    _lifeCount = (_lifeCount - 1).clamp(0, 5);
    _playSfx('hit_miss', volume: 0.8);
    _triggerPopup(_Judgment.miss);
    if (_lifeCount <= 0) _endGame();
  }

  void _triggerPopup(_Judgment j) {
    _lastJudgment = j;
    _judgmentAlpha = 1.0;
    _judgmentY = size.y * 0.48;
  }

  void _endGame() {
    if (!_isRunning) return;
    _isRunning = false;
    _audioPlayer.stop();

    onGameEnd(GameResult(
      gameId: 'E4',
      score: _score,
      maxPossibleScore: _cues.length * 100,
      accuracy: _cues.isNotEmpty ? _hits / _cues.length : 0.0,
      duration: Duration(seconds: _elapsed.round()),
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: _hits,
      misses: _misses,
    ));
  }

  // ─── 렌더 ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_isFever) _renderFeverBg(canvas);
    _renderStage(canvas);
    _renderSinger(canvas);
    _renderLyric(canvas);
    _renderLeader(canvas);
    _renderPlayer(canvas);
    _renderHUD(canvas);
    if (_judgmentAlpha > 0) _renderJudgment(canvas);
    if (_isCountingDown) _renderCountdown(canvas);
  }

  // 피버 배경 펄스
  void _renderFeverBg(Canvas canvas) {
    final pulse = (sin(_globalTimer * 7) * 0.5 + 0.5) * 0.12;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFD4AF37).withValues(alpha: pulse));
    // 황금 테두리
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
  }

  // 카운트다운 오버레이
  void _renderCountdown(Canvas canvas) {
    // 반투명 어둠
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.black.withValues(alpha: 0.45));

    final n = _countdown.ceil().clamp(1, 3);
    final scale = 1.0 + (_countdown - _countdown.floorToDouble()) * 0.3;
    final fs = 120.0 * scale;
    TextPaint(style: TextStyle(
      fontSize: fs, fontWeight: FontWeight.bold,
      color: const Color(0xFFD4AF37),
      shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
    )).render(canvas, '$n', Vector2(size.x / 2 - fs * 0.3, size.y / 2 - fs * 0.6));

    TextPaint(style: const TextStyle(
      fontSize: 26, color: Colors.white70,
    )).render(canvas, '준비하세요!', Vector2(size.x / 2 - 70, size.y / 2 + 60));
  }

  // 배경 — mono 무대 이미지 (없으면 회색 fallback)
  void _renderStage(Canvas canvas) {
    if (_imgBg != null) {
      canvas.drawImageRect(
        _imgBg!,
        Rect.fromLTWH(0, 0, _imgBg!.width.toDouble(), _imgBg!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint(),
      );
      return;
    }
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF707070), Color(0xFF3C3C3C)],
      ).createShader(rect));
  }

  // 가수 (오른쪽)
  void _renderSinger(Canvas canvas) {
    final cx = _singerX;
    final cy = size.y * tuneSingerY;

    if (_imgSinger != null) {
      final h = size.y * tuneSingerScale;
      final w = _imgSinger!.width.toDouble() * (h / _imgSinger!.height.toDouble());
      final dst = Rect.fromLTWH(cx - w / 2, cy - h * 0.30, w, h);
      // 베이스 얼굴 (입 다뭄 · 눈 뜸)
      _drawFullImage(canvas, _imgSinger!, dst);
      // 입 벌림 오버레이 — 가사가 나오는 동안만 노래하듯 열림
      if (_imgSingerMouthOpen != null && _currentLyric() != null &&
          sin(_globalTimer * 9) > 0.0) {
        _drawFullImage(canvas, _imgSingerMouthOpen!, dst);
      }
      // 눈 감음 오버레이 — 약 3.5초마다 0.12초 깜빡임
      if (_imgSingerEyesClosed != null && (_globalTimer % 3.5) < 0.12) {
        _drawFullImage(canvas, _imgSingerEyesClosed!, dst);
      }
    } else {
      // 몸 (흰 슈트)
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 26), width: 38, height: 58),
          Paint()..color = const Color(0xFFF5F0E8));
      // 머리
      canvas.drawCircle(Offset(cx, cy), 19, Paint()..color = const Color(0xFFFFDBAC));
      // 마이크 (왼쪽으로 — 관중 향해)
      canvas.drawLine(Offset(cx - 12, cy + 4), Offset(cx - 26, cy - 16),
          Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(cx - 26, cy - 16), 6, Paint()..color = const Color(0xFFD4AF37));
    }
    // 이름표
  }

  // 팔 리그 — 튜너(tools/trot_arm_tuner.py)의 pivot·해부학 모델과 동일.
  // n: 0=폄끝(shExt), 1=굽힘끝(shFlex). 위팔·아래팔 분리 이미지, 어깨/팔꿈치 각도 독립.
  void _drawArm(Canvas canvas, _RigParams p, ui.Image bodyImg, double cx, double cy,
      ui.Image? upperImg, ui.Image? foreImg, double n, double opacity) {
    final bh = size.y * p.bscale;
    final bw = bodyImg.width.toDouble() * (bh / bodyImg.height.toDouble());
    final bleft = cx - 2 - bw / 2, btop = cy - bh * 0.30;
    final sx = bleft + p.bsx * bw, sy = btop + p.bsy * bh;   // 어깨 관절 화면좌표
    final s = p.armScale * size.y / 800.0;                    // 튜너 H=800 기준 → 해상도 독립

    final anatSh = p.shExtDeg + n * (p.shFlexDeg - p.shExtDeg);
    final uDir = _deg2rad(90 + (p.flip ? 1 : -1) * anatSh);
    double ex = sx, ey = sy;                                  // 팔꿈치
    if (upperImg != null) {
      final uw = upperImg.width.toDouble() * s, uh = upperImg.height.toDouble() * s;
      final usx = p.uSx * uw, usy = p.uSy * uh, uex = p.uEx * uw, uey = p.uEy * uh;
      final dx = p.flip ? -(uex - usx) : (uex - usx);
      final d0 = atan2(uey - usy, dx);
      _drawImgPivot(canvas, upperImg, p.uSx, p.uSy, sx, sy, s, uDir - d0, p.flip, opacity);
      final l = sqrt((uex - usx) * (uex - usx) + (uey - usy) * (uey - usy));
      ex = sx + cos(uDir) * l; ey = sy + sin(uDir) * l;
    }
    final anatEl = p.elExtDeg + n * (p.elFlexDeg - p.elExtDeg);
    final fDir = uDir + _deg2rad((p.flip ? -1 : 1) * anatEl);
    if (foreImg != null) {
      final fw = foreImg.width.toDouble() * s, fh = foreImg.height.toDouble() * s;
      final fex = p.fEx * fw, fey = p.fEy * fh, fwx = p.fWx * fw, fwy = p.fWy * fh;
      final fdx = p.flip ? -(fwx - fex) : (fwx - fex);
      final d0f = atan2(fwy - fey, fdx);
      _drawImgPivot(canvas, foreImg, p.fEx, p.fEy, ex, ey, s, fDir - d0f, p.flip, opacity);
    }
  }

  double _deg2rad(double d) => d * pi / 180.0;

  // 이미지를 정규화 피벗(pnx,pny) 기준으로 (tx,ty)에 배치 + contentRot 회전 + 옵션 좌우반전.
  void _drawImgPivot(Canvas canvas, ui.Image img, double pnx, double pny,
      double tx, double ty, double scale, double contentRot, bool flip, double opacity) {
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final w = iw * scale, h = ih * scale;
    canvas.save();
    canvas.translate(tx, ty);
    canvas.rotate(contentRot);
    if (flip) canvas.scale(-1, 1);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH(-pnx * w, -pny * h, w, h),
      Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  // 이미지 1장을 지정 사각형에 그리기 (오버레이는 같은 dst로 정합성 자동 유지).
  void _drawFullImage(Canvas canvas, ui.Image img, Rect dst) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint(),
    );
  }

  // 몸통+머리 스프라이트(팔 없음)를 인물 중심(cx,cy)에 배치. 에셋 상단=머리.
  void _drawBody(Canvas canvas, ui.Image img, double cx, double cy, double scale) {
    final h = size.y * scale;
    final w = img.width.toDouble() * (h / img.height.toDouble());
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - 2 - w / 2, cy - h * 0.30, w, h),
      Paint(),
    );
  }

  // 현재 가사(시간 기반). 실제 가사/타이밍은 추후 교체.
  String? _currentLyric() {
    if (!_isRunning) return null;
    // 현재 줄을 '다음 항목(가사/지움마커) 시각'까지 표시. 빈 텍스트('')는 자막 지움.
    for (int i = _lyricLines.length - 1; i >= 0; i--) {
      final start = _lyricLines[i].$1;
      if (_songTime >= start) {
        final txt = _lyricLines[i].$2;
        if (txt.isEmpty) return null; // 지움 마커
        final end = (i + 1 < _lyricLines.length) ? _lyricLines[i + 1].$1 : start + 4.0;
        final visible = _songTime < end && (_songTime - start) < 8.0;
        return visible ? txt : null;
      }
    }
    return null;
  }

  // 가수 위 가사 — GriunPolSensibility 폰트, "달리자"는 크게.
  void _renderLyric(Canvas canvas) {
    final line = _currentLyric();
    if (line == null || line.isEmpty) return;
    const normal = TextStyle(
      fontFamily: 'GriunPolSensibility', fontSize: 34, color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
    );
    final spans = <InlineSpan>[];
    final parts = line.split('달리자');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i], style: normal));
      }
      if (i < parts.length - 1) {
        spans.add(const TextSpan(text: '달리자', style: TextStyle(
          fontFamily: 'GriunPolSensibility', fontSize: 62, color: Color(0xFFD4AF37),
          fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
        )));
      }
    }
    if (spans.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr, textAlign: TextAlign.center,
    )..layout();
    final singerTop = size.y * tuneSingerY - (size.y * tuneSingerScale) * 0.30;
    final x = _singerX - tp.width / 2;
    final y = (singerTop - tp.height - 14).clamp(4.0, size.y);
    tp.paint(canvas, Offset(x, y));
  }

  // 응원단장 (중앙)
  void _renderLeader(Canvas canvas) {
    const p = _leaderRig;
    final cx = size.x * p.bx, cy = size.y * p.by;

    if (_imgBodyLeader != null) {
      _drawBody(canvas, _imgBodyLeader!, cx, cy, p.bscale);
      if (_failTimer > 0 && _imgBodyLeaderFail != null) {
        _drawBody(canvas, _imgBodyLeaderFail!, cx, cy, p.bscale); // 얼굴만 오버레이
      }
      _drawArm(canvas, p, _imgBodyLeader!, cx, cy, _imgLeaderArmUpper, _imgLeaderArmFore, _leaderAngle, 1.0);
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - 2, cy + 22), width: 26, height: 52),
          Paint()..color = const Color(0xFFC8102E));
      canvas.drawCircle(Offset(cx - 2, cy), 17, Paint()..color = const Color(0xFFFFDBAC));
    }

  }

  // 플레이어 (왼쪽)
  void _renderPlayer(Canvas canvas) {
    const p = _playerRig;
    final cx = size.x * p.bx, cy = size.y * p.by;

    if (_imgBodyPlayer != null) {
      _drawBody(canvas, _imgBodyPlayer!, cx, cy, p.bscale);
      if (_failTimer > 0 && _imgBodyPlayerFail != null) {
        _drawBody(canvas, _imgBodyPlayerFail!, cx, cy, p.bscale); // 얼굴만 오버레이
      }
      _drawArm(canvas, p, _imgBodyPlayer!, cx, cy, _imgPlayerArmUpper, _imgPlayerArmFore,
          _playerAngle, 1.0);
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - 2, cy + 20), width: 24, height: 50),
          Paint()..color = const Color(0xFF2C4A7C));
      canvas.drawCircle(Offset(cx - 2, cy), 17, Paint()..color = const Color(0xFFFFDBAC));
    }

  }

  // HUD
  void _renderHUD(Canvas canvas) {
    // [임시] 가사 타이밍 캡처용 — "달리자" 나오는 초를 읽어 _lyricLines에 반영.
    TextPaint(style: const TextStyle(fontSize: 14, color: Colors.white70))
        .render(canvas, 't=${_songTime.toStringAsFixed(1)}s', Vector2(18, 18));
    if (_combo >= 2) {
      _tpCombo.render(canvas, '$_combo COMBO', Vector2(size.x / 2 - 64, 12));
    }

    // 체력
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.x - 20 - i * 32.0, 24), 10,
        Paint()
          ..color = i < _lifeCount
              ? const Color(0xFFC8102E)
              : Colors.grey.withValues(alpha: 0.4),
      );
    }

    // 관객 에너지 바 (하단)
    const barH = 10.0;
    final barW = size.x * 0.38;
    final barX = size.x * 0.31;
    final barY = size.y - 22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH),
          const Radius.circular(5)),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * _crowdEnergy, barH),
          const Radius.circular(5)),
      Paint()..color = const Color(0xFFD4AF37),
    );
    TextPaint(style: const TextStyle(fontSize: 10, color: Colors.white54))
        .render(canvas, '관객 에너지', Vector2(barX - 4, barY - 14));

    // 피버 텍스트
    if (_isFever) {
      final pulse = (sin(_globalTimer * 6) * 0.4 + 0.6).clamp(0.0, 1.0);
      TextPaint(style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.bold,
        color: const Color(0xFFD4AF37).withValues(alpha: pulse),
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
      )).render(canvas, '🔥 FEVER!', Vector2(size.x / 2 - 54, 66));
    }
  }

  // 판정 팝업
  void _renderJudgment(Canvas canvas) {
    final alpha = _judgmentAlpha.clamp(0.0, 1.0);
    final (text, color, fs) = switch (_lastJudgment!) {
      _Judgment.perfect => ('완벽해!', const Color(0xFFD4AF37), 110.0),
      _Judgment.good    => ('좋아!', const Color(0xFF9BE7FF), 100.0),
      _Judgment.miss    => ('아쉬워', const Color(0xFFBBBBBB), 84.0),
    };
    TextPaint(style: TextStyle(
      fontFamily: 'A2Z',
      fontSize: fs, fontWeight: FontWeight.bold,
      color: color.withValues(alpha: alpha),
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: alpha), blurRadius: 4, offset: const Offset(3, 3)),
        Shadow(color: Colors.black.withValues(alpha: alpha), blurRadius: 12),
      ],
    )).render(canvas, text, Vector2(size.x * 0.5 - fs * text.length * 0.32, _judgmentY));
  }

  @override
  void onRemove() {
    _sub?.cancel();
    _posSub?.cancel();
    _audioPlayer.dispose();
    for (final p in _sfxPlayers.values) {
      p.dispose();
    }
    _sfxPlayers.clear();
    super.onRemove();
  }
}

// ─── StatefulWidget 래퍼 ─────────────────────────────────────────────────────────

class TrotRhythmGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;

  const TrotRhythmGame({
    super.key,
    required this.bluetoothService,
    required this.config,
  });

  @override
  State<TrotRhythmGame> createState() => _TrotRhythmGameState();
}

class _TrotRhythmGameState extends State<TrotRhythmGame> {
  late TrotRhythmFlameGame _game;
  late GameMotorController _motor;
  double _simAngle = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);

    final stream = _isSim
        ? null
        : widget.bluetoothService.dataStream
            .map((s) => double.tryParse(s.trim()))
            .where((v) => v != null)
            .map((v) => widget.config.normalizer.normalize(v!));

    _game = TrotRhythmFlameGame(
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
      try {
        widget.bluetoothService.sendBytes(
            Uint8List.fromList(utf8.encode('PART:${widget.config.bodyPart}\n')));
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.bluetoothService
              .sendBytes(Uint8List.fromList(utf8.encode('arom\n')));
        });
      } catch (e) {
        debugPrint('Bluetooth Send Error: $e');
      }
      _motor.startWatchdog();
    }
  }

  @override
  void dispose() {
    _motor.safeStop();
    _motor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Expanded(child: GameWidget(game: _game)),
        if (_isSim) _buildSimControls(),
        _buildControlBar(),
      ]),
    );
  }

  Widget _buildSimControls() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Text('←', style: TextStyle(color: Colors.white70, fontSize: 16)),
        Expanded(
          child: Slider(
            value: _simAngle,
            min: 0.0,
            max: 1.0,
            activeColor: const Color(0xFF87CEEB),
            inactiveColor: Colors.white24,
            onChanged: (v) {
              setState(() => _simAngle = v);
              _game.setPlayerAngle(v);
            },
          ),
        ),
        const Text('→', style: TextStyle(color: Colors.white70, fontSize: 16)),
      ]),
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나가기', style: TextStyle(color: Colors.white60)),
        ),
      ]),
    );
  }
}
