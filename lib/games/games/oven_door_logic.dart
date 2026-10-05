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
