import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:exo_tablet_app_v6/robot_protocol.dart';

void main() {
  group('RobotProtocol commands', () {
    test('matches motor_control_v5_2 command grammar', () {
      expect(RobotProtocol.selectPart('rElbow'), 'PART:rElbow');
      expect(
        RobotProtocol.cpm(minDegrees: 10, maxDegrees: 90, speedRadPerSec: 0.05),
        'cpm,10,90,0.05',
      );
      expect(
        RobotProtocol.isometric(targetDegrees: 60, holdSeconds: 5),
        'isometric,60,5',
      );
      expect(RobotProtocol.isometricStop, 'isom_stop');
      expect(
        RobotProtocol.isotonic(targetDegrees: 90, resistanceKg: 1),
        'isotonic,90,1',
      );
    });

    test('keeps all UI parts but rejects unknown codes and reversed CPM ranges',
        () {
      expect(RobotProtocol.selectPart('rWrist'), 'PART:rWrist');
      expect(RobotProtocol.selectPart('lElbow'), 'PART:lElbow');
      expect(
          () => RobotProtocol.selectPart('unknownJoint'), throwsArgumentError);
      expect(
        () => RobotProtocol.cpm(minDegrees: 90, maxDegrees: 10),
        throwsArgumentError,
      );
    });

    test('inverts only right shoulder EF and right elbow angles', () {
      expect(
        RobotProtocol.cpmForPart(
          partCode: 'rShoulderEF',
          minDegrees: 10,
          maxDegrees: 90,
          speedRadPerSec: 0.05,
        ),
        'cpm,-90,-10,0.05',
      );
      expect(
        RobotProtocol.isometricForPart(
          partCode: 'rElbow',
          targetDegrees: 60,
          holdSeconds: 5,
        ),
        'isometric,-60,5',
      );
      expect(
        RobotProtocol.isotonicForPart(
          partCode: 'rShoulderRo',
          targetDegrees: 60,
          resistanceKg: 1,
        ),
        'isotonic,60,1',
      );
      expect(RobotProtocol.toUiDegrees('rElbow', -45), 45);
      expect(RobotProtocol.toUiDegrees('rShoulderEF', -30), 30);
      expect(RobotProtocol.toUiDegrees('rShoulderRo', -30), -30);
    });
  });

  test('parses joint state JSON and converts radians to degrees', () {
    const line =
        '{"arm":"RIGHT","state":[{"id":0,"online":1,"pos":1.5707963267948966,'
        '"vel":0.5,"tau_cmd":1.2,"tau_meas":1.1}]}';
    final frame = RobotTelemetryFrame.tryParse(line);
    final joint = frame?.jointForPart('rShoulderEF');

    expect(frame?.arm, 'RIGHT');
    expect(joint?.online, isTrue);
    expect(joint?.positionDegrees, closeTo(90, 1e-9));
    expect(joint?.velocityDegreesPerSec, closeTo(0.5 * 180 / math.pi, 1e-9));
    expect(joint?.measuredTorqueNm, 1.1);
  });

  test('parses M7 isometric phase, repetition, and countdown', () {
    const line = '{"arm":"RIGHT","state":[{"id":2,"online":1,"pos":0.1,'
        '"vel":0.0,"tau_cmd":2.2,"tau_meas":2.0,'
        '"isometric":{"phase":"holding","rep":2,"total_reps":3,'
        '"remaining_ms":2450}}]}';

    final isometric =
        RobotTelemetryFrame.tryParse(line)?.jointForPart('rElbow')?.isometric;

    expect(isometric?.phase, IsometricPhase.holding);
    expect(isometric?.rep, 2);
    expect(isometric?.totalReps, 3);
    expect(isometric?.remainingMs, 2450);
  });

  test('keeps joint telemetry usable when isometric status is malformed', () {
    const line = '{"arm":"RIGHT","state":[{"id":2,"online":1,"pos":0.1,'
        '"vel":0.0,"tau_cmd":2.2,"tau_meas":2.0,'
        '"isometric":{"phase":"unknown","rep":2,"total_reps":3,'
        '"remaining_ms":2450}}]}';

    final joint = RobotTelemetryFrame.tryParse(line)?.jointForPart('rElbow');

    expect(joint, isNotNull);
    expect(joint?.isometric, isNull);
  });
}
