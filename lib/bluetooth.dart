import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';  // 25.06.02 추가내용
import 'dart:async';   // 25.06.02 추가내용


class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;

  final StreamController<String> _dataController = StreamController<String>.broadcast();  // 25.06.02 추가내용
  Stream<String> get dataStream => _dataController.stream;  // 25.06.02 추가내용

  BluetoothService._internal();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  BluetoothDevice? connectedDevice;

  // 0903
  String _buf = '';
  VoidCallback? _onDisconnectedCb;

  
  Future<void> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    if (statuses.values.any((status) => status != PermissionStatus.granted)) {
      throw Exception("Bluetooth permissions not granted");
    }
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Future<void> connect(BluetoothDevice device, VoidCallback onDisconnected) async {
    if (_connection != null && _connection!.isConnected) {
      await _connection!.close();
    }

    _connection = await BluetoothConnection.toAddress(device.address);
    // initializeStream(); // Bluetooth 데이터 수신 스트림 초기화  // 25.06.17 추가내용
    connectedDevice = device;
    // ensureListening();                   // 250826 추가: 단일 구독 시작
    // debugPrint('Connected to ${device.name}');    // 0903

    // 0903
    // _connection!.input?.listen(null).onDone(() {
    // debugPrint('Disconnected from ${device.name}');
    // connectedDevice = null;
    // _connection = null;
    // onDisconnected(); // 연결 끊김 콜백 호출
    // });

    _onDisconnectedCb = onDisconnected;
    initializeStream();
    debugPrint('Connected to ${device.name}');
  }

  Future<bool> sendBytes(Uint8List data) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        _connection!.output.add(data);
        await _connection!.output.allSent;
        debugPrint('Data sent to ${connectedDevice?.name}');
        return true;
      } else {
        throw Exception('Bluetooth not connected');
      }
    } catch (e) {
      debugPrint("Send failed: $e");
      return false;
    }
  }

  // 25.06.02 추가내용
  Future<String?> receiveByte() async {
  try {
    if (_connection != null && _connection!.isConnected) {
      // 데이터가 들어올 때까지 첫 패킷을 기다림
      final data = await _connection!.input!.first;
      final received = utf8.decode(data, allowMalformed: true).trim();
      debugPrint('Data received from ${connectedDevice?.name}: $received');
      return received;
    } else {
      throw Exception('Bluetooth not connected');
    }
  } catch (e) {
    debugPrint("Receive failed: $e");
    return null;
  }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    connectedDevice = null;
    debugPrint("Disconnected");
  }

  bool isConnected() {
    return _connection != null && _connection!.isConnected;
  }

  Stream<BluetoothDiscoveryResult> startDiscovery() {
    return _bluetooth.startDiscovery();
  }

  void cancelDiscovery() {
    _bluetooth.cancelDiscovery();
  }

  // 0903
  void initializeStream() {
    // 단일 구독: input은 single-subscription stream
    _connection!.input!.listen(
      (Uint8List data) {
        // 바이트 → UTF-8 문자열로 누적
        _buf += utf8.decode(data, allowMalformed: true);

        // \n 기준으로 라인 분리해 String 스트림으로 push
        int idx;
        while ((idx = _buf.indexOf('\n')) != -1) {
          final line = _buf.substring(0, idx).trim();
          _buf = _buf.substring(idx + 1);
          if (line.isNotEmpty) {
            // debugPrint('[BluetoothService] line: $line');
            _dataController.add(line);    // ← 앱의 dataStream 으로 전달 (예: "12.34")
          }
        }
      },
      onDone: () {
        debugPrint('Disconnected from ${connectedDevice?.name}');
        connectedDevice = null;
        _connection = null;
        _onDisconnectedCb?.call();        // ← 화면 콜백 호출
      },
      onError: (e, st) {
        debugPrint('BT input error: $e');
      },
      cancelOnError: false,
    );
  }


}
