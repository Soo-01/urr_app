/// 블루투스에서 수신된 원시 각도 값을 0.0~1.0 범위로 정규화하는 클래스.
/// 캘리브레이션에서 측정된 min/max 각도를 기반으로 매핑한다.
class AngleNormalizer {
  final double minAngle;
  final double maxAngle;

  const AngleNormalizer({required this.minAngle, required this.maxAngle});

  /// rawAngle을 0.0(minAngle) ~ 1.0(maxAngle) 범위로 정규화.
  double normalize(double rawAngle) {
    if ((maxAngle - minAngle).abs() < 0.5) return 0.5;
    return ((rawAngle - minAngle) / (maxAngle - minAngle)).clamp(0.0, 1.0);
  }

  /// 정규화된 값을 원시 각도로 역변환.
  double denormalize(double normalized) {
    return minAngle + normalized * (maxAngle - minAngle);
  }

  /// ROM 범위 (도 단위).
  double get range => (maxAngle - minAngle).abs();
}
