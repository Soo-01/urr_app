import 'package:exo_tablet_app_v6/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile and ROM prerequisites follow the active user', () {
    final provider = UserProvider();

    expect(provider.hasRegisteredProfile, isFalse);
    expect(provider.hasAnyRomMeasurement, isFalse);

    provider.saveUser(
      'patient',
      'Male',
      50,
      170,
      70,
      'Right',
      30,
      25,
      '1234',
    );
    expect(provider.hasRegisteredProfile, isTrue);

    provider.updateProm('rShoulderEF', '5', 0, 90);
    provider.updateArom('rShoulderEF', 10, 80);
    provider.updateArom('rElbow', 10, 100);

    expect(provider.hasAnyRomMeasurement, isTrue);
    expect(provider.promForPart('rShoulderEF')?['minAngle'], 0);
    expect(provider.aromForPart('rShoulderEF')?['maxAngle'], 80);
    expect(provider.measuredRomForPart('rShoulderEF')?['minAngle'], 10);
    expect(provider.measuredRomForPart('rShoulderEF')?['maxAngle'], 80);
    expect(provider.measuredRomForPart('rShoulderEF')?['mode'], 'AROM');
    expect(provider.measuredRomForPart('rElbow')?['minAngle'], 10);
    expect(provider.measuredRomForPart('rShoulderRo'), isNull);

    final reloaded = UserProvider();
    reloaded.allSavedUsers = provider.allSavedUsers;
    reloaded.loadUser(reloaded.allSavedUsers['patient']!);
    expect(reloaded.promForPart('rShoulderEF')?['maxAngle'], 90);
    expect(reloaded.aromForPart('rShoulderEF')?['minAngle'], 10);
    expect(reloaded.measuredRomForPart('rShoulderEF')?['mode'], 'AROM');
  });
}
