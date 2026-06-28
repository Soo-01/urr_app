# Changelog

모든 개발 업데이트를 날짜 역순으로 기록합니다.  
`exo` 브랜치 merge 시 반드시 여기에 항목을 추가하세요.

---

## [2026-06-29] — 신규 팀원 온보딩 문서 추가
- **변경**: `docs/onboarding_en.md`, `docs/onboarding_kr.md` 신규 생성
- **영향**: 앱 개발자 없음 (문서만)
- **관련 문서**: docs/onboarding_en.md, docs/onboarding_kr.md

---

## [2026-06-25] — arm_wrestling_build_guide.md 기획 고도화 (문서만)
- **변경**: 팔씨름 게임 문서 전면 개정 — 재활 타겟 어깨 내/외회전으로 변경, 1인칭→닌텐도 팔씨름 스타일 시점 논의, 에셋 전략(합성 크롭), 크로마키 #00FF00, Brawl Stars 스타일 확정, 동물 표정 9장 추가
- **영향**: 앱 개발자 없음 (문서만, 코드 미구현)
- **중단 지점**: 에셋 이미지 생성 시도 중 — 1인칭 시점 AI 생성 어려움으로 시점 재논의 후 중단
- **다음 결정**: **리듬 액션 게임 먼저 개발** (arm wrestling은 추후)
- **관련 문서**: docs/arm_wrestling_build_guide.md

---

## 형식 템플릿

```
## [YYYY-MM-DD] — 제목 (한 줄 요약)
- **변경**: 무엇을 했는가
- **영향**: 앱 개발자 대응 필요 여부 (없음 / handover_for_app_dev.md 참고)
- **관련 문서**: docs/파일명.md
```

---

## [2026-06-17] — docs 폴더 추가
- **변경**: 게임 빌드 가이드, 리서치, 계획 문서 21개를 docs/ 폴더로 정리
- **영향**: 앱 개발자 없음 (문서만)
- **관련 문서**: docs/handover_for_app_dev.md

## [2026-06-17] — 언어 설정, 이력 화면, 카드 폼 수정
- **변경**: 언어 설정(한국어/영어) 추가, 이력 페이지 개선, 저장 카드 폼 수정
- **영향**: 앱 개발자 없음 (기존 화면 수정)
- **관련 문서**: —

## [2026-06-17] — Shield Guard 블루투스 수정
- **변경**: shield_guard_game.dart 블루투스 통신 로직 수정
- **영향**: 앱 개발자 없음 (게임 내부만)
- **관련 문서**: docs/shield_guard_build_guide.md

## [2026-05-28] — 게임 시스템 초기 추가
- **변경**: lib/games/ 전체 구조 신규 추가 (game_base, game_hub, shield_guard 등)
- **영향**: 앱 개발자 확인 필요 — navi.dart 탭 인덱스 변경 (기존 탭 +1)
- **관련 문서**: docs/handover_for_app_dev.md
