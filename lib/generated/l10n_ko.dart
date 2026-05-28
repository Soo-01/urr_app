// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get homeScreenTitle => '홈 화면';

  @override
  String get bluetoothConnected => '블루투스: 연결됨';

  @override
  String get bluetoothDisconnected => '연결되지 않음';

  @override
  String get scanDevices => '기기 검색';

  @override
  String connectedTo(Object deviceName) {
    return '연결된 장치: $deviceName';
  }

  @override
  String connectionFailed(Object error) {
    return '연결 실패: $error';
  }

  @override
  String get discoveredDevices => '검색된 장치';

  @override
  String get motorPower => '모터 전원: ';

  @override
  String get on => '켜짐';

  @override
  String get off => '꺼짐';

  @override
  String battery(Object batteryLevel) {
    return '배터리: $batteryLevel%';
  }

  @override
  String get languageEnglish => '영어';

  @override
  String get languageKorean => '한국어';

  @override
  String get enterPassword => '비밀번호 입력';

  @override
  String get enterPasswordInstruction => '비밀번호를 입력하세요';

  @override
  String get incorrectPassword => '비밀번호가 틀렸습니다';

  @override
  String get passwordHint => '비밀번호';

  @override
  String get passwordToSave => '저장할 비밀번호를 입력하세요';

  @override
  String get saveComplete => '저장 완료';

  @override
  String get informationSaved => '정보가 성공적으로 저장되었습니다!';

  @override
  String get profile => '프로필';

  @override
  String get name => '이름';

  @override
  String get gender => '성별';

  @override
  String get male => '남성';

  @override
  String get female => '여성';

  @override
  String get other => '기타';

  @override
  String get age => '나이';

  @override
  String get height => '키 (m)';

  @override
  String get weight => '몸무게 (kg)';

  @override
  String get diseasedArm => '질병이 있는 팔';

  @override
  String get right => '오른쪽';

  @override
  String get left => '왼쪽';

  @override
  String get armLength => '팔 길이 (cm)';

  @override
  String get forearmLength => '전완 길이 (cm)';

  @override
  String get saveInformation => '정보 저장';

  @override
  String get savedInformation => '저장된 정보';

  @override
  String get modeSelect => '모드 선택';

  @override
  String get romMode => '측정 모드 선택';

  @override
  String get bluetoothMessageSent => '블루투스 메시지 전송됨';

  @override
  String get bluetoothFailed => '블루투스 전송 실패';

  @override
  String get bluetoothError => '블루투스 메시지 전송 오류';

  @override
  String get mode => '모드';

  @override
  String get selectVelocity => '속도를 선택하세요';

  @override
  String get selectRange => '가동 범위를 선택하세요';

  @override
  String get measuredROM => '측정된 가동 범위';

  @override
  String get selectAngle => '각도를 선택하세요';

  @override
  String get targetAngle => '목표 각도';

  @override
  String get currentAngle => '현재 각도';

  @override
  String get minAngle => '최소 각도';

  @override
  String get maxAngle => '최대 각도';

  @override
  String get currentTorque => '현재 토크';

  @override
  String get minTorque => '최소 토크';

  @override
  String get maxTorque => '최대 토크';

  @override
  String get receivedAngle => '받은 각도';

  @override
  String get waitMeasurement => '측정 대기 중입니다';

  @override
  String get savedROM => '측정된 가동 범위가 저장되었습니다';

  @override
  String get noMeasuredAngle => '각도 측정값이 없습니다';

  @override
  String get selectResistance => '저항력을 선택하세요';

  @override
  String get enterRangeAndResistance => '각도 범위와 저항력을 선택하세요';

  @override
  String get selectHoldDuration => '지속 시간을 선택하세요';

  @override
  String get enterAngleAndDuration => '각도와 지속 시간을 입력하세요';

  @override
  String get enterRangeAndVelocity => '각도 범위와 속도를 입력하세요';

  @override
  String get selectMode => '모드를 선택해주세요';

  @override
  String get originalVelocity => '10초동안 2 걸음';

  @override
  String get save => '저장';

  @override
  String get receive => '수신';

  @override
  String get start => '시작';

  @override
  String get sit => '앉기';

  @override
  String get stand => '서기';

  @override
  String get walk => '걷기';

  @override
  String get direction => '방향';

  @override
  String get passiverom => '수동 가동 범위';

  @override
  String get activerom => '능동 가동 범위';

  @override
  String get cpm => '수동 운동';

  @override
  String get isometric => '등척성 운동';

  @override
  String get isotonic => '등장성 운동';

  @override
  String get stop => '정지';

  @override
  String get controlScreen => '제어 화면';

  @override
  String get controlMode => '제어 모드';

  @override
  String get saveGains => '게인 저장';

  @override
  String get gcOn => '중력 보상 켜짐';

  @override
  String get gcOff => '중력 보상 꺼짐';

  @override
  String get controlGainsSent => '제어 게인이 성공적으로 전송되었습니다';

  @override
  String get transmissionFailed => '전송 실패';

  @override
  String get failedToSendGains => '제어 게인 전송에 실패했습니다';

  @override
  String get pdControl => 'PD 제어';

  @override
  String get gravityCompensator => '중력 보상기';

  @override
  String get gravityCompensatorEnabled => '중력 보상 장치 활성화됨';

  @override
  String get gravityCompensatorDisabled => '중력 보상 장치 비활성화됨';

  @override
  String get fileUploadSend => '파일 업로드 및 전송';

  @override
  String get uploadedFiles => '업로드된 파일';

  @override
  String get uploadCSV => 'CSV 업로드';

  @override
  String get sendFileViaBluetooth => '블루투스로 파일 전송';

  @override
  String get selected => '선택됨';

  @override
  String get upload => '업로드';

  @override
  String get sendFile => '파일 전송';

  @override
  String get sendFiles => '파일 전송';

  @override
  String get fileSentSuccess => '파일 전송 완료';

  @override
  String get fileSentFail => '파일 전송 실패';

  @override
  String get loading => '전송중...';

  @override
  String get reset => '초기화';

  @override
  String get home => '홈';

  @override
  String get control => '제어';

  @override
  String get fileUpload => '파일 업로드';

  @override
  String get history => '기록';

  @override
  String get information => '정보';

  @override
  String get selectPart => '관절 선택';

  @override
  String get lShoulderEF => '왼쪽 어깨 굴곡/신전';

  @override
  String get lShoulderRo => '왼쪽 어깨 내회전/외회전';

  @override
  String get lElbow => '왼쪽 팔꿈치 굴곡/신전';

  @override
  String get lWrist => '왼쪽 손목 굴곡/신전';

  @override
  String get userInfoEntry => '사용자 정보 입력';

  @override
  String get loadUser => '불러오기';

  @override
  String get close => '닫기';

  @override
  String get currentUser => '현재 사용자';

  @override
  String get userList => '사용자 목록';

  @override
  String get noUserList => '저장된 사용자가 없습니다.';

  @override
  String get deleteUser => '사용자 삭제';

  @override
  String get deleteUserConfirm => '사용자를 목록에서 삭제하시겠습니까?';

  @override
  String get deleted => '삭제되었습니다.';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get loadUserInfo => '정보 불러오기';

  @override
  String get enterPwd => '비밀번호 입력';
}
