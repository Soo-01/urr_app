# EXO Tablet App v2 — Jetson ROS 2 연동

이 문서는 Flutter 태블릿 앱과 Jetson의 `motor_control_v5_2.cpp` 사이의 명령 및 상태 데이터 연동 규격을 설명한다. 기존 `README.md`는 변경하지 않는다.

## 중요: Bluetooth–ROS 2 브리지 필요

`motor_control_v5_2.cpp`는 Bluetooth를 직접 읽지 않는다. 이 노드는 ROS 2의 `/tablet_cmd` 토픽을 구독하고 `/robot/joint_states` 토픽을 발행한다. 따라서 아래 역할을 수행하는 Jetson 측 브리지 프로세스가 반드시 실행 중이어야 한다.

```text
Flutter 앱
  ├─ Bluetooth 송신: PART:rElbow\n, cpm,10,90,0.05\n 등
  └─ Bluetooth 수신: {"arm":"RIGHT","state":[...]}\n
          ↕ Bluetooth Classic RFCOMM

Jetson Bluetooth–ROS 2 브리지
  ├─ Bluetooth 명령 한 줄 → /tablet_cmd std_msgs/msg/String 발행
  └─ /robot/joint_states 구독 → JSON 한 줄을 Bluetooth로 송신

          ↕ ROS 2

motor_control_v5_2.cpp (수정 없음)
```

앱 코드만 수정해서는 ROS 2 토픽을 직접 생성할 수 없다. 앱에서 보낸 Bluetooth 문자열을 ROS 2 토픽으로 변환하는 브리지가 없으면 앱 터미널에는 송신 로그가 남더라도 `motor_control_v5_2.cpp`의 `cmdCallback()`에는 도달하지 않는다.

## 부위 선택 목록과 현재 지원 하드웨어

앱의 부위 선택 목록은 기존 구성을 유지한다.

```text
lShoulderEF, lShoulderRo, lElbow, lWrist
rShoulderEF, rShoulderRo, rElbow, rWrist
```

단, 현재 `motor_control_v5_2.cpp`가 실제로 수락하고 제어하는 관절은 다음 세 개뿐이다.

| 코드 | 관절 | Jetson joint id |
|---|---|---:|
| `rShoulderEF` | 오른쪽 어깨 굴곡/신전 | 0 |
| `rShoulderRo` | 오른쪽 어깨 회전 | 1 |
| `rElbow` | 오른쪽 팔꿈치 | 2 |

왼팔과 `rWrist`도 앱에서 선택하고 Bluetooth로 `PART:` 명령을 보낼 수 있지만, 현재 Jetson 제어 코드는 해당 명령을 `Unsupported PART`로 거부한다. 이 목록은 향후 왼팔과 손목 하드웨어를 연결할 때 UI를 다시 복구할 필요가 없도록 유지한다. 현재 모터 시험에서는 `rShoulderEF`, `rShoulderRo`, `rElbow`만 사용해야 한다.

## 앱 → Jetson 명령 규격

모든 Bluetooth 명령은 UTF-8 문자열이며 마지막에 줄바꿈 `\n`을 붙인다. Jetson 브리지는 줄바꿈을 제거한 문자열을 `/tablet_cmd`의 `data` 필드로 발행해야 한다.

| 기능 | 앱이 보내는 문자열 | 동일한 ROS 2 data |
|---|---|---|
| 관절 선택 | `PART:rShoulderEF\n` | `PART:rShoulderEF` |
| AROM 시작 | `arom\n` | `arom` |
| PROM 시작 | `prom[,speed_rad_s]\n` | `prom[,speed_rad_s]` |
| PROM 방향 전환 | `dir\n` | `dir` |
| CPM 시작 | `cpm,min_deg,max_deg[,speed_rad_s]\n` | `cpm,min_deg,max_deg[,speed_rad_s]` |
| Isometric 시작 | `isometric,target_deg,hold_sec\n` | `isometric,target_deg,hold_sec` |
| Isotonic 시작 | `isotonic,target_deg,resistance_kg\n` | `isotonic,target_deg,resistance_kg` |
| 현재 위치 정지/고정 | `stop\n` | `stop` |

예를 들어 앱에서 오른쪽 팔꿈치 CPM 10~90도, 속도 레벨 5를 시작하면 다음 두 줄을 순서대로 보낸다.

```text
PART:rElbow
cpm,10,90,0.05
```

이는 다음 ROS 2 명령과 같은 역할을 한다.

```bash
ros2 topic pub --once /tablet_cmd std_msgs/msg/String "{data: 'PART:rElbow'}"
ros2 topic pub --once /tablet_cmd std_msgs/msg/String "{data: 'cpm,10,90,0.05'}"
```

### 속도 레벨

UI의 속도 레벨 1~10은 안전한 초기 통합을 위해 다음과 같이 변환한다.

```text
1 → 0.01 rad/s
5 → 0.05 rad/s
10 → 0.10 rad/s
```

## Jetson → 앱 상태 규격

Jetson 브리지는 `/robot/joint_states`의 `std_msgs/msg/String.data` JSON 뒤에 `\n`을 붙여 앱으로 전달해야 한다.

```json
{
  "arm": "RIGHT",
  "state": [
    {
      "id": 0,
      "online": 1,
      "pos": 1.5707963268,
      "vel": 0.5,
      "tau_cmd": 1.2,
      "tau_meas": 1.1
    }
  ]
}
```

앱의 처리 단위는 다음과 같다.

| 필드 | 수신 단위 | UI 표시 |
|---|---|---|
| `pos` | rad | degree로 변환 |
| `vel` | rad/s | degree/s로 변환 가능 |
| `tau_cmd` | Nm | Nm |
| `tau_meas` | Nm | Nm |
| `online` | 0 또는 1 | 오프라인/온라인 |

ROM 화면은 선택 관절의 위치를 degree로 변환해 현재·최소·최대 각도를 갱신한다. CPM 화면도 선택 관절 각도를 표시하며 Isometric 화면은 `tau_meas`를 현재·최소·최대 토크로 표시한다.

## 주요 구현 파일

- `lib/robot_protocol.dart`: 공식 명령 생성, 입력 검증, 상태 JSON 파싱, rad→degree 변환
- `lib/robot_command_service.dart`: 줄바꿈 프레이밍, Bluetooth 연결 확인, PART→모드 순차 송신
- `lib/bluetooth.dart`: 원시 문자열 스트림과 타입이 지정된 telemetry 스트림 제공
- `lib/rommode.dart`: PART, AROM, PROM, 방향 전환, 정지 및 관절 각도 표시
- `lib/mode.dart`: CPM, Isometric, Isotonic, 정지 및 각도/토크 표시
- `lib/games/game_motor_controller.dart`: 게임 명령을 Jetson 문법에 맞게 송신
- `test/robot_protocol_test.dart`: 명령 문법과 JSON/단위 변환 테스트

## UI 동작 순서

운동 시작 시 앱은 이전에 Jetson에 남아 있던 선택 관절이 사용되는 것을 막기 위해 다음 순서로 송신한다.

1. Bluetooth 연결 여부 확인
2. 현재 선택된 `PART:` 명령 송신
3. 100ms 대기
4. 모드 및 세부 설정 명령 송신
5. 두 송신이 성공한 경우에만 UI를 측정/운동 중 상태로 변경

Bluetooth가 연결되지 않았거나 PART 전송이 실패하면 안전상 모드 명령을 실제 전송하지 않는다. 대신 Flutter 터미널에는 실행하려던 명령을 다음처럼 남긴다.

```text
[ROBOT TX] skipped (Bluetooth disconnected): PART:rShoulderEF
[ROBOT TX] skipped (PART failed): arom
```

Bluetooth 연결이 정상일 때만 다음처럼 두 명령 모두 `sent`로 표시된다.

```text
[ROBOT TX] sent: PART:rShoulderEF
[ROBOT TX] sent: arom
```

현재 `sendBytes()`의 성공은 Android Bluetooth 출력 버퍼에 전달됐다는 의미다. Jetson 제어 코드가 명령을 최종 수락했다는 ACK는 아니다. C++를 수정하지 않는 조건에서는 명령 거부 여부를 앱이 직접 확인할 수 없으므로 Jetson 로그도 함께 확인해야 한다.

## Jetson 브리지 확인 항목

앱과 실제 연결하기 전에 Jetson에서 다음을 확인한다.

```bash
ros2 topic echo /tablet_cmd
ros2 topic echo /robot/joint_states
```

앱에서 관절을 선택했을 때 `/tablet_cmd`에 `PART:...`가 나타나야 한다. 시작 버튼을 눌렀을 때 이어서 모드 명령이 나타나야 한다. `/robot/joint_states`가 발행되고 있어도 브리지가 Bluetooth로 다시 보내지 않으면 앱 UI에는 각도와 토크가 표시되지 않는다.

## 안전상 주의

- 실제 환자 또는 부하를 연결하기 전에 무부하·저속으로 시험한다.
- Stop 버튼은 항상 `stop`을 송신한다.
- Bluetooth 연결이 이미 끊어진 경우 앱의 Stop 명령은 Jetson에 도달하지 않는다.
- 앱 연결 끊김 시 자동 정지가 필요하면 Jetson 브리지 또는 별도 안전 노드에서 연결 timeout을 감지해 `/tablet_cmd`에 `stop`을 발행해야 한다.
- CPM 입력은 반드시 `min < max`여야 한다.
- UI의 각도는 degree, Jetson 상태의 원본 위치는 rad이므로 단위 변환을 제거하면 안 된다.

## 측정 기록의 현재 상태

기록 화면 제작을 위해 사용했던 ROM 더미값 `10.5° ~ 135.0°` 저장 함수와 호출은 전체 주석 처리되어 있다. `record.dart` import도 비활성화되어 있으므로 ROM 화면에서 저장 버튼을 눌러도 해당 더미 범위가 `SharedPreferences`, `RecordManager`, `UserProvider` 중 어디에도 저장되지 않으며 Flutter 터미널에도 출력되지 않는다. 실제 telemetry의 최소·최대 각도를 저장하는 정책이 확정되면 `_saveAngleData()`를 실제 측정값 기반으로 새로 정리한 뒤 다시 연결해야 한다.

기록 탭의 각 기록 카드 우측 상단에는 작은 휴지통 버튼이 표시된다. 버튼을 누르고 삭제 확인 창에서 삭제를 선택하면 해당 기록이 `SharedPreferences`의 `user_accumulated_records`에서 영구 삭제되고 목록이 즉시 갱신된다. 동일 사용자의 다른 기록은 유지된다.

## 변경 기록 관리 규칙

앞으로 이 저장소의 동작 코드를 수정할 때는 같은 변경에서 반드시 다음 문서도 갱신한다.

1. 동작, 프로토콜, 설치 또는 사용법이 바뀌면 `README_v2.md`를 수정한다.
2. 모든 코드 변경은 `CHANGELOG.md`의 최신 날짜 아래에 추가한다.
3. 기존 `README.md`는 별도 요청이 없는 한 유지한다.
4. 명령 문자열을 변경하면 `robot_protocol_test.dart` 테스트도 함께 변경한다.
