# [E4] 트로트 리듬 응원 게임 (Trot Rhythm Action) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-10  
**파일**: `lib/games/games/trot_rhythm_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 현재 상태 (2026-06-10 기준)

| 항목 | 상태 |
|------|------|
| 기본 리듬 게임 뼈대 (노트 스폰, 싱크 유지) | ❌ 미완성 |
| 어깨 관절(좌우 이동) ↔ 레인 매핑 알고리즘 | ❌ 미완성 |
| 팔꿈치 관절(속도 기반) ↔ 타격(Hit) 스윙 감지 | ❌ 미완성 |
| Perfect/Good/Miss 시간차 판정 및 콤보 로직 | ❌ 미완성 |
| 스프라이트 통합 (무대, 미러볼, 아바타, 노트, 응원봉) | ❌ 미완성 |
| 타격 이펙트 및 피버(Fever) 타임 시각 연출 | ❌ 미완성 |
| UI 및 판정 텍스트 팝업 (얼씨구!, 좋지!) | ❌ 미완성 |
| 트로트 오디오 ↔ 노트 맵(Map) 데이터 동기화 | ❌ 미완성 |
| 추임새(SFX) 재생 및 BGM 볼륨 밸런싱 | ❌ 미완성 |
| Brunnstrom 난이도 ↔ 판정 범위(Tolerance) 연동 | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

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
  │         ├── Perfect (±0.15s) → 콤보 증가, 점수++
  │         ├── Good (±0.3s) → 콤보 증가, 점수+
  │         └── Miss (초과) → 콤보 초기화, 체력 감소
  ├── 5. 피버 상태 업데이트 (_updateFever)
  │     └─ 콤보 수에 비례하여 피버 게이지 증가, 100% 도달 시 미러볼/조명 강화
  └── 6. 애니메이션 업데이트 (가수 흔들림, 폭죽 파티클, 팝업 텍스트)
  ↓
render(canvas)
  ├── 1. 배경: 화려한 7080 트로트 무대 (bg_trot_stage)
  ├── 2. 조명: 미러볼 (disco_ball), 네온사인
  ├── 3. 아바타: 무대 중앙의 가수 (singer_avatar)
  ├── 4. 레인: 수직 구분선 (lane_line) 및 판정선 (target_zone)
  ├── 5. 노트: 떨어지는 음표 및 반짝이 (note_music)
  ├── 6. 커서: 야광 응원봉 (cursor_stick)
  ├── 7. 이펙트: 타격 폭죽 파티클 (hit_effect / BlendMode.plus)
  ├── 8. 팝업 UI: "얼씨구!", "좋지!" 텍스트 팝업 (ui_text_*)
  └── 9. HUD: 콤보 수, 점수, 피버 게이지 (fever_gauge_fill)
```

---

## 2. 핵심 상태 변수

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

## 3. 난이도 및 생체역학 파라미터

어르신의 인지/반응 속도를 고려하여 일반 리듬게임보다 판정 시간을 매우 관대하게 둡니다.

```dart
// Brunnstrom 난이도 기반 파라미터 설정
// Level이 낮을수록 판정은 후하고 노트 떨어지는 속도는 느림
double get noteSpeedMultiplier => 0.5 + (config.difficultyLevel * 0.1); 

// 판정 허용 시간 (초)
double get perfectWindow => 0.25 - (config.difficultyLevel * 0.02); // 기본 ±0.15초 (Level 5 기준)
double get goodWindow => 0.4 - (config.difficultyLevel * 0.02);   // 기본 ±0.30초 (Level 5 기준)

// 스윙 감지 민감도 (팔꿈치를 얼마나 빨리 펴야 타격으로 인정할 것인가)
double get swingThreshold => 15.0 / config.difficultyLevel; // 초당 각도 변화량
```

| Level | 노트 낙하 속도 | 판정선 도달 시간 | Perfect 허용치 | Good 허용치 |
|-------|-------------|---------------|--------------|-------------|
| 1 | 매우 느림 | 화면 생성 후 3초 | ±0.23초 (매우 넉넉) | ±0.38초 |
| 3 | 보통 | 화면 생성 후 2.5초| ±0.19초 (보통) | ±0.34초 |
| 5 | 다소 빠름 | 화면 생성 후 2초 | ±0.15초 (엄격) | ±0.30초 |

---

## 4. 스프라이트 (에셋) 목록 요약

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션 필요 여부 |
|--------|-----------|----------------|---------|------------------|
| `bg_trot_stage.png` | 1920×1080 | 화면 전체 | **유지** | 고정 |
| `disco_ball.png` | 512×512 | 150×150 px | 투명화 | 회전 (Effect API) |
| `singer_avatar.png`| 512×512 | 250×400 px | 투명화 | 둥둥 떠다니기 (Hover) |
| `lane_line.png` | 128×1024 | 20×800 px | **검정 유지** | 투명도 반투명 고정 |
| `target_zone.png` | 256×256 | 150×150 px | **검정 유지** | 펄스 (Effect API) |
| `note_music.png` | 256×256 | 100×100 px | 투명화 | 수직 낙하 로직 |
| `cursor_stick.png` | 256×512 | 100×250 px | 투명화 | 좌우 이동 및 스윙 애니 |
| `hit_effect.png` | 512×512 | 200×200 px | **검정 유지** | 순간 확대 & 페이드아웃 |
| `ui_text_perfect.png`| 512×256| 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_good.png` | 512×256| 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_miss.png` | 512×256| 200×100 px | 투명화 | 팝업 (떨어짐 연출) |

---

## 5. 애니메이션 연출 및 구현 가이드 (상세)

Flame 엔진 기능을 적극 활용하여 화려한 "뽕짝" 무대 연출을 구현합니다.

### 5-1. 트랜스폼 이펙트 (Flame Effects API)
*   **미러볼 회전**: `disco_ball`에 `RotateEffect.by(tau, EffectController(duration: 4.0, infinite: true))` 적용. 피버 타임 시 `duration`을 2.0으로 덮어씌워 회전 속도 2배.
*   **아바타 댄스**: `singer_avatar`에 `MoveEffect.by(Vector2(0, 15), EffectController(duration: 0.5, infinite: true, alternate: true))` (무릎 바운스 느낌) 적용.
*   **판정선 빛 펄스**: `target_zone`에 `OpacityEffect.to(0.3, EffectController(duration: 0.5, infinite: true, alternate: true))` 적용. (BlendMode.plus 상태)
*   **타격 텍스트 팝업**: 판정 시 `ui_text_perfect`를 생성하고 `ScaleEffect.to(1.2)`와 `MoveEffect.by(Vector2(0, -50))`을 동시 재생 후 `RemoveEffect()`로 제거.

### 5-2. 스윙 애니메이션 (타격 모션)
*   응원봉(`cursor_stick`)은 기본적으로 수직 서 있습니다.
*   타격 감지 시: `SequenceEffect`를 통해 `RotateEffect.by(-0.5)` (뒤로 젖힘) -> `RotateEffect.by(1.0)` (앞으로 강하게 휘두름) -> `RotateEffect.to(0.0)` (원상복구) 를 0.15초 안에 매우 빠르게 재생하여 때리는 손맛을 시각화합니다.

### 5-3. 피버 타임 (Fever Time) 연출
*   **컬러 오버레이**: 화면 전체 크기의 `RectangleComponent`를 최상단 렌더링 바로 아래 두고, `Paint()..color = Color(0x66FF00FF)..blendMode = BlendMode.colorDodge` 적용. 이 색상을 무지개색으로 순환시킵니다.
*   **파티클 폭주**: 배경에서 위로 솟구치는 반짝이 파티클(`ParticleSystemComponent`) 지속 발생.

---

## 6. 스프라이트 제작 및 최적화 파이프라인 (매우 상세)

이 섹션은 위 에셋들을 어떻게 생성하고 다듬어 게임에 넣는지 세분화된 과정입니다.

### 단계 1: AI 이미지 생성 (DALL-E 3 등 활용)
아래 7번에 있는 프롬프트를 사용하여 1:1 또는 지정 비율 이미지를 뽑습니다.
*   오브젝트(가수, 응원봉, 음표, 텍스트 팝업)는 완벽한 배경 제거(누끼)를 위해 **초록 배경(#00FF00)** 지시문을 필수로 넣습니다.
*   빛, 네온사인, 타격 폭죽 등은 광원을 보존하기 위해 **순수 검정 배경(#000000)** 지시문을 넣고 배경 제거를 생략합니다.

### 단계 2: 타이포그래피 (텍스트 이미지) 수동 제작
*   "얼씨구!", "좋지!" 등의 팝업 텍스트는 AI가 한글을 그리지 못하므로 포토샵/일러스트레이터에서 직접 제작합니다.
*   어르신들이 보기 편하게 굵고 가독성 높은 궁서체/복고 폰트를 사용하고, 외곽선(Stroke)과 금박 질감(Gradient)을 두껍게 입힌 후 초록 배경 PNG로 저장합니다.

### 단계 3: 배경 제거 (누끼) 및 알파 마스킹
*   `remove.bg` 나 포토샵 '피사체 선택'으로 초록 배경을 지웁니다.
*   미러볼 주변이나 응원봉 끝에 남은 초록 픽셀(Color Fringe)은 지우개로 말끔히 제거합니다.
*   가수 아바타의 머리카락 등 복잡한 부분은 알파 마스크를 씌워 투명도를 다듬고 PNG-24로 내보냅니다.

### 단계 4: 빛/이펙트 에셋 처리 (BlendMode.plus 셋업)
*   검정 배경으로 뽑은 `target_zone`, `hit_effect`, `lane_line`은 **절대 배경을 지우면 안 됩니다**.
*   색상 교정(Levels) 도구로 검정색 영역이 순수 RGB(0,0,0)인지 확인합니다. (미세한 회색이 섞여 있으면 게임 렌더링 시 네모난 박스 테두리가 보입니다.)

### 단계 5: 리사이징 및 압축 최적화 (TinyPNG)
*   무대 배경은 1920x1080 그대로 두되, 낙하하는 노트(`note_music`)나 팝업 텍스트는 화면 렌더링 사이즈에 맞게 각각 128x128, 256x256 등으로 축소합니다.
*   `tinypng.com`을 통해 용량을 압축하여 게임의 초기 로딩 속도와 램(RAM) 점유율을 줄입니다.

### 단계 6: 게임 적용
*   완성된 이미지는 `assets/images/trot_rhythm/` 에 넣고 소문자/언더스코어 네이밍 규칙(`note_music.png` 형태)을 엄수합니다.
*   `pubspec.yaml` 등록 후 `Flame.images.loadAll()` 로 일괄 캐싱합니다.

---

## 7. AI 이미지 생성 프롬프트

**공통 스타일 지시문**: `retro Korean trot music stage style, 1980s vintage, highly colorful and flashy, shiny neon, cartoon rendering style, cel-shaded, bold black outlines, mobile rhythm game asset`

### 초록 배경 (투명화용) 프롬프트
`, solid bright lime green background (#00FF00), square 1:1 format`

*   **가수 아바타 (singer_avatar)**: `A charismatic retro trot singer character wearing a sparkly sequin jacket and holding a vintage microphone, striking an enthusiastic singing pose, full body, solid bright lime green background`
*   **미러볼 (disco_ball)**: `A shiny silver disco ball reflecting colorful lights, perfectly round, highly detailed reflections, solid bright lime green background`
*   **노트 음표 (note_music)**: `A chunky colorful musical note symbol, 3D shiny appearance, cute and stylized, solid bright lime green background`
*   **응원봉 커서 (cursor_stick)**: `A glowing magical concert light stick (cheering stick), bright neon pink and yellow colors, chunky design, solid bright lime green background`

### 검정 배경 (블렌딩 모드용) 프롬프트
`, pure black background (#000000) for screen blend mode, no solid fill inside, soft inner radiance`

*   **레인 구분선 (lane_line)**: `A tall vertical straight glowing neon line, magenta color, soft outer glow, 1:8 aspect ratio, pure black background`
*   **판정선 구역 (target_zone)**: `A glowing circular target ring, bright cyan neon light, hollow inside, pure black background`
*   **타격 이펙트 (hit_effect)**: `A burst of abstract glowing neon sparks and starbursts, bright yellow and pink colors, exploding outward like a firework, pure black background`

---

## 8. 리듬 게임 특화 로직 가이드 (매우 중요)

리듬 게임은 일반 액션 게임과 달리 프레임 드랍(dt)에 의존하면 싱크가 밀립니다. 아래 공식을 엄수합니다.

### 8-1. 오디오 싱크(Audio Sync) 기반 시간 갱신
```dart
// update(dt) 내부
// dt를 더하는 대신 오디오 플레이어의 현재 위치를 직접 폴링합니다.
if (_audioPlayer.state == PlayerState.playing) {
  _songTime = _audioPlayer.getCurrentPosition().inMilliseconds / 1000.0;
}
```

### 8-2. 노트 위치(Y 좌표) 절대 계산
노트의 `update(dt)` 에서는 `position.y += speed * dt` 를 **사용하지 않습니다**.
```dart
// NoteComponent의 update(dt) 내부
// 판정선의 Y좌표(targetY)와 노트가지정된 타격 시간(hitTime)을 이용해 역산합니다.
// fallTime(2초) 전부터 화면 꼭대기에서 생성되어 떨어집니다.
double timeDiff = hitTime - gameRef._songTime;
double fallDistance = gameRef.size.y; // 화면 높이만큼 낙하
double currentY = gameRef.targetY - (timeDiff * (fallDistance / fallTime));

position.y = currentY;
```

---

## 9. 오디오 및 SFX 타이밍

| 구분 | 이벤트 (애니메이션 동기화) | 파일명 | 볼륨 |
|---|--------|------|------|
| **BGM** | 게임 시작 시 재생 | `Trot_Festival.mp3` | 0.7 (효과음 강조를 위해 낮춤) |
| **SFX** | 퍼펙트(Perfect) 타격 시 | `hit_perfect_janggo.ogg` | 1.0 (찰진 장구/꽹과리 소리) |
| **SFX** | 퍼펙트 보이스 팝업 시 | `voice_ulsigu.ogg` | 1.0 ("얼씨구!") |
| **SFX** | 굿(Good) 타격 시 | `hit_good_tambourine.ogg` | 1.0 (템버린 소리) |
| **SFX** | 굿 보이스 팝업 시 | `voice_johji.ogg` | 1.0 ("좋지!") |
| **SFX** | 미스(Miss) 발생 시 | `hit_miss_drum.ogg` | 0.8 (둔탁한 북 소리) |
| **SFX** | 피버 타임(Fever) 진입 시 | `fever_start_gong.ogg` | 1.0 (웅장한 징 소리) |

---

## 10. 작업 체크리스트

### Phase 1 — 리듬 코어 로직 및 싱크 맞추기
- [ ] FlameAudio를 활용한 BGM 재생 및 `getCurrentPosition` 동기화 로직 (`_songTime`) 구현
- [ ] 맵 데이터(JSON 배열) 파싱 및 시간에 맞춰 `NoteComponent` 스폰 로직
- [ ] 오디오 시간에 종속된 절대 좌표 노트 낙하 공식 구현 (8-2 섹션 참조)

### Phase 2 — 관절 데이터 매핑 및 판정 시스템
- [ ] 어깨 데이터(예: 수평 모음/벌림)를 3개의 레인 인덱스(0, 1, 2)로 이산화(분할)하여 응원봉 X 좌표 이동
- [ ] 팔꿈치 데이터의 1차 미분(Velocity) 계산 로직 및 임계치(`swingThreshold`) 감지 (타격 발동)
- [ ] 타격 발동 시 동일 레인 내 최하단 노트의 `hitTime`과 현재 `_songTime` 간의 오차(Diff) 계산 및 판정 분기

### Phase 3 — 에셋 적용 및 트랜스폼 연출
- [ ] 11종의 모든 스프라이트 파일 `_loadImg()`로 캐싱 및 렌더링 트리 구성
- [ ] 판정선 Glow 맥박 애니메이션 (`OpacityEffect`) 및 미러볼 회전 (`RotateEffect`)
- [ ] 타격 시 응원봉 스윙 모션 연출 (`SequenceEffect`)

### Phase 4 — 이펙트, 사운드, 피버(Fever) 연동
- [ ] 타격 결과에 따른 BGM 위에 오버레이 되는 SFX 및 보이스 동시 재생
- [ ] `hit_effect` (BlendMode.plus)와 타격 텍스트 팝업 (Scale/Move/Opacity 콤보 이펙트) 생성
- [ ] 콤보 카운터 구현, 피버 게이지 100% 도달 시 화면 오버레이 색상 순환 로직

### Phase 5 — 최적화 및 QA (테스트)
- [ ] 판정 윈도우(Tolerance)가 너무 빡빡하여 어르신이 Miss만 내지 않는지 시연 테스트 및 수치 튜닝
- [ ] BGM 사운드가 모바일 기기 스피커에서 깨지지 않고 타격음과 섞이는지 밸런스 튜닝
- [ ] 파티클과 이미지 수가 많아질 때 프레임 드랍이 없는지 에셋 해상도 검토

---

## 11. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 노트를 `y += speed * dt` 로 떨어뜨림 | 리듬게임의 금기. 8번 섹션의 오디오 시간 기반 절대 좌표 계산식을 사용해야 시간이 갈수록 싱크가 어긋나는 것을 방지함. |
| 팔꿈치 스윙을 단순히 '특정 각도 도달'로만 판정 | 환자가 천천히 팔을 뻗고 있는 상태와 순간적으로 내뻗어 타격하는 것을 구분하지 못함. **각도의 변화량(속도)**을 트리거로 사용해야 함. |
| 타격 후 중복 타격 방지 미구현 (디바운싱 누락) | 속도 임계치를 넘었다고 매 프레임 타격 판정을 내리면 한 노트에 10연타 판정이 남. 0.3초 정도의 `_hitCooldownTimer`를 두어야 함. |
| 효과음(SFX) 로딩 지연으로 타격감이 밀림 | 타격 순간에 파일을 읽으면 안 됨. `FlameAudio.audioCache.loadAll()`로 게임 시작(onLoad) 전에 모든 타격음을 메모리에 캐싱. |
| 한글 텍스트(팝업 UI)를 기본 폰트로 렌더링 | 글씨가 작고 얇아 어르신이 읽기 힘듦. 텍스트를 이미지 에셋(PNG)으로 굽거나 굵직한 커스텀 폰트 파일(TTF)을 로드하여 사용. |

---

## 12. 렌더 순서 (Render Order - Z Depth)

```dart
// 리듬 게임은 떨어지는 노트와 시각 피드백의 가독성이 생명이므로 레이어(Z-index)가 매우 중요함
1. 배경 무대 전체 (bg_trot_stage)
2. 미러볼 (disco_ball) - 천장
3. 가수 아바타 (singer_avatar) - 무대 중앙 뒤편 (Hover 애니메이션 중)
4. 피버 타임 색상 오버레이 (반투명 ColorDodge 등) - 무대 전체 조명 효과
5. 레인 구분선 (lane_line / BlendMode.plus)
6. 판정선 타겟 구역 (target_zone / BlendMode.plus)
7. 낙하하는 음표 노트들 (note_music) - 레인 위
8. 응원봉 커서 (cursor_stick) - 노트보다 항상 위에 위치하여 타격 느낌 강조
9. 타격 폭죽 파티클/이펙트 (hit_effect / BlendMode.plus) - 가장 번쩍여야 함
10. 판정 텍스트 팝업 (ui_text_* / "얼씨구!") - 이펙트 위로 튀어오름
11. UI 고정 요소 (점수, 콤보 수, 피버 게이지, 남은 체력)
```
