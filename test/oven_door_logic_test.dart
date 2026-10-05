import 'package:exo_tablet_app_v6/games/angle_normalizer.dart';
import 'package:exo_tablet_app_v6/games/game_base.dart';
import 'package:exo_tablet_app_v6/games/games/oven_door_logic.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _config({int level = 3, BrunnstromStage stage = BrunnstromStage.stage5}) =>
    GameConfig(
      normalizer: const AngleNormalizer(minAngle: -30, maxAngle: 60),
      difficultyLevel: level,
      bodyPart: 'rShoulderRo',
      brunnstromStage: stage,
    );

const _params = OvenParams(
    food: FoodKind.bread,
    requiredOpen: 0.5,
    holdTime: 2.0,
    takeOutWindow: 10.0,
    foodGoal: 1,
    resistanceKg: 0);

/// door를 seconds 동안 60fps로 유지하고, 그동안 나온 이벤트 이름을 돌려준다.
List<String> _hold(OvenSession s, double door, double seconds) {
  final names = <String>[];
  for (var i = 0; i < (seconds * 60).round(); i++) {
    names.addAll(s.update(1 / 60, door).map((e) => e.name));
  }
  return names;
}

/// 넣기를 끝내고 문을 닫아 굽기까지 마친 뒤, 벨이 울린 직후 상태로 만든다.
OvenSession _atTakeOut({OvenParams params = _params}) {
  final s = OvenSession(params);
  _hold(s, 0.9, params.holdTime + 0.2); // 열고 유지 → 넣기 완료
  _hold(s, 0.0, 0.1); // 문 닫기 → 굽기 시작
  _hold(s, 0.0, OvenRules.bakeTime + 0.1); // 굽는 동안 대기 → 벨
  return s;
}

void main() {
  group('OvenParams.fromConfig', () {
    test('레벨 1은 쿠키 — 적게 열고 짧게 버티고 여유 시간이 길다', () {
      final p = OvenParams.fromConfig(_config(level: 1));
      expect(p.food, FoodKind.cookie);
      expect(p.requiredOpen, closeTo(0.35, 1e-9));
      expect(p.holdTime, closeTo(1.0, 1e-9));
      expect(p.takeOutWindow, closeTo(16.0, 1e-9));
      expect(p.foodGoal, 4);
    });

    test('레벨 5는 케이크 — 많이 열고 오래 버티고 여유 시간이 짧다', () {
      final p = OvenParams.fromConfig(_config(level: 5));
      expect(p.food, FoodKind.cake);
      expect(p.requiredOpen, closeTo(0.85, 1e-9));
      expect(p.holdTime, closeTo(3.0, 1e-9));
      expect(p.takeOutWindow, closeTo(8.0, 1e-9));
      expect(p.foodGoal, 8);
    });

    test('모든 레벨에서 여유 시간은 유지 시간의 2.5배 이상이다', () {
      for (var level = 1; level <= 5; level++) {
        final p = OvenParams.fromConfig(_config(level: level));
        expect(p.takeOutWindow, greaterThanOrEqualTo(p.holdTime * 2.5), reason: '레벨 $level');
      }
    });

    test('Brunnstrom 4단계 이상에서만 저항이 걸린다', () {
      final withResistance =
          OvenParams.fromConfig(_config(stage: BrunnstromStage.stage4), resistanceKg: 2);
      expect(withResistance.resistanceKg, closeTo(2.0, 1e-9));

      final blocked =
          OvenParams.fromConfig(_config(stage: BrunnstromStage.stage3), resistanceKg: 2);
      expect(blocked.resistanceKg, 0);
    });

    test('저항은 0~3kg으로 잘린다', () {
      expect(OvenParams.fromConfig(_config(), resistanceKg: 9).resistanceKg,
          closeTo(OvenRules.maxResistanceKg, 1e-9));
      expect(OvenParams.fromConfig(_config(), resistanceKg: -2).resistanceKg, 0);
    });

    test('난이도 값이 범위를 벗어나도 표 안으로 잘린다', () {
      expect(OvenParams.fromConfig(_config(level: 9)).food, FoodKind.cake);
      expect(OvenParams.fromConfig(_config(level: 0)).food, FoodKind.cookie);
    });
  });

  group('FoodKind', () {
    test('한국어 이름', () {
      expect(FoodKind.cookie.label, '쿠키');
      expect(FoodKind.cake.label, '케이크');
    });
  });

  group('OvenSession 넣기', () {
    test('요구 열림에 못 미치면 진행하지 않는다', () {
      final s = OvenSession(_params);
      _hold(s, 0.4, 3.0);
      expect(s.holdProgress, 0);
      expect(s.phase, OvenPhase.inserting);
    });

    test('요구 열림 이상으로 유지 시간만큼 버티면 음식이 들어간다', () {
      final s = OvenSession(_params);
      expect(_hold(s, 0.9, 2.1), contains('insert_done'));
      expect(s.score, OvenRules.insertScore);
      expect(s.hits, 1);
      expect(s.phase, OvenPhase.closing);
    });

    test('0.3초 안에 되돌아오면 진행이 이어진다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 1.5);
      final progressBefore = s.holdProgress;
      _hold(s, 0.2, 0.2); // 유예 안에서 흔들림
      expect(_hold(s, 0.9, 0.1), isNot(contains('drop')));
      expect(s.holdProgress, greaterThan(progressBefore));
      expect(_hold(s, 0.9, 0.6), contains('insert_done'));
    });

    test('0.3초를 넘겨 내려가면 음식이 떨어진다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 1.0);
      expect(_hold(s, 0.2, 0.5), contains('drop'));
      expect(s.lastOutcome, FoodOutcome.dropped);
      expect(s.misses, 1);
      expect(s.foodsDone, 1); // 실패도 개수에 포함
      expect(s.shelf, isEmpty);
    });

    test('아직 시작하지 않았으면 문이 닫혀 있어도 떨어지지 않는다', () {
      final s = OvenSession(_params);
      expect(_hold(s, 0.0, 3.0), isNot(contains('drop')));
      expect(s.phase, OvenPhase.inserting);
    });
  });

  group('OvenSession 굽기와 꺼내기', () {
    test('문을 닫아야 굽기가 시작된다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 2.1);
      _hold(s, 0.9, 1.0); // 연 채로 있으면 굽기가 시작되지 않는다
      expect(s.phase, OvenPhase.closing);
      _hold(s, 0.0, 0.1);
      expect(s.phase, OvenPhase.baking);
    });

    test('굽는 시간이 지나면 벨이 울린다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 2.1);
      _hold(s, 0.0, 0.1);
      expect(_hold(s, 0.0, OvenRules.bakeTime + 0.1), contains('bell'));
      expect(s.phase, OvenPhase.takingOut);
    });

    test('여유 시간 안에 꺼내면 완성 — 빨리 꺼낼수록 보너스가 크다', () {
      final s = _atTakeOut();
      expect(_hold(s, 0.9, 2.1), contains('take_done'));
      expect(s.lastOutcome, FoodOutcome.done);
      expect(s.shelf, [FoodOutcome.done]);
      expect(s.score, greaterThan(OvenRules.insertScore + OvenRules.takeScore));
      expect(s.hits, 2);
    });

    test('여유 시간을 넘기면 탄다', () {
      final s = _atTakeOut();
      expect(_hold(s, 0.0, _params.takeOutWindow + 0.1), contains('burnt'));
      expect(s.lastOutcome, FoodOutcome.burnt);
      expect(s.misses, 1);
      expect(s.shelf, isEmpty);
    });

    test('벨이 울릴 때 이미 열려 있으면 그 프레임부터 유지가 시작된다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 2.1);
      _hold(s, 0.0, 0.1);
      _hold(s, 0.0, OvenRules.bakeTime - 0.5);
      _hold(s, 0.9, 0.6); // 벨이 울리는 순간 이미 문이 열려 있다
      expect(s.phase, OvenPhase.takingOut);
      expect(s.holdProgress, greaterThan(0));
    });
  });

  group('OvenSession 판 진행', () {
    test('목표 개수를 채우면 끝난다', () {
      final s = _atTakeOut();
      _hold(s, 0.9, 2.1);
      expect(s.isFinished, isFalse);
      _hold(s, 0.0, OvenRules.resultTime + 0.1);
      expect(s.isFinished, isTrue);
      expect(s.foodsDone, 1);
    });

    test('목표가 남았으면 다음 음식이 나온다', () {
      const two = OvenParams(
          food: FoodKind.bread,
          requiredOpen: 0.5,
          holdTime: 2.0,
          takeOutWindow: 10.0,
          foodGoal: 2,
          resistanceKg: 0);
      final s = _atTakeOut(params: two);
      _hold(s, 0.9, 2.1);
      _hold(s, 0.0, OvenRules.resultTime + 0.1);
      expect(s.isFinished, isFalse);
      expect(s.phase, OvenPhase.inserting);
      expect(s.holdProgress, 0);
    });

    test('문을 열었다 닫을 때마다 반복이 한 번 센다', () {
      final s = OvenSession(_params);
      _hold(s, 0.5, 0.2);
      expect(_hold(s, 0.05, 0.2), contains('door_close'));
      expect(s.reps, 1);
      _hold(s, 0.14, 0.5); // 히스테리시스 사이 떨림은 세지 않는다
      expect(s.reps, 1);
    });

    test('8분이 지나면 끝난다', () {
      final s = OvenSession(_params);
      for (var i = 0; i < 479; i++) {
        s.update(1.0, 0.0);
      }
      expect(s.isFinished, isFalse);
      s.update(1.0, 0.0);
      expect(s.isFinished, isTrue);
    });

    test('최대 점수와 정확도', () {
      final s = OvenSession(_params);
      expect(s.maxPossibleScore,
          OvenRules.insertScore + OvenRules.takeScore + OvenRules.speedBonusMax);
      expect(s.accuracy, 0);
    });
  });

  group('OvenSession 이상 입력', () {
    test('문 열림이 0~1을 벗어나도 잘린다', () {
      final s = OvenSession(_params);
      s.update(1 / 60, 5.0);
      expect(s.door, 1.0);
      s.update(1 / 60, -3.0);
      expect(s.door, 0.0);
    });

    test('큰 dt 한 번에 벨과 탐이 같이 나오고 판정은 한 번만 난다', () {
      final s = OvenSession(_params);
      _hold(s, 0.9, 2.1);
      _hold(s, 0.0, 0.1);
      final events = s
          .update(OvenRules.bakeTime + _params.takeOutWindow + 1, 0.0)
          .map((e) => e.name)
          .toList();
      expect(events, containsAllInOrder(['bell', 'burnt']));
      expect(events.where((e) => e == 'burnt').length, 1);
      expect(s.misses, 1);
    });

    test('가동범위가 없어 문이 절반에서 멈춰도 8분까지 진행된다', () {
      const hard = OvenParams(
          food: FoodKind.cake,
          requiredOpen: 0.85,
          holdTime: 3.0,
          takeOutWindow: 8.0,
          foodGoal: 8,
          resistanceKg: 0);
      final s = OvenSession(hard);
      for (var i = 0; i < 480; i++) {
        s.update(1.0, 0.5); // 항상 절반만 열림
      }
      expect(s.isFinished, isTrue);
      expect(s.foodsDone, 0);
      expect(s.misses, 0);
    });
  });
}
