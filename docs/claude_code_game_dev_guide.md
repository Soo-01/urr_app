# Claude Code로 Flutter/Flame 2D 게임 만들기
**작성일**: 2026-04-27 (최종 수정: 2026-05-06)  
**스택**: Flutter + Flame 1.36.0 + Dart  
**참고**: YouTube "Zero to Shipped Game with Claude Code in 20 Minutes" (Phaser 튜토리얼에서 Flutter/Flame로 적용)

---

## 1. 핵심 원칙

> "게임 하나씩 MVP → 플레이 테스트 → 피드백 → 개선"  
> "항상 빌드 전에 계획 먼저 (Always plan first before building)"

- **사람**: 아이디어 방향 + 에셋 선택 + 플레이 테스트 + 그래픽 확인
- **AI**: 코드 구현 + 리팩터링 + 버그 수정

매 단계마다 **항상 실행 가능한 상태** 유지

---

## 2. 전체 개발 흐름 (5단계)

```
1단계: 프로젝트 세팅
2단계: 게임 에셋 확보
3단계: 스펙(계획서) 작성
4단계: MVP 빌드 & 반복
5단계: 정리 & 배포
```

---

## 3. 1단계 — 프로젝트 세팅

### IDE 환경

- **VS Code / Cursor** 권장 — 터미널 + 파일 트리 동시에 확인 가능
- Claude Code는 터미널 또는 IDE 확장 모두 사용 가능

### Claude Code 실행 옵션

```bash
# 기본 실행 (매 작업마다 허락 요청)
claude

# 빠른 개발용 (허락 없이 자동 실행)
claude --dangerously-skip-permissions
```

> `--dangerously-skip-permissions`는 개인 프로젝트 / 개발 단계에서 속도를 크게 높인다.  
> 이 프로젝트처럼 `flutter run` 포함 작업이 많을 때 특히 유용.

### 초기 환경 확인

```bash
flutter pub get       # 의존성 설치
flutter run           # 디버그 실행
flutter analyze       # 정적 분석
flutter build apk     # APK 빌드
```

---

## 4. 2단계 — 게임 에셋 확보

### 무료 에셋 소스

| 소스 | 내용 | 라이선스 |
|------|------|---------|
| **Poly.pizza** | 3D 모델 | CC0 |
| **Sketchfab** | 3D 모델 (무료 필터) | 모델마다 다름 |
| **OpenGameArt.org** | 2D 게임 아트 | CC0 / GPL 등 |
| **itch.io** | 픽셀 아트 팩 | 팩마다 다름 |
| **Kenney.nl** | 2D/3D 게임 에셋 | CC0 |

### 에셋 확보 프로세스

```
① Claude에게 게임 설명
② "이 게임에 쓸 수 있는 무료 에셋 추천해줘" → web search
③ 사람이 직접 다운로드 → 프로젝트 폴더에 추가
④ Claude에게 "이 폴더에서 쓸 수 있는 에셋 목록 정리해줘"
```

### 이 프로젝트 에셋 전략 (방패 막기 게임)

```
3D 모델 다운로드 (사람)
  → Blender에서 PNG 렌더링 (사람)
  → assets/images/shield_guard/ 저장 (사람)
  → pubspec.yaml 등록 + 코드 연결 (Claude)
```

### pubspec.yaml 등록 (폴더 단위)

```yaml
flutter:
  assets:
    - assets/images/shield_guard/
    - assets/images/potion_maker/
```

> 폴더 단위로 등록하면 파일 추가 시 자동 포함

---

## 5. 3단계 — 스펙(계획서) 작성

### 좋은 스펙의 구성 요소

| 항목 | 내용 |
|------|------|
| **핵심 게임플레이** | 기본 메카닉 1~2줄 |
| **마일스톤** | 플레이 가능한 단계 3개 |
| **에셋 경로** | 각 스프라이트 파일 경로 명시 |
| **난이도 파라미터** | Brunnstrom Stage / CognitiveLevel 연동 |
| **제외 항목** | 나중에 할 것들 명확히 구분 |

### ask_user_question 활용

새 게임 기획 시 Claude에게 먼저 질문을 시킬 수 있다:

```
"이 게임의 스펙을 작성해. 요구사항 + 플레이 가능한 마일스톤 3개.
 질문이 있으면 ask_user_question 써."
```

→ Claude가 게임 방향, 기능, 에셋 등을 확인하는 질문을 던짐

### 스펙 다듬기

- Claude가 처음 만드는 스펙은 **너무 많은 것을 한 번에** 하려 함
- 불필요한 요소 과감히 제거
- 발표용 최소 요건(MVP)을 먼저 확정

---

## 6. 4단계 — MVP 빌드 & 반복

### 이 프로젝트 권장 개발 순서 (게임 1개 기준)

| 단계 | 목표 | Claude에게 맡길 일 |
|------|------|-----------------|
| 1 | 빈 게임 실행 | FlameGame 골격 + Flutter 래퍼 생성 |
| 2 | 입력 연결 | inputStream 구독 + setSimPosition 슬라이더 |
| 3 | 핵심 오브젝트 | 방패/화살 등 render()에 절차적 그래픽 |
| 4 | 게임 로직 | update()에 충돌·점수·타이머 |
| 5 | 스프라이트 교체 | Canvas 절차적 그래픽 → PNG 스프라이트 |
| 6 | 파티클·이펙트 | 성공/실패 피드백 |
| 7 | HUD | 점수·타이머·체력 표시 |
| 8 | 난이도 연결 | BrunnstromStage·CognitiveLevel 파라미터 반영 |

### 피드백 방식

**모호한 피드백도 효과 있다:**

```
❌ 불필요하게 정밀한 방식:
"화살 생성 주기를 2.5초에서 1.8초로 줄이고 속도를 190px/s로 올려라"

✅ 경험 위주 피드백 (충분히 작동함):
"게임이 너무 지루해. 화살 더 많이 나오게 하고 더 박진감 있게 만들어."
```

- 스크린샷을 붙여서 피드백하면 더 정확
- Claude는 맥락을 이해하고 적절히 해석함

### 버그 처리 방법

```
① 버그 현상 스크린샷 캡처
② Claude에게 스크린샷 + 현상 설명 붙여넣기
   예: "보스가 실제로 나타나지 않고 HP가 0처럼 보인다"
③ Claude 진단 + 수정 시도
④ 고쳐지면 → 원인을 Claude에게 물어서 이해
   예: "버그가 왜 발생했어? 설명해줘"
```

**포기하지 말 것 — 복잡한 버그도 끈기 있게 시도하면 해결된다.**

### 이 프로젝트 자주 발생하는 버그

| 상황 | 해결 접근법 |
|------|------------|
| 스프라이트 안 보임 | pubspec.yaml 경로 확인, onLoad() 로드 확인 |
| 충돌 판정 이상 | Rect 계산 분리 후 print()로 값 확인 |
| 프레임 드랍 | render()에 게임 로직 없는지 확인 |
| BT 스트림 끊김 | `_isSim` 플래그 + 슬라이더로 우회 테스트 |

---

## 7. 5단계 — 정리 & 배포

### 배포 방식 (Android APK)

```bash
flutter build apk --release
# → 생성된 APK를 발표용 태블릿에 설치
```

### 배포 전 체크리스트

- [ ] 사용하지 않는 에셋 파일 제거
- [ ] 미사용 import 삭제
- [ ] 디버그용 print() 제거
- [ ] 슬라이더 시뮬레이션 모드 정상 작동 확인
- [ ] 발표 시나리오 순서대로 앱 흐름 테스트

---

## 8. 프로젝트 구조

```
lib/games/
├── game_base.dart              ← GameConfig, CognitiveLevel, BrunnstromStage 공통 정의
├── game_graphics_utils.dart    ← 공통 절차적 그래픽 유틸 (GfxUtils)
├── game_motor_controller.dart  ← BT 모터 명령 래퍼
├── game_result_screen.dart     ← 게임 결과 화면
└── games/
    ├── shield_guard_game.dart
    ├── potion_maker_game.dart
    ├── tracking_game.dart
    └── ...

assets/images/
└── shield_guard/
    ├── shield_0.png ~ shield_5.png
    ├── shield_glow.png
    ├── arrow_down.png
    ├── arrow_up.png
    └── castle_0.png ~ castle_5.png
```

---

## 9. 게임 파일 기본 구조

모든 게임은 아래 패턴을 따른다:

```dart
// ① FlameGame 본체
class MyFlameGame extends FlameGame {
  final Stream<double>? inputStream; // BT 각도 스트림
  final GameConfig config;
  final void Function(GameResult) onGameEnd;

  @override
  Future<void> onLoad() async { ... }   // 컴포넌트 추가, 구독 시작

  @override
  void update(double dt) { ... }        // 게임 로직 (충돌, 점수, 타이머)

  @override
  void render(Canvas canvas) { ... }    // 그리기만 (로직 금지)

  void endGame() { ... }                // 결과 처리
  void setSimPosition(double v) { ... } // 시뮬레이션 슬라이더 연결
}

// ② Flutter StatefulWidget 래퍼
class MyGame extends StatefulWidget { ... }
class _MyGameState extends State<MyGame> {
  bool _isSim = false; // BT 미연결 시 슬라이더 모드

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Stack(children: [
      GameWidget(game: _game),
      if (_isSim) Slider(...),   // 시뮬레이션 슬라이더
      // 일시정지 / 정지 버튼
    ]));
  }
}
```

---

## 10. Claude Code 역할 분리

| 역할 | 사람 | Claude |
|------|------|--------|
| 게임 아이디어 / 방향 | ✅ | — |
| 에셋 다운로드 / 선택 | ✅ | — |
| Blender 렌더링 | ✅ | — |
| 플레이 테스트 | ✅ | — |
| 임상 적합성 판단 | ✅ | — |
| 코드 구현 | — | ✅ |
| 버그 수정 | — | ✅ |
| 리팩터링 | — | ✅ |
| pubspec.yaml / 에셋 연결 | — | ✅ |

### Claude에게 요청하는 방식

| 역할 | 요청 예시 |
|------|---------|
| 설계자 | "이번 단계에서 필요한 컴포넌트, 상태, 메서드만 설계해" |
| 구현자 | "방패 렌더링만 구현해. 화살은 건드리지 마" |
| 디버거 | "update()에서 프레임 드랍 원인 찾아 수정해" |
| 그래픽 | "render()에서 방패를 이 스프라이트로 교체해" |

---

## 11. 프롬프트 전략

### 기본 템플릿

```
이 프로젝트는 Flutter/Flame 1.36.0 재활 게임 앱이다.
현재 단계 목표: [한 가지 기능]
수정할 파일: lib/games/games/shield_guard_game.dart
수정 금지: game_base.dart, game_motor_controller.dart
완료 조건:
  1) flutter run 후 Shield Guard 게임 진입 가능
  2) 슬라이더로 방패 위아래 이동 가능
  3) 기존 BT 연결 로직 변경 없음
작업 전 변경 계획 요약 → 작업 후 TODO 목록 제시
```

### 그래픽 조정 프롬프트

```
❌ "방패를 더 멋있게 만들어"
✅ "방패 render()에서 단색 fill을 LinearGradient로 교체하고,
    _inTarget일 때 MaskFilter.blur 글로우를 추가해"

❌ "게임이 재미없다"
✅ "화살 속도가 너무 일정하다.
    _dynamicMode일 때 speed에 ±30% 랜덤 변화를 넣어라"
```

### 스프라이트 연결 프롬프트

```
assets/images/shield_guard/ 에 아래 파일이 추가됐다:
  shield_0.png ~ shield_5.png : 1080×1080, 투명 배경
  arrow_down.png, arrow_up.png : 1080×1080, 투명 배경

1) pubspec.yaml에 경로 추가
2) onLoad()에서 images.load()로 로드
3) render()에서 canvas.drawImageRect()로 교체
4) _wallHealth 값에 따라 shield_0~5 전환
5) 기존 절차적 그래픽 코드 제거
```

---

## 12. Flame 핵심 패턴

### 스프라이트 로드 및 렌더

```dart
// onLoad()
final shieldImages = await Future.wait([
  images.load('shield_guard/shield_0.png'),
  images.load('shield_guard/shield_1.png'),
  // ...
]);

// render()
final img = shieldImages[_wallHealth > 5 ? 5 : 5 - _wallHealth];
final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
final dst = Rect.fromCenter(center: Offset(shieldX, shieldY), width: 80, height: 80);
canvas.drawImageRect(img, src, dst, Paint());
```

### 컴포넌트 우선순위

```dart
priority: -10  // 배경
priority: -5   // 중간 레이어
priority:  0   // 게임 오브젝트
priority: 20   // 플로팅 텍스트
priority: 100  // HUD
```

### 파티클

```dart
add(ParticleSystemComponent(
  position: Vector2(x, y),
  particle: GfxUtils.explosionBurst(_rng, count, Colors.cyanAccent),
));
```

---

## 13. 시뮬레이션 ↔ 실제 장치 구조

```dart
// BT 연결 여부에 따라 자동 전환 (이미 구현됨)
_isSim = !widget.bluetoothService.isConnected();

final stream = _isSim
    ? null  // 슬라이더로 setSimPosition() 호출
    : widget.bluetoothService.dataStream
        .map((s) => double.tryParse(s.trim()))
        .where((v) => v != null)
        .map((a) => widget.config.normalizer.normalize(a!));
```

---

## 14. 자주 하는 실수

| 실수 | 올바른 방법 |
|------|------------|
| 한 번에 전체 게임 구현 요청 | 입력 → 렌더 → 로직 → 이펙트 순서로 분리 |
| 스펙 없이 바로 코드 | 계획서 먼저 작성 후 단계별 요청 |
| 버그 발생 시 포기 | 스크린샷 + 현상 설명으로 계속 재시도 |
| 플레이 테스트 없이 다음 단계 | 매 단계 flutter run 후 슬라이더로 직접 확인 |
| 수정 범위 불명확 | "이 파일만 수정, 저 파일 건드리지 마" 명시 |
| render()에 게임 로직 넣기 | 로직은 update(), 그리기만 render() |
| 스프라이트 없이 완성 시도 | 절차적 그래픽으로 먼저 동작, 스프라이트는 나중에 교체 |
| BT 코드 건드리기 | game_motor_controller.dart는 수정 금지 명시 |
| 버그 원인 미파악 | 수정 후 "버그가 왜 발생했어?" 반드시 물어볼 것 |

---

## 15. 이 프로젝트 현재 상태

| 게임 | 상태 |
|------|------|
| [S3] 방패 막기 | 🔄 코드 완성, 스프라이트 제작 중 |
| [E3] 물약 제조 | ⏳ 재설계 예정 |
| [C3] 치기/피하기 | ⏳ 재설계 예정 |
| 나머지 9개 | ⏳ Phase 2 (2026-05 ~ 2027-02) |

### 스프라이트 전달 후 즉시 할 일 (Claude 담당)

```dart
// 1. pubspec.yaml 등록
assets:
  - assets/images/shield_guard/

// 2. onLoad()에서 로드
final shieldImages = await Future.wait([
  images.load('shield_guard/shield_0.png'),
  // ... shield_1~5, shield_glow, arrow_down, arrow_up
]);

// 3. render()에서 교체
canvas.drawImageRect(shieldImages[damageStage], src, dst, paint);
```

### 발표(5/8) 최소 에셋 목록

```
필수 (9장):
  shield_0.png ~ shield_5.png   (방패 6단계)
  shield_glow.png               (목표 맞췄을 때 글로우)
  arrow_down.png                (굽힘저항 ↓)
  arrow_up.png                  (폄저항 ↑)

선택 (없으면 코드 배경 유지):
  castle_0.png ~ castle_5.png   (성 6단계)
```
