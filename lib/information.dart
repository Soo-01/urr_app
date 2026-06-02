// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'main.dart';
// import 'generated/l10n.dart';

// class Information extends StatefulWidget {
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
//   bool _showUserList = false; // 리스트 표시 여부

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
//                 setState(() => _showUserList = false);
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Loaded!')));
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
//     final loc = AppLocalizations.of(context)!;

//     return Scaffold(
//       appBar: AppBar(title: const Text('User Information Summary')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             // 정보 요약 상단에 불러오기 버튼 배치
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text('👤 Current Profile:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 ElevatedButton.icon(
//                   onPressed: () => setState(() => _showUserList = !_showUserList),
//                   icon: const Icon(Icons.people),
//                   label: Text(_showUserList ? '목록 닫기' : '사용자 불러오기'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
            
//             // 불러오기 리스트 (조건부 표시)
//             if (_showUserList) ...[
//               Wrap(
//                 spacing: 8,
//                 children: savedUsers.entries.map((entry) {
//                   return ActionChip(
//                     avatar: const Icon(Icons.lock_outline, size: 16),
//                     label: Text(entry.key),
//                     onPressed: () => _showPasswordDialog(entry.key, entry.value),
//                   );
//                 }).toList(),
//               ),
//               const Divider(),
//             ],

//             Text('Name: ${user.name}', style: const TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
//             Text('Gender: ${user.gender} / Age: ${user.age}'),
//             Text('Height: ${user.height} m / Weight: ${user.weight} kg'),
//             Text('Diseased Arm: ${user.arm}'),
            
//             const Divider(height: 40),
//             const Text('🧠 Training Settings:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text('Selected Mode: ${widget.selectedMode}'),
//             Text('Velocity: ${widget.selectedVelocity} / Intensity: ${widget.selectedIntensity}'),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:convert';
import 'package:provider/provider.dart'; 

import 'record.dart'; 
// ⚠️ 주의: UserProvider가 정의된 파일(주로 main.dart)을 알맞게 임포트 해주세요.
import 'main.dart'; 

class Information extends StatelessWidget {
  // 💡 필요 없는 파라미터를 모두 지웠으므로 생성자도 텅 비워줍니다.
  const Information({super.key});

  Future<List<UserRecord>> _fetchUserRecords(String currentUserName) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('user_accumulated_records'); 
    
    if (recordsJson == null) return [];

    final List<dynamic> decodedList = jsonDecode(recordsJson);
    List<UserRecord> records = decodedList
        .map((item) => UserRecord.fromJson(item))
        .where((r) => r.userName == currentUserName) // ★ 현재 로그인된 이름과 일치하는 기록만 가져옴
        .toList();

    // 최신 날짜 순으로 정렬
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 현재 사용자 정보를 바로 가져옵니다.
    final userProvider = Provider.of<UserProvider>(context);
    final String name = userProvider.name ?? 'Unknown';
    final String gender = userProvider.gender ?? 'Unknown';
    final double age = userProvider.age?.toDouble() ?? 0.0;
    final double height = userProvider.height?.toDouble() ?? 0.0;
    final double weight = userProvider.weight?.toDouble() ?? 0.0;
    final String arm = userProvider.arm ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('User Profile & History')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ==========================================
            // 1. 제일 위에는 현재 로드되어있는 사용자 정보 띄우기
            // ==========================================
            const Text('👤 User Profile:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Name: $name'),
            Text('Gender: $gender'),
            Text('Age: $age'),
            Text('Height: $height cm'),
            Text('Weight: $weight kg'),
            Text('Arm: $arm'),
            const Divider(thickness: 2, height: 32),

            // 💡 Sended Files, Selected Mode Settings, Control Gains 화면에서 모두 제거됨

            // ==========================================
            // 3. Saved Measurement & Training History만 남기기
            // ==========================================
            const Text('📊 Saved Measurement & Training History:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            FutureBuilder<List<UserRecord>>(
              future: _fetchUserRecords(name), // ★ 현재 사용자 이름으로 데이터 조회
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data ?? [];

                // 기록이 없을 때의 메시지 유지
                if (records.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('해당 사용자의 저장된 기록이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                // 기록이 있을 때 출력 (Selected Mode Settings로 띄우던 정보는 extraData에 저장되어 Details: 로 출력됨)
                return Column(
                  children: records.map((record) {
                    final formattedDate = record.timestamp.toString().substring(0, 16);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          record.recordType.contains('ROM') ? Icons.straighten : Icons.fitness_center,
                          color: record.recordType.contains('ROM') ? Colors.blue : Colors.orange,
                          size: 32,
                        ),
                        title: Text('[${record.recordType}] ${record.joint}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Date: $formattedDate\nRange: ${record.minAngle}° ~ ${record.maxAngle}°' +
                            // ★ 여기에 기존 Selected Mode Settings 였던 속도 등의 정보가 나옵니다.
                            (record.extraData.isNotEmpty ? '\nDetails: ${record.extraData}' : '')),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 40), // 하단 여백
          ],
        ),
      ),
    );
  }
}