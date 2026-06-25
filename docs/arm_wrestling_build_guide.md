# [E5] 팔씨름 게임 (Arm Wrestling) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-25  
**아이디어 제안**: 박수영 연구원  
**파일**: `lib/games/games/arm_wrestling_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`  
**레퍼런스 영상**: https://www.youtube.com/watch?v=Ra8OGKzZzmE (Nintendo Arm Wrestling 1985)

> ⏸️ **개발 보류 (2026-06-25)**  
> 리듬 액션 게임을 먼저 개발하기로 결정.  
> 기획·에셋 전략·AI 프롬프트까지 완성. 코드 구현 미착수.  
> 재개 시 에셋 이미지 생성(정면 가로 구도, Brawl Stars 스타일)부터 시작.

---

## 🎮 게임 컨셉 및 재활 목적

**1인칭 시점**: 환자가 직접 팔씨름 테이블에 앉은 것처럼, 화면 하단에서 자신의 팔/손이 올라와 있고 테이블 너머 동물의 팔/손과 맞잡고 있는 구도입니다. 환자가 어깨를 내회전하면 맞잡은 두 손이 동물 쪽으로 넘어가고, 힘을 빼면 밀려 옵니다. 맞잡은 손이 동물 쪽 테이블 끝까지 넘어가면 승리, 반대편(플레이어 쪽)으로 눌리면 패배입니다.

난이도가 올라갈수록 점점 더 크고 힘이 센 동물이 상대로 등장하여 대결을 펼칩니다:

| 라운드/난이도 | 상대 동물 | 시각적 특징 | 힘 수준 및 성향 |
|-------------|----------|-----------|----------------|
| Level 1~2 | 🐒 **침팬지 (Chimpanzee)** | 작고 마른 갈색 털의 팔, 힘이 약함 | 약함, 끈질기게 버티기보다 순간 움찔거림 |
| Level 3 | 🦧 **오랑우탄 (Orangutan)** | 긴 주황색 털의 팔, 긴 리치 | 보통, 일정한 힘으로 꾸준히 저항함 |
| Level 4~5 | 🦍 **고릴라 (Gorilla)** | 거대한 검은 근육질 팔, 은빛 털(실버백) | 매우 강함, 평소 버티다 갑작스러운 폭발적 밀기 |

줄다리기가 "반복적 당기기(사이클)"인 것과 달리, 팔씨름은 **지속적인 등척성(Isometric) 힘 유지 + 순간적인 등장성(Isotonic) 폭발력**의 조합입니다.

**재활 타겟 관절 및 움직임 (Biomechanics):**
- **어깨 내회전 (Shoulder Internal Rotation)**: 팔씨름에서 상대 팔을 눕히는 주동작. 어깨를 안쪽으로 회전시키는 **최대 수의적 근력 발휘** 훈련.
- **어깨 외회전 (Shoulder External Rotation)**: AI에게 밀릴 때(저항) 또는 방어 시 어깨를 바깥으로 회전시키는 편심성 제어.
- **등척성(Isometric) 유지**: 특정 어깨 회전 각도에서 밀리지 않고 버티기 — 회전근개(Rotator Cuff) 안정화 훈련.
- **등장성(Isotonic) 힘 발휘**: 버티다 순간적으로 내회전하여 상대를 넘기는 폭발적 힘 전환(Rate of Force Development).
- **편심성(Eccentric) 제어**: AI에게 밀릴 때 외회전 방향으로 천천히 버티며 내주는 능력 — 회전근개 이심성 강화.

**임상적 가치:**
- **회전근개(Rotator Cuff) 강화**: 극하근·소원근(IR 주동) + 극상근·대원근(ER 안정) 복합 훈련.
- **등척성↔등장성 전환**: 실생활의 "문 손잡이 돌리기", "병 뚜껑 열기", "선반 물건 꺼내기" 등 어깨 회전 동작 기초.
- **ADL 연계**: 수도꼭지·나사 돌리기, 차 핸들 조작, 머리 위 물건 내리기 등 어깨 회전 의존 일상 동작.

---

## 현재 상태 (2026-06-10 기준)

| 항목 | 상태 |
|------|------|
| 기본 게임 구조 (팔 위치, 힘 계산, 승패 판정) | ❌ 미완성 |
| 팔꿈치 등척성/등장성 힘 감지 및 분류 | ❌ 미완성 |
| 동물 AI 상대 적응형 저항/공격 알고리즘 | ❌ 미완성 |
| 모터 저항 연동 (isometric + isotonic 전환) | ❌ 미완성 |
| 스프라이트 통합 (플레이어 팔, 동물 3종 팔, 테이블, 심판, 배경) | ❌ 미완성 |
| 팔 회전 애니메이션 및 근육 떨림 이펙트 | ❌ 미완성 |
| Brunnstrom 난이도 ↔ 동물 종류 자동 매핑 | ❌ 미완성 |
| BGM 및 SFX | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

```
입력 데이터 (BT 센서: 어깨 내회전/외회전 + 모터 저항 토크)
  ↓ AngleNormalizer (0.0~1.0 → 내회전 최대=1.0, 외회전 최대=0.0)
  ↓
ArmWrestlingFlameGame.update(dt)
  ├── 1. 힘 산출 (_calculatePlayerForce)
  │     ├─ 팔꿈치 각도 변화가 거의 없으면 → 등척성 유지(버티기)
  │     ├─ 팔꿈치 각도가 굽힘 방향으로 빠르게 변하면 → 등장성 공격(밀어넘기기)
  │     └─ 모터의 저항 토크 데이터가 있으면 → 실제 힘 추정에 반영
  ├── 2. 동물 AI 상대 힘 산출 (_updateAI)
  │     └─ 동물 종류별 기본 힘 + 적응형 보정 + 고유 공격/방어 패턴 (파동적 변화)
  ├── 3. 팔 위치(각도) 갱신 (_updateArmAngle)
  │     ├─ _armAngle += (playerForce - aiForce) * dt
  │     ├─ _armAngle > 90° → 상대 동물 팔 완전히 눕힘 → 플레이어 승리!
  │     └─ _armAngle < -90° → 자기 팔 눕혀짐 → 패배
  ├── 4. 모터 저항 전송 (_sendMotorCommand)
  │     └─ AI가 밀 때: "isometric,<targetAngle>,<holdTime>\n"
  │     └─ AI가 공격할 때: "isotonic,<resistance>\n"
  └── 5. 애니메이션 (팔 회전, 근육 떨림, 탁자 흔들림)
  ↓
render(canvas)
  ├── 1. 배경: 체육관 / 팔씨름 대회장 (bg_arena)
  ├── 2. 팔씨름 테이블 (table)
  ├── 3. 플레이어 팔 (arm_player) — 앞쪽, 중심축 회전
  ├── 4. 상대 동물 팔 (arm_chimp / arm_orang / arm_gorilla) — 뒤쪽, 대칭 회전
  ├── 5. 맞잡은 손 (hand_grip) — 중심축 회전
  ├── 6. 심판 (referee) — 카운트다운 및 호루라기
  ├── 7. 힘 충돌 이펙트 (impact_spark) — 팽팽할 때
  ├── 8. 힘 게이지 (strength_gauge)
  └── 9. HUD: 라운드, 점수, 상대 동물 정보
```

---

## 2. 핵심 상태 변수

```dart
// 팔씨름 물리
double _armAngle = 0.0;               // -90°(패배) ~ 0°(중립) ~ +90°(승리)
double _playerForce = 0.0;            // 플레이어가 발휘하는 힘
double _aiForce = 0.0;                // AI가 발휘하는 힘

// 어깨 회전 감지 상태
double _prevShoulderAngle = 0.0;
double _shoulderRotVelocity = 0.0;   // 어깨 회전 각속도 (힘 추정용)
//   양수 = 내회전(Internal Rotation) → 상대 밀어넘기기
//   음수 = 외회전(External Rotation) → 밀리거나 방어
bool _isStraining = false;            // 등척성 유지 중 (회전 없이 버티기)

// AI 동물 상대 시스템
AnimalType _currentAnimal = AnimalType.chimpanzee;
// enum AnimalType { chimpanzee, orangutan, gorilla }
double _aiAttackTimer = 0.0;     // AI 공격 타이밍
bool _aiIsAttacking = false;     // AI가 밀어넘기기 시도 중
double _aiAttackDuration = 0.0;  // 현재 공격 지속 시간

// 라운드 시스템
int _currentRound = 1;
int _playerWins = 0;
int _aiWins = 0;
int _totalRounds = 3;

// 시각 효과
double _muscleShakeIntensity = 0.0;  // 팽팽할 때 떨림 강도
double _impactGlow = 0.0;            // 충돌 이펙트 강도
```

---

## 3. 힘 감지 및 분류 알고리즘 (상세)

팔씨름에서는 어깨 회전 각도 변화와 모터 저항 토크를 조합하여 힘을 추정합니다.  
**내회전(IR) = 공격, 외회전(ER) = 밀리거나 방어.**

```dart
void _calculatePlayerForce(double dt) {
  // 어깨 회전 각속도 계산
  // 양수 = 내회전(Internal Rotation), 음수 = 외회전(External Rotation)
  _shoulderRotVelocity = (_currentShoulderAngle - _prevShoulderAngle) / dt;

  // 1. 등척성 유지 감지: 회전 변화가 거의 없으면서 모터 저항이 존재
  if (_shoulderRotVelocity.abs() < _isometricThreshold) {
    _isStraining = true;
    // 버티고 있는 힘 = 모터의 저항 토크에 비례
    _playerForce = _currentMotorResistance * 0.8;
  }
  // 2. 등장성 공격 감지: 내회전 방향으로 빠르게 회전 → 상대 밀어넘기기
  else if (_shoulderRotVelocity > _attackThreshold) {
    _isStraining = false;
    // 공격 힘 = 내회전 각속도에 비례
    _playerForce = _shoulderRotVelocity * _attackMultiplier;
  }
  // 3. 편심성(밀리는 상태): 외회전 방향으로 밀리지만 저항 중
  else if (_shoulderRotVelocity < -_eccentricThreshold) {
    _isStraining = false;
    // 외회전으로 밀리면서도 저항하는 힘
    _playerForce = max(0, _currentMotorResistance * 0.4);
  }

  _prevShoulderAngle = _currentShoulderAngle;
}
```

---

## 4. AI 상대 공격/방어 패턴 (적응형)

AI는 환자의 재활 수준 및 매치된 동물 종류에 맞춰 공격과 방어를 번갈아가며 수행합니다.

```dart
void _updateAI(double dt) {
  _aiAttackTimer += dt;

  // 동물별 기본 방어(유지) 힘
  double baseDefense;
  switch (_currentAnimal) {
    case AnimalType.chimpanzee: baseDefense = 6.0; break;
    case AnimalType.orangutan:  baseDefense = 10.0; break;
    case AnimalType.gorilla:    baseDefense = 14.0; break;
  }

  // 주기적 공격 시도 (동물에 따라 빈도와 공격 스타일 조절)
  double attackInterval;
  double attackStrengthMultiplier;
  switch (_currentAnimal) {
    case AnimalType.chimpanzee:
      attackInterval = 6.0; // 빈번하지만 약한 깜짝 공격
      attackStrengthMultiplier = 1.3;
      break;
    case AnimalType.orangutan:
      attackInterval = 8.0; // 느리지만 묵직한 밀기
      attackStrengthMultiplier = 1.5;
      break;
    case AnimalType.gorilla:
      attackInterval = 5.0; // 강력한 힘으로 갑작스럽게 내리찍기
      attackStrengthMultiplier = 1.8;
      break;
  }

  if (_aiAttackTimer > attackInterval) {
    _aiIsAttacking = true;
    _aiAttackTimer = 0;
    _aiAttackDuration = 0;
  }

  if (_aiIsAttacking) {
    _aiAttackDuration += dt;
    // 공격: 기본 힘에 배수를 곱함
    _aiForce = baseDefense * attackStrengthMultiplier;
    if (_aiAttackDuration > 1.5) {
      _aiIsAttacking = false; // 공격 종료, 방어로 복귀
    }
  } else {
    // 방어: 기본 유지 및 미세한 떨림(파동) 추가
    double wave = sin(_gameTime * 2.0) * 0.1;
    _aiForce = baseDefense * (1.0 + wave);
  }

  // 적응형 보정: 환자가 너무 밀리면 AI 약화 (환자 보호)
  if (_armAngle < -45) _aiForce *= 0.6;
  if (_armAngle > 45) _aiForce *= 1.25; // 쉽게 이기지 못하도록
}
```

---

## 5. 난이도 및 생체역학 파라미터

| Level | 상대 동물 | AI 기본 힘 | AI 공격 빈도 | 모터 저항 | 라운드 시간 |
|-------|----------|----------|-----------|---------|----------|
| 1 | 🐒 침팬지 | 6 (약함) | 6.0초마다 | 매우 약함 | 45초 |
| 2 | 🐒 침팬지 | 8 | 5.5초마다 | 약함 | 40초 |
| 3 | 🦧 오랑우탄 | 10 (대등) | 8.0초마다 | 보통 | 35초 |
| 4 | 🦍 고릴라 | 12 | 5.0초마다 | 강함 | 30초 |
| 5 | 🦍 고릴라 (실버백) | 14 (강함) | 4.0초마다 | 매우 강함 | 25초 |

---

## 6. 스프라이트 (에셋) 목록

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션/이펙트 |
|--------|-----------|----------------|---------|------------------|
| `bg_arena.png` | 1920×1080 | 화면 전체 | 유지 | 고정 (체육관 배경) |
| `table.png` | 1080×512 | 500×250 px | 투명화 | 고정 (하단 중앙) |
| `arm_player.png` | 1080×720 | 화면 하단 고정 | 투명화 | 합성 원본에서 크롭 — 플레이어 팔(손목까지) |
| `hand_grip_chimp.png` | 1080×720 | 화면 중앙, 좌우 이동 | 투명화 | 합성 원본에서 크롭 — 침팬지와 맞잡은 손 부분만 |
| `hand_grip_orang.png` | 1080×720 | 화면 중앙, 좌우 이동 | 투명화 | 합성 원본에서 크롭 — 오랑우탄과 맞잡은 손 부분만 |
| `hand_grip_gorilla.png` | 1080×720 | 화면 중앙, 좌우 이동 | 투명화 | 합성 원본에서 크롭 — 고릴라와 맞잡은 손 부분만 |
| `arm_chimp.png` | 1080×720 | 화면 상단 고정 | 투명화 | 합성 원본에서 크롭 — 침팬지 팔(손목까지) |
| `arm_orang.png` | 1080×720 | 화면 상단 고정 | 투명화 | 합성 원본에서 크롭 — 오랑우탄 팔(손목까지) |
| `arm_gorilla.png` | 1080×720 | 화면 상단 고정 | 투명화 | 합성 원본에서 크롭 — 고릴라 팔(손목까지) |

> **제작 순서**: AI로 합성 1장 생성 → Photoshop/Blender에서 상단(동물 팔) / 중앙(맞잡은 손) / 하단(플레이어 팔) 3구역으로 크롭 → 각각 저장. 크롭 경계선은 손목 위 20~30px 여유를 두고 겹치게 잘라야 이음새가 자연스러움.
| `referee.png` | 512×512 | 150×250 px | 투명화 | 카운트다운 시 흔들림 |
| `muscle_bulge.png`| 256×256 | 80×60 px | **검정 유지** | 힘줄 때 플레이어/동물 이두 펄스 (Plus) |
| `impact_spark.png`| 256×256 | 100×100 px | **검정 유지** | 팽팽한 대치 이펙트 (Plus) |
| `sweat_drop.png` | 128×128 | 15×20 px | 투명화 | 땀 파티클 (힘쓸 때) |
| `strength_gauge.png`| 512×64 | 400×30 px | 투명화 | 게이지 틀 |
| `face_chimp_neutral.png` | 256×256 | 120×120 px | 투명화 | 침팬지 기본 표정 |
| `face_chimp_attack.png` | 256×256 | 120×120 px | 투명화 | 침팬지 공격 표정 (이빨 드러냄) |
| `face_chimp_pain.png` | 256×256 | 120×120 px | 투명화 | 침팬지 고통 표정 (밀릴 때) |
| `face_orang_neutral.png` | 256×256 | 130×130 px | 투명화 | 오랑우탄 기본 표정 |
| `face_orang_attack.png` | 256×256 | 130×130 px | 투명화 | 오랑우탄 공격 표정 |
| `face_orang_pain.png` | 256×256 | 130×130 px | 투명화 | 오랑우탄 고통 표정 |
| `face_gorilla_neutral.png` | 256×256 | 150×150 px | 투명화 | 고릴라 기본 표정 |
| `face_gorilla_attack.png` | 256×256 | 150×150 px | 투명화 | 고릴라 공격 표정 (포효) |
| `face_gorilla_pain.png` | 256×256 | 150×150 px | 투명화 | 고릴라 고통 표정 (밀릴 때) |

### pubspec.yaml 등록

```yaml
flutter:
  assets:
    - assets/images/arm_wrestling/
    - assets/audio/arm_wrestling/
```

> 폴더 단위로 등록하면 파일 추가 시 자동 포함. 에셋 파일은 `assets/images/arm_wrestling/` 하위에 저장.

### 발표용 최소 에셋 (MVP)

```
필수 (7장):
  arm_player.png          (플레이어 팔)
  arm_chimp.png           (Level 1~2 상대)
  arm_gorilla.png         (Level 4~5 상대)
  hand_grip.png           (맞잡은 손)
  table.png               (팔씨름 테이블)
  strength_gauge.png      (힘 게이지)
  bg_arena.png            (배경)

선택 (없으면 코드 절차적 그래픽 유지):
  arm_orang.png           (Level 3 상대)
  referee.png             (심판)
  muscle_bulge.png        (근육 펄스 이펙트)
  impact_spark.png        (충돌 불꽃)
  sweat_drop.png          (땀 파티클)
```

---

## 7. 애니메이션 연출 (상세)

### 7-1. 팔 이동 메카닉 (핵심) — 1인칭 시점

3장을 레이어로 쌓아 사용. 팔은 고정, 손만 이동:

닌텐도 1985 아케이드 팔씨름 스타일 — 정면 가로 구도, 양 팔 좌우 고정, 중앙 손만 회전.

```
[화면 왼쪽 고정] arm_player.png          ← 플레이어 팔, 손목까지 (움직임 없음)
[화면 중앙 회전] hand_grip_<animal>.png  ← _armAngle에 따라 좌우로 기울어짐 (회전)
[화면 오른쪽 고정] arm_<animal>.png      ← 동물 팔, 손목까지 (움직임 없음)
```

*   `hand_grip_<animal>` 은 화면 중앙 고정 + **pivot 회전**:  
    `_armAngle` 양수 → 오른쪽으로 기울어짐 → 동물 팔이 밀리는 느낌.  
    `_armAngle` 음수 → 왼쪽으로 기울어짐 → 플레이어 팔이 밀리는 느낌.
*   회전 범위: 최대 ±45° (`_armAngle.clamp(-90, 90) / 90 * 45`).
*   크롭 기준: 손목 테이핑 밴드 중앙에서 자름. 양쪽 20~30px 겹치게 잘라 이음새 가림.

### 7-2. 근육/힘 이펙트
*   **근육 펄스 (muscle_bulge)**: 등척성 유지(버티기) 중일 때, 플레이어 팔 또는 동물의 팔 이두근 위치에 `muscle_bulge` (BlendMode.plus)를 `OpacityEffect.to(0.3, alternate: true, infinite: true)` 로 맥동. 힘을 주고 있는 느낌을 실감나게 표현.
*   **충돌 불꽃 (impact_spark)**: 양쪽 힘이 비슷할 때(대치 상태, `|armAngle| < 10°`) 맞잡은 손 주변에서 `impact_spark` (BlendMode.plus) 를 ScaleEffect로 번쩍임. 팽팽한 긴장감 연출.
*   **떨림**: 대치 상태에서 전체 팔 구조물에 `MoveEffect.by(Vector2(2, 0), EffectController(duration: 0.02, repeatCount: -1, alternate: true))`. 떨림 강도는 양쪽 힘의 균형에 비례.

### 7-3. 동물 표정 애니메이션

동물 얼굴은 화면 상단 좌측 또는 상대 팔 위에 고정 표시. `_armAngle` 기준으로 3단계 표정 전환:

| 상태 | 조건 | 표정 스프라이트 |
|------|------|----------------|
| 기본 | `_armAngle` -30° ~ +30° | `face_<animal>_neutral.png` |
| 공격 | `_aiIsAttacking == true` 또는 `_armAngle < -30°` (플레이어가 밀릴 때) | `face_<animal>_attack.png` |
| 고통 | `_armAngle > 30°` (동물이 밀릴 때) | `face_<animal>_pain.png` |

```dart
// render()에서 현재 동물 표정 선택
Image get _currentAnimalFace {
  if (_aiIsAttacking || _armAngle < -30) return _faceAttack[_currentAnimal]!;
  if (_armAngle > 30) return _facePain[_currentAnimal]!;
  return _faceNeutral[_currentAnimal]!;
}
```

> 표정 전환은 즉시(스냅) 전환. 트랜지션 불필요.

### 7-4. 환경 파티클
*   **땀 파티클**: 힘을 쓸 때 캐릭터 및 동물의 머리 주변에서 `sweat_drop` 파티클이 1~2초마다 생성되어 아래로 떨어짐.
*   **승리 연출**: 상대 동물의 팔이 테이블에 닿을 때 테이블에서 큰 먼지/충격파 이펙트 발생.

---

## 8. AI 이미지 프롬프트

**공통 스타일**: `modern cartoon mobile game art style inspired by Brawl Stars and Clash Royale, exaggerated proportions, thick black outlines, smooth cel-shading with soft highlights, vibrant saturated colors, clean and polished, 2D mobile game asset`

> **배경색 고정**: 모든 스프라이트 배경은 **크로마키 그린 #00FF00 (RGB 0, 255, 0)** 사용.  
> 포토샵 "색상 범위 선택(Select by Color Range)" 허용오차 10~20으로 한 번에 제거 가능.  
> ⚠️ `lime green` / `bright green` 등 모호한 표현 금지.

*   **배경 (bg_arena)** `1920×1080`: `Vibrant arm wrestling competition arena, wooden stage with spotlights, cheering crowd silhouettes in background, bright arcade-style colors, inspired by 1985 Nintendo Arm Wrestling arcade, wide 16:9, resolution 1920x1080`
*   **테이블 (table)** `1080×512`: `Close-up front view of a sturdy wooden arm wrestling table with padded elbow rests and center grip peg, seen slightly from above, bold outlines, arcade cartoon style, pure chroma key green background hex #00FF00 RGB(0,255,0), resolution 1080x512`

> **합성 원본 제작 방법**: 아래 프롬프트로 전체 장면 1장 생성 → **좌측(플레이어 팔)** / **중앙(맞잡은 손)** / **우측(동물 팔)** 3구역으로 크롭.

> **크롭 전략**: 플레이어와 동물 팔 모두 손목에 **굵은 흰색 테이핑 밴드** 삽입. 밴드 중앙 기준으로 크롭하면 이음새가 가려짐.

*   **침팬지 합성 원본** `1080×720`: `Close-up front view of an arm wrestling match, modern cartoon mobile game style inspired by Brawl Stars and Clash Royale. Two forearms dominate the frame. LEFT: muscular human forearm in a teal sleeve, white wrist tape band, elbow resting on table at the bottom-left, fist raised upright. RIGHT: thin brown-furred chimpanzee forearm, white wrist tape band, elbow on table at bottom-right, fist raised upright. Both fists clasped in classic arm wrestling grip at the center-top of the image — thumbs pointing up, knuckles interlocked sideways (NOT a handshake). Chimpanzee's grimacing cartoon face faintly visible in the upper-right background. Wooden table edge visible at the bottom. Modern cartoon style inspired by Brawl Stars and Clash Royale, thick black outlines, smooth cel-shading with soft highlights, vibrant saturated colors, clean and polished. Pure chroma key green background hex #00FF00 RGB(0,255,0), resolution 1080x720`
*   **오랑우탄 합성 원본** `1080×720`: `Close-up front view of an arm wrestling match, modern cartoon mobile game style inspired by Brawl Stars and Clash Royale. Two forearms dominate the frame. LEFT: muscular human forearm in a teal sleeve, white wrist tape band, elbow resting on table at the bottom-left, fist raised upright. RIGHT: long orange-furred orangutan forearm, white wrist tape band, elbow on table at bottom-right, fist raised upright. Both fists clasped in classic arm wrestling grip at the center-top of the image — thumbs pointing up, knuckles interlocked sideways (NOT a handshake). Orangutan's wise stern cartoon face faintly visible in the upper-right background. Wooden table edge visible at the bottom. Modern cartoon style inspired by Brawl Stars and Clash Royale, thick black outlines, smooth cel-shading with soft highlights, vibrant saturated colors, clean and polished. Pure chroma key green background hex #00FF00 RGB(0,255,0), resolution 1080x720`
*   **고릴라 합성 원본** `1080×720`: `Close-up front view of an arm wrestling match, modern cartoon mobile game style inspired by Brawl Stars and Clash Royale. Two forearms dominate the frame. LEFT: muscular human forearm in a teal sleeve, white wrist tape band, elbow resting on table at the bottom-left, fist raised upright. RIGHT: massive black-and-silver-furred gorilla forearm, white wrist tape band, elbow on table at bottom-right, giant fist raised upright. Both fists clasped in classic arm wrestling grip at the center-top of the image — thumbs pointing up, knuckles interlocked sideways (NOT a handshake). Gorilla's intimidating roaring cartoon face faintly visible in the upper-right background. Wooden table edge visible at the bottom. Modern cartoon style inspired by Brawl Stars and Clash Royale, thick black outlines, smooth cel-shading with soft highlights, vibrant saturated colors, clean and polished. Pure chroma key green background hex #00FF00 RGB(0,255,0), resolution 1080x720`
*   **심판 (referee)** `512×512`: `A cartoon referee character wearing a striped shirt, blowing a whistle, upper body only, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 512x512`
*   **침팬지 표정 — 기본 (face_chimp_neutral)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, chimpanzee face, neutral calm expression, slightly smug, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **침팬지 표정 — 공격 (face_chimp_attack)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, chimpanzee face, aggressive expression, teeth bared, wide eyes, veins popping, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **침팬지 표정 — 고통 (face_chimp_pain)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, chimpanzee face, pained grimacing expression, eyes squinted, sweating, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **오랑우탄 표정 — 기본 (face_orang_neutral)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, orangutan face, neutral calm expression, wise and composed, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **오랑우탄 표정 — 공격 (face_orang_attack)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, orangutan face, intense focused expression, teeth clenched, determined, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **오랑우탄 표정 — 고통 (face_orang_pain)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, orangutan face, straining pained expression, eyes watering, sweating heavily, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **고릴라 표정 — 기본 (face_gorilla_neutral)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, gorilla face, intimidating neutral expression, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **고릴라 표정 — 공격 (face_gorilla_attack)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, gorilla face, roaring aggressive expression, mouth wide open showing teeth, veins on forehead, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **고릴라 표정 — 고통 (face_gorilla_pain)** `256×256`: `Modern cartoon mobile game style inspired by Brawl Stars, gorilla face, shocked disbelief expression, eyes wide, sweating, front view, pure chroma key green background, hex #00FF00, RGB(0,255,0), resolution 256x256`
*   **근육 펄스 (muscle_bulge)** `256×256`: `A glowing muscular energy pulse, bright orange-red glow, solid black background, resolution 256x256`
*   **충돌 불꽃 (impact_spark)** `256×256`: `Electric sparks and lightning bolts colliding, bright yellow and white, solid black background, resolution 256x256`

---

## 9. 오디오

| 구분 | 이벤트 | 파일명 |
|---|--------|------|
| **BGM** | 일반 진행 (긴장감 있는 스포츠 음악) | `Arm_Battle.mp3` |
| **SFX** | 심판 호루라기 (라운드 시작) | `whistle_start.ogg` |
| **SFX** | 힘쓰기 시 으르렁/끙 소리 (루프) | `strain_loop.ogg` |
| **SFX** | 대치 상태 불꽃 소리 | `electric_clash.ogg` |
| **SFX** | 동물 상대 고유 소리 (침팬지 끼끼, 고릴라 크르릉) | `animal_grunt.ogg` |
| **SFX** | 팔 넘어뜨리기 성공 (쾅!) | `slam_table.ogg` |
| **SFX** | 패배 (팔 넘어감) | `defeat_groan.ogg` |
| **SFX** | 최종 우승 | `champion_fanfare.ogg` |

---

## 10. 개발 순서 (8단계)

가이드 원칙: **입력 → 렌더 → 로직 → 이펙트 순서. 매 단계 `flutter run` 후 슬라이더로 직접 확인.**

| 단계 | 목표 | Claude에게 맡길 일 |
|------|------|-----------------|
| 1 | 빈 게임 실행 | `ArmWrestlingFlameGame` + `ArmWrestlingGame` StatefulWidget 골격 생성 |
| 2 | 입력 연결 | `PART:lShoulder`(내/외회전) 스트림 구독 + `setSimPosition()` 슬라이더 연결, `_isSim` 플래그 |
| 3 | 핵심 오브젝트 | `render()`에 팔/테이블/게이지를 절차적 그래픽으로 — 팔 회전 Pivot 시스템 구현 |
| 4 | 게임 로직 | `update()`에 힘 분류(등척성/등장성/편심성) + AI 패턴 + `_armAngle` 물리 + 승패 판정 |
| 5 | 모터 연동 | `isometric` / `isotonic` 명령 전송, 안전 상한 설정, 승패 시 `x\n` |
| 6 | 스프라이트 교체 | 절차적 그래픽 → PNG 로드(`onLoad`) → `canvas.drawImageRect()` 교체 |
| 7 | 파티클·이펙트 | 근육 펄스(BlendMode.plus), 충돌 불꽃, 땀 파티클, 떨림 이펙트 |
| 8 | HUD·난이도 연결 | 라운드 표시·타이머, BGM/SFX 8종, BrunnstromStage → 동물 자동 매핑 |

### 기본 파일 구조

```dart
// lib/games/games/arm_wrestling_game.dart

// ① FlameGame 본체
class ArmWrestlingFlameGame extends FlameGame {
  final Stream<double>? inputStream;
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  @override
  Future<void> onLoad() async { /* 에셋 로드, 스트림 구독 */ }

  @override
  void update(double dt) { /* 힘 계산, AI, 물리, 승패 — 로직만 */ }

  @override
  void render(Canvas canvas) { /* 그리기만 — 로직 금지 */ }

  void setSimPosition(double v) { /* 슬라이더 연결 */ }
}

// ② Flutter StatefulWidget 래퍼
class ArmWrestlingGame extends StatefulWidget { ... }
class _ArmWrestlingGameState extends State<ArmWrestlingGame> {
  bool _isSim = false; // BT 미연결 시 슬라이더 모드

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Stack(children: [
      GameWidget(game: _game),
      if (_isSim) Slider(...),
      // 일시정지 / 정지 버튼
    ]));
  }
}
```

---

## 11. Claude 프롬프트 템플릿

### 단계별 기본 템플릿

```
이 프로젝트는 Flutter/Flame 1.36.0 재활 게임 앱이다.
현재 단계 목표: [한 가지 기능]
수정할 파일: lib/games/games/arm_wrestling_game.dart
수정 금지: game_base.dart, game_motor_controller.dart
완료 조건:
  1) flutter run 후 팔씨름 게임 진입 가능
  2) 슬라이더로 _armAngle 변화 확인 가능
  3) 기존 BT 연결 로직 변경 없음
작업 전 변경 계획 요약 → 작업 후 TODO 목록 제시
```

### 스프라이트 연결 프롬프트 (단계 6 시작 시)

```
assets/images/arm_wrestling/ 에 아래 파일이 추가됐다:
  arm_player.png, arm_chimp.png, arm_gorilla.png : 512×512, 투명 배경
  hand_grip.png : 256×256, 투명 배경
  table.png : 1080×512, 투명 배경
  bg_arena.png : 1920×1080, 배경 유지

1) pubspec.yaml에 assets/images/arm_wrestling/ 경로 추가
2) onLoad()에서 images.load()로 로드
3) render()에서 canvas.drawImageRect()로 교체
4) 기존 절차적 그래픽 코드 제거
```

### 피드백 예시

```
❌ "팔씨름이 재미없다"
✅ "AI가 너무 규칙적으로 공격한다. 침팬지는 더 랜덤하게, 고릴라는 더 묵직하게 바꿔라"

❌ "이펙트 추가해줘"
✅ "대치 상태(|_armAngle| < 10°)에서 hand_grip 위치에 impact_spark를 BlendMode.plus로 번쩍이게 해라"
```

---

## 12. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 팔꿈치 각도 자체를 "힘"으로 사용 | 각도는 위치일 뿐 힘이 아님. **각속도** 또는 **모터 저항 토크**를 힘의 대용으로 사용해야 함 |
| AI가 밀 때 모터가 환자 팔을 갑자기 세게 밀어버림 | 등장성 저항은 반드시 점진적(ramping)으로 증가시키고, 최대 토크 상한(safety limit)을 설정 |
| 편심성 수축(밀리면서 버티기)을 무시하고 이진(밀기/안 밀기)로만 처리 | 천천히 밀리면서도 저항하는 것이 근력 훈련의 핵심. `_playerForce`가 양수이지만 AI보다 약해서 밀리는 상황을 자연스럽게 표현해야 함 |
| 팔 회전 시 두 팔 이미지가 어긋나 보임 | 반드시 공통 Pivot 점(맞잡은 손 중심)을 기준으로 `canvas.rotate()` 한 뒤 두 팔을 동시에 그려야 함 |
| 한 번에 전체 게임 구현 요청 | 8단계 순서대로 분리해서 요청. 매 단계 `flutter run` 후 슬라이더로 확인 |
| render()에 게임 로직 넣기 | 로직은 `update()`, 그리기만 `render()` |
| 스프라이트 없이 완성 시도 | 절차적 그래픽으로 먼저 동작 확인 후 PNG 교체 (단계 3→6) |
| BT 코드 건드리기 | `game_motor_controller.dart` 수정 금지 명시 필수 |

---

## 12. 렌더 순서

```dart
// 1인칭 시점 렌더 순서
1. 배경 (bg_arena) — 체육관, 화면 전체
2. 팔씨름 테이블 (table) — 화면 중앙 수평선
3. 심판 (referee) — 테이블 측면 상단
4. 상대 동물 팔 (arm_chimp / arm_orang / arm_gorilla) — 화면 상단에서 내려오는 구도
5. 플레이어 팔 (arm_player) — 화면 하단에서 올라오는 구도 (고정)
6. 맞잡은 손 (hand_grip) — 중앙, _armAngle에 따라 좌우 이동
7. 근육 펄스 오버레이 (muscle_bulge / BlendMode.plus) — hand_grip 위
8. 충돌 불꽃 (impact_spark / BlendMode.plus) — hand_grip 주변
9. 땀 파티클 (sweat_drop) — 동물 팔 상단
10. 힘 게이지 바 (strength_gauge) — 화면 하단 HUD
11. HUD: 라운드 표시 (●○○), 남은 시간, 상대 동물 아이콘 및 이름
```
