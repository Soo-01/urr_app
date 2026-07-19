import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'generated/l10n.dart';
import 'dart:async'; // 25.06.02 추가내용
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'main.dart';
import 'robot_command_service.dart';
import 'robot_protocol.dart';

class ModeSelectScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final Function(String, String)? onModeChanged;

  const ModeSelectScreen({
    super.key,
    required this.bluetoothService,
    this.onModeChanged,
  });

  @override
  _ModeSelectScreenState createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  String _selectedMode = 'Stop';
  final Map<String, String> _velocityController = {
    // 'PassiveROM': '',
    // 'ActiveROM': '',
    'CPM': '',
    // 'Isometric': '',
    // 'Isotonic': '',
    'Stop': '',
  };
  final Map<String, String> _holddurationController = {
    'Isometric': '',
  };
  final Map<String, String> _resistanceController = {
    'Isotonic': '',
  };

  final TextEditingController _minAngleController = TextEditingController();
  final TextEditingController _maxAngleController = TextEditingController();
  final TextEditingController _targetAngleController = TextEditingController();

  Widget _buildNumberInput(
      {required String label, required TextEditingController controller}) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // 25.06.02 추가내용
  double? _currentAngle;
  double? _minAngle;
  double? _maxAngle;
  double? _currentTorque;
  double? _minTorque;
  double? _maxTorque;
  StreamSubscription<RobotTelemetryFrame>? _btSubscription;
  bool _isMeasuring = false;
  bool _isomActive = false;
  bool _cpmActive = false;
  String? _selectedPart;
  late final RobotCommandService _robotCommands;

  Widget rangeBar(double? min, double? max) {
    if (min == null || max == null) {
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
    double norm(double a) => ((a + 1) / 2).clamp(0.0, 1.0);
    final start = norm(min);
    final end = norm(max);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left = width * math.min(start, end);
          final right = width * (1.0 - math.max(start, end));

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
            ],
          );
        },
      ),
    );
  }

  // 여기부터 추가: CPM / Angle용 막대
  Widget angleRangeBar(double? minAngle, double? maxAngle, double? current) {
    if (minAngle == null || maxAngle == null) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // -100~100 → 0.0~1.0 정규화 (Active ROM 과 동일)
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
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

  Future<void> _selectMode(String mode) async {
    if (mode == 'Stop') {
      await _robotCommands.stop();

      // 상단 상태 표시 콜백도 Stop으로 리셋
      widget.onModeChanged?.call('Stop', '');

      // === 최종적으로 화면 Stop 모드로 전환 ===
      setState(() {
        _selectedMode = 'Stop';
        _cpmActive = false;
        _isomActive = false;
        _isMeasuring = false;
      });

      return;
    }

    // Stop 이외의 normal 모드 전환
    setState(() {
      _selectedMode = mode;
    });

    // 필요하면 새 모드로 바뀔 때 상단 상태 초기화
    widget.onModeChanged?.call(mode, '');
  }

  void _setVelocity(String velocity) {
    setState(() {
      _velocityController[_selectedMode] = velocity;
    });
  }

  void _setResistance(String resistance) {
    setState(() {
      _resistanceController[_selectedMode] = resistance;
    });
  }

  void _setHoldDuration(String duration) {
    setState(() {
      _holddurationController[_selectedMode] = duration;
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

  @override
  void initState() {
    super.initState();
    _robotCommands = RobotCommandService(widget.bluetoothService);

    _btSubscription ??= widget.bluetoothService.telemetryStream.listen((frame) {
      if (!_isMeasuring) return; // 가장 먼저 가드 걸기
      final joint = frame.jointForPart(_selectedPart);
      if (joint == null || !joint.online || !mounted) return;

      setState(() {
        if (_selectedMode == 'Isometric') {
          final torque = joint.measuredTorqueNm;
          _currentTorque = torque;
          if (_minTorque == null || torque < _minTorque!) _minTorque = torque;
          if (_maxTorque == null || torque > _maxTorque!) _maxTorque = torque;
        } else if (_selectedMode == 'CPM' || _selectedMode == 'Isotonic') {
          final angle = joint.positionDegrees;
          _currentAngle = angle;
          if (_minAngle == null || angle < _minAngle!) _minAngle = angle;
          if (_maxAngle == null || angle > _maxAngle!) _maxAngle = angle;
        }
      });
    });
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);

    // PROM 혹은 AROM 중 더 좁은 범위(또는 원하는 데이터)를 가져올 수 있습니다.
    // 예시: PROM 데이터가 존재하면 자동으로 불러오기
    if (userProvider.promData != null) {
      if (_minAngleController.text.isEmpty) {
        _minAngleController.text =
            userProvider.promData!['minAngle'].toStringAsFixed(1);
      }
      if (_maxAngleController.text.isEmpty) {
        _maxAngleController.text =
            userProvider.promData!['maxAngle'].toStringAsFixed(1);
      }
    }
  }

  Future<bool> _saveData(String action) async {
    final loc = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 공통: 사용자 정보 확인
    if (userProvider.name.isEmpty || userProvider.name == " ") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 먼저 입력하거나 불러와주세요.')),
      );
      return false;
    }

    // 공통: 부위 선택 안 됐으면 경고 후 리턴
    if (_selectedMode != 'Stop' && _selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.selectPart)),
      );
      return false;
    }

    String? cmd;
    Map<String, dynamic>? record;

    try {
      switch (_selectedMode) {
        case 'CPM':
          final minDegrees = double.tryParse(_minAngleController.text.trim());
          final maxDegrees = double.tryParse(_maxAngleController.text.trim());
          final level = _velocityController['CPM'] ?? '';
          if (action == 'receive') {
            if (minDegrees == null ||
                maxDegrees == null ||
                level.isEmpty ||
                _cpmActive) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.enterRangeAndVelocity)),
              );
              return false;
            }
            final speed = RobotProtocol.speedLevelToRadPerSec(level);
            cmd = RobotProtocol.cpm(
              minDegrees: minDegrees,
              maxDegrees: maxDegrees,
              speedRadPerSec: speed,
            );
            widget.onModeChanged
                ?.call(_selectedMode, '$minDegrees,$maxDegrees,$speed');
          } else if (action == 'save' && _cpmActive) {
            cmd = RobotProtocol.stop;
            record = {
              'type': 'Exercise',
              'mode': 'CPM',
              'part': _selectedPart,
              'minAngle': minDegrees ?? 0.0,
              'maxAngle': maxDegrees ?? 0.0,
              'velocity': level,
              'reps': 0,
              'date': DateTime.now().toString(),
            };
          }
          break;

        case 'Isometric':
          final target = double.tryParse(_targetAngleController.text.trim());
          final hold =
              double.tryParse(_holddurationController['Isometric'] ?? '');
          if (action == 'receive') {
            if (target == null || hold == null || _isomActive) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.enterAngleAndDuration)),
              );
              return false;
            }
            cmd = RobotProtocol.isometric(
                targetDegrees: target, holdSeconds: hold);
            widget.onModeChanged?.call(_selectedMode, '$target,$hold');
          } else if (action == 'stop' && _isomActive) {
            cmd = RobotProtocol.stop;
            record = {
              'type': 'Exercise',
              'mode': 'Isometric',
              'part': _selectedPart,
              'targetAngle': target ?? 0.0,
              'duration': hold?.toString() ?? '',
              'maxTorque': _maxTorque,
              'reps': 3,
              'date': DateTime.now().toString(),
            };
          }
          break;

        case 'Isotonic':
          final target = double.tryParse(_targetAngleController.text.trim());
          final resistance =
              double.tryParse(_resistanceController['Isotonic'] ?? '');
          if (action == 'receive') {
            if (target == null || resistance == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.enterRangeAndResistance)),
              );
              return false;
            }
            cmd = RobotProtocol.isotonic(
              targetDegrees: target,
              resistanceKg: resistance,
            );
            widget.onModeChanged?.call(_selectedMode, '$target,$resistance');
          } else if (action == 'save') {
            cmd = RobotProtocol.stop;
            record = {
              'type': 'Exercise',
              'mode': 'Isotonic',
              'subMode': 'Virtual resistance',
              'part': _selectedPart,
              'targetAngle': target ?? 0.0,
              'resistance': resistance?.toString() ?? '',
              'date': DateTime.now().toString(),
            };
          }
          break;

        case 'Stop':
          cmd = RobotProtocol.stop;
          break;
      }
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력 범위 또는 설정값을 확인해주세요.')),
      );
      return false;
    }

    if (cmd == null) return false;
    final isStart = action == 'receive';
    final part = _selectedPart;
    final success = isStart && part != null
        ? await _robotCommands.sendForPart(part, cmd)
        : await _robotCommands.send(cmd);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.bluetoothFailed)),
        );
      }
      return false;
    }

    if (record != null) userProvider.addRecord(record);
    if (!mounted) return true;
    setState(() {
      if (isStart) {
        _isMeasuring = true;
        _cpmActive = _selectedMode == 'CPM';
        _isomActive = _selectedMode == 'Isometric';
      } else {
        _isMeasuring = false;
        _cpmActive = false;
        _isomActive = false;
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fontSizeFactor = Provider.of<FontSizeProvider>(context).scaleFactor;

    String getModeLabel(String mode) {
      switch (mode.toLowerCase()) {
        case 'cpm':
          return loc.cpm;
        case 'isometric':
          return loc.isometric;
        case 'isotonic':
          return loc.isotonic;
        case 'stop':
          return loc.stop;
        default:
          return mode;
      }
    }

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
                  ...['CPM', 'Isometric', 'Isotonic'].map((mode) {
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
                    if (_selectedMode == 'CPM') ...[
                      if (!_cpmActive) ...[
                        // === (1) 설정 화면: Range + Velocity 선택 ===
                        Text(loc.selectRange),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberInput(
                              label: loc.minAngle,
                              controller: _minAngleController,
                            ),
                            _buildNumberInput(
                              label: loc.maxAngle,
                              controller: _maxAngleController,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                      ] else ...[
                        // === (2) Indicator 화면: Active ROM 스타일의 각도 표시 ===
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isMeasuring || _currentAngle != null) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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

                              // Active ROM 과 동일한 스타일의 각도 indicator
                              angleRangeBar(
                                  _minAngle, _maxAngle, _currentAngle),

                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              Text(
                                '${loc.waitMeasurement}',
                                style: TextStyle(
                                  fontSize: 18 * fontSizeFactor,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ],

                      // 여기부터는 CPM 모드의 “기본 버튼들” (indicator 여부와 무관하게 항상 보임)
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // RECEIVE 버튼: cpm 시작 + indicator 전환
                          ElevatedButton(
                            onPressed: !_cpmActive
                                ? () => _saveData('receive')
                                : null, // 이미 동작 중이면 비활성화
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.receive),
                          ),

                          const SizedBox(width: 20),

                          // SAVE 버튼: CPM 정지 (x\n) + 측정 종료
                          ElevatedButton(
                            onPressed: _cpmActive
                                ? () => _saveData('save')
                                : null, // 동작 중일 때만 활성화
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
                    ] else if (_selectedMode == 'Isometric') ...[
                      if (!_isomActive) ...[
                        Text(loc.selectAngle),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberInput(
                                label: loc.targetAngle,
                                controller: _targetAngleController),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(loc.selectHoldDuration),
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
                              selected:
                                  _holddurationController[_selectedMode] == v,
                              onSelected: (_) => _setHoldDuration(v),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // RECEIVE 버튼: isometric,targetAngle,duration\n → 시작
                            ElevatedButton(
                              onPressed: () => _saveData('receive'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                textStyle:
                                    TextStyle(fontSize: 18 * fontSizeFactor),
                              ),
                              // child: Text(loc.receive),
                              child: Text(loc.start),
                            ),

                            const SizedBox(width: 20),

                            // STOP 버튼: 아직 시작 전이라 비활성(보기만)
                            ElevatedButton(
                              onPressed:
                                  null, // _isomActive == false 이므로 stop은 의미 없어서 disable
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                textStyle:
                                    TextStyle(fontSize: 18 * fontSizeFactor),
                              ),
                              child: Text(loc.stop),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isMeasuring || _currentTorque != null) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loc.minTorque}: ${_minTorque?.toStringAsFixed(1) ?? '-'} Nm',
                                      style: TextStyle(
                                          fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.currentTorque}: ${_currentTorque?.toStringAsFixed(1) ?? '-'} Nm',
                                      style: TextStyle(
                                          fontSize: 18 * fontSizeFactor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.maxTorque}: ${_maxTorque?.toStringAsFixed(1) ?? '-'} Nm',
                                      style: TextStyle(
                                          fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              rangeBar(_minTorque, _maxTorque),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('-1'),
                                  Text('-0.5'),
                                  Text('0'),
                                  Text('0.5'),
                                  Text('1')
                                ],
                              ),

                              // 여기부터 Stop 버튼 추가
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 운동 중에는 Receive는 비활성화
                                  ElevatedButton(
                                    onPressed: null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      textStyle: TextStyle(
                                          fontSize: 18 * fontSizeFactor),
                                    ),
                                    child: Text(loc.receive),
                                  ),

                                  const SizedBox(width: 20),

                                  // STOP 버튼: isom_stop\n 전송
                                  ElevatedButton(
                                    onPressed: () => _saveData('stop'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      textStyle: TextStyle(
                                          fontSize: 18 * fontSizeFactor),
                                    ),
                                    // child: Text(loc.save),  // UI 텍스트를 Stop으로 바꾸고 싶으면 loc.stop 써도 됨
                                    child: Text(loc.stop),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                '${loc.waitMeasurement}',
                                style: TextStyle(
                                    fontSize: 18 * fontSizeFactor,
                                    color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    ] else if (_selectedMode == 'Isotonic') ...[
                      Text(loc.selectAngle),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberInput(
                            label: loc.targetAngle,
                            controller: _targetAngleController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(loc.selectResistance),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        children: ['1', '2', '3', '4', '5'].map((v) {
                          return ChoiceChip(
                            label: Text('$v'),
                            selected: _resistanceController[_selectedMode] == v,
                            onSelected: (_) => _setResistance(v),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isMeasuring
                                ? null
                                : () => _saveData('receive'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.start),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed:
                                _isMeasuring ? () => _saveData('save') : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              textStyle:
                                  TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.stop),
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
                    color: Colors.red,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
