import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth.dart';
import 'generated/l10n.dart';
import 'dart:async';  // 25.06.02 추가내용
import 'dart:convert';  // 25.08.25 추가내용
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';  // 25.08.25 추가내용
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'main.dart';


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
  double? _currentAngle;
  double? _minAngle;
  double? _maxAngle;
  StreamSubscription<String>? _btSubscription;
  bool _isMeasuring = false;
  bool _activeRom = false;
  bool _passiveRom = false;
  String? _selectedPart;


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
  void _selectMode(String mode) {
    if (mode == 'Stop') {
      // 1) 현재 모드에 맞는 종료 커맨드 먼저 전송
      if (_selectedMode == 'Active ROM' || _selectedMode == 'Passive ROM') {
        // save 동작에는 이미
        // Active ROM → arom\n
        // Passive ROM → x\n
        // 이 들어가 있으니까 이걸 재활용
        _saveData('save');
      }

      // 2) 측정/스트림/각도 상태 정리
      _btSubscription?.cancel();
      _btSubscription = null;

      setState(() {
        _selectedMode = 'Stop';
        _isMeasuring = false;
        _currentAngle = null;
        _minAngle = null;
        _maxAngle = null;
      });


      // softStop 추가
      _saveData('stop');

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
  Future<void> _sendPart(String partCode) async {  //  추후 Jetson에 전송하기 위해 만들어둠. 지금은 딱히 사용 x. Debug print로 출력만 확인
    // 예: PART:<code> 형식으로 단독 전송
    final payload = 'PART:$partCode';
    // await BluetoothService.instance.send(payload);
    debugPrint('[ROM] send $payload');
  }

  // 25.06.02 추가내용
  @override
  void initState() {
  super.initState();

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



  Future<bool> _sendModeDataToBluetooth(String mode) async {
    String message;
    final selectedVelocity = _velocityController[mode] ?? "";

    switch (mode) {
      case 'PassiveROM':
        message = 'mode:A,$selectedVelocity';
        break;
      case 'ActiveROM':
        message = 'mode:B';  // message = 'mode:B,$selectedVelocity';
        break;
      case 'Stop':
        message = 'mode:S';
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
    final selectedVelocity = _velocityController[_selectedMode];

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
      SnackBar(content: Text(AppLocalizations.of(context)!.selectPart)), // arb에 "selectPart" 추가
    );
    return;
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
          // Active ROM 시작: arom\n
          if (!_activeRom) {
            cmd = 'arom\n';
            _activeRom = true;
          }
        } else if (action == 'save') {
          // Active ROM 종료: arom\n
          if (_activeRom) {
            cmd = 'arom\n';
            _activeRom = false;
          }
        }
        break;

      case 'Passive ROM':
        if (action == 'receive') {
          // Passive ROM 시작: prom\n
          if (!_passiveRom) {
            cmd = 'prom\n';
            _passiveRom = true;
          }
        } else if (action == 'direction') {
          // 방향 전환: dir\n
          cmd = 'dir\n';
        } else if (action == 'save') {
          // Passive ROM 종료: x\n
          if (_passiveRom) {
            cmd = 'x\n';
            _passiveRom = false;
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
      cmd = 'stop\n';      // 원하는 softStop 커맨드
      _activeRom = false;
      _passiveRom = false;
    }

    // 실제로 보낼 명령이 있으면 BT로 전송
    if (cmd != null) {
      print('[APP TX] $cmd');  //  cmd [arom]/[prom]/[x]/[dir] 이런식으로 잘 넘어가는 지 확인 

      await widget.bluetoothService.sendBytes(
        Uint8List.fromList(utf8.encode(cmd)),
      );
    }

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

  Future<void> _saveAngleData() async {
    final loc = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false); // Provider 호출

    if (_selectedMode == 'Stop') return;

    if (_minAngle == null || _maxAngle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.noMeasuredAngle}')),
      );
      return;
    }

    final now = DateTime.now().toString().split(' ')[0];
    final angleRange = '${_minAngle!.toStringAsFixed(1)}° ~ ${_maxAngle!.toStringAsFixed(1)}°';

    // ★ 1. Passive ROM과 Active ROM 구분하여 UserProvider에 데이터 저장
    if (_selectedMode == 'Passive ROM') {
      // 속도가 선택되지 않았을 경우를 대비한 기본값 처리
      final velocity = _velocityController['Passive ROM']?.isNotEmpty == true 
          ? _velocityController['Passive ROM']! 
          : 'N/A';
          
      userProvider.updateProm(
        _selectedPart!, 
        velocity, 
        _minAngle!, 
        _maxAngle!
      );
    } else if (_selectedMode == 'Active ROM') {
      userProvider.updateArom(
        _selectedPart!, 
        _minAngle!, 
        _maxAngle!
      );
    }

    debugPrint('[$now] ${loc.measuredROM}: $angleRange');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${loc.savedROM}: $angleRange\n($_selectedMode 저장 완료)')),
    );

    // 저장 후 초기화하고 측정 종료
    setState(() {
      _isMeasuring = false;
    });
  }

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
                            DropdownMenuEntry(value: 'lShoulderEF', label: loc.lShoulderEF),
                            DropdownMenuEntry(value: 'lShoulderRo', label: loc.lShoulderRo),
                            DropdownMenuEntry(value: 'lElbow',      label: loc.lElbow),
                            DropdownMenuEntry(value: 'lWrist',      label: loc.lWrist),
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
                        style: TextStyle(fontSize: 24 * fontSizeFactor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    if (_selectedMode == 'Passive ROM') ...[
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
                                    '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 18 * fontSizeFactor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 16 * fontSizeFactor),
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
                                Text('-100'), Text('-75'), Text('-50'), Text('-25'), Text('0'),
                                Text('25'),  Text('50'),  Text('75'),  Text('100'),
                              ],
                            ),
                          ]
                          
                           else
                            Text('${loc.waitMeasurement}', style: TextStyle(fontSize: 18 * fontSizeFactor, color: Colors.grey)),  // const
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
                                    await _saveData('receive');  // prom\n 전송

                                    // Passive ROM 모드에서 속도 선택 안 했으면 측정 시작하지 않음
                                    if (_selectedMode == 'Passive ROM' && _selectedPart == null) {   //   속도 선택 생략   (_velocityController[_selectedMode]?.isEmpty ?? true) || 
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


                                    // 1113
                                    // 👉 각도 수신용 스트림 구독
                                    _btSubscription?.cancel();
                                    _btSubscription = widget.bluetoothService.dataStream.listen((data) {
                                      final s = data.trim();
                                      print('[BT RX] "$s"');
                                      final angle = double.tryParse(s);
                                      if (angle == null) return;

                                      if (_isMeasuring) { // ★ 측정 중일 때만 UI 반영
                                        final newMin = (_minAngle == null)
                                            ? angle
                                            : (angle < _minAngle! ? angle : _minAngle!);

                                        final newMax = (_maxAngle == null)
                                            ? angle
                                            : (angle > _maxAngle! ? angle : _maxAngle!);

                                        setState(() {
                                          _currentAngle = angle;
                                          _minAngle = newMin;
                                          _maxAngle = newMax;
                                        });
                                      }
                                    });

                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.receive),
                          ),

                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () {
                              // widget.bluetoothService.sendBytes(
                              //   Uint8List.fromList(utf8.encode('dir\n')),   //  방향 전환 버튼
                              // );
                              _saveData('direction');   // dir\n 전송
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.direction),
                          ),


                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () async {
                              await _saveData('save');  // x\n 전송

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
                              setState(() => _isMeasuring = false); // ★ 루프 종료 신호  // 측정 종료 플래그

                              _saveAngleData();

                            },

                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
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
                                    '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 16 * fontSizeFactor),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 18 * fontSizeFactor),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°', style: TextStyle(fontSize: 16 * fontSizeFactor),
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
                                Text('-100'), Text('-75'), Text('-50'), Text('-25'), Text('0'),
                                Text('25'),  Text('50'),  Text('75'),  Text('100'),
                              ],
                            ),

                          ] else
                            Text('${loc.waitMeasurement}', style: TextStyle(fontSize: 18 * fontSizeFactor, color: Colors.grey)),  // const
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
                                    await _saveData('receive');

                                    // Active ROM 모드에서 관절 선택 안 했으면 측정 시작하지 않음
                                    if (_selectedMode == 'Active ROM' && _selectedPart == null) {
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

                                    _btSubscription?.cancel();
                                    _btSubscription = widget.bluetoothService.dataStream.listen((data) {
                                      final s = data.trim();
                                      print('[BT RX] "$s"');
                                      final angle = double.tryParse(s);
                                      if (angle == null) return;

                                      if (_isMeasuring) {  // ★ 측정 중일 때만 UI 반영
                                        final newMin = (_minAngle == null) ? angle : (angle < _minAngle! ? angle : _minAngle!);
                                        final newMax = (_maxAngle == null) ? angle : (angle > _maxAngle! ? angle : _maxAngle!);

                                        setState(() {
                                          _currentAngle = angle;
                                          _minAngle = newMin;
                                          _maxAngle = newMax;
                                        });
                                      }
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            child: Text(loc.receive),
                          ),

                          const SizedBox(width: 20), // 버튼 간 간격
                          ElevatedButton(
                            onPressed: () async {

                              await _saveData('save');  // BT 종료 명령

                              _btSubscription?.cancel();
                              _btSubscription = null;
                          
                              setState(() => _isMeasuring = false);
                          
                              _saveAngleData();  // 원래 쓰던 저장 함수 그대로

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
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
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
                  backgroundColor: _selectedMode == 'Stop'
                      ? Colors.red
                      : null,
                  side: BorderSide(
                    color: _selectedMode == 'Stop' ? Colors.red : Colors.red,
                    width: 3,
                  ),
                  foregroundColor: _selectedMode == 'Stop'
                      ? Colors.white
                      : Colors.black,
                ),
                child: Text(
                  loc.stop, 
                  style: TextStyle(fontSize: 30 * fontSizeFactor, fontWeight: FontWeight.bold),
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