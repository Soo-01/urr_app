import 'package:flutter/material.dart';
import 'dart:math' as math;

class TargetReachingPainter extends CustomPainter {
  final double cursorPosition;   // 0.0~1.0
  final double targetPosition;   // 0.0~1.0
  final double targetRadius;     // 정규화된 타겟 크기 (예: 0.1 = 10%)
  final double dwellProgress;    // 0.0~1.0 (타겟 안 체류 진행도)
  final bool isHitting;
  final int score;
  final int timeRemaining;

  TargetReachingPainter({
    required this.cursorPosition,
    required this.targetPosition,
    required this.targetRadius,
    required this.dwellProgress,
    required this.isHitting,
    required this.score,
    required this.timeRemaining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barY = size.height * 0.5;
    final barLeft = size.width * 0.05;
    final barRight = size.width * 0.95;
    final barWidth = barRight - barLeft;
    final barHeight = 20.0;

    // 배경 바
    final bgPaint = Paint()..color = Colors.grey.shade200;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY - barHeight / 2, barWidth, barHeight),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // 타겟 존
    final targetX = barLeft + targetPosition * barWidth;
    final targetW = targetRadius * barWidth;
    final targetPaint = Paint()
      ..color = isHitting
          ? Colors.amber.withOpacity(0.6)
          : Colors.green.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(targetX, barY), width: targetW, height: barHeight + 30),
        const Radius.circular(8),
      ),
      targetPaint,
    );

    // 타겟 테두리
    final targetBorderPaint = Paint()
      ..color = isHitting ? Colors.amber : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(targetX, barY), width: targetW, height: barHeight + 30),
        const Radius.circular(8),
      ),
      targetBorderPaint,
    );

    // Dwell progress 원형 표시 (타겟 위)
    if (isHitting && dwellProgress > 0) {
      final progressPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(targetX, barY - 40), radius: 16),
        -math.pi / 2,
        dwellProgress * 2 * math.pi,
        false,
        progressPaint,
      );
    }

    // 커서
    final cursorX = barLeft + cursorPosition * barWidth;
    final cursorPaint = Paint()
      ..color = isHitting ? Colors.amber : Colors.blue;
    canvas.drawCircle(Offset(cursorX, barY), 18, cursorPaint);

    // 커서 내부 원
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cursorX, barY), 8, innerPaint);

    // 눈금 표시
    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final x = barLeft + (i / 10) * barWidth;
      canvas.drawLine(
        Offset(x, barY + barHeight / 2 + 5),
        Offset(x, barY + barHeight / 2 + 12),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TargetReachingPainter oldDelegate) {
    return cursorPosition != oldDelegate.cursorPosition ||
        targetPosition != oldDelegate.targetPosition ||
        targetRadius != oldDelegate.targetRadius ||
        dwellProgress != oldDelegate.dwellProgress ||
        isHitting != oldDelegate.isHitting ||
        score != oldDelegate.score ||
        timeRemaining != oldDelegate.timeRemaining;
  }
}
