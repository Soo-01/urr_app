import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bluetooth.dart';
import 'robot_protocol.dart';

class RobotCommandService {
  RobotCommandService(this._bluetooth);

  final BluetoothService _bluetooth;

  bool get isConnected => _bluetooth.isConnected();

  Future<bool> send(String command) async {
    if (!_bluetooth.isConnected()) {
      debugPrint('[ROBOT TX] skipped (Bluetooth disconnected): $command');
      return false;
    }
    final normalized = command.replaceAll('\r', '').replaceAll('\n', '').trim();
    if (normalized.isEmpty) return false;
    final success = await _bluetooth.sendBytes(
      Uint8List.fromList(utf8.encode('$normalized\n')),
    );
    debugPrint('[ROBOT TX] ${success ? 'sent' : 'failed'}: $normalized');
    return success;
  }

  Future<bool> selectPart(String partCode) =>
      send(RobotProtocol.selectPart(partCode));

  /// Re-sends PART immediately before a motion command so the Jetson node
  /// cannot accidentally apply the command to a previously selected joint.
  Future<bool> sendForPart(String partCode, String command) async {
    final partSuccess = await selectPart(partCode);
    if (!partSuccess) {
      debugPrint('[ROBOT TX] skipped (PART failed): $command');
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return send(command);
  }

  Future<bool> stop() => send(RobotProtocol.stop);
}
