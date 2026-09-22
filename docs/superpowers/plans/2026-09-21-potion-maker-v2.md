# 물약 제조[E3] v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 어깨 안쪽/가쪽돌림으로 재료통 레버를 열어 유리 플라스크에 재료를 층층이 붓는 물약 제조 게임 v2를 기존 코드를 폐기하고 새로 만든다.

**Architecture:** 게임 규칙(흐름·판정·등급·점수·상태 전환)은 Flame/Flutter를 쓰지 않는 순수 Dart 파일 `potion_maker_logic.dart`에 두고 `flutter test`로 검증한다. 화면 파일 `potion_maker_game.dart`는 매 프레임 `PotionSession.update(dt, lever)`를 호출하고 돌려받은 이벤트로 연출·기록만 한다. 화면은 1600×900 기준 좌표로 Canvas에 도형을 그리고, 실제 화면 크기에 맞춰 비율로 늘린다.

**Tech Stack:** Flutter 3.44.8, Dart SDK ^3.5.3, Flame ^1.35.1, flutter_test

**Spec:** [docs/potion_maker_build_guide.md](../../potion_maker_build_guide.md) (v2, 2026-09-21). 최종 목업: `docs/images/potion_maker/mockup_final.svg`

## Global Constraints

- **수정 금지 파일**: `lib/games/game_base.dart`, `lib/games/game_motor_controller.dart`.
- **작업 트리에 이 작업과 무관한 커밋 안 된 변경이 많다.** `git add`는 각 태스크에 적힌 파일만 한다. `git add -A`나 `git add .`는 쓰지 않는다.
- **테스트는 `flutter test test/potion_maker_logic_test.dart`만 실행한다.** `test/widget_test.dart`는 깨진 기본 템플릿이라 전체 `flutter test`는 실패한다.
- 규칙 파일은 `dart:math`와 `../game_base.dart`만 import한다 (Flame·Flutter import 금지).
- 패키지 이름: `exo_tablet_app_v6` (테스트 import는 `package:exo_tablet_app_v6/...`).
- 화면 글자는 한국어. 놀리는 표현, 폭발, 독성 연기, 흔들림, 목숨 감소 연출 금지 (대상: 고령 뇌졸중 환자).
- 색: 외곽선 `#3B2A1A`, 배경 `#FFF7E6`→`#FFE2B0`, 목표선 `#E64A19`, 레버 구간 `#9E9E9E`/`#1E88E5`/`#FFB300`, 층 색 `#1E88E5`, `#8E24AA`, `#43A047`, `#FB8C00`, `#D81B60`.
- **시각 확인은 사용자가 직접 한다. 스크린샷을 찍지 않는다.**
- 커밋 메시지는 한국어 conventional 형식(`feat:`, `docs:`, `test:`)이고, 끝에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`를 붙인다.

---

## File Structure

| 파일 | 역할 | 태스크 |
|------|------|--------|
| `lib/games/games/potion_maker_logic.dart` | 규칙: 파라미터, 레시피, 판정, 등급, 세션 상태 기계 | 1, 2 (신규) |
| `test/potion_maker_logic_test.dart` | 규칙 단위 테스트 | 1, 2 (신규) |
| `lib/games/games/potion_maker_game.dart` | Flame 화면 + `PotionMakerGame` 위젯 | 3 (전체 재작성) |
| `lib/games/game_hub.dart` | 포션메이커를 어깨 목록으로 이동, 관절 `lShoulderRo` | 4 (수정) |
| `lib/l10n/intl_ko.arb`, `lib/l10n/intl_en.arb`, `lib/generated/*` | 설명 문구 | 4 (수정 + 재생성) |
| `docs/potion_maker_build_guide.md` | 현재 상태 표 갱신 | 5 (수정) |

---

### Task 0: 사전 정리 (사용자 확인 필요)

**이 태스크는 코드를 쓰지 않는다. 실행 전에 사용자에게 두 가지를 묻고 답에 따라 진행한다.**

- [ ] **Step 1: 커밋 안 된 트로트 변경 확인**

Run: `git status --short lib/games/game_hub.dart lib/l10n lib/generated lib/games/games/potion_maker_game.dart`

2026-09-21 기준 상태:
- `game_hub.dart`, `intl_*.arb`, `lib/generated/*`에 **트로트 리듬 게임 허브 등록 변경이 커밋되지 않은 채** 들어 있다. Task 4가 같은 파일을 커밋하면 이 변경이 함께 섞인다.
- `potion_maker_game.dart`의 커밋 안 된 변경은 `const` 린트 수정뿐이다. Task 3에서 파일 전체를 새로 쓰므로 버려도 된다.

사용자에게 묻는다: "트로트 허브 등록 변경을 먼저 따로 커밋할까요?" 예라고 하면:

```bash
git add lib/games/game_hub.dart lib/l10n/intl_ko.arb lib/l10n/intl_en.arb lib/generated/l10n.dart lib/generated/l10n_ko.dart lib/generated/l10n_en.dart
git commit -m "feat: 트로트 리듬 게임 허브 등록

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 2: 설계 문서 커밋 여부 확인**

사용자에게 묻는다: "포션메이커 설계 문서를 커밋할까요?" 예라고 하면:

```bash
git add docs/potion_maker_build_guide.md docs/images/potion_maker docs/superpowers/plans/2026-09-21-potion-maker-v2.md .gitignore
git commit -m "docs: 포션메이커[E3] v2 설계 가이드·목업·구현 계획

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

`docs/2026_oct_game_dev_plan.md`는 한 번도 커밋된 적 없는 파일이다. 함께 올릴지 따로 묻는다.

---

### Task 1: 규칙 — 파라미터, 레시피, 물약 판정

**Files:**
- Create: `lib/games/games/potion_maker_logic.dart`
- Test: `test/potion_maker_logic_test.dart`

**Interfaces:**
- Consumes: `GameConfig`, `BrunnstromStage` (`lib/games/game_base.dart`), `GameConfig.speedMultiplier`
- Produces:
  - `enum ContainerKind { bigTank, smallBottle }`
  - `enum PourResult { emptied, exact, over, under }`
  - `enum PotionOutcome { normal, shiny, gold, swollen, tiny }` + extension `PotionOutcomeInfo` (`bool isSuccess`, `int stars`, `int bonus`, `String eventName`)
  - `class PotionRules` (static const: `closedBelow`, `bigTankZone`, `openAt`, `closeAt`, `confirmTime`, `transitionTime`, `resultTime`, `maxSessionSeconds`, `goldAt`, `shinyAt`, `targetCeiling`, `tankScore`, `exactScore`, `exactBonusMax`)
  - `class PotionParams` (const 생성자, `factory PotionParams.fromConfig(GameConfig)`)
  - `class Ingredient(ContainerKind kind, double target)` — `double amount`, `double maxOpening`, `PourResult? result`, `double get error`
  - `List<Ingredient> makePotion(PotionParams params, Random rng)`
  - `PotionOutcome judgePotion(List<Ingredient> potion)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/potion_maker_logic_test.dart`:

```dart
import 'dart:math';

import 'package:exo_tablet_app_v6/games/angle_normalizer.dart';
import 'package:exo_tablet_app_v6/games/game_base.dart';
import 'package:exo_tablet_app_v6/games/games/potion_maker_logic.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _config({int level = 3, BrunnstromStage stage = BrunnstromStage.stage5}) =>
    GameConfig(
      normalizer: const AngleNormalizer(minAngle: -60, maxAngle: 60),
      difficultyLevel: level,
      bodyPart: 'lShoulderRo',
      brunnstromStage: stage,
    );

Ingredient _ing(ContainerKind kind,
        {double target = 0.5, double amount = 0, double maxOpening = 0, PourResult? result}) =>
    Ingredient(kind, kind == ContainerKind.bigTank ? 1.0 : target)
      ..amount = amount
      ..maxOpening = maxOpening
      ..result = result;

void main() {
  group('PotionParams.fromConfig', () {
    test('레벨 3 · Brunnstrom 5 → 가이드 표 4-1, 4-2 값', () {
      final p = PotionParams.fromConfig(_config());
      expect(p.potionGoal, 6);
      expect(p.ingredientsPerPotion, 4);
      expect(p.smallPerPotion, 2);
      expect(p.tolerance, closeTo(0.08, 1e-9));
      expect(p.smallFlowRate, closeTo(0.25, 1e-9));
      expect(p.bigTankPourTime, 3.0);
      expect(p.targetLines, [0.3, 0.5, 0.7]);
    });

    test('Brunnstrom 2단계는 큰 통만, 흐름·시간·허용 오차가 느슨하다', () {
      final p = PotionParams.fromConfig(_config(level: 1, stage: BrunnstromStage.stage2));
      expect(p.smallPerPotion, 0);
      expect(p.tolerance, closeTo(0.192, 1e-9));
      expect(p.smallFlowRate, closeTo(0.10, 1e-9));
      expect(p.bigTankPourTime, 1.5);
    });

    test('레벨 5 · Brunnstrom 6 → 허용 오차 0.04, 목표선 0.25~0.75', () {
      final p = PotionParams.fromConfig(_config(level: 5, stage: BrunnstromStage.stage6));
      expect(p.potionGoal, 8);
      expect(p.smallPerPotion, 3);
      expect(p.tolerance, closeTo(0.04, 1e-9));
      expect(p.targetLines.length, 11);
      expect(p.targetLines.first, closeTo(0.25, 1e-9));
      expect(p.targetLines.last, closeTo(0.75, 1e-9));
    });
  });

  group('makePotion', () {
    test('첫 재료는 큰 통이고, 작은 병 수와 목표선 상한을 지킨다', () {
      final p = PotionParams.fromConfig(_config(level: 5, stage: BrunnstromStage.stage6));
      final rng = Random(7);
      for (var k = 0; k < 50; k++) {
        final potion = makePotion(p, rng);
        expect(potion.length, 5);
        expect(potion.first.kind, ContainerKind.bigTank);
        final smalls = potion.where((i) => i.kind == ContainerKind.smallBottle).toList();
        expect(smalls.length, 3);
        for (final s in smalls) {
          expect(s.target + p.tolerance, lessThanOrEqualTo(PotionRules.targetCeiling + 1e-9));
        }
      }
    });

    test('목표선 + 허용 오차가 0.95를 넘는 후보는 쓰지 않는다', () {
      const p = PotionParams(
          potionGoal: 1, ingredientsPerPotion: 2, smallPerPotion: 1, tolerance: 0.3,
          smallFlowRate: 0.25, bigTankPourTime: 2, targetLines: [0.5, 0.7]);
      final rng = Random(1);
      for (var k = 0; k < 20; k++) {
        expect(makePotion(p, rng)[1].target, 0.5);
      }
    });

    test('쓸 수 있는 후보가 없으면 상한값을 목표선으로 쓴다', () {
      const p = PotionParams(
          potionGoal: 1, ingredientsPerPotion: 2, smallPerPotion: 1, tolerance: 0.2,
          smallFlowRate: 0.25, bigTankPourTime: 2, targetLines: [0.8]);
      expect(makePotion(p, Random(1))[1].target, closeTo(0.75, 1e-9));
    });
  });

  group('judgePotion', () {
    PotionOutcome grade(double smallOpening) => judgePotion([
          _ing(ContainerKind.bigTank, maxOpening: 0.9, result: PourResult.emptied),
          _ing(ContainerKind.smallBottle, maxOpening: smallOpening, result: PourResult.exact),
        ]);

    test('작은 병이 모두 정확하면 평균 최대 열림으로 등급을 정한다', () {
      expect(grade(0.8), PotionOutcome.gold); // 평균 0.85
      expect(grade(0.3), PotionOutcome.shiny); // 평균 0.60
      expect(grade(0.2), PotionOutcome.normal); // 평균 0.55
    });

    test('큰 통만 있는 물약도 크게 열면 황금', () {
      expect(
          judgePotion([_ing(ContainerKind.bigTank, maxOpening: 0.9, result: PourResult.emptied)]),
          PotionOutcome.gold);
    });

    test('오차가 가장 큰 작은 병이 과다면 부푼 생물, 과소면 콩알 생물', () {
      final exact = _ing(ContainerKind.smallBottle,
          amount: 0.5, maxOpening: 1, result: PourResult.exact);
      final over = _ing(ContainerKind.smallBottle, amount: 0.62, result: PourResult.over);
      final under = _ing(ContainerKind.smallBottle, amount: 0.30, result: PourResult.under);
      expect(judgePotion([exact, over]), PotionOutcome.swollen);
      expect(judgePotion([over, under]), PotionOutcome.tiny); // 과소 오차 0.2 > 과다 오차 0.12
    });
  });

  group('PotionOutcomeInfo', () {
    test('등급별 별·보너스와 이벤트 이름', () {
      expect(PotionOutcome.gold.stars, 3);
      expect(PotionOutcome.gold.bonus, 200);
      expect(PotionOutcome.shiny.stars, 2);
      expect(PotionOutcome.shiny.bonus, 150);
      expect(PotionOutcome.normal.stars, 1);
      expect(PotionOutcome.normal.bonus, 100);
      expect(PotionOutcome.swollen.stars, 0);
      expect(PotionOutcome.tiny.isSuccess, isFalse);
      expect(PotionOutcome.gold.isSuccess, isTrue);
      expect(PotionOutcome.gold.eventName, 'potion_gold');
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `flutter test test/potion_maker_logic_test.dart`
Expected: FAIL — `potion_maker_logic.dart` 파일이 없어 컴파일 오류 (`Error: Error when reading 'lib/games/games/potion_maker_logic.dart'`)

- [ ] **Step 3: 규칙 파일 작성**

`lib/games/games/potion_maker_logic.dart`:

```dart
import 'dart:math';

import '../game_base.dart';

/// ============================================================================
/// [E3] 물약 제조 (Potion Maker) v2 — 게임 규칙
/// 순수 Dart (Flame·Flutter import 금지) → flutter test로 기기 없이 검증한다.
/// 설계: docs/potion_maker_build_guide.md 3~4장. 수치 튜닝은 이 파일에서만.
/// ============================================================================

enum ContainerKind { bigTank, smallBottle }

enum PourResult { emptied, exact, over, under }

/// 물약 결과. 앞의 셋이 성공 등급, 뒤의 둘이 엉뚱한 결과물이다.
enum PotionOutcome { normal, shiny, gold, swollen, tiny }

extension PotionOutcomeInfo on PotionOutcome {
  bool get isSuccess => index <= PotionOutcome.gold.index;

  int get stars => switch (this) {
        PotionOutcome.normal => 1,
        PotionOutcome.shiny => 2,
        PotionOutcome.gold => 3,
        PotionOutcome.swollen || PotionOutcome.tiny => 0,
      };

  int get bonus => switch (this) {
        PotionOutcome.normal => 100,
        PotionOutcome.shiny => 150,
        PotionOutcome.gold => 200,
        PotionOutcome.swollen || PotionOutcome.tiny => 0,
      };

  /// AngleRecord.event 값 (가이드 3-7): potion_normal, potion_shiny, potion_gold,
  /// potion_swollen, potion_tiny
  String get eventName => 'potion_$name';
}

/// 규칙 상수 (가이드 3장). 실기기 QA에서 이 값들을 조정한다.
class PotionRules {
  PotionRules._();

  /// 레버 열림 o가 이 값 이하면 흐르지 않는다.
  static const double closedBelow = 0.15;

  /// 큰 통은 o가 이 값 이상일 때만 흐른다.
  static const double bigTankZone = 0.80;

  /// 열림/닫힘 상태 히스테리시스 (반복 횟수·확정 판정용).
  static const double openAt = 0.18;
  static const double closeAt = 0.12;

  static const double confirmTime = 1.0; // 작은 병: 닫고 확정까지(초)
  static const double transitionTime = 1.0; // 다음 재료 전환(초)
  static const double resultTime = 3.5; // 물약 결과: 층 펼치기 1초 + 생물 연출(초)
  static const double maxSessionSeconds = 480; // 8분

  /// 성공 등급 기준 (재료별 최대 열림의 평균).
  static const double goldAt = 0.85;
  static const double shinyAt = 0.60;

  /// 목표선 + 허용 오차 상한 (층 높이 기준).
  static const double targetCeiling = 0.95;

  static const int tankScore = 50;
  static const int exactScore = 100;
  static const int exactBonusMax = 50;
}

/// GameConfig에서 뽑아낸 수치 (가이드 4장 표).
class PotionParams {
  final int potionGoal;
  final int ingredientsPerPotion;
  final int smallPerPotion;

  /// 허용 오차 (층 높이 0~1 기준).
  final double tolerance;

  /// 레버를 최대로 열었을 때 초당 층 높이 증가량.
  final double smallFlowRate;

  /// 큰 통을 비우는 데 필요한 흐름 시간 합(초).
  final double bigTankPourTime;

  final List<double> targetLines;

  const PotionParams({
    required this.potionGoal,
    required this.ingredientsPerPotion,
    required this.smallPerPotion,
    required this.tolerance,
    required this.smallFlowRate,
    required this.bigTankPourTime,
    required this.targetLines,
  });

  factory PotionParams.fromConfig(GameConfig config) {
    final level = config.difficultyLevel.clamp(1, 5);
    final stage = config.brunnstromStage.level;
    const goals = {1: 4, 2: 5, 3: 6, 4: 7, 5: 8};
    const perPotion = {1: 3, 2: 3, 3: 4, 4: 4, 5: 5};
    const baseTolerance = {1: 0.12, 2: 0.10, 3: 0.08, 4: 0.06, 5: 0.05};
    const smallRatio = {2: 0.0, 3: 0.25, 4: 0.4, 5: 0.5, 6: 0.6};
    const toleranceFactor = {2: 1.6, 3: 1.4, 4: 1.2, 5: 1.0, 6: 0.8};
    const bigTankTime = {2: 1.5, 3: 2.0, 4: 2.5, 5: 3.0, 6: 3.0};

    final n = perPotion[level]!;
    return PotionParams(
      potionGoal: goals[level]!,
      ingredientsPerPotion: n,
      smallPerPotion: (n * smallRatio[stage]!).round().clamp(0, n - 1),
      tolerance: (baseTolerance[level]! * toleranceFactor[stage]!).clamp(0.03, 0.20).toDouble(),
      smallFlowRate: 0.25 * config.speedMultiplier,
      bigTankPourTime: bigTankTime[stage]!,
      targetLines: _targetLinesFor(level),
    );
  }

  static List<double> _targetLinesFor(int level) {
    if (level <= 2) return const [0.5];
    if (level <= 4) return const [0.3, 0.5, 0.7];
    return [for (var i = 0; i <= 10; i++) (25 + 5 * i) / 100]; // 0.25~0.75, 0.05 간격
  }
}

/// 물약에 들어가는 재료 하나.
class Ingredient {
  final ContainerKind kind;

  /// 작은 병: 목표선, 큰 통: 1.0
  final double target;

  double amount = 0;

  /// 이 재료를 붓는 동안의 최대 레버 열림 (등급 계산용).
  double maxOpening = 0;

  PourResult? result;

  Ingredient(this.kind, this.target);

  double get error => (amount - target).abs();
}

/// 물약 하나의 재료 목록을 만든다. 첫 재료는 항상 큰 통(워밍업), 나머지는 섞는다.
List<Ingredient> makePotion(PotionParams params, Random rng) {
  final rest = <ContainerKind>[
    for (var i = 0; i < params.ingredientsPerPotion - 1 - params.smallPerPotion; i++)
      ContainerKind.bigTank,
    for (var i = 0; i < params.smallPerPotion; i++) ContainerKind.smallBottle,
  ]..shuffle(rng);
  final kinds = [ContainerKind.bigTank, ...rest];

  final ceiling = PotionRules.targetCeiling - params.tolerance;
  final allowed = params.targetLines.where((t) => t <= ceiling + 1e-9).toList();
  final pool = allowed.isEmpty ? [ceiling] : allowed;

  return [
    for (final k in kinds)
      Ingredient(k, k == ContainerKind.bigTank ? 1.0 : pool[rng.nextInt(pool.length)]),
  ];
}

/// 재료를 모두 부은 물약의 결과 (가이드 3-5).
PotionOutcome judgePotion(List<Ingredient> potion) {
  final failed = potion
      .where((i) => i.result == PourResult.over || i.result == PourResult.under)
      .toList();
  if (failed.isNotEmpty) {
    final worst = failed.reduce((a, b) => b.error > a.error ? b : a);
    return worst.result == PourResult.over ? PotionOutcome.swollen : PotionOutcome.tiny;
  }
  final average = potion.fold<double>(0, (sum, i) => sum + i.maxOpening) / potion.length;
  if (average >= PotionRules.goldAt - 1e-9) return PotionOutcome.gold;
  if (average >= PotionRules.shinyAt - 1e-9) return PotionOutcome.shiny;
  return PotionOutcome.normal;
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `flutter test test/potion_maker_logic_test.dart`
Expected: PASS — `All tests passed!` (10개)

- [ ] **Step 5: 커밋**

```bash
git add lib/games/games/potion_maker_logic.dart test/potion_maker_logic_test.dart
git commit -m "feat: 포션메이커 v2 규칙 — 파라미터·레시피·물약 판정

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 규칙 — 세션 상태 기계 (붓기·확정·반복·점수·종료)

**Files:**
- Modify: `lib/games/games/potion_maker_logic.dart` (파일 끝에 추가)
- Test: `test/potion_maker_logic_test.dart` (`main()` 안 끝에 그룹 추가, 파일 위에 헬퍼 추가)

**Interfaces:**
- Consumes: Task 1의 `PotionParams`, `Ingredient`, `makePotion`, `judgePotion`, `PotionRules`, `PotionOutcomeInfo`
- Produces:
  - `class PotionEvent { final String name; final PotionOutcome? outcome; }` — `name`: `lever_open`, `lever_close`, `tank_empty`, `exact`, `over`, `under`, `potion_normal|shiny|gold|swollen|tiny`
  - `enum SessionPhase { waitClosed, pouring, confirming, awaitClose, transition, potionResult, finished }`
  - `class PotionSession(PotionParams params, {Random? rng})`
    - `List<PotionEvent> update(double dt, double lever)`
    - getters: `SessionPhase phase`, `double phaseTime`, `List<Ingredient> currentPotion`, `int index`, `Ingredient current`, `double lever`, `bool leverOpen`, `double flowStrength` (0~1), `double confirmProgress` (0~1), `int potionsDone`, `int stars`, `int score`, `int reps`, `int hits`, `int misses`, `double elapsed`, `PotionOutcome? lastOutcome`, `List<PotionOutcome> shelf`, `bool isFinished`, `int maxPossibleScore`, `double accuracy`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/potion_maker_logic_test.dart`의 `_ing` 헬퍼 아래(= `void main()` 위)에 추가:

```dart
/// 큰 통 1개 + 작은 병 1개(목표 0.5, 허용 오차 0.1), 물약 1개가 목표인 세션.
const _twoStep = PotionParams(
    potionGoal: 1, ingredientsPerPotion: 2, smallPerPotion: 1, tolerance: 0.1,
    smallFlowRate: 0.25, bigTankPourTime: 2.0, targetLines: [0.5]);

/// lever를 seconds 동안 60fps로 유지하고, 그동안 나온 이벤트 이름을 돌려준다.
List<String> _hold(PotionSession s, double lever, double seconds) {
  final names = <String>[];
  for (var i = 0; i < (seconds * 60).round(); i++) {
    names.addAll(s.update(1 / 60, lever).map((e) => e.name));
  }
  return names;
}

/// 첫 재료(큰 통)를 비우고, 두 번째 재료(작은 병)를 붓기 시작할 수 있는 상태로 만든다.
PotionSession _atSmallBottle({PotionParams params = _twoStep}) {
  final s = PotionSession(params, rng: Random(0));
  _hold(s, 0.0, 0.05); // 레버 닫힘 → 붓기 시작
  _hold(s, 0.9, 2.2); // 큰 통 비움
  _hold(s, 0.0, 1.2); // 닫기 → 1초 전환 → 다음 재료
  return s;
}
```

`main()` 안의 마지막 `group` 뒤에 추가:

```dart
  group('PotionSession', () {
    test('새 재료는 레버가 닫혀야 시작한다', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      _hold(s, 0.9, 3.0);
      expect(s.phase, SessionPhase.waitClosed);
      expect(s.current.amount, 0);
      _hold(s, 0.0, 0.05);
      expect(s.phase, SessionPhase.pouring);
    });

    test('큰 통은 0.80 미만에서 흐르지 않고, 이상에서 bigTankPourTime 뒤 비워진다', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      _hold(s, 0.0, 0.05);
      _hold(s, 0.7, 3.0);
      expect(s.current.amount, 0);
      expect(_hold(s, 0.9, 2.1), contains('tank_empty'));
      expect(s.current.result, PourResult.emptied);
      expect(s.score, 50);
    });

    test('큰 통은 나눠 부어도 흐른 시간의 합이 같으면 비워진다', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      _hold(s, 0.0, 0.05);
      _hold(s, 0.9, 1.0);
      _hold(s, 0.0, 0.5);
      expect(s.current.result, isNull);
      expect(_hold(s, 0.9, 1.1), contains('tank_empty'));
      expect(s.reps, 1);
    });

    test('닫힘 구간에서는 흐르지 않는다', () {
      final s = _atSmallBottle();
      _hold(s, 0.14, 2.0);
      expect(s.current.amount, 0);
      expect(s.flowStrength, 0);
    });

    test('작은 병의 흐름 속도는 레버 열림에 비례한다', () {
      final full = _atSmallBottle();
      _hold(full, 1.0, 0.4);
      expect(full.current.amount, closeTo(0.10, 0.005));
      expect(full.flowStrength, closeTo(1.0, 1e-9));

      final half = _atSmallBottle();
      _hold(half, 0.575, 0.4);
      expect(half.current.amount, closeTo(0.05, 0.005));
      expect(half.flowStrength, closeTo(0.5, 1e-9));
    });

    test('목표 + 허용 오차를 넘는 순간 과다가 되고 더 흐르지 않는다', () {
      final s = _atSmallBottle();
      expect(_hold(s, 1.0, 3.0), contains('over'));
      expect(s.current.result, PourResult.over);
      expect(s.phase, SessionPhase.awaitClose);
      expect(s.current.amount, closeTo(0.6, 0.01));
    });

    test('닫고 1초 뒤 정확 판정 — 크게 열었으니 황금 물약', () {
      final s = _atSmallBottle();
      _hold(s, 1.0, 2.0); // 0.5
      _hold(s, 0.0, 0.5);
      expect(s.phase, SessionPhase.confirming);
      expect(s.confirmProgress, greaterThan(0));
      expect(_hold(s, 0.0, 0.6), containsAllInOrder(['exact', 'potion_gold']));
      expect(s.score, 50 + 150 + 200);
      expect(s.stars, 3);
      expect(s.shelf, [PotionOutcome.gold]);
      expect(s.potionsDone, 1);
      expect(s.hits, 2);
    });

    test('확정 대기 중 다시 열면 이어서 붓는다', () {
      final s = _atSmallBottle();
      _hold(s, 1.0, 1.2); // 0.3
      _hold(s, 0.0, 0.5); // 확정 대기
      _hold(s, 1.0, 0.8); // 다시 열기 → 약 0.5
      expect(s.phase, SessionPhase.pouring);
      final events = _hold(s, 0.0, 1.2);
      expect(events, contains('exact'));
      expect(events, isNot(contains('under')));
    });

    test('모자란 채로 1초가 지나면 과소 → 콩알 생물, 별·선반 없음', () {
      final s = _atSmallBottle();
      _hold(s, 1.0, 1.0); // 0.25
      expect(_hold(s, 0.0, 1.2), containsAllInOrder(['under', 'potion_tiny']));
      expect(s.stars, 0);
      expect(s.shelf, isEmpty);
      expect(s.potionsDone, 1); // 엉뚱한 결과물도 개수에 포함
      expect(s.misses, 1);
    });

    test('넘친 뒤 레버를 닫으면 부푼 생물', () {
      final s = _atSmallBottle();
      _hold(s, 1.0, 3.0);
      expect(_hold(s, 0.0, 0.1), contains('potion_swollen'));
    });

    test('0.12~0.18 사이 떨림은 열림/닫힘 상태를 바꾸지 않는다', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      _hold(s, 0.0, 0.05);
      expect(_hold(s, 0.17, 0.5), isNot(contains('lever_open')));
      expect(_hold(s, 0.5, 0.1), contains('lever_open'));
      expect(_hold(s, 0.13, 0.5), isNot(contains('lever_close')));
      expect(_hold(s, 0.11, 0.1), contains('lever_close'));
      expect(s.reps, 1);
    });

    test('재료마다 최대 열림을 기록한다', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      _hold(s, 0.0, 0.05);
      _hold(s, 0.95, 0.5);
      _hold(s, 0.85, 0.5);
      expect(s.current.maxOpening, closeTo(0.95, 1e-9));
    });

    test('목표 물약 수를 채우고 결과 연출이 끝나면 종료', () {
      final s = _atSmallBottle();
      _hold(s, 1.0, 2.0);
      _hold(s, 0.0, 1.1);
      expect(s.phase, SessionPhase.potionResult);
      expect(s.isFinished, isFalse);
      _hold(s, 0.0, PotionRules.resultTime + 0.1);
      expect(s.isFinished, isTrue);
    });

    test('목표가 남았으면 결과 연출 뒤 새 물약을 시작한다', () {
      const params = PotionParams(
          potionGoal: 2, ingredientsPerPotion: 2, smallPerPotion: 1, tolerance: 0.1,
          smallFlowRate: 0.25, bigTankPourTime: 2.0, targetLines: [0.5]);
      final s = _atSmallBottle(params: params);
      _hold(s, 1.0, 2.0);
      _hold(s, 0.0, 1.1);
      _hold(s, 0.0, PotionRules.resultTime + 0.1);
      expect(s.isFinished, isFalse);
      expect(s.index, 0);
      expect(s.current.kind, ContainerKind.bigTank);
      expect(s.current.amount, 0);
    });

    test('8분이 지나면 종료', () {
      const params = PotionParams(
          potionGoal: 100, ingredientsPerPotion: 2, smallPerPotion: 1, tolerance: 0.1,
          smallFlowRate: 0.25, bigTankPourTime: 2.0, targetLines: [0.5]);
      final s = PotionSession(params, rng: Random(0));
      for (var i = 0; i < 479; i++) {
        s.update(1.0, 0.0);
      }
      expect(s.isFinished, isFalse);
      s.update(1.0, 0.0);
      expect(s.isFinished, isTrue);
    });

    test('최대 점수와 시작 시 정확도', () {
      final s = PotionSession(_twoStep, rng: Random(0));
      expect(s.maxPossibleScore, 50 + 150 + 200);
      expect(s.accuracy, 0);
    });
  });
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `flutter test test/potion_maker_logic_test.dart`
Expected: FAIL — `PotionSession`, `SessionPhase`가 정의되지 않았다는 컴파일 오류

- [ ] **Step 3: 세션 코드 추가**

`lib/games/games/potion_maker_logic.dart` 파일 끝에 추가:

```dart
/// 화면에 알리는 이벤트. name은 AngleRecord.event에 그대로 기록한다 (가이드 3-7).
class PotionEvent {
  final String name;
  final PotionOutcome? outcome;
  const PotionEvent(this.name, {this.outcome});
}

enum SessionPhase {
  waitClosed, // 새 재료: 레버가 닫히길 기다림
  pouring, // 붓는 중
  confirming, // 작은 병: 닫고 1초 확정 대기
  awaitClose, // 과다·큰 통 비움 뒤 레버 닫기 대기
  transition, // 다음 재료로 전환 (입력 무시)
  potionResult, // 물약 결과 연출 (입력 무시)
  finished,
}

/// 한 판의 진행 상태. 화면은 매 프레임 update(dt, lever)를 부르고 이벤트로 연출만 한다.
class PotionSession {
  final PotionParams params;
  final Random _rng;

  PotionSession(this.params, {Random? rng}) : _rng = rng ?? Random() {
    _potion = makePotion(params, _rng);
  }

  late List<Ingredient> _potion;
  int _index = 0;
  SessionPhase _phase = SessionPhase.waitClosed;
  double _phaseTime = 0;
  double _elapsed = 0;
  double _lever = 0;
  bool _leverOpen = false;
  double _flow = 0;
  int _potionsDone = 0;
  int _stars = 0;
  int _score = 0;
  int _reps = 0;
  int _hits = 0;
  int _misses = 0;
  PotionOutcome? _lastOutcome;
  final List<PotionOutcome> _shelf = [];

  SessionPhase get phase => _phase;
  double get phaseTime => _phaseTime;
  List<Ingredient> get currentPotion => List.unmodifiable(_potion);
  int get index => _index;
  Ingredient get current => _potion[_index];
  double get lever => _lever;
  bool get leverOpen => _leverOpen;

  /// 지금 흐르는 세기 0~1 (줄기 굵기용).
  double get flowStrength => _flow;

  double get confirmProgress => _phase == SessionPhase.confirming
      ? (_phaseTime / PotionRules.confirmTime).clamp(0.0, 1.0)
      : 0;

  int get potionsDone => _potionsDone;
  int get stars => _stars;
  int get score => _score;
  int get reps => _reps;
  int get hits => _hits;
  int get misses => _misses;
  double get elapsed => _elapsed;
  PotionOutcome? get lastOutcome => _lastOutcome;
  List<PotionOutcome> get shelf => List.unmodifiable(_shelf);
  bool get isFinished => _phase == SessionPhase.finished;
  double get accuracy => (_hits + _misses) == 0 ? 0 : _hits / (_hits + _misses);

  int get maxPossibleScore {
    final small = params.smallPerPotion;
    final big = params.ingredientsPerPotion - small;
    final perPotion = big * PotionRules.tankScore +
        small * (PotionRules.exactScore + PotionRules.exactBonusMax) +
        PotionOutcome.gold.bonus;
    return params.potionGoal * perPotion;
  }

  /// lever = 레버 열림 o (0~1). 이번 프레임에 생긴 이벤트를 돌려준다.
  List<PotionEvent> update(double dt, double lever) {
    final events = <PotionEvent>[];
    if (_phase == SessionPhase.finished) return events;

    _lever = lever.clamp(0.0, 1.0);
    _elapsed += dt;
    _phaseTime += dt;
    _flow = 0;
    _updateLeverState(events);

    switch (_phase) {
      case SessionPhase.waitClosed:
        if (!_leverOpen) _enter(SessionPhase.pouring);
      case SessionPhase.pouring:
        _pour(dt, events);
      case SessionPhase.confirming:
        _confirm(events);
      case SessionPhase.awaitClose:
        if (!_leverOpen) _finishIngredient(events);
      case SessionPhase.transition:
        if (_phaseTime >= PotionRules.transitionTime) {
          _index++;
          _enter(SessionPhase.waitClosed);
        }
      case SessionPhase.potionResult:
        if (_phaseTime >= PotionRules.resultTime) _nextPotion();
      case SessionPhase.finished:
        break;
    }

    if (_phase != SessionPhase.finished && _elapsed >= PotionRules.maxSessionSeconds) {
      _enter(SessionPhase.finished);
    }
    return events;
  }

  void _enter(SessionPhase phase) {
    _phase = phase;
    _phaseTime = 0;
  }

  void _updateLeverState(List<PotionEvent> events) {
    if (!_leverOpen && _lever >= PotionRules.openAt) {
      _leverOpen = true;
      events.add(const PotionEvent('lever_open'));
    } else if (_leverOpen && _lever < PotionRules.closeAt) {
      _leverOpen = false;
      _reps++;
      events.add(const PotionEvent('lever_close'));
    }
  }

  /// 흐름은 레버가 '열림' 상태일 때만 계산한다 (닫힘 상태에서는 흐르지 않음).
  void _pour(double dt, List<PotionEvent> events) {
    final ing = current;
    if (!_leverOpen) {
      if (ing.kind == ContainerKind.smallBottle && ing.amount > 0) {
        _enter(SessionPhase.confirming);
      }
      return;
    }
    ing.maxOpening = max(ing.maxOpening, _lever);

    if (ing.kind == ContainerKind.bigTank) {
      if (_lever < PotionRules.bigTankZone) return;
      _flow = 1.0;
      ing.amount = min(1.0, ing.amount + dt / params.bigTankPourTime);
      if (ing.amount >= 1.0) {
        ing.result = PourResult.emptied;
        _hits++;
        _score += PotionRules.tankScore;
        events.add(const PotionEvent('tank_empty'));
        _enter(SessionPhase.awaitClose);
      }
      return;
    }

    if (_lever <= PotionRules.closedBelow) return;
    _flow = (_lever - PotionRules.closedBelow) / (1 - PotionRules.closedBelow);
    ing.amount += params.smallFlowRate * _flow * dt;
    if (ing.amount > ing.target + params.tolerance) {
      ing.result = PourResult.over;
      _misses++;
      events.add(const PotionEvent('over'));
      _enter(SessionPhase.awaitClose);
    }
  }

  void _confirm(List<PotionEvent> events) {
    if (_leverOpen) {
      _enter(SessionPhase.pouring); // 모자라면 더 부을 수 있다
      return;
    }
    if (_phaseTime < PotionRules.confirmTime) return;

    final ing = current;
    if (ing.error <= params.tolerance) {
      ing.result = PourResult.exact;
      _hits++;
      _score += PotionRules.exactScore +
          (PotionRules.exactBonusMax * (1 - ing.error / params.tolerance)).round();
      events.add(const PotionEvent('exact'));
    } else {
      ing.result = PourResult.under;
      _misses++;
      events.add(const PotionEvent('under'));
    }
    _finishIngredient(events);
  }

  void _finishIngredient(List<PotionEvent> events) {
    if (_index < _potion.length - 1) {
      _enter(SessionPhase.transition);
      return;
    }
    final outcome = judgePotion(_potion);
    _lastOutcome = outcome;
    _potionsDone++;
    if (outcome.isSuccess) {
      _stars += outcome.stars;
      _score += outcome.bonus;
      _shelf.add(outcome);
    }
    events.add(PotionEvent(outcome.eventName, outcome: outcome));
    _enter(SessionPhase.potionResult);
  }

  void _nextPotion() {
    if (_potionsDone >= params.potionGoal) {
      _enter(SessionPhase.finished);
      return;
    }
    _potion = makePotion(params, _rng);
    _index = 0;
    _enter(SessionPhase.waitClosed);
  }
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `flutter test test/potion_maker_logic_test.dart`
Expected: PASS — `All tests passed!` (Task 1의 10개 + 16개 = 26개)

- [ ] **Step 5: 정적 분석**

Run: `flutter analyze lib/games/games/potion_maker_logic.dart test/potion_maker_logic_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/games/games/potion_maker_logic.dart test/potion_maker_logic_test.dart
git commit -m "feat: 포션메이커 v2 규칙 — 세션 상태 기계·점수·종료 조건

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 화면 — `potion_maker_game.dart` 전체 재작성

**Files:**
- Modify (전체 교체): `lib/games/games/potion_maker_game.dart`

**Interfaces:**
- Consumes: Task 2의 `PotionSession`와 getter 전부, `PotionEvent.name`, `PotionRules`, `PotionOutcomeInfo`; `GameMotorController`(`angleStream`, `selectJoint`, `startWatchdog`, `safeStop`, `emergencyStop`, `dispose`); `GameResult`, `AngleRecord`; `GameResultScreen(result:)`; `AppLocalizations.pauseGame`, `.stop`
- Produces: `class PotionMakerGame extends StatefulWidget` — 생성자 `PotionMakerGame({Key? key, required BluetoothService bluetoothService, required GameConfig config})` (허브가 쓰는 시그니처 그대로)

이 태스크는 Canvas 렌더링이라 자동 테스트 대신 **정적 분석 + 사용자 수동 확인**으로 검증한다.

- [ ] **Step 1: 기존 파일 내용 확인**

Run: `git diff --stat lib/games/games/potion_maker_game.dart`
Expected: 커밋 안 된 변경은 `const` 린트 수정뿐(24줄). 파일 전체를 새로 쓰므로 버려도 된다. 이와 다른 변경이 보이면 멈추고 사용자에게 묻는다.

- [ ] **Step 2: 파일 전체를 아래 내용으로 교체**

`lib/games/games/potion_maker_game.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../bluetooth.dart';
import '../../generated/l10n.dart';
import '../game_base.dart';
import '../game_motor_controller.dart';
import '../game_result_screen.dart';
import 'potion_maker_logic.dart';

/// ============================================================================
/// [E3] 물약 제조 (Potion Maker) v2 — 화면
/// 관절: 어깨 안쪽/가쪽돌림 (lShoulderRo), 팔꿈치 90° (로봇 고정은 펌웨어 준비 후)
/// 메카닉: 가쪽돌림으로 재료통 레버를 열어 유리 플라스크에 재료를 층층이 붓는다.
/// 규칙은 potion_maker_logic.dart, 설계는 docs/potion_maker_build_guide.md
/// Phase 1: 스프라이트 없이 Canvas 도형 (좌표는 1600×900 기준, 목업과 같음)
/// ============================================================================

// ─── 색 (가이드 5-1) ───
const _ink = Color(0xFF3B2A1A);
const _wood = Color(0xFFC68B59);
const _cream = Color(0xFFFFF7E6);
const _creamDeep = Color(0xFFFFE2B0);
const _targetColor = Color(0xFFE64A19);
const _goodColor = Color(0xFF2E7D32);
const _zoneClosed = Color(0xFF9E9E9E);
const _zoneFlow = Color(0xFF1E88E5);
const _zoneWide = Color(0xFFFFB300);
const _layerColors = [
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFFD81B60),
];

// ─── 기준 좌표 (1600×900) ───
const _designW = 1600.0;
const _designH = 900.0;
const _flaskCenter = Offset(800, 620);
const _flaskR = 204.0; // 안쪽 반지름
const _flaskBottom = 824.0; // 620 + 204
const _flaskH = 408.0; // 안쪽 높이 H
const _doneLayerH = 0.06 * _flaskH; // 끝난 층 두께
const _slotH = 0.6 * _flaskH; // 지금 붓는 층 칸
const _fillLine = 0.84 * _flaskH; // 완성 시 "딱 맞는 높이"
const _spreadTime = 1.0; // 완성 시 층 펼치기(초)
const _pivot = Offset(800, 225); // 레버 회전축
const _leverRx = 110.0;
const _leverRy = 34.0;
const _popupAt = Offset(1330, 400);

Color _colorOf(int i) => _layerColors[i % _layerColors.length];

Paint _outline(double width) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// at: 왼쪽(center면 가운데) · 세로 가운데 기준.
void _text(Canvas c, String t, Offset at, double fontSize, Color color,
    {bool center = false, bool bold = false, Color? outline}) {
  TextPainter painter(TextStyle style) =>
      TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)
        ..layout();
  final weight = bold ? FontWeight.bold : FontWeight.normal;
  final fill = painter(TextStyle(fontSize: fontSize, color: color, fontWeight: weight));
  final origin = at - Offset(center ? fill.width / 2 : 0, fill.height / 2);
  if (outline != null) {
    painter(TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = outline,
    )).paint(c, origin);
  }
  fill.paint(c, origin);
}

void _dashedLine(Canvas c, Offset a, Offset b, Paint paint, {double dash = 14, double gap = 8}) {
  final length = (b - a).distance;
  final dir = (b - a) / length;
  for (var d = 0.0; d < length; d += dash + gap) {
    c.drawLine(a + dir * d, a + dir * min(d + dash, length), paint);
  }
}

class _Popup {
  final String text;
  final Color color;
  double life = 0;
  _Popup(this.text, this.color);
}

class _Drop {
  Offset pos;
  double vy = 0;
  final Color color;
  _Drop(this.pos, this.color);
}

class PotionMakerFlameGame extends FlameGame {
  final Stream<double>? rawAngleStream;
  final GameConfig config;
  final bool showElbowGuide;
  final void Function(GameResult) onGameEnd;

  late final PotionSession session;
  final Random _rng = Random();
  StreamSubscription<double>? _sub;

  double _raw = 0; // 마지막 원시 각도
  double _p = 0; // 정규화 위치 (0 = 안쪽 끝, 1 = 바깥 끝)
  double _countdown = 3.0;
  bool _started = false;
  bool paused = false;
  bool _ended = false;
  double _recordClock = 0;
  double _dropClock = 0;
  double _stackTop = _flaskBottom; // 플라스크 층 맨 위 y (render에서 갱신)
  final List<AngleRecord> _history = [];
  final List<_Popup> _popups = [];
  final List<_Drop> _drops = [];

  PotionMakerFlameGame({
    this.rawAngleStream,
    required this.config,
    required this.onGameEnd,
    this.showElbowGuide = false,
  });

  @override
  Color backgroundColor() => _cream;

  /// 레버 열림 o = clamp(p / romRatio, 0, 1) (가이드 2-1)
  double get lever => (_p / config.romRatio).clamp(0.0, 1.0);

  @override
  Future<void> onLoad() async {
    session = PotionSession(PotionParams.fromConfig(config));
    _sub = rawAngleStream?.listen((a) {
      _raw = a;
      _p = config.normalizer.normalize(a);
    });
  }

  void setSimPosition(double v) {
    _p = v.clamp(0.0, 1.0);
    _raw = config.normalizer.denormalize(_p);
  }

  void togglePause() => paused = !paused;

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded || _ended || paused) return;
    _updateEffects(dt);
    if (!_started) {
      _countdown -= dt;
      if (_countdown <= 0) _started = true;
      return;
    }
    final events = session.update(dt, lever);
    for (final e in events) {
      _onEvent(e);
    }
    _record(dt, events);
    _spawnDrops(dt);
    if (session.isFinished) endGame();
  }

  void _onEvent(PotionEvent e) {
    switch (e.name) {
      case 'tank_empty':
        _popups.add(_Popup('다 부었어요!', _goodColor));
      case 'exact':
        _popups.add(_Popup('딱 맞아요!', _goodColor));
      case 'over':
        _popups.add(_Popup('조금 넘쳤어요', _targetColor));
      case 'under':
        _popups.add(_Popup('조금 모자라요', _targetColor));
    }
  }

  /// 20Hz로 기록하고, 이벤트가 있는 프레임은 항상 기록한다.
  void _record(double dt, List<PotionEvent> events) {
    _recordClock += dt;
    if (_recordClock < 0.05 && events.isEmpty) return;
    _recordClock = 0;
    _history.add(AngleRecord(
      timestampMs: (session.elapsed * 1000).round(),
      rawAngle: _raw,
      normalizedPosition: _p,
      event: events.map((e) => e.name).join('|'),
    ));
  }

  void _spawnDrops(double dt) {
    if (config.cognitiveLevel.particleCount == 0 || session.flowStrength == 0) return;
    _dropClock += dt;
    if (_dropClock < 0.08) return;
    _dropClock = 0;
    _drops.add(_Drop(Offset(800 + (_rng.nextDouble() - 0.5) * 30, 250), _colorOf(session.index)));
  }

  void _updateEffects(double dt) {
    for (final p in _popups) {
      p.life += dt;
    }
    _popups.removeWhere((p) => p.life > 1.2);
    for (final d in _drops) {
      d.vy += 900 * dt;
      d.pos = d.pos.translate(0, d.vy * dt);
    }
    _drops.removeWhere((d) => d.pos.dy >= _stackTop);
  }

  void endGame() {
    if (_ended || !isLoaded) return;
    _ended = true;
    _sub?.cancel();
    onGameEnd(GameResult(
      gameId: 'potion_maker',
      score: session.score,
      maxPossibleScore: session.maxPossibleScore,
      accuracy: session.accuracy,
      duration: Duration(milliseconds: (session.elapsed * 1000).round()),
      difficultyLevel: config.difficultyLevel,
      bodyPart: config.bodyPart,
      timestamp: DateTime.now(),
      calibrationMin: config.normalizer.minAngle,
      calibrationMax: config.normalizer.maxAngle,
      hits: session.hits,
      misses: session.misses,
      angleHistory: List.unmodifiable(_history),
    ));
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }

  // ─── 렌더 (가이드 5-5 순서) ───

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isLoaded) return;
    final s = min(size.x / _designW, size.y / _designH);
    canvas.save();
    canvas.translate((size.x - _designW * s) / 2, (size.y - _designH * s) / 2);
    canvas.scale(s);

    _drawBackground(canvas);
    _drawShelf(canvas);
    _drawStand(canvas);
    _drawFlask(canvas);
    _drawTarget(canvas);
    _drawStream(canvas);
    _drawContainer(canvas);
    _drawLever(canvas);
    _drawResult(canvas);
    _drawHud(canvas);
    _drawGuide(canvas);
    _drawPopups(canvas);
    if (showElbowGuide) _drawElbowBanner(canvas);
    if (paused) _drawOverlay(canvas, '일시정지', null);
    if (!_started) {
      final n = _countdown.ceil().clamp(1, 3);
      _drawOverlay(canvas, '$n', '레버를 닫고 준비하세요!');
    }
    canvas.restore();
  }

  void _drawBackground(Canvas c) {
    const rect = Rect.fromLTWH(0, 0, _designW, _designH);
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cream, _creamDeep],
          ).createShader(rect));
    final window = Path()
      ..moveTo(1060, 520)
      ..lineTo(1060, 330)
      ..quadraticBezierTo(1150, 250, 1240, 330)
      ..lineTo(1240, 520)
      ..close();
    c.drawPath(window, Paint()..color = const Color(0xFFBFE6FF));
    c.drawPath(window, _outline(6));
    c.drawLine(const Offset(1150, 290), const Offset(1150, 520), _outline(5));
    c.drawRect(const Rect.fromLTWH(0, 850, _designW, 50), Paint()..color = _wood);
    c.drawLine(const Offset(0, 850), const Offset(_designW, 850), _outline(6));
  }

  Offset _shelfSlot(int i) => Offset(90 + (i % 4) * 80.0, (i < 4 ? 540.0 : 400.0) - 36);

  void _drawShelf(Canvas c) {
    for (final y in const [400.0, 540.0]) {
      final plank = Rect.fromLTWH(40, y, 330, 20);
      c.drawRect(plank, Paint()..color = _wood);
      c.drawRect(plank, _outline(5));
    }
    _text(c, '성공한 생물 선반', const Offset(40, 590), 24, const Color(0xFF6D4C41));
    var shelf = session.shelf;
    // 결과 연출 중인 생물은 아직 날아가는 중이므로 선반에 그리지 않는다.
    if (session.phase == SessionPhase.potionResult && (session.lastOutcome?.isSuccess ?? false)) {
      shelf = shelf.sublist(0, shelf.length - 1);
    }
    for (var i = 0; i < shelf.length && i < 8; i++) {
      _drawCreature(c, _shelfSlot(i), shelf[i], 0.85);
    }
  }

  void _drawCreature(Canvas c, Offset at, PotionOutcome kind, double scale, {double alpha = 1}) {
    final r = 34 * scale;
    final body = switch (kind) {
      PotionOutcome.gold => const Color(0xFFFFC107),
      PotionOutcome.shiny => const Color(0xFF4DD0E1),
      PotionOutcome.normal => const Color(0xFF81C784),
      PotionOutcome.swollen => const Color(0xFFF06292),
      PotionOutcome.tiny => const Color(0xFFB39DDB),
    };
    final ink = _ink.withValues(alpha: alpha);
    c.drawCircle(at, r, Paint()..color = body.withValues(alpha: alpha));
    c.drawCircle(at, r, _outline(max(2.0, 5 * scale))..color = ink);
    final eye = Paint()..color = ink;
    c.drawCircle(at + Offset(-10 * scale, -7 * scale), 6 * scale, eye);
    c.drawCircle(at + Offset(10 * scale, -7 * scale), 6 * scale, eye);

    if (kind == PotionOutcome.gold) {
      final top = at.dy - r;
      final crown = Path()
        ..moveTo(at.dx - 22 * scale, top + 2 * scale)
        ..lineTo(at.dx - 15 * scale, top - 16 * scale)
        ..lineTo(at.dx - 7 * scale, top - 4 * scale)
        ..lineTo(at.dx, top - 22 * scale)
        ..lineTo(at.dx + 7 * scale, top - 4 * scale)
        ..lineTo(at.dx + 15 * scale, top - 16 * scale)
        ..lineTo(at.dx + 22 * scale, top + 2 * scale)
        ..close();
      c.drawPath(crown, Paint()..color = _zoneWide.withValues(alpha: alpha));
      c.drawPath(crown, _outline(3)..color = ink);
    }
    if (kind == PotionOutcome.shiny || kind == PotionOutcome.gold) {
      final spark = Paint()
        ..color = const Color(0xFFFF8F00).withValues(alpha: alpha)
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 4; k++) {
        final a = k * pi / 2 + pi / 4;
        final p = at + Offset(cos(a), sin(a)) * (r + 12 * scale);
        c.drawLine(p - Offset(0, 6 * scale), p + Offset(0, 6 * scale), spark);
        c.drawLine(p - Offset(6 * scale, 0), p + Offset(6 * scale, 0), spark);
      }
    }
  }

  void _drawStand(Canvas c) {
    final stand = RRect.fromRectAndRadius(
        const Rect.fromLTWH(660, 826, 280, 26), const Radius.circular(8));
    c.drawRRect(stand, Paint()..color = const Color(0xFF8D6E63));
    c.drawRRect(stand, _outline(5));
  }

  Path _flaskPath() => Path()
    ..addOval(Rect.fromCircle(center: _flaskCenter, radius: _flaskR))
    ..addRect(const Rect.fromLTWH(745, 330, 110, 100));

  double _slotBase() => _flaskBottom - session.index * _doneLayerH;

  /// 층 두께 (가이드 5-3): 끝난 층은 얇게, 지금 층은 0.6H 칸, 완성 시 실제 비율로 펼침.
  List<double> _layerThickness() {
    final potion = session.currentPotion;
    final idx = session.index;
    final phase = session.phase;
    double compressed(int i) {
      if (i < idx) return _doneLayerH;
      if (i > idx) return 0;
      final full = potion[i].amount * _slotH;
      if (phase == SessionPhase.transition) {
        final t = (session.phaseTime / PotionRules.transitionTime).clamp(0.0, 1.0);
        return full + (_doneLayerH - full) * t;
      }
      return full;
    }

    final th = [for (var i = 0; i < potion.length; i++) compressed(i)];
    if (phase == SessionPhase.potionResult) {
      final totalTarget = potion.fold<double>(0, (sum, g) => sum + g.target);
      final unit = _fillLine / totalTarget;
      final t = (session.phaseTime / _spreadTime).clamp(0.0, 1.0);
      for (var i = 0; i < potion.length; i++) {
        th[i] += (potion[i].amount * unit - th[i]) * t;
      }
    }
    return th;
  }

  void _drawFlask(Canvas c) {
    final glass = Paint()..color = Colors.white.withValues(alpha: 0.45);
    c.drawRect(const Rect.fromLTWH(742, 330, 116, 100), glass);
    c.drawCircle(_flaskCenter, _flaskR + 4, glass);

    final th = _layerThickness();
    c.save();
    c.clipPath(_flaskPath());
    var y = _flaskBottom;
    for (var i = 0; i < th.length; i++) {
      if (th[i] <= 0.5) continue;
      final top = y - th[i];
      c.drawRect(Rect.fromLTRB(_flaskCenter.dx - _flaskR, top, _flaskCenter.dx + _flaskR, y),
          Paint()..color = _colorOf(i));
      c.drawLine(Offset(_flaskCenter.dx - _flaskR, top), Offset(_flaskCenter.dx + _flaskR, top),
          _outline(3));
      y = top;
    }
    c.restore();
    _stackTop = y;

    // 유리 외곽선: 목은 양옆 선과 입구만 그려 몸통 원 안에 가로선이 생기지 않게 한다.
    c.drawPath(
        Path()
          ..moveTo(742, 422)
          ..lineTo(742, 330)
          ..lineTo(858, 330)
          ..lineTo(858, 422),
        _outline(7));
    c.drawCircle(_flaskCenter, _flaskR + 4, _outline(7));

    if (session.phase == SessionPhase.potionResult) {
      final fy = _flaskBottom - _fillLine;
      _dashedLine(c, Offset(620, fy), Offset(980, fy), Paint()
        ..color = _goodColor
        ..strokeWidth = 6);
      _text(c, '← 딱 맞는 높이', Offset(1010, fy), 26, _goodColor, bold: true);
    }
  }

  void _drawTarget(Canvas c) {
    const showIn = {
      SessionPhase.waitClosed,
      SessionPhase.pouring,
      SessionPhase.confirming,
      SessionPhase.awaitClose,
    };
    final ing = session.current;
    if (ing.kind != ContainerKind.smallBottle || !showIn.contains(session.phase)) return;
    final base = _slotBase();
    final tol = session.params.tolerance;
    final y = base - ing.target * _slotH;

    c.save();
    c.clipPath(_flaskPath());
    c.drawRect(
        Rect.fromLTRB(_flaskCenter.dx - _flaskR, base - (ing.target + tol) * _slotH,
            _flaskCenter.dx + _flaskR, base - (ing.target - tol) * _slotH),
        Paint()..color = _targetColor.withValues(alpha: 0.18));
    c.restore();
    _dashedLine(c, Offset(600, y), Offset(1000, y), Paint()
      ..color = _targetColor
      ..strokeWidth = 7);
    _text(c, '← 목표선', Offset(1065, y), 28, _targetColor, bold: true);

    final progress = session.confirmProgress;
    if (progress > 0) {
      final ring = Rect.fromCircle(center: Offset(1035, y), radius: 16);
      c.drawCircle(ring.center, 16, _outline(4)..color = _ink.withValues(alpha: 0.25));
      c.drawArc(ring, -pi / 2, 2 * pi * progress, false, Paint()
        ..color = _targetColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6);
    }
  }

  void _drawStream(Canvas c) {
    final f = session.flowStrength;
    if (f > 0) {
      final w = 6 + 14 * f;
      c.drawRect(Rect.fromLTRB(800 - w / 2, 240, 800 + w / 2, _stackTop),
          Paint()..color = _colorOf(session.index));
    }
    for (final d in _drops) {
      c.drawCircle(d.pos, 6, Paint()..color = d.color);
    }
  }

  void _drawContainer(Canvas c) {
    final phase = session.phase;
    if (phase == SessionPhase.potionResult) return;
    final ing = session.current;
    final alpha = phase == SessionPhase.transition
        ? 1 - (session.phaseTime / PotionRules.transitionTime).clamp(0.0, 1.0)
        : 1.0;
    final big = ing.kind == ContainerKind.bigTank;
    final body = big ? const Rect.fromLTWH(690, 20, 220, 180) : const Rect.fromLTWH(720, 50, 160, 150);
    final shape = RRect.fromRectAndRadius(body, const Radius.circular(30));
    c.drawRRect(shape, Paint()..color = Colors.white.withValues(alpha: 0.6 * alpha));

    // 남은 액체: 큰 통은 1 - 양, 작은 병은 (목표 + 허용 오차)를 다 담은 병으로 보고 줄어든다.
    final left = big ? 1 - ing.amount : 1 - ing.amount / (ing.target + session.params.tolerance);
    final inner = body.deflate(10);
    final h = inner.height * left.clamp(0.0, 1.0);
    if (h > 0) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(inner.left, inner.bottom - h, inner.right, inner.bottom),
              const Radius.circular(18)),
          Paint()..color = _colorOf(session.index).withValues(alpha: alpha));
    }
    c.drawRRect(shape, _outline(6)..color = _ink.withValues(alpha: alpha));
    _text(c, big ? '큰 통' : '작은 병', Offset(body.left - 120, body.center.dy), 30,
        _colorOf(session.index).withValues(alpha: alpha),
        bold: true);
  }

  /// 3/4 뷰 레버. 손잡이는 환자 손과 같은 방향: 가쪽돌림 → 화면 왼쪽 (가이드 5-2).
  void _drawLever(Canvas c) {
    const tap = Rect.fromLTWH(788, 200, 24, 25);
    c.drawRect(tap, Paint()..color = const Color(0xFFB0BEC5));
    c.drawRect(tap, _outline(4));

    final oval = Rect.fromCenter(center: _pivot, width: _leverRx * 2, height: _leverRy * 2);
    void zone(double from, double to, Color color) => c.drawArc(
        oval,
        from * pi,
        (to - from) * pi,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    zone(0, PotionRules.closedBelow, _zoneClosed);
    zone(PotionRules.closedBelow, PotionRules.bigTankZone, _zoneFlow);
    zone(PotionRules.bigTankZone, 1, _zoneWide);

    final t = lever * pi;
    final tip = _pivot + Offset(cos(t) * _leverRx, sin(t) * _leverRy);
    c.drawLine(_pivot, tip, Paint()
      ..color = _ink
      ..strokeWidth = 21
      ..strokeCap = StrokeCap.round);
    c.drawLine(_pivot, tip, Paint()
      ..color = const Color(0xFFFFCC80)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round);
    c.drawCircle(tip, 14, Paint()..color = const Color(0xFFFFB74D));
    c.drawCircle(tip, 14, _outline(4));

    _text(c, '← 열림', const Offset(575, 225), 26, _ink, bold: true);
    _text(c, '닫힘', const Offset(918, 225), 22, const Color(0xFF757575));
    _text(c, '★', const Offset(650, 262), 26, _zoneWide, bold: true, outline: _ink);
  }

  void _drawResult(Canvas c) {
    final o = session.lastOutcome;
    if (session.phase != SessionPhase.potionResult || o == null) return;
    final t = session.phaseTime - _spreadTime; // 처음 1초는 층 펼치기
    if (t < 0) return;

    const start = Offset(800, 330);
    const peak = Offset(800, 230);
    final rise = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));
    var pos = Offset.lerp(start, peak, rise)!;

    if (o == PotionOutcome.gold || o == PotionOutcome.shiny) {
      final burst = (t - 0.4) / 0.8;
      if (burst > 0 && burst < 1) {
        final n = o == PotionOutcome.gold ? 16 : 8;
        for (var k = 0; k < n; k++) {
          final a = 2 * pi * k / n;
          c.drawCircle(peak + Offset(cos(a), sin(a)) * (40 + 160 * burst), 7 * (1 - burst),
              Paint()..color = _colorOf(k));
        }
      }
    }

    switch (o) {
      case PotionOutcome.normal || PotionOutcome.shiny || PotionOutcome.gold:
        final fly = Curves.easeInOut.transform(((t - 0.8) / 1.2).clamp(0.0, 1.0));
        pos = Offset.lerp(pos, _shelfSlot(min(session.shelf.length - 1, 7)), fly)!;
        _drawCreature(c, pos, o, 1.4 - 0.55 * fly);
      case PotionOutcome.swollen:
        final grow = 1 + 0.8 * (t / 0.8).clamp(0.0, 1.0);
        final wobble = 1 + 0.06 * sin(t * 18);
        final drift = ((t - 1.0) / 1.5).clamp(0.0, 1.0);
        pos = pos + Offset(0, -500 * drift);
        _drawCreature(c, pos, o, grow * wobble * 1.4);
        if (t < 1.2) _text(c, '뽀잉!', pos + const Offset(90, -60), 34, _targetColor, bold: true);
      case PotionOutcome.tiny:
        final look = sin(t * 6) * 12;
        final fade = 1 - ((t - 1.5) / 1.0).clamp(0.0, 1.0);
        _drawCreature(c, pos + Offset(look, 0), o, 0.3 * 1.4, alpha: 0.5 * fade);
        if (t < 1.2) _text(c, '뿅', pos + const Offset(40, -40), 30, _ink, bold: true);
    }

    final title = switch (o) {
      PotionOutcome.normal => '물약 완성!',
      PotionOutcome.shiny => '반짝 물약!',
      PotionOutcome.gold => '황금 물약!',
      PotionOutcome.swollen => '뚱뚱한 친구가 나왔어요!',
      PotionOutcome.tiny => '콩알만 한 친구가 나왔어요!',
    };
    _text(c, title, const Offset(800, 140), 44, o.isSuccess ? _goodColor : _ink,
        center: true, bold: true, outline: Colors.white);
  }

  void _drawHud(Canvas c) {
    _text(c, '물약 ${session.potionsDone}/${session.params.potionGoal}', const Offset(40, 60), 46,
        _ink,
        bold: true);
    _text(c, '★ ${session.stars}', const Offset(265, 60), 46, _zoneWide,
        bold: true, outline: _ink);

    final potion = session.currentPotion;
    final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(1290, 30, 280, 70 + 40.0 * potion.length), const Radius.circular(16));
    c.drawRRect(card, Paint()..color = Colors.white);
    c.drawRRect(card, _outline(6));
    _text(c, '레시피', const Offset(1310, 65), 30, _ink, bold: true);
    for (var i = 0; i < potion.length; i++) {
      final ing = potion[i];
      final done = ing.result != null;
      final isCurrent = i == session.index && !done;
      final name = ing.kind == ContainerKind.bigTank ? '큰 통' : '작은 병';
      final mark = done ? ' ✔' : (isCurrent ? ' ◀' : '');
      _text(c, '● $name$mark', Offset(1310, 110 + 40.0 * i), 28, _colorOf(i), bold: isCurrent);
    }
  }

  void _drawGuide(Canvas c) {
    final String text;
    switch (session.phase) {
      case SessionPhase.waitClosed || SessionPhase.awaitClose:
        text = '레버를 닫아 주세요';
      case SessionPhase.pouring || SessionPhase.confirming:
        text = session.current.kind == ContainerKind.bigTank
            ? '레버를 바깥으로 끝까지 열어요'
            : '선에 닿으면 레버를 닫아요';
      default:
        text = '';
    }
    if (text.isEmpty) return;
    _text(c, text, const Offset(800, 876), 32, Colors.white, center: true, bold: true, outline: _ink);
  }

  void _drawPopups(Canvas c) {
    for (final p in _popups) {
      final a = (1 - p.life / 1.2).clamp(0.0, 1.0);
      _text(c, p.text, _popupAt.translate(0, -40 * p.life), 40, p.color.withValues(alpha: a),
          center: true, bold: true, outline: Colors.white.withValues(alpha: a));
    }
  }

  /// 펌웨어 팔꿈치 고정 전까지 실기기에서 보여 주는 안내 (가이드 2-2).
  void _drawElbowBanner(Canvas c) {
    final banner = RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 100, 540, 50), const Radius.circular(25));
    c.drawRRect(banner, Paint()..color = Colors.white.withValues(alpha: 0.9));
    c.drawRRect(banner, _outline(4));
    _text(c, '팔꿈치를 90°로 굽힌 채 유지해 주세요', const Offset(310, 125), 24, _ink,
        center: true, bold: true);
  }

  void _drawOverlay(Canvas c, String big, String? small) {
    c.drawRect(const Rect.fromLTWH(0, 0, _designW, _designH),
        Paint()..color = _ink.withValues(alpha: 0.35));
    _text(c, big, const Offset(800, 420), 140, _zoneWide, center: true, bold: true, outline: _ink);
    if (small != null) {
      _text(c, small, const Offset(800, 560), 36, Colors.white,
          center: true, bold: true, outline: _ink);
    }
  }
}

// ─── Flutter Wrapper ───

class PotionMakerGame extends StatefulWidget {
  final BluetoothService bluetoothService;
  final GameConfig config;
  const PotionMakerGame({super.key, required this.bluetoothService, required this.config});

  @override
  State<PotionMakerGame> createState() => _PotionMakerGameState();
}

class _PotionMakerGameState extends State<PotionMakerGame> {
  late PotionMakerFlameGame _game;
  late GameMotorController _motor;
  double _simValue = 0.0; // 0 = 레버 닫힘에서 시작
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    _isSim = !widget.bluetoothService.isConnected();
    _motor = GameMotorController(bt: widget.bluetoothService);
    _game = PotionMakerFlameGame(
      rawAngleStream: _isSim ? null : _motor.angleStream,
      config: widget.config,
      showElbowGuide: !_isSim,
      onGameEnd: (r) {
        _motor.safeStop();
        _motor.dispose();
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => GameResultScreen(result: r)));
        }
      },
    );
    if (!_isSim) {
      _motor.selectJoint(widget.config.bodyPart);
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
      backgroundColor: _cream,
      body: Stack(children: [
        Column(children: [
          Expanded(child: GameWidget(game: _game)),
          if (_isSim)
            Container(
              color: _creamDeep,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              child: Row(children: [
                const Text('↺ 안쪽 (닫기)', style: TextStyle(color: _ink, fontSize: 13)),
                Expanded(
                  child: SliderTheme(
                    data: const SliderThemeData(
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16),
                      trackHeight: 8,
                      activeTrackColor: _zoneFlow,
                      inactiveTrackColor: Color(0x33000000),
                      thumbColor: Colors.white,
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
                const Text('바깥 (열기) ↻', style: TextStyle(color: _ink, fontSize: 13)),
              ]),
            ),
          Container(
            color: _creamDeep,
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: _ink),
                onPressed: _game.togglePause,
                icon: const Icon(Icons.pause),
                label: Text(loc.pauseGame),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                onPressed: () {
                  _motor.safeStop();
                  _game.endGame();
                },
                icon: const Icon(Icons.stop),
                label: Text(loc.stop),
              ),
            ]),
          ),
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
}
```

- [ ] **Step 3: 정적 분석**

Run: `flutter analyze lib/games/games/potion_maker_game.dart lib/games/games/potion_maker_logic.dart lib/games/game_hub.dart`
Expected: `No issues found!` (error·warning 0개. 기존 코드 스타일 관련 info가 나오면 새 파일에서 나온 것만 고친다.)

- [ ] **Step 4: 규칙 테스트 재확인**

Run: `flutter test test/potion_maker_logic_test.dart`
Expected: PASS (26개)

- [ ] **Step 5: 사용자 수동 확인 요청 (스크린샷 찍지 않음)**

사용자에게 다음을 실행해 확인해 달라고 한다:

```
flutter run -d <기기> -t lib/trot_preview.dart
```

→ 게임 허브 → (Task 4 전이므로 아직 "팔꿈치" 목록의) **포션 제조** → Brunnstrom 5단계, 난이도 3 → 시작. BT 미연결이면 하단 슬라이더로 조작한다.

확인할 것:
1. 3·2·1 카운트다운 뒤 큰 통이 나오고, 슬라이더를 오른쪽(바깥)으로 끝까지 밀면 **레버 손잡이가 화면 왼쪽으로** 열리며 금색 구간에서만 흐른다.
2. 큰 통을 비우고 슬라이더를 왼쪽 끝으로 돌리면 1초 뒤 다음 재료가 나오고, 끝난 층이 바닥에 얇게 눌린다.
3. 작은 병에서 목표선·허용 오차 띠가 보이고, 닫으면 확정 원이 1초 동안 찬다. 넘치면 "조금 넘쳤어요", 맞으면 "딱 맞아요!".
4. 물약 완성 시 층이 펼쳐지고 "딱 맞는 높이" 선이 보인 뒤, 등급별 생물(황금은 왕관)이 선반으로 날아간다. 실패하면 부푼 생물/콩알 생물이 나오고 선반에 남지 않는다.
5. 일시정지·정지·비상정지 버튼이 동작하고, 목표 물약 6개를 채우면 결과 화면으로 넘어간다.

- [ ] **Step 6: 커밋 (사용자 확인 후)**

```bash
git add lib/games/games/potion_maker_game.dart
git commit -m "feat: 포션메이커 v2 화면 — 레버·플라스크 층 쌓기·등급 연출 (Canvas 도형)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 허브 등록 변경 — 어깨 목록, `lShoulderRo`, 설명 문구

**Files:**
- Modify: `lib/games/game_hub.dart` (`shoulderGames`, `elbowGames` 목록)
- Modify: `lib/l10n/intl_ko.arb:171`, `lib/l10n/intl_en.arb:171`
- Regenerate: `lib/generated/l10n.dart`, `lib/generated/l10n_ko.dart`, `lib/generated/l10n_en.dart`

**Interfaces:**
- Consumes: Task 3의 `PotionMakerGame(bluetoothService:, config:)` (시그니처 변경 없음)
- Produces: 허브에서 포션 제조가 어깨 목록에 `joint: 'lShoulderRo'`로 표시되고, `GameConfig.bodyPart == 'lShoulderRo'`로 시작된다.

- [ ] **Step 1: 팔꿈치 목록에서 포션 제조 제거**

`lib/games/game_hub.dart`의 `elbowGames`에서 아래 두 줄을 지운다:

```dart
      _GameInfo(id: 'potion_maker', name: loc.potionMaker, description: loc.potionMakerDesc,
          icon: Icons.science, color: const Color(0xFFAB47BC), joint: 'lElbow'),
```

- [ ] **Step 2: 어깨 목록의 금고털이 바로 아래에 추가**

`shoulderGames`에서 이 부분을:

```dart
      _GameInfo(id: 'safe_cracker', name: loc.safeCracker, description: loc.safeCrackerDesc,
          icon: Icons.lock_open, color: const Color(0xFFFFD54F), joint: 'lShoulderRo'),
```

이렇게 바꾼다:

```dart
      _GameInfo(id: 'safe_cracker', name: loc.safeCracker, description: loc.safeCrackerDesc,
          icon: Icons.lock_open, color: const Color(0xFFFFD54F), joint: 'lShoulderRo'),
      _GameInfo(id: 'potion_maker', name: loc.potionMaker, description: loc.potionMakerDesc,
          icon: Icons.science, color: const Color(0xFFAB47BC), joint: 'lShoulderRo'),
```

- [ ] **Step 3: 설명 문구 수정**

`lib/l10n/intl_ko.arb`:

```json
  "potionMakerDesc": "어깨를 바깥으로 돌려 레버를 열고 물약을 만들어요",
```

`lib/l10n/intl_en.arb`:

```json
  "potionMakerDesc": "Rotate your shoulder outward to open the lever and brew potions",
```

- [ ] **Step 4: 로컬라이제이션 재생성**

Run: `flutter gen-l10n`
Expected: 오류 없이 끝나고, `grep -n "potionMakerDesc =>" lib/generated/l10n_ko.dart`가 새 문구를 보여 준다.

- [ ] **Step 5: 정적 분석**

Run: `flutter analyze lib/games/game_hub.dart lib/games/games/potion_maker_game.dart`
Expected: `No issues found!`

- [ ] **Step 6: 사용자 수동 확인 요청**

`flutter run -d <기기> -t lib/trot_preview.dart` → 게임 허브의 **어깨** 목록에 "포션 제조"가 금고털이 아래에 새 설명으로 보이고, 시작하면 Task 3과 같이 동작하는지 확인해 달라고 한다.

- [ ] **Step 7: 커밋**

```bash
git add lib/games/game_hub.dart lib/l10n/intl_ko.arb lib/l10n/intl_en.arb lib/generated/l10n.dart lib/generated/l10n_ko.dart lib/generated/l10n_en.dart
git commit -m "feat: 포션메이커를 어깨 돌림(lShoulderRo) 게임으로 허브 등록 변경

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

(Task 0에서 트로트 변경을 먼저 커밋하지 않았다면, 이 커밋에 트로트 허브 등록이 섞인다는 점을 커밋 전에 사용자에게 알린다.)

---

### Task 5: 문서 상태 갱신

**Files:**
- Modify: `docs/potion_maker_build_guide.md` ("현재 상태" 표, 9장 체크리스트)

**Interfaces:**
- Consumes: Task 1~4 결과, 사용자 수동 확인 결과
- Produces: 가이드의 상태 표와 체크리스트가 실제 진행과 같아진다.

- [ ] **Step 1: 현재 상태 표 갱신**

`docs/potion_maker_build_guide.md` "현재 상태" 표에서 **사용자가 확인한 항목만** ✅로 바꾼다. 날짜 제목 `## 현재 상태 (2026-09-21 기준)`도 갱신 날짜로 바꾼다. 확인 전 항목은 🔄 진행 중으로 둔다.

| 항목 | 바꿀 상태 (확인된 경우) |
|------|------|
| 규칙 파일 `potion_maker_logic.dart` + 단위 테스트 | ✅ 완료 (테스트 26개 통과) |
| 화면 파일 `potion_maker_game.dart` 재작성 (Canvas 도형) | ✅ 완료 |
| 결과 연출 (등급별 성공 생물 / 엉뚱한 결과물) | ✅ 완료 |
| `game_hub` 관절 변경 (`lElbow` → `lShoulderRo`) · 설명 문구 | ✅ 완료 |

- [ ] **Step 2: 9장 체크리스트 갱신**

Phase 1~3에서 끝난 항목을 `- [x]`로 바꾼다. Phase 4(실기기 QA)는 그대로 둔다.

- [ ] **Step 3: 커밋**

```bash
git add docs/potion_maker_build_guide.md
git commit -m "docs: 포션메이커 v2 코어 구현 상태 반영

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 이 계획 밖 (가이드 9장 Phase 4 · 나중 단계)

- 실기기 QA: 센서 방향(가쪽돌림 = `p` 증가) 확인과 반전, 흐름 속도·허용 오차·등급 기준 튜닝
- 펌웨어 팔꿈치 고정(부록 A) 연결
- 스프라이트·BGM·효과음
- 인지 레벨(`CognitiveLevel`)별 오브젝트 크기·HUD 표시 범위 조정 — 이 계획은 파티클 수(`particleCount`)만 반영한다 (가이드 4-3)
