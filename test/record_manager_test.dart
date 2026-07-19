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
}
