import 'package:flutter/material.dart';
import 'dart:math' as math;

class Balloon {
  double normalizedX;
  double radius;      // 정규화된 반지름 (화면 폭 대비)
  Color color;
  bool isBonus;
  bool isPopping;
  double popProgress;  // 0.0~1.0

  Balloon({
    required this.normalizedX,
    required this.radius,
    required this.color,
    this.isBonus = false,
    this.isPopping = false,
    this.popProgress = 0.0,
  });
}

class BalloonPopPainter extends CustomPainter {
  final List<Balloon> balloons;
  final double cursorPosition;
  final int score;
  final int timeRemaining;

  BalloonPopPainter({
    required this.balloons,
    required this.cursorPosition,
    required this.score,
    required this.timeRemaining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barY = size.height * 0.55;
    final barLeft = size.width * 0.05;
    final barRight = size.width * 0.95;
    final barWidth = barRight - barLeft;

    // 배경 바 (풍선이 떠있는 수평선)
    final bgPaint = Paint()..color = Colors.grey.shade200;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY - 2, barWidth, 4),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    // 풍선 그리기
    for (final balloon in balloons) {
      final bx = barLeft + balloon.normalizedX * barWidth;
      final bRadius = balloon.radius * barWidth;

      if (balloon.isPopping) {
        // 터지는 애니메이션
        final scale = 1.0 + balloon.popProgress * 0.5;
        final opacity = (1.0 - balloon.popProgress).clamp(0.0, 1.0);
        final popPaint = Paint()
          ..color = balloon.color.withOpacity(opacity);

        canvas.drawCircle(
          Offset(bx, barY - bRadius * 1.5),
          bRadius * scale,
          popPaint,
        );

        // 파티클
        if (balloon.popProgress > 0.2) {
          final particlePaint = Paint()
            ..color = balloon.color.withOpacity(opacity * 0.7);
          for (int i = 0; i < 6; i++) {
            final angle = i * math.pi / 3 + balloon.popProgress * 2;
            final dist = bRadius * balloon.popProgress * 2;
            canvas.drawCircle(
              Offset(
                bx + math.cos(angle) * dist,
                barY - bRadius * 1.5 + math.sin(angle) * dist,
              ),
              3,
              particlePaint,
            );
          }
        }
      } else {
        // 정상 풍선
        final balloonCenter = Offset(bx, barY - bRadius * 1.5);

        // 풍선 본체
        final bPaint = Paint()..color = balloon.color;
        canvas.drawOval(
          Rect.fromCenter(center: balloonCenter, width: bRadius * 2, height: bRadius * 2.4),
          bPaint,
        );

        // 하이라이트
        final hlPaint = Paint()
          ..color = Colors.white.withOpacity(0.3);
        canvas.drawOval(
          Rect.fromCenter(
            center: balloonCenter + Offset(-bRadius * 0.2, -bRadius * 0.3),
            width: bRadius * 0.6,
            height: bRadius * 0.8,
          ),
          hlPaint,
        );

        // 줄
        final linePaint = Paint()
          ..color = Colors.grey
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(bx, barY - bRadius * 0.3),
          Offset(bx, barY),
          linePaint,
        );

        // 보너스 표시
        if (balloon.isBonus) {
          final starPaint = Paint()..color = Colors.white;
          canvas.drawCircle(balloonCenter, bRadius * 0.3, starPaint);
          final textPainter = TextPainter(
            text: const TextSpan(
              text: '★',
              style: TextStyle(fontSize: 14, color: Colors.amber),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas,
              balloonCenter - Offset(textPainter.width / 2, textPainter.height / 2));
        }
      }
    }

    // 커서 (핀 모양)
    final cursorX = barLeft + cursorPosition * barWidth;
    final pinPaint = Paint()..color = Colors.red.shade700;
    // 핀 머리
    canvas.drawCircle(Offset(cursorX, barY + 20), 12, pinPaint);
    // 핀 바늘
    final needlePaint = Paint()
      ..color = Colors.red.shade700
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cursorX, barY + 8),
      Offset(cursorX, barY - 15),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(BalloonPopPainter oldDelegate) => true;
}
