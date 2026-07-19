# 게임 시스템 추가 내역 — 앱 담당자 인수인계

**작성일**: 2026-05-28  
**대상**: 기존 앱 원작성자 (게임 추가 전 전체 앱 제작자)  
**목적**: 게임 시스템 추가로 인한 변경 내역 및 연동 규약 전달

> 기존 앱 구조(BT 통신, 재활 화면, 상태관리 등)는 본인이 작성했으므로 생략.  
> 이 문서는 **게임 시스템 추가로 달라진 것**만 다룸.

---

## 1. 새로 추가된 파일 및 폴더

### lib/games/ (전체 신규)

```
lib/games/
├── game_base.dart           # 공유 타입 (GameConfig, GameResult, Brunnstrom 등)
├── game_hub.dart            # 게임 선택 화면 — BottomNavBar 탭으로 연결됨
├── calibration_widget.dart  # 게임 전 ROM 캘리브레이션
├── angle_normalizer.dart    # BT 각도 → 0.0~1.0 정규화
├── game_motor_controller.dart  # 게임 중 모터 명령 전송
├── game_result_screen.dart  # 게임 종료 결과 화면
├── score_manager.dart       # 점수/세션 관리
├── game_graphics_utils.dart # 그래픽 유틸
├── kenney_atlas.dart        # 스프라이트 에셋 관리
├── games/                   # 각 게임 구현체 (12개)
│   ├── shield_guard_game.dart   ← 현재 개발 집중 중
│   ├── sky_gardener_game.dart
│   ├── swimming_game.dart
│   └── ... (총 12개)
└── painters/                # CustomPainter 렌더러
```

### assets/ (신규 추가)

```
assets/shield/               # 방패 게임 스프라이트 (PNG)
assets/audio/sheild_guard/   # 방패 게임 BGM (오타 주의: sheild)
assets/images/kenney_*/      # 게임 공통 스프라이트 팩
assets/100-CC0-SFX/          # 효과음 (CC0 라이선스)
assets/DM-CGS/WAV/           # 추가 효과음
```

---

## 2. 기존 앱에서 변경된 부분

### pubspec.yaml

```yaml
# 추가된 패키지
dependencies:
  flame: ^1.36.0        # 게임 엔진
  flame_audio: ^2.1.1   # 게임 오디오

# 추가된 에셋 경로 (기존 CSV 에셋 뒤에 추가됨)
flutter:
  assets:
    - assets/images/kenney_space-shooter-redux/PNG/
    - assets/images/kenney_medieval-rts/...
    - assets/shield/
    - assets/audio/sheild_guard/
    # ... 기타 게임 에셋 폴더들
```

### navi.dart

게임 허브 탭이 기존 탭 목록에 추가됨:

```dart
// 기존 탭 목록에 GameHubScreen 추가
// IndexedStack에 games/game_hub.dart 연결
// BluetoothService 인스턴스를 GameHub로 전달
```

> ⚠️ **탭 인덱스 변경됨**: GameHubScreen이 기존 ModeSelect(3)와 Control(4) 사이에 삽입됨.  
> 기존 탭 인덱스가 아래와 같이 밀렸으니 인덱스를 직접 참조하는 코드가 있다면 확인 필요.

| 탭 | 변경 전 인덱스 | **변경 후 인덱스** |
|----|------------|----------------|
| HomeScreen | 0 | 0 (동일) |
| ProfileScreen | 1 | 1 (동일) |
| ROMModeSelectScreen | 2 | 2 (동일) |
| ModeSelectScreen | 3 | 3 (동일) |
| **GameHubScreen** | — | **4 (신규)** |
| ControlScreen | 4 | **5** |
| FileUploadScreen | 5 | **6** |
| InformationScreen | 6 | **7** |

---

## 3. 게임 시스템 연동 규약

### 게임 진입 흐름

```
GameHubScreen (게임 선택)
    ↓ Navigator.push
CalibrationWidget (ROM 최소/최대 캘리브레이션)
    ↓ GameConfig 생성 후 전달
GameScreen (각 게임 구현체)
    ↓ 종료 시 onGameEnd(GameResult) 콜백
GameResultScreen (점수/정확도 표시)
    ↓ Navigator.pushReplacement
```

### GameConfig — 앱에서 게임으로 전달

`lib/games/game_base.dart` 정의:

```dart
GameConfig({
  required AngleNormalizer normalizer, // BT 각도 정규화기
  int difficultyLevel = 1,             // 1~5
  String bodyPart = '',                // 관절 코드 (lShoulderEF 등)
  Duration gameDuration,
  BrunnstromStage brunnstromStage,     // 회복 단계 2~6
  CognitiveLevel cognitiveLevel,       // 인지 레벨 1~3
  MotorMode motorMode,                 // none/cpm/isometric/isotonic
})
```

### GameResult — 게임에서 앱으로 반환

```dart
GameResult({
  String gameId,
  int score,
  int maxPossibleScore,
  double accuracy,         // 0.0~1.0
  Duration duration,
  DateTime timestamp,
  double calibrationMin,   // 캘리브레이션 최소 각도 (°)
  double calibrationMax,   // 캘리브레이션 최대 각도 (°)
})
```

### AngleNormalizer

BT 수신 원본 각도(°) → 게임 입력 0.0~1.0 변환:

```dart
// lib/games/angle_normalizer.dart
final normalizer = AngleNormalizer(minAngle: 10.0, maxAngle: 90.0);
final normalized = normalizer.normalize(rawAngle);
```

캘리브레이션 위젯이 min/max를 자동 측정하여 AngleNormalizer 생성.

### game_motor_controller.dart

게임 중 모터 명령을 BT로 전송하는 전용 클래스. BluetoothService 싱글톤을 내부에서 직접 사용.  
**앱 담당자가 별도로 수정할 필요 없음** — 게임 담당자 관할.

---

## 4. 담당 경계

| 파일/폴더 | 담당 | 비고 |
|---------|------|------|
| `lib/` 루트 (games/ 제외) | **앱 담당자** | 기존 작성분 |
| `lib/games/` 전체 | 게임 담당자 | 수정 금지 |
| `lib/games/game_base.dart` | **공동** | 수정 시 양측 협의 필요 |
| `lib/games/game_motor_controller.dart` | 게임 담당자 | BT 명령 수정 시 협의 |
| `assets/shield/`, `assets/audio/` | 게임 담당자 | |
| `pubspec.yaml` | **공동** | 패키지/에셋 추가 시 양측 인지 필요 |
| `CLAUDE.md` | **공동** | 아키텍처 변경 시 업데이트 |

---

## 5. 앱 담당자가 추가 개발할 항목

게임 시스템과 연동되는 부분 중 아직 미구현:

| 항목 | 내용 |
|------|------|
| GameConfig 설정 UI | Brunnstrom 단계, 인지 레벨, 게임 시간 등을 환자 프로필 또는 게임 선택 화면에서 입력받는 UI |
| 세션 결과 저장 | GameResult → shared_preferences JSON 또는 CSV 내보내기 |
| 플레이 이력 화면 | 저장된 GameResult 목록 조회 및 표시 |
| 게임 담당자 연락처 | 게임 버그 또는 인터페이스 변경 시 협의 |

---

## 6. 참고 문서

| 문서 | 내용 |
|------|------|
| `CLAUDE.md` | 전체 아키텍처 + BT 프로토콜 + 담당 분리 |
| `docs/game_strategy_and_schedule.md` | Brunnstrom 기반 게임 설계 전략 |
| `docs/game_session_data_format.md` | GameResult JSON/CSV 스키마 |
| `docs/master_development_plan.md` | 전체 개발 일정 |
| `docs/shield_guard_build_guide.md` | 게임 담당자 전용 (참고용) |
