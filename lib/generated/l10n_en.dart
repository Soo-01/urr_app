// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeScreenTitle => 'Home Screen';

  @override
  String get bluetoothConnected => 'Bluetooth: Connected';

  @override
  String get bluetoothDisconnected => 'Disconnected';

  @override
  String get scanDevices => 'Scan for Devices';

  @override
  String connectedTo(Object deviceName) {
    return 'Connected to: $deviceName';
  }

  @override
  String connectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get discoveredDevices => 'Discovered Devices';

  @override
  String get motorPower => 'Motor Power: ';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String battery(Object batteryLevel) {
    return 'Battery: $batteryLevel%';
  }

  @override
  String get languageEnglish => 'EN';

  @override
  String get languageKorean => 'KO';

  @override
  String get enterPassword => 'Enter Password';

  @override
  String get enterPasswordInstruction => 'Enter your password';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String get passwordHint => 'Password';

  @override
  String get passwordToSave => 'Password to Save';

  @override
  String get saveComplete => 'Save Complete';

  @override
  String get informationSaved => 'Information saved successfully!';

  @override
  String get profile => 'Profile';

  @override
  String get name => 'Name';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get other => 'Other';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height (m)';

  @override
  String get weight => 'Weight (kg)';

  @override
  String get diseasedArm => 'Diseased Arm';

  @override
  String get right => 'RIGHT';

  @override
  String get left => 'LEFT';

  @override
  String get armLength => 'Arm Length (cm)';

  @override
  String get forearmLength => 'Forearm Length (cm)';

  @override
  String get saveInformation => 'Save Information';

  @override
  String get savedInformation => 'Saved Information';

  @override
  String get modeSelect => 'Mode Select';

  @override
  String get romMode => 'ROM Mode Select';

  @override
  String get bluetoothMessageSent => 'Bluetooth message sent';

  @override
  String get bluetoothFailed => 'Bluetooth transmission failed';

  @override
  String get bluetoothError => 'Error sending Bluetooth message';

  @override
  String get mode => 'Mode';

  @override
  String get selectVelocity => 'Select Velocity';

  @override
  String get selectRange => 'Select Range of Motion';

  @override
  String get measuredROM => 'Measured Range of Motion';

  @override
  String get selectAngle => 'Select Angle';

  @override
  String get targetAngle => 'Target Angle';

  @override
  String get currentAngle => 'Current Angle';

  @override
  String get minAngle => 'Minimum Angle';

  @override
  String get maxAngle => 'Maximum Angle';

  @override
  String get currentTorque => 'Current Torque';

  @override
  String get minTorque => 'Minimum Torque';

  @override
  String get maxTorque => 'Maximum Torque';

  @override
  String get receivedAngle => 'Received Angle';

  @override
  String get waitMeasurement => 'Waiting for the measurement';

  @override
  String get savedROM => 'Saved Measured ROM';

  @override
  String get noMeasuredAngle => 'No angle measurement';

  @override
  String get selectResistance => 'Select Resistance';

  @override
  String get enterRangeAndResistance => 'Select ROM and Resistance';

  @override
  String get selectHoldDuration => 'Select Hold Duration';

  @override
  String get enterAngleAndDuration => 'Enter Angle and Duration';

  @override
  String get enterRangeAndVelocity => 'Enter ROM and Velocity';

  @override
  String get selectMode => 'Select Mode';

  @override
  String get originalVelocity => '2 Steps for 10s';

  @override
  String get save => 'Save';

  @override
  String get receive => 'Receive';

  @override
  String get start => 'Start';

  @override
  String get sit => 'Sit';

  @override
  String get stand => 'Stand';

  @override
  String get walk => 'Walk';

  @override
  String get direction => 'Direction';

  @override
  String get passiverom => 'Passive ROM';

  @override
  String get activerom => 'Active ROM';

  @override
  String get cpm => 'CPM';

  @override
  String get isometric => 'Isometric';

  @override
  String get isotonic => 'Isotonic';

  @override
  String get stop => 'Stop';

  @override
  String get controlScreen => 'Control Screen';

  @override
  String get controlMode => 'Control Mode';

  @override
  String get saveGains => 'Save Gains';

  @override
  String get gcOn => 'GC On';

  @override
  String get gcOff => 'GC Off';

  @override
  String get controlGainsSent => 'Control gains sent successfully';

  @override
  String get transmissionFailed => 'Transmission failed';

  @override
  String get failedToSendGains => 'Failed to send control gains';

  @override
  String get pdControl => 'PD control';

  @override
  String get gravityCompensator => 'Gravity Compensator';

  @override
  String get gravityCompensatorEnabled => 'Gravity Compensator Enabled';

  @override
  String get gravityCompensatorDisabled => 'Gravity Compensator Disabled';

  @override
  String get fileUploadSend => 'File Upload & Send';

  @override
  String get uploadedFiles => 'Uploaded Files';

  @override
  String get uploadCSV => 'Upload CSV';

  @override
  String get sendFileViaBluetooth => 'Send file via Bluetooth';

  @override
  String get selected => 'Selected';

  @override
  String get upload => 'upload';

  @override
  String get sendFile => 'Send File';

  @override
  String get sendFiles => 'Send Files';

  @override
  String get fileSentSuccess => 'File sent successfully';

  @override
  String get fileSentFail => 'Failed to send file.';

  @override
  String get loading => 'Sending...';

  @override
  String get reset => 'Reset';

  @override
  String get home => 'Home';

  @override
  String get control => 'Control';

  @override
  String get fileUpload => 'File Upload';

  @override
  String get history => 'History';

  @override
  String get information => 'Information';

  @override
  String get selectPart => 'Select Part';

  @override
  String get lShoulderEF => 'Left Shoulder Ext/Flx';

  @override
  String get lShoulderRo => 'Left Shoulder Int/Ext Rotation';

  @override
  String get lElbow => 'Left Elbow Ext/Flx';

  @override
  String get lWrist => 'Left Wrist Ext/Flx';

  @override
  String get userInfoEntry => 'User Information Entry';

  @override
  String get loadUser => 'Load';

  @override
  String get close => 'Close';

  @override
  String get currentUser => 'Currnet User';

  @override
  String get userList => 'User List';

  @override
  String get noUserList => 'There are no saved users.';

  @override
  String get deleteUser => 'Delete User';

  @override
  String get deleteUserConfirm =>
      'Are you sure you want to delete the user from the list?';

  @override
  String get deleted => 'Deleted.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get loadUserInfo => 'Load Information';

  @override
  String get enterPwd => 'Enter Password';

  @override
  String get game => 'Game';

  @override
  String get skyGardener => 'Sky Gardener';

  @override
  String get skyGardenerDesc => 'Sky Gardener Description';

  @override
  String get cloudPainter => 'Cloud Painter';

  @override
  String get cloudPainterDesc => 'Cloud Painter Description';

  @override
  String get shieldGuard => 'Shield Guard';

  @override
  String get shieldGuardDesc => 'Shield Guard Description';

  @override
  String get safeCracker => 'Safe Cracker';

  @override
  String get safeCrackerDesc => 'Safe Cracker Description';

  @override
  String get targetReaching => 'Target Reaching';

  @override
  String get targetReachingDesc => 'Target Reaching Description';

  @override
  String get swimming => 'Swimming';

  @override
  String get swimmingDesc => 'Swimming Description';

  @override
  String get balloonPop => 'Balloon Pop';

  @override
  String get balloonPopDesc => 'Balloon Pop Description';

  @override
  String get carpenter => 'Carpenter';

  @override
  String get carpenterDesc => 'Carpenter Description';

  @override
  String get potionMaker => 'Potion Maker';

  @override
  String get potionMakerDesc => 'Potion Maker Description';

  @override
  String get mealHelper => 'Meal Helper';

  @override
  String get mealHelperDesc => 'Meal Helper Description';

  @override
  String get trackingGame => 'Tracking Game';

  @override
  String get trackingGameDesc => 'Tracking Game Description';

  @override
  String get bowling => 'Bowling';

  @override
  String get bowlingDesc => 'Bowling Description';

  @override
  String get rehabGames => 'Rehab Games';

  @override
  String get categoryShoulder => 'Shoulder';

  @override
  String get categoryElbow => 'Elbow';

  @override
  String get categoryCombined => 'Combined';

  @override
  String get startGame => 'Start Game';

  @override
  String get brunnstromStage => 'Brunnstrom Stage';

  @override
  String get cognitiveLevel => 'Cognitive Level';

  @override
  String get neglectSide => 'Neglect Side';

  @override
  String get neglectNone => 'None';

  @override
  String get neglectLeft => 'Left';

  @override
  String get neglectRight => 'Right';

  @override
  String get selectDifficulty => 'Select Difficulty';

  @override
  String get gameDuration => 'Game Duration';

  @override
  String seconds(int count) {
    return '${count}s';
  }

  @override
  String get pauseGame => 'Pause Game';

  @override
  String get sessionResult => 'Session Result';

  @override
  String get gameOver => 'Game Over';

  @override
  String get finalScore => 'Final Score';

  @override
  String get gameAccuracy => 'Accuracy';

  @override
  String get hits => 'Hits';

  @override
  String get misses => 'Misses';

  @override
  String get sessionDuration => 'Duration';

  @override
  String get difficultyLevel => 'Difficulty';

  @override
  String get backToHub => 'Back to Hub';

  @override
  String get playAgain => 'Play Again';
}
