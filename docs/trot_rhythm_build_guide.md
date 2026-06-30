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

### Phase 1 — Suno 음악 + 노트 맵
- [ ] Suno로 트로트 BGM 생성 (Pro 플랜 권장)
- [ ] BPM 추출 및 librosa/Sonic Visualiser로 비트 타임스탬프 추출
- [ ] `assets/maps/trot_map_01.json` 노트 맵 생성

### Phase 2 — 리듬 코어 로직
- [ ] FlameAudio BGM 재생 + `getCurrentPosition` 동기화 (`_songTime`)
- [ ] JSON 노트 맵 파싱 및 `NoteComponent` 스폰
- [ ] 오디오 시간 기반 절대 좌표 낙하 계산 (10-2 섹션)

### Phase 3 — 관절 매핑 + 판정
- [ ] 어깨 각도 → 3레인(0/1/2) 이산화 → 응원봉 X 이동
- [ ] 팔꿈치 velocity 계산 + `swingThreshold` 감지
- [ ] 眞/善/아쉬워 판정 분기 + 콤보 로직

### Phase 4 — 에셋 + 연출
- [ ] 가수 아바타, 응원봉, 하트 노트 스프라이트 제작 (8번 섹션 프롬프트)
- [ ] 眞/善 한자 텍스트 이미지 제작 (포토샵, 붓글씨 폰트, 금박)
- [ ] 판정선 하트 펄스, 스윙 SequenceEffect, 피버 오버레이 구현

### Phase 5 — QA
- [ ] 판정 윈도우 튜닝 (어르신 반응 속도 기준)
- [ ] BGM + SFX 볼륨 밸런싱
- [ ] 파티클 증가 시 프레임 드랍 여부 확인

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
