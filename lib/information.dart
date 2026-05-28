// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'bluetooth.dart';

// class Information extends StatelessWidget {
//   final List<FileSystemEntity> sendedFiles;
//   final String selectedMode;
//   final String selectedVelocity;
//   final String selectedIntensity;
//   final String name;
//   final String gender;
//   final double age;
//   final double height;
//   final double weight;
//   final String arm;
//   final Map<String, Map<String, double>> controlValues;

//   const Information({
//     super.key,
//     required this.sendedFiles,
//     required this.selectedMode,
//     required this.selectedVelocity,
//     required this.selectedIntensity,
//     required this.name,
//     required this.gender,
//     required this.age,
//     required this.height,
//     required this.weight,
//     required this.arm,
//     required this.controlValues,
//   });

//   String buildBluetoothMessage() {
//     if (selectedMode == 'Stop') return 'E';
//     if (controlValues.containsKey('PD control')) {
//       final pd = controlValues['PD control']!;
//       return 'gain:${arm[0]},${pd['Left Kp']},${pd['Left Kd']},${pd['Right Kp']},${pd['Right Kd']}';
//     } else if (controlValues.containsKey('Gravity Compensator')) {
//       final gc = controlValues['Gravity Compensator']!;
//       return 'grav:${arm[0]},$weight,$height,${gc['Left Thigh_gain']},${gc['Left Shank_gain']}';
//     } else {
//       return '$selectedMode,$selectedVelocity,$selectedIntensity';
//     }
//   }

//   void sendControlData(BuildContext context) async {
//     final message = buildBluetoothMessage();
//     if (message.isEmpty) return;

//     final success = await BluetoothService().sendBytes(Uint8List.fromList(message.codeUnits));
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(success ? 'Data sent: $message' : 'Bluetooth transmission failed'),
//     ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final controlMode = controlValues.keys.isNotEmpty ? controlValues.keys.first : 'N/A';
//     final gainMessage = buildBluetoothMessage();

//     return Scaffold(
//       appBar: AppBar(title: const Text('User Information')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             const Text('📁 Sended Files:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             ...sendedFiles.map((file) => Text('• ${file.path.split('/').last}')),
//             const Divider(),

//             const Text('🧠 Selected Mode Settings:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text('Mode: $selectedMode'),
//             Text('Velocity: $selectedVelocity'),
//             Text('Intensity: $selectedIntensity'),
//             Text('Control Mode: $controlMode'),
//             const Divider(),

//             const Text('👤 User Profile:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text('Name: $name'),
//             Text('Gender: $gender'),
//             Text('Age: $age'),
//             Text('Height: $height cm'),
//             Text('Weight: $weight kg'),
//             Text('Arm: $arm'),
//             const Divider(),

//             const Text('🔧 Control Gains:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             if (controlValues.isEmpty || controlValues[controlMode] == null || controlValues[controlMode]!.isEmpty)
//               const Text('No gain values selected.')
//             else
//               ...controlValues.entries.expand((entry) => [
//                 Text('Mode: ${entry.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
//                 ...entry.value.entries.map((e) => Text('${e.key}: ${e.value.toStringAsFixed(1)}')),
//                 const SizedBox(height: 12),
//               ]),

//             const SizedBox(height: 20),
//             const Text('📡 Generated Bluetooth Message:', style: TextStyle(fontWeight: FontWeight.bold)),
//             Text(gainMessage),
//           ],
//         ),
//       ),
//     );
//   }
// }

/////////////////////////////////////////////////////

// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'main.dart';
// import 'bluetooth.dart';

// class Information extends StatefulWidget {
//   // 생성자 매개변수는 기존 구조를 유지하기 위해 놔두되, 
//   // 프로필 데이터는 Provider에서 가져오도록 수정합니다.
//   final List<FileSystemEntity>? sendedFiles;
//   final String? selectedMode;
//   final String? selectedVelocity;
//   final String? selectedIntensity;
//   final Map<String, Map<String, double>>? controlValues;

//   const Information({
//     super.key,
//     this.sendedFiles,
//     this.selectedMode = 'Stop',
//     this.selectedVelocity = 'Low',
//     this.selectedIntensity = 'Low',
//     this.controlValues = const {},
//   });

//   @override
//   State<Information> createState() => _InformationState();
// }

// class _InformationState extends State<Information> {
//   final TextEditingController _pwConfirmController = TextEditingController();

//   void _showPasswordDialog(String userName, Map<String, dynamic> userData) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Load Profile: $userName'),
//         content: TextField(
//           controller: _pwConfirmController,
//           obscureText: true,
//           decoration: const InputDecoration(hintText: "Enter Password"),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           ElevatedButton(
//             onPressed: () {
//               if (_pwConfirmController.text == userData['password']) {
//                 context.read<UserProvider>().loadUser(userData);
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Loaded Successfully!')));
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Password')));
//               }
//               _pwConfirmController.clear();
//             },
//             child: const Text('Verify'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = context.watch<UserProvider>();
//     final savedUsers = user.allSavedUsers;

//     return Scaffold(
//       appBar: AppBar(title: const Text('User Information')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             const Text('📂 Registered Users (Click to Load):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
//             const SizedBox(height: 10),
//             if (savedUsers.isEmpty) 
//               const Text('No users saved yet.')
//             else
//               Wrap(
//                 spacing: 8,
//                 children: savedUsers.entries.map((entry) {
//                   return ActionChip(
//                     avatar: const Icon(Icons.lock, size: 16),
//                     label: Text(entry.key),
//                     onPressed: () => _showPasswordDialog(entry.key, entry.value),
//                   );
//                 }).toList(),
//               ),
//             const Divider(height: 40, thickness: 2),

//             const Text('👤 Current Profile Detail:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text('Name: ${user.name}', style: const TextStyle(fontSize: 18, color: Colors.blueAccent)),
//             Text('Gender: ${user.gender} / Age: ${user.age}'),
//             Text('Height: ${user.height} m / Weight: ${user.weight} kg'),
//             Text('Diseased Arm: ${user.arm}'),
            
//             const Divider(),
//             const Text('🧠 Settings:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text('Mode: ${widget.selectedMode}'),
//             Text('Velocity: ${widget.selectedVelocity} / Intensity: ${widget.selectedIntensity}'),
//             // Bluetooth Message 등 기존 UI 로직 유지...
//           ],
//         ),
//       ),
//     );
//   }
// }

/////////////////////////////////////////////////////

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'generated/l10n.dart';

class Information extends StatefulWidget {
  final List<FileSystemEntity>? sendedFiles;
  final String? selectedMode;
  final String? selectedVelocity;
  final String? selectedIntensity;
  final Map<String, Map<String, double>>? controlValues;

  const Information({
    super.key,
    this.sendedFiles,
    this.selectedMode = 'Stop',
    this.selectedVelocity = 'Low',
    this.selectedIntensity = 'Low',
    this.controlValues = const {},
  });

  @override
  State<Information> createState() => _InformationState();
}

class _InformationState extends State<Information> {
  final TextEditingController _pwConfirmController = TextEditingController();
  bool _showUserList = false; // 리스트 표시 여부

  void _showPasswordDialog(String userName, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Load Profile: $userName'),
        content: TextField(
          controller: _pwConfirmController,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter Password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_pwConfirmController.text == userData['password']) {
                context.read<UserProvider>().loadUser(userData);
                setState(() => _showUserList = false);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Loaded!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Password')));
              }
              _pwConfirmController.clear();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final savedUsers = user.allSavedUsers;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('User Information Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 정보 요약 상단에 불러오기 버튼 배치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👤 Current Profile:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showUserList = !_showUserList),
                  icon: const Icon(Icons.people),
                  label: Text(_showUserList ? '목록 닫기' : '사용자 불러오기'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // 불러오기 리스트 (조건부 표시)
            if (_showUserList) ...[
              Wrap(
                spacing: 8,
                children: savedUsers.entries.map((entry) {
                  return ActionChip(
                    avatar: const Icon(Icons.lock_outline, size: 16),
                    label: Text(entry.key),
                    onPressed: () => _showPasswordDialog(entry.key, entry.value),
                  );
                }).toList(),
              ),
              const Divider(),
            ],

            Text('Name: ${user.name}', style: const TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            Text('Gender: ${user.gender} / Age: ${user.age}'),
            Text('Height: ${user.height} m / Weight: ${user.weight} kg'),
            Text('Diseased Arm: ${user.arm}'),
            
            const Divider(height: 40),
            const Text('🧠 Training Settings:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Selected Mode: ${widget.selectedMode}'),
            Text('Velocity: ${widget.selectedVelocity} / Intensity: ${widget.selectedIntensity}'),
          ],
        ),
      ),
    );
  }
}