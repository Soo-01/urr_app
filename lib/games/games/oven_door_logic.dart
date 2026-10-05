import '../game_base.dart';

/// ============================================================================
/// [E3] 오븐 문 열기 — 게임 규칙
/// 순수 Dart (Flame·Flutter import 금지) → flutter test로 기기 없이 검증한다.
/// 설계: docs/superpowers/specs/2026-09-29-oven-door-design.md
/// ============================================================================

enum FoodKind { cookie, muffin, bread, pizza, cake }

extension FoodKindLabel on FoodKind {
  String get label => switch (this) {
        FoodKind.cookie => '쿠키',
        FoodKind.muffin => '머핀',
        FoodKind.bread => '식빵',
        FoodKind.pizza => '피자',
        FoodKind.cake => '케이크',
      };
}

/// 규칙 상수. 실기기 QA에서 이 값들을 조정한다.
class OvenRules {
  OvenRules._();

  /// 이 값보다 적게 열려 있으면 문이 닫힌 것으로 본다 (굽기 시작 조건).
  static const double closedBelow = 0.15;

  /// 반복 횟수를 셀 때 쓰는 열림/닫힘 히스테리시스.
  static const double openAt = 0.18;
  static const double closeAt = 0.12;

  /// 손떨림 유예. 요구 열림 밑으로 내려가도 이 시간 안에 되돌아오면 이어진다.
  static const double graceTime = 0.3;

  static const double bakeTime = 8.0; // 굽는 시간(휴식)
  static const double resultTime = 2.0; // 결과 연출
  static const double maxSessionSeconds = 480; // 8분

  static const int insertScore = 50;
  static const int takeScore = 100;
  static const int speedBonusMax = 50;

  static const double maxResistanceKg = 3.0;
}

/// GameConfig와 치료사가 고른 저항에서 뽑아낸 수치 (스펙 6장).
class OvenParams {
  final FoodKind food;

  /// 음식이 들어갈 만큼 열어야 하는 문 열림 비율 (0~1).
  final double requiredOpen;

  /// 그만큼 열고 버텨야 하는 시간(초).
  final double holdTime;

  /// 벨이 울린 뒤 음식이 타기까지의 시간(초).
  final double takeOutWindow;

  final int foodGoal;
  final double resistanceKg;

  const OvenParams({
    required this.food,
    required this.requiredOpen,
    required this.holdTime,
    required this.takeOutWindow,
    required this.foodGoal,
    required this.resistanceKg,
  });

  factory OvenParams.fromConfig(GameConfig config, {double resistanceKg = 0}) {
    final level = config.difficultyLevel.clamp(1, 5);
    const foods = {
      1: FoodKind.cookie,
      2: FoodKind.muffin,
      3: FoodKind.bread,
      4: FoodKind.pizza,
      5: FoodKind.cake,
    };
    const required = {1: 0.35, 2: 0.45, 3: 0.55, 4: 0.70, 5: 0.85};
    const hold = {1: 1.0, 2: 1.5, 3: 2.0, 4: 2.5, 5: 3.0};
    const window = {1: 16.0, 2: 14.0, 3: 12.0, 4: 10.0, 5: 8.0};
    const goal = {1: 4, 2: 5, 3: 6, 4: 7, 5: 8};

    final allowed = config.canUseResistance ? resistanceKg : 0.0;
    return OvenParams(
      food: foods[level]!,
      requiredOpen: required[level]!,
      holdTime: hold[level]!,
      takeOutWindow: window[level]!,
      foodGoal: goal[level]!,
      resistanceKg: allowed.clamp(0.0, OvenRules.maxResistanceKg).toDouble(),
    );
  }
}

/// 화면에 알리는 이벤트. name은 AngleRecord.event에 그대로 기록한다.
class OvenEvent {
  final String name;
  const OvenEvent(this.name);
}

enum OvenPhase {
  inserting, // 문을 열고 버텨 음식을 넣는 중
  closing, // 넣기 완료 → 문이 닫히길 기다림
  baking, // 굽는 중 (팔을 내리고 휴식)
  takingOut, // 벨이 울린 뒤 꺼내는 중
  result, // 결과 연출
  finished,
}

enum FoodOutcome { done, dropped, burnt }

/// 한 판의 진행 상태. 화면은 매 프레임 update(dt, door)를 부르고 이벤트로 연출한다.
class OvenSession {
  final OvenParams params;

  OvenSession(this.params);

  OvenPhase _phase = OvenPhase.inserting;
  double _phaseTime = 0;
  double _elapsed = 0;
  double _door = 0;
  bool _doorOpen = false;
  double _progress = 0; // 유지 진행 0~1
  double _grace = 0; // 요구 열림 아래로 내려간 시간
  int _foodsDone = 0;
  int _score = 0;
  int _reps = 0;
  int _hits = 0;
  int _misses = 0;
  FoodOutcome? _lastOutcome;
  final List<FoodOutcome> _shelf = [];

  OvenPhase get phase => _phase;
  double get phaseTime => _phaseTime;
  double get holdProgress => _progress;
  double get door => _door;
  bool get doorOpen => _doorOpen;
  double get bakeRemaining => _phase == OvenPhase.baking
      ? (OvenRules.bakeTime - _phaseTime).clamp(0.0, OvenRules.bakeTime)
      : 0;
  double get windowRemaining => _phase == OvenPhase.takingOut
      ? (params.takeOutWindow - _phaseTime).clamp(0.0, params.takeOutWindow)
      : 0;
  int get foodsDone => _foodsDone;
  int get score => _score;
  int get reps => _reps;
  int get hits => _hits;
  int get misses => _misses;
  double get elapsed => _elapsed;
  FoodOutcome? get lastOutcome => _lastOutcome;
  List<FoodOutcome> get shelf => List.unmodifiable(_shelf);
  bool get isFinished => _phase == OvenPhase.finished;
  double get accuracy => (_hits + _misses) == 0 ? 0 : _hits / (_hits + _misses);

  int get maxPossibleScore =>
      params.foodGoal *
      (OvenRules.insertScore + OvenRules.takeScore + OvenRules.speedBonusMax);

  /// door = 문 열림 0~1. 이번 프레임에 생긴 이벤트를 돌려준다.
  List<OvenEvent> update(double dt, double door) {
    final events = <OvenEvent>[];
    if (_phase == OvenPhase.finished) return events;

    _door = door.isFinite ? door.clamp(0.0, 1.0) : 0.0;
    _elapsed += dt;
    _phaseTime += dt;
    _updateDoorState(events);

    switch (_phase) {
      case OvenPhase.inserting:
        _hold(dt, events, onDone: () {
          _hits++;
          _score += OvenRules.insertScore;
          events.add(const OvenEvent('insert_done'));
          _enter(OvenPhase.closing);
        });
      case OvenPhase.closing:
        if (_door < OvenRules.closedBelow) _enter(OvenPhase.baking);
      case OvenPhase.baking:
        if (_phaseTime >= OvenRules.bakeTime) {
          // 큰 dt로 굽는 시간을 한참 넘겨 들어올 수 있다. 넘긴 만큼을 꺼내기
          // 단계의 경과 시간으로 넘겨야 같은 프레임에 탐 판정까지 난다.
          final overshoot = _phaseTime - OvenRules.bakeTime;
          events.add(const OvenEvent('bell'));
          _enter(OvenPhase.takingOut);
          _phaseTime = overshoot;
          // 벨이 울린 프레임에도 이미 열려 있으면 바로 유지를 시작한다.
          _takeOut(0, events);
        }
      case OvenPhase.takingOut:
        _takeOut(dt, events);
      case OvenPhase.result:
        if (_phaseTime >= OvenRules.resultTime) _nextFood();
      case OvenPhase.finished:
        break;
    }

    if (_phase != OvenPhase.finished && _elapsed >= OvenRules.maxSessionSeconds) {
      _enter(OvenPhase.finished);
    }
    return events;
  }

  void _enter(OvenPhase phase) {
    _phase = phase;
    _phaseTime = 0;
    _progress = 0;
    _grace = 0;
  }

  void _updateDoorState(List<OvenEvent> events) {
    if (!_doorOpen && _door >= OvenRules.openAt) {
      _doorOpen = true;
      events.add(const OvenEvent('door_open'));
    } else if (_doorOpen && _door < OvenRules.closeAt) {
      _doorOpen = false;
      _reps++;
      events.add(const OvenEvent('door_close'));
    }
  }

  /// 유지 진행. 요구 열림 아래로 내려가면 유예 시간을 재고, 넘기면 음식을 떨어뜨린다.
  void _hold(double dt, List<OvenEvent> events, {required void Function() onDone}) {
    if (_door >= params.requiredOpen) {
      _grace = 0;
      _progress += dt / params.holdTime;
      if (_progress >= 1.0) {
        _progress = 1.0;
        onDone();
      }
      return;
    }
    if (_progress <= 0) return; // 아직 시작하지 않았다
    _grace += dt;
    if (_grace > OvenRules.graceTime) {
      _misses++;
      events.add(const OvenEvent('drop'));
      _finishFood(FoodOutcome.dropped);
    }
  }

  void _takeOut(double dt, List<OvenEvent> events) {
    if (_phase != OvenPhase.takingOut) return;
    _hold(dt, events, onDone: () {
      final remaining =
          (params.takeOutWindow - _phaseTime).clamp(0.0, params.takeOutWindow);
      _hits++;
      _score += OvenRules.takeScore +
          (OvenRules.speedBonusMax * remaining / params.takeOutWindow).round();
      events.add(const OvenEvent('take_done'));
      _shelf.add(FoodOutcome.done);
      _finishFood(FoodOutcome.done);
    });
    if (_phase == OvenPhase.takingOut && _phaseTime >= params.takeOutWindow) {
      _misses++;
      events.add(const OvenEvent('burnt'));
      _finishFood(FoodOutcome.burnt);
    }
  }

  void _finishFood(FoodOutcome outcome) {
    _lastOutcome = outcome;
    _foodsDone++;
    _enter(OvenPhase.result);
  }

  void _nextFood() {
    if (_foodsDone >= params.foodGoal) {
      _enter(OvenPhase.finished);
      return;
    }
    _enter(OvenPhase.inserting);
  }
}
