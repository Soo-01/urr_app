import 'package:flutter_test/flutter_test.dart';

import 'package:exo_tablet_app_v6/isometric_force_tracker.dart';

void main() {
  test('opens only after the target is settled for consecutive samples', () {
    final gate = IsometricTargetGate(targetDegrees: 45);

    expect(
      gate.update(positionDegrees: 30, velocityDegreesPerSecond: 8),
      isFalse,
    );
    expect(
      gate.update(positionDegrees: 44, velocityDegreesPerSecond: 1),
      isFalse,
    );
    expect(
      gate.update(positionDegrees: 45, velocityDegreesPerSecond: 1),
      isFalse,
    );
    expect(
      gate.update(positionDegrees: 45.5, velocityDegreesPerSecond: 0.5),
      isTrue,
    );
    expect(gate.reached, isTrue);
  });

  test('resets consecutive samples when the joint moves away', () {
    final gate = IsometricTargetGate(targetDegrees: 60);

    expect(
      gate.update(positionDegrees: 60, velocityDegreesPerSecond: 0),
      isFalse,
    );
    expect(
      gate.update(positionDegrees: 55, velocityDegreesPerSecond: 0),
      isFalse,
    );
    expect(
      gate.update(positionDegrees: 60, velocityDegreesPerSecond: 0),
      isFalse,
    );
  });
}
