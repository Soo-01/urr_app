# 상지재활로봇 게임 자료조사

## 1. 개요

상지재활 외골격 로봇과 결합된 게임 기반 재활(Game-Based Rehabilitation)은 환자의 치료 참여도와 동기를 크게 높여, 반복 훈련의 질과 양을 모두 개선하는 것으로 입증되었다. 본 문서는 상용 재활로봇 시스템의 게임 분석, 재활 게임 설계 원칙, 1D 각도 입력 기반 게임 유형 분류 및 임상 근거를 정리한다.

---

## 2. 상용 재활로봇 시스템 게임 분석

### 2.1 Armeo (Hocoma)

**시스템:** Armeo Power, Armeo Spring, Armeo Spring Pro
**특징:**
- 상지 관절 센서 내장, 무게 상쇄(counterbalancing) 지원
- 가장 광범위한 게임 라이브러리 보유
- 1D, 2D, 3D 운동 변형 지원

**게임 유형:**
- 일상생활 활동(ADL) 시뮬레이션 게임
- Augmented Performance Feedback 운동 (근력, ROM 훈련)
- 목표 지향적 게임플레이 + 즉각적 보상

**난이도 적응:**
- 각 관절 센서가 움직임을 기록
- 환자 수행에 따른 자동 난이도 조절
- 점진적 진행의 맞춤형 훈련 프로그램

**대상 질환:** 뇌졸중, 외상성 뇌손상, 척수 손상, 다발성 경화증, 뇌성마비, 파킨슨병

---

### 2.2 InMotion ARM (BIONIK Labs)

**시스템:** 케이블 구동 종단점 로봇
**특징:**
- 도달 운동(reaching)과 손 궤적에 초점
- 뇌졸중 후 재활에 가장 널리 사용 (250+ 기관, 900+ 뇌졸중 환자 임상 검증)
- 세션당 400~1,000회 반복

**게임 특징:**
- 운동 계획, 협응, 주의력을 위한 Serious Games
- 반응형 보조: 환자 능력에 따라 로봇 도움 적응
- 환자가 움직임을 시작할 수 없을 때 능동 가이드
- 개선에 따른 점진적 보조 감소

**게임 메커닉:**
- 경쟁 및 협동 게임 모드
- 양손 운동 지원 (대칭/비대칭 양측 훈련)
- 기능적 독립성 측정(FIM) 점수 추적

---

### 2.3 KINARM (BKIN Technologies)

**시스템:** 휠체어 장착형 양팔 외골격
**특징:**
- 연구 중심 시스템, 정량적 평가에 초점
- Dexterit-E 독점 소프트웨어

**평가 게임:**
- 표준화된 운동/인지 과제 배터리
- 학습, 문제 해결, 지각 테스트
- 정량적 고유감각(proprioception) 평가
- 양측 협응 측정

**고유 특징:**
- 전통적 신경학적 평가의 주관성 제거
- 관절별 정밀 힘 측정
- 연령 매칭 대조군과의 상세 성능 보고

---

### 2.4 Amadeo (Tyromotion)

**시스템:** 손가락-손 재활 장치
**특징:**
- 개별 손가락 그립이 있는 팔 지지 슬리브
- 바이오피드백 및 assist-as-needed 상호작용

**게임 유형:**
- 손가락 굴곡/신전 훈련용 VR 게임
- 악력 및 운동 제어 운동
- 간단하고 재미있고 보상적인 게임플레이

**치료 초점:** 악력 기능, 손가락 독립성/협응, 뇌졸중 후 손 회복

---

## 3. 재활 게임 설계 원칙

### 3.1 치료 목표와 게임의 매핑

| 치료 목표 | 게임 설계 전략 |
|-----------|---------------|
| **관절가동범위(ROM) 훈련** | 타겟을 점진적으로 멀리 배치, 현재 ROM 대비 달성 ROM 실시간 피드백, 환자 유연성 한계에 따른 자동 스케일링 |
| **근력 발달** | 게임 환경에서 저항 적용, 움직임 속도 요구 점진적 증가, 반복 횟수 추적 |
| **협응 훈련** | 제약 기반 과제 (직선/곡선 경로), 양손 동기화, 부드러움 메트릭과 시각적 피드백 |
| **정밀도/제어** | 좁은 타겟 존, 위치 유지 과제, 고유감각 훈련 |

### 3.2 점수 및 피드백 메커니즘

**실시간 피드백 (연속):**
- 관절 위치의 실시간 시각적 피드백
- 타겟 접촉 시 시각/청각 피드백
- 게임 중 성능 메트릭 표시
- 햅틱 피드백 (진동/저항) 가능

**세션 요약 피드백 (게임 후):**
- 총 획득 점수
- 성공/실패율
- 히트/미스 횟수
- 달성된 움직임 진폭
- 움직임 부드러움 점수

**보상 시스템:**
- 성공적 타겟 도달 시 포인트
- 가상 코인/수집품
- 배지 및 업적 해제
- 레벨 진행
- 도파민 활성화를 통한 보상 (측좌핵 활성)

### 3.3 난이도 적응 전략 (Flow 이론)

**원칙:** 환자의 기술 수준과 게임 도전 사이의 균형
- 지루함 방지 (기술 > 도전) 및 좌절 방지 (도전 > 기술)
- 게임 중 동적 조절

**적응 파라미터:**
- 타겟 속도/이동 거리
- 시간 제한
- 오브젝트/장애물 수
- 오브젝트 행동 복잡성
- 감도 임계값
- 보조 수준 (로봇 도움량)

**적응 트리거:**
- 성공률 모니터링 (>80% → 난이도 증가, <40% → 감소)
- 움직임 품질 메트릭
- 세션 지속 시간 및 참여도
- 환자 동기 부여 지표

### 3.4 동기 부여 전략

근거 기반 동기 부여 요소:
1. **즉각적 보상:** 성공 시 포인트, 사운드, 시각 효과
2. **진행 추적:** 레벨/마일스톤 진행 시각화
3. **업적 시스템:** 배지, 잠금 해제, 완료 추적
4. **경쟁:** 리더보드, 경쟁 게임 모드
5. **서사/테마:** 실생활 활동 테마 (낚시, 요리, 쇼핑 등)
6. **다양성:** 단조로움 방지를 위한 다양한 게임 유형
7. **자율성:** 게임 선택과 난이도에 대한 환자 선택권

**핵심 발견:** 명시적이고 연속적인 피드백이 있는 게임이 그렇지 않은 게임보다 치료 결과가 유의하게 우수함.

---

## 4. 1D 각도 입력 기반 게임 유형 분류

본 앱은 블루투스를 통해 단일 관절 각도 값을 수신하므로, 1D 입력으로 동작하는 게임에 초점을 맞춘다.

### 4.1 타겟 도달 (Target Reaching)

- **메커닉:** 화면의 특정 각도 위치에 타겟 출현, 환자가 이동하여 도달
- **입력:** 단일 관절 각도 (예: 0~90° → 화면 좌→우)
- **점수:** 정확도와 속도에 따른 포인트
- **난이도:** 타겟 거리, 크기, 시간 제한, 타겟 수 변경
- **임상 근거:** Armeo, InMotion 시스템의 주요 운동. 모든 재활 시스템에서 가장 기본적인 게임 유형

### 4.2 풍선 터트리기 (Balloon Pop)

- **메커닉:** 다양한 각도 위치에 풍선 출현, 도달하여 터트리기
- **입력:** 관절 각도 → 커서 위치
- **점수:** 풍선당 포인트, 연속 팝 콤보
- **난이도:** 풍선 수, 이동 속도, 크기, 타겟 정밀도
- **임상 근거:** ROM 및 속도 훈련에 효과적, 환자에게 높은 동기 부여 제공

### 4.3 추적/따라가기 (Tracking/Following)

- **메커닉:** 타겟이 부드럽게 화면을 이동, 환자가 정확히 따라감
- **입력:** 관절 각도 → 커서 위치
- **점수:** 타겟 이탈 페널티, 정확도 보상
- **난이도:** 타겟 속도, 장애물, 추적 지속 시간 증가
- **임상 근거:** 협응 및 부드러움 평가/훈련. 대측 대칭성 측정에 유용

### 4.4 두더지 잡기 (Whack-A-Mole) — 향후 구현

- **메커닉:** 타겟이 다양한 각도 위치에 짧게 출현, 빠르게 도달
- **입력:** 관절 각도 → 도달 위치
- **점수:** 타겟당 포인트, 콤보 배수
- **난이도:** 더 많은 타겟, 짧은 노출 시간, 예측 불가능한 위치
- **임상 근거:** 반응 시간, 속도, 적극적 ROM 훈련

### 4.5 과일 받기 (Fruit Catching) — 향후 구현

- **메커닉:** 오브젝트가 위에서 떨어짐, 환자가 위치 조정하여 받기
- **입력:** 관절 각도 → 수평 위치
- **점수:** 받은 오브젝트당 포인트
- **난이도:** 빠른 낙하, 좁은 캐치 존, 다단계 빌딩
- **임상 근거:** ROM, 속도, 반응 시간 훈련

### 4.6 낚시 게임 (Fishing) — 향후 구현

- **메커닉:** 다양한 깊이에 물고기 출현, 도달하여 낚기
- **입력:** 관절 각도 → 커서/낚시 바늘 위치
- **점수:** 잡은 물고기당 포인트, 시간 기반 도전
- **난이도:** 물고기 속도, 출현 빈도, 정밀도 요구
- **임상 근거:** ADL 시뮬레이션 (일상생활 활동 훈련), 참여도 향상

---

## 5. 기술 구현 고려사항

### 5.1 렌더링 방식 선택

| 방식 | 장점 | 단점 | 적합 대상 |
|------|------|------|-----------|
| **CustomPainter** | 제로 위젯 오버헤드, 최대 성능, 의존성 없음 | 게임 로직 수동 코딩, 충돌 감지 없음 | 단순 1D 게임 (타겟, 추적) |
| **Flame 엔진** | 게임 루프 내장, 스프라이트/충돌 지원, 확장성 | 프레임워크 오버헤드, 학습 곡선 | 복잡한 2D 게임 (향후) |

**결정:** Priority 1 게임(타겟 도달, 풍선 팝, 추적)은 CustomPainter로 구현. 새 의존성 불필요.

### 5.2 실시간 BT 데이터 + 애니메이션 성능

- **BT 데이터 수신:** 20~50Hz
- **렌더링 목표:** 60fps (프레임당 16.67ms)
- **핵심 최적화:**
  - 게임 캔버스에 독립적인 repaint 레이어 사용
  - BT 업데이트 시 전체 UI가 아닌 CustomPaint 위젯만 리빌드
  - AnimationController로 60fps 애니메이션 (추적 게임의 타겟 이동)
  - 화면 벗어날 때 애니메이션 일시정지 (배터리 절약)

### 5.3 환자 접근성 고려

- 모든 상호작용 요소: 최소 48dp 터치 타겟
- 높은 대비 색상
- 시각 + 청각(TTS) 피드백 동시 제공
- FontSizeProvider.scaleFactor 적용
- 낮은 난이도에서 빠른 미세 운동 제어 요구 회피

---

## 6. 참고 문헌

1. MDPI Sensors (2023). "Design and Analysis of an Upper Limb Rehabilitation Robot Based on Multimodal Control." Sensors 23(21):8801.
2. Springer Virtual Reality (2024). "Assessment of gamified mixed reality environments for upper limb robotic rehabilitation."
3. Hocoma. "Armeo Power Software." hocoma.com/solutions/armeo-power/software/
4. BIONIK Labs / Fitness Gaming. "InMotion ARM Robots for Neurorehabilitation."
5. PMC (2024). "Benefits of Robot-Assisted Upper-Limb Rehabilitation." PMC10856364.
6. Physio-pedia. "KINARM: Kinesiological Instrument for Normal and Altered Reaching Movements."
7. Springer (2014). "Dynamic Difficulty Adaptation in Serious Games for Motor Rehabilitation."
8. JNER (2024). "CFI: VR Motor Rehabilitation Framework." Journal of NeuroEngineering and Rehabilitation.
9. PMC (2025). "Design Guidelines for Game-Based Physical Rehabilitation." PMC12468163.
10. MDPI Applied Sciences (2025). "Developing Serious Video Games for Post-Stroke Rehabilitation." 15(15):8240.
11. Tyromotion. "Amadeo Hand Rehabilitation Robot." tyromotion.com/en/products/amadeo/
12. JMIR Games (2024). "Design of Virtual Reality Exergames for Upper Limb Stroke Rehabilitation." e48900.
13. ResearchGate (2015). "Adaptation in Serious Games for Upper-Limb Rehabilitation."
14. JMIR Games (2020). "Serious Gaming Technology in Upper Extremity Rehabilitation." e19071.
15. JNER (2024). "CFI Framework: Clinical-Function-Interesting Integration."
16. PMC (2020). "Upper Limb Physical Rehabilitation Using Serious Videogames." PMC7660052.
17. PMC (2015). "Wrist ROM During Game Play with Joint-Specific Controller." PMC4536107.
18. JMIR Games (2025). "Reward Feedback Mechanism in VR Serious Games." e67338.
19. JMIR Games (2021). "Standardizing Development of Serious Games." e25854.
