import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../bluetooth.dart';
import '../../generated/l10n.dart';
import '../game_base.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';

import 'dart:typed_data';
import 'dart:convert';  // utf8.encode 사용을 위해 추가


// ============================================================================
// [S3] 방패 막기 (Shield Guard)
// 관절: 어깨 굽힘/폄 (lShoulderEF)
// 메카닉: 화살이 날아옴 → 방패를 목표 높이에 맞추고 등척성 저항 유지
// ============================================================================

// ── 화살 데이터 ──────────────────────────────────────────────────────────────

enum _ArrowPhase { flying, holding, done }

class _ArrowData {
  double x;
  final double y;       // 화살 고정 Y (목표 높이)
  final double speed;
  final bool isDown;    // true = ↓ 굽힘저항, false = ↑ 폄저항
  _ArrowPhase phase;
  bool hitSoundPlayed = false; // 타격음 선재생 플래그

  _ArrowData({
    required this.x,
    required this.y,
    required this.speed,
    required this.isDown,
  }) : phase = _ArrowPhase.flying;
}

// ── 파티클 데이터 ─────────────────────────────────────────────────────────────

class _Particle {
  double x, y, vx, vy;
  double life = 1.0; // 1.0 → 0.0
  final Color color;
  final double radius;

  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.color, required this.radius,
  });
}

// ── FlameGame 본체 ─────────────────────────────────────────────────────────

class ShieldGuardFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  StreamSubscription<double>? _sub;
  double currentPosition = 0.5;
  bool isRunning = false;
  int score = 0;

  final List<_ArrowData> _arrows = [];
  double _spawnTimer = 0;
  final Random _rng = Random();

  // 난이도 파라미터 (Brunnstrom 단계 기반)
  double get _arrowSpeed => 140.0 * config.speedMultiplier;
  double get _spawnInterval => 4.0 / config.speedMultiplier;
  double get _holdRequired => 1.8 * config.speedMultiplier;
  double get _shieldW => 150.0 * config.targetSizeMultiplier;
  double get _shieldH => 180.0 * config.targetSizeMultiplier;

  // 체력
  int _wallHealth = 5; // 5 → 0 = 게임오버

  // 피해 피드백
  double _hitFlash = 0; // 피격 시 화면 붉게 번쩍이는 시간

  // 홀드 상태
  _ArrowData? _holdingArrow;
  double _holdTimer = 0;

  // 타이머
  late double _timeLeft;

  // 막은 화살 수 / 클리어 목표
  int _blockedCount = 0;
  late int _clearTarget; // 난이도별 클리어 목표

  // 파티클
  final List<_Particle> _particles = [];

  // 방패 글로우 펄스
  double _glowPulse = 0; // 0.0~1.0 펄스 위상

  // 충돌 흔들림
  double _shakeTimer = 0; // 0 → 감쇠

  // BGM 상태
  bool _urgentBgmPlaying = false;

  // 캐싱된 TextPaint (매 프레임 생성 방지)
  late final TextPaint _tpScore;
  late final TextPaint _tpHudLabel;
  late final TextPaint _tpHudCount;
  late final TextPaint _tpHoldHint;

  // 캐싱된 Paint (매 프레임 생성 방지)
  final Paint _paintPlain     = Paint();
  final Paint _paintShadow    = Paint()..colorFilter = const ColorFilter.mode(Colors.black54, BlendMode.srcIn);
  final Paint _paintIndicator = Paint()..blendMode = BlendMode.plus;
  final Paint _paintRingBg    = Paint()..color = Colors.white12 ..style = PaintingStyle.stroke ..strokeWidth = 10;
  final Paint _paintRingFg    = Paint()..color = Colors.cyanAccent ..style = PaintingStyle.stroke ..strokeWidth = 10 ..strokeCap = StrokeCap.round;
  final Paint _paintGlow      = Paint()..blendMode = BlendMode.plus;
  final Paint _paintFlash     = Paint();
  final Paint _paintIndBg     = Paint()..color = Colors.black.withValues(alpha: 0.6);
  final Paint _paintLifeOn    = Paint()..color = Colors.white;
  final Paint _paintLifeOff   = Paint()..color = Colors.white.withValues(alpha: 0.15);

  // 캐싱된 이미지 소스 Rect (이미지 로드 후 고정)
  late Rect _arrowSrc;
  late Rect _indicatorSrc;
  late Rect _lifeIconSrc;

  // SFX — 미리 로드된 플레이어 맵
  final Map<String, AudioPlayer> _sfxPlayers = {};

  Future<void> _loadSfx(String path) async {
    final p = AudioPlayer();
    await p.setAudioContext(AudioContext(
      android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    ));
    await p.setSource(AssetSource(path));
    _sfxPlayers[path] = p;
  }

  void _sfx(String path) {
    _sfxPlayers[path]?.play(AssetSource(path));
  }
  // OGG 권장: MP3는 Android에서 루프 지점에 갭 발생. OGG는 루프 갭 없음.
  static const _bgmNormal  = 'sheild_guard/Village Consort.ogg';
  static const _bgmUrgent  = 'sheild_guard/Crunk Knight.ogg';

  // 스프라이트
  late List<ui.Image> _shieldImages;  // shield_0~4
  late ui.Image _shieldGlow;
  late ui.Image _arrowImg;
  late ui.Image _indicatorImg;
  late ui.Image _lifeIconImg;
  List<ui.Image>? _castleImages;      // castle_0~4 (선택)


  ShieldGuardFlameGame({
    this.inputStream,
    required this.config,
    required this.onGameEnd,
  });

  @override
  Color backgroundColor() => const Color(0xFF0D1117);

  Future<ui.Image> _loadImg(String path) async {
    final data = await rootBundle.load('assets/shield/$path');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  Future<void> onLoad() async {
    _timeLeft = config.gameDuration.inSeconds.toDouble();
    _clearTarget = 5 + config.difficultyLevel * 2; // 난이도 1~5 → 목표 7~15개

    _shieldImages = await Future.wait(
      List.generate(5, (i) => _loadImg('shield_$i.png')),
    );
    _shieldGlow   = await _loadImg('shield_glow.png');
    _arrowImg     = await _loadImg('arrow.png');
    _indicatorImg = await _loadImg('indicator.png');
    _lifeIconImg  = await _loadImg('life_icon.png');

    // 성 배경 (없으면 그냥 단색 배경 유지)
    try {
      _castleImages = await Future.wait(
        List.generate(5, (i) => _loadImg('castle_$i.png')),
      );
    } catch (_) {
      _castleImages = null;
    }

    // 이미지 소스 Rect 캐싱
    _arrowSrc     = Rect.fromLTWH(0, 0, _arrowImg.width.toDouble(),     _arrowImg.height.toDouble());
    _indicatorSrc = Rect.fromLTWH(0, 0, _indicatorImg.width.toDouble(), _indicatorImg.height.toDouble());
    _lifeIconSrc  = Rect.fromLTWH(0, 0, _lifeIconImg.width.toDouble(),  _lifeIconImg.height.toDouble());

    // TextPaint 캐싱
    _tpScore    = TextPaint(style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white,    shadows: [Shadow(color: Colors.black, blurRadius: 4)]));
    _tpHudLabel = TextPaint(style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,    shadows: [Shadow(color: Colors.black, blurRadius: 6)]));
    _tpHudCount = TextPaint(style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white,    shadows: [Shadow(color: Colors.black, blurRadius: 4)]));
    _tpHoldHint = TextPaint(style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.cyanAccent, shadows: [Shadow(color: Colors.black, blurRadius: 6)]));

    _sub = inputStream?.listen((v) => currentPosition = v.clamp(0.0, 1.0));
    isRunning = true;

    // BGM + SFX 동시 재생 허용
    await AudioPlayer.global.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.game,
        contentType: AndroidContentType.music,
      ),
    ));

    // BGM + SFX 전부 미리 캐시에 올림 (첫 재생 지연 방지)
    await Future.wait([
      FlameAudio.audioCache.load(_bgmNormal),
      FlameAudio.audioCache.load(_bgmUrgent),
      _loadSfx('100-CC0-SFX/slam_03.ogg'),
      _loadSfx('100-CC0-SFX/bell_01.ogg'),
      _loadSfx('100-CC0-SFX/slam_01.ogg'),
      _loadSfx('100-CC0-SFX/gong_01.ogg'),
      _loadSfx('100-CC0-SFX/door_close_04.ogg'),
    ]);

    await FlameAudio.bgm.play(_bgmNormal, volume: 1.0);
  }

  // ── 업데이트 ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;

    _timeLeft -= dt;
    if (_timeLeft <= 0) { endGame(); return; }

    _updateArrows(dt);
    _updateHold(dt);
    _checkCollision();
    if (_hitFlash > 0) _hitFlash -= dt;
    _updateParticles(dt);
    if (_holdingArrow != null) {
      _glowPulse = (_glowPulse + dt * 3.0) % (2 * pi);
    }
    if (_shakeTimer > 0) _shakeTimer = (_shakeTimer - dt).clamp(0.0, 1.0);

    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnArrow();
    }
  }

  void _updateArrows(double dt) {
    for (final arrow in _arrows) {
      if (arrow.phase == _ArrowPhase.flying) {
        arrow.x -= arrow.speed * dt;
      }
    }
    _arrows.removeWhere((a) => a.phase == _ArrowPhase.done);
  }

  void _applyDamage() {
    _wallHealth = (_wallHealth - 1).clamp(0, 5);
    _hitFlash = 0.4;
    _sfx('100-CC0-SFX/slam_01.ogg'); // 피해
    if (_wallHealth <= 2 && !_urgentBgmPlaying) {
      _urgentBgmPlaying = true;
      FlameAudio.bgm.play(_bgmUrgent, volume: 1.0);
    }
    if (_wallHealth == 0) endGame();
  }

  void _checkCollision() {
    if (_holdingArrow != null) return; // 이미 홀드 중이면 스킵

    final h = size.y;
    final shieldX = size.x * 0.15;

    for (final arrow in _arrows) {
      if (arrow.phase != _ArrowPhase.flying) continue;

      // 타격음 선재생: 200ms 앞에서 재생 (Android 오디오 레이턴시 보정)
      // 선재생 거리 = 속도 × 0.2s (속도가 빠를수록 더 일찍 재생)
      final preOffset = arrow.speed * 0.30; // 300ms 분량 픽셀
      final collisionX = shieldX + 74;
      if (arrow.x > collisionX + preOffset) continue;

      if (!arrow.hitSoundPlayed && arrow.x > collisionX) {
        arrow.hitSoundPlayed = true;
        _sfx('100-CC0-SFX/slam_03.ogg');
        continue; // 아직 충돌 지점 아님 — preOffset px 더 날아간 뒤 판정
      }

      // 화살 Y와 방패 Y를 픽셀 좌표로 직접 비교
      final shieldY = h * 0.1 + (1.0 - currentPosition) * h * 0.8;
      final hitZone = _shieldH * 0.5;
      if ((arrow.y - shieldY).abs() <= hitZone) {
        // 충돌 성공 → 홀드 시작 (화살 끝이 방패 앞면에 위치)
        arrow.phase = _ArrowPhase.holding;
        arrow.x = shieldX + 130 + 20;
        _holdingArrow = arrow;
        _holdTimer = 0;
        _shakeTimer = 0.55;
        if (!arrow.hitSoundPlayed) {
          arrow.hitSoundPlayed = true;
          _sfx('100-CC0-SFX/slam_03.ogg'); // 선재생 못한 경우 fallback
        }
      } else if (arrow.x <= shieldX - 35) {
        // 방패를 완전히 지나침 → 피해
        arrow.phase = _ArrowPhase.done;
        _applyDamage();
      }
    }
  }

  void _updateHold(double dt) {
    final holding = _holdingArrow;
    if (holding == null) return;

    final shieldY = size.y * 0.1 + (1.0 - currentPosition) * size.y * 0.8;
    final inRange = (holding.y - shieldY).abs() <= _shieldH * 0.5;

    if (inRange) {
      _holdTimer += dt;
      if (_holdTimer >= _holdRequired) {
        // 홀드 성공
        score += 10;
        _blockedCount++;
        _sfx('100-CC0-SFX/bell_01.ogg'); // 홀드 성공
        _spawnSuccessParticles(size.x * 0.15, shieldY);
        if (_blockedCount >= _clearTarget) { endGame(); return; }
        holding.phase = _ArrowPhase.done;
        _holdingArrow = null;
        _holdTimer = 0;
      }
    } else {
      // 방패가 벗어남 → 홀드 실패 → 피해
      _spawnDamageParticles(size.x * 0.15, shieldY);
      holding.phase = _ArrowPhase.done;
      _holdingArrow = null;
      _holdTimer = 0;
      _applyDamage();
    }
  }

  void _spawnArrow() {
    final h = size.y;
    final rom = config.romRatio;
    final centerY = h * 0.5;
    final halfRange = h * 0.4 * rom;
    _arrows.add(_ArrowData(
      x: size.x + 30,
      y: centerY - halfRange + _rng.nextDouble() * halfRange * 2,
      speed: _arrowSpeed,
      isDown: _rng.nextBool(),
    ));
  }

  // ── 파티클 ───────────────────────────────────────────────────────────────

  // 현재 흔들림 X 오프셋 (진폭 × sin 고주파 × 감쇠)
  double get _shakeOffset => sin(_shakeTimer * 60) * _shakeTimer * 9.0;

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 200 * dt; // 중력
      p.life -= dt * 1.5;
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _spawnSuccessParticles(double cx, double cy) {
    const colors = [Colors.cyanAccent, Colors.white, Color(0xFFFFD700)];
    for (int i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 80 + _rng.nextDouble() * 160;
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: colors[i % colors.length],
        radius: 3 + _rng.nextDouble() * 4,
      ));
    }
  }

  void _spawnDamageParticles(double cx, double cy) {
    for (int i = 0; i < 12; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 120;
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: Colors.redAccent,
        radius: 3 + _rng.nextDouble() * 3,
      ));
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in _particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.radius * p.life,
        Paint()..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0)),
      );
    }
  }

  // ── 렌더 ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 성 배경
    final castles = _castleImages;
    if (castles != null) {
      final idx = (5 - _wallHealth).clamp(0, 4);
      final img = castles[idx];
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint(),
      );
    }

    // 날아오는 화살 (방패 뒤)
    for (final arrow in _arrows) {
      if (arrow.phase == _ArrowPhase.flying) _drawArrow(canvas, arrow);
    }
    // 방패
    _drawShield(canvas);
    // 꽂힌 화살 (방패 앞)
    for (final arrow in _arrows) {
      if (arrow.phase == _ArrowPhase.holding) _drawArrow(canvas, arrow, xOffset: _shakeOffset);
    }

    if (_holdingArrow != null) {
      _drawHoldRing(canvas);
    }

    // 피격 플래시
    if (_hitFlash > 0) {
      _paintFlash.color = Colors.red.withValues(alpha: (_hitFlash / 0.4) * 0.35);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paintFlash);
    }

    _drawParticles(canvas);
    _drawScore(canvas);
    _drawHud(canvas);
  }

  void _drawArrow(Canvas canvas, _ArrowData arrow, {double xOffset = 0}) {
    final cx = arrow.x + xOffset;
    final cy = arrow.y;
    const arrowW = 260.0;
    const arrowH = 80.0;
    const indicatorSize = 100.0;

    // 화살 스프라이트 (그림자로 가시성 향상)
    final arrowDst  = Rect.fromCenter(center: Offset(cx, cy),         width: arrowW,        height: arrowH);
    final shadowDst = Rect.fromCenter(center: Offset(cx + 3, cy + 3), width: arrowW,        height: arrowH);
    canvas.drawImageRect(_arrowImg, _arrowSrc, shadowDst, _paintShadow);
    canvas.drawImageRect(_arrowImg, _arrowSrc, arrowDst,  _paintPlain);

    // ↓↑ 방향 인디케이터 스프라이트 (화살 위쪽, 검정 원 배경으로 가시성 확보)
    final indY = cy - arrowH / 2 - indicatorSize / 2 - 8;
    final indDst = Rect.fromCenter(center: Offset(cx, indY), width: indicatorSize, height: indicatorSize);

    canvas.drawCircle(Offset(cx, indY), indicatorSize / 2 + 6, _paintIndBg);

    canvas.save();
    if (!arrow.isDown) {
      canvas.translate(cx, indY);
      canvas.scale(1, -1);
      canvas.translate(-cx, -indY);
    }
    canvas.drawImageRect(_indicatorImg, _indicatorSrc, indDst, _paintIndicator);
    canvas.restore();
  }

  void _drawShield(Canvas canvas) {
    final shieldX = size.x * 0.15 + _shakeOffset;
    final shieldY = size.y * 0.1 + (1.0 - currentPosition) * size.y * 0.8;
    final shieldW = _shieldW;
    final shieldH = _shieldH;

    final dst = Rect.fromCenter(center: Offset(shieldX, shieldY), width: shieldW, height: shieldH);

    // 손상 단계 스프라이트
    final idx = (5 - _wallHealth).clamp(0, 4);
    final img = _shieldImages[idx];
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, _paintPlain);

    // 홀드 중: 글로우 오버레이 (BlendMode.plus) + 펄스
    if (_holdingArrow != null) {
      final pulse = (sin(_glowPulse) * 0.5 + 0.5);
      final glowSrc = Rect.fromLTWH(0, 0, _shieldGlow.width.toDouble(), _shieldGlow.height.toDouble());
      _paintGlow.color = Colors.white.withValues(alpha: 0.4 + pulse * 0.4);
      canvas.drawImageRect(_shieldGlow, glowSrc, dst, _paintGlow);
    }
  }

  void _drawHoldRing(Canvas canvas) {
    final holding = _holdingArrow!;
    final h = size.y;
    final shieldX = size.x * 0.15;
    final shieldY = h * 0.1 + (1.0 - currentPosition) * h * 0.8;

    final ringRadius = _shieldW * 0.7;
    const ringWidth = 10.0;
    final progress = (_holdTimer / _holdRequired).clamp(0.0, 1.0);

    // 배경 링
    canvas.drawCircle(Offset(shieldX, shieldY), ringRadius, _paintRingBg);

    // 진행 링
    canvas.drawArc(
      Rect.fromCircle(center: Offset(shieldX, shieldY), radius: ringRadius),
      -pi / 2, 2 * pi * progress, false, _paintRingFg,
    );

    // 저항 방향 힌트 (화살 반대 방향)
    final hint = holding.isDown ? '↑ 버텨!' : '↓ 버텨!';
    _tpHoldHint.render(canvas, hint, Vector2(shieldX, shieldY - ringRadius - 24), anchor: Anchor.center);
  }

  void _drawScore(Canvas canvas) {
    _tpScore.render(canvas, '점수: $score', Vector2(size.x - 16, 16), anchor: Anchor.topRight);
  }

  void _drawHud(Canvas canvas) {
    // 막은 화살 수 / 목표 (상단 중앙)
    _tpHudLabel.render(canvas, '막은 화살',              Vector2(size.x / 2, 6),  anchor: Anchor.topCenter);
    _tpHudCount.render(canvas, '$_blockedCount / $_clearTarget', Vector2(size.x / 2, 42), anchor: Anchor.topCenter);

    // 목숨 아이콘 스프라이트 (상단 좌측)
    const iconSize = 52.0;
    const spacing = 62.0;
    const startX = 20.0;
    const topY = 16.0;

    for (int i = 0; i < 5; i++) {
      final cx = startX + i * spacing + iconSize / 2;
      final iconDst = Rect.fromCenter(center: Offset(cx, topY + iconSize / 2), width: iconSize, height: iconSize);
      canvas.drawImageRect(
        _lifeIconImg, _lifeIconSrc, iconDst,
        i < _wallHealth ? _paintLifeOn : _paintLifeOff,
      );
    }
  }

  void setSimPosition(double v) {
    currentPosition = v.clamp(0.0, 1.0);
  }

  void endGame() {
    isRunning = false;
    _sub?.cancel();
    FlameAudio.bgm.stop();
    _sfx(_blockedCount >= _clearTarget
        ? '100-CC0-SFX/gong_01.ogg'         // 클리어
        : '100-CC0-SFX/door_close_04.ogg'); // 게임오버
    final result = GameResult(
      gameId: 'shield_guard',
      score: score,
      maxPossibleScore: _clearTarget * 10,
      accuracy: 0,
      duration: config.gameDuration,
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
    );
    onGameEnd(result);
  }

  @override
  void onRemove() {
    _sub?.cancel();
    FlameAudio.bgm.stop();
    for (final p in _sfxPlayers.values) {
      p.dispose();
    }
    super.onRemove();
  }
}

// ── Flutter 래퍼 ───────────────────────────────────────────────────────────

class ShieldGuardGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;

  const ShieldGuardGame({
    super.key,
    required this.bluetoothService,
    required this.config,
  });

  @override
  State<ShieldGuardGame> createState() => _ShieldGuardGameState();
}

class _ShieldGuardGameState extends State<ShieldGuardGame> {
  late ShieldGuardFlameGame _game;
  late GameMotorController _motor;
  double _simValue = 0.5;
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);

    // Jetson으로부터 전송되는 모터 [0]번의 Pos 데이터를 파싱하여 높이 매핑
    final stream = _isSim
        ? null
        : widget.bluetoothService.dataStream
            .map((s) => double.tryParse(s.trim()))
            .where((v) => v != null)
            .map((a) => widget.config.normalizer.normalize(a!));

    _game = ShieldGuardFlameGame(
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
      // --- 게임 시작 시 자동 명령 전송 부분 수정 ---
      try {
        // 1. 0번 모터(rShoulderEF)를 타겟으로 지정
        widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode("PART:rShoulderEF\n")));
        
        // 2. 약간의 딜레이(100ms) 후 arom 모드 실행
        // (블루투스 직렬 통신에서 명령이 겹치지 않도록 방지)
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode("arom\n")));
        });
      } catch (e) {
        debugPrint("Bluetooth Send Error: $e");
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

  Widget _buildSlider() {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      child: Row(children: [
        const Text('⬇', style: TextStyle(color: Colors.white54)),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16),
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
        ),
        const Text('⬆', style: TextStyle(color: Colors.white54)),
      ]),
    );
  }

  Widget _buildControlBar(AppLocalizations loc) {
    return Container(
      color: const Color(0xFF0D1117),
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
}
