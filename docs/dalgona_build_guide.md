# [C4] 달고나 게임 (Dalgona Challenge) 제작 가이드
**최초 작성**: 2026-06-10  
**최종 수정**: 2026-06-10  
**아이디어 제안**: 박수영 연구원  
**파일**: `lib/games/games/dalgona_game.dart`  
**수정 금지**: `game_base.dart`, `game_motor_controller.dart`

---

## 🎮 게임 컨셉 및 재활 목적

플레이어는 포장마차의 달고나 장인이 됩니다. 뜨거운 설탕을 녹여 달고나를 만들고, 틀에 찍힌 모양(별, 하트, 우산, 원 등)을 바늘로 조심스럽게 따라가며 떼어냅니다. 성공하면 달고나 컬렉션에 추가되고, 실패하면 달고나가 깨집니다.

**핵심 메카닉: 경로 추적(Path Tracing)**  
화면에 표시된 달고나 모양의 윤곽선(경로)을 관절 움직임으로 커서(바늘)를 따라 이동시켜야 합니다. 경로를 벗어나면 달고나에 금이 가고, 너무 많이 벗어나면 깨집니다. 느리고 정밀한 제어가 핵심입니다.

**재활 타겟 관절 및 움직임 (Biomechanics):**
- **어깨 굽힘/폄 (Shoulder Flexion/Extension)**: 바늘(커서)의 **Y축(상하)** 이동. 팔을 올리면 바늘이 위로, 내리면 아래로.
- **팔꿈치 굽힘/폄 (Elbow Flexion/Extension)**: 바늘(커서)의 **X축(좌우)** 이동. 팔꿈치를 굽히면 바늘이 한쪽으로, 펴면 반대쪽으로.
- **복합 관절 협응 (Combined)**: 별, 우산 등 복잡한 모양을 따라가려면 어깨와 팔꿈치를 동시에 미세 조절해야 함. 공동운동 패턴 분리 훈련의 핵심.

**임상적 가치:**
- **정밀 운동 제어(Fine Motor Control)**: 빠르게 움직이는 것이 아닌, 느리고 정확하게 움직이는 것을 훈련. 편마비 환자의 떨림(tremor) 억제 및 위치 인식(고유수용감각) 향상.
- **관절 분리 운동**: 어깨만 움직여야 할 구간(수직선)과 팔꿈치만 움직여야 할 구간(수평선)이 번갈아 나오므로, 공동운동 패턴에서 벗어나는 연습이 자연스럽게 유도됨.
- **등속성(Isokinetic) 훈련**: 일정한 속도로 관절을 움직이는 능력 향상.
- **ADL 연계**: 글씨 쓰기, 단추 끼우기, 열쇠 돌리기 등 일상생활의 정밀 조작과 유사한 운동 패턴.

---

## 현재 상태 (2026-06-10 기준)

| 항목 | 상태 |
|------|------|
| 기본 게임 구조 (경로 데이터, 커서 이동, 판정) | ❌ 미완성 |
| 어깨(Y축) + 팔꿈치(X축) 복합 관절 매핑 | ❌ 미완성 |
| 경로 이탈 판정 및 달고나 금 가는 연출 | ❌ 미완성 |
| 모양별 경로 데이터(별, 하트, 우산, 원) | ❌ 미완성 |
| 스프라이트 통합 (달고나, 바늘, 배경) | ❌ 미완성 |
| 파티클 이펙트 (설탕 가루, 금 갈라짐) | ❌ 미완성 |
| Brunnstrom 난이도 및 경로 허용 폭 연동 | ❌ 미완성 |
| **배경 음악 (BGM)** | ❌ 미완성 |
| **효과음 (바늘 긁기, 금 가기, 성공, 깨짐)** | ❌ 미완성 |

---

## 1. 게임 구조 한눈에 보기

```
입력 데이터 (BT 센서: 어깨 굽힘/폄, 팔꿈치 굽힘/폄)
  ↓ 관절 가동 범위(ROM) Calibration 데이터 적용
  ↓ AngleNormalizer → 어깨: 0.0~1.0 (Y축), 팔꿈치: 0.0~1.0 (X축)
  ↓
DalgonaFlameGame.update(dt)
  ├── 1. 커서(바늘) 위치 갱신 (_updateNeedlePosition)
  │     ├─ 어깨 → 바늘 Y 좌표 (위/아래)
  │     └─ 팔꿈치 → 바늘 X 좌표 (좌/우)
  ├── 2. 경로 이탈 판정 (_checkPathDeviation)
  │     ├─ 바늘 위치와 현재 경로 구간의 최단 거리 계산
  │     ├─ 거리 ≤ _pathWidth  → onPath (정상)
  │     ├─ 거리 > _pathWidth  → deviation (이탈 → 금 누적)
  │     └─ _crackLevel >= _maxCrack → 달고나 깨짐 → endGame()
  ├── 3. 진행 상태 업데이트 (_updateProgress)
  │     ├─ 바늘이 경로 위에 있을 때만 진행률(_progress) 증가
  │     └─ _progress >= 100% → 완벽 떼어냄 → 성공!
  ├── 4. 애니메이션 업데이트
  │     ├─ 설탕 가루 파티클 (바늘 이동 중 미세 파티클)
  │     ├─ 금 균열 애니메이션 (이탈 시 확장)
  │     └─ 완성 시 팡파레 이펙트
  └── 5. 타이머 / 체력 관리
        └─ 제한 시간 내에 경로 완주 필요 (Level에 따라 조절)
  ↓
render(canvas)
  ├── 1. 배경: 포장마차 노점 (bg_street_stall)
  ├── 2. 달고나 원판 (dalgona_base) — 연한 갈색 원형
  ├── 3. 모양 틀 각인 경로 (Path 렌더링) — 점선/실선으로 표시
  ├── 4. 진행된 경로 (완료 구간은 색상 변경)
  ├── 5. 금 균열 (crack_overlay) — 이탈 누적에 따라 확장
  ├── 6. 바늘 커서 (needle_cursor)
  ├── 7. 설탕 가루 파티클 (sugar_particle)
  ├── 8. 진행률 게이지 및 금 균열 레벨 표시
  └── 9. HUD: 시간, 점수, 남은 달고나 수
```

---

## 2. 핵심 상태 변수

```dart
// 관절 매핑 상태
double shoulderNorm = 0.0;        // 어깨 정규화 (0.0~1.0) → Y축
double elbowNorm = 0.0;           // 팔꿈치 정규화 (0.0~1.0) → X축

// 경로 추적 상태
List<Offset> _shapePath = [];     // 현재 모양의 경로 좌표 리스트 (별, 하트 등)
int _currentSegment = 0;          // 현재 추적 중인 경로 구간 인덱스
double _progress = 0.0;           // 전체 경로 진행률 (0.0 ~ 1.0)

// 판정 상태
double _crackLevel = 0.0;         // 금 균열 누적량 (0.0 ~ _maxCrack)
late double _maxCrack;            // 허용 최대 금 (난이도별 상이)
late double _pathWidth;           // 경로 허용 폭 (난이도별 상이)

// 게임 상태
int _score = 0;
int _currentShape = 0;            // 현재 도전 중인 모양 인덱스
late int _clearTarget;            // 클리어 목표 (성공적으로 떼어낸 달고나 수)
double _remainingTime = 0.0;      // 남은 시간

// 시각 효과
double _needleShakeTimer = 0.0;   // 이탈 시 바늘 흔들림
bool _isOnPath = true;            // 현재 경로 위에 있는지 여부
```

---

## 3. 난이도 및 생체역학 파라미터

어깨(Y축)와 팔꿈치(X축)를 동시에 제어해야 하므로, 난이도에 따라 경로 복잡도와 허용 폭을 세밀하게 조절합니다.

```dart
// difficultyLevel 1~5 기준
double get _pathWidth => 60.0 - (config.difficultyLevel * 8.0);
// Level 1: 52px(매우 넓은 길), Level 5: 20px(바늘 하나 겨우 지나가는 폭)

double get _maxCrack => 100.0 + (6 - config.difficultyLevel) * 20.0;
// Level 1: 200(매우 관대), Level 5: 120(3~4번 이탈이면 깨짐)

double get _timeLimit => 90.0 + (6 - config.difficultyLevel) * 15.0;
// Level 1: 165초, Level 5: 105초

_clearTarget = 2 + config.difficultyLevel;
// Level 1: 3개, Level 5: 7개
```

| Level | 경로 허용 폭 | 최대 금 허용치 | 제한 시간 | 모양 복잡도 | 클리어 목표 |
|-------|-----------|-------------|---------|----------|----------|
| 1 | 52px (매우 넓음) | 200 (매우 관대) | 165초 | 원(Circle) | 3개 |
| 2 | 44px | 180 | 150초 | 삼각형, 사각형 | 4개 |
| 3 | 36px (보통) | 160 (보통) | 135초 | 별(Star) | 5개 |
| 4 | 28px | 140 | 120초 | 하트(Heart) | 6개 |
| 5 | 20px (매우 좁음) | 120 (엄격) | 105초 | 우산(Umbrella) | 7개 |

---

## 4. 경로(Shape Path) 데이터 구조 및 생성 방법

경로는 화면 좌표의 `List<Offset>` 형태로 저장하며, 달고나 원판 중앙을 기준으로 정규화합니다.

### 4-1. 모양별 경로 정의
```dart
enum DalgonaShape {
  circle,     // Level 1: 가장 쉬움 (어깨/팔꿈치 동시 원운동)
  triangle,   // Level 2: 직선 3개 (관절 분리 시작)
  square,     // Level 2: 직선 4개 (수직선=어깨만, 수평선=팔꿈치만)
  star,       // Level 3: 꼭짓점 5개 (방향 전환 잦음)
  heart,      // Level 4: 곡선 + 꼭짓점 (고난도 곡선 추적)
  umbrella,   // Level 5: 곡선 + 직선 + 손잡이 (최고 난이도)
}
```

### 4-2. 경로 좌표 생성 알고리즘
```dart
List<Offset> _generatePath(DalgonaShape shape, double radius) {
  switch (shape) {
    case DalgonaShape.circle:
      // 원: 0~2π를 64등분하여 점 생성
      return List.generate(64, (i) {
        double angle = (i / 64) * 2 * pi;
        return Offset(cos(angle) * radius, sin(angle) * radius);
      });

    case DalgonaShape.star:
      // 별: 외부 5꼭짓점 + 내부 5꼭짓점을 교차 연결
      List<Offset> points = [];
      for (int i = 0; i < 10; i++) {
        double angle = (i / 10) * 2 * pi - pi / 2;
        double r = (i % 2 == 0) ? radius : radius * 0.45;
        points.add(Offset(cos(angle) * r, sin(angle) * r));
      }
      // 각 꼭짓점 사이를 8등분 보간하여 매끄럽게
      return _interpolatePoints(points, 8);

    // ... heart, umbrella 등도 유사하게 정의
  }
}
```

### 4-3. 재활 관점에서의 경로 설계 원칙
| 경로 구간 | 요구되는 관절 움직임 | 재활 의미 |
|----------|-------------------|----------|
| **수직 직선 (↑↓)** | 어깨 굽힘/폄만, 팔꿈치 고정 | 어깨 분리 운동 |
| **수평 직선 (←→)** | 팔꿈치 굽힘/폄만, 어깨 고정 | 팔꿈치 분리 운동 |
| **대각선 (↗↘)** | 어깨 + 팔꿈치 동시 | 관절 간 협응 |
| **곡선 (⌒)** | 비율이 계속 변하는 복합 | 고유수용감각 정밀 훈련 |
| **꼭짓점 (∠)** | 급격한 방향 전환 | 운동 계획(Motor Planning) |

---

## 5. 경로 이탈 판정 알고리즘 (상세)

바늘과 경로 사이의 거리를 실시간으로 측정하여 판정합니다.

```dart
void _checkPathDeviation() {
  // 1. 바늘 위치 (화면 좌표)
  Offset needlePos = Offset(
    _elbowNorm * size.x,   // X = 팔꿈치
    (1.0 - _shoulderNorm) * size.y, // Y = 어깨 (반전: 팔 올리면 위)
  );

  // 2. 현재 경로 구간의 가장 가까운 점까지의 거리 계산
  double minDist = double.infinity;
  int closestSegment = _currentSegment;

  // 현재 구간 및 인접 구간(±3)에서 최단 거리 탐색
  for (int i = max(0, _currentSegment - 3);
       i < min(_shapePath.length - 1, _currentSegment + 3); i++) {
    double dist = _pointToSegmentDistance(
      needlePos, _shapePath[i], _shapePath[i + 1]
    );
    if (dist < minDist) {
      minDist = dist;
      closestSegment = i;
    }
  }

  // 3. 판정
  if (minDist <= _pathWidth) {
    // 경로 위: 진행률 증가
    _isOnPath = true;
    _currentSegment = closestSegment;
    _progress = _currentSegment / (_shapePath.length - 1);
  } else {
    // 경로 이탈: 금 누적
    _isOnPath = false;
    double deviationAmount = (minDist - _pathWidth) * 0.1; // 초과 거리에 비례
    _crackLevel += deviationAmount;

    if (_crackLevel >= _maxCrack) {
      _breakDalgona(); // 달고나 깨짐 → 다음 달고나 또는 게임오버
    }
  }
}
```

---

## 6. 스프라이트 (에셋) 목록

| 파일명 | 캔버스 크기 | 게임 내 크기 | 배경 처리 | 애니메이션/이펙트 |
|--------|-----------|----------------|---------|------------------|
| **[배경 & 환경]** | | | | |
| `bg_street_stall.png` | 1920×1080 | 화면 전체 | 유지 | 고정 배경 |
| `dalgona_base.png` | 1080×1080 | 500×500 px | 투명화 | 고정 (중앙) |
| `dalgona_shape_overlay.png` | 1080×1080 | 500×500 px | 투명화 | 성공 시 분리 애니 |
| **[상호작용 오브젝트]** | | | | |
| `needle_cursor.png` | 256×256 | 40×120 px | 투명화 | 이탈 시 흔들림 (Effect) |
| `crack_line.png` | 512×512 | 가변 | **검정 유지** | 이탈량에 따라 확장 (Plus) |
| **[UI & 가이드]** | | | | |
| `progress_ring.png` | 256×256 | 80×80 px | **검정 유지** | 원형 진행률 게이지 (Plus) |
| `guide_arrow.png` | 256×256 | 50×50 px | **검정 유지** | 다음 이동 방향 가이드 (Plus) |
| `life_dalgona.png` | 256×256 | 50×50 px × 3 | 투명화 | 남은 달고나 수 |
| **[파티클 소스]** | | | | |
| `sugar_particle.png` | 128×128 | 5~10 px | 투명화 | 파티클 시스템 (미세 가루) |
| `crack_fragment.png` | 128×128 | 20~40 px | 투명화 | 깨질 때 조각 파티클 |
| `sparkle.png` | 128×128 | 10~15 px | **검정 유지** | 성공 시 반짝 (Screen) |

---

## 7. 애니메이션 연출 및 구현 가이드 (상세)

### 7-1. 트랜스폼 이펙트 (Flame Effects API)
*   **바늘 이탈 흔들림**: 경로를 벗어났을 때 `MoveEffect.by(Vector2(5, 0), EffectController(duration: 0.03, repeatCount: 4, alternate: true))` 적용. 바늘이 떨리는 느낌.
*   **달고나 분리 애니메이션**: 성공 시 `dalgona_shape_overlay`(떼어낸 모양)가 `MoveEffect.by(Vector2(0, -80))` + `OpacityEffect.to(0.0)` 으로 하늘로 떠올라 사라짐.
*   **금 균열 확장**: `crack_line`의 `ScaleEffect.to(crackLevel / maxCrack)` 을 매 프레임 업데이트. 금이 점점 퍼지는 느낌.
*   **진행 방향 가이드 화살표**: `guide_arrow`가 경로의 다음 구간 방향으로 자동 회전 (`angle` 속성 갱신). 바늘이 어느 방향으로 가야 하는지 실시간 안내.

### 7-2. 파티클 시스템
*   **설탕 가루 (바늘 이동 중)**: 바늘이 경로 위를 따라갈 때 매 0.1초마다 `sugar_particle` 1~2개 생성. 중력으로 아래로 떨어지며 0.5초 후 소멸. 달고나를 깎고 있는 느낌.
*   **깨짐 파티클 (실패 시)**: 달고나가 깨질 때 `crack_fragment` 15~20개가 중앙에서 사방으로 퍼짐 (`AcceleratedParticle`, 랜덤 방향, 중력 적용). 조각이 바닥으로 떨어지는 연출.
*   **성공 반짝 (완성 시)**: `sparkle` (BlendMode.screen) 파티클이 달고나 주변에서 원형으로 퍼져나감. 금박 빛나는 느낌.

### 7-3. 경로 렌더링 애니메이션
*   **미완료 경로**: 달고나 위에 **점선**으로 표시. `canvas.drawPath()` + `PathEffect.dashPathEffect([10, 10])` 사용.
*   **완료 경로**: 바늘이 지나간 구간은 **황금색 실선**으로 변경. 진행감을 시각적으로 전달.
*   **현재 위치 강조**: 바늘이 있는 경로 위치에 작은 원형 글로우 표시.

---

## 8. 스프라이트 제작 파이프라인

### 단계 1: AI 이미지 생성
**공통 스타일**: `Korean street food market style, warm golden lighting, nostalgic retro atmosphere, cartoon rendering style, cel-shaded, bold black outlines, mobile game asset`

**[초록 배경 - 투명화용]**
*   **배경 (bg_street_stall)**: `A cozy Korean night market food stall (pojangmacha) with warm yellow lights, wooden counter, steam rising, nostalgic atmosphere, wide 16:9 panoramic view` (배경 자체는 유지)
*   **달고나 원판 (dalgona_base)**: `A perfectly round golden-brown Korean dalgona (honeycomb candy) seen from directly above, flat disc shape, slightly caramelized surface texture, thin crispy edges, solid bright lime green background (#00FF00)`
*   **모양 오버레이 (dalgona_shape_overlay)**: `A star-shaped piece of golden-brown dalgona candy, perfectly cut out, seen from above, solid bright lime green background (#00FF00)` (별, 하트, 우산 등 모양별 5종 제작)
*   **바늘 커서 (needle_cursor)**: `A thin sharp silver sewing needle with a small round head, vertical orientation pointing down, shiny metallic surface, solid bright lime green background (#00FF00)`
*   **달고나 목숨 아이콘 (life_dalgona)**: `A tiny cute golden-brown dalgona candy icon, round shape with a small star stamp, readable at small sizes, solid bright lime green background (#00FF00)`
*   **파티클: 설탕 가루 (sugar_particle)**: `A tiny golden-brown sugar crystal crumb, irregularly shaped, solid bright lime green background (#00FF00)`
*   **파티클: 깨진 조각 (crack_fragment)**: `A small broken piece of golden-brown candy, jagged edges, solid bright lime green background (#00FF00)`

**[검정 배경 - BlendMode.plus/screen 용]**
*   **금 균열 (crack_line)**: `Thin branching crack lines spreading outward from center, bright white glowing fracture pattern on solid black background (#000000)`
*   **진행 원형 게이지 (progress_ring)**: `A thin glowing circular progress ring, bright golden-yellow neon outline, pure black background (#000000)`
*   **방향 가이드 (guide_arrow)**: `A small glowing directional arrow pointing right, bright cyan neon color (#00E5FF), pure black background (#000000)`
*   **성공 반짝 (sparkle)**: `A single bright golden sparkle star burst, radiating light rays, pure black background (#000000)`

### 단계 2: 타이포그래피 (수동 제작)
*   `ui_text_clear.png`: "성공!", "완벽!" (금박 효과, 초록 배경)
*   `ui_text_crack.png`: "금이 갔어요!", "조심!" (빨간 경고, 초록 배경)
*   `ui_text_break.png`: "깨졌다!" (깨진 글자 효과, 초록 배경)

### 단계 3: 배경 제거 (투명화) 및 빛 효과 처리
*   초록 배경 에셋: `remove.bg`로 투명화 후 초록 잔여 픽셀 수동 정리. PNG-24 저장.
*   검정 배경 에셋: 절대 배경 제거 금지. 순수 검정(RGB 0,0,0) 확인 후 그대로 저장.

### 단계 4: 리사이징 및 압축
*   배경: 1920×1080 유지.
*   달고나/바늘/UI: 256~512px로 축소.
*   파티클 소스: 128px 이하로 축소.
*   `tinypng.com` 으로 용량 최적화.

### 단계 5: 게임 적용
*   `assets/images/dalgona/` 폴더에 소문자_언더스코어 네이밍으로 저장.
*   `pubspec.yaml` 에셋 등록 후 `Flame.images.loadAll()` 로 캐싱.

---

## 9. 오디오 및 SFX

### BGM

| 파일 | 경로 | 재생 시점 | 볼륨 |
|------|------|---------|------|
| `Dalgona_Calm.mp3` | `assets/audio/dalgona/` | 게임 시작 ~ 일반 진행 | 0.7 |
| `Dalgona_Tense.mp3` | `assets/audio/dalgona/` | 금 균열 70% 이상 시 | 0.9 |

차분하고 집중력을 높이는 어쿠스틱/로파이 분위기의 BGM. 금이 많이 갔을 때는 긴장감 있는 트랙으로 전환.

### SFX

| 이벤트 | 추천 효과음 | 파일명 |
|--------|-----------|------|
| 바늘이 경로 위를 이동 중 | 사각사각 가벼운 긁는 소리 (루프) | `scratch_loop.ogg` |
| 경로 이탈 (금 발생) | 칙! 하는 날카로운 금 가는 소리 | `crack_snap.ogg` |
| 이탈 복귀 (경로 복귀 성공) | 부드러운 안도감 효과음 | `back_on_track.ogg` |
| 달고나 모양 완성 | 짝짝! 박수 소리 + 쨍그랑 깨끗한 소리 | `shape_complete.ogg` |
| 달고나 깨짐 (실패) | 바삭! 쩍 갈라지는 과자 소리 | `break_crumble.ogg` |
| 전체 클리어 | 팡파레 음악 | `game_clear.ogg` |

---

## 10. 작업 체크리스트

### Phase 1 — 경로 시스템 및 복합 관절 매핑
- [ ] FlameGame 골격 + Flutter 래퍼
- [ ] 어깨(Y축) + 팔꿈치(X축) 동시 입력 매핑 (`PART:lShoulderEF` + `PART:lElbow` 동시 수신)
- [ ] `DalgonaShape` enum 및 모양별 경로(List<Offset>) 생성 알고리즘 구현
- [ ] 경로를 canvas에 점선/실선으로 렌더링하는 `_drawPath()` 구현
- [ ] 바늘 커서 렌더링 및 X, Y 실시간 이동

### Phase 2 — 판정 시스템 (경로 이탈/추적)
- [ ] `_pointToSegmentDistance()` — 점과 선분 간 최단 거리 계산 유틸
- [ ] `_checkPathDeviation()` — 매 프레임 경로 이탈 검사 및 금 누적 로직
- [ ] `_updateProgress()` — 경로 진행률 계산 (바늘이 경로 위에 있을 때만 증가)
- [ ] `_currentSegment` 자동 전진 로직 (뒤로 돌아가는 것 방지)

### Phase 3 — 스프라이트 및 시각 연출
- [ ] 13종 에셋 로드 (`_loadImg()`)
- [ ] 달고나 원판 + 모양 각인 경로 중앙 정렬 렌더링
- [ ] 완료 구간 색상 변경 (점선 → 황금 실선) 로직
- [ ] 금 균열(crack_line) BlendMode.plus 오버레이 확장 연출
- [ ] 경로 방향 가이드 화살표(guide_arrow) 회전 로직

### Phase 4 — 파티클, 이펙트, 오디오
- [ ] 바늘 이동 중 설탕 가루 파티클 (sugar_particle, 중력 적용)
- [ ] 깨짐 시 조각 파티클 (crack_fragment, 사방 확산)
- [ ] 성공 시 반짝 파티클 (sparkle, BlendMode.screen, 원형 확산)
- [ ] BGM 재생 및 금 균열 70% 이상 시 긴장 트랙 전환
- [ ] SFX 6종 트리거 연동 (긁기 루프, 금 가기, 깨짐 등)

### Phase 5 — 마무리 및 어르신/환자 테스트
- [ ] Brunnstrom 단계별 경로 허용 폭/모양 복잡도 자동 매핑 검증
- [ ] 클리어 조건 및 결과 화면(성공/깨짐 구분) 연동
- [ ] 태블릿 실기기에서 두 관절 동시 입력 테스트 (노이즈, 응답 속도)
- [ ] `flutter build apk --release` 빌드 및 성능 프로파일링

---

## 11. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 어깨와 팔꿈치 센서 데이터를 하나의 `PART` 명령으로 전환하려 함 | 달고나 게임은 **두 관절 동시 입력**이 필요함. `game_motor_controller`에서 두 관절 데이터를 동시에 구독하는 방식 사용 |
| `_pointToSegmentDistance`를 단순히 점과 점 사이 거리로 계산 | 경로는 점이 아닌 **선분**이므로, 점과 선분 사이의 수직 최단 거리를 구해야 정확한 판정 |
| 진행률을 바늘 이동 거리로 계산 | 바늘이 경로를 벗어나서 돌아다닌 거리도 포함됨. 반드시 **경로 구간 인덱스 기반**으로 진행률을 산정 |
| 곡선 경로를 너무 적은 점(10개 미만)으로 근사 | 곡선이 각져서 보이고 판정도 부정확해짐. 원은 최소 64점, 별은 꼭짓점당 8점 보간 필수 |
| 금 균열 BlendMode를 설정하지 않음 | 검정 배경 금 이미지가 네모나게 보임. `Paint()..blendMode = BlendMode.plus` 필수 |

---

## 12. 렌더 순서 (Render Order - Z Depth)

```dart
// render() 내부 순서 — 달고나 위에 경로와 바늘이 올바르게 보여야 함
1. 배경: 포장마차 노점 (bg_street_stall)
2. 달고나 원판 (dalgona_base) — 화면 중앙
3. 미완료 경로 점선 (canvas.drawPath + dashEffect)
4. 완료 경로 황금 실선 (진행된 구간까지만)
5. 금 균열 오버레이 (crack_line / BlendMode.plus) — 달고나 위에 겹침
6. 방향 가이드 화살표 (guide_arrow / BlendMode.plus)
7. 바늘 커서 (needle_cursor) — 항상 최상단 오브젝트
8. 설탕 가루 파티클 (바늘 아래쪽으로 떨어짐)
9. 깨짐/성공 파티클 (이벤트 발생 시에만)
10. 성공 시 떠오르는 모양 오버레이 (dalgona_shape_overlay)
11. 원형 진행률 게이지 (progress_ring / BlendMode.plus)
12. HUD: 남은 시간, 점수, 남은 달고나 아이콘 (life_dalgona)
```
