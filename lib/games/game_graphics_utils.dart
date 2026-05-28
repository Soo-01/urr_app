import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart' as fp;
import 'package:flutter/material.dart';

/// 모든 재활 게임에서 공통으로 사용하는 절차적 그래픽 유틸리티
class GfxUtils {
  GfxUtils._();

  // ─── 글로우 / 섀도우 ───

  /// 블러 글로우 원
  static void drawGlow(Canvas canvas, Offset center, double radius, Color color,
      {double blurSigma = 14, double alpha = 0.35}) {
    canvas.drawCircle(center, radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma));
  }

  /// 드롭 섀도우
  static void drawShadow(Canvas canvas, Offset center, double radius,
      {double offsetY = 6, double blurSigma = 8, double alpha = 0.4}) {
    canvas.drawCircle(Offset(center.dx, center.dy + offsetY), radius * 0.85,
        Paint()
          ..color = Colors.black.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma));
  }

  /// 빛나는 원 (그라디언트 하이라이트 포함)
  static void drawShinyCircle(Canvas canvas, Offset center, double radius,
      Color base, Color highlight) {
    // 베이스
    canvas.drawCircle(center, radius, Paint()..color = base);
    // 상단 하이라이트
    canvas.drawCircle(
        Offset(center.dx - radius * 0.2, center.dy - radius * 0.25),
        radius * 0.38,
        Paint()..color = highlight.withValues(alpha: 0.35));
    // 작은 반짝임 점
    canvas.drawCircle(
        Offset(center.dx - radius * 0.28, center.dy - radius * 0.32),
        radius * 0.08,
        Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  /// 빛나는 RRect (그라디언트)
  static void drawShinyRRect(Canvas canvas, Rect rect, double cornerRadius,
      Color base, Color topHighlight, {double strokeWidth = 0}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topHighlight, base],
            stops: const [0.0, 0.5],
          ).createShader(rect));
    if (strokeWidth > 0) {
      canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth);
    }
  }

  // ─── 파티클 생성기 ───

  /// 꽃잎 파티클 버스트 (수집/성공 이펙트)
  static fp.Particle petalBurst(Random rng, int count, Color color) {
    return fp.Particle.generate(
      count: count,
      lifespan: 0.7,
      generator: (i) {
        final angle = rng.nextDouble() * pi * 2;
        final speed = 60 + rng.nextDouble() * 100;
        final size = 3.0 + rng.nextDouble() * 4;
        return fp.AcceleratedParticle(
          speed: Vector2(cos(angle) * speed, sin(angle) * speed - 60),
          acceleration: Vector2(0, 220),
          child: fp.ScalingParticle(
            to: 0,
            child: fp.CircleParticle(
              radius: size,
              paint: Paint()
                ..color = Color.lerp(color, Colors.white, rng.nextDouble() * 0.5)!
                    .withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }

  /// 폭발 파티클 버스트
  static fp.Particle explosionBurst(Random rng, int count, Color color) {
    final colors = [
      color,
      Color.lerp(color, Colors.white, 0.4)!,
      Color.lerp(color, Colors.yellow, 0.3)!,
    ];
    return fp.Particle.generate(
      count: count,
      lifespan: 0.6,
      generator: (i) {
        final angle = (i / count) * pi * 2 + rng.nextDouble() * 0.4;
        final speed = 80 + rng.nextDouble() * 140;
        return fp.AcceleratedParticle(
          speed: Vector2(cos(angle) * speed, sin(angle) * speed),
          acceleration: Vector2(0, 160),
          child: fp.ScalingParticle(
            to: 0,
            child: fp.CircleParticle(
              radius: 2 + rng.nextDouble() * 3,
              paint: Paint()..color = colors[i % colors.length].withValues(alpha: 0.9),
            ),
          ),
        );
      },
    );
  }

  /// 마법 별 파티클 (마법/완성 이펙트)
  static fp.Particle magicStarBurst(Random rng, int count, Color color) {
    return fp.Particle.generate(
      count: count,
      lifespan: 0.9,
      generator: (i) {
        final angle = rng.nextDouble() * pi * 2;
        final speed = 40 + rng.nextDouble() * 120;
        final c = [color, Colors.white, Colors.yellow, Colors.cyanAccent][i % 4];
        return fp.AcceleratedParticle(
          speed: Vector2(cos(angle) * speed, sin(angle) * speed - 80),
          acceleration: Vector2(0, 100),
          child: fp.ScalingParticle(
            to: 0,
            child: fp.CircleParticle(
              radius: 1.5 + rng.nextDouble() * 3,
              paint: Paint()..color = c.withValues(alpha: 0.9),
            ),
          ),
        );
      },
    );
  }

  // ─── 배경 유틸 ───

  /// 3레이어 배경 그라디언트 (하늘/실내 등 모두 사용)
  static void drawVerticalGradient(Canvas canvas, Rect rect, List<Color> colors,
      {List<double>? stops}) {
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: stops,
          ).createShader(rect));
  }

  /// 별빛 점 (배경 장식)
  static void drawStarfield(Canvas canvas, Size size, double time,
      {int count = 30, double maxAlpha = 0.4}) {
    final rng = Random(42);
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final twinkle = (sin(time * 1.5 + i * 1.3) * 0.5 + 0.5);
      canvas.drawCircle(
          Offset(x, y),
          0.5 + rng.nextDouble() * 1.5,
          Paint()
            ..color = Colors.white.withValues(alpha: twinkle * maxAlpha));
    }
  }

  /// 불꽃 (촛불/모닥불 하단)
  static void drawFlame(Canvas canvas, Offset base, double width, double height,
      double time, {Color innerColor = Colors.yellow, Color outerColor = Colors.orange}) {
    for (int layer = 2; layer >= 0; layer--) {
      final flicker = sin(time * 8 + layer * 1.2) * 0.12 + 1.0;
      final h = height * flicker * (0.6 + layer * 0.2);
      final w = width * (0.5 + layer * 0.25);
      final path = Path();
      path.moveTo(base.dx, base.dy);
      path.quadraticBezierTo(
          base.dx - w * 0.6, base.dy - h * 0.4,
          base.dx + sin(time * 4 + layer) * w * 0.15,
          base.dy - h);
      path.quadraticBezierTo(
          base.dx + w * 0.6, base.dy - h * 0.4,
          base.dx, base.dy);
      final color = layer == 0
          ? Colors.white.withValues(alpha: 0.7)
          : layer == 1
              ? innerColor.withValues(alpha: 0.75)
              : outerColor.withValues(alpha: 0.5);
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  // ─── 기하 유틸 ───

  /// 반짝임 점 (하이라이트 스파크)
  static void drawSparkle(Canvas canvas, Offset center, double size, Color color,
      {double angle = 0}) {
    final paint = Paint()..color = color;
    for (int i = 0; i < 4; i++) {
      final a = angle + i * pi / 2;
      canvas.drawLine(center, Offset(center.dx + cos(a) * size, center.dy + sin(a) * size),
          paint..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(center, size * 0.25, paint);
  }

  /// 별 모양 경로
  static Path starPath(Offset center, double outerR, double innerR, int points) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = (i * pi / points) - pi / 2;
      final x = center.dx + cos(a) * r;
      final y = center.dy + sin(a) * r;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    return path;
  }
}
