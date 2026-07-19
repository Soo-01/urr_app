import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'generated/l10n.dart';

import 'record.dart';
// ⚠️ 주의: UserProvider가 정의된 파일(주로 main.dart)을 알맞게 임포트 해주세요.
import 'main.dart';

class Information extends StatefulWidget {
  // 💡 필요 없는 파라미터를 모두 지웠으므로 생성자도 텅 비워줍니다.
  const Information({super.key});

  @override
  State<Information> createState() => _InformationState();
}

class _InformationState extends State<Information> {
  Future<List<UserRecord>> _fetchUserRecords(String currentUserName) async {
    return RecordManager.loadRecords(userName: currentUserName);
  }

  Future<void> _confirmAndDeleteRecord(UserRecord record) async {
    final loc = AppLocalizations.of(context)!;
    final isKorean = loc.localeName == 'ko';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isKorean ? '기록 삭제' : 'Delete record'),
        content: Text(isKorean
            ? '이 측정 및 운동 기록을 삭제하시겠습니까?'
            : 'Delete this measurement or training record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await RecordManager.deleteRecord(record);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted
            ? (isKorean ? '기록이 삭제되었습니다.' : 'Record deleted.')
            : (isKorean ? '기록을 찾을 수 없습니다.' : 'Record not found.')),
      ),
    );
  }

  // 예시: 파일 상단 또는 클래스 내부에 작성
  String getLocalizedGender(String gender, AppLocalizations loc) {
    switch (gender) {
      case 'Male':
        return loc.male;
      case 'Female':
        return loc.female;
      default:
        return gender; // 매핑되지 않은 경우 원본 텍스트 반환
    }
  }

  String getLocalizedArm(String arm, AppLocalizations loc) {
    switch (arm) {
      case 'Right':
        return loc.right;
      case 'Left':
        return loc.left;
      default:
        return arm;
    }
  }

  String getLocalizedMode(String mode, AppLocalizations loc) {
    switch (mode) {
      case 'Passive ROM':
        return loc.passiverom;
      case 'Active ROM':
        return loc.activerom;
      case 'CPM':
        return loc.cpm;
      case 'Isometric':
        return loc.isometric;
      case 'Isotonic':
        return loc.isotonic;

      // case 'lShoulderEF': return loc.lShoulderEF;
      // case 'lShoulderRo': return loc.lShoulderRo;
      // case 'lElbow': return loc.lElbow;
      // case 'lWrist': return loc.lWrist;

      // case 'rShoulderEF': return loc.rShoulderEF;
      // case 'rShoulderRo': return loc.rShoulderRo;
      // case 'rElbow': return loc.rElbow;
      // case 'rWrist': return loc.rWrist;

      default:
        return mode;
    }
  }

  String getLocalizedJoint(String joint, AppLocalizations loc) {
    switch (joint) {
      case 'lShoulderEF':
        return loc.lShoulderEF;
      case 'lShoulderRo':
        return loc.lShoulderRo;
      case 'lElbow':
        return loc.lElbow;
      case 'lWrist':
        return loc.lWrist;

      case 'rShoulderEF':
        return loc.rShoulderEF;
      case 'rShoulderRo':
        return loc.rShoulderRo;
      case 'rElbow':
        return loc.rElbow;
      case 'rWrist':
        return loc.rWrist;
      default:
        return joint; // 일치하는 게 없으면 원본 반환
    }
  }

  String getLocalizedExtraData(String extraData, AppLocalizations loc) {
    // 저장된 문자열 내부의 영어 라벨들을 한글 라벨로 교체합니다.
    return extraData
        .replaceAll('Velocity:', '속도:')
        .replaceAll('Intensity:', '저항력:')
        .replaceAll('Target Angle:', '목표 각도:')
        .replaceAll('Duration:', '지속 시간:')
        .replaceAll('SubMode:', '모드:')
        .replaceAll('Cable', '케이블')
        .replaceAll('Dumbbell', '덤벨');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Provider에서 현재 사용자 정보를 바로 가져옵니다.
    final userProvider = Provider.of<UserProvider>(context);
    final String name = userProvider.name;
    final String gender = userProvider.gender;
    final double age = userProvider.age.toDouble();
    final double height = userProvider.height.toDouble();
    final double weight = userProvider.weight.toDouble();
    final String arm = userProvider.arm;

    return Scaffold(
      appBar: AppBar(title: Text(loc.userProfileAndHistory)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ==========================================
            // 1. 제일 위에는 현재 로드되어있는 사용자 정보 띄우기
            // ==========================================
            Text('👤 ${loc.profile}:',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${loc.name}: $name'),
            // Text('${loc.gender}: $gender'),
            Text('${loc.gender}: ${getLocalizedGender(gender, loc)}'),
            Text('${loc.age}: $age'),
            Text('${loc.height}: $height cm'),
            Text('${loc.weight}: $weight kg'),
            Text('${loc.diseasedArm}: ${getLocalizedArm(arm, loc)}'),
            const Divider(thickness: 2, height: 32),

            // 💡 Sended Files, Selected Mode Settings, Control Gains 화면에서 모두 제거됨

            // ==========================================
            // 3. Saved Measurement & Training History만 남기기
            // ==========================================
            Text('📊 ${loc.savedMeasurementAndTrainigHistory}:',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    child: Text(loc.noSavedHistory,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                // 기록이 있을 때 출력 (Selected Mode Settings로 띄우던 정보는 extraData에 저장되어 Details: 로 출력됨)
                return Column(
                  children: records.map((record) {
                    final formattedDate =
                        record.timestamp.toString().substring(0, 16);

                    // return Card(
                    //   margin: const EdgeInsets.symmetric(vertical: 6),
                    //   elevation: 2,
                    //   child: ListTile(
                    //     leading: Icon(
                    //       record.recordType.contains('ROM') ? Icons.straighten : Icons.fitness_center,
                    //       color: record.recordType.contains('ROM') ? Colors.blue : Colors.orange,
                    //       size: 32,
                    //     ),
                    //     title: Text('[${record.recordType}] ${record.joint}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    //     subtitle: Text('${loc.data}: $formattedDate\n${loc.range}: ${record.minAngle}° ~ ${record.maxAngle}°' +
                    //         // ★ 여기에 기존 Selected Mode Settings 였던 속도 등의 정보가 나옵니다.
                    //         (record.extraData.isNotEmpty ? '\n${loc.details}: ${record.extraData}' : '')),
                    //     isThreeLine: true,
                    //   ),
                    // );
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: Stack(
                        children: [
                          ListTile(
                            contentPadding:
                                const EdgeInsets.fromLTRB(16, 8, 48, 8),
                            leading: Icon(
                              record.recordType.contains('ROM')
                                  ? Icons.straighten
                                  : Icons.fitness_center,
                              color: record.recordType.contains('ROM')
                                  ? Colors.blue
                                  : Colors.orange,
                              size: 32,
                            ),
                            title: Text(
                              '[${getLocalizedMode(record.recordType, loc)}] ${getLocalizedJoint(record.joint, loc)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${loc.data}: $formattedDate\n${loc.range}: ${record.minAngle}° ~ ${record.maxAngle}°' +
                                  (record.extraData.isNotEmpty
                                      ? '\n${loc.details}: ${getLocalizedExtraData(record.extraData, loc)}'
                                      : ''),
                            ),
                            isThreeLine: true,
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              color: Colors.red.shade400,
                              tooltip: loc.localeName == 'ko'
                                  ? '기록 삭제'
                                  : 'Delete record',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmAndDeleteRecord(record),
                            ),
                          ),
                        ],
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
