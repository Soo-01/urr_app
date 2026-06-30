# [E4] 트로트 리듬 응원 게임 (Trot Rhythm Action) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-29  
**파일**: `lib/games/games/trot_rhythm_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 현재 상태 (2026-06-29 기준)

| 항목 | 상태 |
|------|------|
| 기본 리듬 게임 뼈대 (노트 스폰, 싱크 유지) | ❌ 미완성 |
| 어깨 관절(좌우 이동) ↔ 레인 매핑 알고리즘 | ❌ 미완성 |
| 팔꿈치 관절(속도 기반) ↔ 타격(Hit) 스윙 감지 | ❌ 미완성 |
| Perfect/Good/Miss 시간차 판정 및 콤보 로직 | ❌ 미완성 |
| 스프라이트 통합 (무대, 가수, 노트, 응원봉) | ❌ 미완성 |
| 타격 이펙트 및 피버(Fever) 타임 시각 연출 | ❌ 미완성 |
| 판정 텍스트 팝업 (진/선/미 한자 스타일) | ❌ 미완성 |
| Suno 생성 BGM ↔ 노트 맵(Map) 데이터 동기화 | ❌ 미완성 |
| 추임새(SFX) 재생 및 BGM 볼륨 밸런싱 | ❌ 미완성 |
| Brunnstrom 난이도 ↔ 판정 범위(Tolerance) 연동 | ❌ 미완성 |

---

## 1. 비주얼 컨셉 — 미스터트롯/미스트롯 레퍼런스

### 1-1. 조사 결과 요약

| 항목 | 미스터트롯 스타일 | 게임 적용 방향 |
|------|----------------|-------------|
| **배경 색조** | 흰색/크림 (시즌3) · 아이보리+홍색 (미스트롯4) | 크림 화이트 배경 + 홍색 포인트 조명 |
| **캐릭터** | 흰 슈트 착용 한국인 남성 트로트 가수 | 흰 슈트 or 개량 한복 가수 아바타 |
| **판정 UI** | 심사위원 의자 옆 하트 발광 디스플레이 점등 | 하트 발광 팝업 → 판정 피드백 |
| **순위 텍스트** | 진(眞) · 선(善) · 미(美) 한자 타이포그래피 | PERFECT=眞, GOOD=善, MISS=아쉬워 |
| **응원봉** | 하늘색(스카이블루) LED · 6가지 애니메이션 | 하늘색 LED 응원봉 커서 |
| **팬덤 연출** | 공식 응원봉 집단 점멸, 콘서트 레이저쇼 | 피버 타임: 응원봉 전체 점멸 |
| **전통 요소** | 개량 한복, 구미호, 한자 | 한자 타이포그래피 · 전통 색감 |

### 1-2. 컬러 팔레트

```
배경:    #FFFAF0 (크림 화이트)    — 미스터트롯3 주조색
포인트:  #C8102E (홍색)           — 미스트롯4 한복 색
응원봉:  #87CEEB (스카이블루)     — 임영웅 응원봉 대표색
보조:    #1A1A1A (딥 블랙)        — 미스트롯4 한복 검정
골드:    #D4AF37 (금색)           — 한자 텍스트 금박 효과
```

### 1-3. 판정 텍스트 스타일

| 판정 | 텍스트 | 스타일 |
|------|--------|--------|
| Perfect | **眞** (진) | 금박 한자, 대형, 위로 솟구침 |
| Good | **善** (선) | 흰색 한자, 중형, 팝업 |
| Miss | **아쉬워** | 회색, 소형, 아래로 떨어짐 |

> "얼씨구!" "좋지!" 같은 올드한 추임새는 사용하지 않음.  
> 진/선은 미스터트롯 실제 시스템에서 가져온 레퍼런스로 시청자 친숙도가 높음.

---

## 2. 게임 구조 한눈에 보기

```
입력 데이터 (BT 센서: 어깨 굽힘/폄/돌림, 팔꿈치 굽힘/폄)
  ↓ 관절 가동 범위(ROM) Calibration 데이터 적용
  ↓
TrotRhythmFlameGame.update(dt)
  ├── 1. 리듬 코어 동기화 (_updateSync)
  │     └─ 오디오 재생기에서 실제 시간(_songTime)을 읽어와 게임 시간 동기화
  ├── 2. 레인 이동 단계 (_updateMovePhase)
  │     └─ 어깨 각도 데이터를 이산화하여 3개 레인(0, 1, 2) 중 하나로 응원봉 위치 이동
  ├── 3. 노트 낙하 단계 (_updateNotes)
  │     └─ 맵 데이터에서 노트 스폰 및 (_songTime - noteTime)을 계산하여 노트의 정확한 Y 좌표 갱신
  ├── 4. 타격 및 판정 단계 (_updateHitPhase)
  │     └─ 팔꿈치 폄/굽힘 속도(Velocity) 임계치 돌파 시 스윙 판정 발동
  │     └─ 현재 응원봉 레인에 있는 가장 아래쪽 노트와의 시간차 검사
  │         ├── 眞 Perfect (±0.15s) → 콤보 증가, 점수++
  │         ├── 善 Good (±0.3s) → 콤보 증가, 점수+
  │         └── 아쉬워 Miss (초과) → 콤보 초기화, 체력 감소
  ├── 5. 피버 상태 업데이트 (_updateFever)
  │     └─ 콤보 수에 비례하여 피버 게이지 증가, 100% 도달 시 응원봉 전체 점멸 연출
  └── 6. 애니메이션 업데이트 (가수 댄스, 하트 발광, 판정 텍스트 팝업)
  ↓
render(canvas)
  ├── 1. 배경: 미스터트롯 스타일 경연 무대 (bg_trot_stage)
  ├── 2. 조명: 홍색+골드 스팟 조명, LED 배경 월
  ├── 3. 아바타: 흰 슈트 한국인 트로트 가수 (singer_avatar)
  ├── 4. 레인: 수직 구분선 (lane_line) 및 판정선 (target_zone)
  ├── 5. 노트: 하트 모양 낙하 노트 (note_heart)
  ├── 6. 커서: 하늘색 LED 응원봉 (cursor_stick)
  ├── 7. 이펙트: 하트 발광 파티클 (hit_effect / BlendMode.plus)
  ├── 8. 팝업 UI: 眞/善/아쉬워 한자 판정 팝업 (ui_text_*)
  └── 9. HUD: 콤보 수, 점수, 피버 게이지 (fever_gauge_fill)
```

---

## 3. 핵심 상태 변수

```dart
// 리듬 동기화 상태
double _songTime = 0.0;           // 음악의 현재 재생 시간 (매 프레임 갱신)
List<NoteData> _mapData = [];     // 전체 곡의 노트 맵 (시간, 레인)
List<NoteComponent> _activeNotes = [];

// 관절 매핑 상태
int _currentLane = 1;             // 0: Left, 1: Center, 2: Right
double _elbowVelocity = 0.0;      // 팔꿈치 각도 변화량 (스윙 판정용)
bool _isHitting = false;          // 디바운스 처리용 플래그
double _hitCooldownTimer = 0.0;   // 연속 타격 방지 쿨다운

// 점수 및 진행 상태
int _score = 0;
int _combo = 0;
int _maxCombo = 0;
int _lifeCount = 5;

// 피버(Fever) 시스템
double _feverGauge = 0.0;         // 0.0 ~ 100.0
bool _isFeverTime = false;
double _feverTimer = 0.0;         // 피버 지속 시간
```

---

## 4. 난이도 및 생체역학 파라미터

어르신의 인지/반응 속도를 고려하여 일반 리듬게임보다 판정 시간을 매우 관대하게 둡니다.

```dart
double get noteSpeedMultiplier => 0.5 + (config.difficultyLevel * 0.1);

// 판정 허용 시간 (초)
double get perfectWindow => 0.25 - (config.difficultyLevel * 0.02);
double get goodWindow => 0.4 - (config.difficultyLevel * 0.02);

// 스윙 감지 민감도
double get swingThreshold => 15.0 / config.difficultyLevel;
```

| Level | 노트 낙하 속도 | 판정선 도달 시간 | 眞 허용치 | 善 허용치 |
|-------|-------------|---------------|---------|---------|
| 1 | 매우 느림 | 화면 생성 후 3초 | ±0.23초 | ±0.38초 |
| 3 | 보통 | 화면 생성 후 2.5초 | ±0.19초 | ±0.34초 |
| 5 | 다소 빠름 | 화면 생성 후 2초 | ±0.15초 | ±0.30초 |

---

## 5. 스프라이트 (에셋) 목록

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션 |
|--------|-----------|------------|---------|---------|
| `bg_trot_stage.png` | 1920×1080 | 화면 전체 | **유지** | 고정 |
| `singer_avatar.png` | 512×512 | 250×400 px | 투명화 | 바운스 댄스 (Hover) |
| `lane_line.png` | 128×1024 | 20×800 px | **검정 유지** | 반투명 고정 |
| `target_zone.png` | 256×256 | 150×150 px | **검정 유지** | 하트 펄스 (Effect API) |
| `note_heart.png` | 256×256 | 100×100 px | 투명화 | 수직 낙하 |
| `cursor_stick.png` | 256×512 | 100×250 px | 투명화 | 좌우 이동 + 스윙 |
| `hit_effect.png` | 512×512 | 200×200 px | **검정 유지** | 순간 확대 & 페이드아웃 |
| `ui_text_jin.png` | 512×256 | 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_seon.png` | 512×256 | 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_miss.png` | 512×256 | 200×100 px | 투명화 | 팝업 (떨어짐 연출) |

> 미러볼/네온사인 제거 → 하트 발광 + 홍색 스팟 조명으로 대체

---

## 6. 애니메이션 연출 가이드

### 6-1. 트랜스폼 이펙트

- **하트 판정선 펄스**: `target_zone`에 `ScaleEffect.by(Vector2(1.1, 1.1), EffectController(duration: 0.5, infinite: true, alternate: true))` + `OpacityEffect`
- **가수 댄스**: `singer_avatar`에 `MoveEffect.by(Vector2(0, 10), EffectController(duration: 0.4, infinite: true, alternate: true))` (무릎 바운스)
- **판정 텍스트 팝업**: `ui_text_jin` 생성 → `ScaleEffect.to(1.3)` + `MoveEffect.by(Vector2(0, -60))` 동시 재생 → `RemoveEffect()`

### 6-2. 스윙 애니메이션 (응원봉 타격)

```dart
// SequenceEffect로 0.15초 안에 휘두름 → 원상복구
SequenceEffect([
  RotateEffect.by(-0.4, EffectController(duration: 0.05)), // 뒤로 젖힘
  RotateEffect.by(0.8, EffectController(duration: 0.07)),  // 앞으로 스윙
  RotateEffect.to(0.0, EffectController(duration: 0.03)),  // 복구
])
```

### 6-3. 피버 타임 (Fever Time) 연출

- **응원봉 점멸**: 커서 응원봉 색상을 하늘색 → 흰색 → 하늘색으로 빠르게 순환 (임영웅 응원봉 LED 효과 참조)
- **홍색 오버레이**: `Paint()..color = Color(0x44C8102E)..blendMode = BlendMode.colorDodge` 전체 화면에 적용
- **하트 파티클**: 배경에서 하트 모양 파티클이 위로 솟구침

---

## 7. 스프라이트 제작 파이프라인

### 단계 1: AI 이미지 생성

- 캐릭터·오브젝트(가수, 응원봉, 노트, 텍스트): **초록 배경 #00FF00** 필수
- 빛·이펙트(판정선, 타격 폭죽): **검정 배경 #000000** (BlendMode.plus 용)

### 단계 2: 타이포그래피 — 眞/善 한자 이미지

- AI가 한자를 부정확하게 그릴 수 있으므로 **포토샵/Canva에서 직접 제작**
- 폰트: 붓글씨 계열 (예: 나눔손글씨, 문체부 공공서체) — 눈누(noonnu.cc) 상업용 무료
- 스타일: 금박 그라디언트 + 두꺼운 외곽선 + 초록 배경 PNG

### 단계 3: 배경 제거 (누끼)

- `remove.bg` 또는 포토샵 피사체 선택으로 초록 배경 제거
- 가수 머리카락 등 복잡한 경계: 알파 마스크 수동 정리 → PNG-24 내보내기

### 단계 4: BlendMode.plus 에셋 처리

- `target_zone`, `hit_effect`, `lane_line`: 배경 절대 제거 금지
- Levels 도구로 검정 영역이 순수 RGB(0,0,0)인지 확인 (회색 잔류 시 박스 테두리 노출)

### 단계 5: 압축 최적화

- `tinypng.com`으로 PNG 압축 → 로딩 속도 + RAM 절감
- 파일 저장 위치: `assets/images/trot_rhythm/` (소문자 언더스코어 네이밍)
- `pubspec.yaml` 등록 후 `Flame.images.loadAll()` 일괄 캐싱

---

## 8. AI 이미지 생성 프롬프트

**공통 스타일**: `Korean trot music competition show style (inspired by Mr. Trot), modern K-entertainment stage, cream white and crimson red color palette, warm golden spotlights, cel-shaded cartoon, bold black outlines, mobile rhythm game asset`

### 초록 배경 (투명화용)

- **가수 아바타**: `A handsome Korean male trot singer in his 30s wearing a pristine white suit, holding a microphone, enthusiastic singing pose, full body, bright stage lighting, solid lime green background #00FF00`
- **노트 (하트)**: `A glowing heart shape, crimson red with golden shimmer, 3D shiny, cute and chunky, solid lime green background #00FF00`
- **응원봉**: `A sleek LED light stick (K-pop cheering stick), sky blue glowing color, modern design, bright illuminated, solid lime green background #00FF00`

### 검정 배경 (BlendMode.plus용)

- **판정선**: `A glowing horizontal target line, warm golden neon light, soft outer glow, pure black background #000000`
- **레인 구분선**: `A tall vertical glowing neon divider line, crimson red soft glow, 1:8 aspect ratio, pure black background #000000`
- **타격 이펙트**: `An explosion of glowing hearts and golden sparks, crimson and gold colors, radiating outward, pure black background #000000`

---

## 9. 음악 제작 — Suno AI

### 9-1. Suno 프롬프트 (트로트 스타일)

```
Korean trot song, upbeat and cheerful, traditional Korean instruments (janggu, gayageum),
modern production, bright tempo around 120 BPM, encouraging and energetic,
suitable for elderly rehabilitation exercise, no lyrics or instrumental only
```

> 가사 있는 버전을 원하면 `[verse]`, `[chorus]` 태그 활용

### 9-2. 저작권

| 플랜 | 상업적 사용 | 비고 |
|------|-----------|------|
| 무료 | ❌ Suno 소유 | 비상업 임상·연구 목적은 실질 위험 낮음 |
| Pro/Premier | ✅ 사용자 소유 | 논문 발표·외부 배포 시 권장 |

### 9-3. BPM 추출 및 노트 맵 생성 워크플로우

```
Suno에서 MP3 다운로드
  ↓
BPM 감지: Tunebat.com 또는 BeatRhythm (웹 업로드, 무료)
  ↓
비트 타임스탬프 추출:
  옵션 A — Sonic Visualiser: 비트 마커 수동 클릭 → CSV 내보내기
  옵션 B — Python librosa:
    import librosa
    y, sr = librosa.load('song.mp3')
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
    times = librosa.frames_to_time(beats, sr=sr)
  ↓
노트 맵 JSON 변환:
  [{"time": 1.23, "lane": 1}, {"time": 1.85, "lane": 0}, ...]
  ↓
assets/maps/trot_map_01.json 으로 저장
```

---

## 10. 리듬 게임 특화 로직 (매우 중요)

### 10-1. 오디오 싱크 기반 시간 갱신

```dart
// dt 누적 금지 — 오디오 플레이어 현재 위치를 직접 폴링
if (_audioPlayer.state == PlayerState.playing) {
  _songTime = _audioPlayer.getCurrentPosition().inMilliseconds / 1000.0;
}
```

### 10-2. 노트 위치 절대 계산

```dart
// position.y += speed * dt 사용 금지
double timeDiff = hitTime - gameRef._songTime;
double fallDistance = gameRef.size.y;
position.y = gameRef.targetY - (timeDiff * (fallDistance / fallTime));
```

---

## 11. 오디오 및 SFX

| 구분 | 이벤트 | 파일명 | 볼륨 |
|------|--------|--------|------|
| BGM | 게임 시작 | `trot_bgm_01.mp3` (Suno 생성) | 0.7 |
| SFX | 眞 (Perfect) 타격 | `hit_perfect_heart.ogg` | 1.0 (맑은 종소리) |
| SFX | 善 (Good) 타격 | `hit_good_chime.ogg` | 1.0 (부드러운 차임) |
| SFX | 아쉬워 (Miss) | `hit_miss_dull.ogg` | 0.8 (둔탁한 소리) |
| SFX | 피버 진입 | `fever_fanfare.ogg` | 1.0 (짧은 팡파레) |

> 장구/꽹과리 SFX 제거 → 판정 피드백은 심플한 종/차임 계열로 교체 (Rhythm Heaven 스타일)  
> 효과음 출처: freesound.org (CC0 필터), kenney.nl

---

## 12. 저작권 주의사항

| 항목 | 사용 가능 여부 | 근거 |
|------|-------------|------|
| "미스터트롯" 명칭·로고 | ❌ 불가 | TV조선 상표 |
| 실제 출연자 얼굴·목소리 | ❌ 불가 | 초상권·퍼블리시티권 |
| 트로트 경연 무대 스타일·분위기 | ✅ 가능 | 스타일 자체는 저작권 대상 아님 |
| 진(眞)·선(善)·미(美) 한자 | ✅ 가능 | 일반 한자, 누구나 사용 가능 |
| Suno 생성 음원 (무료 플랜) | ⚠️ 주의 | 비상업 목적은 실질 위험 낮음, 외부 배포 시 Pro 권장 |
| 효과음 CC0 | ✅ 가능 | freesound.org CC0 태그 필터 필수 확인 |
| 폰트 | ✅ 가능 | 눈누(noonnu.cc)에서 상업용 무료 폰트 사용 |

**결론**: 가상의 한국인 트로트 가수 캐릭터 + 경연 무대 스타일 참고 + AI 생성 음악 사용 시 저작권 문제 없음.

---

## 13. 작업 체크리스트

### Phase 1 — 리듬 코어 로직 (플레이스홀더 음악으로 시작)

#### 1-A. 파일 뼈대 생성
- [ ] `lib/games/games/trot_rhythm_game.dart` 파일 생성
- [ ] `claude_code_game_dev_guide.md` 패턴대로 `FlameGame + StatefulWidget` 기본 구조 작성
- [ ] `NoteData` 클래스 정의 (time: double, lane: int)
- [ ] `NoteComponent` 클래스 생성 (`PositionComponent` 상속, hitTime/lane 필드)

#### 1-B. 오디오 + 싱크 (플레이스홀더 사용)
- [ ] `assets/audio/trot_rhythm/` 폴더 생성
- [ ] 임시 메트로놈 MP3 다운로드 (freesound.org CC0, 120 BPM) → `trot_bgm_placeholder.mp3`로 저장
- [ ] `pubspec.yaml` flutter.assets에 `assets/audio/trot_rhythm/` 경로 추가
- [ ] `onLoad()`에서 `FlameAudio.audioCache.loadAll([bgm, sfx 목록])` 호출
- [ ] `_audioPlayer` 인스턴스 생성 및 BGM 재생 시작
- [ ] `update(dt)` 내에서 `_songTime` 폴링 갱신 구현 (10-1 섹션 코드)
- [ ] 일시정지/재개 시 `_audioPlayer.pause()` / `resume()` 연동

#### 1-C. 노트 맵 파싱 + 스폰 (더미 맵으로 시작)
- [ ] `pubspec.yaml` assets에 `assets/maps/` 경로 추가
- [ ] 120 BPM 기준 0.5초 간격 더미 맵 직접 작성 → `assets/maps/trot_map_placeholder.json`:
  ```json
  [
    {"time": 1.0, "lane": 1}, {"time": 1.5, "lane": 0},
    {"time": 2.0, "lane": 1}, {"time": 2.5, "lane": 2}
  ]
  ```
- [ ] `onLoad()`에서 `assets/maps/trot_map_placeholder.json` 로드 및 `_mapData` 파싱
- [ ] `update(dt)`에서 `_songTime >= note.time && !note.spawned` 조건으로 스폰
- [ ] `NoteComponent`를 게임 트리에 `add()`
- [ ] 판정선 아래로 내려간 노트(Miss 처리 후) `removeFromParent()` 호출

#### 1-D. 노트 낙하 계산
- [ ] `targetY` 상수: 화면 하단에서 150px 위 (판정선 Y좌표)
- [ ] `fallTime` 상수: Level별 2.0~3.0초 (4번 섹션 테이블 참조)
- [ ] `NoteComponent.update(dt)` 내 절대 좌표 계산 구현 (10-2 섹션 코드)
- [ ] `_songTime` 이전에 hitTime이 지난 노트 → Miss 처리 후 제거

---

### Phase 2 — 관절 매핑 + 판정 시스템

#### 2-A. 어깨 → 레인 이산화
- [ ] BT 입력 파트 코드 확인: `PART:lShoulderEF` (어깨 굽힘/폄)
- [ ] `AngleNormalizer`로 원시 각도 → 0.0~1.0 정규화
- [ ] 정규화 값 → 레인 변환:
  ```dart
  int _angleToLane(double normalized) {
    if (normalized < 0.33) return 0; // Left
    if (normalized < 0.66) return 1; // Center
    return 2;                         // Right
  }
  ```
- [ ] 레인 변경 시 응원봉 X좌표를 `MoveEffect.to()`로 부드럽게 이동 (0.1초)
- [ ] 레인 X좌표 상수 설정: `laneX = [size.x*0.25, size.x*0.5, size.x*0.75]`

#### 2-B. 팔꿈치 → 스윙 감지
- [ ] `_prevElbowAngle` 변수 선언
- [ ] 매 프레임 velocity 계산: `_elbowVelocity = (current - _prev) / dt`
- [ ] `_prevElbowAngle = currentAngle` 업데이트
- [ ] `_elbowVelocity > swingThreshold && !_isHitting` 조건으로 타격 발동
- [ ] `_isHitting = true`, `_hitCooldownTimer = 0.3` 설정
- [ ] `update(dt)`에서 `_hitCooldownTimer -= dt; if <= 0 → _isHitting = false`

#### 2-C. 판정 분기
- [ ] 현재 레인의 `_activeNotes`에서 가장 hitTime이 가까운 노트 탐색
- [ ] `timeDiff = (_songTime - note.hitTime).abs()` 계산
- [ ] 분기 처리:
  ```dart
  if (timeDiff < perfectWindow) → _onPerfect(note)
  else if (timeDiff < goodWindow) → _onGood(note)
  else → _onMiss()
  ```
- [ ] `_onPerfect()`: score += 100 * comboMultiplier, combo++, feverGauge += 5
- [ ] `_onGood()`: score += 50, combo++, feverGauge += 2
- [ ] `_onMiss()`: combo = 0, feverGauge -= 10 (min 0), lifeCount--
- [ ] `_maxCombo` 갱신: `if (combo > _maxCombo) _maxCombo = combo`
- [ ] `lifeCount <= 0` → `_gameOver()` 호출

---

### Phase 3 — 에셋 제작 + 연출 구현

#### 3-A. AI 이미지 생성 (8번 섹션 프롬프트 사용)
- [ ] `bg_trot_stage.png` — 경연 무대 배경 (1920×1080, 유지)
- [ ] `singer_avatar.png` — 흰 슈트 한국인 가수 (512×512, 초록 배경)
- [ ] `cursor_stick.png` — 하늘색 LED 응원봉 (256×512, 초록 배경)
- [ ] `note_heart.png` — 홍색+금색 하트 (256×256, 초록 배경)
- [ ] `hit_effect.png` — 하트+금색 파티클 폭발 (512×512, **검정** 배경)
- [ ] `target_zone.png` — 골드 판정 링 (256×256, **검정** 배경)
- [ ] `lane_line.png` — 홍색 수직 선 (128×1024, **검정** 배경)

#### 3-B. 한자 텍스트 이미지 직접 제작
- [ ] 눈누(noonnu.cc)에서 붓글씨 계열 TTF 다운로드 (상업용 무료 필터)
- [ ] 포토샵/Canva에서 `ui_text_jin.png` 제작: "眞" 금박 그라디언트 + 검정 외곽선 (512×256, 초록 배경)
- [ ] `ui_text_seon.png` 제작: "善" 흰색 + 홍색 외곽선 (512×256, 초록 배경)
- [ ] `ui_text_miss.png` 제작: "아쉬워" 회색 + 가는 외곽선 (512×256, 초록 배경)

#### 3-C. 누끼 + 최적화
- [ ] 초록 배경 7종: remove.bg 또는 포토샵으로 배경 제거 → PNG-24 저장
- [ ] 검정 배경 3종: Levels 도구로 RGB(0,0,0) 순수 검정 확인
- [ ] 전체 10종: tinypng.com 압축
- [ ] `assets/images/trot_rhythm/` 폴더에 소문자 언더스코어 네이밍으로 저장
- [ ] `pubspec.yaml` assets에 `assets/images/trot_rhythm/` 경로 추가

#### 3-D. Flutter 코드 — 스프라이트 연동
- [ ] `onLoad()`에서 `Flame.images.loadAll([...])` 모든 이미지 캐싱
- [ ] `singer_avatar` SpriteComponent 생성 → `MoveEffect` 바운스 댄스 적용
- [ ] `cursor_stick` SpriteComponent 생성 → 레인 X좌표 계산 및 이동 연결
- [ ] `note_heart` NoteComponent에 Sprite 렌더링 추가
- [ ] `target_zone` 3개 생성 (레인별) → `BlendMode.plus` 설정 → 하트 펄스 `ScaleEffect`
- [ ] `lane_line` 4개 생성 (레인 경계) → `BlendMode.plus` 설정 → 반투명 고정
- [ ] `hit_effect` 타격 시 생성 → `ScaleEffect.to(1.5)` + `OpacityEffect.to(0)` → `RemoveEffect()`
- [ ] 판정 팝업: 판정 시 해당 `ui_text_*` SpriteComponent 생성 → `ScaleEffect` + `MoveEffect` + `RemoveEffect()`

#### 3-E. 피버 시스템 구현
- [ ] `_feverGauge` 100.0 도달 시 `_isFeverTime = true`, `_feverTimer = 10.0`
- [ ] 피버 중 홍색 오버레이 `RectangleComponent` 최상단 아래에 추가 (`BlendMode.colorDodge`)
- [ ] 응원봉 색상 순환: `_feverColorTimer` 매 프레임 증가 → `sin()` 값으로 하늘색↔흰색 보간
- [ ] 하트 파티클 `ParticleSystemComponent` 추가 (배경에서 위로 솟구침, 초당 5개)
- [ ] `update(dt)`에서 `_feverTimer -= dt; if <= 0 → _isFeverTime = false` 및 오버레이 제거

#### 3-F. HUD 구현
- [ ] 점수 `TextComponent` 우상단 (size 28, 흰색, 골드 외곽선)
- [ ] 콤보 `TextComponent` 화면 중앙 상단 (size 40, 콤보 0일 때 숨김)
- [ ] 피버 게이지: 배경 `RectangleComponent` + 채우기 `RectangleComponent` (좌하단 가로 바)
- [ ] 체력 하트 5개 `SpriteComponent` 좌상단 배치 → Miss 시 하나씩 회색 처리

---

### Phase 4 — 효과음 추가

- [ ] freesound.org에서 CC0 태그 필터 후 맑은 종소리(perfect), 차임(good), 둔탁한 소리(miss), 팡파레(fever) 각 1개 다운로드
- [ ] `.ogg` 포맷으로 변환 (ffmpeg 또는 온라인 컨버터)
- [ ] `assets/audio/trot_rhythm/` 폴더에 저장 (11번 섹션 파일명 참조)
- [ ] `pubspec.yaml` assets 등록
- [ ] `onLoad()`에서 `FlameAudio.audioCache.loadAll([sfx 목록])` 호출
- [ ] `_onPerfect()`, `_onGood()`, `_onMiss()`, 피버 진입 시 각각 SFX 재생

---

### Phase 5 — GameResult 연동 + 종료 처리

- [ ] `_gameOver()` 또는 곡 종료 시 `GameResult` 객체 생성:
  ```dart
  GameResult(
    gameId: 'E4',
    score: _score,
    maxPossibleScore: _mapData.length * 100,
    accuracy: _combo / _mapData.length,
    duration: Duration(seconds: 60),
    hits: _totalHits,
    misses: _totalMisses,
  )
  ```
- [ ] `widget.onGameEnd(result)` 콜백 호출
- [ ] BT 연결 끊김 이벤트 수신 시 `_audioPlayer.pause()` + 게임 일시정지 처리

---

### Phase 6 — QA 및 튜닝

#### 6-A. 판정 튜닝
- [ ] Level 1에서 노트 낙하 속도가 3초 도달인지 실측 확인
- [ ] 어르신 반응 속도(~0.5초) 기준으로 `perfectWindow` / `goodWindow` 재조정 필요 여부 확인
- [ ] 스윙 `swingThreshold` 값: 너무 낮으면 오판정, 너무 높으면 Miss 과다 → 수치 튜닝

#### 6-B. 오디오 밸런싱
- [ ] BGM 0.7 볼륨에서 SFX가 묻히지 않는지 확인
- [ ] 모바일 기기 스피커에서 음원 깨짐 여부 확인
- [ ] SFX가 타격 즉시(지연 없이) 재생되는지 확인 (캐싱 확인)

#### 6-C. 성능 확인
- [ ] 피버 타임 파티클 30개 이상 시 FPS 드랍 여부 확인 → 최대 개수 제한 설정
- [ ] 노트 20개 동시 화면에 있을 때 렌더링 부하 확인
- [ ] 앱 가로 모드 고정 (`AndroidManifest.xml` screenOrientation) 확인

#### 6-D. 최종 흐름 검증
- [ ] 게임 시작 → BGM 재생 → 노트 낙하 → 판정 → 종료 → GameResultScreen 전환 전체 흐름 확인
- [ ] `GameResult` 반환값 (score, maxCombo, accuracy, angleHistory) 정상 채워지는지 확인
- [ ] Brunnstrom Stage 2(가장 낮은 단계) 설정 시 모터 CPM 보조가 정상 작동하는지 확인

---

### Phase 7 — 음악 교체 (나중에 진행) ⏳

> Phase 1~6 완료 후, 음악이 결정되면 진행.  
> 플레이스홀더(`trot_bgm_placeholder.mp3`, `trot_map_placeholder.json`)를 실제 음원으로 교체하는 작업.

#### 7-A. Suno BGM 생성
- [ ] Suno(suno.ai) 접속 → 9-1 섹션 프롬프트 입력
- [ ] 120 BPM 트로트 스타일 3가지 버전 생성 후 1곡 선택
- [ ] MP3 다운로드 → `assets/audio/trot_rhythm/trot_bgm_01.mp3` 저장 (플레이스홀더 교체)

#### 7-B. BPM 및 비트 추출
- [ ] Tunebat.com에 MP3 업로드 → BPM 수치 기록
- [ ] Python librosa로 비트 타임스탬프 배열 추출:
  ```python
  import librosa
  y, sr = librosa.load('trot_bgm_01.mp3')
  tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
  times = librosa.frames_to_time(beats, sr=sr).tolist()
  print(f"BPM: {tempo:.1f}, beats: {len(times)}")
  ```
- [ ] 추출된 첫 10개 타임스탬프를 BGM과 함께 수동 청취로 검증

#### 7-C. 실제 노트 맵 생성
- [ ] 비트 타임스탬프 + lane 할당 → `assets/maps/trot_map_01.json` 생성
  - 초안: 모든 노트 lane=1(center)
  - 이후: 강박=center, 약박=left/right 분산
- [ ] 게임 시간(60초) 범위로 자르기
- [ ] `trot_map_placeholder.json` → `trot_map_01.json` 으로 코드 내 참조 교체
- [ ] 실제 음원으로 게임 전체 흐름 재검증 (Phase 6-D 반복)

---

## 14. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| `y += speed * dt`로 노트 낙하 | 오디오 싱크 기반 절대 좌표 계산 (10-2 섹션) 사용 |
| 팔꿈치 특정 각도 도달로 스윙 판정 | 각도 **변화량(velocity)** 임계치로 판정해야 천천히 뻗는 것과 구분 |
| 타격 후 디바운싱 미구현 | `_hitCooldownTimer` 0.3초로 연속 판정 방지 |
| 효과음 타격 시 파일 로드 | `FlameAudio.audioCache.loadAll()`로 `onLoad`에서 미리 캐싱 |
| 한자 텍스트를 기본 폰트로 렌더링 | PNG 이미지 에셋으로 굽거나 TTF 폰트 파일을 직접 로드 |

---

## 15. 렌더 순서 (Z-Depth)

```
1.  배경 무대 (bg_trot_stage)
2.  가수 아바타 (singer_avatar) — 댄스 애니메이션 중
3.  피버 타임 홍색 오버레이 (ColorDodge, 피버 시에만)
4.  레인 구분선 (lane_line / BlendMode.plus)
5.  판정선 하트 구역 (target_zone / BlendMode.plus)
6.  낙하하는 하트 노트들 (note_heart)
7.  응원봉 커서 (cursor_stick)
8.  타격 하트 파티클 (hit_effect / BlendMode.plus)
9.  판정 텍스트 팝업 (ui_text_jin / ui_text_seon / ui_text_miss)
10. HUD 고정 요소 (점수, 콤보, 피버 게이지, 체력)
```
