import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../bluetooth.dart';

/// 게임↔모터 브리지 클래스.
/// 게임에서 모터 명령을 안전하게 전송하고, BT 연결 상태를 감시한다.
class GameMotorController {
  final BluetoothService bt;
  Timer? _watchdog;
  DateTime? _lastDataReceived;
  bool _motorActive = false;
  String _currentJoint = '';
  String _currentMode = ''; // 'cpm', 'isometric', 'isotonic', ''

  /// BT 데이터 수신 없이 이 시간이 지나면 자동 정지 (밀리초)
  static const int watchdogTimeoutMs = 3000;

  /// 모터 저항/속도 상한선 (하드코딩 안전 제한)
  static const double maxResistance = 5.0;
  static const double maxCpmVelocity = 10.0;
  static const double maxIsometricHoldTime = 10.0;

  GameMotorController({required this.bt});

  bool get isConnected => bt.isConnected();
  bool get isMotorActive => _motorActive;
  String get currentJoint => _currentJoint;

  // ─── 관절 선택 ───

  Future<bool> selectJoint(String jointCode) async {
    _currentJoint = jointCode;
    return _send('PART:$jointCode\n');
  }

  // ─── 모터 모드 시작 ───

  Future<bool> startCPM(double maxAngle, double minAngle, {double velocity = 3.0}) async {
    velocity = velocity.clamp(1.0, maxCpmVelocity);
    _currentMode = 'cpm';
    _motorActive = true;
    return _send('cpm,$maxAngle,$minAngle\n');
  }

  Future<bool> startIsometric(double targetAngle, double holdTime) async {
    holdTime = holdTime.clamp(1.0, maxIsometricHoldTime);
    _currentMode = 'isometric';
    _motorActive = true;
    return _send('isometric,$targetAngle,$holdTime\n');
  }

  Future<bool> startIsotonic(double resistance) async {
    resistance = resistance.clamp(0.0, maxResistance);
    _currentMode = 'isotonic';
    _motorActive = true;
    return _send('isotonic,$resistance\n');
  }

  // ─── 정지 ───

  /// 긴급 정지 — 어떤 상황에서든 즉시 실행
  Future<bool> emergencyStop() async {
    _motorActive = false;
    _currentMode = '';
    stopWatchdog();
    return _send('x\n');
  }

  /// 현재 모드에 맞는 안전 정지
  Future<bool> safeStop() async {
    bool result;
    switch (_currentMode) {
      case 'isometric':
        result = await _send('isom_stop\n');
        break;
      case 'cpm':
      case 'isotonic':
      default:
        result = await _send('x\n');
    }
    _motorActive = false;
    _currentMode = '';
    return result;
  }

  // ─── 워치독 (BT 연결 감시) ───

  /// 게임 시작 시 호출. BT 데이터가 일정 시간 없으면 자동 정지.
  void startWatchdog() {
    _lastDataReceived = DateTime.now();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!bt.isConnected()) {
        emergencyStop();
        return;
      }
      if (_motorActive && _lastDataReceived != null) {
        final elapsed = DateTime.now().difference(_lastDataReceived!).inMilliseconds;
        if (elapsed > watchdogTimeoutMs) {
          emergencyStop();
        }
      }
    });
  }

  void stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// BT 데이터 수신 시마다 호출하여 워치독 리셋
  void notifyDataReceived() {
    _lastDataReceived = DateTime.now();
  }

  // ─── 각도 스트림 (정규화 전 raw) ───

  /// 게임용 raw 각도 스트림 (String → double)
  Stream<double> get angleStream => bt.dataStream
      .map((s) => double.tryParse(s.trim()))
      .where((v) => v != null)
      .cast<double>();

  // ─── 내부 ───

  Future<bool> _send(String cmd) async {
    if (!bt.isConnected()) return false;
    return bt.sendBytes(Uint8List.fromList(utf8.encode(cmd)));
  }

  void dispose() {
    stopWatchdog();
  }
}
