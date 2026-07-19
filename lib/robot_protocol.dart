import 'dart:convert';
import 'dart:math' as math;

/// Command and telemetry contract shared by the Flutter UI and
/// motor_control_v5_2.cpp through a Jetson Bluetooth-ROS bridge.
class RobotProtocol {
  RobotProtocol._();

  /// Parts exposed by the tablet UI. The current motor_control_v5_2.cpp
  /// accepts only [currentlySupportedParts], but the complete list remains in
  /// the UI for future left-arm and wrist hardware.
  static const Set<String> knownParts = {
    'lShoulderEF',
    'lShoulderRo',
    'lElbow',
    'lWrist',
    'rShoulderEF',
    'rShoulderRo',
    'rElbow',
    'rWrist',
  };

  static const Set<String> currentlySupportedParts = {
    'rShoulderEF',
    'rShoulderRo',
    'rElbow',
  };

  static String selectPart(String partCode) {
    if (!knownParts.contains(partCode)) {
      throw ArgumentError.value(partCode, 'partCode', 'Unknown part');
    }
    return 'PART:$partCode';
  }

  static const String arom = 'arom';
  static const String reverseProm = 'dir';
  static const String stop = 'stop';
  static const String isometricStop = 'isom_stop';

  static String prom({double? speedRadPerSec}) {
    if (speedRadPerSec == null) return 'prom';
    if (!speedRadPerSec.isFinite || speedRadPerSec <= 0) {
      throw ArgumentError.value(speedRadPerSec, 'speedRadPerSec');
    }
    return 'prom,${_number(speedRadPerSec)}';
  }

  static String cpm({
    required double minDegrees,
    required double maxDegrees,
    double? speedRadPerSec,
  }) {
    if (!minDegrees.isFinite ||
        !maxDegrees.isFinite ||
        minDegrees >= maxDegrees) {
      throw ArgumentError('CPM requires finite minDegrees < maxDegrees');
    }
    if (speedRadPerSec != null &&
        (!speedRadPerSec.isFinite || speedRadPerSec <= 0)) {
      throw ArgumentError.value(speedRadPerSec, 'speedRadPerSec');
    }
    final speed = speedRadPerSec == null ? '' : ',${_number(speedRadPerSec)}';
    return 'cpm,${_number(minDegrees)},${_number(maxDegrees)}$speed';
  }

  static String isometric({
    required double targetDegrees,
    required double holdSeconds,
  }) {
    if (!targetDegrees.isFinite || !holdSeconds.isFinite || holdSeconds < 0) {
      throw ArgumentError('Invalid isometric settings');
    }
    return 'isometric,${_number(targetDegrees)},${_number(holdSeconds)}';
  }

  static String isotonic({
    required double targetDegrees,
    required double resistanceKg,
  }) {
    if (!targetDegrees.isFinite || !resistanceKg.isFinite || resistanceKg < 0) {
      throw ArgumentError('Invalid isotonic settings');
    }
    return 'isotonic,${_number(targetDegrees)},${_number(resistanceKg)}';
  }

  /// UI speed levels 1..10 map to a conservative 0.01..0.10 rad/s.
  static double speedLevelToRadPerSec(String level) {
    final value = int.tryParse(level);
    if (value == null || value < 1 || value > 10) {
      throw ArgumentError.value(level, 'level', 'Expected 1 through 10');
    }
    return value / 100.0;
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class JointTelemetry {
  const JointTelemetry({
    required this.id,
    required this.online,
    required this.positionRad,
    required this.velocityRadPerSec,
    required this.commandedTorqueNm,
    required this.measuredTorqueNm,
    this.isometric,
  });

  final int id;
  final bool online;
  final double positionRad;
  final double velocityRadPerSec;
  final double commandedTorqueNm;
  final double measuredTorqueNm;
  final IsometricTelemetry? isometric;

  double get positionDegrees => positionRad * 180.0 / math.pi;
  double get velocityDegreesPerSec => velocityRadPerSec * 180.0 / math.pi;

  static JointTelemetry? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = _asInt(value['id']);
    final position = _asFiniteDouble(value['pos']);
    final velocity = _asFiniteDouble(value['vel']);
    final commandedTorque = _asFiniteDouble(value['tau_cmd']);
    final measuredTorque = _asFiniteDouble(value['tau_meas']);
    if (id == null ||
        position == null ||
        velocity == null ||
        commandedTorque == null ||
        measuredTorque == null) {
      return null;
    }
    return JointTelemetry(
      id: id,
      online: _asInt(value['online']) == 1,
      positionRad: position,
      velocityRadPerSec: velocity,
      commandedTorqueNm: commandedTorque,
      measuredTorqueNm: measuredTorque,
      isometric: IsometricTelemetry.fromJson(value['isometric']),
    );
  }
}

enum IsometricPhase { idle, moving, holding, resting, completed }

class IsometricTelemetry {
  const IsometricTelemetry({
    required this.phase,
    required this.rep,
    required this.totalReps,
    required this.remainingMs,
  });

  final IsometricPhase phase;
  final int rep;
  final int totalReps;
  final int remainingMs;

  static IsometricTelemetry? fromJson(Object? value) {
    if (value is! Map) return null;
    final phase = switch (value['phase']) {
      'idle' => IsometricPhase.idle,
      'moving' => IsometricPhase.moving,
      'holding' => IsometricPhase.holding,
      'resting' => IsometricPhase.resting,
      'completed' => IsometricPhase.completed,
      _ => null,
    };
    final rep = _asInt(value['rep']);
    final totalReps = _asInt(value['total_reps']);
    final remainingMs = _asInt(value['remaining_ms']);
    if (phase == null ||
        rep == null ||
        totalReps == null ||
        remainingMs == null ||
        rep < 0 ||
        totalReps < 0 ||
        remainingMs < 0) {
      return null;
    }
    return IsometricTelemetry(
      phase: phase,
      rep: rep,
      totalReps: totalReps,
      remainingMs: remainingMs,
    );
  }
}

class RobotTelemetryFrame {
  RobotTelemetryFrame({
    required this.arm,
    required this.joints,
    required this.receivedAt,
  });

  final String arm;
  final List<JointTelemetry> joints;
  final DateTime receivedAt;

  static RobotTelemetryFrame? tryParse(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map ||
          decoded['arm'] is! String ||
          decoded['state'] is! List) {
        return null;
      }
      final joints = (decoded['state'] as List)
          .map(JointTelemetry.fromJson)
          .whereType<JointTelemetry>()
          .toList(growable: false);
      if (joints.isEmpty) return null;
      return RobotTelemetryFrame(
        arm: decoded['arm'] as String,
        joints: joints,
        receivedAt: DateTime.now(),
      );
    } on FormatException {
      return null;
    }
  }

  JointTelemetry? jointForPart(String? partCode) {
    if (partCode == null) return null;
    const jointIds = {
      'lShoulderEF': 0,
      'lShoulderRo': 1,
      'lElbow': 2,
      'lWrist': 3,
      'rShoulderEF': 0,
      'rShoulderRo': 1,
      'rElbow': 2,
      'rWrist': 3,
    };
    final expectedArm = partCode.startsWith('l') ? 'LEFT' : 'RIGHT';
    if (arm != expectedArm) return null;
    final id = jointIds[partCode];
    if (id == null) return null;
    for (final joint in joints) {
      if (joint.id == id) return joint;
    }
    return null;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _asFiniteDouble(Object? value) {
  if (value is! num) return null;
  final result = value.toDouble();
  return result.isFinite ? result : null;
}
