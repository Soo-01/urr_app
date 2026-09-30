# Changelog

이 파일에는 EXO Tablet App v2의 코드 변경 사항을 기록한다. 날짜는 Asia/Seoul 기준으로 작성한다.

## 2026-07-18

### Fixed

- ROM 저장 버튼에서 임시 더미 범위 `10.5° ~ 135.0°`를 기록하던 `_saveAngleData()` 함수와 호출 전체를 주석 처리해 `SharedPreferences`, `RecordManager`, `UserProvider`에 실제로 저장되지 않도록 했다.
- Bluetooth 미연결 또는 PART 송신 실패 시 후속 모드 명령이 보이지 않던 문제를 수정했다. 안전상 실제 모드 명령은 보내지 않지만 `[ROBOT TX] skipped (PART failed): arom`과 같이 예정된 명령을 Flutter 터미널에 기록한다.
- ROM 및 운동 화면에서 제거됐던 왼팔/오른팔 어깨 굴곡신전, 어깨 회전, 팔꿈치, 손목의 전체 8개 부위 선택 항목을 복원했다.
- 왼팔과 손목 telemetry도 향후 사용할 수 있도록 arm과 joint id 매핑을 추가했다.

### Added

- 기록 카드 우측 상단에 작은 휴지통 버튼과 삭제 확인 창을 추가했다.
- `RecordManager.loadRecords()`와 `RecordManager.deleteRecord()`를 추가해 기록 조회와 개별 영구 삭제를 한 곳에서 처리하도록 했다.
- 선택한 기록만 영구 삭제되는지 검증하는 `record_manager_test.dart`를 추가했다.
- `RobotProtocol`을 추가해 `motor_control_v5_2.cpp`와 동일한 명령 문자열을 한 곳에서 생성하도록 구성했다.
- `RobotCommandService`를 추가해 Bluetooth 연결 검사, 줄바꿈 프레이밍, PART→모드 순차 송신을 구현했다.
- `/robot/joint_states` JSON을 파싱하는 `RobotTelemetryFrame`과 `JointTelemetry` 모델을 추가했다.
- Bluetooth 서비스에 타입이 지정된 `telemetryStream`을 추가했다.
- 명령 문법, 유효성 검사, JSON 파싱 및 rad→degree 변환 단위 테스트를 추가했다.
- Bluetooth–ROS 2 브리지 요구사항과 사용법을 설명하는 `README_v2.md`를 추가했다.

### Changed

- ROM 화면의 PART 선택을 디버그 출력에서 실제 Bluetooth 송신으로 변경했다.
- 운동 화면의 PART 선택을 디버그 출력에서 실제 Bluetooth 송신으로 변경했다.
- AROM 종료 명령을 재차 `arom`을 보내는 토글 방식에서 명시적인 `stop`으로 변경했다.
- PROM 속도 레벨 1~10을 0.01~0.10 rad/s로 변환해 `prom,<speed>`로 전달하도록 변경했다.
- CPM 명령 인자 순서를 `cpm,min,max,speed`로 수정했다.
- Isotonic UI를 최소/최대 범위 입력에서 목표각/저항 입력으로 변경하고 `isotonic,target,resistance`를 보내도록 수정했다.
- Stop 동작을 `stop` 명령으로 통일했다.
- ROM 및 운동 화면이 JSON telemetry에서 선택 관절만 필터링하도록 변경했다.
- 관절 위치를 rad에서 degree로 변환해 UI에 표시하도록 변경했다.
- Isometric 토크 표시 단위를 degree 기호에서 `Nm`로 수정했다.
- 게임의 기본 관절 코드를 현재 지원되는 오른팔 관절로 변경했다.
- 게임 CPM 명령을 `min,max,speed` 순서와 0.01~0.10 rad/s 범위로 맞췄다.
- 게임 Isotonic 명령에 목표각과 저항을 모두 포함하도록 변경했다.

### Not changed

- Jetson의 `motor_control_v5_2.cpp`는 수정하지 않았다.
- 기존 `README.md`는 수정하지 않았다.

### Known limitations

- Jetson에서 Bluetooth 문자열과 ROS 2 토픽을 변환하는 별도 브리지 노드가 없으면 앱 명령은 `/tablet_cmd`에 도달하지 않는다.
- 현재 C++ 인터페이스는 명령 ACK 토픽을 제공하지 않으므로 앱은 Bluetooth 송신 성공과 Jetson 명령 수락을 구분할 수 없다.
- Bluetooth 연결이 끊어진 뒤에는 앱에서 보낸 Stop 명령이 Jetson에 도달할 수 없다.
