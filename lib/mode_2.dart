import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth.dart';
import 'generated/l10n.dart';
import 'dart:async'; // 25.06.02 추가내용
import 'dart:convert'; // 25.08.25 추가내용
import 'dart:math' as math;

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
  StreamSubscription<String>? _btSubscription;
  bool _isMeasuring = false;
  // bool _activeRom = false;
  String? _selectedPart;
  bool _isoActiveUI = false;

  Widget rangeBar(double? minAngle, double? maxAngle) {
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

  void _selectMode(String mode) {
    setState(() {
      _selectedMode = mode;
    });

    if (mode == 'Stop') {
      widget.onModeChanged?.call('Stop', '');
      _sendModeDataToBluetooth('Stop');
    }
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
  Future<void> _sendPart(String partCode) async {
    //  추후 Jetson에 전송하기 위해 만들어둠. 지금은 딱히 사용 x. Debug print로 출력만 확인
    // 예: PART:<code> 형식으로 단독 전송
    final payload = 'PART:$partCode';
    // await BluetoothService.instance.send(payload);
    debugPrint('[ROM] send $payload');
  }

  // 25.06.02 추가내용
  @override
  void initState() {
    super.initState();

    _btSubscription ??= widget.bluetoothService.dataStream.listen((data) {
      final s = data.trim();
      print('[BT RX] "$s"');
      final angle = double.tryParse(s);
      if (angle == null) return;

      if (_isMeasuring) {
        // ★ 측정 중일 때만 UI 반영
        setState(() {
          _currentAngle = angle;

          // (선택1) 적응형 범위 사용 시:
          if (_minAngle == null || angle < _minAngle!) _minAngle = angle;
          if (_maxAngle == null || angle > _maxAngle!) _maxAngle = angle;
        });
      }
    });
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _sendModeDataToBluetooth(String mode,
      {String? extraData}) async {
    String message;
    final selectedVelocity = _velocityController[mode] ?? "";
    final selectedResistance = _resistanceController[mode] ?? "";
    final selectedHoldDuration = _holddurationController[mode] ?? "";

    switch (mode) {
      // case 'PassiveROM':
      //   message = 'mode:A,$selectedVelocity';
      //   break;
      // case 'ActiveROM':
      //   message = 'mode:B,$selectedVelocity';
      //   break;
      case 'CPM':
        // message = 'mode:C,$selectedVelocity';
        message = extraData != null
            ? 'CPM,$extraData\n' // 예: 10,40,3
            : 'CPM,$selectedVelocity\n';
        break;
      case 'Isometric':
        // message = 'mode:D,$extraData,$selectedHoldDuration\n';  //  $targetAngle
        message = extraData != null
            ? 'isometric,$extraData\n' // 예: 10,40,3
            : 'isometric,$selectedHoldDuration\n';
        break;
      case 'Isotonic':
        message = 'isotonic,$selectedResistance\n';
        break;
      case 'Stop':
        message = 'mode:S\n';
        break;
      default:
        return false;
    }

    try {
      final success = await widget.bluetoothService.sendBytes(
        Uint8List.fromList(message.codeUnits),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(success
                ? '${AppLocalizations.of(context)!.bluetoothMessageSent}: $message'
                : AppLocalizations.of(context)!.bluetoothFailed)),
      );
      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.bluetoothError}: $e')),
      );
      return false;
    }
  }

  Future<void> _speakCountdown(Function sendAction) async {
    final loc = AppLocalizations.of(context)!;
    final tts = FlutterTts();
    final langCode = loc.localeName == 'ko' ? 'ko-KR' : 'en-US';

    await tts.setLanguage(langCode);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);

    final success = await sendAction();

    if (success) {
      for (int i = 5; i > 0; i--) {
        await tts.speak('$i');
        await tts.awaitSpeakCompletion(true);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.bluetoothFailed)),
      );
    }
  }

  // Future<void> _saveData() async {
  //   final selectedVelocity = _velocityController[_selectedMode];

  //   if (_selectedMode != 'Stop') {
  //     if ((selectedVelocity?.isNotEmpty ?? false)) {
  //       await _speakCountdown(() async {
  //         widget.onModeChanged?.call(_selectedMode, selectedVelocity!);
  //         return await _sendModeDataToBluetooth(_selectedMode);
  //       });
  //     } else {
  // ScaffoldMessenger.of(context).showSnackBar(
  //   SnackBar(content: Text(AppLocalizations.of(context)!.selectVelocity)),
  // );
  //     }
  //   }
  // }

  Future<void> _saveData() async {
    final selectedVelocity = _velocityController[_selectedMode];
    final selectedResistance = _resistanceController[_selectedMode];
    final selectedHoldDuration = _holddurationController[_selectedMode];
    final minAngle = _minAngleController.text;
    final maxAngle = _maxAngleController.text;
    final targetAngle = _targetAngleController.text;

    if (_selectedMode == 'Stop') return;

    // 공통: 부위 선택 안 됐으면 바로 경고 후 리턴
    if (_selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .selectPart)), // arb에 "selectPart" 추가
      );
      return;
    }

    switch (_selectedMode) {
      // case 'Passive ROM':
      // case 'Active ROM':
      case 'Isometric':
        if ((selectedHoldDuration?.isNotEmpty ?? false) &&
            targetAngle.isNotEmpty) {
          await _speakCountdown(() async {
            widget.onModeChanged
                ?.call(_selectedMode, '$targetAngle,$selectedHoldDuration');

            // return await _sendModeDataToBluetooth(_selectedMode,
            //     extraData: '$targetAngle,$selectedHoldDuration');

            // ✅ 1) 블루투스로 명령 전송
            final result = await _sendModeDataToBluetooth(
              _selectedMode,
              extraData: '$targetAngle,$selectedHoldDuration',
            );

            // ✅ 2) 전송이 끝난 뒤 화면 전환
            if (mounted) {
              setState(() {
                _isoActiveUI = true; // ← 여기서 Indicator 화면으로 전환
              });
            }

            return result;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.enterAngleAndDuration)),
          );
        }
        break;

      case 'CPM':
        if ((selectedVelocity?.isNotEmpty ?? false) &&
            minAngle.isNotEmpty &&
            maxAngle.isNotEmpty) {
          await _speakCountdown(() async {
            // 예시: onModeChanged에 velocity와 범위 같이 넘기기
            widget.onModeChanged
                ?.call(_selectedMode, '$minAngle,$maxAngle,$selectedVelocity');
            // return await _sendModeDataToBluetooth(_selectedMode);
            return await _sendModeDataToBluetooth(_selectedMode,
                extraData: '$minAngle,$maxAngle,$selectedVelocity');
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.enterRangeAndVelocity)),
          );
        }
        break;

      // case 'Isotonic':
      //   if ((selectedResistance?.isNotEmpty ?? false)) {
      //     await _speakCountdown(() async {
      //       widget.onModeChanged?.call(_selectedMode, selectedResistance!);
      //       return await _sendModeDataToBluetooth(_selectedMode);
      //     });
      //   } else {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text(AppLocalizations.of(context)!.selectResistance)),
      //     );
      //   }
      //   break;
      case 'Isotonic':
        if ((selectedResistance?.isNotEmpty ?? false) &&
            minAngle.isNotEmpty &&
            maxAngle.isNotEmpty) {
          await _speakCountdown(() async {
            // min, max, resistance를 모두 전달
            final combinedData = '$minAngle,$maxAngle,$selectedResistance';
            widget.onModeChanged?.call(_selectedMode, combinedData);
            return await _sendModeDataToBluetooth(_selectedMode,
                extraData: combinedData);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.enterRangeAndResistance)),
          );
        }
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.selectMode)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    String getModeLabel(String mode) {
      switch (mode.toLowerCase()) {
        // case 'passive rom':
        //   return loc.passiverom;
        // case 'active rom':
        //   return loc.activerom;
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

                  // if (_selectedMode != 'Stop') ...[
                  //   Text('${loc.mode}: ${getModeLabel(_selectedMode)}',
                  //       style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  //   const SizedBox(height: 24),
                  //   // Text(loc.originalVelocity),
                  //   // const SizedBox(height: 16),
                  //   Text(loc.selectVelocity),
                  //   const SizedBox(height: 16),
                  //   Wrap(
                  //     spacing: 10,
                  //     children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
                  //       return ChoiceChip(
                  //         label: Text('$v'),
                  //         selected: _velocityController[_selectedMode] == v,
                  //         onSelected: (_) => _setVelocity(v),
                  //       );
                  //     }).toList(),
                  //   ),
                  //   const SizedBox(height: 32),
                  //   ElevatedButton(
                  //     onPressed: _saveData,
                  //     style: ElevatedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  //       textStyle: const TextStyle(fontSize: 18),
                  //     ),
                  //     child: Text(loc.save),
                  //   ),
                  // ],

                  if (_selectedMode != 'Stop') ...[
                    Text('${loc.mode}: ${getModeLabel(_selectedMode)}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    if (_selectedMode == 'CPM') ...[
                      Text(loc.selectRange),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberInput(
                              label: loc.minAngle,
                              controller: _minAngleController),
                          _buildNumberInput(
                              label: loc.maxAngle,
                              controller: _maxAngleController),
                        ],
                      ),
                      const SizedBox(height: 24), // 24
                      Text(loc.selectVelocity),
                      const SizedBox(height: 16), // 16
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
                    ] else if (_selectedMode == 'Isometric') ...[
                      // 각도 입력 + 유지 시간 지정
                      if (!_isoActiveUI) ...[
                        Text(loc.selectAngle),
                        const SizedBox(height: 16), // 16
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
                            // _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
                            _buildNumberInput(
                                label: loc.targetAngle,
                                controller: _targetAngleController),
                          ],
                        ),
                        const SizedBox(height: 24), // 24
                        // 각도^
                        Text(loc.selectHoldDuration),
                        const SizedBox(height: 16), // 16
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
                      ]

                      // 25.06.02 추가내용
                      else ...[
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // children: [
                          //   if (_isMeasuring) ...[
                          //     Text(
                          //         '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                          //         style: const TextStyle(fontSize: 20)),
                          //     Text(
                          //         '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°'),
                          //     Text(
                          //         '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°'),
                          //     const SizedBox(height: 20),
                          //     LinearProgressIndicator(
                          //       value: (_currentAngle != null &&
                          //               _minAngle != null &&
                          //               _maxAngle != null &&
                          //               (_maxAngle! - _minAngle!).abs() >= 1e-5)
                          //           ? (((_currentAngle! - _minAngle!) /
                          //                       (_maxAngle! - _minAngle!))
                          //                   .clamp(0.0, 1.0))
                          //               .toDouble()
                          //           : null,
                          //       minHeight: 10,
                          //     ),
                          //   ] else
                          //     Text('${loc.waitMeasurement}',
                          //         style: TextStyle(
                          //             fontSize: 18,
                          //             color: Colors.grey)), // const
                          // ],
                          children: [
                            if (_isMeasuring || _currentAngle != null) ...[
                              // Text('${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 18)),
                              // Text('${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                              // Text('${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°', style: const TextStyle(fontSize: 15)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: const TextStyle(fontSize: 16),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: const TextStyle(fontSize: 18),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: const TextStyle(fontSize: 16),
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

                              rangeBar(_minAngle, _maxAngle),

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
                              Text('${loc.waitMeasurement}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey)), // const
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                    ] else if (_selectedMode == 'Isotonic') ...[
                      Text(loc.selectRange),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberInput(
                              label: loc.minAngle,
                              controller: _minAngleController),
                          _buildNumberInput(
                              label: loc.maxAngle,
                              controller: _maxAngleController),
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
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: Text(loc.save),
                    ),
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
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold),
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