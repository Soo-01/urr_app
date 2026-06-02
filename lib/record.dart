import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 1. 누적 저장을 위한 데이터 모델 정의
class UserRecord {
  final DateTime timestamp;
  final String userName;     // 사용자 식별을 위한 이름
  final String recordType;   // 예: 'Passive ROM', 'Active ROM', 'CPM', 'Isometric', 'Isotonic'
  final String joint;        // 예: '오른팔 어깨 굴곡/신전', '왼팔 손목 굴곡/신전'
  final double minAngle;
  final double maxAngle;
  final String extraData;    // 속도, 저항력 단계, 지속시간 등 추가 정보 (선택 사항)

  UserRecord({
    required this.timestamp,
    required this.userName,
    required this.recordType,
    required this.joint,
    required this.minAngle,
    required this.maxAngle,
    this.extraData = '',
  });

  // 객체를 JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'userName': userName,
        'recordType': recordType,
        'joint': joint,
        'minAngle': minAngle,
        'maxAngle': maxAngle,
        'extraData': extraData,
      };

  // JSON을 객체로 변환 (불러오기용)
  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        timestamp: DateTime.parse(json['timestamp']),
        userName: json['userName'],
        recordType: json['recordType'],
        joint: json['joint'],
        minAngle: json['minAngle'].toDouble(),
        maxAngle: json['maxAngle'].toDouble(),
        extraData: json['extraData'] ?? '',
      );
}

// 2. 다른 모드(ROM, CPM 등)에서 데이터를 저장하고 불러오기 위한 전역 매니저
class RecordManager {
  static const String _storageKey = 'user_accumulated_records';

  // 새로운 기록을 기존 리스트에 누적하여 저장
  static Future<void> saveRecord(UserRecord newRecord) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString(_storageKey);
    List<UserRecord> records = [];

    if (recordsJson != null) {
      final List<dynamic> decodedList = jsonDecode(recordsJson);
      records = decodedList.map((item) => UserRecord.fromJson(item)).toList();
    }

    records.add(newRecord); // 새 기록 추가 (누적)
    await prefs.setString(_storageKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  // 운동/게임을 위해 특정 사용자 & 특정 관절의 '가장 최근 ROM 측정값'만 가져오기
  static Future<Map<String, double>?> getLatestROMLimit(String userName, String joint) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString(_storageKey);
    
    if (recordsJson == null) return null;

    final List<dynamic> decodedList = jsonDecode(recordsJson);
    List<UserRecord> records = decodedList
        .map((item) => UserRecord.fromJson(item))
        .where((r) => r.userName == userName && 
                      r.joint == joint && 
                      r.recordType.contains('ROM')) // ROM 측정 기록만 필터링
        .toList();

    if (records.isEmpty) return null; // 해당 관절의 ROM 측정 기록이 없는 경우

    // 최신 날짜 순으로 정렬 후 가장 첫 번째(최신) 데이터 반환
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return {
      'minAngle': records.first.minAngle,
      'maxAngle': records.first.maxAngle,
    };
  }
}

// 3. 기록을 사용자 UI에 보여주는 화면 위젯
class RecordScreen extends StatelessWidget {
  final String currentUser; // navi.dart 등에서 전달받을 현재 프로필 사용자 이름

  const RecordScreen({super.key, required this.currentUser});

  // SharedPreferences에서 데이터를 매번 새로 읽어오는 함수
  Future<List<UserRecord>> _fetchRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString(RecordManager._storageKey);
    
    if (recordsJson == null) return [];

    final List<dynamic> decodedList = jsonDecode(recordsJson);
    List<UserRecord> records = decodedList
        .map((item) => UserRecord.fromJson(item))
        // 💡 테스트 중이므로 현재 사용자 이름 필터링은 임시로 주석 처리합니다.
        // .where((record) => record.userName == currentUser) 
        .toList();
    
    // 최신 날짜순으로 정렬
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder를 사용하면 탭을 누를 때마다 _fetchRecords()가 실행되어 최신 데이터를 가져옵니다.
    return Scaffold(
      appBar: AppBar(title: const Text('저장된 훈련 및 측정 기록')),
      body: FutureBuilder<List<UserRecord>>(
        future: _fetchRecords(), // 위에서 만든 함수 호출
        builder: (context, snapshot) {
          // 데이터를 불러오는 중일 때 (로딩 인디케이터)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final _userRecords = snapshot.data ?? [];

          // 저장된 기록이 없을 때
          if (_userRecords.isEmpty) {
            return const Center(child: Text('저장된 기록이 없습니다.', style: TextStyle(fontSize: 18)));
          }

          // 기록이 있을 때 리스트 뷰로 출력
          return ListView.builder(
            itemCount: _userRecords.length,
            itemBuilder: (context, index) {
              final record = _userRecords[index];
              // 날짜 포맷팅 (예: 2026-06-02 15:30)
              final formattedDate = record.timestamp.toString().substring(0, 16);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    record.recordType.contains('ROM') ? Icons.straighten : Icons.fitness_center,
                    color: record.recordType.contains('ROM') ? Colors.blue : Colors.orange,
                    size: 36,
                  ),
                  title: Text('[${record.recordType}] ${record.joint}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('측정일: $formattedDate'),
                      Text('가동 범위: ${record.minAngle}° ~ ${record.maxAngle}°'),
                      if (record.extraData.isNotEmpty) Text('상세 설정: ${record.extraData}'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}