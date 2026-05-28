import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @homeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Screen'**
  String get homeScreenTitle;

  /// No description provided for @bluetoothConnected.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth: Connected'**
  String get bluetoothConnected;

  /// No description provided for @bluetoothDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get bluetoothDisconnected;

  /// No description provided for @scanDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanDevices;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to: {deviceName}'**
  String connectedTo(Object deviceName);

  /// Bluetooth connection failure message
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(Object error);

  /// No description provided for @discoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered Devices'**
  String get discoveredDevices;

  /// No description provided for @motorPower.
  ///
  /// In en, this message translates to:
  /// **'Motor Power: '**
  String get motorPower;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery: {batteryLevel}%'**
  String battery(Object batteryLevel);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglish;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'KO'**
  String get languageKorean;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter Password'**
  String get enterPassword;

  /// No description provided for @enterPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPasswordInstruction;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @passwordToSave.
  ///
  /// In en, this message translates to:
  /// **'Password to Save'**
  String get passwordToSave;

  /// No description provided for @saveComplete.
  ///
  /// In en, this message translates to:
  /// **'Save Complete'**
  String get saveComplete;

  /// No description provided for @informationSaved.
  ///
  /// In en, this message translates to:
  /// **'Information saved successfully!'**
  String get informationSaved;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height (m)'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weight;

  /// No description provided for @diseasedArm.
  ///
  /// In en, this message translates to:
  /// **'Diseased Arm'**
  String get diseasedArm;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'RIGHT'**
  String get right;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'LEFT'**
  String get left;

  /// No description provided for @armLength.
  ///
  /// In en, this message translates to:
  /// **'Arm Length (cm)'**
  String get armLength;

  /// No description provided for @forearmLength.
  ///
  /// In en, this message translates to:
  /// **'Forearm Length (cm)'**
  String get forearmLength;

  /// No description provided for @saveInformation.
  ///
  /// In en, this message translates to:
  /// **'Save Information'**
  String get saveInformation;

  /// No description provided for @savedInformation.
  ///
  /// In en, this message translates to:
  /// **'Saved Information'**
  String get savedInformation;

  /// No description provided for @modeSelect.
  ///
  /// In en, this message translates to:
  /// **'Mode Select'**
  String get modeSelect;

  /// No description provided for @romMode.
  ///
  /// In en, this message translates to:
  /// **'ROM Mode Select'**
  String get romMode;

  /// No description provided for @bluetoothMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth message sent'**
  String get bluetoothMessageSent;

  /// No description provided for @bluetoothFailed.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth transmission failed'**
  String get bluetoothFailed;

  /// No description provided for @bluetoothError.
  ///
  /// In en, this message translates to:
  /// **'Error sending Bluetooth message'**
  String get bluetoothError;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @selectVelocity.
  ///
  /// In en, this message translates to:
  /// **'Select Velocity'**
  String get selectVelocity;

  /// No description provided for @selectRange.
  ///
  /// In en, this message translates to:
  /// **'Select Range of Motion'**
  String get selectRange;

  /// No description provided for @measuredROM.
  ///
  /// In en, this message translates to:
  /// **'Measured Range of Motion'**
  String get measuredROM;

  /// No description provided for @selectAngle.
  ///
  /// In en, this message translates to:
  /// **'Select Angle'**
  String get selectAngle;

  /// No description provided for @targetAngle.
  ///
  /// In en, this message translates to:
  /// **'Target Angle'**
  String get targetAngle;

  /// No description provided for @currentAngle.
  ///
  /// In en, this message translates to:
  /// **'Current Angle'**
  String get currentAngle;

  /// No description provided for @minAngle.
  ///
  /// In en, this message translates to:
  /// **'Minimum Angle'**
  String get minAngle;

  /// No description provided for @maxAngle.
  ///
  /// In en, this message translates to:
  /// **'Maximum Angle'**
  String get maxAngle;

  /// No description provided for @currentTorque.
  ///
  /// In en, this message translates to:
  /// **'Current Torque'**
  String get currentTorque;

  /// No description provided for @minTorque.
  ///
  /// In en, this message translates to:
  /// **'Minimum Torque'**
  String get minTorque;

  /// No description provided for @maxTorque.
  ///
  /// In en, this message translates to:
  /// **'Maximum Torque'**
  String get maxTorque;

  /// No description provided for @receivedAngle.
  ///
  /// In en, this message translates to:
  /// **'Received Angle'**
  String get receivedAngle;

  /// No description provided for @waitMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the measurement'**
  String get waitMeasurement;

  /// No description provided for @savedROM.
  ///
  /// In en, this message translates to:
  /// **'Saved Measured ROM'**
  String get savedROM;

  /// No description provided for @noMeasuredAngle.
  ///
  /// In en, this message translates to:
  /// **'No angle measurement'**
  String get noMeasuredAngle;

  /// No description provided for @selectResistance.
  ///
  /// In en, this message translates to:
  /// **'Select Resistance'**
  String get selectResistance;

  /// No description provided for @enterRangeAndResistance.
  ///
  /// In en, this message translates to:
  /// **'Select ROM and Resistance'**
  String get enterRangeAndResistance;

  /// No description provided for @selectHoldDuration.
  ///
  /// In en, this message translates to:
  /// **'Select Hold Duration'**
  String get selectHoldDuration;

  /// No description provided for @enterAngleAndDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter Angle and Duration'**
  String get enterAngleAndDuration;

  /// No description provided for @enterRangeAndVelocity.
  ///
  /// In en, this message translates to:
  /// **'Enter ROM and Velocity'**
  String get enterRangeAndVelocity;

  /// No description provided for @selectMode.
  ///
  /// In en, this message translates to:
  /// **'Select Mode'**
  String get selectMode;

  /// No description provided for @originalVelocity.
  ///
  /// In en, this message translates to:
  /// **'2 Steps for 10s'**
  String get originalVelocity;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @sit.
  ///
  /// In en, this message translates to:
  /// **'Sit'**
  String get sit;

  /// No description provided for @stand.
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get stand;

  /// No description provided for @walk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walk;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @passiverom.
  ///
  /// In en, this message translates to:
  /// **'Passive ROM'**
  String get passiverom;

  /// No description provided for @activerom.
  ///
  /// In en, this message translates to:
  /// **'Active ROM'**
  String get activerom;

  /// No description provided for @cpm.
  ///
  /// In en, this message translates to:
  /// **'CPM'**
  String get cpm;

  /// No description provided for @isometric.
  ///
  /// In en, this message translates to:
  /// **'Isometric'**
  String get isometric;

  /// No description provided for @isotonic.
  ///
  /// In en, this message translates to:
  /// **'Isotonic'**
  String get isotonic;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @controlScreen.
  ///
  /// In en, this message translates to:
  /// **'Control Screen'**
  String get controlScreen;

  /// No description provided for @controlMode.
  ///
  /// In en, this message translates to:
  /// **'Control Mode'**
  String get controlMode;

  /// No description provided for @saveGains.
  ///
  /// In en, this message translates to:
  /// **'Save Gains'**
  String get saveGains;

  /// No description provided for @gcOn.
  ///
  /// In en, this message translates to:
  /// **'GC On'**
  String get gcOn;

  /// No description provided for @gcOff.
  ///
  /// In en, this message translates to:
  /// **'GC Off'**
  String get gcOff;

  /// No description provided for @controlGainsSent.
  ///
  /// In en, this message translates to:
  /// **'Control gains sent successfully'**
  String get controlGainsSent;

  /// No description provided for @transmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transmission failed'**
  String get transmissionFailed;

  /// No description provided for @failedToSendGains.
  ///
  /// In en, this message translates to:
  /// **'Failed to send control gains'**
  String get failedToSendGains;

  /// No description provided for @pdControl.
  ///
  /// In en, this message translates to:
  /// **'PD control'**
  String get pdControl;

  /// No description provided for @gravityCompensator.
  ///
  /// In en, this message translates to:
  /// **'Gravity Compensator'**
  String get gravityCompensator;

  /// No description provided for @gravityCompensatorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Gravity Compensator Enabled'**
  String get gravityCompensatorEnabled;

  /// No description provided for @gravityCompensatorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Gravity Compensator Disabled'**
  String get gravityCompensatorDisabled;

  /// No description provided for @fileUploadSend.
  ///
  /// In en, this message translates to:
  /// **'File Upload & Send'**
  String get fileUploadSend;

  /// No description provided for @uploadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get uploadedFiles;

  /// No description provided for @uploadCSV.
  ///
  /// In en, this message translates to:
  /// **'Upload CSV'**
  String get uploadCSV;

  /// No description provided for @sendFileViaBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Send file via Bluetooth'**
  String get sendFileViaBluetooth;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'upload'**
  String get upload;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get sendFile;

  /// No description provided for @sendFiles.
  ///
  /// In en, this message translates to:
  /// **'Send Files'**
  String get sendFiles;

  /// No description provided for @fileSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'File sent successfully'**
  String get fileSentSuccess;

  /// No description provided for @fileSentFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send file.'**
  String get fileSentFail;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get loading;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @control.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get control;

  /// No description provided for @fileUpload.
  ///
  /// In en, this message translates to:
  /// **'File Upload'**
  String get fileUpload;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @selectPart.
  ///
  /// In en, this message translates to:
  /// **'Select Part'**
  String get selectPart;

  /// No description provided for @lShoulderEF.
  ///
  /// In en, this message translates to:
  /// **'Left Shoulder Ext/Flx'**
  String get lShoulderEF;

  /// No description provided for @lShoulderRo.
  ///
  /// In en, this message translates to:
  /// **'Left Shoulder Int/Ext Rotation'**
  String get lShoulderRo;

  /// No description provided for @lElbow.
  ///
  /// In en, this message translates to:
  /// **'Left Elbow Ext/Flx'**
  String get lElbow;

  /// No description provided for @lWrist.
  ///
  /// In en, this message translates to:
  /// **'Left Wrist Ext/Flx'**
  String get lWrist;

  /// No description provided for @userInfoEntry.
  ///
  /// In en, this message translates to:
  /// **'User Information Entry'**
  String get userInfoEntry;

  /// No description provided for @loadUser.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get loadUser;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @currentUser.
  ///
  /// In en, this message translates to:
  /// **'Currnet User'**
  String get currentUser;

  /// No description provided for @userList.
  ///
  /// In en, this message translates to:
  /// **'User List'**
  String get userList;

  /// No description provided for @noUserList.
  ///
  /// In en, this message translates to:
  /// **'There are no saved users.'**
  String get noUserList;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @deleteUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the user from the list?'**
  String get deleteUserConfirm;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted.'**
  String get deleted;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @loadUserInfo.
  ///
  /// In en, this message translates to:
  /// **'Load Information'**
  String get loadUserInfo;

  /// No description provided for @enterPwd.
  ///
  /// In en, this message translates to:
  /// **'Enter Password'**
  String get enterPwd;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
