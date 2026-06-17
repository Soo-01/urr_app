# 게임 세션 데이터 형식

## 1. 개요

게임 세션 데이터는 두 가지 형식으로 저장된다:
1. **세션 요약** — JSON 형식으로 shared_preferences에 저장 (앱 내 히스토리 표시용)
2. **각도 이력** — CSV 형식으로 파일 내보내기 (분석/연구용)

---

## 2. 세션 요약 (JSON)

### 저장 위치
`shared_preferences` 키: `game_session_history`

### 스키마

```json
{
  "sessions": [
    {
      "gameId": "target_reaching",
      "score": 15,
      "maxPossibleScore": 20,
      "accuracy": 0.85,
      "durationSeconds": 60,
      "difficultyLevel": 3,
      "bodyPart": "lElbow",
      "timestamp": "2026-03-23T14:30:00.000",
      "calibrationMin": -15.5,
      "calibrationMax": 72.3,
      "hits": 15,
      "misses": 5
    }
  ]
}
```

### 필드 설명

| 필드 | 타입 | 설명 |
|------|------|------|
| `gameId` | String | 게임 식별자 (`target_reaching`, `balloon_pop`, `tracking`) |
| `score` | int | 획득 점수 |
| `maxPossibleScore` | int | 최대 가능 점수 |
| `accuracy` | double | 정확도 (0.0~1.0) |
| `durationSeconds` | int | 게임 소요 시간 (초) |
| `difficultyLevel` | int | 난이도 레벨 (1~5) |
| `bodyPart` | String | 운동 부위 코드 |
| `timestamp` | String | ISO 8601 형식 타임스탬프 |
| `calibrationMin` | double | 캘리브레이션된 최소 각도 |
| `calibrationMax` | double | 캘리브레이션된 최대 각도 |
| `hits` | int | 성공 횟수 |
| `misses` | int | 실패 횟수 |

---

## 3. 각도 이력 (CSV)

### 파일명 규칙
`{gameId}_{bodyPart}_{timestamp}.csv`

예: `target_reaching_lElbow_20260323_143000.csv`

### CSV 형식

```csv
timestamp_ms,raw_angle,normalized_position,target_position,event
0,12.34,0.32,0.65,
16,12.50,0.33,0.65,
33,13.10,0.34,0.65,
500,25.30,0.65,0.65,hit
516,25.10,0.64,0.82,
```

### 열 설명

| 열 | 타입 | 설명 |
|----|------|------|
| `timestamp_ms` | int | 게임 시작 후 경과 시간 (밀리초) |
| `raw_angle` | double | 블루투스에서 수신된 원시 각도 값 |
| `normalized_position` | double | 정규화된 위치 (0.0~1.0) |
| `target_position` | double | 현재 타겟의 정규화된 위치 (0.0~1.0) |
| `event` | String | 이벤트 (빈 문자열, `hit`, `miss`, `pop`, `spawn`) |

### 게임별 이벤트 코드

**타겟 도달:**
- `hit` — 타겟 도달 성공
- `new_target` — 새 타겟 생성
- `timeout` — 시간 초과로 타겟 미도달

**풍선 터트리기:**
- `pop` — 풍선 터트리기 성공
- `pop_bonus` — 골드 풍선 터트리기
- `spawn` — 새 풍선 생성
- `expire` — 풍선 시간 초과 소멸

**추적 게임:**
- (이벤트 없음 — 연속 정확도 데이터로 기록)
- `direction_change` — 타겟 방향 전환 시점

---

## 4. 데이터 저장 정책

- **세션 요약:** 최근 50개 세션까지 유지 (FIFO)
- **각도 이력 CSV:** 앱 문서 디렉토리에 저장, File Upload 탭에서 내보내기 가능
- **샘플링:** BT 수신 데이터를 모두 기록 (20~50Hz)
