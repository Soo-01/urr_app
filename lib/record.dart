import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // UserProvider가 정의된 파일 경로
import 'generated/l10n.dart'; // 다국어 지원 (필요시 사용)

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // 사용자가 리스트에서 선택한 특정 기록을 담을 변수
  Map<String, dynamic>? _selectedRecord;

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 누적된 유저 데이터를 실시간 감지
    final userProvider = context.watch<UserProvider>();
    final records = userProvider.userRecords; // 전체 누적 기록 리스트

    // 누적 통계 계산 (ROM 측정 횟수 vs 실제 운동/훈련 횟수)
    int totalRom = records.where((r) => r['mode'].toString().contains('ROM')).length;
    int totalExercise = records.length - totalRom;

    return Scaffold(
      appBar: AppBar(
        title: Text('${userProvider.name.trim().isEmpty ? "사용자 없음" : userProvider.name}의 훈련 누적 기록'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: userProvider.name.trim().isEmpty
          ? const Center(
              child: Text(
                '먼저 사용자 정보를 입력하거나 불러와 주세요.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // --- 1. 상단 누적 통계 요약 대시보드 ---
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('총 누적 기록', '${records.length}건', Icons.history, Colors.blue),
                      _buildStatCard('가동 범위 측정', '${totalRom}건', Icons.straighten, Colors.indigo),
                      _buildStatCard('훈련(운동) 누적', '${totalExercise}건', Icons.fitness_center, Colors.green),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // --- 2. 하단 기록 리스트 및 상세 뷰 (마스터-디테일 패턴) ---
                Expanded(
                  child: Row(
                    children: [
                      // [좌측 패널] 누적 기록 목록
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: records.isEmpty
                              ? const Center(child: Text('아직 저장된 훈련 기록이 없습니다.'))
                              : ListView.builder(
                                  itemCount: records.length,
                                  // 최신 기록이 위로 오도록 역순 배치
                                  itemBuilder: (context, index) {
                                    final record = records[records.length - 1 - index];
                                    final isSelected = _selectedRecord == record;
                                    final isExercise = record['type'] == 'Exercise';

                                    return ListTile(
                                      tileColor: isSelected ? Colors.blue.shade50 : null,
                                      leading: CircleAvatar(
                                        backgroundColor: isExercise ? Colors.green.shade100 : Colors.indigo.shade100,
                                        child: Icon(
                                          isExercise ? Icons.fitness_center : Icons.straighten,
                                          color: isExercise ? Colors.green : Colors.indigo,
                                        ),
                                      ),
                                      title: Text(
                                        '[${record['mode']}] ${record['part'] ?? '부위 미상'}',
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        record['date']?.toString().split('.')[0] ?? '',
                                      ),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () {
                                        setState(() {
                                          _selectedRecord = record;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),

                      // [우측 패널] 선택된 특정 훈련의 상세 데이터
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: _selectedRecord == null
                              ? const Center(
                                  child: Text(
                                    '좌측에서 훈련 기록을 선택하면 상세 정보가 표시됩니다.',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                )
                              : _buildRecordDetail(_selectedRecord!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // 통계용 카드 위젯
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // 우측 상세 정보 렌더링 위젯
  Widget _buildRecordDetail(Map<String, dynamic> record) {
    final isExercise = record['type'] == 'Exercise';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExercise ? Icons.fitness_center : Icons.straighten,
                color: isExercise ? Colors.green : Colors.indigo,
                size: 32,
              ),
              const SizedBox(width: 10),
              Text(
                '${record['mode']} 상세 기록',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 40, thickness: 2),
          
          _detailRow('훈련 일시', record['date']?.toString().split('.')[0] ?? ''),
          _detailRow('타겟 관절', record['part'] ?? '-'),
          
          const SizedBox(height: 24),
          const Text('측정 및 훈련 데이터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // 모드별 데이터 조건부 렌더링
          if (record['minAngle'] != null && record['maxAngle'] != null) ...[
            _detailRow('최소 각도', '${record['minAngle']}°'),
            _detailRow('최대 각도', '${record['maxAngle']}°'),
          ],
          
          if (record['velocity'] != null && record['velocity'] != 'N/A')
            _detailRow('훈련 속도', '${record['velocity']}'),
            
          if (record['mode'] == 'Isometric') ...[
            _detailRow('목표 각도', '${record['targetAngle']}°'),
            _detailRow('지속 시간', '${record['duration']}초'),
            if (record['maxTorque'] != null)
              _detailRow('최대 힘(Torque)', '${record['maxTorque']}'),
          ],
          
          if (record['mode'] == 'Isotonic') ...[
            _detailRow('저항력 단계', '${record['resistance']}'),
            _detailRow('운동 도구', '${record['subMode'] ?? '미선택'}'), 
          ],

          if (record['reps'] != null && record['reps'] > 0)
            _detailRow('반복 횟수', '${record['reps']}회'),
        ],
      ),
    );
  }

  // 상세 정보 한 줄을 이쁘게 표시하기 위한 헬퍼 위젯
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          SizedBox(
            width: 150, 
            child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.black54))
          ),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}