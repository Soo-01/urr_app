import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'generated/l10n.dart';
import 'locale_provider.dart';
import 'bluetooth.dart';
import 'battery.dart';
import 'navi.dart';

import 'profile.dart';
import 'information.dart';

void main() {
  runApp(
    // ChangeNotifierProvider(
    //   create: (context) => LocaleProvider(),
    //   child: const MyApp(),
    // ),
    MultiProvider( // ChangeNotifierProvider를 MultiProvider로 변경
      providers: [
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => FontSizeProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothService = BluetoothService();
    final localeProvider = Provider.of<LocaleProvider>(context);
    final fontSizeProvider = Provider.of<FontSizeProvider>(context); // 추가

    return MaterialApp(
      title: 'URR App',
      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 236, 239, 106)),  // 255, 236, 239, 106
        useMaterial3: true,
        iconTheme: IconThemeData(size: 30 * fontSizeProvider.scaleFactor),
      ),
      home: BottomNavBar(bluetoothService: bluetoothService),
      routes: {
       '/home': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/profile': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/mode select': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/rom mode': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/control': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/file_upload': (context) => BottomNavBar(bluetoothService: bluetoothService),
        '/information': (context) => BottomNavBar(bluetoothService: bluetoothService),

        // '/profile': (context) => const ProfileScreen(),
        // '/information': (context) => const Information(),
      },
    );
  }
}

class FontSizeProvider extends ChangeNotifier {
  double _scaleFactor = 1.2; // 디폴트 값을 조금 키움 (1.0 -> 1.2)

  double get scaleFactor => _scaleFactor;

  void setScaleFactor(double factor) {
    _scaleFactor = factor;
    notifyListeners();
  }
}


class LocaleProvider extends ChangeNotifier {
  // Locale _locale = const Locale('en'); // 언어 기본값
  Locale _locale = const Locale('ko'); // 언어 기본값
  final FlutterTts _tts = FlutterTts();

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    _setTtsLanguage(locale);
    notifyListeners();
  }

  void _setTtsLanguage(Locale locale) async {
    if (locale.languageCode == 'ko') {
      await _tts.setLanguage('ko-KR');
    } else {
      await _tts.setLanguage('en-US');
    }
  }
}

class HomeScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
 const HomeScreen({super.key, required this.bluetoothService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BatteryService _batteryService = BatteryService();
  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, int> _connectionHistory = {};

  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;
  final List<BluetoothDiscoveryResult> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;

  bool _scanning = false;
  bool _bluetoothConnected = false;
  bool _motorPower = false;
  int _batteryLevel = 0;

  @override
  // void initState() {
  //   super.initState();
  //   widget.bluetoothService.requestPermissions();
  //   _loadBatteryLevel();
  //   _loadConnectionHistory();
  // }
  @override
  void initState() {
    super.initState();
  
    Future.microtask(() async {
      try {
        await widget.bluetoothService.requestPermissions();
      } catch (e) {
        debugPrint("❌ 권한 요청 실패: $e");
      }
    });
  
    _loadBatteryLevel();
    _loadConnectionHistory();
  }


  void _loadBatteryLevel() async {
    final level = await _batteryService.getBatteryLevel();
    setState(() {
      _batteryLevel = level;
    });
  }

  void _loadConnectionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      final count = prefs.getInt(key) ?? 0;
      _connectionHistory[key] = count;
    }
  }

  void _startScan() async {
    setState(() {
      _discoveredDevices.clear();
      _scanning = true;
    });

    _discoveryStream = widget.bluetoothService.startDiscovery().listen((result) {
      final exists = _discoveredDevices.any((d) => d.device.address == result.device.address);
      if (!exists) {
        setState(() {
          _discoveredDevices.add(result);
          _discoveredDevices.sort((a,b) {
            final countA = _connectionHistory[a.device.address] ?? 0;
            final countB = _connectionHistory[b.device.address] ?? 0;
            return countB.compareTo(countA);
          });
        });
      }
    }, onDone: () {
      setState(() {
        _scanning = false;
      });
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await widget.bluetoothService.connect(device, () {
        setState(() {
          _connectedDevice = null;
          _bluetoothConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.bluetoothDisconnected),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 10,
              left: 20,
              right: 20,
            )
          ),
        );
      });

      setState(() {
        _connectedDevice = device;
        _bluetoothConnected = true;
      });

      final addr = device.address;
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(addr) ?? 0;
      final newCount = currentCount + 1;
      final localeCode = AppLocalizations.of(context)!.localeName;

      await prefs.setInt(addr, newCount);
      _connectionHistory[addr] = newCount;

      await _flutterTts.setLanguage(localeCode == 'ko' ? 'ko-KR' : 'en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(
        localeCode == 'ko' ? '블루투스가 연결되었습니다.' : 'Bluetooth Device Connected',
    );

      await _flutterTts.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(seconds: 10));
      await _flutterTts.speak(
        localeCode == 'ko' ? '준비되었습니다.' : 'Ready',
    );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.connectedTo(device.name ?? "Unknown")),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.connectionFailed(e.toString()))),
      );
    }
  }

  void _setTtsLanguage(String language) async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    String languageCode = localeProvider.locale.languageCode;
    String ttsLanguage = languageCode == 'ko' ? 'ko-KR' : 'en-US';
    await _flutterTts.setLanguage(ttsLanguage);
  }

 
  @override
  void dispose() {
    _discoveryStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(locale!.homeScreenTitle)),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 왼쪽 - 연결 상태 및 스캔 버튼
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _bluetoothConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: _bluetoothConnected ? Colors.blue : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(_bluetoothConnected ? AppLocalizations.of(context)!.bluetoothConnected : AppLocalizations.of(context)!.bluetoothDisconnected),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startScan,
                        child: Text(AppLocalizations.of(context)!.scanDevices),
                      ),
                      if (_connectedDevice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          AppLocalizations.of(context)!.connectedTo(_connectedDevice!.name ?? "Unknown"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(),

                // 오른쪽 - 검색된 장치 리스트
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(locale.discoveredDevices),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index].device;
                            return ListTile(
                              title: Text(device.name ?? 'Unknown Device'),
                              subtitle: Text(device.address),
                              onTap: () => _connectToDevice(device),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Language Toggle - 왼쪽 정렬
                Consumer<LocaleProvider>(
                  builder: (context, localeProvider, child) {
                    final isEnglish = localeProvider.locale.languageCode == 'en';
                    return Row(
                      children: [
                        const Icon(Icons.language),
                        const SizedBox(width: 8),
                        Switch(
                          value: isEnglish,
                          onChanged: (val) {
                            final newLocale = val ? const Locale('en') : const Locale('ko');
                            localeProvider.setLocale(newLocale);
                          },
                        ),
                        Text(isEnglish ? AppLocalizations.of(context)!.languageEnglish : AppLocalizations.of(context)!.languageKorean),
                      ],
                    );
                  },
                ),

                // Motor Power & Battery - 중앙 정렬
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppLocalizations.of(context)!.motorPower),
                        Switch(
                          value: _motorPower,
                          onChanged: (val) {
                            setState(() {
                              _motorPower = val;
                            });
                          },
                        ),
                        Text(_motorPower ? AppLocalizations.of(context)!.on : AppLocalizations.of(context)!.off),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.battery_full),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.battery(_batteryLevel)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}   



//////////////////////////////////////////////////////


// // --- 유저 정보 관리를 위한 Provider ---
// class UserProvider extends ChangeNotifier {
//   String name = " ";  // No Name
//   String gender = "Male";
//   double age = 0.0;
//   double height = 0.0;
//   double weight = 0.0;
//   String arm = "Right";
//   double armLength = 0.0; 
//   double forearmLength = 0.0;

//   // 전체 저장된 유저 데이터 (이름을 Key로 저장)
//   Map<String, Map<String, dynamic>> allSavedUsers = {};

//   // 데이터 저장 함수
//   void saveUser(String n, String g, double a, double h, double w, String ar, double al, double fal, String pw) {
//     allSavedUsers[n] = {
//       'name': n, 'gender': g, 'age': a, 'height': h, 'weight': w, 'arm': ar, 'armLength': al, 'forearmLength': fal, 'password': pw,
//     };
//     // 현재 활성화된 정보 업데이트
//     name = n; gender = g; age = a; height = h; weight = w; armLength = al; forearmLength = fal; arm = ar;
//     notifyListeners();
//   }

//   // 데이터 불러오기 함수
//   void loadUser(Map<String, dynamic> data) {
//     name = data['name'];
//     gender = data['gender'];
//     age = data['age'];
//     height = data['height'];
//     weight = data['weight'];
//     arm = data['arm'];
//     armLength = (data['armLength'] ?? 0.0).toDouble();
//     forearmLength = (data['forearmLength'] ?? 0.0).toDouble();
//     notifyListeners();
//   }

//   // 사용자 삭제 메서드
//   void deleteUser(String userName) {
//     if (allSavedUsers.containsKey(userName)) {
//       allSavedUsers.remove(userName);
      
//       // 만약 현재 화면에 표시된 유저를 지운 것이라면 화면 정보도 초기화 (선택 사항)
//       if (name == userName) {
//         name = "N/A";
//         age = 0.0;
//         height = 0.0;
//         weight = 0.0;
//         armLength = 0.0;
//         forearmLength = 0.0;
//         // 다른 필드들도 초기값으로 세팅...
//       }
      
//       notifyListeners(); // 리스트 업데이트 알림
//     }
//   }
// }




// --- 유저 정보 관리를 위한 Provider ---
class UserProvider extends ChangeNotifier {
  // 1. 기본 유저 정보
  String name = " ";  // No Name
  String gender = "Male";
  double age = 0.0;
  double height = 0.0;
  double weight = 0.0;
  String arm = "Right";
  double armLength = 0.0; 
  double forearmLength = 0.0;

  // 2. ROM 측정 데이터 (PROM / AROM 분리 저장)
  // PROM: 관절(part), 속도(velocity), 최소각도(minAngle), 최대각도(maxAngle)
  Map<String, dynamic>? promData; 
  
  // AROM: 관절(part), 최소각도(minAngle), 최대각도(maxAngle)
  Map<String, dynamic>? aromData;

  // 3. 운동 기록 데이터 (CPM, Isometric, Isotonic 훈련 기록 저장 리스트)
  List<Map<String, dynamic>> userRecords = [];

  // 전체 저장된 유저 데이터 (이름을 Key로 저장)
  Map<String, Map<String, dynamic>> allSavedUsers = {};

  // 데이터 저장 함수
  void saveUser(String n, String g, double a, double h, double w, String ar, double al, double fal, String pw) {
    // 기존 유저 데이터가 있다면 기록(records)과 각 측정 데이터(PROM, AROM)를 유지하고, 없다면 빈 값으로 초기화
    List<Map<String, dynamic>> existingRecords = allSavedUsers[n]?['records'] ?? [];
    Map<String, dynamic>? existingProm = allSavedUsers[n]?['promData'];
    Map<String, dynamic>? existingArom = allSavedUsers[n]?['aromData'];

    allSavedUsers[n] = {
      'name': n, 
      'gender': g, 
      'age': a, 
      'height': h, 
      'weight': w, 
      'arm': ar, 
      'armLength': al, 
      'forearmLength': fal, 
      'password': pw,
      'records': existingRecords, 
      'promData': existingProm,   
      'aromData': existingArom,   
    };

    // 현재 활성화된 정보 업데이트
    name = n; 
    gender = g; 
    age = a; 
    height = h; 
    weight = w; 
    armLength = al; 
    forearmLength = fal; 
    arm = ar;
    userRecords = existingRecords;
    promData = existingProm;
    aromData = existingArom;
    
    notifyListeners();
  }

  // 데이터 불러오기 함수
  void loadUser(Map<String, dynamic> data) {
    name = data['name'];
    gender = data['gender'];
    age = data['age'];
    height = data['height'];
    weight = data['weight'];
    arm = data['arm'];
    armLength = (data['armLength'] ?? 0.0).toDouble();
    forearmLength = (data['forearmLength'] ?? 0.0).toDouble();
    
    // 사용자를 불러올 때 해당 사용자의 기록 및 PROM/AROM 데이터도 함께 불러오기
    userRecords = List<Map<String, dynamic>>.from(data['records'] ?? []);
    promData = data['promData'] != null ? Map<String, dynamic>.from(data['promData']) : null;
    aromData = data['aromData'] != null ? Map<String, dynamic>.from(data['aromData']) : null;

    notifyListeners();
  }

  // 사용자 삭제 메서드
  void deleteUser(String userName) {
    if (allSavedUsers.containsKey(userName)) {
      allSavedUsers.remove(userName);
      
      // 만약 현재 화면에 표시된 유저를 지운 것이라면 화면 정보도 초기화
      if (name == userName) {
        name = " ";
        age = 0.0;
        height = 0.0;
        weight = 0.0;
        armLength = 0.0;
        forearmLength = 0.0;
        promData = null;
        aromData = null;
        userRecords = [];
      }
      
      notifyListeners(); 
    }
  }

  // 4. PROM 업데이트 메서드 (선택 관절, 속도, 각도 범위)
  void updateProm(String part, String velocity, double minAngle, double maxAngle) {
    promData = {
      'part': part,
      'velocity': velocity,
      'minAngle': minAngle,
      'maxAngle': maxAngle,
      'date': DateTime.now().toString(),
    };
    
    if (allSavedUsers.containsKey(name)) {
      allSavedUsers[name]!['promData'] = promData;
    }
    notifyListeners();
  }

  // 5. AROM 업데이트 메서드 (선택 관절, 각도 범위)
  void updateArom(String part, double minAngle, double maxAngle) {
    aromData = {
      'part': part,
      'minAngle': minAngle,
      'maxAngle': maxAngle,
      'date': DateTime.now().toString(),
    };
    
    if (allSavedUsers.containsKey(name)) {
      allSavedUsers[name]!['aromData'] = aromData;
    }
    notifyListeners();
  }

  // 6. 운동 기록 추가 메서드 (운동 모드 종류에 따라 다른 Map 구조를 유연하게 수용)
  // void addRecord(Map<String, dynamic> record) {
  //   userRecords.add(record);
    
  //   if (allSavedUsers.containsKey(name)) {
  //     allSavedUsers[name]!['records'] = userRecords;
  //   }
  //   notifyListeners();
  // }
  // 6. 운동 기록 추가 메서드 (수정됨: 참조 꼬임 방지 및 확실한 누적 보장)
  void addRecord(Map<String, dynamic> record) {
    // 기존 리스트의 복사본을 만들고 거기에 새 기록을 추가하여 확실하게 누적시킴
    userRecords = List<Map<String, dynamic>>.from(userRecords)..add(record);
    
    // 전체 저장소(allSavedUsers) 맵에도 복사본을 업데이트
    if (allSavedUsers.containsKey(name)) {
      allSavedUsers[name]!['records'] = List<Map<String, dynamic>>.from(userRecords);
    }
    
    notifyListeners();
  }
}