import 'package:flutter/material.dart';
import 'dart:math' as math;

class TrackingPainter extends CustomPainter {
  final double cursorPosition;
  final double targetPosition;
  final double averageAccuracy;
  final List<double> accuracyHistory; // 최근 정확도 값들 (시각적 트레일)
  final int timeRemaining;

  TrackingPainter({
    required this.cursorPosition,
    required this.targetPosition,
    required this.averageAccuracy,
    required this.accuracyHistory,
    required this.timeRemaining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barY = size.height * 0.45;
    final barLeft = size.width * 0.05;
    final barRight = size.width * 0.95;
    final barWidth = barRight - barLeft;
    final barHeight = 16.0;

    // 배경 바
    final bgPaint = Paint()..color = Colors.grey.shade200;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY - barHeight / 2, barWidth, barHeight),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // 눈금
    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final x = barLeft + (i / 10) * barWidth;
      canvas.drawLine(
        Offset(x, barY + barHeight / 2 + 4),
        Offset(x, barY + barHeight / 2 + 10),
        tickPaint,
      );
    }

    // 커서-타겟 연결선
    final cursorX = barLeft + cursorPosition * barWidth;
    final targetX = barLeft + targetPosition * barWidth;
    final dist = (cursorPosition - targetPosition).abs();
    final lineColor = Color.lerp(Colors.green, Colors.red, dist.clamp(0.0, 1.0))!;

    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.5)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(cursorX, barY),
      Offset(targetX, barY),
      linePaint,
    );

    // 타겟 (맥동하는 원)
    final pulse = 0.9 + 0.1 * math.sin(DateTime.now().millisecondsSinceEpoch / 200);
    final targetPaint = Paint()..color = Colors.green;
    canvas.drawCircle(Offset(targetX, barY), 20 * pulse, targetPaint);
    final targetInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(targetX, barY), 8, targetInner);

    // 커서
    final cursorPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(cursorX, barY), 16, cursorPaint);
    final cursorInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cursorX, barY), 6, cursorInner);

    // 정확도 히스토리 그래프 (하단)
    final graphTop = size.height * 0.65;
    final graphBottom = size.height * 0.85;
    final graphHeight = graphBottom - graphTop;
    final graphLeft = barLeft;
    final graphWidth = barWidth;

    // 그래프 배경
    final graphBg = Paint()..color = Colors.grey.shade100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(graphLeft, graphTop, graphWidth, graphHeight),
        const Radius.circular(8),
      ),
      graphBg,
    );

    // 50% 기준선
    final midPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(graphLeft, graphTop + graphHeight * 0.5),
      Offset(graphLeft + graphWidth, graphTop + graphHeight * 0.5),
      midPaint,
    );

    // 정확도 곡선
    if (accuracyHistory.length > 1) {
      final path = Path();
      for (int i = 0; i < accuracyHistory.length; i++) {
        final x = graphLeft + (i / (accuracyHistory.length - 1)) * graphWidth;
        final y = graphBottom - accuracyHistory[i] * graphHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final graphLinePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, graphLinePaint);
    }

    // 그래프 레이블
    _drawText(canvas, '100%', Offset(graphLeft - 40, graphTop - 6), 11, Colors.grey);
    _drawText(canvas, '50%', Offset(graphLeft - 30, graphTop + graphHeight * 0.5 - 6), 11, Colors.grey);
    _drawText(canvas, '0%', Offset(graphLeft - 22, graphBottom - 6), 11, Colors.grey);
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(TrackingPainter oldDelegate) => true;
}
