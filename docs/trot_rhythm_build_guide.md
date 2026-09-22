# [E4] 트로트 리듬 응원 게임 (Trot Rhythm Action) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-29  
**파일**: `lib/games/games/trot_rhythm_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 현재 상태 (2026-06-29 기준)

| 항목　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 | 상태　　　　 |
| --------------------------------------------------------------------| --------------|
| 팔꿈치 굴곡/신전 ↔ 응원단장 따라하기 게임 뼈대　　　　　　　　　　 | ✅ 완료　　　 |
| Perfect/Good/Miss 판정 및 콤보/피버 시스템　　　　　　　　　　　　 | ✅ 완료　　　 |
| Suno 생성 음원 (`오늘은 달리자.mp3`, 136 BPM) 탑재　　　　　　　　 | ✅ 완료　　　 |
| 비트 분석 기반 노트/큐 맵 (`trot_map_01.json`, 98 큐) 생성 및 연동 | ✅ 완료　　　 |
| 오디오 싱크 기반 리얼타임 시간 갱신　　　　　　　　　　　　　　　　| ✅ 완료　　　 |
| 추임새/판정(SFX) 효과음 재생 및 믹싱 연동　　　　　　　　　　　　 | ✅ 완료　　　 |
| 고품질 PNG 스프라이트 에셋 통합　　　　　　　　　　　　　　　　　　| 🔄 진행 예정 |

---

## 1. 비주얼 컨셉 — 미스터트롯/미스트롯 레퍼런스

### 1-1. 조사 결과 요약

| 항목 | 미스터트롯 스타일 | 게임 적용 방향 |
|------|----------------|-------------|
| **배경 색조** | 흰색/크림 (시즌3) · 아이보리+홍색 (미스트롯4) | 크림 화이트 배경 + 홍색 포인트 조명 |
| **캐릭터** | 흰 슈트 착용 한국인 남성 트로트 가수 | 흰 슈트 or 개량 한복 가수 아바타 |
| **판정 UI** | 심사위원 의자 옆 하트 발광 디스플레이 점등 | 하트 발광 팝업 → 판정 피드백 |
| **순위 텍스트** | 미스터트롯 스타일 타이포그래피 | PERFECT=완벽해!, GOOD=좋아!, MISS=아쉬워 |
| **응원봉** | 하늘색(스카이블루) LED · 6가지 애니메이션 | 하늘색 LED 응원봉 커서 |
| **팬덤 연출** | 공식 응원봉 집단 점멸, 콘서트 레이저쇼 | 피버 타임: 응원봉 전체 점멸 |
| **전통 요소** | 개량 한복, 한국적 색감 | 한글 타이포그래피 · 전통 색감 |

### 1-2. 컬러 팔레트

```
배경:    #FFFAF0 (크림 화이트)    — 미스터트롯3 주조색
포인트:  #C8102E (홍색)           — 미스트롯4 한복 색
응원봉:  #87CEEB (스카이블루)     — 임영웅 응원봉 대표색
보조:    #1A1A1A (딥 블랙)        — 미스트롯4 한복 검정
골드:    #D4AF37 (금색)           — 한글 텍스트 금박 효과
```

### 1-3. 판정 텍스트 스타일

| 판정 | 텍스트 | 스타일 |
|------|--------|--------|
| Perfect | **완벽해!** | 금박, 대형, 위로 솟구침 |
| Good | **좋아!** | 흰색, 중형, 팝업 |
| Miss | **아쉬워** | 회색, 소형, 아래로 떨어짐 |

---

## 2. 탑재 음원 상세 정보 ("오늘은 달리자")

### 2-1. 기본 메타데이터
| 항목　　　　　　　　| 사양 / 내용　　　　　　　　　　　　　　　　　　　|
| ---------------------| --------------------------------------------------|
| **곡명**　　　　　　| 오늘은 달리자　　　　　　　　　　　　　　　　　　|
| **아티스트 / 출처** | radiantzithers651 (Suno AI 생성 음원)　　　　　　|
| **장르 / 분위기**　 | 세미 트로트 (경쾌하고 신나는 응원곡 스타일)　　　|
| **템포 (BPM)**　　　| **136 BPM** (4/4 박자)　　　　　　　　　　　　　 |
| **1비트(박) 길이**　| 약 **0.4412초** (441.2 ms)　　　　　　　　　　　 |
| **1마디(4박) 길이** | 약 **1.7648초** (1764.8 ms)　　　　　　　　　　　|
| **총 음원 길이**　　| **3분 15초** (195.84초)　　　　　　　　　　　　　|
| **연동 파일 경로**　| `assets/audio/trot_rhythm/오늘은 달리자.mp3`　　 |
| **비트 맵 파일**　　| `assets/maps/trot_map_01.json` (총 98개 큐/노트) |

### 2-2. 악곡 구조 및 큐(Cue) 타임라인
곡의 기승전결에 맞춰 재활 훈련의 난이도와 강도가 유기적으로 조절되도록 구성되어 있습니다:

| 구간 (Section) | 시간대 (초) | 큐 개수 | 운동 강도 및 게임 연출 |
|----------------|------------|---------|---------------------|
| **Intro (전주)** | 0:00 ~ 0:14 (0.0s ~ 14.5s) | 4개 | 완만하고 넓은 좌우 팔 흔들기 (워밍업) |
| **Verse 1 (1절 도입)** | 0:14 ~ 0:35 (14.5s ~ 35.7s) | 12개 | 정박자 중심의 기본 팔꿈치 굴곡/신전 동작 |
| **Pre-Chorus 1 (1절 빌드업)** | 0:35 ~ 0:49 (35.7s ~ 49.8s) | 8개 | 박자 간격이 좁아지며 리듬 고조 (집중도 유도) |
| **Chorus 1 (1절 후렴구)** | 0:49 ~ 1:17 (49.8s ~ 77.6s) | 16개 | 신나는 클라이맥스! 10콤보 달성 시 **🔥 FEVER 진입** |
| **Verse 2 (2절 도입)** | 1:17 ~ 1:38 (77.6s ~ 98.8s) | 12개 | 안정적인 템포로 호흡 가다듬기 (중간 휴식 효과) |
| **Pre-Chorus 2 (2절 빌드업)** | 1:38 ~ 1:52 (98.8s ~ 112.9s) | 8개 | 점진적 속도 증가 및 타격감 강화 |
| **Chorus 2 (2절 후렴구)** | 1:52 ~ 2:20 (112.9s ~ 140.7s) | 16개 | 2차 피버 타임 기회 및 고득점 콤보 구간 |
| **Bridge / Solo (간주)** | 2:20 ~ 2:41 (140.7s ~ 161.9s) | 8개 | 변칙적인 리듬 유도로 인지적 반응성 훈련 |
| **Final Chorus & Outro (최종 후렴 & 후주)** | 2:41 ~ 3:15 (161.9s ~ 195.8s) | 14개 | 최종 마무리 스트레칭 및 훈련 완료 피드백 |
| **합계** | **총 195.84초** | **총 98개** | **완곡 시 약 3분 15초의 전신/상지 리듬 재활 운동** |

### 2-3. 재활 훈련(RAS) 관점의 설계 특징
1. **리듬적 청각 자극 (Rhythmic Auditory Stimulation, RAS)**:
   - 136 BPM의 빠른 세미 트로트 비트는 뇌졸중 및 상지 기능 저하 환자의 동작 개시와 리듬 동기화(Entrainment)를 유도하여 움직임의 규칙성을 높여줍니다.
2. **동작 완급 조절 (Pacing)**:
   - 전주(Intro)와 간주(Bridge)에서 속도를 늦추고 후렴(Chorus)에서 동작을 고조시켜 심폐 및 관절 피로도 누적을 예방합니다.
3. **오디오 싱크 절대 동기화 (`_songTime`)**:
   - `AudioPlayer`의 실제 재생 시간을 기준으로 매 프레임 동기화되므로, 프레임 드랍이 발생해도 음악과 응원단장의 모션/노트 판정이 절대 어긋나지 않습니다.

### 2-4. 학술적·임상적 근거 (Rhythmic Auditory-Motor Entrainment)

리듬 동기화(Entrainment)를 활용한 상지 재활 훈련은 신경학적 음악치료(NMT) 및 신경재활의학 분야에서 다수의 최고 권위 저널(Stroke 등)을 통해 입증된 검증된 프로토콜입니다.

| 연구 / 출처 | 대상 및 프로토콜 | 주요 임상 결과 및 의의 |
|------------|----------------|----------------------|
| **Thaut et al. (2002)**<br>_Stroke (AHA Journal)_ | 뇌졸중 편마비 환자 대상<br>리듬 청각 큐(Cued vs Noncued)<br>팔 도달(Arm reaching) 훈련 | • **동작 매끄러움(Smoothness) 유의미한 향상**<br>• 다중 가속 곡선이 정상인과 유사한 **단일 종형 가속도(Single-peaked velocity)**로 전환<br>• 이두근-삼두근의 비정상적 동시 수축(Co-contraction) 감소 및 길항근 타이밍 오차 개선 |
| **Malcolm et al. (2009)**<br>_J. Stroke Cerebrovasc. Dis._ | 만성 뇌졸중 환자 대상<br>리듬 청각-운동 훈련 (RAMT) | • **FMA(Fugl-Meyer) 및 WMFT(Wolf Motor Function) 점수 유의미한 향상**<br>• 경두개 자기자극술(TMS)을 통해 뇌 피질의 **운동 신경가소성(Cortical Reorganization)** 실측 입증 |
| **Whitall et al. (2000)**<br>_Stroke (AHA Journal)_ | 만성 편마비 환자 대상<br>양측 상지 청각 리듬 반복 훈련<br>(BATRAC 프로토콜) | • 리듬 큐 반복 훈련 시 단순 자가 운동 대비 **상지 근력, 관절 가동 범위(ROM), 일상생활 수행력(ADL) 대폭 향상** |

> **치료적 기전 요약**: 청각 신호(비트)는 뇌의 청각 피질뿐 아니라 소뇌·기저핵·전운동피질을 10~20ms 이내에 즉각 자극하여 손상된 운동 개시(Movement Initiation)를 보조하고, 운동학적 흔들림(Kinematic Variability)을 줄여 일관된 관절 훈련을 가능하게 합니다.

---

## 3. 게임 구조 한눈에 보기

> **실제 설계**: 3레인 낙하노트가 아니라 **측면 "응원단장 따라하기"**. **어깨 각도 1개(lShoulderEF)** 로,
> 응원단장이 시연하는 목표 각도에 플레이어가 팔을 맞추면 판정. 레인·낙하노트 없음. (어깨+팔꿈치 2자유도는 추후)

```
입력: BT 어깨 굴곡/신전 각도(lShoulderEF) → 0.0~1.0 정규화 → _playerAngle
      (BT 미연결 시 하단 슬라이더 시뮬레이션)
  ↓
TrotRhythmFlameGame.update(dt)
  ├ 카운트다운(3·2·1) 종료 → BGM 재생 + _isRunning=true
  ├ _updateCue(dt): 활성 큐(_activeCue) 진행
  │   ├ moving : 응원단장 각도(_leaderAngle)를 목표(_leaderTargetAngle)로 easeInOut 보간
  │   └ holding: 오차 |_playerAngle − _leaderTargetAngle| 로 판정
  │        ├ < _perfectTol → 완벽해!  (콤보++, 점수 +100×콤보배수)
  │        ├ < _goodTol    → 좋아!    (콤보++, 점수 +50)
  │        └ 홀딩 65% 경과까지 못 맞춤 → 아쉬워 (콤보 0, 체력 −1)
  ├ _updateCrowdEnergy(dt): 콤보 비례 관객 에너지 보간
  └ 판정 팝업 알파/Y 페이드
  ↓
render(canvas)   // 절차적 도형 기본, 스프라이트 있으면 자동 교체(없으면 fallback)
  ├ (피버=콤보≥10 시) 황금 배경 펄스
  ├ 배경 무대            (bg_trot_stage)
  ├ 가수 (오른쪽)        (singer_avatar + 입/눈 표정 오버레이, 바운스)
  ├ 응원단장 (중앙)      (body_leader + 팔 리그, 다음 동작 ghost 예고)
  ├ 관객                 (audience_member + cheer_stick 흔들기)
  ├ 플레이어 (왼쪽)      (body_player + 팔 리그, 목표 ghost + 판정 링)
  ├ HUD                  (점수·콤보·체력하트5·관객에너지바·FEVER)
  └ 판정 팝업(완벽해!/좋아!/아쉬워) / 카운트다운 오버레이
```

---

## 4. 핵심 상태 변수

```dart
// 응원단장(시연) 각도 상태
double _leaderAngle = 0.5;        // 현재 각도 (매 프레임 보간)
double _leaderTargetAngle = 0.5;  // 이번 큐 목표 각도
double _leaderPrevAngle = 0.5;    // 보간 시작점

// 플레이어 각도 (BT lShoulderEF 또는 슬라이더)
double _playerAngle = 0.5;

// 큐 시퀀스 (응원단장 동작 지시)
late List<_Cue> _cues;            // _Cue(targetAngle, transitionTime, holdTime)
int _cueIndex = 0;
_Cue? _activeCue;                 // phase: moving → holding → done
double _globalTimer = 0.0;

// 점수 및 진행 상태
int _score = 0, _combo = 0, _maxCombo = 0;
int _hits = 0, _misses = 0, _lifeCount = 5;
double _crowdEnergy = 0.3;        // 관객 에너지 (콤보 비례)

// 피버 — 게이지가 아니라 콤보 임계
bool get _isFever => _combo >= 10;

// 스프라이트 (없으면 null → 절차적 렌더 fallback)
ui.Image? _imgBg, _imgSinger, _imgSingerMouthOpen, _imgSingerEyesClosed;
ui.Image? _imgBodyLeader, _imgBodyPlayer, _imgStick, _imgAudience;
// 팔 리그 — 인물별 개별 (공유 아님)
ui.Image? _imgLeaderArmUpper, _imgLeaderArmFore, _imgPlayerArmUpper, _imgPlayerArmFore;
```

---

## 5. 난이도 및 생체역학 파라미터

어르신의 인지/반응 속도를 고려하여 일반 리듬게임보다 판정 시간을 매우 관대하게 둡니다.

```dart
double get noteSpeedMultiplier => 0.5 + (config.difficultyLevel * 0.1);

// 판정 허용 시간 (초)
double get perfectWindow => 0.25 - (config.difficultyLevel * 0.02);
double get goodWindow => 0.4 - (config.difficultyLevel * 0.02);

// 스윙 감지 민감도
double get swingThreshold => 15.0 / config.difficultyLevel;
```

| Level | 노트 낙하 속도 | 판정선 도달 시간 | 완벽해! 허용치 | 좋아! 허용치 |
|-------|-------------|---------------|---------|---------|
| 1 | 매우 느림 | 화면 생성 후 3초 | ±0.23초 | ±0.38초 |
| 3 | 보통 | 화면 생성 후 2.5초 | ±0.19초 | ±0.34초 |
| 5 | 다소 빠름 | 화면 생성 후 2초 | ±0.15초 | ±0.30초 |

---

## 6. 스프라이트 (에셋) 목록

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션 |
|--------|-----------|------------|---------|---------|
| `bg_trot_stage.png` | 1920×1080 | 화면 전체 | **유지** | 고정 |
| `singer_avatar.png` | 512×512 | 250×400 px | 투명화 | 바운스 댄스 (Hover) |
| `lane_line.png` | 128×1024 | 20×800 px | **검정 유지** | 반투명 고정 |
| `target_zone.png` | 256×256 | 150×150 px | **검정 유지** | 하트 펄스 (Effect API) |
| `note_heart.png` | 256×256 | 100×100 px | 투명화 | 수직 낙하 |
| `cursor_stick.png` | 256×512 | 100×250 px | 투명화 | 좌우 이동 + 스윙 |
| `hit_effect.png` | 512×512 | 200×200 px | **검정 유지** | 순간 확대 & 페이드아웃 |
| `ui_text_perfect.png` | 512×256 | 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_good.png` | 512×256 | 200×100 px | 투명화 | 팝업 (Scale + Move Up) |
| `ui_text_miss.png` | 512×256 | 200×100 px | 투명화 | 팝업 (떨어짐 연출) |

> 미러볼/네온사인 제거 → 하트 발광 + 홍색 스팟 조명으로 대체

---

## 7. 애니메이션 연출 가이드

### 7-1. 트랜스폼 이펙트

- **하트 판정선 펄스**: `target_zone`에 `ScaleEffect.by(Vector2(1.1, 1.1), EffectController(duration: 0.5, infinite: true, alternate: true))` + `OpacityEffect`
- **가수 댄스**: `singer_avatar`에 `MoveEffect.by(Vector2(0, 10), EffectController(duration: 0.4, infinite: true, alternate: true))` (무릎 바운스)
- **판정 텍스트 팝업**: `ui_text_perfect` 생성 → `ScaleEffect.to(1.3)` + `MoveEffect.by(Vector2(0, -60))` 동시 재생 → `RemoveEffect()`

### 7-2. 스윙 애니메이션 (응원봉 타격)

```dart
// SequenceEffect로 0.15초 안에 휘두름 → 원상복구
SequenceEffect([
  RotateEffect.by(-0.4, EffectController(duration: 0.05)), // 뒤로 젖힘
  RotateEffect.by(0.8, EffectController(duration: 0.07)),  // 앞으로 스윙
  RotateEffect.to(0.0, EffectController(duration: 0.03)),  // 복구
])
```

### 7-3. 피버 타임 (Fever Time) 연출

- **응원봉 점멸**: 커서 응원봉 색상을 하늘색 → 흰색 → 하늘색으로 빠르게 순환 (임영웅 응원봉 LED 효과 참조)
- **홍색 오버레이**: `Paint()..color = Color(0x44C8102E)..blendMode = BlendMode.colorDodge` 전체 화면에 적용
- **하트 파티클**: 배경에서 하트 모양 파티클이 위로 솟구침

---

## 8. 스프라이트 제작 파이프라인

### 단계 1: AI 이미지 생성

- 캐릭터·오브젝트(가수, 응원봉, 노트, 텍스트): **초록 배경 #00FF00** 필수
- 빛·이펙트(판정선, 타격 폭죽): **검정 배경 #000000** (BlendMode.plus 용)

### 단계 2: 판정 텍스트 이미지 제작

- **포토샵/Canva에서 직접 제작**
- 폰트: 굵고 둥근 한글 계열 (예: 나눔고딕ExtraBold, 배달의민족 폰트) — 눈누(noonnu.cc) 상업용 무료
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

## 9. AI 이미지 생성 프롬프트 (리듬천국 스타일 · 어깨 관절 리그)

> 실제 코드는 **측면 따라하기 + 어깨 관절 리그**(1자유도, 팔 전체가 어깨축 스윙 / 3레인 낙하노트 아님). 에셋 규격은 [assets/images/trot_rhythm/ASSET_SPEC.md] 참조.
> 그림체 = **리듬천국 플랫 2D**, 복장 = **미스터트롯(한국 트로트 경연 TV) + 마칭밴드/치어리더 스타일**(명칭·로고·실존인물 금지, §13).
> 응원단장/플레이어 = **마칭밴드 치어리더 전신**(응원단장 빨강 군악대, 플레이어 흰+파랑), 둘 다 우리 `cheer_stick`을 듦.

### 9-0. 공통 프리앰블 (모든 프롬프트 앞에 붙임)

```
Rhythm Heaven (Rhythm Tengoku) video game art style: flat 2D vector illustration,
thick bold uniform black outlines, solid flat colors, minimal cel shading,
simple clean geometric shapes, cute quirky charming minimalist character design,
bright cheerful palette, Nintendo WarioWare aesthetic.
Palette: cream white #FFFAF0, crimson red #C8102E, sky blue #87CEEB, gold #D4AF37, black.
STRICTLY FLAT 2D, hand-drawn 2D game sprite, sticker-style, orthographic flat view,
no depth, no 3D, no realistic lighting, single flat color fills only.
Negative: 3D, 3D render, CGI, Pixar, clay render, realistic/volumetric shading,
glossy reflections, photorealistic, gradient shading, text, watermark, logo, extra limbs.
```

### 9-1. 배경 (초록 아님 · 무대는 오른쪽)

```
[프리앰블] A glamorous Korean trot music TV competition stage (fictional, no logos, no text),
cream white and crimson red theme with gold accents.
The MAIN STAGE, spotlight and runway are on the RIGHT SIDE (bright golden spotlight on the right
where a singer stands); the LEFT SIDE is a lower open stage / audience-floor area.
Sparkling LED back wall, simple geometric floor, grand and festive,
WIDE 16:9 EMPTY stage, NO characters, asymmetric composition weighted to the right. --ar 16:9
```
→ `bg_trot_stage.png` (1920×1080, 불투명)

### 9-2. 가수 베이스 (세로형 캔버스 · 초록 크로마)

```
[프리앰블] A cheerful cartoon Korean male trot singer (fictional), wearing a glossy WHITE tuxedo
suit with subtle gold trim (Korean trot competition performer vibe), holding a microphone up,
¾ three-quarter view facing slightly toward viewer, MOUTH CLOSED gentle smile, EYES OPEN,
full body standing, centered, isolated on SOLID FLAT chroma green background #00B140.
```
→ `singer_avatar.png` (512×768 권장, 세로형) — 초록 제거

### 9-3. 가수 표정 오버레이 — ⚠️ img2img(마스크 편집)로 제작

> 새로 생성 금지. **9-2 결과를 인페인팅**으로 입/눈만 바꿔 정합성 유지. 세 파일 캔버스 크기 동일 필수.
- 입: `Keep everything identical, same pose and position. Only open the mouth wide as if singing.` → 입 부위만 남기고 투명 = `singer_mouth_open.png`
- 눈: `Keep everything identical, same pose and position. Only gently close both eyes (blinking).` → 눈 부위만 남기고 투명 = `singer_eyes_closed.png`

### 9-4. 몸통 2종 (전신 · 봉 든 팔만 제외 · 초록 크로마)

> **전신(머리~부츠)**. 한 손은 허리에(고정, 몸통에 그림), **봉 든 쪽(화면 오른쪽) 어깨는 팔 없이 비움** → 리그 팔이 붙어 스윙. 화면엔 항상 완전한 전신으로 보임.

응원단장 (빨강 군악대):
```
[프리앰블] A cheerful young Korean cheer-squad LEADER girl, FULL BODY (head to boots),
RED military marching-band cheer jacket with gold buttons and braid, red shako hat with white plume,
short white pleated skirt, white lace-up boots, ¾ front view, big smile.
ONE arm resting HAND ON HIP (viewer's left). The OTHER arm (viewer's RIGHT — the raised stick side)
is OMITTED: that shoulder is EMPTY, NO raised arm, NO pompom, NO baton.
Isolated on solid flat chroma green #00B140.
```
→ `body_leader.png` (384×640)

플레이어 (흰+파랑):
```
[프리앰블] A cheerful young Korean cheerleader girl (the player), FULL BODY (head to boots),
WHITE marching-band cheer jacket with BLUE vest and gold trim, short white pleated skirt,
white lace-up boots, ponytail, ¾ front view, gentle smile.
ONE arm resting HAND ON HIP (viewer's left). The OTHER arm (viewer's RIGHT — raised stick side)
is OMITTED: EMPTY shoulder, NO raised arm, NO baton, NO pompom.
Isolated on solid flat chroma green #00B140.
```
→ `body_player.png` (384×640)

### 9-5. 관객 (작게 · 응원봉 없음 · 초록 크로마)

```
[프리앰블] A tiny simple cartoon audience fan, small round body and head, ¾ view, cheering happily,
colorful casual clothes, NO light stick (added by code), very simple, isolated on chroma green #00B140.
```
→ `audience_member.png` (128×192) — 16명이 1장 공유

### 9-6. 응원봉 (세로 · 초록 크로마)

```
[프리앰블] A K-pop LED cheering light stick, sky blue #87CEEB glowing, standing PERFECTLY VERTICAL
pointing STRAIGHT DOWN, glowing white bulb tip at the very BOTTOM, handle grip at the very TOP,
simple clean design, centered, isolated on chroma green #00B140.
```
→ `cheer_stick.png` (64×300)

### 9-7. 팔 리그 — ⚠️ 어깨 스윙 · 인물별 4종 (공유 아님)

봉 든 팔 = 별도 리그. **어깨축으로 위/아래 스윙**(팔꿈치 고정). 세로로 곧게, **어깨끝=상단중앙**. 소매색은 각 의상에 맞춤.

응원단장 — 빨강 소매:
```
[프리앰블] A SEPARATE floating cheerleader UPPER-ARM segment (shoulder to elbow),
RED military marching-band jacket sleeve with gold trim, straight VERTICAL limb,
shoulder end at TOP, elbow at bottom, NOT attached to any body. Chroma green #00B140, centered.
```
→ `leader_arm_upper.png` (96×220)
```
[프리앰블] A SEPARATE floating forearm ending in a WHITE-GLOVED hand, RED jacket cuff with gold trim,
straight VERTICAL limb, elbow at TOP, gloved hand at bottom (holding nothing),
NOT attached to any body. Chroma green #00B140, centered.
```
→ `leader_arm_fore.png` (96×260)

플레이어 — 흰 소매:
```
[프리앰블] A SEPARATE floating cheerleader UPPER-ARM segment (shoulder to elbow),
WHITE marching-band jacket sleeve with gold trim (subtle blue accent ok), straight VERTICAL limb,
shoulder end at TOP, elbow at bottom, NOT attached to any body. Chroma green #00B140, centered.
```
→ `player_arm_upper.png` (96×220)
```
[프리앰블] A SEPARATE floating forearm ending in a WHITE-GLOVED hand, WHITE jacket cuff with gold trim,
straight VERTICAL limb, elbow at TOP, gloved hand at bottom (holding nothing),
NOT attached to any body. Chroma green #00B140, centered.
```
→ `player_arm_fore.png` (96×260)

`cheer_stick.png`(하늘색 LED 봉)은 응원단장·플레이어 공유.

### 9-8. 핵심 팁

1. **키잉**: 인물/오브젝트는 `#00B140` 초록 단색 배경으로 뽑고 remove.bg로 제거 (흰 슈트를 흰 배경에 뽑으면 못 지움).
2. **가수 오버레이는 반드시 img2img 인페인팅** — 새 생성 금지(정합성 깨짐). 단순 도형이라 포토샵 직접 덧그리기가 더 확실.
3. **일관성**: 가수·응원단장·플레이어를 같은 세션/시드로 이어 뽑으면 화풍 통일.
4. **판정 텍스트**(완벽해!/좋아!/아쉬워)는 AI 텍스트가 불안정 → Canva/폰트로 직접(현재는 코드 폰트 렌더라 없어도 됨).

---

## 10. 음악 제작 — Suno AI

### 10-1. Suno 프롬프트 (트로트 스타일)

```
Korean trot song, upbeat and cheerful, traditional Korean instruments (janggu, gayageum),
modern production, bright tempo around 120 BPM, encouraging and energetic,
suitable for elderly rehabilitation exercise, no lyrics or instrumental only
```

> 가사 있는 버전을 원하면 `[verse]`, `[chorus]` 태그 활용

### 10-2. 저작권

| 플랜 | 상업적 사용 | 비고 |
|------|-----------|------|
| 무료 | ❌ Suno 소유 | 비상업 임상·연구 목적은 실질 위험 낮음 |
| Pro/Premier | ✅ 사용자 소유 | 논문 발표·외부 배포 시 권장 |

### 10-3. BPM 추출 및 노트 맵 생성 워크플로우

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

## 11. 리듬 게임 특화 로직 (매우 중요)

### 11-1. 오디오 싱크 기반 시간 갱신

```dart
// dt 누적 금지 — 오디오 플레이어 현재 위치를 직접 폴링
if (_audioPlayer.state == PlayerState.playing) {
  _songTime = _audioPlayer.getCurrentPosition().inMilliseconds / 1000.0;
}
```

### 11-2. 노트 위치 절대 계산

```dart
// position.y += speed * dt 사용 금지
double timeDiff = hitTime - gameRef._songTime;
double fallDistance = gameRef.size.y;
position.y = gameRef.targetY - (timeDiff * (fallDistance / fallTime));
```

---

## 12. 오디오 및 SFX

| 구분 | 이벤트 | 파일명 | 볼륨 |
|------|--------|--------|------|
| BGM | 게임 시작 | `trot_bgm_01.mp3` (Suno 생성) | 0.7 |
| SFX | 완벽해! (Perfect) 타격 | `hit_perfect_heart.ogg` | 1.0 (맑은 종소리) |
| SFX | 좋아! (Good) 타격 | `hit_good_chime.ogg` | 1.0 (부드러운 차임) |
| SFX | 아쉬워 (Miss) | `hit_miss_dull.ogg` | 0.8 (둔탁한 소리) |
| SFX | 피버 진입 | `fever_fanfare.ogg` | 1.0 (짧은 팡파레) |

> 장구/꽹과리 SFX 제거 → 판정 피드백은 심플한 종/차임 계열로 교체 (Rhythm Heaven 스타일)  
> 효과음 출처: freesound.org (CC0 필터), kenney.nl

---

## 13. 저작권 주의사항

| 항목 | 사용 가능 여부 | 근거 |
|------|-------------|------|
| "미스터트롯" 명칭·로고 | ❌ 불가 | TV조선 상표 |
| 실제 출연자 얼굴·목소리 | ❌ 불가 | 초상권·퍼블리시티권 |
| 트로트 경연 무대 스타일·분위기 | ✅ 가능 | 스타일 자체는 저작권 대상 아님 |
| 판정 텍스트 (완벽해!/좋아!/아쉬워) | ✅ 가능 | 일반 한국어 |
| Suno 생성 음원 (무료 플랜) | ⚠️ 주의 | 비상업 목적은 실질 위험 낮음, 외부 배포 시 Pro 권장 |
| 효과음 CC0 | ✅ 가능 | freesound.org CC0 태그 필터 필수 확인 |
| 폰트 | ✅ 가능 | 눈누(noonnu.cc)에서 상업용 무료 폰트 사용 |

**결론**: 가상의 한국인 트로트 가수 캐릭터 + 경연 무대 스타일 참고 + AI 생성 음악 사용 시 저작권 문제 없음.

---

## 14. 작업 체크리스트

### Phase 1 — 리듬 코어 로직 (기본 뼈대 및 음원 연동)

#### 1-A. 파일 뼈대 생성
- [x] `lib/games/games/trot_rhythm_game.dart` 파일 생성
- [x] `claude_code_game_dev_guide.md` 패턴대로 `FlameGame + StatefulWidget` 기본 구조 작성
- [x] `_Cue` 클래스 정의 (targetAngle: double, transitionTime: double, holdTime: double)
- [x] 응원단장(시범) + 관객(반응) + 플레이어(하단) 씬 구조 구현

#### 1-B. 오디오 + 싱크
- [x] `assets/audio/trot_rhythm/` 폴더 생성
- [x] 트로트 정식 음원 탑재 (`오늘은 달리자.mp3`, 136 BPM, 195.8초)
- [x] `pubspec.yaml` flutter.assets에 `assets/audio/trot_rhythm/` 경로 등록
- [x] `onLoad()`에서 `_audioPlayer.setSource(AssetSource('audio/trot_rhythm/오늘은 달리자.mp3'))` 로드
- [x] 카운트다운(3, 2, 1) 종료 시점 BGM 루프 재생 시작 및 게임 루프 동기화
- [x] 게임 종료/이탈 시 `_audioPlayer.stop()` 및 리소스 정리

#### 1-C. 노트/큐 맵 파싱 + 스폰
- [x] `pubspec.yaml` assets에 `assets/maps/` 경로 등록
- [x] 136 BPM 타임스탬프 기반 정식 큐 맵 제작 (`assets/maps/trot_map_01.json`, 98개 큐)
- [x] `onLoad()`에서 `assets/maps/trot_map_01.json` 로드 및 파싱 (실패 시 절차적 생성 fallback)
- [x] 큐 시퀀스에 맞추어 응원단장의 팔꿈치 굴곡/신전 동작 실시간 시연
- [x] 마지막 큐 도달 시 자동으로 `GameResultScreen`으로 점수 및 정확도 전달

#### 1-D. 각도 추적 및 판정
- [x] 블루투스 센서(`PART:lElbow`) 각도 실시간 정규화(0.0~1.0) 구독
- [x] 블루투스 미연결 시 하단 슬라이더 시뮬레이션 모드 지원
- [x] 응원단장 목표 각도와의 오차 기반 3단계 판정 ("완벽해!", "좋아!", "아쉬워")
- [x] 콤보 누적 및 10콤보 이상 달성 시 피버(Fever) 모드 발동

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

#### 3-B. 한글 판정 텍스트 UI 제작
- [ ] 눈누(noonnu.cc)에서 깔끔한 한국어 폰트(상업용 무료) 활용
- [ ] `ui_text_perfect.png` 제작: "완벽해!" 금박 그라디언트 + 검정 외곽선 (512×256, 초록 배경)
- [ ] `ui_text_good.png` 제작: "좋아!" 흰색 + 홍색 외곽선 (512×256, 초록 배경)
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
| 판정 텍스트를 기본 폰트로 렌더링 | PNG 이미지 에셋으로 굽거나 TTF 폰트 파일을 직접 로드 |

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
9.  판정 텍스트 팝업 (ui_text_perfect / ui_text_good / ui_text_miss)
10. HUD 고정 요소 (점수, 콤보, 피버 게이지, 체력)
```
