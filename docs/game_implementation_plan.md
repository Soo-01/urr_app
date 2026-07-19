# 상지재활 게임 구현 계획서

## 1. 아키텍처 개요

### 1.1 설계 원칙

- 기존 앱 패턴 준수: 상태는 부모 위젯에 리프팅, BluetoothService는 생성자로 전달, 로컬라이제이션은 `AppLocalizations.of(context)!`
- CustomPainter 기반 렌더링 (새 의존성 없음)
- 게임은 Navigator.push로 전체 화면 실행 (IndexedStack 외부)
- 캘리브레이션 → 게임 → 결과 화면의 일관된 흐름

### 1.2 파일 구조

```
lib/games/
  game_hub.dart                    # 게임 선택 화면 (네비게이션 탭)
  game_base.dart                   # 공통 타입 정의
  calibration_widget.dart          # ROM 캘리브레이션 위젯
  score_manager.dart               # 점수/난이도/세션 관리
  angle_normalizer.dart            # BT 각도 → 0.0~1.0 정규화
  game_result_screen.dart          # 게임 결과 화면
  games/
    target_reaching_game.dart      # 타겟 도달 게임
    balloon_pop_game.dart          # 풍선 터트리기 게임
    tracking_game.dart             # 추적 게임
  painters/
    target_reaching_painter.dart   # 타겟 도달 CustomPainter
    balloon_pop_painter.dart       # 풍선 터트리기 CustomPainter
    tracking_painter.dart          # 추적 게임 CustomPainter
```

### 1.3 데이터 흐름

```
BluetoothService.dataStream ("12.34\n")
  │
  ├─ double.tryParse(data.trim()) → rawAngle
  │
  ├─ AngleNormalizer.normalize(rawAngle) → normalizedPos (0.0~1.0)
  │
  ├─ Game State Update
  │   ├─ 커서 위치 갱신
  │   ├─ 충돌/근접 판정
  │   ├─ 점수 갱신
  │   └─ 난이도 체크
  │
  └─ setState() → CustomPainter.shouldRepaint → Canvas repaint
```

BT 미연결 시: Slider 위젯으로 시뮬레이션 입력 제공

---

## 2. 공통 인프라 상세 설계

### 2.1 AngleNormalizer (`angle_normalizer.dart`)

```dart
class AngleNormalizer {
  final double minAngle;  // 캘리브레이션된 최소 ROM
  final double maxAngle;  // 캘리브레이션된 최대 ROM

  double normalize(double rawAngle) {
    if (maxAngle == minAngle) return 0.5;
    return ((rawAngle - minAngle) / (maxAngle - minAngle)).clamp(0.0, 1.0);
  }
}
```

기존 `rommode.dart`의 `norm()` 함수와 동일 원리이나, 하드코딩(-100/+100) 대신 캘리브레이션 값 사용.

### 2.2 GameBase (`game_base.dart`)

```dart
enum GameState { calibrating, countdown, playing, paused, finished }

class GameConfig {
  final AngleNormalizer normalizer;
  final int difficultyLevel;       // 1~5
  final String bodyPart;           // 예: 'lElbow'
  final Duration gameDuration;     // 예: 60초
}

class GameResult {
  final String gameId;             // 'target_reaching', 'balloon_pop', 'tracking'
  final int score;
  final int maxPossibleScore;
  final double accuracy;           // 0.0~1.0
  final Duration duration;
  final int difficultyLevel;
  final String bodyPart;
  final DateTime timestamp;
  final List<AngleRecord> angleHistory;
}

class AngleRecord {
  final int timestampMs;
  final double rawAngle;
  final double normalizedPosition;
}
```

### 2.3 ScoreManager (`score_manager.dart`)

**기능:**
- 세션 중 점수 추적
- 라운드별 난이도 적응 (성공률 >80% → 레벨 업, <40% → 레벨 다운)
- TTS 피드백 ("잘했어요!" / "Great job!") — 기존 FlutterTts 패턴 활용
- shared_preferences로 최근 게임 결과 저장 (JSON 인코딩)

### 2.4 CalibrationWidget (`calibration_widget.dart`)

**흐름:**
1. "팔을 최대 범위로 움직여주세요" 안내 표시 (로컬라이제이션)
2. BT 스트림 구독, min/max 각도 추적 (rommode.dart의 기존 패턴)
3. TTS 카운트다운: "3... 2... 1... 시작!" → 10초 측정 → "캘리브레이션 완료"
4. AngleNormalizer 반환
5. 게임 중 "재캘리브레이션" 버튼 제공

---

## 3. 네비게이션 통합

### 3.1 navi.dart 수정

**변경 사항:**
- `pages` 배열 index 4에 `GameHubScreen` 추가
- NavigationRail에 `Icons.games` 아이콘 + 게임 라벨 추가
- BottomNavigationBar에 동일 항목 추가
- 비밀번호 게이트: `index == 4` → `index == 5` (Control 탭 이동)

**결과 탭 순서:**
| Index | 화면 | 아이콘 |
|-------|------|--------|
| 0 | Home | Icons.home |
| 1 | Profile | Icons.person |
| 2 | ROM Mode | Icons.straighten |
| 3 | Mode Select | Icons.fitness_center |
| 4 | **Game Hub** | **Icons.games** |
| 5 | Control (비밀번호) | Icons.settings |
| 6 | File Upload | Icons.file_upload |

### 3.2 Game Hub 화면 설계

**레이아웃 (가로 태블릿):**
- AppBar: "재활 게임" / "Rehabilitation Games"
- 게임 카드 그리드 (2행 x 3열)
  - 각 카드: 아이콘, 게임 이름, 간단 설명, 난이도 뱃지
  - 미구현 게임: 잠금 아이콘 표시
- 카드 탭 → `Navigator.push`로 게임 전체 화면 실행

**Navigator.push 사용 이유:**
1. 게임은 전체 화면 필요 (NavigationRail 없이)
2. IndexedStack은 모든 자식을 유지하여 메모리 낭비
3. 뒤로가기 버튼으로 Game Hub 복귀

---

## 4. 게임별 상세 설계

### 4.1 타겟 도달 게임 (Target Reaching)

**임상 목적:** ROM 훈련, 위치 정확도 향상

**화면 구성:**
```
┌─────────────────────────────────────────────┐
│  타겟 도달 게임    점수: 5    남은시간: 45초    │
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│  ──────[===타겟===]──────●커서──────────────  │
│                                             │
│                                             │
│         "타겟으로 이동하세요!"                 │
│                                             │
│              [일시정지]                       │
└─────────────────────────────────────────────┘
```

**게임 메커닉:**
- 수평 바에 커서(현재 각도, 큰 원)와 타겟 존(하이라이트 영역) 표시
- 커서가 타겟 존 안에 dwell time 동안 유지 → "히트"
- 히트 시: 색상 변화(파랑→금색) + TTS("좋아요!") + 점수 +1
- 새 타겟이 다른 위치에 생성
- 게임 시간: 기본 60초

**CustomPainter 필드:**
- `cursorPosition` (0.0~1.0)
- `targetPosition` (0.0~1.0)
- `targetRadius` (정규화된 크기)
- `isHitting` (bool, 색상 피드백)
- `score`, `timeRemaining`
- `dwellProgress` (0.0~1.0, 원형 프로그레스)

**난이도 레벨:**
| 레벨 | 타겟 크기 | Dwell Time | 타겟 범위 |
|------|----------|------------|----------|
| 1 | 20% | 1.0초 | ROM 30~70% |
| 2 | 15% | 0.8초 | ROM 20~80% |
| 3 | 12% | 0.6초 | ROM 10~90% |
| 4 | 8% | 0.4초 | ROM 5~95% |
| 5 | 5% | 0.3초 | ROM 0~100% |

---

### 4.2 풍선 터트리기 게임 (Balloon Pop)

**임상 목적:** ROM 확장, 반응 속도 향상, 동기 부여

**화면 구성:**
```
┌─────────────────────────────────────────────┐
│  풍선 터트리기    점수: 12    남은시간: 50초    │
├─────────────────────────────────────────────┤
│                                             │
│    🎈        🎈    🎈         🎈             │
│       🎈              🎈                    │
│  ────────────────●핀──────────────────────  │
│                                             │
│                                             │
│              [일시정지]                       │
└─────────────────────────────────────────────┘
```

**게임 메커닉:**
- 풍선(컬러 원 + 줄)이 수평 바 위 다양한 위치에 생성
- 커서(핀/바늘 모양)가 풍선에 겹치면 즉시 팝
- 팝 애니메이션: 원이 확대 → 파티클 흩어짐 → 사라짐 (~300ms)
- 골드 풍선: 가끔 출현, 2배 점수
- 일정 간격으로 새 풍선 스폰

**CustomPainter 필드:**
- `balloons`: List<Balloon> (normalizedX, radius, color, isPopping, popAnimProgress)
- `cursorPosition` (0.0~1.0)
- `score`, `timeRemaining`

**난이도 레벨:**
| 레벨 | 풍선 크기 | 스폰 간격 | 최대 동시 | 범위 | 이동 |
|------|----------|----------|----------|------|------|
| 1 | 큰 (8%) | 2.0초 | 3개 | 30~70% | 없음 |
| 2 | 중 (6%) | 1.5초 | 4개 | 20~80% | 없음 |
| 3 | 중 (5%) | 1.2초 | 5개 | 10~90% | 없음 |
| 4 | 소 (4%) | 1.0초 | 6개 | 5~95% | 느림 |
| 5 | 소 (3%) | 0.7초 | 8개 | 0~100% | 보통 |

---

### 4.3 추적 게임 (Tracking)

**임상 목적:** 부드러운 움직임, 운동 제어, 협응력

**화면 구성:**
```
┌─────────────────────────────────────────────┐
│  추적 게임    정확도: 85%    남은시간: 30초      │
├─────────────────────────────────────────────┤
│                                             │
│  경로 미리보기:  ╌╌╌╌╌╌╮                      │
│                      ╰╌╌╌╌╌╌              │
│  ────────────●타겟───●커서──────────────── │
│              ↕ 거리 표시                      │
│                                             │
│  [정확도 히스토리 그래프]                       │
│              [일시정지]                       │
└─────────────────────────────────────────────┘
```

**게임 메커닉:**
- 타겟 점이 사전 정의된 경로(사인파, 계단식 등)를 따라 이동
- 환자가 커서를 타겟에 최대한 가깝게 유지
- 연속 정확도: `1.0 - |cursorPos - targetPos|`
- 시각 피드백: 커서-타겟 연결선, 초록(가까움)→빨강(멀음)
- 평균 정확도 백분율 표시
- 경로 미리보기 (타겟 앞의 희미한 선)

**타겟 이동 패턴:**
- AnimationController + Ticker로 60fps 타겟 이동 (BT 수신과 독립)
- `_getTargetPosition(elapsedMs)` 함수로 시간 기반 위치 계산

**난이도 레벨:**
| 레벨 | 패턴 | 속도 | 진폭 | 방향 전환 |
|------|------|------|------|----------|
| 1 | 느린 사인파 | 0.3x | ROM 30~70% | 부드러움 |
| 2 | 사인파 | 0.5x | ROM 20~80% | 부드러움 |
| 3 | 사인파 | 1.0x | ROM 10~90% | 보통 |
| 4 | 복합파 | 1.2x | ROM 5~95% | 가끔 급격 |
| 5 | 불규칙 | 1.5x | ROM 0~100% | 빈번 급격 |

---

## 5. 구현 순서 및 의존성

```
Phase 1: 문서
  ├── game_research.md
  ├── game_implementation_plan.md
  └── game_session_data_format.md

Phase 2: 공통 인프라
  ├── angle_normalizer.dart (의존성 없음)
  ├── game_base.dart (angle_normalizer에 의존)
  ├── score_manager.dart (game_base에 의존)
  └── calibration_widget.dart (angle_normalizer, BluetoothService에 의존)

Phase 3: 네비게이션
  ├── game_hub.dart (game_base에 의존)
  ├── navi.dart 수정 (game_hub에 의존)
  └── ARB 파일 + flutter gen-l10n

Phase 4: 게임 구현
  ├── target_reaching (painter + game) ← 파이프라인 검증
  ├── balloon_pop (painter + game)
  └── tracking (painter + game)

Phase 5: 마무리
  ├── game_result_screen.dart
  ├── 세션 히스토리
  └── 디버그 시뮬레이션 모드
```

---

## 6. 로컬라이제이션 키 목록

### 게임 허브
- `rehabGames` / 재활 게임
- `targetReaching` / 타겟 도달
- `balloonPop` / 풍선 터트리기
- `trackingGame` / 추적 게임
- `targetReachingDesc` / 타겟 위치까지 정확하게 이동하세요
- `balloonPopDesc` / 풍선을 터트려 점수를 획득하세요
- `trackingGameDesc` / 움직이는 타겟을 따라가세요
- `comingSoon` / 준비 중
- `difficulty` / 난이도
- `easy` / 쉬움
- `medium` / 보통
- `hard` / 어려움

### 캘리브레이션
- `calibration` / 캘리브레이션
- `calibrationInstruction` / 팔을 최대 범위로 움직여주세요
- `calibrationComplete` / 캘리브레이션 완료
- `recalibrate` / 재캘리브레이션
- `startCalibration` / 캘리브레이션 시작

### 게임 공통
- `gameScore` / 점수
- `gameTime` / 남은 시간
- `gameAccuracy` / 정확도
- `gameOver` / 게임 종료
- `greatJob` / 잘했어요!
- `tryAgain` / 다시 도전
- `startGame` / 게임 시작
- `pauseGame` / 일시정지
- `resumeGame` / 재개
- `backToHub` / 게임 목록으로
- `playAgain` / 다시 하기
- `level` / 레벨
- `round` / 라운드
- `hits` / 히트
- `misses` / 미스

### 타겟 도달
- `moveToTarget` / 타겟으로 이동하세요
- `targetHit` / 타겟 도달!

### 풍선 터트리기
- `popBalloons` / 풍선을 터트리세요
- `bonusBalloon` / 보너스 풍선!

### 추적 게임
- `followTarget` / 타겟을 따라가세요
- `avgAccuracy` / 평균 정확도

### 결과 화면
- `sessionResult` / 세션 결과
- `finalScore` / 최종 점수
- `sessionDuration` / 소요 시간
- `difficultyLevel` / 난이도 레벨
- `sessionHistory` / 세션 기록
