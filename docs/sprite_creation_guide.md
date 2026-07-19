# 방패 막기 게임 — 스프라이트 제작 가이드 (AI 이미지 생성)
**작성일**: 2026-05-07  
**도구**: Gemini / ChatGPT Image / Midjourney 등 AI 이미지 생성 툴  
**담당**: 사람 (프롬프트 작성 + 배경 제거) + AI (코드 연결)

---

## 1. 필요한 스프라이트 목록

| # | 파일명 | 내용 | 크기 | 우선순위 |
|---|--------|------|------|---------|
| 1 | `shield_0.png` | 완전한 방패 | 1080×1080 | 필수 |
| 2 | `shield_1.png` | 흠집 1개 | 1080×1080 | 필수 |
| 3 | `shield_2.png` | 흠집 2개 + 긁힘 | 1080×1080 | 필수 |
| 4 | `shield_3.png` | 가장자리 조각 떨어짐 | 1080×1080 | 필수 |
| 5 | `shield_4.png` | 심하게 파손, 중앙 균열 | 1080×1080 | 필수 |
| 6 | `shield_5.png` | 거의 파괴, 뼈대만 남음 | 1080×1080 | 필수 |
| 7 | `shield_glow.png` | 방패 형태 발광 오버레이 | 1080×1080 | 필수 |
| 8 | `arrow_down.png` | 화살 + 굵은 ↓ 표시 | 1080×1080 | 필수 |
| 9 | `arrow_up.png` | 화살 + 굵은 ↑ 표시 | 1080×1080 | 필수 |
| 10 | `castle_0.png` | 완전한 중세 성 | 1920×1080 | 선택 |
| 11 | `castle_1~5.png` | 성 붕괴 단계 | 1920×1080 | 선택 |

> **발표 최소 요건**: 1~9번 (9장)만 있으면 시연 가능

---

## 2. AI 이미지 생성 프로세스

```
① AI 툴에 아래 프롬프트 입력
② 생성된 이미지 확인 → 마음에 안 들면 재생성 또는 프롬프트 수정
③ 배경 제거 (투명 PNG 변환) → remove.bg 또는 AI 툴 자체 기능
④ 크기 조정 → 1080×1080 (방패/화살), 1920×1080 (성)
⑤ assets/images/shield_guard/ 에 저장
```

### 배경 제거 도구

| 도구 | 방법 |
|------|------|
| **remove.bg** | 업로드하면 자동 투명 배경 처리 (무료 저해상도) |
| **Gemini** | 프롬프트에 "transparent background" 명시 |
| **Photoshop** | 자동 선택 → 배경 삭제 |
| **GIMP** (무료) | 퍼지 선택 → 배경 삭제 → PNG 내보내기 |

---

## 3. 스타일 통일 기준

모든 스프라이트에 **동일한 스타일 접두어**를 붙여서 일관성 유지:

```
스타일: 3D 렌더링 느낌의 사실적 중세 판타지 오브젝트
조명: 왼쪽 위 45도 방향 강한 주광, 오른쪽 약한 반사광
배경: 투명 (transparent background)
시점: 정면 (front-facing), 약간 위에서 내려다보는 각도
품질: 게임 아이콘 수준 고품질 렌더링
```

---

## 4. 스프라이트별 AI 프롬프트

### 방패 (shield_0 ~ shield_5)

**공통 베이스 프롬프트:**
```
A medieval knight's shield, heater shape,
metallic silver surface with decorative cross emblem in the center,
gold trim border, 3D rendered, photorealistic,
front-facing view, strong key light from upper-left,
transparent background, square format 1:1
```

**단계별 추가 프롬프트:**

| 파일 | 추가 설명 |
|------|---------|
| `shield_0` | (추가 없음 — 완전한 상태) |
| `shield_1` | `with one deep scratch mark on the surface` |
| `shield_2` | `with two scratch marks, paint chipping off, worn edges` |
| `shield_3` | `with a chunk broken off from the edge, cracks visible` |
| `shield_4` | `heavily damaged, large crack across the center, bent metal, paint mostly gone` |
| `shield_5` | `nearly destroyed, only the metal frame remains, multiple large holes, severely bent` |

**같은 세션에서 순서대로 생성하는 방법 (권장):**
```
1) shield_0 생성 → 마음에 들면 저장
2) "이 방패에 흠집 하나를 추가해줘" → shield_1
3) "흠집을 하나 더 추가하고 도색이 벗겨지도록 해줘" → shield_2
4) 이런 식으로 순차적으로 손상 추가 → 스타일 일관성 유지
```

---

### 글로우 오버레이 (shield_glow)

```
A glowing magical aura in the shape of a heater shield outline,
cyan-blue luminous energy glow, soft radiant light,
no solid fill — only the glowing border and inner light effect,
transparent background, square format 1:1,
game UI overlay style
```

> 방패 이미지 위에 반투명하게 합성되므로 배경이 완전히 투명해야 함  
> 글로우 색상: 청록색 (#00E5FF 계열)

---

### 화살 (arrow_down, arrow_up)

**공통 베이스:**
```
A medieval arrow, wooden shaft with brown color,
metal arrowhead (silver), natural feather fletching,
3D rendered, photorealistic, transparent background,
square format 1:1, game asset style
```

**방향별 추가:**

| 파일 | 추가 설명 |
|------|---------|
| `arrow_down` | `pointing downward vertically, with a bold white downward arrow symbol ↓ on the shaft` |
| `arrow_up` | `pointing upward vertically, with a bold white upward arrow symbol ↑ on the shaft` |

> ↓↑ 기호 생성이 어려우면 기호 없이 방향만 맞춰도 됨 — 코드에서 텍스트로 덧그릴 수 있음

---

### 성 배경 (castle_0 ~ castle_5) — 선택

**공통 베이스:**
```
A realistic medieval stone castle at dusk,
massive stone walls with detailed texture, tall towers with battlements,
dramatic golden-orange sunset sky with purple clouds,
cinematic dramatic side lighting, wide panoramic view,
photorealistic, 16:9 aspect ratio, high detail, full scene
```

**단계별 추가:**

| 파일 | 추가 설명 |
|------|---------|
| `castle_0` | (추가 없음 — 완전한 상태) |
| `castle_1` | `with cracks in the walls, a few stones fallen out` |
| `castle_2` | `with the top of a small tower collapsed, debris on the ground` |
| `castle_3` | `with half of the main tower destroyed, rubble scattered` |
| `castle_4` | `heavily damaged, main wall partially collapsed, large hole visible` |
| `castle_5` | `completely in ruins, only rubble and broken walls remain` |

> 성 배경은 배경 제거 불필요 — 하늘 포함 전체 이미지 그대로 사용

---

## 5. 일관성 유지 팁

| 팁 | 설명 |
|-----|------|
| **같은 세션 유지** | AI 대화를 끊지 않고 이어서 생성하면 스타일 일관성 높아짐 |
| **이미지 첨부 수정** | shield_0 완성 후 → 이미지 첨부하면서 "이걸 기반으로 손상 추가해줘" |
| **재시도 권장** | 한 번에 마음에 드는 이미지가 나오지 않는 것이 정상, 3~5회 재시도 |
| **비교 확인** | 6장을 나란히 놓고 손상 정도가 단계적으로 느껴지는지 확인 |

---

## 6. 이미지 크기 조정

| 항목 | 목표 크기 | 간단한 방법 |
|------|---------|------------|
| 방패 / 화살 / 글로우 | 1080×1080 | Windows 그림판 → 크기 조정 |
| 성 배경 | 1920×1080 | Windows 그림판 → 크기 조정 |

> 크기가 정확하지 않아도 코드에서 `drawImageRect`로 자동 조정되므로 ±100px 오차는 괜찮음

---

## 7. 저장 위치

```
k:\upper_limb_rehap_game\assets\images\shield_guard\
  ├── shield_0.png
  ├── shield_1.png
  ├── shield_2.png
  ├── shield_3.png
  ├── shield_4.png
  ├── shield_5.png
  ├── shield_glow.png
  ├── arrow_down.png
  ├── arrow_up.png
  ├── castle_0.png  (선택)
  └── ...
```

저장 완료 후 → Claude에게 알리면 코드 연결 즉시 처리

---

## 8. 작업 분담

| 작업 | 담당 |
|------|------|
| AI 프롬프트 작성 + 이미지 생성 | **사람** |
| 배경 제거 (투명 PNG 변환) | **사람** |
| 크기 조정 후 폴더 저장 | **사람** |
| pubspec.yaml 등록 | Claude |
| onLoad() 스프라이트 로드 코드 | Claude |
| render() 스프라이트 교체 | Claude |
| 손상 단계 전환 로직 | Claude |
