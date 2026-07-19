# [S3] 방패 막기 게임 제작 가이드
**최초 작성**: 2026-05-07  
**최종 수정**: 2026-05-20  
**파일**: `lib/games/games/shield_guard_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 현재 상태 (2026-05-20 기준)

| 항목 | 상태 |
|------|------|
| 기본 게임 구조 (화살·방패·충돌) | ✅ 완성 |
| 홀드 메카닉 + 진행 링 | ✅ 완성 |
| 파티클 이펙트 | ✅ 완성 |
| 화살 충돌 흔들림 효과 | ✅ 완성 |
| Brunnstrom 난이도 연동 | ✅ 완성 |
| 스프라이트 통합 (방패·화살·성·목숨) | ✅ 완성 |
| 방패 글로우 펄스 효과 | ✅ 완성 |
| HUD — 막은 화살 수 / 목표 표시 | ✅ 완성 |
| 클리어 조건 (목표 개수 달성) | ✅ 완성 |
| **배경 음악 (BGM)** | ❌ 미완성 |
| **효과음 (화살 충돌·성공·피해·클리어)** | ❌ 미완성 |
| 결과 화면 (클리어 vs 게임오버 구분) | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

```
입력 (BT 각도 or 슬라이더)
  ↓ AngleNormalizer (0.0~1.0)
  ↓ currentPosition
  ↓
ShieldGuardFlameGame.update(dt)
  ├── 화살 이동 (_updateArrows)
  ├── 충돌 판정 (_checkCollision)
  ├── 홀드 처리 (_updateHold)
  │     ├── 성공 → score+10, _blockedCount++
  │     │         → _blockedCount >= _clearTarget → endGame()
  │     └── 실패 → _applyDamage() → _wallHealth==0 → endGame()
  ├── 파티클 업데이트
  ├── 글로우 펄스 / 흔들림 감쇠
  └── 화살 스폰 (_spawnInterval)
  ↓
render(canvas)
  ├── castle 배경 (castle_0~4, 데미지 단계)
  ├── 날아오는 화살 (flying phase)
  ├── 방패 (_drawShield)  ← shield_0~4 + shield_glow 오버레이
  ├── 꽂힌 화살 (holding phase)  ← 방패 앞에 렌더
  ├── 홀드 진행 링 + "버텨!" 텍스트
  ├── 피격 플래시 (붉은 화면)
  ├── 파티클
  ├── 점수 (우측 상단)
  └── HUD — 목숨 아이콘 × 5 (좌측) + 막은 화살 X/Y (중앙)
```

---

## 2. 핵심 상태 변수

```dart
double currentPosition;      // 0.0~1.0, BT 입력 or 슬라이더
int _wallHealth = 5;         // 체력 (0 = 게임오버)
int score = 0;
int _blockedCount = 0;       // 막은 화살 수
late int _clearTarget;       // 클리어 목표 (난이도별)

_ArrowData? _holdingArrow;   // 현재 꽂혀있는 화살
double _holdTimer = 0;       // 홀드 유지 시간

double _shakeTimer = 0;      // 충돌 흔들림 (감쇠)
double _glowPulse = 0;       // 방패 글로우 펄스 위상
double _hitFlash = 0;        // 피격 화면 플래시
```

---

## 3. 난이도 파라미터

```dart
// difficultyLevel 1~5 기준
double get _arrowSpeed    => 140.0 * config.speedMultiplier;
double get _spawnInterval => 4.0   / config.speedMultiplier;
double get _holdRequired  => 1.8   * config.speedMultiplier;
double get _shieldW       => 150.0 * config.targetSizeMultiplier;
double get _shieldH       => 180.0 * config.targetSizeMultiplier;

// onLoad()에서 설정
_clearTarget = 5 + config.difficultyLevel * 2;
// Level 1→7개, Level 2→9개, Level 3→11개, Level 4→13개, Level 5→15개
```

| Level | 클리어 목표 | 화살 속도 | 방패 크기 |
|-------|-----------|---------|---------|
| 1 | 7개 | ×0.5 | ×1.5 |
| 2 | 9개 | ×0.75 | ×1.25 |
| 3 | 11개 | ×1.0 (기본) | ×1.0 |
| 4 | 13개 | ×1.25 | ×0.85 |
| 5 | 15개 | ×1.5 | ×0.7 |

---

## 4. 스프라이트 목록

| 파일명 | 캔버스 크기 | 게임 내 렌더 크기 | 화면 위치 | 배경 처리 |
|--------|-----------|----------------|---------|---------|
| `shield_0~4.png` | 1080×1080 | 150×180 px (Level3 기준) | X=화면 15%, Y=팔 각도 가변 | 투명 (remove.bg) |
| `shield_glow.png` | 1080×1080 | 방패와 동일 (오버레이) | 방패 위에 정렬 | 검정 + BlendMode.plus |
| `arrow.png` | 1080×1080 | 260×80 px | 우→좌 비행, Y=랜덤 | 투명 (remove.bg) |
| `indicator.png` | 512×512 | 100×100 px | 화살 위 (↓기본, ↑코드에서 반전) | 검정 + BlendMode.plus |
| `life_icon.png` | 256×256 | 52×52 px × 5개 | 상단 좌측 나열 | 투명 (remove.bg) |
| `castle_0~4.png` | 1920×1080 | 화면 전체 | 배경 전체 | 포함 (하늘 포함) |

**배경 처리 방법:**

| 종류 | 생성 배경 | 처리 |
|------|---------|------|
| 일반 스프라이트 (방패·화살·목숨) | 초록 (#00FF00) | remove.bg → 투명 PNG |
| 글로우 스프라이트 (shield_glow, indicator) | **검정 (#000000)** | 제거 불필요 — BlendMode.plus 렌더 |
| 배경 이미지 (castle) | 없음 (하늘 포함) | 그대로 사용 |

**castle 인덱스 매핑**: `castleImages[5 - _wallHealth]`  
→ wallHealth 5=완전한 성(castle_0), wallHealth 1=폐허(castle_4)

---

## 5. AI 이미지 생성 프롬프트

**공통 카툰 스타일:**
```
cartoon rendering style, cel-shaded, bold black outlines,
vibrant saturated colors, stylized proportions,
medieval fantasy game asset, flat clean shading with subtle gradients,
square 1:1 format, mobile game icon style
```

### 방패 (shield_0~4) — 1080×1080, 초록 배경

**shield_0 (완전한 방패):**
```
A medieval heater shield centered in a 1:1 square canvas,
occupying about 75% of the canvas area, front-facing view,
shiny silver metallic surface with a bold golden cross emblem in the center,
thick gold trim along the border, perfect pristine condition,
cartoon rendering style, cel-shaded, bold black outlines,
vibrant saturated colors, flat clean shading with subtle gradients,
solid bright lime green background (#00FF00), square 1:1 format, mobile game icon style
```

**shield_1~4:** 이전 이미지 첨부 후 순서대로 요청
```
shield_1: 오른쪽 상단에 대각선 흠집 1개, 도색 벗겨짐
shield_2: 흠집 추가, 가장자리 마모, 표면 패인 곳
shield_3: 왼쪽 하단 모서리 떨어짐, 균열 퍼짐, 금테 일부 소실
shield_4: 중앙 대각선 균열, 금속 휨, 도색 대부분 소실
```

### 글로우 (shield_glow) — 1080×1080, 검정 배경
```
A magical glowing aura in the exact shape of a heater shield outline,
centered in a 1:1 square canvas, occupying about 75% of the canvas,
bright cyan-teal luminous energy (color: #00E5FF),
cartoon style thick glowing border with soft inner radiance —
no solid fill inside, only the glowing outline and faint inner glow,
solid pure black background (#000000),
square 1:1 format, game UI overlay style
```

### 화살 (arrow) — 1080×1080, 초록 배경
```
A medieval arrow in horizontal position pointing LEFT,
centered in a 1:1 square canvas, arrow length occupying 80% of canvas width,
wooden shaft with warm brown color, bold black outline,
large sharp triangular arrowhead (silver) on the LEFT end,
stylized feather fletching on the RIGHT end,
cartoon rendering style, cel-shaded, vibrant colors, bold outlines,
solid bright lime green background (#00FF00), square 1:1 format, mobile game asset
```

### 방향 인디케이터 (indicator) — 512×512, 검정 배경 — **1장만 제작**
```
A bold downward arrow symbol ↓ centered in a 512×512 canvas,
thick chunky design occupying 70% of the canvas,
bright white fill with cyan-blue (#00E5FF) outer glow and black outline,
clean sharp edges, readable at small sizes,
flat 2D cartoon icon style, solid pure black background (#000000)
```
> ↑는 코드에서 `canvas.scale(1, -1)` 수직 반전 처리

### 목숨 아이콘 (life_icon) — 256×256, 초록 배경
```
A small medieval shield icon centered in a 256×256 canvas,
occupying about 70% of the canvas area, front-facing view,
shiny silver with a small golden cross emblem, thick gold border trim,
cute and chunky proportions, readable at very small sizes (52×52px),
cartoon rendering style, cel-shaded, bold black outlines,
solid bright lime green background (#00FF00), square 1:1 format
```

### 성 배경 (castle_0~4) — 1920×1080, 배경 포함

**castle_0 (완전한 성):**
```
A medieval stone castle at dusk, wide 16:9 panoramic view,
tall towers with battlements, dramatic golden-orange sunset sky,
cartoon rendering style, cel-shaded, bold black outlines,
vibrant warm colors, stylized clouds and sky,
epic fantasy atmosphere, castle perfectly intact,
full scene illustration
```

**castle_1~4:** 이전 이미지 첨부 후 순서대로 요청
```
castle_1: 성벽 균열, 돌조각 낙하, 연기 한 줄기
castle_2: 작은 탑 상단 무너짐, 성벽 파손, 불꽃 보임
castle_3: 메인 탑 절반 붕괴, 성벽 큰 구멍, 불길과 연기
castle_4: 거의 폐허, 탑들 대부분 무너짐, 전체에 불길과 짙은 연기
```

---

## 6. 오디오

### 패키지 및 에셋 등록 ✅ 완성

```yaml
# pubspec.yaml
dependencies:
  flame_audio: ^2.1.1

flutter:
  assets:
    - assets/audio/sheild_guard/   # (오타 주의: sheild)
```

> `flame_audio`는 `assets/audio/`를 자동 prefix로 붙임  
> 코드에서 경로 지정 시 `assets/audio/` 제외하고 이후 경로만 사용

---

### BGM ✅ 완성

| 파일 | 경로 | 재생 시점 | 볼륨 |
|------|------|---------|------|
| `Village Consort.mp3` | `assets/audio/sheild_guard/` | 게임 시작 ~ 체력 3 이상 | 1.0 |
| `Crunk Knight.mp3` | `assets/audio/sheild_guard/` | 체력 2 이하 (긴박 전환) | 1.0 |

```dart
static const _bgmNormal = 'sheild_guard/Village Consort.mp3';
static const _bgmUrgent = 'sheild_guard/Crunk Knight.mp3';

// onLoad()
await FlameAudio.bgm.play(_bgmNormal, volume: 1.0);

// _applyDamage() — 체력 2 이하 시 전환
if (_wallHealth <= 2 && !_urgentBgmPlaying) {
  _urgentBgmPlaying = true;
  FlameAudio.bgm.play(_bgmUrgent, volume: 1.0);
}

// endGame() + onRemove()
FlameAudio.bgm.stop();
```

---

### SFX ❌ 미완성

기존 에셋 재활용 — 별도 파일 다운로드 불필요:

| 이벤트 | 파일 | 경로 |
|--------|------|------|
| 화살 꽂힘 | `metal_03.ogg` | `assets/100-CC0-SFX/` |
| 홀드 성공 | `bell_01.ogg` | `assets/100-CC0-SFX/` |
| 피해 | `sfx_shieldDown.ogg` | `assets/images/kenney_space-shooter-redux/Bonus/` |
| 클리어 | `gong_01.ogg` | `assets/100-CC0-SFX/` |
| 게임오버 | `explosion.ogg` | `assets/100-CC0-SFX/` |

> 위 폴더들은 이미 pubspec.yaml에 등록되어 있어 추가 작업 불필요  
> `FlameAudio.play()` 경로는 `assets/` 이후부터 작성

```dart
// 구현 예시
FlameAudio.play('100-CC0-SFX/metal_03.ogg');   // 화살 꽂힘
FlameAudio.play('100-CC0-SFX/bell_01.ogg');    // 홀드 성공
FlameAudio.play('images/kenney_space-shooter-redux/Bonus/sfx_shieldDown.ogg'); // 피해
FlameAudio.play('100-CC0-SFX/gong_01.ogg');    // 클리어
FlameAudio.play('100-CC0-SFX/explosion.ogg');  // 게임오버
```

---

## 7. 작업 체크리스트

### Phase 1 — 핵심 게임플레이 ✅ 완성

- [x] FlameGame 골격 + Flutter 래퍼
- [x] BT 입력 스트림 구독 + 슬라이더 시뮬레이션
- [x] 화살 생성 / 이동 / 충돌 판정
- [x] 홀드 메카닉 + 진행 링
- [x] 점수 / 체력 / 피해 로직
- [x] 파티클 이펙트 (성공 / 피해)
- [x] 충돌 흔들림 효과
- [x] Brunnstrom 난이도 연동

### Phase 2 — 스프라이트 통합 ✅ 완성

- [x] pubspec.yaml 에셋 경로 등록 (`assets/shield/`)
- [x] `_loadImg()` 헬퍼로 스프라이트 로드
- [x] 방패 스프라이트 교체 (shield_0~4)
- [x] 글로우 오버레이 + 펄스 애니메이션 (shield_glow)
- [x] 화살 스프라이트 교체 (arrow.png)
- [x] 방향 인디케이터 (indicator.png, ↑는 수직 반전)
- [x] 목숨 아이콘 HUD (life_icon.png × 5)
- [x] 성 배경 데미지 단계 (castle_0~4)

### Phase 3 — HUD / 클리어 조건 ✅ 완성

- [x] 타이머 제거 → 막은 화살 수 / 목표 표시
- [x] 클리어 조건 (`_blockedCount >= _clearTarget`)
- [x] 목표 달성 시 `endGame()` 호출
- [x] `maxPossibleScore = _clearTarget * 10`

### Phase 4 — 오디오 🔄 진행 중

**BGM ✅ 완성**
- [x] `flame_audio: ^2.1.1` 패키지 추가
- [x] `assets/audio/sheild_guard/` 에셋 경로 등록
- [x] `Village Consort.mp3` — 평상시 BGM (볼륨 1.0)
- [x] `Crunk Knight.mp3` — 체력 2 이하 긴박 전환 BGM
- [x] `endGame()` / `onRemove()`에서 BGM 정지

**SFX ✅ 완성**
- [x] 화살 꽂힘 — `100-CC0-SFX/slam_03.ogg`
- [x] 홀드 성공 — `100-CC0-SFX/bell_01.ogg`
- [x] 피해 — `100-CC0-SFX/slam_01.ogg`
- [x] 클리어 — `100-CC0-SFX/gong_01.ogg`
- [x] 게임오버 — `100-CC0-SFX/door_close_04.ogg`

### Phase 5 — 마무리 ❌ 미완성

- [ ] 결과 화면 클리어 / 게임오버 구분 표시
- [ ] 전체 플레이 테스트 (Level 1 / Level 5)
- [ ] `flutter build apk --release` 성공 확인
- [ ] 태블릿 실기기 설치 및 시연 테스트

---

## 8. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| render()에 충돌 판정 넣기 | 충돌은 update(), 렌더만 render() |
| BT 코드 수정 | `game_motor_controller.dart` 절대 건드리지 않음 |
| 스프라이트 경로 오타 | pubspec.yaml 폴더 경로와 load() 경로 일치 확인 |
| 방패/성 손상 단계 인덱스 역방향 | `5 - _wallHealth` (health 5=정상→index 0) |
| 글로우 블렌드 모드 미설정 | 검정 배경 이미지는 반드시 `BlendMode.plus` |
| 꽂힌 화살이 방패 뒤에 숨음 | render 순서: flying → shield → holding |
| BGM이 결과 화면에서도 재생 | `endGame()`과 `onRemove()`에서 `FlameAudio.bgm.stop()` |

---

## 9. 렌더 순서 (중요)

```dart
// render() 내부 순서 — 반드시 이 순서 유지
1. castle 배경 (전체 화면)
2. 날아오는 화살 (_ArrowPhase.flying)   // 방패 뒤
3. 방패 (_drawShield)                   // 중간
4. 꽂힌 화살 (_ArrowPhase.holding)      // 방패 앞
5. 홀드 링 + "버텨!" 텍스트
6. 피격 플래시 (붉은 반투명 오버레이)
7. 파티클
8. 점수 (우측 상단)
9. HUD (목숨 아이콘, 막은 화살 수)
```
