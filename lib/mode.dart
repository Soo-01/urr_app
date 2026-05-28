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
  // final TextEditingController _isoDurationController = TextEditingController(); // 1~10 duration용


  // 1024 isometric
  // final TextEditingController _minTorqueController = TextEditingController();
  // final TextEditingController _maxTorqueController = TextEditingController();

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




  // void _selectMode(String mode) {
  //   setState(() {
  //     _selectedMode = mode;
  //   });

  //   if (mode == 'Stop') {
  //     widget.onModeChanged?.call('Stop', '');
  //     _sendModeDataToBluetooth('Stop');
  //   }
  // }
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

  // 25.06.02 추가내용
  // @override
  // void initState() {
  //   super.initState();

  //   _btSubscription ??= widget.bluetoothService.dataStream.listen((data) {
  //     final s = data.trim();
  //     print('[BT RX] "$s"');
  //     final torque = double.tryParse(s);
  //     if (torque == null) return;

  //     if (_isMeasuring) {
  //       // ★ 측정 중일 때만 UI 반영
  //       setState(() {
  //         _currentAngle = torque;

  //         // (선택1) 적응형 범위 사용 시:
  //         if (_minTorque == null || torque < _minTorque!) _minTorque = torque;
  //         if (_maxTorque == null || torque > _maxTorque!) _maxTorque = torque;
  //       });
  //     }
  //   });
  // }

  // 1113
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

//   Future<void> _saveData(String action) async {
//   final loc = AppLocalizations.of(context)!;
//   final selectedVelocity = _velocityController[_selectedMode];
//   final selectedResistance = _resistanceController[_selectedMode];
//   final selectedHoldDuration = _holddurationController[_selectedMode];
//   final minAngle = _minAngleController.text;
//   final maxAngle = _maxAngleController.text;
//   // final minTorque = _minTorqueController.text;
//   // final maxTorque = _maxTorqueController.text;
//   final targetAngle = _targetAngleController.text;

//   // if (_selectedMode == 'Stop') return;

//   // 공통: 부위 선택 안 됐으면 바로 경고 후 리턴
//   // if (_selectedMode != 'Stop' && _selectedPart == null) {
//   //   ScaffoldMessenger.of(context).showSnackBar(
//   //     SnackBar(
//   //         content: Text(AppLocalizations.of(context)!
//   //             .selectPart)), // arb에 "selectPart" 추가
//   //   );
//   //   return;
//   // }
//   if (_selectedMode != 'Stop' &&_selectedPart == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(loc.selectPart)), // arb에 "selectPart" 추가
//     );
//     return;
//   }

//   String? cmd; // 실제로 보낼 문자열

//   switch (_selectedMode) {
//     case 'CPM':
//       // 화면 상에서는 min/max angle, velocity를 계속 입력받지만
//       // Jetson에는 'cpm\n'만 보낸다.
//         await _speakCountdown(() async {
//           // UI에서 필요하면 이 정보는 유지
//           widget.onModeChanged?.call(_selectedMode, '$minAngle,$maxAngle,$selectedVelocity');

//           // 1) Jetson으로 명령 전송
//           final result = await _sendModeDataToBluetooth(_selectedMode);

//           // 2) 전송 성공 시 → Indicator UI로 전환 + 측정 시작
//           if (mounted && result) {
//             setState(() {
//               _cpmActive = true;
//               _isMeasuring = true;

//               // 측정 시작 시각 / 범위 초기화
//               _currentAngle = null;
//               _minAngle = null;
//               _maxAngle = null;
//             });
//           }

//           return result;
//         });
//       break;

//     case 'Isometric':
//       if ((selectedHoldDuration?.isNotEmpty ?? false) && targetAngle.isNotEmpty) {
//         await _speakCountdown(() async {
//           widget.onModeChanged?.call(_selectedMode, '$targetAngle,$selectedHoldDuration');
//           // return await _sendModeDataToBluetooth(_selectedMode, extraData: '$targetAngle,$selectedHoldDuration');
          
//           // 1) 블루투스로 명령 전송
//             final result = await _sendModeDataToBluetooth(
//               _selectedMode,
//               extraData: '$targetAngle,$selectedHoldDuration',
//             );

//             // 2) 전송이 끝난 뒤 화면 전환
//             if (mounted) {
//               setState(() {
//                 _isomActive = true; // ← 여기서 Indicator 화면으로 전환
//                 _isMeasuring = true;
//               });
//             }

//             return result;
//         });
//       } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(AppLocalizations.of(context)!.enterAngleAndDuration)),
//           );
//       }
//       break;

//     // case 'CPM':
//     //   if ((selectedVelocity?.isNotEmpty ?? false) && minAngle.isNotEmpty && maxAngle.isNotEmpty) {
//     //     await _speakCountdown(() async {
//     //       // 예시: onModeChanged에 velocity와 범위 같이 넘기기
//     //       widget.onModeChanged?.call(_selectedMode, '$minAngle,$maxAngle,$selectedVelocity');
//     //       // return await _sendModeDataToBluetooth(_selectedMode);
//     //       return await _sendModeDataToBluetooth(_selectedMode, extraData: '$minAngle,$maxAngle,$selectedVelocity');
//     //     });
//     //   } else {
//     //     ScaffoldMessenger.of(context).showSnackBar(
//     //       SnackBar(content: Text(AppLocalizations.of(context)!.enterRangeAndVelocity)),
//     //     );
//     //   }
//     //   break;
//     // 1113   위 기존 내용 일단 생략
//     // case 'CPM':
//     //   // range of motion + velocity 입력은 지금은 사용하지 않음
//     //   //    그냥 Save 누르면 'cpm\n'을 보내고, 필요하다면 나중에 ROM/속도 로직을 추가.
//     //   await _speakCountdown(() async {
//     //     // onModeChanged 에는 일단 빈 문자열로 보내두자 (필요하면 나중에 수정)
//     //     widget.onModeChanged?.call(_selectedMode, '');
//     //     return await _sendModeDataToBluetooth(_selectedMode);
//     //   });
//     //   break;
        



//     // case 'Isotonic':
//     //   if ((selectedResistance?.isNotEmpty ?? false)) {
//     //     await _speakCountdown(() async {
//     //       widget.onModeChanged?.call(_selectedMode, selectedResistance!);
//     //       return await _sendModeDataToBluetooth(_selectedMode);
//     //     });
//     //   } else {
//     //     ScaffoldMessenger.of(context).showSnackBar(
//     //       SnackBar(content: Text(AppLocalizations.of(context)!.selectResistance)),
//     //     );
//     //   }
//     //   break;
//     case 'Isotonic':
//       if ((selectedResistance?.isNotEmpty ?? false) && minAngle.isNotEmpty && maxAngle.isNotEmpty) {
//         await _speakCountdown(() async {
//           // min, max, resistance를 모두 전달
//           final combinedData = '$minAngle,$maxAngle,$selectedResistance';
//           widget.onModeChanged?.call(_selectedMode, combinedData);
//           return await _sendModeDataToBluetooth(_selectedMode, extraData: combinedData);
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(AppLocalizations.of(context)!.enterRangeAndResistance)),
//         );
//       }
//       break;


//     default:
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(AppLocalizations.of(context)!.selectMode)),
//       );
//       break;
//   }
// }

  // Future<void> _saveData(String action) async {
  //   final loc = AppLocalizations.of(context)!;

  //   // 공통: 부위 선택 안 됐으면 경고 후 리턴 (rommode 스타일)
  //   if (_selectedMode != 'Stop' && _selectedPart == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(loc.selectPart)),
  //     );
  //     return;
  //   }

  //   String? cmd; // 실제로 보낼 문자열

  //   switch (_selectedMode) {
  //     // =========================
  //     // 1) CPM 모드
  //     // =========================
  //     case 'CPM': {
  //       // min / max 각도는 TextField에서 입력 받는다고 가정
  //       final minText = _minAngleController.text.trim();
  //       final maxText = _maxAngleController.text.trim();

  //       if (action == 'receive') {
  //         // --- CPM 시작: "cpm,minAngle,maxAngle\n" ---
  //         if (minText.isEmpty || maxText.isEmpty) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(content: Text(loc.enterRangeAndVelocity)), // arb에 적당한 문구 등록
  //           );
  //           break;
  //         }

  //         // 이미 동작 중이면 다시 시작 안 함
  //         if (_cpmActive) {
  //           break;
  //         }

  //         // 상단 상태 표시용 콜백이 있다면 같이 넘겨주기
  //         widget.onModeChanged?.call(
  //           _selectedMode,
  //           '$maxText,$minText',
  //         );

  //         cmd = 'cpm,$maxText,$minText\n';
  //         _cpmActive = true;

  //         // 화면에서 indicator / rangebar 사용하는 플래그는
  //         // 기존 코드에서 하던 그대로 setState 안에 추가하면 됨
  //         setState(() {
  //           _isMeasuring = true;      // 이미 있다면
  //           // _currentAngle = null;
  //           // _minAngleValue = null;
  //           // _maxAngleValue = null;
  //         });

  //       } else if (action == 'save') {
  //         // --- CPM 종료: "x\n" ---
  //         if (_cpmActive) {
  //           cmd = 'x\n';
  //           _cpmActive = false;
  //           setState(() {
  //             _isMeasuring = false;
  //             // rangebar를 그대로 두고 싶으면 여기서 값을 초기화하지 말고 유지
  //           });
  //         }
  //       }
  //       break;
  //     }

  //     // =========================
  //     // 2) Isometric 모드
  //     // =========================
  //     case 'Isometric': {
  //       final targetText   = _targetAngleController.text.trim();
  //       // duration을 TextField로 받는 경우:
  //       // final durationText = _isoDurationController.text.trim();
  //       // 만약 Dropdown 등에서 int로 가지고 있다면:
  //       // final durationText = _isoSelectedDuration.toString();
  //       final durationText = _holddurationController[_selectedMode]?.trim() ?? '';

  //       if (action == 'receive') {
  //         // --- Isometric 시작: "isometric,targetAngle,duration\n" ---
  //         if (targetText.isEmpty || durationText.isEmpty) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(content: Text(loc.enterAngleAndDuration)),
  //           );
  //           break;
  //         }

  //         if (_isomActive) {
  //           break;
  //         }

  //         widget.onModeChanged?.call(
  //           _selectedMode,
  //           '$targetText,$durationText',
  //         );

  //         cmd = 'isometric,$targetText,$durationText\n';
  //         _isomActive = true;

  //         setState(() {
  //           _isMeasuring  = true;
  //           // _currentTorque = null;
  //           // _minTorque     = null;
  //           // _maxTorque     = null;
  //         });

  //       } else if (action == 'stop') {
  //         // --- Isometric 중단: "isom_stop\n" ---
  //         if (_isomActive) {
  //           cmd = 'isom_stop\n';
  //           _isomActive = false;

  //           setState(() {
  //             _isMeasuring  = false;
  //             // torque 그래프를 남기고 싶으면 초기화하지 말고 유지
  //           });
  //         }
  //       }
  //       break;
  //     }

  //     // =========================
  //     // 3) Stop (필요하다면)
  //     // =========================
  //     case 'Stop':
  //       if (action == 'save' || action == 'receive') {
  //         cmd = 'x\n';        // 전체 정지 공통 커맨드
  //         _cpmActive = false;
  //         _isomActive = false;
  //         _isMeasuring = false;
  //       }
  //       break;

  //     default:
  //       break;
  //   }

  //   // 실제로 보낼 명령이 있으면 BT로 전송
  //   if (cmd != null) {
  //     print('[APP TX] $cmd');  //  cmd [cpm,-10,10]/[isometric,30,5] 이런식으로 잘 넘어가는 지 확인 

  //     await widget.bluetoothService.sendBytes(
  //       Uint8List.fromList(utf8.encode(cmd)),
  //     );
  //   }
  // }

  // mode.dart 내의 _saveData(String action) 함수를 아래와 같이 수정하세요.

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
                        style: TextStyle(fontSize: 24*fontSizeFactor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // if (_selectedMode == 'CPM') ...[
                    //   if (!_cpmActive) ...[
                    //     // === (1) 설정 화면: Range + Velocity 선택 ===
                    //     Text(loc.selectRange),
                    //     const SizedBox(height: 16),
                    //     Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //       children: [
                    //         _buildNumberInput(
                    //           label: loc.minAngle,
                    //           controller: _minAngleController,
                    //         ),
                    //         _buildNumberInput(
                    //           label: loc.maxAngle,
                    //           controller: _maxAngleController,
                    //         ),
                    //       ],
                    //     ),
                    //     const SizedBox(height: 24),
                    //     Text(loc.selectVelocity),
                    //     const SizedBox(height: 16),
                    //     Wrap(
                    //       spacing: 10,
                    //       children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
                    //         return ChoiceChip(
                    //           label: Text('$v'),
                    //           selected: _velocityController[_selectedMode] == v,
                    //           onSelected: (_) => _setVelocity(v),
                    //         );
                    //       }).toList(),
                    //     ),
                    //   ] else ...[
                    //     // === (2) Indicator 화면: Active ROM 스타일의 각도 표시 ===
                    //     const SizedBox(height: 24),
                    //     Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         if (_isMeasuring || _currentAngle != null) ...[
                    //           Row(
                    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //             children: [
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 16),
                    //                   textAlign: TextAlign.start,
                    //                 ),
                    //               ),
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 18),
                    //                   textAlign: TextAlign.center,
                    //                 ),
                    //               ),
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 16),
                    //                   textAlign: TextAlign.end,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),

                    //           const SizedBox(height: 20),

                    //           // Active ROM 과 동일한 스타일의 각도 indicator
                    //           angleRangeBar(_minAngle, _maxAngle),

                    //           const SizedBox(height: 4),
                    //           Row(
                    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //             children: const [
                    //               Text('-100'),
                    //               Text('-75'),
                    //               Text('-50'),
                    //               Text('-25'),
                    //               Text('0'),
                    //               Text('25'),
                    //               Text('50'),
                    //               Text('75'),
                    //               Text('100'),
                    //             ],
                    //           ),
                    //         ] else
                    //           Text(
                    //             '${loc.waitMeasurement}',
                    //             style: const TextStyle(
                    //               fontSize: 18,
                    //               color: Colors.grey,
                    //             ),
                    //           ),
                    //       ],
                    //     ),

                    //     const SizedBox(height: 32),

                    //   Row(
                    //     mainAxisAlignment: MainAxisAlignment.center,
                    //     children: [
                    //       ElevatedButton(
                    //         onPressed: () async {
                    //           // 👉 CPM 모드일 때: cpm 시작 + indicator 전환
                    //           if (_selectedMode == 'CPM') {
                    //             // 필요하면 여기서 min/max/velocity 체크 (_minAngleController, _maxAngleController 등) 해도 됨

                    //             await _speakCountdown(() async {
                    //               // (원하면 현재 설정값 전달)
                    //               final selectedVelocity = _velocityController[_selectedMode] ?? '';
                    //               widget.onModeChanged?.call(
                    //                 _selectedMode,
                    //                 '${_minAngleController.text},${_maxAngleController.text},$selectedVelocity',
                    //               );

                    //               // 1) Jetson/Teensy에 CPM 시작 명령
                    //               widget.bluetoothService.sendBytes(
                    //                 Uint8List.fromList(utf8.encode('cpm\n')),
                    //               );

                    //               // 2) Indicator UI + 측정 시작
                    //               if (mounted) {
                    //                 setState(() {
                    //                   _cpmActive = true;   // 설정 화면 → indicator 화면 전환
                    //                   _isMeasuring = true;   // BT 수신값 반영 시작

                    //                   _currentAngle = null;  // 범위 초기화
                    //                   _minAngle = null;
                    //                   _maxAngle = null;
                    //                 });
                    //               }

                    //               return true;
                    //             });
                    //           } else {
                    //             // 👉 CPM 이 아닌 나머지 모드에서는 기존 receive 로직 유지
                    //             // (여기에 원래 쓰던 onPressed 내용 넣어주면 됨)
                    //             _saveData();   // 예시
                    //           }
                    //         },
                    //         style: ElevatedButton.styleFrom(
                    //           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    //           textStyle: const TextStyle(fontSize: 18),
                    //         ),
                    //         child: Text(loc.receive),
                    //       ),


                    //       const SizedBox(width: 20), // 버튼 간 간격
                    //       ElevatedButton(
                    //         onPressed: () {
                    //           if (_selectedMode == 'CPM') {
                    //             // 👉 CPM 정지 명령
                    //             widget.bluetoothService.sendBytes(
                    //               Uint8List.fromList(utf8.encode('x\n')),
                    //             );

                    //             // 👉 측정만 종료 (indicator는 마지막 값 그대로 표시)
                    //             setState(() {
                    //               _isMeasuring = false;
                    //             });

                    //             // 필요하면 여기서 CPM 결과 저장 함수 호출도 가능
                    //             // _saveCpmResult(); 이런 식으로
                    //           } else {
                    //             // 👉 CPM 이 아닌 모드에서는 기존 Save 동작 유지
                    //             _saveData();  // 예시
                    //           }
                    //         },
                    //         style: ElevatedButton.styleFrom(
                    //           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    //           textStyle: const TextStyle(fontSize: 18),
                    //         ),
                    //         child: Text(loc.save),
                    //       ),
                    //     ],
                    //   ),

                    //   ]
                    // ] 
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
                            // onPressed: () async {
                            //   if (_selectedMode == 'CPM') {
                            //     await _speakCountdown(() async {
                            //       final selectedVelocity = _velocityController[_selectedMode] ?? '';
                            //       widget.onModeChanged?.call(
                            //         _selectedMode,
                            //         '${_minAngleController.text},${_maxAngleController.text},$selectedVelocity',
                            //       );
                    
                            //       // 1) Jetson/Teensy에 CPM 시작 명령
                            //       widget.bluetoothService.sendBytes(
                            //         Uint8List.fromList(utf8.encode('cpm\n')),
                            //       );
                    
                            //       // 2) Indicator UI + 측정 시작
                            //       if (mounted) {
                            //         setState(() {
                            //           _cpmActive = true;   // 설정 화면 → indicator 화면 전환
                            //           _isMeasuring = true;   // BT 수신값 반영 시작
                    
                            //           _currentAngle = null;  // 범위 초기화
                            //           _minAngle = null;
                            //           _maxAngle = null;
                            //         });
                            //       }
                            //       return true;
                            //     });
                            //   }
                            // },
                            onPressed: !_cpmActive
                                ? () => _saveData('receive')
                                : null, // 이미 동작 중이면 비활성화
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              textStyle: TextStyle(fontSize: 18 * fontSizeFactor),
                            ),
                            // style: ElevatedButton.styleFrom(
                            //   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            //   textStyle: const TextStyle(fontSize: 18),
                            // ),
                            child: Text(loc.receive),
                          ),
                    
                          const SizedBox(width: 20),
                    
                          // SAVE 버튼: CPM 정지 (x\n) + 측정 종료
                          ElevatedButton(
                            // onPressed: () {
                            //   if (_selectedMode == 'CPM') {
                            //     widget.bluetoothService.sendBytes(
                            //       Uint8List.fromList(utf8.encode('x\n')),
                            //     );
                    
                            //     setState(() {
                            //       _isMeasuring = false;  // 값 업데이트만 멈춤
                            //     });
                            //   }
                            // },
                            // style: ElevatedButton.styleFrom(
                            //   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            //   textStyle: const TextStyle(fontSize: 18),
                            // ),
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

                    // else if (_selectedMode == 'Isometric') ...[
                    //   // 각도 입력 + 유지 시간 지정
                    //   if(!_isomActive) ...[
                    //   Text(loc.selectAngle),
                    //   const SizedBox(height: 16),
                    //   Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: [
                    //       // _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
                    //       // _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
                    //       _buildNumberInput(label: loc.targetAngle, controller: _targetAngleController),
                    //     ],
                    //   ),
                    //   const SizedBox(height: 24),
                    //   // 각도^
                    //   Text(loc.selectHoldDuration),
                    //   const SizedBox(height: 16),
                    //   Wrap(
                    //     spacing: 10,
                    //     children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
                    //       return ChoiceChip(
                    //         label: Text('$v'),
                    //         selected: _holddurationController[_selectedMode] == v,
                    //         onSelected: (_) => _setHoldDuration(v),
                    //       );
                    //     }).toList(),
                    //   ),
                    //   ]

                    //   // 25.10.24 추가내용
                    //   else ...[
                    //     const SizedBox(height: 24),
                    //     Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         if (_isMeasuring || _currentTorque != null) ...[
                    //           Row(
                    //             mainAxisAlignment:
                    //                 MainAxisAlignment.spaceBetween,
                    //             children: [
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.minTorque}: ${_minTorque?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 16),
                    //                   textAlign: TextAlign.start,
                    //                 ),
                    //               ),
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.currentTorque}: ${_currentTorque?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 18),
                    //                   textAlign: TextAlign.center,
                    //                 ),
                    //               ),
                    //               Expanded(
                    //                 child: Text(
                    //                   '${loc.maxTorque}: ${_maxTorque?.toStringAsFixed(1) ?? '-'}°',
                    //                   style: const TextStyle(fontSize: 16),
                    //                   textAlign: TextAlign.end,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),

                    //           const SizedBox(height: 20),

                    //           rangeBar(_minTorque, _maxTorque),

                    //           const SizedBox(height: 4),
                    //           Row(
                    //             mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                    //             children: const [Text('-1'), Text('-0.5'), Text('0'), Text('0.5'), Text('1')],
                    //           ),
                    //         ] else
                    //           Text('${loc.waitMeasurement}',
                    //               style: TextStyle(fontSize: 18, color: Colors.grey)), // const
                    //       ],
                    //     ),
                    //   ],

                    // ] 

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

                        // const SizedBox(height: 32),
                        // // Isometric용 전용 Save 버튼 (Start 개념)
                        // ElevatedButton(
                        //   onPressed: _saveData,   // Isometric case에서 iso\n 보내고 _isomActive / _isMeasuring 켜는 로직 이미 있음
                        //   style: ElevatedButton.styleFrom(
                        //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        //     textStyle: const TextStyle(fontSize: 18),
                        //   ),
                        //   child: Text(loc.save),
                        // ),
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

                    
                    // else if (_selectedMode == 'Isotonic') ...[
                    //   Text(loc.selectRange),
                    //   const SizedBox(height: 16),
                    //   Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: [
                    //       _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
                    //       _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
                    //     ],
                    //   ),
                    //   const SizedBox(height: 24),
                    //   Text(loc.selectResistance),
                    //   const SizedBox(height: 16),
                    //   Wrap(
                    //     spacing: 10,
                    //     children: ['1', '2', '3', '4', '5'].map((v) {
                    //       return ChoiceChip(
                    //         label: Text('$v'),
                    //         selected: _resistanceController[_selectedMode] == v,
                    //         onSelected: (_) => _setResistance(v),
                    //       );
                    //     }).toList(),
                    //   ),
                    // ],

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

                    

                    // const SizedBox(height: 32),
                    // ElevatedButton(
                    //   onPressed: _saveData,
                    //   style: ElevatedButton.styleFrom(
                    //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    //     textStyle: const TextStyle(fontSize: 18),
                    //   ),
                    //   child: Text(loc.save),
                    // ),
                  ],


                ],
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Center(
              // child: OutlinedButton(
              //   onPressed: () => _selectMode('Stop'),
              //   style: OutlinedButton.styleFrom(
              //     shape: const CircleBorder(),
              //     minimumSize: const Size(150, 150),
              //     backgroundColor: _selectedMode == 'Stop'
              //         ? Colors.red
              //         : null,
              //     side: BorderSide(
              //       color: _selectedMode == 'Stop' ? Colors.red : Colors.red,
              //       width: 3,
              //     ),
              //     foregroundColor: _selectedMode == 'Stop'
              //         ? Colors.white
              //         : Colors.black,
              //   ),
              //   child: Text(
              //     loc.stop, 
              //     style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              //  ),
              // // child: const Icon(
              // //     Icons.pause,
              // //     size: 80,
              // //     color: Colors.black,
              // //   ),
              // ),



              // child: OutlinedButton(
              //   onPressed: () {
              //     // 1) Isometric 모드일 때 STOP command 보내기
              //     if (_selectedMode == 'Isometric') {
              //       widget.bluetoothService.sendBytes(
              //         Uint8List.fromList(utf8.encode('isom_stop\n')),
              //       );

              //       // BT 스트림 정리
              //       _btSubscription?.cancel();
              //       _btSubscription = null;

              //       // UI 상태 초기화
              //       setState(() {
              //         _isMeasuring = false;
              //         _isomActive = false;
              //         _currentTorque = null;
              //         _minTorque = null;
              //         _maxTorque = null;
              //       });
              //     }

              //     // 2) 원래 하던대로 Stop 모드로 변경
              //     _selectMode('Stop');
              //   },
              //   style: OutlinedButton.styleFrom(
              //     shape: const CircleBorder(),
              //     minimumSize: const Size(150, 150),
              //     backgroundColor:
              //         _selectedMode == 'Stop' ? Colors.red : null,
              //     side: BorderSide(
              //       color: _selectedMode == 'Stop' ? Colors.red : Colors.red,
              //       width: 3,
              //     ),
              //     foregroundColor:
              //         _selectedMode == 'Stop' ? Colors.white : Colors.black,
              //   ),
              //   child: Text(
              //     loc.stop,
              //     style: const TextStyle(
              //       fontSize: 30,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),

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

///////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
///////////////////////////////////////////////////////




// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'bluetooth.dart';
// import 'generated/l10n.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;

// class ModeSelectScreen extends StatefulWidget {
//   final BluetoothService bluetoothService;
//   final Function(String, String)? onModeChanged;

//   const ModeSelectScreen({
//     super.key,
//     required this.bluetoothService,
//     this.onModeChanged,
//   });

//   @override
//   _ModeSelectScreenState createState() => _ModeSelectScreenState();
// }

// class _ModeSelectScreenState extends State<ModeSelectScreen> {
//   String _selectedMode = 'Stop';
//   final Map<String, String> _velocityController = {
//     'CPM': '',
//     'Stop': '',
//   };
//   final Map<String, String> _holddurationController = {
//     'Isometric': '',
//   };
//   final Map<String, String> _resistanceController = {
//     'Isotonic': '',
//   };

//   final TextEditingController _minAngleController = TextEditingController();
//   final TextEditingController _maxAngleController = TextEditingController();
//   final TextEditingController _targetAngleController = TextEditingController();

//   // measurement state
//   double? _currentAngle;
//   double? _minAngle;
//   double? _maxAngle;
//   double? _currentTorque;
//   double? _minTorque;
//   double? _maxTorque;
//   StreamSubscription<String>? _btSubscription;
//   bool _isMeasuring = false;
//   bool _isomActive = false;
//   bool _cpmActive = false;
//   bool _isotonicActive = false;
//   String? _selectedPart;

//   @override
//   void initState() {
//     super.initState();

//     _btSubscription ??= widget.bluetoothService.dataStream.listen((data) {
//       if (!_isMeasuring) return;
//       final s = data.trim();
//       final value = double.tryParse(s);
//       if (value == null) return;

//       setState(() {
//         if (_selectedMode == 'Isometric') {
//           _currentTorque = value;
//           if (_minTorque == null || value < _minTorque!) _minTorque = value;
//           if (_maxTorque == null || value > _maxTorque!) _maxTorque = value;
//         } else if (_selectedMode == 'CPM') {
//           _currentAngle = value;
//           if (_minAngle == null || value < _minAngle!) _minAngle = value;
//           if (_maxAngle == null || value > _maxAngle!) _maxAngle = value;
//         } else if (_selectedMode == 'Isotonic') {
//           double? angleValue;
//           double? torqueValue;
//           if (s.contains(',')) {
//             final parts = s.split(',');
//             if (parts.isNotEmpty) angleValue = double.tryParse(parts[0]);
//             if (parts.length > 1) torqueValue = double.tryParse(parts[1]);
//           }
//           angleValue ??= value;
//           torqueValue ??= value;
//           _currentAngle = angleValue;
//           if (_minAngle == null || angleValue! < _minAngle!) _minAngle = angleValue;
//           if (_maxAngle == null || angleValue! > _maxAngle!) _maxAngle = angleValue;
//           _currentTorque = torqueValue;
//           if (_minTorque == null || torqueValue! < _minTorque!) _minTorque = torqueValue;
//           if (_maxTorque == null || torqueValue! > _maxTorque!) _maxTorque = torqueValue;
//         }
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _btSubscription?.cancel();
//     super.dispose();
//   }

//   void _setVelocity(String v) => setState(() => _velocityController[_selectedMode] = v);
//   void _setResistance(String r) => setState(() => _resistanceController[_selectedMode] = r);
//   void _setHoldDuration(String d) => setState(() => _holddurationController[_selectedMode] = d);

//   Future<void> _selectMode(String mode) async {
//     if (mode == 'Stop') {
//       // stop CPM
//       if (_selectedMode == 'CPM') {
//         await widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode('x\n')));
//         setState(() {
//           _cpmActive = false;
//           _isMeasuring = false;
//           _currentAngle = null;
//           _minAngle = null;
//           _maxAngle = null;
//         });
//       } else if (_selectedMode == 'Isometric') {
//         await widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode('isom_stop\n')));
//         setState(() {
//           _isomActive = false;
//           _isMeasuring = false;
//           _currentTorque = null;
//           _minTorque = null;
//           _maxTorque = null;
//         });
//       }
//       if (_selectedMode == 'Isotonic') {
//         await widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode('isoto_stop\n')));
//         setState(() {
//           _isotonicActive = false;
//           _isMeasuring = false;
//           _currentAngle = null;
//           _minAngle = null;
//           _maxAngle = null;
//           _currentTorque = null;
//           _minTorque = null;
//           _maxTorque = null;
//         });
//       }
//       await widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode('stop\n')));
//       widget.onModeChanged?.call('Stop', '');
//       setState(() => _selectedMode = 'Stop');
//       return;
//     }
//     // switch to other mode
//     setState(() => _selectedMode = mode);
//     widget.onModeChanged?.call(mode, '');
//   }

//   Future<void> _saveData(String action) async {
//     final loc = AppLocalizations.of(context)!;
//     if (_selectedMode != 'Stop' && _selectedPart == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(loc.selectPart)),
//       );
//       return;
//     }
//     String? cmd;
//     switch (_selectedMode) {
//       case 'CPM': {
//         final minText = _minAngleController.text.trim();
//         final maxText = _maxAngleController.text.trim();
//         if (action == 'receive') {
//           if (minText.isEmpty || maxText.isEmpty) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(loc.enterRangeAndVelocity)),
//             );
//             break;
//           }
//           if (_cpmActive) break;
//           widget.onModeChanged?.call(_selectedMode, '$maxText,$minText');
//           cmd = 'cpm,$maxText,$minText\n';
//           _cpmActive = true;
//           setState(() {
//             _isMeasuring = true;
//             _currentAngle = null;
//             _minAngle = null;
//             _maxAngle = null;
//           });
//         } else if (action == 'save') {
//           if (_cpmActive) {
//             cmd = 'x\n';
//             _cpmActive = false;
//             setState(() {
//               _isMeasuring = false;
//             });
//           }
//         }
//         break;
//       }
//       case 'Isometric': {
//         final targetText = _targetAngleController.text.trim();
//         final durationText = _holddurationController[_selectedMode]?.trim() ?? '';
//         if (action == 'receive') {
//           if (targetText.isEmpty || durationText.isEmpty) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(loc.enterAngleAndDuration)),
//             );
//             break;
//           }
//           if (_isomActive) break;
//           widget.onModeChanged?.call(_selectedMode, '$targetText,$durationText');
//           cmd = 'isometric,$targetText,$durationText\n';
//           _isomActive = true;
//           setState(() {
//             _isMeasuring = true;
//           });
//         } else if (action == 'stop') {
//           if (_isomActive) {
//             cmd = 'isom_stop\n';
//             _isomActive = false;
//             setState(() {
//               _isMeasuring = false;
//             });
//           }
//         }
//         break;
//       }
//       case 'Stop': {
//         if (action == 'save' || action == 'receive') {
//           cmd = 'x\n';
//           _cpmActive = false;
//           _isomActive = false;
//           _isotonicActive = false;
//           _isMeasuring = false;
//         }
//         break;
//       }
//       case 'Isotonic': {
//         final minText = _minAngleController.text.trim();
//         final maxText = _maxAngleController.text.trim();
//         final resistanceText = _resistanceController[_selectedMode]?.trim() ?? '';
//         if (action == 'receive') {
//           if (minText.isEmpty || maxText.isEmpty || resistanceText.isEmpty) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(loc.enterRangeAndResistance)),
//             );
//             break;
//           }
//           if (_isotonicActive) break;
//           widget.onModeChanged?.call(_selectedMode, '$minText,$maxText,$resistanceText');
//           cmd = 'isoto,$minText,$maxText,$resistanceText\n';
//           _isotonicActive = true;
//           setState(() {
//             _isMeasuring = true;
//             _currentAngle = null;
//             _minAngle = null;
//             _maxAngle = null;
//             _currentTorque = null;
//             _minTorque = null;
//             _maxTorque = null;
//           });
//         } else if (action == 'save' || action == 'stop') {
//           if (_isotonicActive) {
//             cmd = 'isoto_stop\n';
//             _isotonicActive = false;
//             setState(() {
//               _isMeasuring = false;
//             });
//           }
//         }
//         break;
//       }
//       default:
//         break;
//     }
//     if (cmd != null) {
//       await widget.bluetoothService.sendBytes(Uint8List.fromList(utf8.encode(cmd)));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final loc = AppLocalizations.of(context)!;

//     String getModeLabel(String mode) {
//       switch (mode.toLowerCase()) {
//         case 'cpm':
//           return loc.cpm;
//         case 'isometric':
//           return loc.isometric;
//         case 'isotonic':
//           return loc.isotonic;
//         case 'stop':
//           return loc.stop;
//         default:
//           return mode;
//       }
//     }

//     return Scaffold(
//       appBar: AppBar(title: Text(loc.modeSelect)),
//       body: Row(
//         children: [
//           // 왼쪽 패널
//           Expanded(
//             flex: 3,
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   // 부위 선택 드롭다운
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 8),
//                     child: Align(
//                       alignment: Alignment.topRight,
//                       child: SizedBox(
//                         width: 300,
//                         child: DropdownMenu<String>(
//                           initialSelection: _selectedPart,
//                           hintText: loc.selectPart,
//                           dropdownMenuEntries: [
//                             DropdownMenuEntry(value: 'lShoulderEF', label: loc.lShoulderEF),
//                             DropdownMenuEntry(value: 'lShoulderRo', label: loc.lShoulderRo),
//                             DropdownMenuEntry(value: 'lElbow', label: loc.lElbow),
//                             DropdownMenuEntry(value: 'lWrist', label: loc.lWrist),
//                           ],
//                           onSelected: (value) async {
//                             setState(() => _selectedPart = value);
//                             if (value != null) {
//                               final payload = 'PART:$value';
//                               debugPrint('[ROM] send $payload');
//                             }
//                           },
//                         ),
//                       ),
//                     ),
//                   ),

//                   // 모드 선택 버튼들
//                   ...['CPM', 'Isometric', 'Isotonic'].map((mode) {
//                     final isSelected = _selectedMode == mode;
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: OutlinedButton(
//                         style: OutlinedButton.styleFrom(
//                           minimumSize: const Size(double.infinity, 48),
//                           backgroundColor: isSelected ? Colors.blue.shade100 : null,
//                           side: BorderSide(
//                             color: isSelected ? Colors.blue : Colors.grey,
//                             width: 2,
//                           ),
//                           foregroundColor: isSelected ? Colors.blue.shade900 : Colors.black,
//                         ),
//                         onPressed: () => _selectMode(mode),
//                         child: Text(getModeLabel(mode)),
//                       ),
//                     );
//                   }).toList(),

//                   const SizedBox(height: 24),

//                   // 상세 UI (Stop이 아닐 때만)
//                   if (_selectedMode != 'Stop') ...[
//                     Text(
//                       '${loc.mode}: ${getModeLabel(_selectedMode)}',
//                       style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 24),

//                     // CPM
//                     if (_selectedMode == 'CPM') ...[
//                       // 설정 화면
//                       if (!_cpmActive) ...[
//                         Text(loc.selectRange),
//                         const SizedBox(height: 16),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
//                             _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
//                           ],
//                         ),
//                         const SizedBox(height: 24),
//                         Text(loc.selectVelocity),
//                         const SizedBox(height: 16),
//                         Wrap(
//                           spacing: 10,
//                           children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'].map((v) {
//                             return ChoiceChip(
//                               label: Text('$v'),
//                               selected: _velocityController[_selectedMode] == v,
//                               onSelected: (_) => _setVelocity(v),
//                             );
//                           }).toList(),
//                         ),
//                       ]
//                       // Indicator 화면
//                       else ...[
//                         const SizedBox(height: 24),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (_isMeasuring || _currentAngle != null) ...[
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.start,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 18),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.end,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 20),
//                               angleRangeBar(_minAngle, _maxAngle, _currentAngle),
//                               const SizedBox(height: 4),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: const [
//                                   Text('-100'), Text('-75'), Text('-50'), Text('-25'), Text('0'),
//                                   Text('25'), Text('50'), Text('75'), Text('100'),
//                                 ],
//                               ),
//                             ] else
//                               Text(
//                                 loc.waitMeasurement,
//                                 style: const TextStyle(fontSize: 18, color: Colors.grey),
//                               ),
//                           ],
//                         ),
//                       ],

//                       const SizedBox(height: 32),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           ElevatedButton(
//                             onPressed: !_cpmActive ? () => _saveData('receive') : null,
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                               textStyle: const TextStyle(fontSize: 18),
//                             ),
//                             child: Text(loc.receive),
//                           ),
//                           const SizedBox(width: 20),
//                           ElevatedButton(
//                             onPressed: _cpmActive ? () => _saveData('save') : null,
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                               textStyle: const TextStyle(fontSize: 18),
//                             ),
//                             child: Text(loc.save),
//                           ),
//                         ],
//                       ),
//                     ]
//                     // Isometric
//                     else if (_selectedMode == 'Isometric') ...[
//                       if (!_isomActive) ...[
//                         Text(loc.selectAngle),
//                         const SizedBox(height: 16),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             _buildNumberInput(label: loc.targetAngle, controller: _targetAngleController),
//                           ],
//                         ),
//                         const SizedBox(height: 24),
//                         Text(loc.selectHoldDuration),
//                         const SizedBox(height: 16),
//                         Wrap(
//                           spacing: 10,
//                           children: ['1','2','3','4','5','6','7','8','9','10'].map((v) {
//                             return ChoiceChip(
//                               label: Text('$v'),
//                               selected: _holddurationController[_selectedMode] == v,
//                               onSelected: (_) => _setHoldDuration(v),
//                             );
//                           }).toList(),
//                         ),
//                         const SizedBox(height: 32),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             ElevatedButton(
//                               onPressed: () => _saveData('receive'),
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                 textStyle: const TextStyle(fontSize: 18),
//                               ),
//                               child: Text(loc.start),
//                             ),
//                             const SizedBox(width: 20),
//                             ElevatedButton(
//                               onPressed: null,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                 textStyle: const TextStyle(fontSize: 18),
//                               ),
//                               child: Text(loc.stop),
//                             ),
//                           ],
//                         ),
//                       ]
//                       else ...[
//                         const SizedBox(height: 24),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (_isMeasuring || _currentTorque != null) ...[
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.minTorque}: ${_minTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.start,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.currentTorque}: ${_currentTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 18),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.maxTorque}: ${_maxTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.end,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 20),
//                               rangeBar(_minTorque, _maxTorque),
//                               const SizedBox(height: 4),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: const [Text('-1'), Text('-0.5'), Text('0'), Text('0.5'), Text('1')],
//                               ),
//                               const SizedBox(height: 24),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   ElevatedButton(
//                                     onPressed: null,
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                       textStyle: const TextStyle(fontSize: 18),
//                                     ),
//                                     child: Text(loc.receive),
//                                   ),
//                                   const SizedBox(width: 20),
//                                   ElevatedButton(
//                                     onPressed: () => _saveData('stop'),
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                       textStyle: const TextStyle(fontSize: 18),
//                                     ),
//                                     child: Text(loc.stop),
//                                   ),
//                                 ],
//                               ),
//                             ] else
//                               Text(
//                                 loc.waitMeasurement,
//                                 style: const TextStyle(fontSize: 18, color: Colors.grey),
//                               ),
//                           ],
//                         ),
//                       ],
//                     ]
//                     // Isotonic
//                     else if (_selectedMode == 'Isotonic') ...[
//                       if (!_isotonicActive) ...[
//                         Text(loc.selectRange),
//                         const SizedBox(height: 16),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             _buildNumberInput(label: loc.minAngle, controller: _minAngleController),
//                             _buildNumberInput(label: loc.maxAngle, controller: _maxAngleController),
//                           ],
//                         ),
//                         const SizedBox(height: 24),
//                         Text(loc.selectResistance),
//                         const SizedBox(height: 16),
//                         Wrap(
//                           spacing: 10,
//                           children: ['1', '2', '3', '4', '5'].map((v) {
//                             return ChoiceChip(
//                               label: Text('$v'),
//                               selected: _resistanceController[_selectedMode] == v,
//                               onSelected: (_) => _setResistance(v),
//                             );
//                           }).toList(),
//                         ),
//                         const SizedBox(height: 32),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             ElevatedButton(
//                               onPressed: () => _saveData('receive'),
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                 textStyle: const TextStyle(fontSize: 18),
//                               ),
//                               child: Text(loc.start),
//                             ),
//                             const SizedBox(width: 20),
//                             ElevatedButton(
//                               onPressed: null,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                 textStyle: const TextStyle(fontSize: 18),
//                               ),
//                               child: Text(loc.save),
//                             ),
//                           ],
//                         ),
//                       ]
//                       else ...[
//                         const SizedBox(height: 24),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (_isMeasuring || _currentAngle != null) ...[
//                               // 각도 표시
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.minAngle}: ${_minAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.start,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.currentAngle}: ${_currentAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 18),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.maxAngle}: ${_maxAngle?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.end,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 10),
//                               angleRangeBar(_minAngle, _maxAngle, _currentAngle),
//                               const SizedBox(height: 4),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: const [
//                                   Text('-100'), Text('-75'), Text('-50'), Text('-25'), Text('0'),
//                                   Text('25'), Text('50'), Text('75'), Text('100'),
//                                 ],
//                               ),
//                               const SizedBox(height: 24),
//                               // 토크 표시
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.minTorque}: ${_minTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.start,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.currentTorque}: ${_currentTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 18),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       '${loc.maxTorque}: ${_maxTorque?.toStringAsFixed(1) ?? '-'}°',
//                                       style: const TextStyle(fontSize: 16),
//                                       textAlign: TextAlign.end,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 10),
//                               rangeBar(_minTorque, _maxTorque),
//                               const SizedBox(height: 4),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: const [Text('-1'), Text('-0.5'), Text('0'), Text('0.5'), Text('1')],
//                               ),
//                               const SizedBox(height: 24),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   ElevatedButton(
//                                     onPressed: null,
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                       textStyle: const TextStyle(fontSize: 18),
//                                     ),
//                                     child: Text(loc.start),
//                                   ),
//                                   const SizedBox(width: 20),
//                                   ElevatedButton(
//                                     onPressed: () => _saveData('save'),
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                                       textStyle: const TextStyle(fontSize: 18),
//                                     ),
//                                     child: Text(loc.save),
//                                   ),
//                                 ],
//                               ),
//                             ] else
//                               Text(
//                                 loc.waitMeasurement,
//                                 style: const TextStyle(fontSize: 18, color: Colors.grey),
//                               ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ],
//                 ],
//               ),
//             ),
//           ),

//           // 오른쪽 Stop 버튼
//           Expanded(
//             flex: 2,
//             child: Center(
//               child: OutlinedButton(
//                 onPressed: () => _selectMode('Stop'),
//                 style: OutlinedButton.styleFrom(
//                   shape: const CircleBorder(),
//                   minimumSize: const Size(150, 150),
//                   backgroundColor: _selectedMode == 'Stop' ? Colors.red : null,
//                   side: const BorderSide(color: Colors.red, width: 3),
//                   foregroundColor: _selectedMode == 'Stop' ? Colors.white : Colors.black,
//                 ),
//                 child: Text(
//                   loc.stop,
//                   style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // 공통 숫자 입력 위젯
//   Widget _buildNumberInput({required String label, required TextEditingController controller}) {
//     return SizedBox(
//       width: 120,
//       child: TextField(
//         controller: controller,
//         keyboardType: TextInputType.number,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//         ),
//       ),
//     );
//   }

//   // 범위바 위젯 (토크용)
//   Widget rangeBar(double? min, double? max) {
//     if (min == null || max == null) {
//       return Container(
//         height: 10,
//         decoration: BoxDecoration(
//           color: Colors.black12,
//           borderRadius: BorderRadius.circular(4),
//         ),
//       );
//     }
//     double norm(double a) => ((a + 1) / 2).clamp(0.0, 1.0);
//     final start = norm(min);
//     final end = norm(max);
//     return SizedBox(
//       height: 10,
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           final width = constraints.maxWidth;
//           final left = width * math.min(start, end);
//           final right = width * (1.0 - math.max(start, end));
//           return Stack(
//             children: [
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.black12,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//               Positioned(
//                 left: left,
//                 right: right,
//                 top: 0,
//                 bottom: 0,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.primary,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   // 각도 표시 막대
//   Widget angleRangeBar(double? minAngle, double? maxAngle, double? current) {
//     if (minAngle == null || maxAngle == null) {
//       return Container(
//         height: 10,
//         decoration: BoxDecoration(
//           color: Colors.black12,
//           borderRadius: BorderRadius.circular(4),
//         ),
//       );
//     }
//     double norm(double a) => ((a + 100) / 200).clamp(0.0, 1.0);
//     final start = norm(minAngle);
//     final end = norm(maxAngle);
//     final curNorm = current != null ? norm(current) : null;
//     return SizedBox(
//       height: 10,
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           final width = constraints.maxWidth;
//           final left = width * math.min(start, end);
//           final right = width * (1.0 - math.max(start, end));
//           final curX = curNorm != null ? (curNorm * width) : null;
//           return Stack(
//             children: [
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.black12,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//               Positioned(
//                 left: left,
//                 right: right,
//                 top: 0,
//                 bottom: 0,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.primary,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//               ),
//               if (curX != null)
//                 Positioned(
//                   left: curX - 3,
//                   top: 0,
//                   bottom: 0,
//                   child: Container(
//                     width: 6,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(3),
//                     ),
//                   ),
//                 ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
