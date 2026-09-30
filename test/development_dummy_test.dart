import 'package:exo_tablet_app_v6/bluetooth.dart';
import 'package:exo_tablet_app_v6/robot_command_service.dart';
import 'package:exo_tablet_app_v6/robot_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('debug fallback emits joint telemetry without Bluetooth hardware',
      () async {
    final bluetooth = BluetoothService();
    final commands = RobotCommandService(bluetooth);
    final firstFrame = bluetooth.telemetryStream.first;

    expect(
      await commands.sendForPart('rElbow', RobotProtocol.arom),
      isTrue,
    );

    final frame = await firstFrame.timeout(const Duration(seconds: 1));
    final joint = frame.jointForPart('rElbow');
    expect(joint, isNotNull);
    expect(joint!.positionDegrees, lessThanOrEqualTo(0));
    expect(
      RobotProtocol.toUiDegrees('rElbow', joint.positionDegrees),
      inInclusiveRange(0, 90),
    );

    expect(await commands.stop(), isTrue);
  });
}
