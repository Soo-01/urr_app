import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:provider/provider.dart';
import 'main.dart';
import 'bluetooth.dart';
import 'profile.dart';
import 'rommode.dart';
import 'mode.dart';
import 'control.dart';
import 'file_upload.dart';
import 'information.dart';
import 'generated/l10n.dart';
import 'games/game_hub.dart';

class BottomNavBar extends StatefulWidget {
  final BluetoothService bluetoothService;

  const BottomNavBar({super.key, required this.bluetoothService});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  late final BluetoothService _bluetoothService;

  String _name = '';
  String _gender = 'Male';
  double _age = 0.0;
  double _height = 0.0;
  double _weight = 0.0;
  String _arm = 'Right';

  List<FileSystemEntity> _uploadedFiles = [];
  final List<FileSystemEntity> _sendedFiles = [];
  String _selectedMode = 'Stop';
  final Map<String, String> _velocityController = {'Sit': '', 'Stand': '', 'Walk': '', 'Stop': ''};
  final Map<String, String> _intensityController = {'Sit': '', 'Stand': '', 'Walk': '', 'Stop': ''};
  final Map<String, Map<String, double>> _controlValues = {};

  @override
  void initState() {
    super.initState();
    _bluetoothService = widget.bluetoothService;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controlValues.isNotEmpty) {
        _controlValues.forEach((controlMode, values) {
          updateControlValues(
            controlMode: controlMode,
            selectedMode: _selectedMode,
            selectedVelocity: _velocityController[_selectedMode] ?? '',
            gains: values,
            arm: _arm,
            height: _height,
            weight: _weight,
          );
        });
      }
    });
  }

  Future<bool> _showPasswordDialog() async {
    final loc = AppLocalizations.of(context)!;
    const correctPassword = '0070';
    final TextEditingController controller = TextEditingController();
    bool wrongPassword = false;

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(loc.enterPassword),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.enterPasswordInstruction, 
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: wrongPassword ? Colors.red : Colors.grey,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length == 4) {
                        if (value == correctPassword) {
                          Navigator.of(context).pop(true);
                        } else {
                          setState(() {
                            wrongPassword = true;
                          });
                          Future.delayed(const Duration(milliseconds: 500), () {
                            controller.clear();
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return result == true;
  }

  void _onItemTapped(int index) async {
    if (index == 6) {
      final success = await _showPasswordDialog();
      if (!success) {
        return;
      }
    }

    setState(() {
      _selectedIndex = index;
    });
  }

    void updateChangedFiles(List<FileSystemEntity> files) {
      setState(() {
        _uploadedFiles = files;
    });
  }

  void updateSendedFiles(FileSystemEntity file) {
    setState(() {
      _sendedFiles.removeWhere((f) => f.path.split('/').last == file.path.split('/').last);
      _sendedFiles.add(file);
    });
  }

  void updateModeSettings(String mode, String velocity) {
    setState(() {
      _selectedMode = mode;
      _velocityController[mode] = velocity;
    });
  }

  Future<void> updateControlValues({
    required String controlMode,
    required String selectedMode,
    required String selectedVelocity,
    required Map<String, double> gains,
    required String arm,
    required double height,
    required double weight,
  }) async {
    // This method stores control values for use in the Information screen.
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // final pages = [
    //   HomeScreen(bluetoothService: _bluetoothService),
    //   ProfileScreen(
    //     name: _name,
    //     gender: _gender,
    //     age: _age,
    //     height: _height,
    //     weight: _weight,
    //     arm: _arm,
    //     onSave: (name, gender, age, height, weight, arm) {
    //       setState(() {
    //         _name = name;
    //         _gender = gender;
    //         _age = age;
    //         _height = height;
    //         _weight = weight;
    //         _arm = arm;
    //       });
    //     },
    //   ),
    //   ROMModeSelectScreen(
    //     bluetoothService: _bluetoothService,
    //     onModeChanged: updateModeSettings,
    //   ),
    //   ModeSelectScreen(
    //     bluetoothService: _bluetoothService,
    //     onModeChanged: updateModeSettings,
    //   ),
    //   ControlScreen(
    //     arm: _arm,
    //     height: _height,
    //     weight: _weight,
    //     onSave: (controlMode, mode, values) {
    //       setState(() {
    //         _controlValues[controlMode] = values;
    //       });
    //       updateControlValues(
    //         controlMode: controlMode,
    //         selectedMode: mode,
    //         selectedVelocity: _velocityController[mode] ?? '',
    //         gains: values,
    //         arm: _arm,
    //         height: _height,
    //         weight: _weight,
    //       );
    //     },
    //   ),
    //   FileUploadScreen(
    //     bluetoothService: _bluetoothService,
    //     onFilesChanged: updateChangedFiles,
    //     onFilesSent: updateSendedFiles,
    //   ),
    //   Information(
    //     sendedFiles: _sendedFiles,
    //     selectedMode: _selectedMode,
    //     selectedVelocity: _velocityController[_selectedMode] ?? '',
    //     selectedIntensity: _intensityController[_selectedMode] ?? '',
    //     name: _name,
    //     gender: _gender,
    //     age: _age,
    //     height: _height,
    //     weight: _weight,
    //     arm: _arm,
    //     controlValues: _controlValues,
    //   ),
    // ];
    final pages = [
      HomeScreen(bluetoothService: _bluetoothService),
      
      // 1. ProfileScreen 수정: 모든 파라미터를 지웁니다. 
      // (데이터는 ProfileScreen 내부에서 UserProvider를 통해 직접 처리함)
      const ProfileScreen(),

      // ProfileScreen(
      //   name: '', // 초기값 설정
      //   gender: 'Male',
      //   age: 0.0,
      //   height: 0.0,
      //   weight: 0.0,
      //   arm: 'Right',
      //   onSave: (name, gender, age, height, weight, arm) {
      //     // 저장 버튼 클릭 시 수행할 로직 작성
      //     print('Saved: $name');
      //   },
      //   userList: [], // (선택 사항) 저장된 사용자 리스트 전달
      // ),
    
      ROMModeSelectScreen(
        bluetoothService: _bluetoothService,
        onModeChanged: updateModeSettings,
      ),
      ModeSelectScreen(
        bluetoothService: _bluetoothService,
        onModeChanged: updateModeSettings,
      ),
      ControlScreen(
        arm: _arm,
        height: _height,
        weight: _weight,
        onSave: (controlMode, mode, values) {
          setState(() {
            _controlValues[controlMode] = values;
          });
          updateControlValues(
            controlMode: controlMode,
            selectedMode: mode,
            selectedVelocity: _velocityController[mode] ?? '',
            gains: values,
            arm: _arm,
            height: _height,
            weight: _weight,
          );
        },
      ),
      GameHubScreen(                                   // 4
        bluetoothService: _bluetoothService,
      ),
      FileUploadScreen(
        bluetoothService: _bluetoothService,
        onFilesChanged: updateChangedFiles,
        onFilesSent: updateSendedFiles,
      ),
    
      // 2. Information 수정: 개인정보(name, age 등) 파라미터를 모두 지웁니다.
      // (이 정보 역시 Information 내부에서 Provider로 가져옴)
      Information(
        sendedFiles: _sendedFiles,
        selectedMode: _selectedMode,
        selectedVelocity: _velocityController[_selectedMode] ?? '',
        selectedIntensity: _intensityController[_selectedMode] ?? '',
        controlValues: _controlValues,
      ),
    ];

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return Row(
            children: [
              if (isLandscape)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.selected,
                  destinations: [
                    NavigationRailDestination(icon: const Icon(Icons.home), label: Text(loc.home)),
                    NavigationRailDestination(icon: const Icon(Icons.person), label: Text(loc.profile)),
                    NavigationRailDestination(icon: const Icon(Icons.straighten), label: Text(loc.romMode)),
                    NavigationRailDestination(icon: const Icon(Icons.fitness_center), label: Text(loc.modeSelect)),
                    NavigationRailDestination(icon: const Icon(Icons.settings), label: Text(loc.control)),
                    NavigationRailDestination(icon: const Icon(Icons.sports_esports), label: Text(loc.game)),
                    NavigationRailDestination(icon: const Icon(Icons.file_upload), label: Text(loc.fileUpload)),
                    // NavigationRailDestination(icon: const Icon(Icons.info), label: Text(loc.information)),
                    NavigationRailDestination(icon: const Icon(Icons.history), label: Text(loc.history)),
                  ],
                ),
              Expanded(child: IndexedStack(index: _selectedIndex, children: pages)),
              // 우측 하단 글자 크기 조절 버튼 추가
              Positioned(
                right: 20,
                bottom: orientation == Orientation.landscape ? 20 : 80, // 내비게이션 바 위치 고려
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: "inc_font",
                      onPressed: () {
                        final provider = Provider.of<FontSizeProvider>(context, listen: false);
                        provider.setScaleFactor((provider.scaleFactor + 0.1).clamp(1.0, 2.0));
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: "dec_font",
                      onPressed: () {
                        final provider = Provider.of<FontSizeProvider>(context, listen: false);
                        provider.setScaleFactor((provider.scaleFactor - 0.1).clamp(1.0, 2.0));
                      },
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: OrientationBuilder(
        builder: (context, orientation) => orientation == Orientation.landscape
            ? const SizedBox.shrink()
            : BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.home),
                  BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.profile),
                  BottomNavigationBarItem(icon: const Icon(Icons.straighten), label: loc.romMode),
                  BottomNavigationBarItem(icon: const Icon(Icons.fitness_center), label: loc.modeSelect),
                  BottomNavigationBarItem(icon: const Icon(Icons.settings), label: loc.control),
                  BottomNavigationBarItem(icon: const Icon(Icons.sports_esports), label: loc.game),
                  BottomNavigationBarItem(icon: const Icon(Icons.file_upload), label: loc.fileUpload),
                  // BottomNavigationBarItem(icon: const Icon(Icons.star), label: loc.information),
                  BottomNavigationBarItem(icon: const Icon(Icons.history), label: loc.history),
                ],
              ),
        ),
      );
    }
  }
