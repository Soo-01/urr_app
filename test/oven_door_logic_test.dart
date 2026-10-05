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
}
