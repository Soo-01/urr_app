import 'package:exo_tablet_app_v6/games/game_base.dart';
import 'package:exo_tablet_app_v6/games/angle_normalizer.dart';
import 'package:exo_tablet_app_v6/joint_options.dart';
import 'package:exo_tablet_app_v6/robot_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared rehabilitation joint list matches the ROM protocol list', () {
    expect(rehabilitationJointCodes.toSet(), RobotProtocol.knownParts);
  });

  test('game accuracy is synchronized with success and failure counts', () {
    expect(
      GameResult.accuracyFromCounts(hits: 7, misses: 3),
      closeTo(0.7, 1e-9),
    );
    expect(
      GameResult.accuracyFromCounts(hits: 0, misses: 0),
      0,
    );
    expect(
      () => GameResult.accuracyFromCounts(hits: -1, misses: 0),
      throwsArgumentError,
    );
  });

  test('Shield Guard ROM maps its vertical axis and midpoint consistently', () {
    const normalizer = AngleNormalizer(minAngle: 10, maxAngle: 80);

    expect(normalizer.normalize(10), 0);
    expect(normalizer.normalize(45), closeTo(0.5, 1e-9));
    expect(normalizer.normalize(80), 1);
    expect(normalizer.denormalize(0.5), 45);
  });
}
