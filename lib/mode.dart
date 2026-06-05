import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth.dart';
import 'generated/l10n.dart';
import 'dart:async'; // 25.06.02 추가내용
import 'dart:convert'; // 25.08.25 추가내용
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'main.dart';

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

  Widget _buildNumberInput({required String label, required TextEditingController controller}) {
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
  StreamSubscription<String>? _btSubscription;
  bool _isMeasuring = false;
  bool _isomActive = false;
  bool _cpmActive = false;
  String? _selectedPart;

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
    final end   = norm(maxAngle);

    final curNorm = current != null ? norm(current) : null;

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left  = width * math.min(start, end);
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
                    color: Colors.white,           // marker 색상
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
      // === 현재 모드 종료 처리 ===
      if (_selectedMode == 'CPM') {
        // CPM 종료 → x\n
        await widget.bluetoothService.sendBytes(
          Uint8List.fromList(utf8.encode('x\n')),
        );

        // BT 스트림 정리
        // _btSubscription?.cancel();
        // _btSubscription = null;

        // UI 상태 초기화
        setState(() {
          _cpmActive    = false;
          _isMeasuring  = false;
          // CPM 관련 값들도 필요하면 초기화
          _currentAngle = null;
          _minAngle     = null;
          _maxAngle     = null;
        });
      } else if (_selectedMode == 'Isometric') {
        // Isometric 종료 → isom_stop\n
        await widget.bluetoothService.sendBytes(
          Uint8List.fromList(utf8.encode('isom_stop\n')),
        );

        // BT 스트림 정리
        // _btSubscription?.cancel();
        // _btSubscription = null;

        setState(() {
          _isomActive    = false;
          _isMeasuring   = false;
          _currentTorque = null;
          _minTorque     = null;
          _maxTorque     = null;
        });
      }

      // --- 어떤 모드든 무조건 stop\n (softStop) 추가 송신 ---
      await widget.bluetoothService.sendBytes(
        Uint8List.fromList(utf8.encode('stop\n')),
      );

      // 상단 상태 표시 콜백도 Stop으로 리셋
      widget.onModeChanged?.call('Stop', '');

      // === 최종적으로 화면 Stop 모드로 전환 ===
      setState(() {
        _selectedMode = 'Stop';
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
  Future<void> _sendPart(String partCode) async {
    //  추후 Jetson에 전송하기 위해 만들어둠. 지금은 딱히 사용 x. Debug print로 출력만 확인
    // 예: PART:<code> 형식으로 단독 전송
    final payload = 'PART:$partCode';
    // await BluetoothService.instance.send(payload);
    debugPrint('[ROM] send $payload');
  }


    @override
    void initState() {
      super.initState();

      _btSubscription ??= widget.bluetoothService.dataStream.listen((data) {
        if (!_isMeasuring) return;      // 가장 먼저 가드 걸기
        
        final s = data.trim();
        print('[BT RX] "$s"');

        final value = double.tryParse(s);   // torque 또는 angle 값
        if (value == null) return;

        // if (!_isMeasuring) return;          // 측정 중이 아닐 땐 무시

        setState(() {
          if (_selectedMode == 'Isometric') {
            // Isometric: 토크 값으로 해석
            _currentTorque = value;
            if (_minTorque == null || value < _minTorque!) _minTorque = value;
            if (_maxTorque == null || value > _maxTorque!) _maxTorque = value;
          } else if (_selectedMode == 'CPM') {
            // CPM: 각도 값으로 해석
            _currentAngle = value;
            if (_minAngle == null || value < _minAngle!) _minAngle = value;
            if (_maxAngle == null || value > _maxAngle!) _maxAngle = value;
          }
        });
      });
    }


  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _sendModeDataToBluetooth(String mode, {String? extraData}) async {
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
        // message = extraData != null
        //   ? 'mode:C,$extraData\n' // 예: 10,40,3
        //   : 'mode:C,$selectedVelocity\n';     //  일단 각도 범위 및 속도 입력 생략
        message = 'cpm\n';
        break;
      case 'Isometric':
        // message = 'mode:D,$extraData,$selectedHoldDuration\n';  //  $targetAngle
        message = extraData != null
          ? 'isometric,$extraData\n' // 예: 10,40,3
          : 'isometric,$selectedHoldDuration\n';
        break;
      case 'Isotonic':
        message = 'mode:E,$selectedResistance\n';
        break;
      case 'Stop':
        if (_selectedMode == 'Isometric') {
          message = 'isom_stop\n';
        }
        else { message = 'x\n'; }    // 'mode:S\n';  
        break;
      default:
        return false;
    }

    try {
      final success = await widget.bluetoothService.sendBytes(
        Uint8List.fromList(message.codeUnits),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success
          ? '${AppLocalizations.of(context)!.bluetoothMessageSent}: $message'
          : AppLocalizations.of(context)!.bluetoothFailed)),
      );
      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.bluetoothError}: $e')),
      );
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    
    // PROM 혹은 AROM 중 더 좁은 범위(또는 원하는 데이터)를 가져올 수 있습니다.
    // 예시: PROM 데이터가 존재하면 자동으로 불러오기
    if (userProvider.promData != null) {
      if (_minAngleController.text.isEmpty) {
        _minAngleController.text = userProvider.promData!['minAngle'].toStringAsFixed(1);
      }
      if (_maxAngleController.text.isEmpty) {
        _maxAngleController.text = userProvider.promData!['maxAngle'].toStringAsFixed(1);
      }
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


  Future<void> _saveData(String action) async {
    final loc = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 공통: 사용자 정보 확인
    if (userProvider.name.isEmpty || userProvider.name == " ") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 먼저 입력하거나 불러와주세요.')),
      );
      return;
    }

    // 공통: 부위 선택 안 됐으면 경고 후 리턴
    if (_selectedMode != 'Stop' && _selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.selectPart)),
      );
      return;
    }

    String? cmd;

    switch (_selectedMode) {
      case 'CPM': {
        final minText = _minAngleController.text.trim();
        final maxText = _maxAngleController.text.trim();

        if (action == 'receive') {
          // --- CPM 시작 ---
          if (minText.isEmpty || maxText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.enterRangeAndVelocity)), 
            );
            break;
          }
          if (_cpmActive) break;
          
          widget.onModeChanged?.call(_selectedMode, '$maxText,$minText');
          cmd = 'cpm,$maxText,$minText\n';
          _cpmActive = true;

          setState(() {
            _isMeasuring = true;      
          });

        } else if (action == 'save') {
          // --- CPM 종료 및 기록 저장 ---
          if (_cpmActive) {
            cmd = 'x\n';
            _cpmActive = false;
            setState(() { _isMeasuring = false; });

            // ★ CPM 운동 기록 저장
            userProvider.addRecord({
              'type': 'Exercise',
              'mode': 'CPM',
              'part': _selectedPart,
              'minAngle': double.tryParse(minText) ?? 0.0,
              'maxAngle': double.tryParse(maxText) ?? 0.0,
              'velocity': _velocityController['CPM'] ?? 'N/A',
              'reps': 0, // TODO: Jetson에서 받은 반복 횟수가 있다면 업데이트
              'date': DateTime.now().toString(),
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CPM 운동이 기록되었습니다.')));
          }
        }
        break;
      }

      case 'Isometric': {
        final targetText = _targetAngleController.text.trim();
        final durationText = _holddurationController[_selectedMode]?.trim() ?? '';

        if (action == 'receive') {
          // --- Isometric 시작 ---
          if (targetText.isEmpty || durationText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.enterAngleAndDuration)),
            );
            break;
          }
          if (_isomActive) break;

          widget.onModeChanged?.call(_selectedMode, '$targetText,$durationText');
          cmd = 'isometric,$targetText,$durationText\n';
          _isomActive = true;

          setState(() { _isMeasuring  = true; });

        } else if (action == 'stop') {
          // --- Isometric 중단 및 기록 저장 ---
          if (_isomActive) {
            cmd = 'isom_stop\n';
            _isomActive = false;
            setState(() { _isMeasuring  = false; });

            // ★ Isometric 운동 기록 저장
            userProvider.addRecord({
              'type': 'Exercise',
              'mode': 'Isometric',
              'part': _selectedPart,
              'targetAngle': double.tryParse(targetText) ?? 0.0,
              'duration': durationText,
              'maxTorque': _maxTorque,
              'reps': 3, // 명세에 따라 3회 반복 (또는 Jetson에서 받은 실제 횟수)
              'date': DateTime.now().toString(),
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등척성 운동이 기록되었습니다.')));
          }
        }
        break;
      }

      case 'Isotonic': {
        final minText = _minAngleController.text.trim();
        final maxText = _maxAngleController.text.trim();
        final resistanceText = _resistanceController[_selectedMode] ?? '';

        if (action == 'receive') { // Isotonic '시작' 버튼 누를 때
          if (minText.isEmpty || maxText.isEmpty || resistanceText.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.enterRangeAndResistance)),
            );
            break;
          }
          
          final combinedData = '$minText,$maxText,$resistanceText';
          widget.onModeChanged?.call(_selectedMode, combinedData);
          cmd = 'isoto,$combinedData\n'; // Bluetooth 전송 명령어 예시
          setState(() { _isMeasuring = true; });
          
        } else if (action == 'save') { // Isotonic '저장' 버튼 누를 때
          cmd = 'x\n'; // 정지 명령어
          setState(() { _isMeasuring = false; });

          // ★ Isotonic 운동 기록 저장
          userProvider.addRecord({
            'type': 'Exercise',
            'mode': 'Isotonic',
            'subMode': 'Band', // TODO: UI에서 덤벨/밴드 선택 값 연동
            'part': _selectedPart,
            'minAngle': double.tryParse(minText) ?? 0.0,
            'maxAngle': double.tryParse(maxText) ?? 0.0,
            'resistance': resistanceText,
            'date': DateTime.now().toString(),
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등장성 운동이 기록되었습니다.')));
        }
        break;
      }

      case 'Stop':
        if (action == 'save' || action == 'receive') {
          cmd = 'x\n';
          _cpmActive = false;
          _isomActive = false;
          _isMeasuring = false;
        }
        break;
    }

    if (cmd != null) {
      print('[APP TX] $cmd');  
      await widget.bluetoothService.sendBytes(
        Uint8List.fromList(utf8.encode(cmd)),
      );
    }
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
                          backgroundColor: isSelected ? Colors.blue.shade100 : null,
                          side: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                          foregroundColor: isSelected ? Colors.blue.shade900 : Colors.black,
                        ),
                        onPressed: () => _selectMode(mode),
                        child: Text(getModeLabel(mode)),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  if (_selectedMode != 'Stop') ...[
                    Text('${loc.mode}: ${getModeLabel(_selectedMode)}',
                        style: TextStyle(fontSize: 24*fontSizeFactor, fontWeight: FontWeight.bold)),
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
                          children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 18 * fontSizeFactor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                    
                              const SizedBox(height: 20),
                    
                              // Active ROM 과 동일한 스타일의 각도 indicator
                              angleRangeBar(_minAngle, _maxAngle, _currentAngle),
                    
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
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
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
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.save),
                          ),
                        ],
                      ),
                    ]

                    else if (_selectedMode == 'Isometric') ...[
                      if(!_isomActive) ...[
                        Text(loc.selectAngle),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberInput(label: loc.targetAngle, controller: _targetAngleController),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(loc.selectHoldDuration),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
                            return ChoiceChip(
                              label: Text('$v'),
                              selected: _holddurationController[_selectedMode] == v,
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
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                              ),
                              // child: Text(loc.receive),
                              child: Text(loc.start),
                            ),

                            const SizedBox(width: 20),

                            // STOP 버튼: 아직 시작 전이라 비활성(보기만)
                            ElevatedButton(
                              onPressed: null, // _isomActive == false 이므로 stop은 의미 없어서 disable
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                              ),
                              child: Text(loc.stop),
                            ),
                          ],
                        ),

                      ]
                      else ...[
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isMeasuring || _currentTorque != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${loc.minTorque}: ${_minTorque?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.currentTorque}: ${_currentTorque?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 18 * fontSizeFactor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${loc.maxTorque}: ${_maxTorque?.toStringAsFixed(1) ?? '-'}°',
                                      style: TextStyle(fontSize: 16 * fontSizeFactor),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              rangeBar(_minTorque, _maxTorque),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                                children: const [Text('-1'), Text('-0.5'), Text('0'), Text('0.5'), Text('1')],
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
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                                    ),
                                    child: Text(loc.receive),
                                  ),

                                  const SizedBox(width: 20),

                                  // STOP 버튼: isom_stop\n 전송
                                  ElevatedButton(
                                    onPressed: () => _saveData('stop'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                                    ),
                                    // child: Text(loc.save),  // UI 텍스트를 Stop으로 바꾸고 싶으면 loc.stop 써도 됨
                                    child: Text(loc.stop),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                '${loc.waitMeasurement}',
                                style: TextStyle(fontSize: 18 * fontSizeFactor, color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    ]

                  

                    else if (_selectedMode == 'Isotonic') ...[
                      Text(loc.selectRange),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
                          _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
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
                      ElevatedButton(
                        onPressed: () => _saveData('receive'),
                        // onPressed: _saveData(),   // Isotonic case에서 적절한 명령 보내도록 구현해둔 그 함수
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                        ),
                        child: Text(loc.save),
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
                  foregroundColor: _selectedMode == 'Stop' ? Colors.white : Colors.black,
                ),
                child: Text(
                  loc.stop,
                  style: TextStyle(fontSize: 30 * fontSizeFactor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
