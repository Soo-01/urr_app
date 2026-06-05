import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:convert';
import 'package:provider/provider.dart';
import 'generated/l10n.dart';


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
    final loc = AppLocalizations.of(context)!;

    // Provider에서 현재 사용자 정보를 바로 가져옵니다.
    final userProvider = Provider.of<UserProvider>(context);
    final String name = userProvider.name ?? 'Unknown';
    final String gender = userProvider.gender ?? 'Unknown';
    final double age = userProvider.age?.toDouble() ?? 0.0;
    final double height = userProvider.height?.toDouble() ?? 0.0;
    final double weight = userProvider.weight?.toDouble() ?? 0.0;
    final String arm = userProvider.arm ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text(loc.userProfileAndHistory)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ==========================================
            // 1. 제일 위에는 현재 로드되어있는 사용자 정보 띄우기
            // ==========================================
            Text('👤 ${loc.profile}:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${loc.name}: $name'),
            Text('${loc.gender}: $gender'),
            Text('${loc.age}: $age'),
            Text('${loc.height}: $height cm'),
            Text('${loc.weight}: $weight kg'),
            Text('${loc.diseasedArm}: $arm'),
            const Divider(thickness: 2, height: 32),

            // 💡 Sended Files, Selected Mode Settings, Control Gains 화면에서 모두 제거됨

            // ==========================================
            // 3. Saved Measurement & Training History만 남기기
            // ==========================================
            Text('📊 ${loc.savedMeasurementAndTrainigHistory}:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(loc.noSavedHistory, style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
                        subtitle: Text('${loc.data}: $formattedDate\n${loc.range}: ${record.minAngle}° ~ ${record.maxAngle}°' +
                            // ★ 여기에 기존 Selected Mode Settings 였던 속도 등의 정보가 나옵니다.
                            (record.extraData.isNotEmpty ? '\n${loc.details}: ${record.extraData}' : '')),
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