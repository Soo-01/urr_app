import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'generated/l10n.dart';
import 'dart:async'; // 25.06.02 추가내용
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';  // 25.08.25 추가내용
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'main.dart';
import 'record.dart';
import 'robot_command_service.dart';
import 'robot_protocol.dart';

class ROMModeSelectScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final Function(String, String)? onModeChanged;

  const ROMModeSelectScreen({
    super.key,
    required this.bluetoothService,
    this.onModeChanged,
  });

  @override
  _ROMModeSelectScreenState createState() => _ROMModeSelectScreenState();
}

class _ROMModeSelectScreenState extends State<ROMModeSelectScreen> {
  String _selectedMode = 'Stop';
  final Map<String, String> _velocityController = {
    'Passive ROM': '',
    'Stop': '',
    // 'ActiveROM': '',
  };

  // 25.06.02 추가내용
  final Map<String, double?> _currentAngles = {
    'Passive ROM': null,
    'Active ROM': null,
  };
  final Map<String, double?> _minAngles = {
    'Passive ROM': null,
    'Active ROM': null,
  };
  final Map<String, double?> _maxAngles = {
    'Passive ROM': null,
    'Active ROM': null,
  };
  double? get _currentAngle => _currentAngles[_selectedMode];
  set _currentAngle(double? value) => _currentAngles[_selectedMode] = value;
  double? get _minAngle => _minAngles[_selectedMode];
  set _minAngle(double? value) => _minAngles[_selectedMode] = value;
  double? get _maxAngle => _maxAngles[_selectedMode];
  set _maxAngle(double? value) => _maxAngles[_selectedMode] = value;
  StreamSubscription<RobotTelemetryFrame>? _btSubscription;
  bool _isMeasuring = false;
  bool _activeRom = false;
  bool _passiveRom = false;
  String? _measurementMode;
  String? _selectedPart;
  late final RobotCommandService _robotCommands;

  Widget rangeBar(double? minAngle, double? maxAngle, double? current) {
    if (minAngle == null || maxAngle == null) {
      // 값이 없을 때는 그냥 옅은 바만 표시
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // -100~100 → 0.0~1.0 정규화
    double norm(double a) => ((a + 100) / 200).clamp(0.0, 1.0);
    final start = norm(minAngle);
    final end = norm(maxAngle);
    final curNorm = current != null ? norm(current) : null;

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left = width * math.min(start, end);
          final right = width * (1.0 - math.max(start, end));
          final curX = curNorm != null ? (curNorm * width) : null;

          return Stack(
            children: [
              // 연한 전체 바
              Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 진한 min~max 구간
              Positioned(
                left: left,
                right: right,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // 3) 현재값 marker
              if (curX != null)
                Positioned(
                  left: curX - 3, // marker 중앙 정렬
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: Colors.white, // marker 색상
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // void _selectMode(String mode) {
  //   setState(() {
  //     _selectedMode = mode;
  //   });

  //   if (mode == 'Stop') {
  //     _saveData('stop');
  //     widget.onModeChanged?.call('Stop', '');
  //     _sendModeDataToBluetooth('Stop');
  //   }
  // }
  Future<void> _selectMode(String mode) async {
    if (mode == 'Stop') {
      await _robotCommands.stop();

      // 2) 측정/스트림/각도 상태 정리
      _btSubscription?.cancel();
      _btSubscription = null;

      setState(() {
        _selectedMode = 'Stop';
        _isMeasuring = false;
        _measurementMode = null;
        _currentAngle = null;
        _minAngle = null;
        _maxAngle = null;
      });

      // 3) 외부로 모드 변경 알림
      widget.onModeChanged?.call('Stop', '');
    } else {
      setState(() {
        _selectedMode = mode;
      });
    }
  }

  void _setVelocity(String velocity) {
    setState(() {
      _velocityController[_selectedMode] = velocity;
    });
  }

  //0827
  Future<bool> _sendPart(String partCode) async {
    final success = await _robotCommands.selectPart(partCode);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.bluetoothFailed)),
      );
    }
    return success;
  }

  // 25.06.02 추가내용
  @override
  void initState() {
    super.initState();
    _robotCommands = RobotCommandService(widget.bluetoothService);

    // _btSubscription ??= widget.bluetoothService.dataStream.listen((data) {
    //   final s = data.trim();
    //   print('[BT RX] "$s"');
    //   final angle = double.tryParse(s);
    //   if (angle == null) return;

    //   if (_isMeasuring) {  // ★ 측정 중일 때만 UI 반영
    //     setState(() {
    //       _currentAngle = angle;

    //       // (선택1) 적응형 범위 사용 시:
    //       if (_minAngle == null || angle < _minAngle!) _minAngle = angle;
    //       if (_maxAngle == null || angle > _maxAngle!) _maxAngle = angle;
    //     });
    //   }
    // });
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _saveData(String action) async {
    final selectedVelocity = _velocityController[_selectedMode];
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // if (_selectedMode == 'Stop') return;

    // 공통: 부위 선택 안 됐으면 바로 경고 후 리턴
    // if (_selectedMode != 'Stop' &&_selectedPart == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(AppLocalizations.of(context)!.selectPart)), // arb에 "selectPart" 추가
    //   );
    //   return;
    // }
    // 공통: 부위 선택 안 됐으면 바로 경고 후 리턴
    if (action != 'stop' && _selectedMode != 'Stop' && _selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .selectPart)), // arb에 "selectPart" 추가
      );
      return false;
    }

    String? cmd; // 실제로 보낼 문자열

    switch (_selectedMode) {
      // case 'stop':
      //   // if (action == 'save' || action == 'receive') {
      //   //   cmd = 'stop\n';   // ← 원하는 Stop 커맨드
      //   //   _activeRom = false;
      //   //   _passiveRom = false;
      //   // }
      //   cmd = 'stop\n';   // ← 원하는 Stop 커맨드
      //   _activeRom = false;
      //   _passiveRom = false;
      //   break;

      case 'Active ROM':
        if (action == 'receive') {
          if (!_activeRom) {
            cmd = RobotProtocol.arom;
          }
        } else if (action == 'save') {
          if (_activeRom) {
            cmd = RobotProtocol.stop;
          }
        }
        break;

      case 'Passive ROM':
        if (action == 'receive') {
          if (!_passiveRom) {
            if (selectedVelocity?.isEmpty ?? true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.selectVelocity),
                ),
              );
              return false;
            }
            final speed = (selectedVelocity?.isNotEmpty ?? false)
                ? RobotProtocol.speedLevelToRadPerSec(selectedVelocity!)
                : null;
            cmd = RobotProtocol.prom(speedRadPerSec: speed);
          }
        } else if (action == 'direction') {
          cmd = RobotProtocol.reverseProm;
        } else if (action == 'save') {
          if (_passiveRom) {
            cmd = RobotProtocol.stop;
          }
        }
        // if ((selectedVelocity?.isNotEmpty ?? false)) {
        //   await _speakCountdown(() async {
        //     widget.onModeChanged?.call(_selectedMode, selectedVelocity!);
        //     return await _sendModeDataToBluetooth(_selectedMode);
        //   });
        // } else {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       SnackBar(content: Text(AppLocalizations.of(context)!.selectVelocity)),
        //     );
        // }
        //  우선은 속도 입력 없이 실행시키는거 우선으로 진행
        break;
    }

    // softStop 추가
    if (action == 'stop') {
      cmd = RobotProtocol.stop;
    }

    // 실제로 보낼 명령이 있으면 BT로 전송
    if (cmd != null) {
      final part = _selectedPart;
      final success = action == 'receive' && part != null
          ? await _robotCommands.sendForPart(part, cmd)
          : await _robotCommands.send(cmd);
      if (!success) return false;
      if (!mounted) return false;
      if (action == 'save') {
        if (userProvider.name.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select or save a user first.')),
          );
          return false;
        }
        if (_selectedMode == 'Active ROM') {
          if (_minAngle == null || _maxAngle == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)!.noMeasuredAngle)),
            );
            return false;
          }
          await RecordManager.saveRecord(UserRecord(
            timestamp: DateTime.now(),
            userName: userProvider.name,
            recordType: _selectedMode,
            joint: _selectedPart!,
            minAngle: _minAngle,
            maxAngle: _maxAngle,
          ));
          userProvider.updateArom(_selectedPart!, _minAngle!, _maxAngle!);
        } else if (_selectedMode == 'Passive ROM') {
          if (_minAngle == null || _maxAngle == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)!.noMeasuredAngle)),
            );
            return false;
          }
          await RecordManager.saveRecord(UserRecord(
            timestamp: DateTime.now(),
            userName: userProvider.name,
            recordType: _selectedMode,
            joint: _selectedPart!,
            minAngle: _minAngle,
            maxAngle: _maxAngle,
            velocity: selectedVelocity ?? '',
          ));
          userProvider.updateProm(
              _selectedPart!, selectedVelocity ?? '', _minAngle!, _maxAngle!);
        }
      }
      if (action == 'receive') {
        _measurementMode = _selectedMode;
        _activeRom = _selectedMode == 'Active ROM';
        _passiveRom = _selectedMode == 'Passive ROM';
      } else if (action == 'save' || action == 'stop') {
        _measurementMode = null;
        _activeRom = false;
        _passiveRom = false;
      }
      return true;
    }
    return false;
  }

  void _listenToSelectedJoint() {
    _btSubscription?.cancel();
    _btSubscription = widget.bluetoothService.telemetryStream.listen((frame) {
      final joint = frame.jointForPart(_selectedPart);
      if (!_isMeasuring || joint == null || !joint.online || !mounted) return;
      final measurementMode = _measurementMode;
      if (measurementMode == null) return;
      final angle = joint.positionDegrees;
      final previousMin = _minAngles[measurementMode];
      final previousMax = _maxAngles[measurementMode];
      final newMin = previousMin == null ? angle : math.min(previousMin, angle);
      final newMax = previousMax == null ? angle : math.max(previousMax, angle);
      setState(() {
        _currentAngles[measurementMode] = angle;
        _minAngles[measurementMode] = newMin;
        _maxAngles[measurementMode] = newMax;
      });
    });
  }

  // Future<void> _saveAngleData() async {
  //   final loc = AppLocalizations.of(context)!;

  //   if (_selectedMode == 'Stop') return;

  //   if (_minAngle == null || _maxAngle == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('${loc.noMeasuredAngle}')),
  //     );
  //     return;
  //   }

  //   final now = DateTime.now().toString().split(' ')[0];
  //   final angleRange = '${_minAngle!.toStringAsFixed(1)}° ~ ${_maxAngle!.toStringAsFixed(1)}°';

  //   // 예시: 콘솔 출력 또는 기록 저장
  //   debugPrint('[$now] ${loc.measuredROM}: $angleRange');

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text('${loc.savedROM}: $angleRange')),
  //   );

  //   // 저장 후 초기화하고 측정 종료
  //   setState(() {
  //     _isMeasuring = false;
  //     // _currentAngle = null;   // 측정만 종료해서 측정 끝나더라도 값은 확인할 수 있도록.
  //     // _minAngle = null;
  //     // _maxAngle = null;
  //   });
  // }
  // rommode.dart 내의 _saveAngleData() 함수를 아래와 같이 수정하세요.

  /* 더미 ROM 기록 기능 비활성화 시작
  Future<void> _saveAngleData() async {
    final loc = AppLocalizations.of(context)!;
    final userProvider =
        Provider.of<UserProvider>(context, listen: false); // Provider 호출

    if (_selectedMode == 'Stop') return;

    ///////////////////////////////////////////////////////////// record.dart 테스트를 위해 아래 부분 잠시 주석함
    // if (_minAngle == null || _maxAngle == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('${loc.noMeasuredAngle}')),
    //   );
    //   return;
    // }
    ///////////////////////////////////////////////////////////// record.dart 테스트를 위해 윗 부분 잠시 주석함

    // ---------------------------------------------------------
    // 2. [테스트용 더미 데이터 설정 및 저장 연동]
    double dummyMinAngle = 10.5; // 가짜 최소 각도
    double dummyMaxAngle = 135.0; // 가짜 최대 각도

    String currentVelocity = _selectedMode == 'Passive ROM'
        ? (_velocityController['Passive ROM'] ?? 'N/A')
        : 'N/A';
    String details = 'Velocity: $currentVelocity'; // 필요시 Intensity 등 추가 가능

    // record.dart의 RecordManager를 호출하여 누적 저장합니다.
    await RecordManager.saveRecord(UserRecord(
      timestamp: DateTime.now(),
      // userName: '테스트유저', // 임시 사용자 이름 (나중엔 프로필 연동 필요)
      userName: userProvider.name,
      recordType: _selectedMode, // 'Passive ROM' 또는 'Active ROM'
      joint: _selectedPart ?? '관절 미선택', // 드롭다운에서 선택한 관절
      minAngle: dummyMinAngle, // 실제 구동 시엔 _minAngle! 로 복구
      maxAngle: dummyMaxAngle, // 실제 구동 시엔 _maxAngle! 로 복구
      // extraData: '테스트용 가짜 데이터입니다.',
      extraData: details, // ★ Selected Mode Settings의 내용들이 여기에 같이 저장됨
    ));
    // ---------------------------------------------------------

    final now = DateTime.now().toString().split(' ')[0];
    // final angleRange = '${_minAngle!.toStringAsFixed(1)}° ~ ${_maxAngle!.toStringAsFixed(1)}°'; /// record.dart 테스트를 위해 윗 부분 잠시 주석함
    final angleRange =
        '${dummyMinAngle.toStringAsFixed(1)}° ~ ${dummyMaxAngle.toStringAsFixed(1)}°';

    // ★ 1. Passive ROM과 Active ROM 구분하여 UserProvider에 데이터 저장
    if (_selectedMode == 'Passive ROM') {
      // 속도가 선택되지 않았을 경우를 대비한 기본값 처리
      final velocity = _velocityController['Passive ROM']?.isNotEmpty == true
          ? _velocityController['Passive ROM']!
          : 'N/A';

      userProvider.updateProm(
          _selectedPart!,
          velocity,
          // _minAngle!,
          // _maxAngle!
          dummyMinAngle, // _minAngle! 대신 더미값 사용  /// record.dart 테스트를 위해 잠시 주석함
          dummyMaxAngle // _maxAngle! 대신 더미값 사용  /// record.dart 테스트를 위해 잠시 주석함
          );
    } else if (_selectedMode == 'Active ROM') {
      userProvider.updateArom(
          _selectedPart!,
          // _minAngle!,
          // _maxAngle!
          dummyMinAngle, // _minAngle! 대신 더미값 사용  /// record.dart 테스트를 위해 잠시 주석함
          dummyMaxAngle // _maxAngle! 대신 더미값 사용  /// record.dart 테스트를 위해 잠시 주석함
          );
    }

    debugPrint('[$now] ${loc.measuredROM}: $angleRange');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${loc.savedROM}: $angleRange\n($_selectedMode 저장 완료)')),
    );

    // 저장 후 초기화하고 측정 종료
    setState(() {
      _isMeasuring = false;
    });
  }
  더미 ROM 기록 기능 비활성화 끝 */

//////////////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fontSizeFactor = Provider.of<FontSizeProvider>(context).scaleFactor;

    String getModeLabel(String mode) {
      switch (mode.toLowerCase()) {
        case 'passive rom':
          return loc.passiverom;

        case 'active rom':
          return loc.activerom;
        case 'stop':
          return loc.stop;
        default:
          return mode;
      }
    }

    //   String getPartLabel(String part) {  // 지금은 사용 안함. 나중에 필요할 수도?
    //   switch (part) {
    //     case 'lShoulderEF':
    //       return loc.lShoulderEF; // "Left Shoulder Ext/Flx"
    //     case 'lShoulderRo':
    //       return loc.lShoulderRo; // "Left Shoulder Int/Ext Rotation"
    //     case 'lElbow':
    //       return loc.lElbow;      // "Left Elbow Ext/Flx"
    //     case 'lWrist':
    //       return loc.lWrist;      // "Left Wrist Ext/Flx"
    //     default:
    //       return part;
    //   }
    // }

    return Scaffold(
      appBar: AppBar(title: Text(loc.modeSelect)),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: 300, // 드롭다운 버튼 너비 조절
                        child: DropdownMenu<String>(
                          initialSelection: _selectedPart,
                          hintText: loc.selectPart, // "Select Part"
                          dropdownMenuEntries: [
                            DropdownMenuEntry(
                                value: 'lShoulderEF', label: loc.lShoulderEF),
                            DropdownMenuEntry(
                                value: 'lShoulderRo', label: loc.lShoulderRo),
                            DropdownMenuEntry(
                                value: 'lElbow', label: loc.lElbow),
                            DropdownMenuEntry(
                                value: 'lWrist', label: loc.lWrist),
                            DropdownMenuEntry(
                                value: 'rShoulderEF', label: loc.rShoulderEF),
                            DropdownMenuEntry(
                                value: 'rShoulderRo', label: loc.rShoulderRo),
                            DropdownMenuEntry(
                                value: 'rElbow', label: loc.rElbow),
                            DropdownMenuEntry(
                                value: 'rWrist', label: loc.rWrist),
                          ],
                          onSelected: (value) async {
                            setState(() => _selectedPart = value);
                            if (value != null) {
                              await _sendPart(value); // 선택 즉시 전송
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  ...['Passive ROM', 'Active ROM'].map((mode) {
                    final isSelected = _selectedMode == mode;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor:
                              isSelected ? Colors.blue.shade100 : null,
                          side: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                          foregroundColor:
                              isSelected ? Colors.blue.shade900 : Colors.black,
                        ),
                        onPressed: () => _selectMode(mode),
                        child: Text(getModeLabel(mode)),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  if (_selectedMode != 'Stop') ...[
                    Text('${loc.mode}: ${getModeLabel(_selectedMode)}',
                        style: TextStyle(
                            fontSize: 24 * fontSizeFactor,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    if (_selectedMode == 'Passive ROM') ...[
                      Text(loc.selectVelocity),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        children: [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                          '10'
                        ].map((v) {
                          return ChoiceChip(
                            label: Text('$v'),
                            selected: _velocityController[_selectedMode] == v,
                            onSelected: (_) => _setVelocity(v),
                          );
                        }).toList(),
                      ),

                      // 25.06.02 추가내용
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // if (_isMeasuring) ...[
                          //   Text('${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 18)),
                          //   Text('${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                          //   Text('${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                          //   const SizedBox(height: 20),
                          //   LinearProgressIndicator(
                          //     value: (_currentAngle != null && _minAngle != null && _maxAngle != null
                          //             && (_maxAngle! - _minAngle!).abs() >= 1e-5)
                          //         ? (((_currentAngle! - _minAngle!) / (_maxAngle! - _minAngle!))
                          //             .clamp(0.0, 1.0)).toDouble()
                          //         : null,
                          //     minHeight: 10,
                          //   ),

                          // ]
                          if (_isMeasuring || _currentAngle != null) ...[
                            // Text('${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                            //     style: const TextStyle(fontSize: 18)),
                            // Text('${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                            //     style: const TextStyle(fontSize: 15)),
                            // Text('${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                            //     style: const TextStyle(fontSize: 15)),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 18 * fontSizeFactor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 여기서부터 rangeBar 적용
                            rangeBar(_minAngle, _maxAngle, _currentAngle),

                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('-100'),
                                Text('-75'),
                                Text('-50'),
                                Text('-25'),
                                Text('0'),
                                Text('25'),
                                Text('50'),
                                Text('75'),
                                Text('100'),
                              ],
                            ),
                          ] else
                            Text('${loc.waitMeasurement}',
                                style: TextStyle(
                                    fontSize: 18 * fontSizeFactor,
                                    color: Colors.grey)), // const
                        ],
                      ),

                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isMeasuring
                                ? null // 측정 중이면 버튼 비활성화(중복 루프 방지)
                                : () async {
                                    final sent = await _saveData('receive');
                                    if (!sent) return;

                                    // Passive ROM 모드에서 속도 선택 안 했으면 측정 시작하지 않음
                                    if (_selectedMode == 'Passive ROM' &&
                                        _selectedPart == null) {
                                      //   속도 선택 생략   (_velocityController[_selectedMode]?.isEmpty ?? true) ||
                                      return; // 여기서 종료 → _isMeasuring = true 안 됨 → Progress도 안 뜸
                                    }

                                    setState(() {
                                      _isMeasuring = true;
                                      _currentAngle = null;

                                      // 바로 determinate로 보이게 고정 범위(원하면 적응형은 null)
                                      _minAngle = null;
                                      _maxAngle = null;
                                    });

                                    // if (!_passiveRom) {           // 이미 ON이면 다시 안 보냄(토글 꼬임 방지)
                                    //   widget.bluetoothService.sendBytes(
                                    //     Uint8List.fromList(utf8.encode('prom\n')),
                                    //   );
                                    //   _passiveRom = true;
                                    // }

                                    _listenToSelectedJoint();
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.receive),
                          ),

                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () {
                              // widget.bluetoothService.sendBytes(
                              //   Uint8List.fromList(utf8.encode('dir\n')),   //  방향 전환 버튼
                              // );
                              _saveData('direction'); // dir\n 전송
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.direction),
                          ),

                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () async {
                              await _saveData('save'); // x\n 전송

                              // Passive ROM 동작 정지
                              // if (_passiveRom) {
                              //   widget.bluetoothService.sendBytes(
                              //     Uint8List.fromList(utf8.encode('x\n')), // 정지: x 입력
                              //   );
                              //   _passiveRom = false;
                              // }

                              // 각도 수신 구독도 중단
                              _btSubscription?.cancel();
                              _btSubscription = null;

                              // _isMeasuring = false;   // ← 루프 종료 신호
                              // setState(() {});        // UI 갱신
                              setState(() => _isMeasuring =
                                  false); // ★ 루프 종료 신호  // 측정 종료 플래그

                              // 임시 더미값(10.5°~135.0°) 저장 기능 비활성화.
                              // 실제 측정값 저장 정책 확정 후 다시 연결합니다.
                              // await _saveAngleData();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.save),
                          ),
                        ],
                      ),
                    ] else if (_selectedMode == 'Active ROM') ...[
                      const SizedBox(height: 16),

                      // 25.06.02 추가내용
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isMeasuring || _currentAngle != null) ...[
                            // Text('${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 18)),
                            // Text('${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                            // Text('${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 18 * fontSizeFactor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                                    style: TextStyle(
                                        fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            // LinearProgressIndicator(
                            //   value: (_currentAngle != null && _minAngle != null && _maxAngle != null
                            //           && (_maxAngle! - _minAngle!).abs() >= 0.5)  // 1e-5
                            //       ? (((_currentAngle! - _minAngle!) / (_maxAngle! - _minAngle!))
                            //           .clamp(0.0, 1.0)).toDouble()
                            //       : null,
                            //   minHeight: 10,
                            // ),

                            // LinearProgressIndicator(
                            //   value: (_currentAngle != null)
                            //       ? _norm100(_currentAngle!)  // -100→0.0, 0→0.5, 100→1.0
                            //       : null,                     // null이면 indeterminate
                            //   minHeight: 10,
                            // ),

                            rangeBar(_minAngle, _maxAngle, _currentAngle),

                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('-100'),
                                Text('-75'),
                                Text('-50'),
                                Text('-25'),
                                Text('0'),
                                Text('25'),
                                Text('50'),
                                Text('75'),
                                Text('100'),
                              ],
                            ),
                          ] else
                            Text('${loc.waitMeasurement}',
                                style: TextStyle(
                                    fontSize: 18 * fontSizeFactor,
                                    color: Colors.grey)), // const
                        ],
                      ),

                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isMeasuring
                                ? null // 측정 중이면 버튼 비활성화(중복 루프 방지)
                                : () async {
                                    final sent = await _saveData('receive');
                                    if (!sent) return;

                                    // Active ROM 모드에서 관절 선택 안 했으면 측정 시작하지 않음
                                    if (_selectedMode == 'Active ROM' &&
                                        _selectedPart == null) {
                                      return; // 여기서 종료 → _isMeasuring = true 안 됨 → Progress도 안 뜸
                                    }

                                    setState(() {
                                      _isMeasuring = true;
                                      _currentAngle = null;

                                      // 바로 determinate로 보이게 고정 범위(원하면 적응형은 null)
                                      _minAngle = null;
                                      _maxAngle = null;
                                    });

                                    // if (!_activeRom) {           // 이미 ON이면 다시 안 보냄(토글 꼬임 방지)
                                    //   widget.bluetoothService.sendBytes(
                                    //     Uint8List.fromList(utf8.encode('arom\n')),
                                    //   );
                                    //   _activeRom = true;
                                    // }

                                    _listenToSelectedJoint();
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.receive),
                          ),

                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () async {
                              await _saveData('save'); // BT 종료 명령

                              _btSubscription?.cancel();
                              _btSubscription = null;

                              setState(() => _isMeasuring = false);

                              // 임시 더미값(10.5°~135.0°) 저장 기능 비활성화.
                              // 실제 측정값 저장 정책 확정 후 다시 연결합니다.
                              // await _saveAngleData();

                              // if (_activeRom) {
                              //   widget.bluetoothService.sendBytes(
                              //     Uint8List.fromList(utf8.encode('arom\n')), // 펌웨어에 q(확실한 OFF)가 있으면 'q\n' 권장
                              //   );
                              //   _activeRom = false;
                              // }
                              // // _isMeasuring = false;   // ← 루프 종료 신호
                              // // setState(() {});        // UI 갱신

                              // // ★ 각도 수신 구독도 중단
                              // _btSubscription?.cancel();
                              // _btSubscription = null;

                              // setState(() => _isMeasuring = false); // ★ 루프 종료 신호

                              // _saveData(); // _saveAngleData();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.save),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: OutlinedButton(
                onPressed: () => _selectMode('Stop'),
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: const Size(150, 150),
                  backgroundColor: _selectedMode == 'Stop' ? Colors.red : null,
                  side: BorderSide(
                    color: _selectedMode == 'Stop' ? Colors.red : Colors.red,
                    width: 3,
                  ),
                  foregroundColor:
                      _selectedMode == 'Stop' ? Colors.white : Colors.black,
                ),
                child: Text(
                  loc.stop,
                  style: TextStyle(
                      fontSize: 30 * fontSizeFactor,
                      fontWeight: FontWeight.bold),
                ),
                // child: const Icon(
                //     Icons.pause,
                //     size: 80,
                //     color: Colors.black,
                //   ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
