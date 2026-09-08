# 장소 리뷰 요약 동의·신고 실행 기록

기록일: 2026-09-07. 인수 파일명은 작업 시작일 2026-09-06 유지.

## 문제와 수정

기존 장소 탐색 상세 및 일정의 장소 상세는 진입 시 리뷰 요약 GET을 호출했고, 구 User 서버는 캐시 miss 때 Gemini를 호출했다. Client는 자동 GET으로 저장된 요약만 표시하며, 캐시가 없을 때 사용자가 명시 버튼을 누르고 장소 리뷰 요약 범위의 외부 AI 전송에 동의한 뒤 POST하도록 변경했다.

Gemini 실제 prompt에는 장소명과 공개 블로그 후기 발췌문(description)이 전달된다. User→Agent의 제목 필드는 Gemini prompt에 포함되지 않는다. UI와 공개 정책의 고지는 최종 전달 범위에 맞췄다. 현재 위치의 좌표·주소 필드는 리뷰 요약 POST에 포함되지 않는다.

세 번째 동의 범위는 여행/Vision과 독립이며 이번 로그인에만 유효하다. 설정에서 해당 범위만 철회할 수 있다. 동의 거부는 POST 0회, 진행 중 중복 탭은 POST 추가 0회이다. POST body는 query, consent=true, client_request_id(UUID)만 포함한다. 실패 후 사용자의 재시도는 같은 UUID와 본문을 유지한다. 전송 직전, 401 갱신 재전송 전, 응답 반영 전에 세션과 동의 세대가 유효해야 한다. 철회 또는 계정 변경 이후 응답은 버린다.

저장된 요약과 새 생성 요약은 REVIEW_SUMMARY 신고 버튼을 제공한다. 사용자에게 표시된 장소명과 요약은 편집 가능한 설명 초안으로만 사용하며, 자동으로 검증된 원문이라고 표시하지 않는다. 신고는 reason/description/client_request_id/content_type 네 필드만 보내며 target ID와 이미지가 없다. 운영 결과는 기존 신고·차단 관리에서 조회한다.

## 실행 검증

- 최종 전체 Flutter tests: 400 PASS (`/tmp/map-review-consent-full-final-20260906.log`).
- 표적 동의·철회·신고·장소 UI·API tests: 45 PASS (`/tmp/map-review-consent-targeted-final-20260906.log`).
- 정적 분석: no issues (`/tmp/map-review-consent-analyze-exact-20260906.log`).
- 모바일 환경 계약 Python tests: 15 PASS (`/tmp/map-review-consent-config-tests-20260906.log`).
- 새 회귀: 캐시 GET 표시/자동 생성 없음, 거부, 동일 UUID 재시도, pending 버튼 잠금, 철회·계정 변경 응답 폐기, 401 중 철회 재전송 차단, 세 번째 범위 독립 철회, 캐시 결과의 앱내 신고와 수정 설명, description-only 신고 계약, JSON 인코딩 후 전송 직전 가드.
- 코드 graphify query 선행 및 새 worktree 내 `graphify update .` 완료. 원래 root graph는 수정하지 않음.
- 로컬 synthetic fixtures/mock HTTP만 사용. 외부 검색·유료 AI 호출·GCP mutation·실사용자 변경 0.

## 배포와 한계

Client 기반: 6aa709660d4d347977a13063158b308f88bc2cf3. 작업 브랜치: fix/review-summary-ai-consent-20260906.

**User cached-only GET + 명시 POST 계약, REVIEW_SUMMARY V028 전진 migration을 먼저 배포한 뒤 Client를 공개해야 한다.** 구 User 서버는 같은 GET에서 Gemini를 호출할 수 있으므로 Client 단독 배포로 자동 호출 문제가 해소되지 않는다. 기존 cache 응답의 query/bullets/sourceCount 형태는 호환된다.

이 증거는 로컬 실행 범위이다. GCP 새 endpoint 저장·신고 운영 처리, 실제 브라우저·기기·스토어 빌드의 해당 화면은 별도 검증이 필요하다. 동의 철회는 새 전송·응답 반영을 막으며 이미 서버/외부 AI에 전송한 요청을 원격 취소하거나 삭제하지 않는다.
