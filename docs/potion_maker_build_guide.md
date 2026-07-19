# [E3] 물약 제조 게임 (Potion Maker) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-10  
**파일**: `lib/games/games/potion_maker_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 현재 상태 (2026-06-10 기준)

| 항목 | 상태 |
|------|------|
| 기본 게임 구조 (이동·선택·따르기 판정) | ❌ 미완성 |
| 어깨/팔꿈치 관절 데이터 분리 및 매핑 | ❌ 미완성 |
| 타겟 포즈 (어깨90/팔꿈치90) 유지 메카닉 | ❌ 미완성 |
| 어깨 돌림에 따른 병 기울임 및 따르기 파티클 연출 | ❌ 미완성 |
| Flame Effect API를 활용한 트랜스폼 애니메이션 | ❌ 미완성 |
| 스프라이트 시트 및 파티클 시스템 통합 | ❌ 미완성 |
| Brunnstrom 난이도 및 ROM 연동 | ❌ 미완성 |
| UI/가이드 마법진 (동작 유도 홀로그램) | ❌ 미완성 |
| 실패(오염/연기) / 성공(별가루) 이펙트 연출 | ❌ 미완성 |
| **배경 음악 (BGM)** | ❌ 미완성 |
| **효과음 (선택·따르기·성공·폭발)** | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

```
입력 데이터 (BT 센서: 어깨 굽힘/폄, 돌림, 팔꿈치 굽힘/폄)
  ↓ 관절 가동 범위(ROM) Calibration 데이터 적용
  ↓
PotionMakerFlameGame.update(dt)
  ├── 1. 이동 단계 (_updateMovePhase)
  │     └─ 어깨 굽힘/폄 데이터 → 마법 장갑(커서) Y축 이동
  ├── 2. 선택 단계 (_updateSelectPhase)
  │     └─ 장갑이 타겟 물약병 위치에 있을 때, 팔꿈치 폄 감지 시 병 쥠 (_isGrabbed = true)
  ├── 3. 조준 단계 (_updatePositioningPhase)
  │     └─ 병을 잡은 상태로 어깨 90도, 팔꿈치 90도 범위 진입/유지 확인
  ├── 4. 따르기 단계 (_updatePourPhase)
  │     └─ 조준 유지 시, 어깨 회전 값 매핑 → 병 기울임(RotateEffect) 및 용액 증가 (_pouredVolume)
  ├── 파티클/애니메이션 업데이트 (가마솥 끓는 애니, 빛 펄스, 연기, 액체 떨어짐)
  └── 레시피 판정 (_checkRecipe)
        ├── 정량/정답 성공 → 마법 생물 생성(Scale/Move 애니메이션)
        └── 용량 초과/오답 → 실패 흔들림(Shake 애니) 및 생명력 감소
  ↓
render(canvas)
  ├── 1. 배경: 연금술 연구실 (bg_alchemy_lab) 및 레시피 두루마리 (recipe_scroll)
  ├── 2. 완성 생물 (creature_1~5) (선반 레이어)
  ├── 3. 메인 가마솥 (cauldron) + 끓는 액체 시트 (cauldron_liquid) + 가마솥 글로우 (cauldron_glow)
  ├── 4. 대기 중인 물약병들 (potion_1~5)
  ├── 5. 플레이어 마법 장갑 (glove_open / glove_grab)
  ├── 6. 액체 파티클 (liquid_drop) 및 연기 파티클 (smoke_cloud)
  ├── 7. 룬 용량 게이지 (rune_gauge_bg, rune_gauge_fill)
  ├── 8. 동작 가이드 홀로그램 (guide_holo_*)
  └── 9. HUD (생명력: life_icon)
```

---

## 2. 핵심 상태 변수

```dart
// 관절 매핑 상태
double shoulderFlexion = 0.0;    
double elbowFlexion = 0.0;       
double shoulderRotation = 0.0;   

PotionGameState _currentState = PotionGameState.idle;

int _lifeCount = 3;              
PotionType? _grabbedPotion;      
double _pouredVolume = 0.0;      
double _targetVolume = 50.0;     

int _craftedCount = 0;           
late int _clearTarget;           
```

---

## 3. 난이도 및 생체역학 파라미터

| Level | 클리어 목표 | 자세 판정 범위(Tolerance) | 용량 판정 허용치 | 액체 흐름 속도 |
|-------|-----------|-------------------------|----------------|-------------|
| 1 | 4개 | ±20도 (매우 관대함) | ±30% | 느림 (맞추기 쉬움) |
| 3 | 6개 | ±10도 (기본) | ±15% | 보통 |
| 5 | 8개 | ±5도 (엄격함) | ±5% | 빠름 (세밀한 조절 필요)|

---

## 4. 스프라이트 (에셋) 목록 요약

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션 필요 여부 |
|--------|-----------|----------------|---------|------------------|
| `bg_alchemy_lab.png` | 1920×1080 | 화면 전체 | 유지 | 없음 |
| `cauldron.png` | 1080×1080 | 400×400 px | 투명화 | 실패 시 진동 (Effect API) |
| `cauldron_glow.png` | 1080×1080 | 400×400 px | **검정 유지** | 펄스 (Effect API) |
| `cauldron_liquid.png`| 1024×256 | 200×50 px | 투명화 | **1×4 스프라이트 시트** |
| `potion_1~5.png` | 512×512 | 100×120 px | 투명화 | 병 기울임 (센서 연동) |
| `creature_1~5.png`| 512×512 | 80×80 px | 투명화 | 둥둥 떠다니기 (Effect API) |
| `glove_open / grab` | 512×512 | 120×120 px | 투명화 | 이미지 스왑 로직 |
| `rune_gauge_fill` | 256×1024 | 50×300 px | **검정 유지** | Rect Clip 렌더 연출 |
| `guide_holo_*` | 512×512 | 150×150 px | **검정 유지** | 펄스 (Effect API) |
| `liquid_drop.png` | 128×128 | 10~20 px | 투명화 | 파티클 시스템 |
| `smoke_cloud.png` | 256×256 | 50~100 px | **검정 유지** | 파티클 시스템 (Screen Blend) |

---

## 5. 애니메이션 연출 및 구현 가이드 (상세)

Flame 엔진에서 제공하는 기능을 조합하여 판타지 분위기의 애니메이션을 구현합니다.

### 5-1. 트랜스폼 이펙트 (Flame Effects API)
*   **떠다니는 효과**: 마법 생물, 장갑에 `MoveEffect.by(Vector2(0, 10), EffectController(duration: 1.5, infinite: true, alternate: true))` 적용.
*   **마법 펄스 효과**: 가마솥 글로우와 마법진에 `OpacityEffect.to(0.4, EffectController(duration: 1.0, infinite: true, alternate: true))` 적용.
*   **가마솥 흔들림**: 실패 시 `MoveEffect.by(Vector2(15, 0), EffectController(duration: 0.05, repeatCount: 5, alternate: true))` 적용.
*   **병 기울이기**: 센서값 정규화 후 `angle` 속성에 직접 매핑.

### 5-2. 파티클 시스템 (Particle System)
*   **액체 붓기 (liquid_drop)**: 병 주둥이에서 발생, 중력 가속도(`AcceleratedParticle`)를 받으며 아래로 떨어짐.
*   **실패 시 독성 연기 (smoke_cloud)**: 가마솥에서 위로 무작위 확산(`random velocity`). `ScaleEffect`로 커지면서 `OpacityEffect`로 페이드아웃. BlendMode.screen 필수.
*   **성공 폭죽**: 투명화된 파티클이 원형으로 퍼져나감.

### 5-3. 스프라이트 시트 애니메이션
*   **가마솥 내부 액체**: `cauldron_liquid.png` (1열 4프레임) `SpriteAnimationComponent`로 `stepTime: 0.2` 지정하여 무한 루프.

---

## 6. 스프라이트 제작 및 최적화 파이프라인 (매우 상세)

이 섹션은 위 4번의 에셋들을 처음부터 끝까지 어떻게 만들어 게임에 적용하는지 세분화한 작업 과정입니다.

### 단계 1: AI 이미지 생성 (DALL-E 3, Midjourney 등 활용)
아래 7번에 나열된 프롬프트를 사용하여 원본 1:1(혹은 16:9) 비율의 이미지를 생성합니다.
*   **초록 배경(#00FF00) 프롬프트**: 실체가 있는 오브젝트(가마솥, 병, 생물, 장갑 등)에 사용합니다. 이후 완벽한 외곽선 추출(누끼)을 위해 배경색 대비를 극대화합니다.
*   **순수 검정 배경(#000000) 프롬프트**: 마법진, 글로우 펄스, 게이지 불빛, 연기 파티클 등 빛나는 이펙트에 사용합니다. 이 이미지들은 절대 배경을 제거하지 않습니다!

### 단계 2: 배경 제거 (누끼 따기) 및 마스킹 리터칭
오브젝트 스프라이트(초록 배경)에만 적용하는 단계입니다.
1.  **자동 툴 사용**: `remove.bg` 또는 Photoshop의 '피사체 선택(Select Subject)' 기능을 사용하여 1차적으로 초록색 배경을 날립니다.
2.  **수동 정리 (Photoshop / GIMP)**:
    *   장갑 손가락 사이나 물약병 주둥이 틈새에 남은 초록색 픽셀(Color Fringe)을 지우개 툴(Hard edge)로 깔끔하게 정리합니다.
    *   반투명한 영역(유리병 질감)이 지저분해졌다면 불투명도를 높여 깔끔한 2D 애니메이션 느낌을 살립니다.
3.  **투명 PNG로 내보내기**: 포맷은 반드시 PNG-24 (투명도 체크)로 저장합니다.

### 단계 3: 빛/이펙트 이미지의 처리 (블렌딩 모드 셋업)
검정 배경으로 뽑은 `_glow`, `guide_holo`, `smoke_cloud`, `rune_gauge_fill` 에셋 처리법입니다.
1.  **절대 배경 지우개 금지**: 포토샵에서 배경을 지우면 빛의 부드러운 그라데이션이 다 망가집니다.
2.  **컬러 보정**: 검정색이 완전한 순수 검정(RGB 0,0,0)인지 레벨(Levels)을 조정하여 확인합니다. (배경이 짙은 회색이면 게임 화면에 네모난 박스가 보입니다).
3.  **저장**: 검정 배경 그대로 JPG 또는 PNG로 저장합니다.
4.  **엔진 적용 원리**: Flame의 코드에서 `Paint()..blendMode = BlendMode.plus` (또는 screen)를 적용하면 검정색은 투명해지고 색상 있는 빛 부분만 화면에 더해집니다.

### 단계 4: 스프라이트 시트 (Spritesheet) 병합 작업
끓는 액체 애니메이션(`cauldron_liquid.png`)을 만드는 특수 과정입니다.
1.  **개별 프레임 준비**: 물결이 일렁이는 이미지 4장을 준비합니다. (AI로 생성한 후 조금씩 픽셀 유동화/왜곡 필터를 주어 4프레임을 만듭니다.)
2.  **병합 (Stitching)**:
    *   가로 256px × 세로 256px 크기로 4장이라면, 포토샵 캔버스를 가로 1024px × 세로 256px로 만듭니다.
    *   프레임 1, 2, 3, 4를 순서대로 가로로 딱 붙여서 나열합니다. (격자에 맞게 정렬).
3.  **투명화 및 저장**: 배경을 투명하게 날리고 1장의 가로로 긴 PNG 파일로 내보냅니다.

### 단계 5: 해상도 최적화 및 리사이징
원본 이미지는 1080p 고해상도이므로, 모바일 성능을 위해 사이즈를 줄여야 합니다.
1.  **리사이징**:
    *   배경: 1920×1080 그대로 유지.
    *   가마솥/장갑/홀로그램: 512×512 또는 256×256으로 축소 (Photoshop 이미지 크기 조절).
    *   파티클(liquid_drop 등): 128×128 이하로 과감히 축소 (렌더링 부하 큼).
2.  **용량 압축 (TinyPNG)**: `tinypng.com` 같은 사이트에 완성된 PNG를 넣어 품질 손상 없이 메타데이터를 제거하고 용량을 압축합니다.

### 단계 6: 게임 프로젝트 편입 및 네이밍 컨벤션
1.  **폴더 위치**: 완성된 이미지는 반드시 프로젝트의 `assets/images/potion_maker/` 폴더에 복사합니다.
2.  **명명 규칙**: 소문자 영문과 언더스코어(`_`)만 사용합니다. (예: `Potion_01.png` ❌ → `potion_1.png` ⭕)
3.  **코드 등록**: `pubspec.yaml` 파일에 폴더를 등록한 후 `Flame.images.load()`로 호출합니다.

---

## 7. AI 이미지 생성 프롬프트

위의 '단계 1'에서 사용할 구체적 프롬프트 목록입니다.

**공통 스타일**: `cartoon rendering style, cel-shaded, bold black outlines, vibrant saturated colors, stylized proportions, fantasy alchemy game asset`

### 초록 배경 (투명화용) 프롬프트 추가 지시문
`, solid bright lime green background (#00FF00), square 1:1 format`

*   **배경 (bg_alchemy_lab)**: `A cozy magical fantasy alchemy laboratory at night, wide 16:9 panoramic view, tall wooden shelves filled with glowing potion bottles, old spellbooks, candlelight casting soft warm shadows`
*   **가마솥 (cauldron)**: `A large heavy copper alchemy cauldron filled with bubbling glowing pink liquid, centered in canvas, intricate magical runes carved along the rim` (초록 배경 적용)
*   **물약병 (potion_1~5)**: `A beautiful fantasy potion bottle shaped like a teardrop, filled with glowing cosmic blue liquid with tiny stars inside, cork stopper` (초록 배경 적용, 프롬프트의 색상/테마 변경하며 5종 생성)
*   **생물 (creature_1~5)**: `A cute tiny glowing magical slime creature with big eyes, radiating bright cyan light, sitting happily` (초록 배경 적용)
*   **열린 장갑 (glove_open)**: `A floating magical wizard's glove holding invisible energy, front-facing view, bright purple fabric, fingers open and spread out` (초록 배경 적용)
*   **쥔 장갑 (glove_grab)**: `A floating magical wizard's glove, front-facing view, bright purple fabric, fingers tightly closed in a grabbing fist gesture` (초록 배경 적용)
*   **생명력 아이콘 (life_icon)**: `A small cute glowing red heart gem, shiny and polished, bold black outline` (초록 배경 적용)
*   **액체 파티클 (liquid_drop)**: `A single stylized glowing droplet of magical liquid, bright cyan and magenta colors` (초록 배경 적용)

### 검정 배경 (블렌딩 모드용) 프롬프트 추가 지시문
`, pure black background (#000000) for screen blend mode, no solid fill inside, soft inner radiance`

*   **가마솥 펄스 (cauldron_glow)**: `A glowing magical aura matching exactly the shape of a large round cauldron, neon magenta-pink luminous energy (#FF00FF), thick glowing border` (검정 배경 적용)
*   **게이지 뼈대 (rune_gauge_bg)**: `A tall vertical magical rune progress bar frame, thick carved stone border with unlit ancient symbols, empty inside, 1:4 aspect ratio` (초록 배경 적용 후 내부 투명화)
*   **게이지 액체 (rune_gauge_fill)**: `A tall vertical bar of glowing liquid magic, bright neon magenta-pink (#FF00FF), 1:4 aspect ratio` (검정 배경 적용)
*   **가이드 마법진 (guide_holo_*)**: `A magical glowing hologram symbol of a bent arm turning into a straight arm, bright cyan-teal luminous energy (#00E5FF), thick neon lines` (검정 배경 적용)
*   **독성 연기 (smoke_cloud)**: `A puff of dark purple and green toxic smoke, stylized cartoon clouds, glowing slightly` (검정 배경 적용)

### 스프라이트 시트용 프롬프트
*   **끓는 액체 (cauldron_liquid)**: `A horizontal spritesheet containing 4 frames of bubbling magical glowing pink liquid, top-down isometric view of liquid surface, showing ripples and bursting magic bubbles, 4:1 aspect ratio` (초록 배경 적용 후 단계 4 진행)

---

## 8. 오디오 및 SFX 타이밍

| 구분 | 이벤트 (애니메이션 동기화) | 파일명 |
|---|--------|------|
| **BGM** | 일반 게임 진행 | `Mystic_Lab.mp3` |
| **BGM** | 생물 창조 애니메이션(Scale up) 시 | `Magic_Success.mp3`|
| **SFX** | 커서 이동 및 둥둥거림(Hover) | `magic_chime_light.ogg` |
| **SFX** | 팔꿈치 펴서 병 쥘 때 (glove 교체) | `grab_magic.ogg` |
| **SFX** | 조준 완료 마법진 활성화(Glow 시작) | `bell_01.ogg` |
| **SFX** | 파티클 쏟아질 때 (루프) | `water_pour.ogg` |
| **SFX** | 마법 폭죽 파티클 터질 때 | `gong_01.ogg` |
| **SFX** | 가마솥 흔들리며 연기 확산될 때 | `explosion.ogg` |

---

## 9. 작업 체크리스트

### Phase 1 — 코어 매핑 및 기본 UI
- [ ] FlameGame, 관절 데이터 구독, 마법 장갑의 Y축 이동 매핑

### Phase 2 — 상호작용 및 트랜스폼 애니메이션 (Effect API)
- [ ] Hover 판정 및 팔꿈치 폄 감지 시 장갑 스프라이트 교체(`glove_grab`) 로직
- [ ] 어깨90/팔꿈치90 유지 및 센서 연동 병 기울이기(RotateEffect/angle 매핑) 구현
- [ ] 생물/장갑 Hovering (MoveEffect), 마법진 Glow 펄스 (OpacityEffect) 연동

### Phase 3 — 스프라이트 시트 및 렌더링
- [ ] 단계별로 제작된 16종 스프라이트 파일 `_loadImg()` 로드
- [ ] `SpriteAnimation.fromFrameData`로 끓는 액체 가마솥에 결합
- [ ] 룬 게이지 마스킹/클리핑 연출 및 전시 선반 결과물 배치

### Phase 4 — 파티클 및 이펙트 연출
- [ ] 따르기 상태 시 `AcceleratedParticle`을 활용한 액체 파티클 방출
- [ ] 오답 실패 시 가마솥 Shake Effect 적용 + 독성 연기 파티클 방출
- [ ] 성공 시 폭죽 파티클 및 BGM/SFX 사운드 동기화

### Phase 5 — 마무리 및 튜닝
- [ ] 목숨 소진 및 클리어 조건 연동
- [ ] 이미지 용량 최적화가 잘 되어 프레임 드랍이 없는지 모바일/태블릿 기기 테스트

---

## 10. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 빛 효과(Glow/Holo) 이미지의 배경을 remove.bg로 지움 | 검정 배경을 그대로 두고, 코드에서 `BlendMode.plus`를 사용해야 그라데이션이 유지됨 |
| 파티클 이미지를 너무 큰 원본(512px)으로 씀 | 화면에 수십 개가 렌더링되므로, 파티클 소스는 반드시 128px 이하로 리사이즈 및 압축 |
| 시트 애니메이션 프레임 데이터 좌표 계산 오류 | `SpriteAnimationData.sequenced` 를 사용하여 `amount`(프레임 수)와 `stepTime`만 지정하면 안전 |

---

## 11. 렌더 순서 (중요)

```dart
// 렌더링 뎁스(Depth) 보장 (파티클과 이펙트 포함)
1. 배경 (bg_alchemy_lab) 및 레시피 (recipe_scroll)
2. 전시된 마법 생물 (Hover 애니메이션 동작 중)
3. 대기 중인 물약병 (potion_1~5)
4. 가마솥 몸체 (cauldron)
5. 가마솥 내부 끓는 액체 애니메이션 시트 (cauldron_liquid)
6. 가마솥 글로우 펄스 (cauldron_glow)
7. 마법 장갑 및 잡은 물약 (센서에 따른 기울기 실시간 반영)
8. 떨어지는 액체 파티클 (가마솥 안으로 들어가는 느낌 연출)
9. 실패 시 독성 연기 파티클 (BlendMode.screen)
10. 성공 시 마법 폭죽 파티클
11. 룬 게이지 배경 및 차오르는 내용물
12. 동작 유도 홀로그램 가이드 (Glow 펄스 동작 중)
13. 생명력 아이콘 및 점수 텍스트
```
