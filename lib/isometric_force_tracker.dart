/// Delays isometric force sampling until the selected joint has settled at
/// the requested target angle.
class IsometricTargetGate {
  IsometricTargetGate({
    required this.targetDegrees,
    this.angleToleranceDegrees = 2.0,
    this.velocityToleranceDegreesPerSecond = 2.0,
    this.requiredStableSamples = 3,
  });

  final double targetDegrees;
  final double angleToleranceDegrees;
  final double velocityToleranceDegreesPerSecond;
  final int requiredStableSamples;

  int _stableSamples = 0;
  bool _reached = false;

  bool get reached => _reached;

  bool update({
    required double positionDegrees,
    required double velocityDegreesPerSecond,
  }) {
    if (_reached) return true;

    final isAtTarget =
        (positionDegrees - targetDegrees).abs() <= angleToleranceDegrees;
    final isSettled =
        velocityDegreesPerSecond.abs() <= velocityToleranceDegreesPerSecond;

    if (isAtTarget && isSettled) {
      _stableSamples++;
      if (_stableSamples >= requiredStableSamples) _reached = true;
    } else {
      _stableSamples = 0;
    }
    return _reached;
  }
}
