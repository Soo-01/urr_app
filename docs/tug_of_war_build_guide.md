# [E4] 줄다리기 게임 (Tug of War) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-10  
**아이디어 제안**: 박수영 연구원  
**파일**: `lib/games/games/tug_of_war_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 🎮 게임 컨셉 및 재활 목적

플레이어는 정글 절벽 위 다리에서 동물 상대와 밧줄을 잡고 줄다리기 승부를 펼칩니다. 다리 양쪽 끝에 각각 플레이어와 동물이 서 있으며, 밧줄을 자기 쪽으로 당겨 **상대를 절벽 아래로 떨어뜨리면 승리**합니다. 반대로 자신이 밀려나면 절벽 아래로 떨어지며 패배합니다.

난이도가 올라갈수록 점점 강한 동물이 상대로 등장합니다:

| 라운드/난이도 | 상대 동물 | 시각적 특징 | 힘 수준 |
|-------------|----------|-----------|--------|
| Level 1~2 | 🐒 **침팬지 (Chimpanzee)** | 작고 날쌔지만 힘은 약함 | 약함 |
| Level 3 | 🦧 **오랑우탄 (Orangutan)** | 긴 팔, 중간 체구 | 보통 |
| Level 4~5 | 🦍 **고릴라 (Gorilla)** | 거대한 체구, 은색 등 (실버백) | 강함 |

**재활 타겟 관절 및 움직임 (Biomechanics):**
- **팔꿈치 굽힘/폄 (Elbow Flexion/Extension)**: 밧줄을 잡고 **반복적으로 당기기** — 팔꿈치를 굽혀 당기고, 펴서 다시 잡고, 다시 당기는 왕복 운동.
- **등장성(Isotonic) 근력 훈련**: 모터가 밧줄을 반대 방향으로 저항하므로, 환자는 저항에 맞서 관절을 움직여야 함.
- **지구력(Endurance) 훈련**: 한 번이 아닌 지속적 반복 운동을 통해 근지구력 향상.

**임상적 가치:**
- **등장성 반복 운동**: 일정 저항 하에서 팔꿈치를 반복 굽힘/폄 → 실제 일상(문 열기, 물건 들어올리기)과 유사한 기능적 근력 회복.
- **피드백 기반 동기 부여**: "동물을 떨어뜨리겠다"는 도전 심리가 반복 운동의 지루함을 없앰.
- **적응형 저항**: 환자의 힘에 맞게 AI의 저항이 실시간 조절되어 과부하 방지.

---

## 현재 상태 (2026-06-10 기준)

| 항목 | 상태 |
|------|------|
| 기본 게임 구조 (밧줄 당기기, 위치 산출) | ❌ 미완성 |
| 팔꿈치 반복 굽힘/폄 → 당기기 변환 로직 | ❌ 미완성 |
| 동물 AI 상대 저항 알고리즘 (적응형) | ❌ 미완성 |
| 모터 등장성 저항 연동 (`isotonic` 명령) | ❌ 미완성 |
| 스프라이트 통합 (동물 3종, 절벽, 밧줄, 배경) | ❌ 미완성 |
| 패배/승리 시 떨어지기 낙하 애니메이션 | ❌ 미완성 |
| Brunnstrom 난이도 ↔ 동물 종류 자동 매핑 | ❌ 미완성 |
| BGM 및 SFX | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

```
입력 데이터 (BT 센서: 팔꿈치 굽힘/폄)
  ↓ AngleNormalizer (0.0~1.0)
  ↓
TugOfWarFlameGame.update(dt)
  ├── 1. 당기기 감지 (_detectPull)
  │     └─ 팔꿈치 각도의 변화 패턴(폄→굽힘 사이클) 감지
  │     └─ 한 사이클 완료 시 _pullPower 누적 (속도·ROM에 비례)
  ├── 2. 동물 AI 힘 산출 (_updateAnimalAI)
  │     └─ 동물 종류별 기본 저항 + 적응형 보정 (환자가 잘하면 AI 약간 강화)
  ├── 3. 밧줄 위치 갱신 (_updateRopePosition)
  │     └─ _ropePosition += (_pullPower - _aiPower) * dt
  │     └─ ropePosition > threshold → 동물이 절벽 아래로 떨어짐 → 승리!
  │     └─ ropePosition < -threshold → 플레이어가 절벽 아래로 떨어짐 → 패배
  ├── 4. 모터 저항 명령 전송 (_sendMotorResistance)
  │     └─ 동물 AI 저항에 비례하는 등장성 저항 명령
  └── 5. 애니메이션 업데이트 (동물 모션, 밧줄 떨림, 떨어지기 연출)
  ↓
render(canvas)
  ├── 1. 배경: 정글 협곡 + 구름 아래 낭떠러지 (bg_jungle_cliff)
  ├── 2. 절벽 아래 깊은 협곡 (abyss_depth) — 패배/승리 시 낙하 목적지
  ├── 3. 다리 / 플랫폼 (bridge_platform) — 양쪽 끝이 절벽
  ├── 4. 밧줄 (rope) — 수평, 위치가 좌우로 이동
  ├── 5. 중앙 깃발 (flag) — 밧줄 중앙에 부착
  ├── 6. 플레이어 캐릭터 (player_pull) — 좌측 절벽 끝
  ├── 7. 동물 상대 (animal_chimp / animal_orang / animal_gorilla) — 우측 절벽 끝
  ├── 8. 떨어지기 애니메이션 (falling_sprite) — 승패 결정 시
  ├── 9. 힘 게이지 바 (power_gauge)
  └── 10. HUD: 라운드, 남은 시간, 상대 동물 이름
```

---

## 2. 핵심 상태 변수

```dart
// 관절 매핑
double _prevElbowAngle = 0.0;
double _currentElbowAngle = 0.0;
bool _isPulling = false;
int _pullCount = 0;

// 줄다리기 물리
double _ropePosition = 0.0;      // -1.0(패배 절벽) ~ 0.0(중앙) ~ +1.0(승리 절벽)
double _pullPower = 0.0;
double _aiPower = 0.0;

// 동물 상대 시스템
AnimalType _currentAnimal = AnimalType.chimpanzee;
// enum AnimalType { chimpanzee, orangutan, gorilla }

// 라운드 시스템
int _currentRound = 1;
int _playerWins = 0;
int _animalWins = 0;
int _totalRounds = 3;            // 3전 2선승

// 떨어지기 연출
bool _isFalling = false;         // 떨어지기 애니메이션 진행 중
bool _isPlayerFalling = false;   // true: 플레이어 떨어짐, false: 동물 떨어짐
double _fallProgress = 0.0;      // 낙하 진행률 (0.0 ~ 1.0)

// 시각 효과
double _ropeShake = 0.0;
double _playerLean = 0.0;
```

---

## 3. 당기기 감지 알고리즘 (상세)

팔꿈치의 "펴기 → 굽히기" 한 사이클을 하나의 "당기기(Pull)"로 인식합니다.

```dart
void _detectPull(double dt) {
  double angleDelta = _currentElbowAngle - _prevElbowAngle;

  if (!_isPulling && angleDelta < -_pullThreshold) {
    _isPulling = true;
    _pullStartAngle = _currentElbowAngle;
  }

  if (_isPulling && angleDelta >= 0) {
    _isPulling = false;
    double pullRange = (_pullStartAngle - _currentElbowAngle).abs();
    double pullSpeed = pullRange / _pullDuration;
    _pullPower += pullRange * pullSpeed * _powerMultiplier;
    _pullCount++;
  }

  _prevElbowAngle = _currentElbowAngle;
}
```

---

## 4. 동물 AI 저항 알고리즘 (적응형)

```dart
void _updateAnimalAI(double dt) {
  // 동물별 기본 힘
  double baseStrength;
  switch (_currentAnimal) {
    case AnimalType.chimpanzee: baseStrength = 7.0; break;
    case AnimalType.orangutan:  baseStrength = 11.0; break;
    case AnimalType.gorilla:    baseStrength = 15.0; break;
  }

  // 적응형 보정
  double adaptiveFactor = 1.0;
  if (_ropePosition > 0.3) adaptiveFactor = 1.15;
  if (_ropePosition < -0.3) adaptiveFactor = 0.85;

  // 동물별 고유 행동 패턴
  double wave;
  switch (_currentAnimal) {
    case AnimalType.chimpanzee:
      wave = sin(_gameTime * 3.0) * 0.2; // 빠르고 불규칙적으로 당김
      break;
    case AnimalType.orangutan:
      wave = sin(_gameTime * 1.5) * 0.15; // 느리지만 꾸준히 당김
      break;
    case AnimalType.gorilla:
      wave = sin(_gameTime * 1.0) * 0.1 +
             (sin(_gameTime * 0.3) > 0.8 ? 0.3 : 0.0); // 평소 유지 + 가끔 폭발적 당기기
      break;
  }
  _aiPower = baseStrength * adaptiveFactor * (1.0 + wave);
}
```

---

## 5. 떨어지기 애니메이션 (승패 결정 시)

게임의 핵심 재미 요소입니다. 밧줄이 한쪽으로 완전히 넘어가면 진 쪽이 절벽 아래로 떨어집니다.

```dart
void _triggerFall(bool isPlayerFalling) {
  _isFalling = true;
  _isPlayerFalling = isPlayerFalling;
  _fallProgress = 0.0;

  // 모터 즉시 정지
  motorController.send("x\n");
}

void _updateFall(double dt) {
  if (!_isFalling) return;
  _fallProgress += dt * 1.5; // 1.5초에 걸쳐 낙하 완료

  if (_fallProgress >= 1.0) {
    _isFalling = false;
    if (_isPlayerFalling) {
      _animalWins++;
    } else {
      _playerWins++;
    }
    // 다음 라운드 또는 최종 결과
    _checkMatchResult();
  }
}
```

### 떨어지기 시각 연출 (4단계)
1. **비틀거림 (0.0~0.2)**: 진 쪽 캐릭터가 절벽 끝에서 양팔을 휘저으며 균형을 잃음. `RotateEffect.by(0.3, alternate: true, repeatCount: 3)` 적용.
2. **발 미끄러짐 (0.2~0.4)**: 발이 절벽 끝에서 미끄러지며 먼지 파티클 발생. 캐릭터의 Y 좌표가 살짝 내려감.
3. **낙하 (0.4~0.8)**: 캐릭터가 `MoveEffect.by(Vector2(0, screenHeight))` + `ScaleEffect.to(0.3)` (멀어지는 느낌)으로 아래로 떨어짐. 동시에 "아아아~!" SFX 재생.
4. **착지/물보라 (0.8~1.0)**: 화면 하단에서 물보라(splash) 또는 먼지 구름 파티클 폭발. 쿵! SFX 재생.

---

## 6. 난이도 및 생체역학 파라미터

| Level | 상대 동물 | AI 기본 힘 | 저항 (모터) | 사이클당 필요 ROM | 라운드 시간 |
|-------|----------|----------|-----------|----------------|----------|
| 1 | 🐒 침팬지 | 7 (약함) | 없음 | 30° | 60초 |
| 2 | 🐒 침팬지 | 9 | 약함 | 45° | 50초 |
| 3 | 🦧 오랑우탄 | 11 (대등) | 보통 | 60° | 45초 |
| 4 | 🦍 고릴라 | 13 | 강함 | 75° | 40초 |
| 5 | 🦍 고릴라 (실버백) | 15 (매우 강함) | 매우 강함 | 90° | 35초 |

---

## 7. 스프라이트 (에셋) 목록

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션/이펙트 |
|--------|-----------|----------------|---------|------------------|
| **[배경 & 환경]** | | | | |
| `bg_jungle_cliff.png` | 1920×1080 | 화면 전체 | 유지 | 고정 (정글 협곡 배경) |
| `bridge_platform.png` | 1024×256 | 800×100 px | 투명화 | 고정 (양쪽 절벽 다리) |
| `abyss_depth.png` | 512×512 | 300×300 px | **검정 유지** | 하단 깊은 협곡 (어두운 그라데이션) |
| `rope.png` | 1024×128 | 800×30 px | 투명화 | X축 이동 + 떨림 |
| `flag.png` | 256×256 | 80×100 px | 투명화 | 밧줄 중앙 따라 이동 |
| **[캐릭터]** | | | | |
| `player_pull_sheet.png` | 1024×512 | 200×300 px | 투명화 | **1×4 스프라이트 시트** (당기기) |
| `animal_chimp_sheet.png` | 1024×512 | 180×280 px | 투명화 | **1×4 시트** (침팬지 당기기) |
| `animal_orang_sheet.png` | 1024×512 | 220×320 px | 투명화 | **1×4 시트** (오랑우탄 당기기) |
| `animal_gorilla_sheet.png`| 1024×512 | 280×380 px | 투명화 | **1×4 시트** (고릴라 당기기) |
| **[UI & 이펙트]** | | | | |
| `power_gauge_bg/fill` | 512×64 | 400×30 px | 투명화/검정 | 게이지 |
| `dust_cloud.png` | 128×128 | 30~50 px | **검정 유지** | 발밑 먼지 (Screen) |
| `splash_water.png` | 256×256 | 150×150 px | **검정 유지** | 낙하 후 물보라 (Screen) |
| `confetti.png` | 128×128 | 10~20 px | 투명화 | 승리 시 색종이 |

---

## 8. AI 이미지 프롬프트

**공통**: `cartoon cel-shaded, bold black outlines, vibrant colors, jungle adventure style, mobile game asset`

*   **배경 (bg_jungle_cliff)**: `A dramatic jungle canyon scene with two cliff edges connected by a rope bridge, deep misty abyss below, lush tropical vegetation, wide 16:9`
*   **다리 (bridge_platform)**: `A wooden rope bridge platform viewed from the side, two cliff edges with wooden planks in between, cartoon style, solid lime green background, 4:1 ratio`
*   **침팬지 시트 (animal_chimp_sheet)**: `A spritesheet of 4 frames showing a cute cartoon chimpanzee pulling a rope, right-facing, progressive pulling motion, expressive face, solid lime green background, 4:1 aspect ratio`
*   **오랑우탄 시트 (animal_orang_sheet)**: `A spritesheet of 4 frames showing a strong cartoon orangutan with long arms pulling a rope, right-facing, progressive pulling motion, reddish-brown fur, solid lime green background, 4:1 aspect ratio`
*   **고릴라 시트 (animal_gorilla_sheet)**: `A spritesheet of 4 frames showing a massive cartoon silverback gorilla pulling a rope, right-facing, progressive pulling motion, muscular build, intimidating but cartoon-cute, solid lime green background, 4:1 aspect ratio`
*   **물보라 (splash_water)**: `A cartoon water splash explosion, bright blue and white, solid black background`

---

## 9. 오디오

| 구분 | 이벤트 | 파일명 |
|---|--------|------|
| **BGM** | 일반 진행 (신나는 정글 모험 음악) | `Jungle_Battle.mp3` |
| **SFX** | 당기기 사이클 완료 | `pull_grunt.ogg` |
| **SFX** | 밧줄 팽팽해지는 소리 | `rope_tension.ogg` |
| **SFX** | 동물 울음 (침팬지: 끼끼, 고릴라: 우우!) | `animal_cry.ogg` |
| **SFX** | 떨어지기 — 비명/울음 | `falling_scream.ogg` |
| **SFX** | 떨어지기 — 물보라/착지 | `splash_landing.ogg` |
| **SFX** | 최종 승리 팡파레 | `victory_fanfare.ogg` |

---

## 10. 작업 체크리스트

### Phase 1 — 당기기 감지 및 물리 로직
- [ ] FlameGame 골격 + `PART:lElbow` 구독
- [ ] 팔꿈치 폄→굽힘 사이클 감지 알고리즘 구현
- [ ] `_ropePosition` 물리 계산 (플레이어 힘 - 동물 AI 힘)
- [ ] 동물별 AI 저항 및 행동 패턴 구현 (침팬지/오랑우탄/고릴라)

### Phase 2 — 떨어지기 연출 및 모터 연동
- [ ] `_triggerFall()` 및 4단계 낙하 애니메이션 구현
- [ ] `isotonic,<resistance>` 등장성 저항 전송
- [ ] 라운드 종료/낙하 시 모터 정지

### Phase 3 — 스프라이트 및 애니메이션
- [ ] 14종 에셋 로드 (동물 3종 시트 포함)
- [ ] `SpriteAnimationComponent`로 동물/플레이어 당기기 모션
- [ ] 밧줄+깃발 X축 이동 및 떨림 이펙트
- [ ] 낙하 후 물보라(splash_water) BlendMode.screen 파티클

### Phase 4 — 오디오 및 라운드 시스템
- [ ] 3전 2선승 라운드 + 난이도에 따른 동물 교체
- [ ] BGM 및 SFX 7종 트리거 연동
- [ ] 승리/패배 결과 화면 (동물이 떨어지는 씬 vs 플레이어가 떨어지는 씬)

### Phase 5 — 마무리
- [ ] Brunnstrom 난이도별 동물 종류/AI 힘/저항 자동 매핑 검증
- [ ] 실기기 모터 저항 체감 테스트
- [ ] `flutter build apk --release`

---

## 11. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 팔꿈치 각도의 절대값으로 당기기 판정 | 반드시 **각도의 변화량(사이클)**을 감지해야 함 |
| AI 저항이 너무 강해 환자가 전혀 못 이김 | 적응형 보정으로 환자가 밀릴 때는 AI를 약화시켜야 함 |
| 떨어지기 애니메이션 중에도 입력을 받음 | `_isFalling == true`일 때는 모든 입력과 AI 갱신을 차단해야 함 |
| 동물 크기가 난이도와 무관하게 동일 | 침팬지는 작고, 고릴라는 크게 — 시각적으로 난이도를 직관적으로 전달 |

---

## 12. 렌더 순서

```dart
1. 배경: 정글 협곡 (bg_jungle_cliff)
2. 절벽 아래 깊은 협곡 (abyss_depth) — 하단
3. 다리/플랫폼 (bridge_platform) — 중앙
4. 밧줄 (rope) — X축 이동 중
5. 중앙 깃발 (flag) — 밧줄 위에 부착
6. 플레이어 캐릭터 (player_pull) — 좌측 절벽 끝
7. 동물 상대 (animal_*_sheet) — 우측 절벽 끝 (난이도에 따라 교체)
8. 발밑 먼지 파티클 (dust_cloud / BlendMode.screen)
9. === 떨어지기 애니메이션 (진 쪽 캐릭터가 낙하) ===
10. 물보라/착지 파티클 (splash_water / BlendMode.screen) — 하단
11. 승리 시 색종이 파티클 (confetti)
12. 힘 게이지 바 (power_gauge_bg + fill)
13. HUD: 라운드 (●○○), 남은 시간, 상대 동물 이름/아이콘
```
