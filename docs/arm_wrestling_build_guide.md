# [E5] 팔씨름 게임 (Arm Wrestling) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-10  
**아이디어 제안**: 박수영 연구원  
**파일**: `lib/games/games/arm_wrestling_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 🎮 게임 컨셉 및 재활 목적

플레이어는 테이블에서 동물 상대와 1:1 팔씨름 대결을 벌입니다. 화면 중앙에 플레이어의 팔과 동물의 팔이 맞잡고 있으며, 환자가 팔꿈치를 힘껏 굽히면 상대 동물의 팔을 자기 쪽으로 넘기고, 힘을 빼면 상대에게 밀립니다. 상대 동물의 팔을 완전히 눕히면(테이블 패드에 닿으면) 승리, 자기 팔이 눕혀지면 패배입니다.

난이도가 올라갈수록 점점 더 크고 힘이 센 동물이 상대로 등장하여 대결을 펼칩니다:

| 라운드/난이도 | 상대 동물 | 시각적 특징 | 힘 수준 및 성향 |
|-------------|----------|-----------|----------------|
| Level 1~2 | 🐒 **침팬지 (Chimpanzee)** | 작고 마른 갈색 털의 팔, 힘이 약함 | 약함, 끈질기게 버티기보다 순간 움찔거림 |
| Level 3 | 🦧 **오랑우탄 (Orangutan)** | 긴 주황색 털의 팔, 긴 리치 | 보통, 일정한 힘으로 꾸준히 저항함 |
| Level 4~5 | 🦍 **고릴라 (Gorilla)** | 거대한 검은 근육질 팔, 은빛 털(실버백) | 매우 강함, 평소 버티다 갑작스러운 폭발적 밀기 |

줄다리기가 "반복적 당기기(사이클)"인 것과 달리, 팔씨름은 **지속적인 등척성(Isometric) 힘 유지 + 순간적인 등장성(Isotonic) 폭발력**의 조합입니다.

**재활 타겟 관절 및 움직임 (Biomechanics):**
- **팔꿈치 굽힘 (Elbow Flexion)**: 상대를 넘기기 위해 팔꿈치를 강하게 굽히는 **주동적 근력 발휘**.
- **등척성(Isometric) 유지**: 상대의 힘에 맞서 현재 각도에서 버티기 — 특정 각도에서 일정 시간 힘을 유지하는 훈련.
- **등장성(Isotonic) 힘 발휘**: 버티다가 순간적으로 상대를 밀어넘기는 폭발적 굽힘 — 빠른 힘 전환(Rate of Force Development) 훈련.
- **편심성(Eccentric) 제어**: 상대에게 밀릴 때(팔이 펴지는 방향) 천천히 버티며 내주는 능력 — 편심성 수축으로 근 손상 없이 근력을 키움.

**임상적 가치:**
- **최대 수의적 수축(MVIC)에 가까운 힘 발휘 유도**: 경쟁 상황이 환자의 최대 노력을 끌어냄.
- **등척성↔등장성 전환 훈련**: 실생활에서 "무거운 물건을 들고 있다가 올리기"와 같은 복합 근수축 패턴 훈련.
- **ADL 연계**: 문 닫기/열기, 무거운 물건 들기, 수도꼭지 돌리기 등 일상 동작의 근력 기초.

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
입력 데이터 (BT 센서: 팔꿈치 굽힘/폄 + 힘/토크 추정)
  ↓ AngleNormalizer (0.0~1.0)
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
double _armAngle = 0.0;           // -90°(패배) ~ 0°(중립) ~ +90°(승리)
double _playerForce = 0.0;        // 플레이어가 발휘하는 힘
double _aiForce = 0.0;            // AI가 발휘하는 힘

// 힘 감지 상태
double _prevElbowAngle = 0.0;
double _elbowVelocity = 0.0;     // 팔꿈치 각속도 (힘 추정용)
bool _isStraining = false;        // 힘주기 상태 (등척성 유지 중)

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

팔씨름에서는 "단순히 각도가 바뀌는 것"이 아니라 "얼마나 강하게 밀고 있는가"를 추정해야 합니다.

```dart
void _calculatePlayerForce(double dt) {
  _elbowVelocity = (_currentElbowAngle - _prevElbowAngle) / dt;

  // 1. 등척성 유지 감지: 각도 변화가 거의 없으면서 모터 저항이 존재
  if (_elbowVelocity.abs() < _isometricThreshold) {
    _isStraining = true;
    // 버티고 있는 힘 = 모터의 저항 토크에 비례 (센서 데이터 활용)
    _playerForce = _currentMotorResistance * 0.8;
  }
  // 2. 등장성 공격 감지: 굽힘 방향으로 빠르게 움직임
  else if (_elbowVelocity > _attackThreshold) {
    _isStraining = false;
    // 공격 힘 = 각속도에 비례 (빠르게 굽힐수록 강한 공격)
    _playerForce = _elbowVelocity * _attackMultiplier;
  }
  // 3. 편심성(밀리는 상태): 펴지는 방향으로 움직이지만 저항 중
  else if (_elbowVelocity < -_eccentricThreshold) {
    _isStraining = false;
    // 밀리면서도 저항하는 힘 (완전히 힘을 빼면 급속히 밀림)
    _playerForce = max(0, _currentMotorResistance * 0.4);
  }

  _prevElbowAngle = _currentElbowAngle;
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
| `arm_player.png` | 512×512 | 300×150 px | 투명화 | 중심축(손잡이) 기준 회전 |
| `arm_chimp.png` | 512×512 | 260×130 px | 투명화 | 침팬지 팔 (대칭 회전, 갈색 털) |
| `arm_orang.png` | 512×512 | 300×150 px | 투명화 | 오랑우탄 팔 (대칭 회전, 긴 주황 털) |
| `arm_gorilla.png` | 512×512 | 350×180 px | 투명화 | 고릴라 팔 (대칭 회전, 거대한 은/검은 털) |
| `hand_grip.png` | 256×256 | 100×100 px | 투명화 | 맞잡은 손 (중심축) |
| `referee.png` | 512×512 | 150×250 px | 투명화 | 카운트다운 시 흔들림 |
| `muscle_bulge.png`| 256×256 | 80×60 px | **검정 유지** | 힘줄 때 플레이어/동물 이두 펄스 (Plus) |
| `impact_spark.png`| 256×256 | 100×100 px | **검정 유지** | 팽팽한 대치 이펙트 (Plus) |
| `sweat_drop.png` | 128×128 | 15×20 px | 투명화 | 땀 파티클 (힘쓸 때) |
| `strength_gauge.png`| 512×64 | 400×30 px | 투명화 | 게이지 틀 |

---

## 7. 애니메이션 연출 (상세)

### 7-1. 팔 회전 메카닉 (핵심)
*   두 팔(플레이어 팔과 현재 동물 팔)과 맞잡은 손(`hand_grip`)은 하나의 **회전축(Pivot)**을 공유합니다.
*   `_armAngle` (-90° ~ +90°)에 따라 전체 팔 구조물이 회전합니다.
*   렌더링 시 `canvas.save()` → `canvas.translate(pivotX, pivotY)` → `canvas.rotate(_armAngle * pi / 180)` → 두 팔 그리기 → `canvas.restore()`.

### 7-2. 근육/힘 이펙트
*   **근육 펄스 (muscle_bulge)**: 등척성 유지(버티기) 중일 때, 플레이어 팔 또는 동물의 팔 이두근 위치에 `muscle_bulge` (BlendMode.plus)를 `OpacityEffect.to(0.3, alternate: true, infinite: true)` 로 맥동. 힘을 주고 있는 느낌을 실감나게 표현.
*   **충돌 불꽃 (impact_spark)**: 양쪽 힘이 비슷할 때(대치 상태, `|armAngle| < 10°`) 맞잡은 손 주변에서 `impact_spark` (BlendMode.plus) 를 ScaleEffect로 번쩍임. 팽팽한 긴장감 연출.
*   **떨림**: 대치 상태에서 전체 팔 구조물에 `MoveEffect.by(Vector2(2, 0), EffectController(duration: 0.02, repeatCount: -1, alternate: true))`. 떨림 강도는 양쪽 힘의 균형에 비례.

### 7-3. 환경 파티클
*   **땀 파티클**: 힘을 쓸 때 캐릭터 및 동물의 머리 주변에서 `sweat_drop` 파티클이 1~2초마다 생성되어 아래로 떨어짐.
*   **승리 연출**: 상대 동물의 팔이 테이블에 닿을 때 테이블에서 큰 먼지/충격파 이펙트 발생.

---

## 8. AI 이미지 프롬프트

**공통**: `cartoon cel-shaded, bold black outlines, vibrant colors, sports competition atmosphere, mobile game asset`

*   **배경 (bg_arena)**: `A brightly lit arm wrestling competition arena, wooden stage, cheering crowd silhouettes, spotlights, wide 16:9`
*   **테이블 (table)**: `A sturdy wooden arm wrestling table with elbow pads and hand grips, seen from front, solid lime green background`
*   **플레이어 팔 (arm_player)**: `A strong muscular cartoon human arm from elbow to hand, forearm angled up, fist clenched, facing right, solid lime green background`
*   **침팬지 상대 팔 (arm_chimp)**: `A thin cartoon chimpanzee arm with brown fur, from elbow to hand, forearm angled up, fist clenched, facing left, solid lime green background`
*   **오랑우탄 상대 팔 (arm_orang)**: `A long cartoon orangutan arm with bright orange fur, from elbow to hand, forearm angled up, fist clenched, facing left, solid lime green background`
*   **고릴라 상대 팔 (arm_gorilla)**: `A massive muscular cartoon gorilla arm with thick black and silver fur, giant fist clenched, facing left, solid lime green background`
*   **맞잡은 손 (hand_grip)**: `Two cartoon hands gripping each other tightly in an arm wrestling lock, front view, solid lime green background`
*   **심판 (referee)**: `A cartoon referee character wearing a striped shirt, blowing a whistle, full body, solid lime green background`
*   **근육 펄스 (muscle_bulge)**: `A glowing muscular energy pulse, bright orange-red glow, solid black background`
*   **충돌 불꽃 (impact_spark)**: `Electric sparks and lightning bolts colliding, bright yellow and white, solid black background`

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

## 10. 작업 체크리스트

### Phase 1 — 힘 감지 및 물리 엔진
- [ ] FlameGame 골격 + `PART:lElbow` 구독
- [ ] 등척성/등장성/편심성 힘 분류 알고리즘 구현
- [ ] `_armAngle` 물리 계산 (playerForce - aiForce) 및 경계값 처리
- [ ] 동물별 AI 저항 및 행동 패턴 구현 (침팬지/오랑우탄/고릴라)

### Phase 2 — 모터 연동
- [ ] 등척성 유지 시: `isometric,<targetAngle>,<holdTime>` 명령
- [ ] 등장성 발휘 시: `isotonic,<resistance>` 명령
- [ ] AI 공격 중: 모터가 환자 팔을 펴는 방향으로 저항 인가
- [ ] 승패 판정 시: `x\n` 모터 정지

### Phase 3 — 스프라이트 및 회전 애니메이션
- [ ] 12종 에셋 로드 (동물 3종 팔 포함)
- [ ] 중심축(Pivot) 기반 팔 회전 렌더링 시스템 구현
- [ ] 근육 펄스(muscle_bulge) 및 충돌 불꽃(impact_spark) BlendMode.plus 연출
- [ ] 떨림 이펙트 (대치 상태에서 강도 비례)

### Phase 4 — 오디오 및 라운드
- [ ] 3전 2선승 라운드 + 난이도에 따른 동물 교체
- [ ] BGM 및 SFX 8종 트리거 연동
- [ ] 승리/패배 결과 화면

### Phase 5 — 마무리
- [ ] 난이도별 동물 종류/AI 힘/저항 자동 매핑 검증 및 체감 테스트
- [ ] 편심성 수축 시 모터 안전 한계치 초과하지 않는지 검증
- [ ] 태블릿 실기기 빌드 및 성능 테스트

---

## 11. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 팔꿈치 각도 자체를 "힘"으로 사용 | 각도는 위치일 뿐 힘이 아님. **각속도** 또는 **모터 저항 토크**를 힘의 대용으로 사용해야 함 |
| AI가 밀 때 모터가 환자 팔을 갑자기 세게 밀어버림 | 등장성 저항은 반드시 점진적(ramping)으로 증가시키고, 최대 토크 상한(safety limit)을 설정 |
| 편심성 수축(밀리면서 버티기)을 무시하고 이진(밀기/안 밀기)로만 처리 | 천천히 밀리면서도 저항하는 것이 근력 훈련의 핵심. `_playerForce`가 양수이지만 AI보다 약해서 밀리는 상황을 자연스럽게 표현해야 함 |
| 팔 회전 시 두 팔 이미지가 어긋나 보임 | 반드시 공통 Pivot 점(맞잡은 손 중심)을 기준으로 `canvas.rotate()` 한 뒤 두 팔을 동시에 그려야 함 |

---

## 12. 렌더 순서

```dart
1. 배경 (bg_arena)
2. 심판 (referee) — 배경 뒤편
3. 팔씨름 테이블 (table) — 하단 중앙
4. === 팔 회전 그룹 (canvas.rotate로 일괄 회전) ===
   4a. 상대 동물 팔 (arm_chimp / arm_orang / arm_gorilla) — 뒤쪽 (난이도에 맞게 선택)
   4b. 맞잡은 손 (hand_grip) — 중심
   4c. 플레이어 팔 (arm_player) — 앞쪽
5. 근육 펄스 오버레이 (muscle_bulge / BlendMode.plus) — 팔 위
6. 충돌 불꽃 (impact_spark / BlendMode.plus) — 손 주변
7. 땀 파티클 (sweat_drop) — 캐릭터/동물 이마
8. 힘 게이지 바 (strength_gauge)
9. HUD: 라운드 표시 (●○○), 남은 시간, 상대 동물 아이콘 및 이름
```
