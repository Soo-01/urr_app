import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exo_tablet_app_v6/record.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deleteRecord permanently removes only the selected record', () async {
    final first = UserRecord(
      timestamp: DateTime(2026, 7, 18, 8, 36),
      userName: 'tester',
      recordType: 'Active ROM',
      joint: 'rShoulderEF',
      minAngle: 10.5,
      maxAngle: 135.0,
    );
    final second = UserRecord(
      timestamp: DateTime(2026, 7, 18, 9),
      userName: 'tester',
      recordType: 'Passive ROM',
      joint: 'rElbow',
      minAngle: 20,
      maxAngle: 90,
    );

    await RecordManager.saveRecord(first);
    await RecordManager.saveRecord(second);
    expect(await RecordManager.loadRecords(userName: 'tester'), hasLength(2));

    expect(await RecordManager.deleteRecord(first), isTrue);
    final remaining = await RecordManager.loadRecords(userName: 'tester');
    expect(remaining, hasLength(1));
    expect(remaining.single.timestamp, second.timestamp);
    expect(await RecordManager.deleteRecord(first), isFalse);
  });

  test('persists structured fields for every exercise record type', () async {
    final records = [
      UserRecord(
        timestamp: DateTime(2026, 7, 19, 10),
        userName: 'tester',
        recordType: 'CPM',
        joint: 'rElbow',
        minAngle: 10,
        maxAngle: 80,
        velocity: '4',
      ),
      UserRecord(
        timestamp: DateTime(2026, 7, 19, 11),
        userName: 'tester',
        recordType: 'Isometric',
        joint: 'rShoulderEF',
        targetAngle: 45,
        holdDurationSeconds: 5,
        minTorque: -0.4,
        maxTorque: 0.8,
      ),
      UserRecord(
        timestamp: DateTime(2026, 7, 19, 12),
        userName: 'tester',
        recordType: 'Isotonic',
        joint: 'rShoulderRo',
        targetAngle: 60,
        resistanceLevel: 3,
      ),
    ];

    for (final record in records) {
      await RecordManager.saveRecord(record);
    }

    final loaded = await RecordManager.loadRecords(userName: 'tester');
    expect(loaded, hasLength(3));
    expect(loaded[0].recordType, 'Isotonic');
    expect(loaded[0].targetAngle, 60);
    expect(loaded[0].resistanceLevel, 3);
    expect(loaded[1].holdDurationSeconds, 5);
    expect(loaded[1].minTorque, -0.4);
    expect(loaded[1].maxTorque, 0.8);
    expect(loaded[2].minAngle, 10);
    expect(loaded[2].maxAngle, 80);
    expect(loaded[2].velocity, '4');
  });
}
